// Shared helpers for the harvest-reviews scripts. Zero dependencies.
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fs.realpathSync(fileURLToPath(import.meta.url)));

// The store is per computer and gitignored: it lives next to the team-reviewer skill so
// that skill can read it without knowing where harvest-reviews is installed.
export const STORE = path.resolve(
  process.env.REVIEW_HARVEST_DIR || path.join(HERE, '../../team-reviewer/.review-harvest'),
);

export const CATEGORIES = [
  'correctness', 'security', 'perf', 'architecture', 'naming',
  'tests', 'a11y', 'types', 'dx', 'style',
];

export function storePath(...parts) {
  return path.join(STORE, ...parts);
}

export function ensureStore() {
  for (const dir of ['raw', 'classified', 'examples']) {
    fs.mkdirSync(storePath(dir), { recursive: true });
  }
}

export function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch {
    return fallback;
  }
}

export function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n');
}

export function readJsonl(file) {
  if (!fs.existsSync(file)) return [];
  return fs
    .readFileSync(file, 'utf8')
    .split('\n')
    .filter((line) => line.trim())
    .map((line, i) => {
      try {
        return JSON.parse(line);
      } catch {
        throw new Error(`${file}:${i + 1} is not valid JSON`);
      }
    });
}

export function readJsonlDir(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.jsonl'))
    .sort()
    .flatMap((f) => readJsonl(path.join(dir, f)));
}

export function loadState() {
  return readJson(storePath('state.json'), { watermarks: {}, seen: {}, runs: [], pending: null });
}

export function saveState(state) {
  writeJson(storePath('state.json'), state);
}

export function gh(args, input) {
  return execFileSync('gh', args, {
    input,
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
    stdio: ['pipe', 'pipe', 'pipe'],
  });
}

export function today() {
  return new Date().toISOString().slice(0, 10);
}

export function truncateLines(text, maxLines) {
  if (!text) return text;
  const lines = text.split('\n');
  if (lines.length <= maxLines) return text;
  return [...lines.slice(0, maxLines), `… (${lines.length - maxLines} more lines)`].join('\n');
}

export function truncateChars(text, max) {
  if (!text || text.length <= max) return text;
  return text.slice(0, max) + ` … (${text.length - max} more chars)`;
}

export function parseFlags(argv, { repeatable = [], boolean = [] } = {}) {
  const flags = { _: [] };
  for (const key of repeatable) flags[key] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith('--')) {
      flags._.push(arg);
      continue;
    }
    const [rawKey, inline] = arg.slice(2).split(/=(.*)/s);
    if (boolean.includes(rawKey)) {
      flags[rawKey] = true;
      continue;
    }
    const value = inline ?? argv[++i];
    if (value === undefined) throw new Error(`--${rawKey} needs a value`);
    if (repeatable.includes(rawKey)) flags[rawKey].push(value);
    else flags[rawKey] = value;
  }
  return flags;
}

// Review comments anchor to the last line of their diff hunk, so keep the tail.
export function tailLines(text, maxLines) {
  if (!text) return text;
  const lines = text.split('\n');
  if (lines.length <= maxLines) return text;
  return [lines[0], `… (${lines.length - maxLines} lines above)`, ...lines.slice(-maxLines)].join('\n');
}
