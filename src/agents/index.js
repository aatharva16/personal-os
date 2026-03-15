/**
 * Agent registry — maps slash-command names to agent instances.
 *
 * To add a new agent:
 *  1. Create agents/<name>/SOUL.md and agents/<name>/MEMORY.md
 *  2. Add an entry below.
 */

import { BaseAgent } from "./base.js";

const registry = {
  health: new BaseAgent("health"),
  stocks: new BaseAgent("stocks"),
  email: new BaseAgent("email"),
};

/**
 * Initialise (load SOUL + MEMORY from disk) for all registered agents.
 */
export async function loadAllAgents() {
  await Promise.all(Object.values(registry).map((a) => a.load()));
  console.log(`[Registry] Loaded agents: ${Object.keys(registry).join(", ")}`);
}

/**
 * Retrieve an agent by name. Returns null if unknown.
 * @param {string} name
 * @returns {BaseAgent|null}
 */
export function getAgent(name) {
  return registry[name] ?? null;
}

export const agentNames = Object.keys(registry);
export default registry;
