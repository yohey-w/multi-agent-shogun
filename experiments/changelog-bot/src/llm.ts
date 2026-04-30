import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';
import {
  ChangelogOutputSchema,
  type ChangelogOutput,
  type LlmInput,
  type LlmOptions,
  type Provider,
} from './types.js';

const SYSTEM_PROMPT = `You are a release note generator. Given raw git commit messages, PR titles/bodies, and optional issue bodies, produce a user-facing CHANGELOG section in Keep-a-Changelog format (Added/Changed/Fixed/Removed/Deprecated/Security). Also suggest a SemVer bump (major/minor/patch) based on breaking-change heuristics. Never fabricate features not present in the input. Write in the same language as the majority of input (ja if >50% Japanese).

Respond ONLY with valid JSON matching this schema, no prose:
{
  "sections": {
    "added":      string[],
    "changed":    string[],
    "fixed":      string[],
    "removed":    string[],
    "deprecated": string[],
    "security":   string[]
  },
  "bump": "major" | "minor" | "patch",
  "breaking_notes": string[]
}`;

export function resolveProvider(explicit?: Provider): { provider: Provider; apiKey: string } {
  if (explicit === 'anthropic') {
    const k = process.env.ANTHROPIC_API_KEY;
    if (!k) throw new Error('ANTHROPIC_API_KEY is not set. See README for BYOK setup.');
    return { provider: 'anthropic', apiKey: k };
  }
  if (explicit === 'openai') {
    const k = process.env.OPENAI_API_KEY;
    if (!k) throw new Error('OPENAI_API_KEY is not set. See README for BYOK setup.');
    return { provider: 'openai', apiKey: k };
  }
  if (process.env.ANTHROPIC_API_KEY) {
    return { provider: 'anthropic', apiKey: process.env.ANTHROPIC_API_KEY };
  }
  if (process.env.OPENAI_API_KEY) {
    return { provider: 'openai', apiKey: process.env.OPENAI_API_KEY };
  }
  throw new Error(
    'No API key found. Set ANTHROPIC_API_KEY or OPENAI_API_KEY. See README for BYOK setup.',
  );
}

export function defaultModel(provider: Provider): string {
  return provider === 'anthropic' ? 'claude-haiku-4-5' : 'gpt-4o-mini';
}

export async function generateChangelog(
  input: LlmInput,
  opts: LlmOptions,
): Promise<ChangelogOutput> {
  const userJson = JSON.stringify(input, null, 2);
  let lastErr: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const raw =
        opts.provider === 'anthropic'
          ? await callAnthropic(userJson, opts)
          : await callOpenAI(userJson, opts);
      const parsed = extractJson(raw);
      return ChangelogOutputSchema.parse(parsed);
    } catch (e) {
      lastErr = e;
    }
  }
  throw new Error(
    `LLM output validation failed after retry: ${lastErr instanceof Error ? lastErr.message : String(lastErr)}`,
  );
}

async function callAnthropic(user: string, opts: LlmOptions): Promise<string> {
  const client = new Anthropic({ apiKey: opts.apiKey });
  const res = await client.messages.create({
    model: opts.model,
    max_tokens: 4096,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: user }],
  });
  const block = res.content.find((b) => b.type === 'text');
  if (!block || block.type !== 'text') throw new Error('Anthropic returned no text');
  return block.text;
}

async function callOpenAI(user: string, opts: LlmOptions): Promise<string> {
  const client = new OpenAI({ apiKey: opts.apiKey });
  const res = await client.chat.completions.create({
    model: opts.model,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      { role: 'user', content: user },
    ],
    response_format: { type: 'json_object' },
  });
  const text = res.choices[0]?.message?.content;
  if (!text) throw new Error('OpenAI returned no text');
  return text;
}

function extractJson(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const body = fenced ? fenced[1] : text;
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('No JSON object in LLM output');
  return JSON.parse(body.slice(start, end + 1));
}
