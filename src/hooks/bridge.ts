/**
 * Hook Bridge - TypeScript logic invoked by shell scripts
 *
 * This module provides the main entry point for shell hooks to call TypeScript
 * for complex processing. The shell script reads stdin, passes it to this module,
 * and writes the JSON output to stdout.
 *
 * Usage from shell:
 * ```bash
 * #!/bin/bash
 * INPUT=$(cat)
 * echo "$INPUT" | node ~/.claude/omc/hook-bridge.mjs --hook=keyword-detector
 * ```
 */

import { detectKeywordsWithType, removeCodeBlocks } from './keyword-detector/index.js';
import { readRalphState, incrementRalphIteration, clearRalphState, detectCompletionPromise, createRalphLoopHook } from './ralph/index.js';
import { processOrchestratorPreTool } from './omc-orchestrator/index.js';
import { addBackgroundTask, completeBackgroundTask } from '../hud/background-tasks.js';
import {
  readVerificationState,
  startVerification,
  getArchitectVerificationPrompt,
  clearVerificationState
} from './ralph/index.js';
import { checkIncompleteTodos, StopContext, isContextLimitStop, isUserAbort } from './todo-continuation/index.js';
import { checkPersistentModes, createHookOutput } from './persistent-mode/index.js';
import { activateUltrawork, readUltraworkState } from './ultrawork/index.js';
import {
  readAutopilotState,
  isAutopilotActive,
  getPhasePrompt,
  transitionPhase,
  formatCompactSummary
} from './autopilot/index.js';
import {
  ULTRAWORK_MESSAGE,
  ULTRATHINK_MESSAGE,
  SEARCH_MESSAGE,
  ANALYZE_MESSAGE,
  TODO_CONTINUATION_PROMPT,
  RALPH_MESSAGE
} from '../installer/hooks.js';

// New async hook imports
import {
  processSubagentStart,
  processSubagentStop,
  type SubagentStartInput,
  type SubagentStopInput
} from './subagent-tracker/index.js';
import {
  processPreCompact,
  type PreCompactInput
} from './pre-compact/index.js';
import {
  processSetup,
  type SetupInput
} from './setup/index.js';
import {
  handlePermissionRequest,
  type PermissionRequestInput
} from './permission-handler/index.js';
import {
  handleSessionEnd,
  type SessionEndInput
} from './session-end/index.js';

/**
 * Input format from Claude Code hooks (via stdin)
 */
export interface HookInput {
  /** Session identifier */
  sessionId?: string;
  /** User prompt text */
  prompt?: string;
  /** Message content (alternative to prompt) */
  message?: {
    content?: string;
  };
  /** Message parts (alternative structure) */
  parts?: Array<{
    type: string;
    text?: string;
  }>;
  /** Tool name (for tool hooks) */
  toolName?: string;
  /** Tool input parameters */
  toolInput?: unknown;
  /** Tool output (for post-tool hooks) */
  toolOutput?: unknown;
  /** Working directory */
  directory?: string;
}

/**
 * Output format for Claude Code hooks (to stdout)
 */
export interface HookOutput {
  /** Whether to continue with the operation */
  continue: boolean;
  /** Optional message to inject into context */
  message?: string;
  /** Reason for blocking (when continue=false) */
  reason?: string;
  /** Modified tool input (for pre-tool hooks) */
  modifiedInput?: unknown;
}

/**
 * Hook types that can be processed
 */
export type HookType =
  | 'keyword-detector'
  | 'stop-continuation'
  | 'ralph'
  | 'persistent-mode'
  | 'session-start'
  | 'session-end'          // NEW: Cleanup and metrics on session end
  | 'pre-tool-use'
  | 'post-tool-use'
  | 'autopilot'
  | 'subagent-start'       // NEW: Track agent spawns
  | 'subagent-stop'        // NEW: Verify agent completion
  | 'pre-compact'          // NEW: Save state before compaction
  | 'setup-init'           // NEW: One-time initialization
  | 'setup-maintenance'    // NEW: Periodic maintenance
  | 'permission-request';  // NEW: Smart auto-approval

/**
 * Extract prompt text from various input formats
 */
function getPromptText(input: HookInput): string {
  if (input.prompt) {
    return input.prompt;
  }
  if (input.message?.content) {
    return input.message.content;
  }
  if (input.parts) {
    return input.parts
      .filter(p => p.type === 'text' && p.text)
      .map(p => p.text)
      .join(' ');
  }
  return '';
}

