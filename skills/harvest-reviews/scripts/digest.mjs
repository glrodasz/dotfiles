#!/usr/bin/env node
// Print the pending fetch (or a given raw file) as compact, numbered items to classify.
//
// Usage: node digest.mjs [raw-file] [--offset 0] [--limit 40]
// The item ids printed here are the keys classified/<date>.jsonl lines must use.
import { loadState, parseFlags, readJsonl, tailLines, truncateChars, truncateLines } from './lib.mjs';

const flags = parseFlags(process.argv.slice(2));
const file = flags._[0] ?? loadState().pending?.file;
if (!file) {
  console.error('digest: no pending fetch. Run fetch-reviews.mjs first or pass a raw file.');
  process.exit(1);
}
const offset = Number(flags.offset ?? 0);
const limit = Number(flags.limit ?? 40);

const items = [];
for (const pr of readJsonl(file)) {
  const header = `${pr.repo}#${pr.number} "${pr.title}" by ${pr.author}`;
  for (const t of pr.threads) items.push({ kind: 'thread', pr, header, ...t });
  for (const r of pr.reviews) items.push({ kind: `review ${r.state}`, pr, header, ...r });
  for (const c of pr.comments) items.push({ kind: 'conversation', pr, header, ...c });
}

const slice = items.slice(offset, offset + limit);
console.log(`# Items ${offset + 1}–${offset + slice.length} of ${items.length} from ${file}\n`);

for (const [i, item] of slice.entries()) {
  console.log(`## ${offset + i + 1}. id=${item.id}`);
  console.log(`${item.kind} · ${item.header} · ${item.createdAt.slice(0, 10)}`);
  if (item.kind === 'thread') {
    const flagsText = [
      item.isResolved && 'resolved',
      item.isOutdated && 'outdated',
      item.hasSuggestion && 'suggestion',
      item.response.length && `${item.response.length} follow-up commit(s) on this file`,
    ].filter(Boolean);
    console.log(`\`${item.path}:${item.line ?? '?'}\` ${flagsText.join(' · ')}`);
    console.log('```diff\n' + tailLines(item.diffHunk ?? '', 15) + '\n```');
    for (const c of item.comments) {
      console.log(`- [${c.role}] ${truncateChars(c.body.replace(/\s+/g, ' '), 600)}`);
    }
    if (item.response.length) {
      const r = item.response[0];
      console.log(`Follow-up ${r.oid} "${r.message}":`);
      console.log('```diff\n' + truncateLines(r.patch, 25) + '\n```');
    }
  } else {
    console.log(`- [${item.author === item.pr.author ? 'author' : 'reviewer'}] ` +
      truncateChars(item.body.replace(/\s+/g, ' '), 800));
  }
  console.log();
}

if (offset + slice.length < items.length) {
  console.log(`Next batch: --offset ${offset + slice.length} --limit ${limit}`);
}
