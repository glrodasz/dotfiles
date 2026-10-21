#!/usr/bin/env node
// Join raw items + classifications + rules.json, compute evidence, and regenerate the
// markdown the team-reviewer skill reads. Prints added / changed / removed rules and a diff.
//
// Usage: node render.mjs [--commit] [--force]
//   --commit  mark the pending fetch as processed (advances the watermark in state.json)
//   --force   commit even when some pending items have no classification line
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  CATEGORIES, STORE, ensureStore, gh, loadState, parseFlags, readJson, readJsonlDir, saveState,
  storePath, tailLines, today, truncateLines, writeJson,
} from './lib.mjs';

const DAY = 86400e3;
const STALE_DAYS = 182;
const RECENT_DAYS = 90;
const TOP_N = 15;
const EXAMPLES_PER_RULE = 3;

const flags = parseFlags(process.argv.slice(2), { boolean: ['commit', 'force'] });
ensureStore();
const now = Date.now();
const warnings = [];

// Whose PRs count as "yours" for the per-rule marker; cached so render works offline.
function myLogin() {
  const state = loadState();
  if (state.me) return state.me;
  try {
    state.me = gh(['api', 'user', '-q', '.login']).trim();
    saveState(state);
    return state.me;
  } catch {
    return null;
  }
}
const me = myLogin();

// --- load --------------------------------------------------------------------------------
const items = new Map();
for (const pr of readJsonlDir(storePath('raw'))) {
  const base = { repo: pr.repo, number: pr.number, prUrl: pr.url, title: pr.title, prAuthor: pr.author };
  for (const t of pr.threads) items.set(t.id, { ...base, kind: 'thread', ...t });
  for (const r of pr.reviews) items.set(r.id, { ...base, kind: 'review', reviewer: r.author, ...r });
  for (const c of pr.comments) items.set(c.id, { ...base, kind: 'conversation', reviewer: c.author, ...c });
}

const classifications = new Map();
for (const c of readJsonlDir(storePath('classified'))) classifications.set(c.id, c);

const rulesFile = storePath('rules.json');
const { rules = [] } = readJson(rulesFile, { rules: [] });
const ruleIds = new Set(rules.map((r) => r.id));

for (const c of classifications.values()) {
  if (c.category && !CATEGORIES.includes(c.category)) warnings.push(`${c.id}: unknown category "${c.category}"`);
  if (c.ruleId && !ruleIds.has(c.ruleId)) warnings.push(`${c.id}: ruleId "${c.ruleId}" is not in rules.json`);
  if (!items.has(c.id)) warnings.push(`${c.id}: classified but missing from raw/`);
}
for (const r of rules) {
  if (!CATEGORIES.includes(r.category)) warnings.push(`rule ${r.id}: unknown category "${r.category}"`);
}

// --- evidence ----------------------------------------------------------------------------
const dateOf = (item) => item?.createdAt ?? '';
const byRule = new Map(rules.map((r) => [r.id, { supports: [], contradicts: [] }]));
for (const c of classifications.values()) {
  const bucket = byRule.get(c.ruleId);
  const item = items.get(c.id);
  if (!bucket || !item) continue;
  const entry = { c, item };
  if (c.stance === 'contradicts') bucket.contradicts.push(entry);
  else if (c.stance === 'supports' || c.stance === 'false-positive') bucket.supports.push(entry);
}

