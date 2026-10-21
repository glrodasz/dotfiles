#!/usr/bin/env node
// Fetch human review activity from merged PRs into <store>/raw/<date>.jsonl, one PR per line.
//
// Usage: node fetch-reviews.mjs [since] [--repo owner/name | --repo org:name]...
//          [--search "<GitHub search qualifiers>"] [--path <prefix|glob>]...
//          [--reviewer <login>]... [--exclude-user <login>]... [--limit 300] [--rescan]
//
// since: 14d | 2w | 3m | 2026-10-01 (also accepts "since: 14d"). Without it, the watermark
// of the previous run with the same filters is used, else 30 days.
import { execFile } from 'node:child_process';
import fs from 'node:fs';
import {
  STORE, ensureStore, gh, loadState, parseFlags, saveState, storePath, tailLines, today,
  truncateChars, truncateLines,
} from './lib.mjs';


const KNOWN_BOTS = new Set([
  'copilot', 'copilot-pull-request-reviewer', 'github-actions', 'dependabot', 'renovate',
  'coderabbitai', 'sonarcloud', 'sonarqubecloud', 'codecov', 'vercel', 'netlify', 'linear',
  'changeset-bot', 'cursor', 'greptile-apps', 'graphite-app', 'sourcery-ai', 'deepsource-io',
  'snyk-bot', 'socket-security', 'mergify', 'kodiakhq', 'claude', 'gemini-code-assist',
]);
const TRIVIAL_RE =
  /^\s*(lgtm|looks good( to me)?|approved?|ship ?it|:shipit:|nice( work| one)?|thanks?( you)?|ty|great( work| job)?|done|fixed|\+1|👍|🚀|✅|🎉|💯|🔥)[\s!.:)]*$/i;
const MAX_PATCH_LINES = 80;
const MAX_ATTEMPTS = 5;
const PR_CACHE_TTL = 86400e3; // a crashed run resumes from cache for a day
const COMMIT_CACHE_TTL = 7 * 86400e3; // commits are immutable; just bound the size
const TRANSIENT_RE =
  /connection reset|ECONNRESET|ETIMEDOUT|timeout|EOF|TLS|HTTP 5\d\d|\b50[234]\b|secondary rate limit|rate limit|abuse|submitted too quickly|RATE_LIMITED|something went wrong/i;
const MAX_COMMITS_PER_THREAD = 3;
const CONCURRENCY = 4;

const flags = parseFlags(process.argv.slice(2), {
  repeatable: ['repo', 'path', 'reviewer', 'exclude-user'],
  boolean: ['rescan'],
});
const limit = Number(flags.limit ?? 300);
const excludeUsers = new Set(flags['exclude-user'].map((u) => u.toLowerCase()));
const reviewers = new Set(flags.reviewer.map((u) => u.toLowerCase()));
const pathMatchers = flags.path.map(toPathMatcher);

function parseSince(tokens) {
  const text = tokens.join(' ').replace(/since:?/i, '').trim();
  if (!text) return null;
  const date = text.match(/\b\d{4}-\d{2}-\d{2}(T[\d:.]+Z?)?\b/);
  if (date) return new Date(date[0]).toISOString();
  const rel = text.match(/\b(\d+)\s*([dwm])\b/i);
  if (rel) {
    const days = Number(rel[1]) * { d: 1, w: 7, m: 30 }[rel[2].toLowerCase()];
    return new Date(Date.now() - days * 86400e3).toISOString();
  }
  throw new Error(`Cannot read a "since" value from: ${text}`);
}

function toPathMatcher(pattern) {
  if (!/[*?]/.test(pattern)) return (p) => p.startsWith(pattern);
  const re = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*\*\/?/g, '\u0000')
    .replace(/\*/g, '[^/]*')
    .replace(/\?/g, '[^/]')
    .replace(/\u0000/g, '.*');
  return (p) => new RegExp(`^${re}$`).test(p);
}

function isBot(actor) {
  if (!actor) return true;
  const login = actor.login.toLowerCase();
  return (
    actor.__typename === 'Bot' ||
    /\[bot\]$|bot$|^bot-/.test(login) ||
    KNOWN_BOTS.has(login) ||
    excludeUsers.has(login)
  );
}

