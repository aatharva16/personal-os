/**
 * Personal AI OS — Entry Point
 *
 * Runs a Telegram bot that lets the user switch between agent personas
 * via slash commands (e.g. /agent stocks) and chat naturally.
 */

import "dotenv/config";
import TelegramBot from "node-telegram-bot-api";
import { loadAllAgents, getAgent, agentNames } from "./agents/index.js";

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const ALLOWED_USER_ID = parseInt(process.env.TELEGRAM_ALLOWED_USER_ID ?? "0", 10);

if (!BOT_TOKEN) {
  console.error("ERROR: TELEGRAM_BOT_TOKEN is not set.");
  process.exit(1);
}

const bot = new TelegramBot(BOT_TOKEN, { polling: true });

// Per-chat state: which agent is currently active
const activeAgents = new Map(); // chatId → agent name

function currentAgent(chatId) {
  const name = activeAgents.get(chatId) ?? "health";
  return getAgent(name);
}

function isAuthorized(userId) {
  if (!ALLOWED_USER_ID) return true; // open if not configured
  return userId === ALLOWED_USER_ID;
}

// ── /start ────────────────────────────────────────────────────────────────────
bot.onText(/\/start/, async (msg) => {
  if (!isAuthorized(msg.from.id)) return;

  const names = agentNames.join(", ");
  await bot.sendMessage(
    msg.chat.id,
    `👋 *Personal AI OS* is online.\n\nAvailable agents: ${names}\n\nSwitch with: \`/agent <name>\`\nCurrent agent: *${activeAgents.get(msg.chat.id) ?? "health"}*`,
    { parse_mode: "Markdown" }
  );
});

// ── /agent <name> ─────────────────────────────────────────────────────────────
bot.onText(/\/agent(?:\s+(\w+))?/, async (msg, match) => {
  if (!isAuthorized(msg.from.id)) return;
  const chatId = msg.chat.id;

  if (!match[1]) {
    const names = agentNames.map((n) => `• \`${n}\``).join("\n");
    await bot.sendMessage(
      chatId,
      `Available agents:\n${names}\n\nUsage: \`/agent <name>\``,
      { parse_mode: "Markdown" }
    );
    return;
  }

  const name = match[1].toLowerCase();
  const agent = getAgent(name);
  if (!agent) {
    await bot.sendMessage(chatId, `Unknown agent: *${name}*. Try: ${agentNames.join(", ")}`, {
      parse_mode: "Markdown",
    });
    return;
  }

  activeAgents.set(chatId, name);
  // Reset session history on agent switch
  agent.resetSession();
  await bot.sendMessage(
    chatId,
    `Switched to *${name}* agent. Session history cleared.`,
    { parse_mode: "Markdown" }
  );
});

// ── /reset — clear current agent's session ────────────────────────────────────
bot.onText(/\/reset/, async (msg) => {
  if (!isAuthorized(msg.from.id)) return;
  const agent = currentAgent(msg.chat.id);
  agent.resetSession();
  await bot.sendMessage(msg.chat.id, `Session reset for *${agent.name}* agent.`, {
    parse_mode: "Markdown",
  });
});

// ── /memory — show current agent's persistent memory ─────────────────────────
bot.onText(/\/memory/, async (msg) => {
  if (!isAuthorized(msg.from.id)) return;
  const agent = currentAgent(msg.chat.id);
  const text = agent.memory || "(Memory is empty)";
  await bot.sendMessage(msg.chat.id, `*${agent.name} Memory:*\n\`\`\`\n${text}\n\`\`\``, {
    parse_mode: "Markdown",
  });
});

// ── /status — system info ─────────────────────────────────────────────────────
bot.onText(/\/status/, async (msg) => {
  if (!isAuthorized(msg.from.id)) return;
  const chatId = msg.chat.id;
  const activeName = activeAgents.get(chatId) ?? "health";
  const agent = getAgent(activeName);
  const tokens = agent
    ? Math.round(agent.history.reduce((s, m) => s + m.content.length / 4, 0))
    : 0;

  await bot.sendMessage(
    chatId,
    `*System Status*\n• Active agent: ${activeName}\n• Session tokens (approx): ${tokens}\n• Compaction threshold: ${process.env.MEMORY_COMPACTION_THRESHOLD ?? 8000}\n• Cheap model: \`${process.env.MODEL_CHEAP}\`\n• Smart model: \`${process.env.MODEL_SMART}\``,
    { parse_mode: "Markdown" }
  );
});

// ── /help ─────────────────────────────────────────────────────────────────────
bot.onText(/\/help/, async (msg) => {
  if (!isAuthorized(msg.from.id)) return;
  await bot.sendMessage(
    msg.chat.id,
    `*Commands*\n/start — welcome message\n/agent <name> — switch agent\n/reset — clear session history\n/memory — view persistent memory\n/status — system info\n/help — this message\n\n*Available agents:* ${agentNames.join(", ")}`,
    { parse_mode: "Markdown" }
  );
});

// ── Plain messages → active agent ─────────────────────────────────────────────
bot.on("message", async (msg) => {
  if (!isAuthorized(msg.from.id)) return;
  if (!msg.text || msg.text.startsWith("/")) return;

  const chatId = msg.chat.id;
  const agent = currentAgent(chatId);

  // Show "typing" indicator while waiting
  await bot.sendChatAction(chatId, "typing");

  try {
    const reply = await agent.send(msg.text);
    await bot.sendMessage(chatId, reply, { parse_mode: "Markdown" });
  } catch (err) {
    console.error(`[Bot] Error from ${agent.name} agent:`, err.message);
    await bot.sendMessage(
      chatId,
      `⚠️ Error: ${err.message}\n\nPlease try again or use /reset to clear the session.`
    );
  }
});

// ── Boot ──────────────────────────────────────────────────────────────────────
(async () => {
  console.log("[Boot] Loading agents…");
  await loadAllAgents();
  console.log("[Boot] Personal AI OS is running. Waiting for messages…");
})();