/**
 * Process keyword detection hook
 * Detects ultrawork/ultrathink/search/analyze keywords and returns injection message
 * Also activates persistent ultrawork state when ultrawork keyword is detected
 */
function processKeywordDetector(input: HookInput): HookOutput {
  const promptText = getPromptText(input);
  if (!promptText) {
    return { continue: true };
  }

  // Remove code blocks to prevent false positives
  const cleanedText = removeCodeBlocks(promptText);

  // Detect keywords
  const keywords = detectKeywordsWithType(cleanedText);

  if (keywords.length === 0) {
    return { continue: true };
  }

  // Priority: ralph > ultrawork > ultrathink > deepsearch > analyze
  const hasRalph = keywords.some(k => k.type === 'ralph');
  const hasUltrawork = keywords.some(k => k.type === 'ultrawork');
  const hasUltrathink = keywords.some(k => k.type === 'ultrathink');
  const hasDeepsearch = keywords.some(k => k.type === 'deepsearch');
  const hasAnalyze = keywords.some(k => k.type === 'analyze');

  if (hasRalph) {
    // Activate ralph state which also auto-activates ultrawork
    const sessionId = input.sessionId;
    const directory = input.directory || process.cwd();
    const hook = createRalphLoopHook(directory);
    hook.startLoop(sessionId || 'cli-session', promptText);

    return {
      continue: true,
      message: RALPH_MESSAGE
    };
  }

  if (hasUltrawork) {
    // Activate persistent ultrawork state
    const sessionId = input.sessionId;
    const directory = input.directory || process.cwd();
    activateUltrawork(promptText, sessionId, directory);

    return {
      continue: true,
      message: ULTRAWORK_MESSAGE
    };
  }

  if (hasUltrathink) {
    return {
      continue: true,
      message: ULTRATHINK_MESSAGE
    };
  }

  if (hasDeepsearch) {
    return {
      continue: true,
      message: SEARCH_MESSAGE
    };
  }

  if (hasAnalyze) {
    return {
      continue: true,
      message: ANALYZE_MESSAGE
    };
  }

  return { continue: true };
}

/**
 * Process stop continuation hook
 * Checks for incomplete todos and blocks stop if tasks remain
 */
async function processStopContinuation(input: HookInput): Promise<HookOutput> {
  const sessionId = input.sessionId;
  const directory = input.directory || process.cwd();

  // Extract stop context for abort detection (supports both camelCase and snake_case)
  const stopContext: StopContext = {
    stop_reason: (input as Record<string, unknown>).stop_reason as string | undefined,
    stopReason: (input as Record<string, unknown>).stopReason as string | undefined,
    user_requested: (input as Record<string, unknown>).user_requested as boolean | undefined,
    userRequested: (input as Record<string, unknown>).userRequested as boolean | undefined,
  };

  // Never block context-limit stops (causes deadlock - issue #213)
  if (isContextLimitStop(stopContext)) {
    return { continue: true };
  }

  // Respect user abort
  if (isUserAbort(stopContext)) {
    return { continue: true };
  }

  // Check for incomplete todos
  const incompleteTodos = await checkIncompleteTodos(sessionId, directory, stopContext);

  if (incompleteTodos.count > 0) {
    return {
      continue: false,
      reason: `${TODO_CONTINUATION_PROMPT}\n\n[Status: ${incompleteTodos.count} tasks remaining]`
    };
  }

  return { continue: true };
}

/**
 * Process Ralph hook (session.idle event)
 * Continues work loops until completion promise is detected and architect verifies
 */
