import { describe, it, expect, vi, beforeEach } from 'vitest';

/**
 * Smoke test for ChangelogBot.
 *
 * Contract with src/ (implemented by ashigaru1):
 *   - src/render.ts exports `renderChangelog(structured, meta): string`
 *   - src/llm.ts    exports `generateChangelog(input, opts): Promise<Structured>`
 *   - src/git.ts    exports `collectCommits({ from, to, cwd }): Promise<Commit[]>`
 *
 * If any of these imports fail at runtime the test is marked failing (not
 * skipped) per project "SKIP = FAIL" rule. Once ashigaru1 lands the CLI, this
 * file should pass as-is.
 */

type Structured = {
  sections: {
    added: string[];
    changed: string[];
    fixed: string[];
    removed?: string[];
    deprecated?: string[];
    security?: string[];
  };
  bump: 'major' | 'minor' | 'patch';
  breaking_notes: string[];
};

const GIT_LOG_FIXTURE = [
  {
    sha: 'aaaaaaa',
    message: 'feat: add Whisper fallback for audio pipeline',
    body: 'Closes #123. Falls back to Whisper when Vosk fails.',
  },
  {
    sha: 'bbbbbbb',
    message: 'fix: Ollama WebP encode 500 error',
    body: 'Encode as PNG when WebP is not supported. Fixes #128.',
  },
  {
    sha: 'ccccccc',
    message: 'chore: bump deps',
    body: '',
  },
];

const LLM_FIXTURE: Structured = {
  sections: {
    added: ['Audio pipeline falls back to Whisper when Vosk fails (#123)'],
    changed: [],
    fixed: ['Ollama WebP encode 500 error by re-encoding as PNG (#128)'],
  },
  bump: 'minor',
  breaking_notes: [],
};

describe('ChangelogBot smoke', () => {
  beforeEach(() => vi.resetModules());

  it('renders Keep-a-Changelog sections from a structured LLM response', async () => {
    let render: (s: Structured, meta: { from: string; to: string; date: string }) => string;
    try {
      ({ renderChangelog: render } = await import('../src/render'));
    } catch (e) {
      throw new Error(
        `src/render.ts not available yet — ashigaru1 CLI implementation required. Underlying: ${(e as Error).message}`,
      );
    }

    const md = render(LLM_FIXTURE, { from: 'v0.1.0', to: 'HEAD', date: '2026-04-12' });

    expect(md).toMatch(/### Added/);
    expect(md).toMatch(/### Fixed/);
    expect(md).toMatch(/Whisper fallback|Whisper/);
    expect(md).toMatch(/Ollama/);
    expect(md).toMatch(/Suggested bump.*minor/i);
  });

  it('collects commits between refs without calling the LLM (--dry-run path)', async () => {
    let collectCommits: (opts: { from: string; to: string; cwd?: string }) => Promise<unknown[]>;
    try {
      ({ collectCommits } = await import('../src/git'));
    } catch (e) {
      throw new Error(
        `src/git.ts not available yet — ashigaru1 CLI implementation required. Underlying: ${(e as Error).message}`,
      );
    }

    // Use the multi-agent-shogun repo itself as a real git fixture.
    const commits = await collectCommits({ from: 'HEAD~3', to: 'HEAD' });
    expect(Array.isArray(commits)).toBe(true);
    expect(commits.length).toBeGreaterThan(0);
  });

  it('mocks the LLM call and never hits the real API', async () => {
    vi.doMock('@anthropic-ai/sdk', () => {
      return {
        default: class {
          messages = {
            create: vi.fn(async () => ({
              content: [{ type: 'text', text: JSON.stringify(LLM_FIXTURE) }],
            })),
          };
        },
      };
    });
    vi.doMock('openai', () => {
      return {
        default: class {
          chat = {
            completions: {
              create: vi.fn(async () => ({
                choices: [{ message: { content: JSON.stringify(LLM_FIXTURE) } }],
              })),
            },
          };
        },
      };
    });

    let generateChangelog: (
      input: { commits: typeof GIT_LOG_FIXTURE; prs: []; issues: []; from_ref: string; to_ref: string },
      opts: { provider: 'anthropic' | 'openai'; model?: string; apiKey: string },
    ) => Promise<Structured>;
    try {
      ({ generateChangelog } = await import('../src/llm'));
    } catch (e) {
      throw new Error(
        `src/llm.ts not available yet — ashigaru1 CLI implementation required. Underlying: ${(e as Error).message}`,
      );
    }

    const out = await generateChangelog(
      { commits: GIT_LOG_FIXTURE, prs: [], issues: [], from_ref: 'v0.1.0', to_ref: 'HEAD' },
      { provider: 'anthropic', apiKey: 'test-key-not-real' },
    );

    expect(['major', 'minor', 'patch']).toContain(out.bump);
    expect(out.sections.added.length + out.sections.fixed.length).toBeGreaterThan(0);
  });
});
