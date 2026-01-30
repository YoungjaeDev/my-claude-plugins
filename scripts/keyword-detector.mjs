#!/usr/bin/env node

/**
 * OMC Keyword Detector Hook (Node.js)
 * Detects magic keywords and invokes skill tools
 * Cross-platform: Windows, macOS, Linux
 *
 * Supported keywords (in priority order):
 * 1. cancelomc/stopomc: Stop active modes
 * 2. ralph: Persistence mode until task completion
 * 3. autopilot: Full autonomous execution
 * 4. ultrapilot: Parallel autopilot
 * 5. ultrawork/ulw: Maximum parallel execution
 * 6. ecomode/eco: Token-efficient execution
 * 7. swarm: N coordinated agents
 * 8. pipeline: Sequential agent chaining
 * 9. ralplan: Iterative planning with consensus
 * 10. plan: Planning interview mode
 * 11. tdd: Test-driven development
 * 12. research: Research orchestration
 * 13. ultrathink/think: Extended reasoning
 * 14. deepsearch: Codebase search (restricted patterns)
 * 15. analyze: Analysis mode (restricted patterns)
 */

import { writeFileSync, mkdirSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

const ULTRATHINK_MESSAGE = `<think-mode>

**ULTRATHINK MODE ENABLED** - Extended reasoning activated.

You are now in deep thinking mode. Take your time to:
1. Thoroughly analyze the problem from multiple angles
2. Consider edge cases and potential issues
3. Think through the implications of each approach
4. Reason step-by-step before acting

Use your extended thinking capabilities to provide the most thorough and well-reasoned response.

</think-mode>

---
`;

// Read all stdin
async function readStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf-8');
}

// Extract prompt from various JSON structures
function extractPrompt(input) {
  try {
    const data = JSON.parse(input);
    if (data.prompt) return data.prompt;
    if (data.message?.content) return data.message.content;
    if (Array.isArray(data.parts)) {
      return data.parts
        .filter(p => p.type === 'text')
        .map(p => p.text)
        .join(' ');
    }
    return '';
  } catch {
    // Fallback: try to extract with regex
    const match = input.match(/"(?:prompt|content|text)"\s*:\s*"([^"]+)"/);
    return match ? match[1] : '';
  }
}

// Remove code blocks to prevent false positives
function removeCodeBlocks(text) {
  return text
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`]+`/g, '');
}

// Create state file for a mode
function activateState(directory, prompt, stateName) {
  const state = {
    active: true,
    started_at: new Date().toISOString(),
    original_prompt: prompt,
    reinforcement_count: 0,
    last_checked_at: new Date().toISOString()
  };

  // Write to local .omc/state directory
  const localDir = join(directory, '.omc', 'state');
  if (!existsSync(localDir)) {
    try { mkdirSync(localDir, { recursive: true }); } catch {}
  }
  try { writeFileSync(join(localDir, `${stateName}-state.json`), JSON.stringify(state, null, 2)); } catch {}

  // Write to global .omc/state directory
  const globalDir = join(homedir(), '.omc', 'state');
  if (!existsSync(globalDir)) {
    try { mkdirSync(globalDir, { recursive: true }); } catch {}
  }
  try { writeFileSync(join(globalDir, `${stateName}-state.json`), JSON.stringify(state, null, 2)); } catch {}
}

/**
 * Clear state files for cancel operation
 */
function clearStateFiles(directory, modeNames) {
  for (const name of modeNames) {
    const localPath = join(directory, '.omc', 'state', `${name}-state.json`);
    const globalPath = join(homedir(), '.omc', 'state', `${name}-state.json`);
    try { if (existsSync(localPath)) unlinkSync(localPath); } catch {}
    try { if (existsSync(globalPath)) unlinkSync(globalPath); } catch {}
  }
}

/**
 * Create a skill invocation message that tells Claude to use the Skill tool
 */
function createSkillInvocation(skillName, originalPrompt, args = '') {
  const argsSection = args ? `\nArguments: ${args}` : '';
  return `[MAGIC KEYWORD: ${skillName.toUpperCase()}]

You MUST invoke the skill using the Skill tool:

Skill: oh-my-claudecode:${skillName}${argsSection}

User request:
${originalPrompt}

IMPORTANT: Invoke the skill IMMEDIATELY. Do not proceed without loading the skill instructions.`;
}

/**
 * Create proper hook output with additionalContext (Claude Code hooks API)
 * The 'message' field is NOT a valid hook output - use hookSpecificOutput.additionalContext
 */
function createHookOutput(additionalContext) {
  return {
    continue: true,
    hookSpecificOutput: {
      hookEventName: 'UserPromptSubmit',
      additionalContext
    }
  };
}

