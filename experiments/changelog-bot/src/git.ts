import { simpleGit, SimpleGit } from 'simple-git';
import type { CommitInfo } from './types.js';

export class GitSource {
  private git: SimpleGit;

  constructor(cwd: string = process.cwd()) {
    this.git = simpleGit(cwd);
  }

  async resolveLatestTag(): Promise<string | null> {
    try {
      const tags = await this.git.tags(['--sort=-creatordate']);
      return tags.all[0] ?? null;
    } catch {
      return null;
    }
  }

  async getCommits(from: string | null, to: string): Promise<CommitInfo[]> {
    const range = from ? `${from}..${to}` : to;
    const log = await this.git.log([range, '--no-merges']);
    return log.all.map((c) => ({
      sha: c.hash.slice(0, 7),
      message: c.message,
      body: c.body ?? '',
      author: c.author_name,
      date: c.date,
    }));
  }

  async getRemoteSlug(): Promise<string | null> {
    try {
      const remotes = await this.git.getRemotes(true);
      const origin = remotes.find((r) => r.name === 'origin');
      if (!origin) return null;
      const url = origin.refs.fetch ?? origin.refs.push;
      return parseRemoteSlug(url);
    } catch {
      return null;
    }
  }
}

export function parseRemoteSlug(url: string): string | null {
  const m =
    url.match(/github\.com[:/]([^/]+)\/([^/.]+)(?:\.git)?$/) ??
    url.match(/^([^/]+)\/([^/]+)$/);
  if (!m) return null;
  return `${m[1]}/${m[2].replace(/\.git$/, '')}`;
}

export function extractPrNumbers(commits: CommitInfo[]): number[] {
  const nums = new Set<number>();
  for (const c of commits) {
    const text = `${c.message}\n${c.body}`;
    for (const m of text.matchAll(/#(\d+)/g)) {
      nums.add(Number(m[1]));
    }
    const squash = c.message.match(/\(#(\d+)\)$/);
    if (squash) nums.add(Number(squash[1]));
  }
  return [...nums];
}
