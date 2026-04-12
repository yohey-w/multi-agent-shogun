import { z } from 'zod';

export const ChangelogOutputSchema = z.object({
  sections: z.object({
    added: z.array(z.string()).default([]),
    changed: z.array(z.string()).default([]),
    fixed: z.array(z.string()).default([]),
    removed: z.array(z.string()).default([]),
    deprecated: z.array(z.string()).default([]),
    security: z.array(z.string()).default([]),
  }),
  bump: z.enum(['major', 'minor', 'patch']),
  breaking_notes: z.array(z.string()).default([]),
});

export type ChangelogOutput = z.infer<typeof ChangelogOutputSchema>;

export interface CommitInfo {
  sha: string;
  message: string;
  body: string;
  author?: string;
  date?: string;
}

export interface PrInfo {
  number: number;
  title: string;
  body: string;
  labels?: string[];
}

export interface IssueInfo {
  number: number;
  title: string;
  body: string;
}

export interface LlmInput {
  commits: CommitInfo[];
  prs: PrInfo[];
  issues: IssueInfo[];
  from_ref: string;
  to_ref: string;
}

export type Provider = 'anthropic' | 'openai';

export interface LlmOptions {
  provider: Provider;
  model: string;
  apiKey: string;
}