// Main
async function main() {
  try {
    const input = await readStdin();
    if (!input.trim()) {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    let data = {};
    try { data = JSON.parse(input); } catch {}
    const directory = data.directory || process.cwd();

    const prompt = extractPrompt(input);
    if (!prompt) {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    const cleanPrompt = removeCodeBlocks(prompt).toLowerCase();

    // Priority order: cancel > ralph > autopilot > ultrapilot > ultrawork > ecomode > swarm > pipeline > ralplan > plan > tdd > research > ultrathink > deepsearch > analyze

    // Priority 1: Cancel (BEFORE other modes - clears states)
    // Use specific keywords to avoid false positives from natural language
    // (e.g., "don't let it stop the context" or URLs containing "cancel")
    if (/\b(cancelomc|stopomc)\b/i.test(cleanPrompt)) {
      // Special: clear state files instead of creating them
      clearStateFiles(directory, ['ralph', 'autopilot', 'ultrapilot', 'ultrawork', 'ecomode', 'swarm', 'pipeline']);
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('cancel', prompt))));
      return;
    }

    // Priority 2: Ralph keywords
    if (/\b(ralph|don't stop|must complete|until done)\b/i.test(cleanPrompt)) {
      activateState(directory, prompt, 'ralph');
      activateState(directory, prompt, 'ultrawork');
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('ralph', prompt))));
      return;
    }

    // Priority 3: Autopilot keywords
    if (/\b(autopilot|auto pilot|auto-pilot|autonomous|full auto|fullsend)\b/i.test(cleanPrompt) ||
        /\bbuild\s+me\s+/i.test(cleanPrompt) ||
        /\bcreate\s+me\s+/i.test(cleanPrompt) ||
        /\bmake\s+me\s+/i.test(cleanPrompt) ||
        /\bi\s+want\s+a\s+/i.test(cleanPrompt) ||
        /\bi\s+want\s+an\s+/i.test(cleanPrompt) ||
        /\bhandle\s+it\s+all\b/i.test(cleanPrompt) ||
        /\bend\s+to\s+end\b/i.test(cleanPrompt) ||
        /\be2e\s+this\b/i.test(cleanPrompt)) {
      activateState(directory, prompt, 'autopilot');
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('autopilot', prompt))));
      return;
    }

    // Priority 4: Ultrapilot
    if (/\b(ultrapilot|ultra-pilot)\b/i.test(cleanPrompt) ||
        /\bparallel\s+build\b/i.test(cleanPrompt) ||
        /\bswarm\s+build\b/i.test(cleanPrompt)) {
      activateState(directory, prompt, 'ultrapilot');
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('ultrapilot', prompt))));
      return;
    }

    // Priority 5: Ultrawork keywords
    if (/\b(ultrawork|ulw|uw)\b/i.test(cleanPrompt)) {
      activateState(directory, prompt, 'ultrawork');
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('ultrawork', prompt))));
      return;
    }

    // Priority 6: Ecomode keywords (includes "efficient")
    if (/\b(eco|ecomode|eco-mode|efficient|save-tokens|budget)\b/i.test(cleanPrompt)) {
      activateState(directory, prompt, 'ecomode');
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('ecomode', prompt))));
      return;
    }

    // Priority 7: Swarm - parse N from "swarm N agents"
    const swarmMatch = cleanPrompt.match(/\bswarm\s+(\d+)\s+agents?\b/i);
    if (swarmMatch || /\bcoordinated\s+agents\b/i.test(cleanPrompt)) {
      const agentCount = swarmMatch ? swarmMatch[1] : '3'; // default 3
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('swarm', prompt, agentCount))));
      return;
    }

    // Priority 8: Pipeline
    if (/\b(pipeline)\b/i.test(cleanPrompt) || /\bchain\s+agents\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('pipeline', prompt))));
      return;
    }

    // Priority 9: Ralplan keyword (before plan to avoid false match)
    if (/\b(ralplan)\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('ralplan', prompt))));
      return;
    }

    // Priority 10: Plan keywords
    if (/\b(plan this|plan the)\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('plan', prompt))));
      return;
    }

    // Priority 11: TDD
    if (/\b(tdd)\b/i.test(cleanPrompt) ||
        /\btest\s+first\b/i.test(cleanPrompt) ||
        /\bred\s+green\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('tdd', prompt))));
      return;
    }

    // Priority 12: Research
    // "research" alone OR "analyze data" OR "statistics" trigger research skill
    if (/\b(research)\b/i.test(cleanPrompt) ||
        /\banalyze\s+data\b/i.test(cleanPrompt) ||
        /\bstatistics\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('research', prompt))));
      return;
    }

    // Priority 13: Ultrathink/think keywords (keep inline message)
    if (/\b(ultrathink|think hard|think deeply)\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(ULTRATHINK_MESSAGE)));
      return;
    }

    // Priority 14: Deepsearch (RESTRICTED patterns)
    if (/\b(deepsearch)\b/i.test(cleanPrompt) ||
        /\bsearch\s+(the\s+)?(codebase|code|files?|project)\b/i.test(cleanPrompt) ||
        /\bfind\s+(in\s+)?(codebase|code|all\s+files?)\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('deepsearch', prompt))));
      return;
    }

    // Priority 15: Analyze (RESTRICTED patterns)
    if (/\b(deep\s*analyze)\b/i.test(cleanPrompt) ||
        /\binvestigate\s+(the|this|why)\b/i.test(cleanPrompt) ||
        /\bdebug\s+(the|this|why)\b/i.test(cleanPrompt)) {
      console.log(JSON.stringify(createHookOutput(createSkillInvocation('analyze', prompt))));
      return;
    }

    // No keywords detected
    console.log(JSON.stringify({ continue: true }));
  } catch (error) {
    // On any error, allow continuation
    console.log(JSON.stringify({ continue: true }));
  }
}

main();