async function processRalph(input: HookInput): Promise<HookOutput> {
  const sessionId = input.sessionId;
  const directory = input.directory || process.cwd();

  if (!sessionId) {
    return { continue: true };
  }

  // Read Ralph state
  const state = readRalphState(directory);

  if (!state || !state.active) {
    return { continue: true };
  }

  // Check if this is the right session
  if (state.session_id && state.session_id !== sessionId) {
    return { continue: true };
  }

  // Check for existing verification state (architect verification in progress)
  const verificationState = readVerificationState(directory);

  if (verificationState?.pending) {
    // Check if architect has approved (by looking for the tag in transcript)
    // This is handled more thoroughly in persistent-mode hook
    // Here we just remind to spawn architect if verification is pending
    const verificationPrompt = getArchitectVerificationPrompt(verificationState);
    return {
      continue: true,
      message: verificationPrompt
    };
  }

  // Check for completion promise in transcript
  const completed = detectCompletionPromise(sessionId, state.completion_promise);

  if (completed) {
    // Start architect verification instead of completing immediately
    startVerification(directory, state.completion_promise, state.prompt);
    const newVerificationState = readVerificationState(directory);

    if (newVerificationState) {
      const verificationPrompt = getArchitectVerificationPrompt(newVerificationState);
      return {
        continue: true,
        message: verificationPrompt
      };
    }

    // Fallback if verification couldn't be started
    clearRalphState(directory);
    return {
      continue: true,
      message: `[RALPH LOOP COMPLETE] Task completed after ${state.iteration} iteration(s).`
    };
  }

  // Check max iterations
  if (state.iteration >= state.max_iterations) {
    clearRalphState(directory);
    clearVerificationState(directory);
    return {
      continue: true,
      message: `[RALPH LOOP STOPPED] Max iterations (${state.max_iterations}) reached without completion.`
    };
  }

  // Increment and continue
  const newState = incrementRalphIteration(directory);
  if (!newState) {
    return { continue: true };
  }

  const continuationPrompt = `[RALPH LOOP - ITERATION ${newState.iteration}/${newState.max_iterations}]

Your previous attempt did not output the completion promise. Continue working on the task.

IMPORTANT:
- Review your progress so far
- Continue from where you left off
- When FULLY complete, output: <promise>${newState.completion_promise}</promise>
- Do not stop until the task is truly done

Original task:
${newState.prompt}`;

  return {
    continue: true,
    message: continuationPrompt
  };
}

/**
 * Process persistent mode hook (enhanced stop continuation)
 * Unified handler for ultrawork, ralph, and todo-continuation
 */
async function processPersistentMode(input: HookInput): Promise<HookOutput> {
  const sessionId = input.sessionId;
  const directory = input.directory || process.cwd();

  // Extract stop context for abort detection (supports both camelCase and snake_case)
  const stopContext: StopContext = {
    stop_reason: (input as Record<string, unknown>).stop_reason as string | undefined,
    stopReason: (input as Record<string, unknown>).stopReason as string | undefined,
    user_requested: (input as Record<string, unknown>).user_requested as boolean | undefined,
    userRequested: (input as Record<string, unknown>).userRequested as boolean | undefined,
  };

  const result = await checkPersistentModes(sessionId, directory, stopContext);
  return createHookOutput(result);
}

/**
 * Process session start hook
 * Restores persistent mode states and injects context if needed
 */
async function processSessionStart(input: HookInput): Promise<HookOutput> {
  const sessionId = input.sessionId;
  const directory = input.directory || process.cwd();

  const messages: string[] = [];

  // Check for active autopilot state
  const autopilotState = readAutopilotState(directory);
  if (autopilotState?.active) {
    messages.push(`<session-restore>

[AUTOPILOT MODE RESTORED]

You have an active autopilot session from ${autopilotState.started_at}.
Original idea: ${autopilotState.originalIdea}
Current phase: ${autopilotState.phase}

Continue autopilot execution until complete.

</session-restore>

---

`);
  }

  // Check for active ultrawork state
  const ultraworkState = readUltraworkState(directory);
  if (ultraworkState?.active) {
    messages.push(`<session-restore>

[ULTRAWORK MODE RESTORED]

You have an active ultrawork session from ${ultraworkState.started_at}.
Original task: ${ultraworkState.original_prompt}

Continue working in ultrawork mode until all tasks are complete.

</session-restore>

---

`);
  }

  // Check for incomplete todos
  const todoResult = await checkIncompleteTodos(sessionId, directory);
  if (todoResult.count > 0) {
    messages.push(`<session-restore>

[PENDING TASKS DETECTED]

You have ${todoResult.count} incomplete tasks from a previous session.
Please continue working on these tasks.

</session-restore>

---

`);
  }

  if (messages.length > 0) {
    return {
      continue: true,
      message: messages.join('\n')
    };
  }

  return { continue: true };
}

/**
 * Process pre-tool-use hook
 * Checks delegation enforcement and tracks background tasks
 */
