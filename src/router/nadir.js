/**
 * NadirClaw Proxy — Intelligent model router.
 *
 * Classifies incoming prompts by complexity and routes them to the
 * cheapest model capable of handling them:
 *   - Low complexity  → MODEL_CHEAP  (Gemini Flash 1.5-8B or similar)
 *   - High complexity → MODEL_SMART  (Claude 3.5 Sonnet)
 *
 * All calls are forwarded to OpenRouter, which provides a single
 * OpenAI-compatible endpoint for all upstream providers.
 */

import OpenAI from "openai";

const COMPLEXITY_THRESHOLD = parseInt(
  process.env.NADIR_COMPLEXITY_THRESHOLD ?? "60",
  10
);
const MODEL_CHEAP = process.env.MODEL_CHEAP ?? "google/gemini-flash-1.5-8b";
const MODEL_SMART =
  process.env.MODEL_SMART ?? "anthropic/claude-3.5-sonnet";

const openrouter = new OpenAI({
  baseURL: "https://openrouter.ai/api/v1",
  apiKey: process.env.OPENROUTER_API_KEY,
  defaultHeaders: {
    "HTTP-Referer": "https://github.com/personal-os",
    "X-Title": "Personal AI OS",
  },
});

/**
 * Heuristic complexity scorer (0–100).
 *
 * Uses lightweight signals so the classification itself costs nothing:
 *  - Prompt length
 *  - Presence of reasoning/analysis keywords
 *  - Multi-step indicators (numbered lists, "compare", "explain why")
 *  - Code-generation signals
 */
function scoreComplexity(prompt) {
  let score = 0;

  // Length signal (longer prompts tend to be harder)
  const words = prompt.split(/\s+/).length;
  score += Math.min(words / 5, 20); // up to 20 pts

  // Reasoning keywords
  const reasoningKeywords =
    /\b(analyze|compare|explain|reason|why|how|evaluate|summarize|plan|strategy|recommend|diagnose|debug|optimize)\b/gi;
  const reasoningMatches = (prompt.match(reasoningKeywords) ?? []).length;
  score += Math.min(reasoningMatches * 8, 32); // up to 32 pts

  // Multi-step / structured output signals
  const multiStepSignals = /(\d+\.\s|\bbullet\b|\bstep\b|\blist\b|\bpros and cons\b)/gi;
  score += (prompt.match(multiStepSignals) ?? []).length * 5; // 5 pts each

  // Code signals
  const codeSignals = /\b(code|function|script|implement|write a|create a|build)\b/gi;
  score += Math.min((prompt.match(codeSignals) ?? []).length * 10, 20); // up to 20 pts

  return Math.min(Math.round(score), 100);
}

/**
 * Route and execute a chat completion.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {{ forceModel?: string, stream?: boolean }} options
 * @returns {Promise<string>} The assistant reply text
 */
export async function chat(messages, options = {}) {
  const lastUserMessage =
    [...messages].reverse().find((m) => m.role === "user")?.content ?? "";

  const complexity = scoreComplexity(lastUserMessage);
  const model =
    options.forceModel ??
    (complexity >= COMPLEXITY_THRESHOLD ? MODEL_SMART : MODEL_CHEAP);

  console.log(
    `[NadirClaw] complexity=${complexity} threshold=${COMPLEXITY_THRESHOLD} → ${model}`
  );

  const response = await openrouter.chat.completions.create({
    model,
    messages,
    stream: false,
  });

  const reply = response.choices[0]?.message?.content ?? "";
  return reply;
}

/**
 * Estimate token count (rough: 1 token ≈ 4 chars).
 */
export function estimateTokens(messages) {
  const totalChars = messages.reduce(
    (sum, m) => sum + (m.content?.length ?? 0),
    0
  );
  return Math.ceil(totalChars / 4);
}

export { scoreComplexity, MODEL_CHEAP, MODEL_SMART };