// Machine-written comments from user-type accounts usually open with an HTML marker.
const isTrivial = (body) =>
  !body || !body.trim() || TRIVIAL_RE.test(body) || body.trimStart().startsWith('<!--');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function withRetry(label, fn) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt >= MAX_ATTEMPTS || !TRANSIENT_RE.test(err.message)) throw err;
      const wait = 1000 * 2 ** attempt + Math.random() * 1000;
      process.stderr.write(`  retry ${attempt}/${MAX_ATTEMPTS - 1} in ${Math.round(wait / 1000)}s (${label}): ${err.message.split('\n')[0]}\n`);
      await sleep(wait);
    }
  }
}

function graphql(query, variables) {
  return withRetry('graphql', async () => {
    const { stdout } = await runWithInput(
      ['api', 'graphql', '--input', '-'],
      JSON.stringify({ query, variables }),
    );
    const res = JSON.parse(stdout);
    if (res.errors?.length) throw new Error(res.errors.map((e) => e.type ?? e.message).join('; '));
    return res.data;
  });
}

const cacheFile = (kind, key) => storePath('cache', kind, `${key.replace(/[^\w.-]/g, '__')}.json`);

function readCache(kind, key, ttl) {
  const file = cacheFile(kind, key);
  try {
    if (Date.now() - fs.statSync(file).mtimeMs > ttl) return null;
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return null;
  }
}

function writeCache(kind, key, value) {
  const file = cacheFile(kind, key);
  fs.mkdirSync(storePath('cache', kind), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value));
}

function pruneCache() {
  for (const [kind, ttl] of [['prs', PR_CACHE_TTL], ['commits', COMMIT_CACHE_TTL]]) {
    const dir = storePath('cache', kind);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir)) {
      const file = `${dir}/${f}`;
      if (Date.now() - fs.statSync(file).mtimeMs > ttl) fs.rmSync(file);
    }
  }
}

function runWithInput(args, input) {
  return new Promise((resolve, reject) => {
    const child = execFile('gh', args, { maxBuffer: 256 * 1024 * 1024 }, (err, stdout, stderr) =>
      err ? reject(new Error(stderr || err.message)) : resolve({ stdout }),
    );
    child.stdin.end(input);
  });
}

async function pool(items, worker) {
  const results = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        results[i] = await worker(items[i], i);
      }
    }),
  );
  return results;
}

const SEARCH_QUERY = `query($q: String!, $after: String) {
  search(query: $q, type: ISSUE, first: 50, after: $after) {
    pageInfo { hasNextPage endCursor }
    nodes { ... on PullRequest { number mergedAt repository { nameWithOwner } } }
  }
}`;

const ACTOR = 'author { login __typename }';
const PR_QUERY = `query($owner: String!, $name: String!, $number: Int!, $after: String) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      number title body url createdAt mergedAt baseRefName ${ACTOR}
      files(first: 100) { totalCount nodes { path additions deletions } }
      commits(first: 100) { nodes { commit { oid committedDate messageHeadline } } }
      reviews(first: 100) { nodes { id ${ACTOR} state body submittedAt url } }
      comments(first: 100) { nodes { id ${ACTOR} body createdAt url } }
      reviewThreads(first: 50, after: $after) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id path line originalLine startLine isResolved isOutdated
          comments(first: 50) { nodes { ${ACTOR} body createdAt url diffHunk } }
        }
      }
    }
  }
}`;

// GitHub search returns at most 1000 hits per query, so walk the window in weekly slices,
// oldest first. When the limit cuts a run short, `until` stops at the last PR fetched so
// the next run resumes from there instead of skipping the rest.
async function searchPRs(since, until, qualifiers) {
  const found = [];
  const week = 7 * 86400e3;
  for (let start = Date.parse(since); start < Date.parse(until); start += week) {
    const from = new Date(start).toISOString().replace(/\.\d+Z$/, 'Z');
    const to = new Date(Math.min(start + week, Date.parse(until))).toISOString().replace(/\.\d+Z$/, 'Z');
    const q = `is:pr is:merged merged:${from}..${to} ${qualifiers}`.trim();
    const slice = [];
    let after = null;
    do {
      const data = await graphql(SEARCH_QUERY, { q, after });
      slice.push(...data.search.nodes.filter((n) => n.number));
      after = data.search.pageInfo.hasNextPage ? data.search.pageInfo.endCursor : null;
    } while (after);
    const seenKeys = new Set(found.map((n) => `${n.repository.nameWithOwner}#${n.number}`));
    const fresh = slice.filter((n) => !seenKeys.has(`${n.repository.nameWithOwner}#${n.number}`));
    found.push(...fresh.sort((a, b) => a.mergedAt.localeCompare(b.mergedAt)));
    if (found.length >= limit) {
      const kept = found.slice(0, limit);
      return { hits: kept, until: kept.at(-1).mergedAt, capped: true };
    }
  }
  return { hits: found, until, capped: false };
}