const computed = rules.map((rule) => {
  const { supports, contradicts } = byRule.get(rule.id);
  supports.sort((a, b) => dateOf(b.item).localeCompare(dateOf(a.item)));
  const evidence = supports.length;
  const changed = supports.filter((s) => s.c.outcome === 'changed').length;
  const lastSeen = dateOf(supports[0]?.item).slice(0, 10) || null;
  const lastContradicted = contradicts.map((x) => dateOf(x.item)).sort().at(-1)?.slice(0, 10) ?? null;
  const recent = supports.filter((s) => now - Date.parse(dateOf(s.item)) < RECENT_DAYS * DAY).length;
  const isFalsePositive = rule.kind === 'false-positive';
  const admitted = isFalsePositive ? evidence >= 1 : evidence >= 2 || changed >= 1;
  const stale = !!lastSeen && now - Date.parse(lastSeen) > STALE_DAYS * DAY;
  const contradicted =
    !!lastContradicted &&
    now - Date.parse(lastContradicted) < RECENT_DAYS * DAY &&
    lastContradicted >= (lastSeen ?? '');
  const projects = [...new Set(supports.map((s) => s.item.repo))].sort();
  const onMine = me ? supports.filter((s) => s.item.prAuthor === me).length : 0;
  return {
    ...rule, supports, contradicts, evidence, changed, recent, lastSeen, lastContradicted, onMine,
    admitted, stale, contradicted, projects, score: evidence + changed + recent,
  };
});

const statusOf = (r) =>
  r.contradicted
    ? `contradicted by ${r.contradicts.length} thread(s), latest ${r.lastContradicted}`
    : r.stale
      ? `stale: unseen since ${r.lastSeen}`
      : r.contradicts.length
        ? `active (contested ${r.contradicts.length}×, last ${r.lastContradicted})`
        : 'active';

const active = computed.filter((r) => r.admitted && r.kind !== 'false-positive');
const falsePositives = computed.filter((r) => r.admitted && r.kind === 'false-positive');
const candidates = computed.filter((r) => !r.admitted);
const top = active
  .filter((r) => !r.stale && !r.contradicted)
  .sort((a, b) => b.score - a.score || (b.lastSeen ?? '').localeCompare(a.lastSeen ?? ''))
  .slice(0, TOP_N);

// --- markdown ----------------------------------------------------------------------------
const fence = (lang, body) => '```' + lang + '\n' + body.replace(/\n+$/, '') + '\n```';
const beforeAfter = (r) => {
  if (!r.before && !r.after) return '';
  const lines = (text, sign) => (text ?? '').split('\n').filter(Boolean).map((l) => `${sign} ${l}`);
  return fence('diff', [...lines(r.before, '-'), ...lines(r.after, '+')].join('\n'));
};
const evidenceLine = (r) =>
  `**Evidence:** ${r.evidence} (${r.changed} led to a change) · **Last seen:** ${r.lastSeen ?? '—'}` +
  (r.projects.length ? ` · **Projects:** ${r.projects.join(', ')}` : '') +
  (r.onMine ? ` · **On your PRs:** ${r.onMine}` : '');

const reposSeen = [...new Set([...items.values()].map((i) => i.repo))].sort();
const prsSeen = new Set([...items.values()].map((i) => i.prUrl)).size;
const generated =
  `<!-- Generated by harvest-reviews/scripts/render.mjs on ${today()}. Edit rules.json, not this file. -->`;

function renderRules() {
  const out = [
    generated,
    '# Team review rules',
    '',
    `Learned from ${classifications.size} classified review items across ${prsSeen} merged PRs` +
      (reposSeen.length ? ` in ${reposSeen.join(', ')}.` : '.') +
      ` ${active.length} rules, ${candidates.length} candidates waiting for more evidence.`,
  ];
  for (const category of CATEGORIES) {
    const group = active.filter((r) => r.category === category);
    if (!group.length) continue;
    out.push('', `## ${category}`);
    for (const r of group.sort((a, b) => b.score - a.score)) {
      out.push(
        '',
        `### \`${r.id}\` — ${r.rule}`,
        '',
        `- **Why:** ${r.why ?? '—'}`,
        `- ${evidenceLine(r)}`,
        `- **Status:** ${statusOf(r)}`,
        `- **Examples:** [examples/${category}.md](examples/${category}.md#${r.id})`,
      );
      const hunk = beforeAfter(r);
      if (hunk) out.push('', hunk);
    }
  }
  return out.join('\n') + '\n';
}

