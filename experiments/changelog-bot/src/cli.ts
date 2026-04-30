#!/usr/bin/env node
import { Command } from 'commander';
import { writeFileSync } from 'node:fs';
import { GitSource, extractPrNumbers } from './git.js';
import { GitHubSource } from './github.js';
import { generateChangelog, resolveProvider, defaultModel } from './llm.js';
import { finalBump, heuristicBump, nextVersion } from './semver.js';
import { renderChangelog, renderDryRun } from './render.js';
import type { LlmInput, Provider } from './types.js';

interface CliOptions {
  from?: string;
  to: string;
  output?: string;
  provider?: Provider;
  model?: string;
  bump?: boolean;
  dryRun?: boolean;
  repo?: string;
  githubToken?: string;
}

const program = new Command();

program
  .name('changelog-bot')
  .description('AI-powered CHANGELOG generation without Conventional Commits (BYOK)')
  .version('0.1.0')
  .option('--from <ref>', 'starting ref (default: latest tag)')
  .option('--to <ref>', 'ending ref', 'HEAD')
  .option('--output <file>', 'write changelog to file (default: stdout)')
  .option('--provider <p>', 'anthropic | openai (default: auto from env)')
  .option('--model <name>', 'model name (default: claude-haiku-4-5)')
  .option('--bump', 'print suggested SemVer bump only')
  .option('--dry-run', 'show git/PR data without calling LLM')
  .option('--repo <slug>', 'GitHub repo (owner/name); default: origin remote')
  .option('--github-token <token>', 'GitHub token (default: GITHUB_TOKEN env)')
  .action(async (opts: CliOptions) => {
    try {
      await run(opts);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`changelog-bot: ${msg}`);
      process.exit(1);
    }
  });

async function run(opts: CliOptions): Promise<void> {
  const git = new GitSource();
  const fromRef = opts.from ?? (await git.resolveLatestTag());
  const toRef = opts.to;

  const commits = await git.getCommits(fromRef, toRef);
  if (commits.length === 0) {
    console.error(`changelog-bot: no commits between ${fromRef ?? 'root'}..${toRef}`);
    process.exit(0);
  }

  const prNumbers = extractPrNumbers(commits);
  const slug = opts.repo ?? (await git.getRemoteSlug());
  const token = opts.githubToken ?? process.env.GITHUB_TOKEN;

  let prs: Awaited<ReturnType<GitHubSource['fetchPrs']>> = [];
  let issues: Awaited<ReturnType<GitHubSource['fetchIssues']>> = [];
  if (slug && token && prNumbers.length > 0) {
    const gh = new GitHubSource(slug, token);
    prs = await gh.fetchPrs(prNumbers);
    const issueRefs = prNumbers.filter((n) => !prs.some((p) => p.number === n));
    issues = await gh.fetchIssues(issueRefs);
  }

  if (opts.dryRun) {
    const text = renderDryRun(commits, prs, fromRef ?? 'root', toRef);
    writeOutput(text, opts.output);
    return;
  }

  if (opts.bump) {
    const b = heuristicBump(commits, prs);
    writeOutput(b, opts.output);
    return;
  }

  const { provider, apiKey } = resolveProvider(opts.provider);
  const model = opts.model ?? defaultModel(provider);

  const input: LlmInput = {
    commits,
    prs,
    issues,
    from_ref: fromRef ?? 'root',
    to_ref: toRef,
  };

  const output = await generateChangelog(input, { provider, model, apiKey });
  const bump = finalBump(output, commits, prs);
  const version = nextVersion(fromRef, bump);
  const md = renderChangelog(output, { version, bump });
  writeOutput(md, opts.output);
}

function writeOutput(text: string, file?: string): void {
  if (file) {
    writeFileSync(file, text.endsWith('\n') ? text : text + '\n', 'utf8');
    console.error(`changelog-bot: wrote ${file}`);
  } else {
    process.stdout.write(text.endsWith('\n') ? text : text + '\n');
  }
}

program.parseAsync(process.argv);