async function fetchPR(repo, number) {
  const cached = readCache('prs', `${repo}#${number}`, PR_CACHE_TTL);
  if (cached) return cached;
  const [owner, name] = repo.split('/');
  let pr;
  let after = null;
  const threads = [];
  do {
    const data = await graphql(PR_QUERY, { owner, name, number, after });
    pr = data.repository.pullRequest;
    threads.push(...pr.reviewThreads.nodes);
    after = pr.reviewThreads.pageInfo.hasNextPage ? pr.reviewThreads.pageInfo.endCursor : null;
  } while (after);
  pr.reviewThreads = threads;
  writeCache('prs', `${repo}#${number}`, pr);
  return pr;
}

const commitCache = new Map();
async function commitFiles(repo, oid) {
  const key = `${repo}@${oid}`;
  if (!commitCache.has(key)) {
    const cached = readCache('commits', key, COMMIT_CACHE_TTL);
    commitCache.set(
      key,
      cached
        ? Promise.resolve(cached)
        : withRetry('commit', () => runWithInput(['api', `repos/${repo}/commits/${oid}`], ''))
            .then(({ stdout }) => {
              const files = (JSON.parse(stdout).files ?? []).map(({ filename, previous_filename, patch }) => ({
                filename, previous_filename, patch,
              }));
              writeCache('commits', key, files);
              return files;
            })
            .catch(() => []),
    );
  }
  return commitCache.get(key);
}

async function responseToThread(repo, pr, path, since) {
  const later = pr.commits.nodes
    .map((n) => n.commit)
    .filter((c) => c.committedDate > since);
  const changes = [];
  for (const commit of later) {
    if (changes.length >= MAX_COMMITS_PER_THREAD) break;
    const files = await commitFiles(repo, commit.oid);
    const file = files.find((f) => f.filename === path || f.previous_filename === path);
    if (!file) continue;
    changes.push({
      oid: commit.oid.slice(0, 10),
      date: commit.committedDate,
      message: commit.messageHeadline,
      patch: truncateLines(file.patch ?? '(binary or too large)', MAX_PATCH_LINES),
    });
  }
  return changes;
}

