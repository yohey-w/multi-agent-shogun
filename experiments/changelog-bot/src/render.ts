import type { ChangelogOutput } from './types.js';
import type { Bump } from './semver.js';

interface RenderOptions {
  version: string;
  date?: string;
  bump: Bump;
}

export function renderChangelog(output: ChangelogOutput, opts: RenderOptions): string {
  const date = opts.date ?? new Date().toISOString().slice(0, 10);
  const lines: string[] = [];
  lines.push(`## [${opts.version}] - ${date}`);
  lines.push('');

  const sectionOrder: Array<[keyof ChangelogOutput['sections'], string]> = [
    ['added', 'Added'],
    ['changed', 'Changed'],
    ['fixed', 'Fixed'],
    ['removed', 'Removed'],
    ['deprecated', 'Deprecated'],
    ['security', 'Security'],
  ];

  for (const [key, label] of sectionOrder) {
    const items = output.sections[key];
    if (!items || items.length === 0) continue;
    lines.push(`### ${label}`);
    for (const it of items) lines.push(`- ${it}`);
    lines.push('');
  }

  if (output.breaking_notes.length > 0) {
    lines.push('### ⚠ BREAKING CHANGES');
    for (const n of output.breaking_notes) lines.push(`- ${n}`);
    lines.push('');
  }

  lines.push(`**Suggested bump**: ${opts.bump}`);
  lines.push('');
  return lines.join('\n');
}

export function renderDryRun(
  commits: { sha: string; message: string }[],
  prs: { number: number; title: string }[],
  fromRef: string,
  toRef: string,
): string {
  const lines: string[] = [];
  lines.push(`# ChangelogBot dry-run`);
  lines.push(`Range: ${fromRef}..${toRef}`);
  lines.push('');
  lines.push(`## Commits (${commits.length})`);
  for (const c of commits) lines.push(`- ${c.sha} ${c.message}`);
  lines.push('');
  lines.push(`## PRs (${prs.length})`);
  for (const p of prs) lines.push(`- #${p.number} ${p.title}`);
  return lines.join('\n');
}