function processPreToolUse(input: HookInput): HookOutput {
  const directory = input.directory || process.cwd();

  // Check delegation enforcement FIRST
  const enforcementResult = processOrchestratorPreTool({
    toolName: input.toolName || '',
    toolInput: (input.toolInput as Record<string, unknown>) || {},
    sessionId: input.sessionId,
    directory,
  });

  // If enforcement blocks, return immediately
  if (!enforcementResult.continue) {
    return {
      continue: false,
      reason: enforcementResult.reason,
      message: enforcementResult.message,
    };
  }

  // Track Task tool invocations for HUD background tasks display
  if (input.toolName === 'Task') {
    const toolInput = input.toolInput as {
      description?: string;
      subagent_type?: string;
      run_in_background?: boolean;
    } | undefined;

    if (toolInput?.description) {
      const taskId = `task-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      addBackgroundTask(
        taskId,
        toolInput.description,
        toolInput.subagent_type,
        directory
      );
    }
  }

  // Return enforcement message if present (warning), otherwise continue silently
  return enforcementResult.message
    ? { continue: true, message: enforcementResult.message }
    : { continue: true };
}

/**
 * Process post-tool-use hook
 * Marks background tasks as completed
 */
function processPostToolUse(input: HookInput): HookOutput {
  const directory = input.directory || process.cwd();

  // Track Task tool completion for HUD
  if (input.toolName === 'Task') {
    const toolInput = input.toolInput as {
      description?: string;
    } | undefined;

    // We don't have the exact task ID, but the HUD state cleanup handles this
    // For now, this is a placeholder - proper tracking would need tool_use_id
    // which isn't reliably available in all hook scenarios
  }

  return { continue: true };
}

/**
 * Process autopilot hook
 * Manages autopilot state and injects phase prompts
 */
function processAutopilot(input: HookInput): HookOutput {
  const directory = input.directory || process.cwd();

  const state = readAutopilotState(directory);

  if (!state || !state.active) {
    return { continue: true };
  }

  // Check phase and inject appropriate prompt
  const context = {
    idea: state.originalIdea,
    specPath: state.expansion.spec_path || '.omc/autopilot/spec.md',
    planPath: state.planning.plan_path || '.omc/plans/autopilot-impl.md'
  };

  const phasePrompt = getPhasePrompt(state.phase, context);

  if (phasePrompt) {
    return {
      continue: true,
      message: `[AUTOPILOT - Phase: ${state.phase.toUpperCase()}]\n\n${phasePrompt}`
    };
  }

  return { continue: true };
}

/**
 * Main hook processor
 * Routes to specific hook handler based on type
 */
export async function processHook(
  hookType: HookType,
  input: HookInput
): Promise<HookOutput> {
  try {
    switch (hookType) {
      case 'keyword-detector':
        return processKeywordDetector(input);

      case 'stop-continuation':
        return await processStopContinuation(input);

      case 'ralph':
        return await processRalph(input);

      case 'persistent-mode':
        return await processPersistentMode(input);

      case 'session-start':
        return await processSessionStart(input);

      case 'pre-tool-use':
        return processPreToolUse(input);

      case 'post-tool-use':
        return processPostToolUse(input);

      case 'autopilot':
        return processAutopilot(input);

      // New async hook types
      case 'session-end':
        return await handleSessionEnd(input as unknown as SessionEndInput);

      case 'subagent-start':
        return processSubagentStart(input as unknown as SubagentStartInput);

      case 'subagent-stop':
        return processSubagentStop(input as unknown as SubagentStopInput);

      case 'pre-compact':
        return await processPreCompact(input as unknown as PreCompactInput);

      case 'setup-init':
        return await processSetup({
          ...input,
          trigger: 'init',
          hook_event_name: 'Setup'
        } as unknown as SetupInput);

      case 'setup-maintenance':
        return await processSetup({
          ...input,
          trigger: 'maintenance',
          hook_event_name: 'Setup'
        } as unknown as SetupInput);

      case 'permission-request':
        return await handlePermissionRequest(input as unknown as PermissionRequestInput);

      default:
        return { continue: true };
    }
  } catch (error) {
    // Log error but don't block execution
    console.error(`[hook-bridge] Error in ${hookType}:`, error);
    return { continue: true };
  }
}

/**
 * CLI entry point for shell script invocation
 * Reads JSON from stdin, processes hook, writes JSON to stdout
 */
export async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const hookArg = args.find(a => a.startsWith('--hook='));

  if (!hookArg) {
    console.error('Usage: node hook-bridge.mjs --hook=<type>');
    process.exit(1);
  }

  const hookType = hookArg.split('=')[1] as HookType;

  // Read stdin
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }

  const inputStr = Buffer.concat(chunks).toString('utf-8');

  let input: HookInput;
  try {
    input = JSON.parse(inputStr);
  } catch {
    input = {};
  }

  // Process hook
  const output = await processHook(hookType, input);

  // Write output to stdout
  console.log(JSON.stringify(output));
}

// Run if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(err => {
    console.error('[hook-bridge] Fatal error:', err);
    process.exit(1);
  });
}
