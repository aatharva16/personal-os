/**
 * BaseAgent — shared scaffolding for all Personal AI OS agents.
 *
 * Each concrete agent lives in its own folder under agents/ and carries:
 *  - SOUL.md   — immutable personality & behavioral constraints
 *  - MEMORY.md — persistent, evolving knowledge (written back after sessions)
 *
 * The base class handles:
 *  - Loading / saving SOUL and MEMORY from disk
 *  - Building the system prompt (SOUL + MEMORY injected)
 *  - Managing the in-session message history
 *  - Triggering context compaction when the token budget is exceeded
 */

import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { chat, estimateTokens } from "../router/nadir.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const COMPACTION_THRESHOLD = parseInt(
  process.env.MEMORY_COMPACTION_THRESHOLD ?? "8000",
  10
);

export class BaseAgent {
  /**
   * @param {string} name  - Folder name under src/agents/ (e.g. "health")
   */
  constructor(name) {
    this.name = name;
    this.agentDir = path.join(__dirname, name);
    this.soul = "";
    this.memory = "";
    /** @type {Array<{role: string, content: string}>} */
    this.history = [];
  }

  async load() {
    const [soul, memory] = await Promise.all([
      fs
        .readFile(path.join(this.agentDir, "SOUL.md"), "utf8")
        .catch(() => ""),
      fs
        .readFile(path.join(this.agentDir, "MEMORY.md"), "utf8")
        .catch(() => ""),
    ]);
    this.soul = soul.trim();
    this.memory = memory.trim();
  }

  /** Persist updated memory back to disk. */
  async saveMemory(newMemory) {
    this.memory = newMemory.trim();
    await fs.writeFile(
      path.join(this.agentDir, "MEMORY.md"),
      this.memory + "\n"
    );
  }

  /** Full system prompt: personality + current memory snapshot. */
  get systemPrompt() {
    let prompt = this.soul;
    if (this.memory) {
      prompt += `\n\n---\n## Persistent Memory\n${this.memory}`;
    }
    return prompt;
  }

  /** All messages the router will see, including the system prompt. */
  get messages() {
    return [
      { role: "system", content: this.systemPrompt },
      ...this.history,
    ];
  }

  /**
   * Send a user message and return the assistant reply.
   * Automatically compacts context when token budget is exceeded.
   */
  async send(userText, { forceModel } = {}) {
    this.history.push({ role: "user", content: userText });

    if (estimateTokens(this.messages) > COMPACTION_THRESHOLD) {
      await this._compact();
    }

    const reply = await chat(this.messages, { forceModel });
    this.history.push({ role: "assistant", content: reply });
    return reply;
  }

  /** Clear in-session history (does NOT affect persistent memory). */
  resetSession() {
    this.history = [];
  }

  /**
   * Context compaction — summarise the current conversation into MEMORY.md
   * using the cheap model, then reset the in-session history.
   */
  async _compact() {
    console.log(`[${this.name}] Compacting context (token budget exceeded)…`);

    const summaryPrompt = [
      { role: "system", content: "You are a concise note-taker." },
      {
        role: "user",
        content: `Summarise the key facts, decisions, and open items from the
conversation below into bullet points. Merge with any existing memory notes.
Do NOT include small talk.

### Existing Memory
${this.memory || "(empty)"}

### Conversation
${this.history.map((m) => `${m.role.toUpperCase()}: ${m.content}`).join("\n\n")}`,
      },
    ];

    const newMemory = await chat(summaryPrompt, {
      forceModel: process.env.MODEL_CHEAP,
    });

    await this.saveMemory(newMemory);
    this.history = [];

    console.log(`[${this.name}] Compaction complete. Memory updated.`);
  }
}
