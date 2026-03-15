/**
 * Heartbeat — runs periodically (via systemd timer) to keep agents current.
 *
 * Each agent's heartbeat task is defined in its SOUL.md under a
 * `## Heartbeat Task` section.  If none is defined, the agent is skipped.
 *
 * Uses the cheap model (Gemini Flash) to minimise costs.
 */

import "dotenv/config";
import { loadAllAgents, agentNames, getAgent } from "../agents/index.js";
import { chat } from "../router/nadir.js";

const MODEL = process.env.MODEL_CHEAP ?? "google/gemini-flash-1.5-8b";

async function runHeartbeat() {
  console.log(`[Heartbeat] Starting — ${new Date().toISOString()}`);
  await loadAllAgents();

  for (const name of agentNames) {
    const agent = getAgent(name);
    if (!agent) continue;

    // Extract heartbeat task from SOUL.md
    const heartbeatMatch = agent.soul.match(
      /##\s+Heartbeat Task\s*\n([\s\S]*?)(?:\n##|\s*$)/i
    );
    if (!heartbeatMatch) {
      console.log(`[Heartbeat] ${name}: no heartbeat task defined, skipping.`);
      continue;
    }

    const task = heartbeatMatch[1].trim();
    console.log(`[Heartbeat] ${name}: running task — "${task.slice(0, 80)}…"`);

    try {
      const messages = [
        { role: "system", content: agent.systemPrompt },
        {
          role: "user",
          content: `[Heartbeat task — ${new Date().toISOString()}]\n${task}`,
        },
      ];

      const result = await chat(messages, { forceModel: MODEL });
      console.log(`[Heartbeat] ${name}: done.\n${result.slice(0, 200)}`);

      // Optionally persist heartbeat notes to memory
      if (result.trim()) {
        const updatedMemory =
          agent.memory +
          `\n\n### Heartbeat — ${new Date().toISOString()}\n${result}`;
        await agent.saveMemory(updatedMemory);
      }
    } catch (err) {
      console.error(`[Heartbeat] ${name}: ERROR — ${err.message}`);
    }
  }

  console.log(`[Heartbeat] Done — ${new Date().toISOString()}`);
}

runHeartbeat().catch((err) => {
  console.error("[Heartbeat] Fatal error:", err);
  process.exit(1);
});