// One line per rule so a reviewer can scan every rule cheaply and open rules.md only for
// the ones that look relevant.
function renderIndex() {
  const out = [
    generated,
    '# Rule index',
    '',
    `${active.length} rules, strongest first per category. Format: id (evidence×, changed) rule.` +
      ' Details, why and before→after: rules.md. Examples: examples/<category>.md.',
  ];
  for (const category of CATEGORIES) {
    const group = active.filter((r) => r.category === category).sort((a, b) => b.score - a.score);
    if (!group.length) continue;
    out.push('', `## ${category}`, '');
    for (const r of group) {
      const flags = [r.stale && 'stale', r.contradicted && 'contradicted', r.onMine && `${r.onMine}× yours`]
        .filter(Boolean)
        .join(', ');
      out.push(`- \`${r.id}\` (${r.evidence}×, ${r.changed}Δ${flags ? `, ${flags}` : ''}) ${r.rule}`);
    }
  }
  return out.join('\n') + '\n';
}

function renderFalsePositives() {
  const out = [generated, '# Do not flag', '', 'Things reviewers pushed back on or said are fine here.'];
  for (const r of falsePositives) {
    out.push('', `- **\`${r.id}\`** — ${r.rule}${r.why ? ` _${r.why}_` : ''} (${r.evidence}×, last ${r.lastSeen})`);
  }
  if (!falsePositives.length) out.push('', '_None yet._');
  return out.join('\n') + '\n';
}

function renderTop() {
  if (!top.length) return '_No rules learned yet. Run /harvest-reviews to seed them._\n';
  return (
    top
      .map(
        (r, i) =>
          `${i + 1}. **[${r.category}] ${r.rule}** — ${r.why ?? ''} ` +
          `_(\`${r.id}\`, ${r.evidence}× · last ${r.lastSeen}${r.onMine ? ` · ${r.onMine}× on your PRs` : ''})_`,
      )
      .join('\n') + '\n'
  );
}

function renderExample({ c, item }) {
  const where = item.kind === 'thread' ? ` · \`${item.path}:${item.line ?? '?'}\`` : ` · ${item.kind}`;
  const out = [
    `#### ${item.repo}#${item.number}${where} · ${c.outcome ?? '—'} · ${dateOf(item).slice(0, 10)}`,
    '',
    `**@${item.reviewer}** · **${item.repo}** · [link](${item.url})`,
  ];
  if (item.diffHunk) out.push('', '**Code**', '', fence('diff', tailLines(item.diffHunk, 12)));
  const comment = item.kind === 'thread' ? item.comments[0].body : item.body;
  out.push('', '**Comment**', '', comment.split('\n').map((l) => `> ${l}`).join('\n'));
  const fix = item.response?.[0];
  const reply = item.comments?.find((x) => x.role === 'author');
  out.push('', '**Fix**', '');
  if (fix) out.push(`${fix.oid} — ${fix.message}`, '', fence('diff', truncateLines(fix.patch, 30)));
  else if (reply) out.push(`No follow-up change on this file. Author replied: "${reply.body.slice(0, 300)}"`);
  else out.push('No follow-up change on this file.');
  return out.join('\n');
}

function renderExamples(category) {
  const group = [...active, ...falsePositives].filter((r) => r.category === category);
  if (!group.length) return null;
  const out = [generated, `# ${category} — examples`];
  for (const r of group) {
    out.push('', `<a id="${r.id}"></a>`, `## \`${r.id}\` — ${r.rule}`);
    for (const s of r.supports.slice(0, EXAMPLES_PER_RULE)) out.push('', renderExample(s));
  }
  return out.join('\n') + '\n';
}

// --- write + diff ------------------------------------------------------------------------
const previous = readJson(storePath('.render-snapshot.json'), { rules: {} }).rules;
const oldRulesMd = fs.existsSync(storePath('rules.md')) ? fs.readFileSync(storePath('rules.md'), 'utf8') : '';

