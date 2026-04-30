import semver from 'semver';
import type { ChangelogOutput, CommitInfo, PrInfo } from './types.js';

export type Bump = 'major' | 'minor' | 'patch';

const BREAKING_RE = /\bBREAKING[ -]CHANGE\b|!:/i;

export function heuristicBump(commits: CommitInfo[], prs: PrInfo[]): Bump {
  const haystack =
    commits.map((c) => `${c.message}\n${c.body}`).join('\n') +
    '\n' +
    prs.map((p) => `${p.title}\n${p.body}`).join('\n');

  if (BREAKING_RE.test(haystack)) return 'major';
  if (/\b(feat|feature|add(ed)?)\b/i.test(haystack)) return 'minor';
  return 'patch';
}

export function reconcileBump(llm: Bump, heuristic: Bump): Bump {
  const order: Bump[] = ['patch', 'minor', 'major'];
  const pick = Math.max(order.indexOf(llm), order.indexOf(heuristic));
  return order[pick] ?? 'patch';
}

export function nextVersion(current: string | null, bump: Bump): string {
  const base = current && semver.valid(semver.coerce(current)) ? semver.coerce(current)!.version : '0.0.0';
  return semver.inc(base, bump) ?? '0.0.0';
}

export function finalBump(output: ChangelogOutput, commits: CommitInfo[], prs: PrInfo[]): Bump {
  return reconcileBump(output.bump, heuristicBump(commits, prs));
}
