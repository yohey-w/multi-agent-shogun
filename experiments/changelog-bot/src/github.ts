import { graphql } from '@octokit/graphql';
import type { PrInfo, IssueInfo } from './types.js';

type GraphqlFn = typeof graphql;

interface NodeResponse {
  repository: Record<
    string,
    {
      number: number;
      title: string;
      body: string | null;
      labels?: { nodes: { name: string }[] };
    } | null
  > | null;
}

export class GitHubSource {
  private client: GraphqlFn;
  private owner: string;
  private repo: string;

  constructor(slug: string, token: string) {
    const [owner, repo] = slug.split('/');
    if (!owner || !repo) {
      throw new Error(`Invalid repo slug: ${slug} (expected owner/repo)`);
    }
    this.owner = owner;
    this.repo = repo;
    this.client = graphql.defaults({
      headers: { authorization: `token ${token}` },
    });
  }

  async fetchPrs(numbers: number[]): Promise<PrInfo[]> {
    if (numbers.length === 0) return [];
    const results: PrInfo[] = [];
    for (const part of chunk(numbers, 20)) {
      const query = buildRepoQuery(part, 'pullRequest');
      try {
        const data = await this.client<NodeResponse>(query, {
          owner: this.owner,
          repo: this.repo,
        });
        const nodes = data.repository ?? {};
        for (const node of Object.values(nodes)) {
          if (!node) continue;
          results.push({
            number: node.number,
            title: node.title,
            body: node.body ?? '',
            labels: node.labels?.nodes.map((n) => n.name),
          });
        }
      } catch {
        // individual batch may fail if numbers mix PR/Issue; ignore and continue
      }
    }
    return results;
  }

  async fetchIssues(numbers: number[]): Promise<IssueInfo[]> {
    if (numbers.length === 0) return [];
    const results: IssueInfo[] = [];
    for (const part of chunk(numbers, 20)) {
      const query = buildRepoQuery(part, 'issue');
      try {
        const data = await this.client<NodeResponse>(query, {
          owner: this.owner,
          repo: this.repo,
        });
        const nodes = data.repository ?? {};
        for (const node of Object.values(nodes)) {
          if (!node) continue;
          results.push({
            number: node.number,
            title: node.title,
            body: node.body ?? '',
          });
        }
      } catch {
        // ignore
      }
    }
    return results;
  }
}

export function buildRepoQuery(
  numbers: number[],
  kind: 'pullRequest' | 'issue',
): string {
  const fields = numbers
    .map(
      (n) => `
    n${n}: ${kind}(number: ${n}) {
      number
      title
      body
      ${kind === 'pullRequest' ? 'labels(first: 20) { nodes { name } }' : ''}
    }`,
    )
    .join('\n');
  return `query($owner: String!, $repo: String!) {
  repository(owner: $owner, name: $repo) {${fields}
  }
}`;
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}