async function buildRecord(repo, number, seen) {
  const pr = await fetchPR(repo, number);
  const prAuthor = pr.author?.login?.toLowerCase();
  const byHuman = (node) => !isBot(node.author) && node.author.login.toLowerCase() !== prAuthor;
  const roleOf = (actor) => (actor?.login?.toLowerCase() === prAuthor ? 'author' : 'reviewer');

  const threads = [];
  for (const t of pr.reviewThreads) {
    const comments = t.comments.nodes.filter((c) => !isBot(c.author));
    const first = comments[0];
    if (!first || !byHuman(first) || isTrivial(first.body)) continue;
    if (reviewers.size && !reviewers.has(first.author.login.toLowerCase())) continue;
    if (pathMatchers.length && !pathMatchers.some((m) => m(t.path))) continue;
    const last = comments.at(-1).createdAt;
    if (!flags.rescan && seen[t.id] === last) continue;
    threads.push({
      id: t.id,
      path: t.path,
      line: t.line ?? t.originalLine,
      startLine: t.startLine,
      isResolved: t.isResolved,
      isOutdated: t.isOutdated,
      url: first.url,
      createdAt: first.createdAt,
      lastCommentAt: last,
      reviewer: first.author.login,
      diffHunk: tailLines(first.diffHunk, 40),
      hasSuggestion: /```suggestion/.test(first.body),
      comments: comments.map((c) => ({
        author: c.author.login,
        role: roleOf(c.author),
        body: truncateChars(c.body, 2000),
        createdAt: c.createdAt,
      })),
      response: await responseToThread(repo, pr, t.path, first.createdAt),
    });
  }

  const reviews = pr.reviews.nodes
    .filter((r) => byHuman(r) && !isTrivial(r.body))
    .filter((r) => !reviewers.size || reviewers.has(r.author.login.toLowerCase()))
    .filter((r) => flags.rescan || !seen[r.id])
    .map((r) => ({
      id: r.id, author: r.author.login, state: r.state, url: r.url,
      createdAt: r.submittedAt, lastCommentAt: r.submittedAt, body: truncateChars(r.body, 3000),
    }));

  const comments = pr.comments.nodes
    .filter((c) => byHuman(c) && !isTrivial(c.body))
    .filter((c) => !reviewers.size || reviewers.has(c.author.login.toLowerCase()))
    .filter((c) => flags.rescan || !seen[c.id])
    .map((c) => ({
      id: c.id, author: c.author.login, url: c.url,
      createdAt: c.createdAt, lastCommentAt: c.createdAt, body: truncateChars(c.body, 3000),
    }));

  if (!threads.length && !reviews.length && !comments.length) return null;
  return {
    repo,
    number: pr.number,
    url: pr.url,
    title: pr.title,
    body: truncateChars(pr.body ?? '', 1500),
    author: pr.author?.login ?? 'ghost',
    baseRefName: pr.baseRefName,
    createdAt: pr.createdAt,
    mergedAt: pr.mergedAt,
    files: pr.files.nodes.map((f) => `${f.path} (+${f.additions}/-${f.deletions})`),
    filesTotal: pr.files.totalCount,
    threads,
    reviews,
    comments,
  };
}

function defaultRepo() {
  try {
    return gh(['repo', 'view', '--json', 'nameWithOwner', '-q', '.nameWithOwner']).trim();
  } catch {
    return null;
  }
}

async function main() {
  ensureStore();
  pruneCache();
  const state = loadState();
  const repos = flags.repo.length ? flags.repo : [defaultRepo()].filter(Boolean);
  if (!repos.length) {
    throw new Error('Not inside a GitHub repo. Pass --repo owner/name or --repo org:name.');
  }

  const scope = repos.map((r) => (r.startsWith('org:') ? r : `repo:${r}`)).join(' ');
  const filterKey = JSON.stringify({
    scope, search: flags.search ?? '', path: flags.path, reviewer: flags.reviewer,
  });
  const runStartedAt = new Date().toISOString();
  const since =
    parseSince(flags._) ??
    state.watermarks[filterKey] ??
    new Date(Date.now() - 30 * 86400e3).toISOString();

  const qualifiers = `${scope} ${flags.search ?? ''}`.trim();
  const q = `is:pr is:merged merged:>=${since.slice(0, 10)} ${qualifiers}`;
  const search = await searchPRs(since, runStartedAt, qualifiers);
  const { hits, capped } = search;
  process.stderr.write(
    `Found ${hits.length} merged PRs${capped ? ` (capped by --limit ${limit}, up to ${search.until})` : ''}. ` +
      'Fetching review threads…\n',
  );

  let done = 0;
  const failed = [];
  const records = (
    await pool(hits, async (hit) => {
      const repo = hit.repository.nameWithOwner;
      try {
        return await buildRecord(repo, hit.number, state.seen);
      } catch (err) {
        failed.push({ pr: `${repo}#${hit.number}`, mergedAt: hit.mergedAt, error: err.message.split('\n')[0] });
        return null;
      } finally {
        if (++done % 10 === 0) process.stderr.write(`  ${done}/${hits.length}\n`);
      }
    })
  ).filter(Boolean);

  // A PR that still failed after retries holds the watermark back to its merge time, so
  // the next run picks it up; the PR cache makes that rerun cheap.
  const until = failed.length
    ? failed.map((f) => f.mergedAt).sort()[0]
    : search.until;

  const file = storePath('raw', `${today()}.jsonl`);
  if (records.length) {
    fs.appendFileSync(file, records.map((r) => JSON.stringify(r)).join('\n') + '\n');
  }

  const ids = {};
  for (const r of records) {
    for (const item of [...r.threads, ...r.reviews, ...r.comments]) ids[item.id] = item.lastCommentAt;
  }
  // Committed to watermarks/seen only after classification (render.mjs --commit), so a
  // failed or abandoned run is fetched again next time.
  state.pending = { file, filterKey, query: q, since, until, ids };
  saveState(state);

  const count = (key) => records.reduce((n, r) => n + r[key].length, 0);
  console.log(
    JSON.stringify(
      {
        store: STORE,
        file: records.length ? file : null,
        query: q,
        since,
        until,
        cappedByLimit: capped,
        failedPRs: failed.length,
        failures: failed.slice(0, 10),
        prsMatched: hits.length,
        prsWithReviewActivity: records.length,
        threads: count('threads'),
        threadsWithFollowUpChange: records.reduce(
          (n, r) => n + r.threads.filter((t) => t.response.length).length,
          0,
        ),
        reviewSummaries: count('reviews'),
        conversationComments: count('comments'),
        newItems: Object.keys(ids).length,
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error(`fetch-reviews: ${err.message}`);
  process.exit(1);
});