fs.writeFileSync(storePath('rules.md'), renderRules());
fs.writeFileSync(storePath('index.md'), renderIndex());
fs.writeFileSync(storePath('false-positives.md'), renderFalsePositives());
fs.writeFileSync(storePath('top-rules.md'), renderTop());
for (const f of fs.readdirSync(storePath('examples'))) fs.rmSync(storePath('examples', f));
for (const category of CATEGORIES) {
  const md = renderExamples(category);
  if (md) fs.writeFileSync(storePath('examples', `${category}.md`), md);
}

const snapshot = {};
for (const r of [...active, ...falsePositives]) {
  snapshot[r.id] = {
    rule: r.rule, why: r.why, status: statusOf(r), evidence: r.evidence,
    top: top.indexOf(r) + 1 || null,
  };
}
writeJson(storePath('.render-snapshot.json'), { rules: snapshot });

const added = Object.keys(snapshot).filter((id) => !previous[id]);
const removed = Object.keys(previous).filter((id) => !snapshot[id]);
const changed = Object.keys(snapshot).filter((id) => {
  const a = previous[id];
  const b = snapshot[id];
  return a && (a.rule !== b.rule || a.why !== b.why || a.status !== b.status || a.evidence !== b.evidence || a.top !== b.top);
});

function describeChange(id) {
  const a = previous[id];
  const b = snapshot[id];
  const parts = [];
  if (a.rule !== b.rule) parts.push(`reworded: "${a.rule}" → "${b.rule}"`);
  if (a.why !== b.why) parts.push('why updated');
  if (a.evidence !== b.evidence) parts.push(`evidence ${a.evidence} → ${b.evidence}`);
  if (a.status !== b.status) parts.push(`status ${a.status} → ${b.status}`);
  if (a.top !== b.top) parts.push(`top-15 rank ${a.top ?? '—'} → ${b.top ?? '—'}`);
  return `- \`${id}\`: ${parts.join('; ')}`;
}

let diff = '';
const tmp = path.join(os.tmpdir(), `rules-before-${process.pid}.md`);
fs.writeFileSync(tmp, oldRulesMd);
try {
  execFileSync('diff', ['-u', '--label', 'rules.md (before)', '--label', 'rules.md (after)', tmp, storePath('rules.md')], { encoding: 'utf8' });
} catch (err) {
  diff = err.stdout ?? '';
} finally {
  fs.rmSync(tmp, { force: true });
}

// --- commit state ------------------------------------------------------------------------
let commitNote = '';
if (flags.commit) {
  const state = loadState();
  const pending = state.pending;
  if (!pending) {
    commitNote = 'Nothing pending to commit.';
  } else {
    const missing = Object.keys(pending.ids).filter((id) => !classifications.has(id));
    if (missing.length && !flags.force) {
      commitNote = `NOT committed: ${missing.length} pending item(s) have no classification ` +
        `(first: ${missing.slice(0, 5).join(', ')}). Classify them or rerun with --force.`;
    } else {
      state.watermarks[pending.filterKey] = pending.until;
      Object.assign(state.seen, pending.ids);
      state.runs.push({
        at: new Date().toISOString(), query: pending.query, since: pending.since,
        items: Object.keys(pending.ids).length, unclassified: missing.length,
      });
      state.pending = null;
      saveState(state);
      commitNote = `Committed: watermark for this filter set to ${pending.until}.`;
    }
  }
}

// --- report ------------------------------------------------------------------------------
const list = (ids, fmt) => (ids.length ? ids.map(fmt).join('\n') : '- none');
console.log(`Store: ${STORE}
Rules: ${active.length} active · ${falsePositives.length} do-not-flag · ${candidates.length} candidates · top ${top.length}

### Added
${list(added, (id) => `- \`${id}\` — ${snapshot[id].rule}`)}

### Changed
${list(changed, describeChange)}

### Removed
${list(removed, (id) => `- \`${id}\` — ${previous[id].rule}`)}
${warnings.length ? `\n### Warnings\n${warnings.map((w) => `- ${w}`).join('\n')}\n` : ''}
${commitNote ? `\n${commitNote}\n` : ''}
### rules.md diff
${diff ? fence('diff', diff) : '_No change._'}`);
