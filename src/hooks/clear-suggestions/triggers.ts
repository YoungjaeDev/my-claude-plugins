/**
 * Clear Suggestions Trigger Detection
 *
 * Implements the 5 semantic triggers that determine when to suggest /clear:
 * 1. Workflow complete - ralph/autopilot/ultrawork finished
 * 2. Architect verified - architect approval passed
 * 3. Planning complete - ralplan/plan skill completed
 * 4. Context >50% + artifacts - high context but plan files exist
 * 5. Degradation signals - 3+ consecutive failures
 */

import { existsSync, readFileSync } from 'fs';
import { join } from 'path';
import type { ClearSuggestionTrigger, ClearSuggestionState, ClearSuggestionConfig, PreservedArtifact } from './types.js';
import { CONTEXT_THRESHOLD, FAILURE_THRESHOLD, FAILURE_WINDOW_MS } from './constants.js';

/**
 * Detect if a workflow (ralph/autopilot/ultrawork) just completed.
 *
 * Checks state files for modes that transitioned from active to inactive
 * within the current hook call.
 */
export function detectWorkflowComplete(
  state: ClearSuggestionState
): ClearSuggestionTrigger | null {
  if (state.workflowJustCompleted) {
    return 'workflow_complete';
  }
  return null;
}

/**
 * Detect if architect verification just passed.
 *
 * Reads ralph verification state to see if architect approved.
 */
export function detectArchitectVerified(
  state: ClearSuggestionState
): ClearSuggestionTrigger | null {
  if (state.architectJustVerified) {
    return 'architect_verified';
  }
  return null;
}

/**
 * Detect if planning just completed.
 *
 * Checks if a plan skill or ralplan skill just finished.
 */
export function detectPlanningComplete(
  state: ClearSuggestionState
): ClearSuggestionTrigger | null {
  if (state.planningJustCompleted) {
    return 'planning_complete';
  }
  return null;
}

/**
 * Detect if context is above threshold and artifacts exist to reload.
 *
 * This trigger fires when context is high but the user has saved artifacts
 * (plans, PRDs, notes) that would automatically reload after /clear.
 */
export function detectContextWithArtifacts(
  contextUsageRatio: number | undefined,
  artifacts: PreservedArtifact[],
  config?: ClearSuggestionConfig
): ClearSuggestionTrigger | null {
  const threshold = config?.contextThreshold ?? CONTEXT_THRESHOLD;

  if (contextUsageRatio === undefined || contextUsageRatio < threshold) {
    return null;
  }

  // Only suggest if there are artifacts to reload
  if (artifacts.length === 0) {
    return null;
  }

  return 'context_artifacts';
}

/**
 * Detect degradation signals from consecutive failures.
 *
 * Tracks recent tool failures and triggers when the threshold is exceeded.
 */
export function detectDegradationSignals(
  state: ClearSuggestionState,
  config?: ClearSuggestionConfig
): ClearSuggestionTrigger | null {
  const threshold = config?.failureThreshold ?? FAILURE_THRESHOLD;
  const now = Date.now();

  // Filter to recent failures only
  const recentFailures = state.failureTimestamps.filter(
    ts => now - ts < FAILURE_WINDOW_MS
  );

  if (recentFailures.length >= threshold) {
    return 'degradation_signals';
  }

  return null;
}

/**
 * Check if a tool output indicates a failure
 */
export function isToolFailure(toolName: string, toolOutput: string): boolean {
  if (!toolOutput) return false;

  const output = toolOutput.toLowerCase();

  // Bash failures
  if (toolName === 'Bash' || toolName === 'bash') {
    const failurePatterns = [
      /error:/i,
      /failed/i,
      /exit code: [1-9]/i,
      /exit status [1-9]/i,
      /fatal:/i,
      /command not found/i,
    ];
    return failurePatterns.some(p => p.test(toolOutput));
  }

  // Edit failures
  if (toolName === 'Edit' || toolName === 'edit') {
    const editFailures = [
      'old_string not found',
      'not unique',
      'no match',
      'failed to edit',
    ];
    return editFailures.some(f => output.includes(f));
  }

  // Task failures
  if (toolName === 'Task' || toolName === 'task') {
    const taskFailures = [
      'error',
      'failed',
      'timeout',
      'agent error',
    ];
    return taskFailures.some(f => output.includes(f));
  }

  return false;
}

/**
 * Discover preserved artifacts in the project directory.
 *
 * Scans for plans, PRDs, specs, progress files, notepads, and wisdom files
 * that would survive a /clear and be available in the new session.
 */
export function discoverPreservedArtifacts(directory: string): PreservedArtifact[] {
  const artifacts: PreservedArtifact[] = [];

  const candidates: Array<{
    type: PreservedArtifact['type'];
    relativePath: string;
    description: string;
  }> = [
    // Plans
    { type: 'plan', relativePath: '.omc/plans', description: 'Implementation plans (.omc/plans/)' },
    // PRD
    { type: 'prd', relativePath: '.omc/prd.json', description: 'Product Requirements Document (.omc/prd.json)' },
    { type: 'prd', relativePath: 'prd.json', description: 'Product Requirements Document (prd.json)' },
    // Spec
    { type: 'spec', relativePath: '.omc/autopilot/spec.md', description: 'Autopilot specification (.omc/autopilot/spec.md)' },
    // Progress
    { type: 'progress', relativePath: '.omc/progress.txt', description: 'Progress log (.omc/progress.txt)' },
    { type: 'progress', relativePath: 'progress.txt', description: 'Progress log (progress.txt)' },
    // Notepad
    { type: 'notepad', relativePath: '.omc/notepad.md', description: 'Notepad memory (.omc/notepad.md)' },
    // Wisdom files
    { type: 'learning', relativePath: '.omc/notepads', description: 'Wisdom entries (.omc/notepads/)' },
    // AGENTS.md
    { type: 'decision', relativePath: 'AGENTS.md', description: 'Agent documentation (AGENTS.md)' },
    // CLAUDE.md
    { type: 'decision', relativePath: '.claude/CLAUDE.md', description: 'Project instructions (.claude/CLAUDE.md)' },
  ];

  for (const candidate of candidates) {
    const fullPath = join(directory, candidate.relativePath);
    if (existsSync(fullPath)) {
      artifacts.push({
        type: candidate.type,
        path: fullPath,
        description: candidate.description,
      });
    }
  }

  return artifacts;
}

/**
 * Check if a mode just completed by comparing current state with previous state.
 *
 * Reads mode state files to detect transitions from active to inactive.
 */
export function checkModeJustCompleted(
  directory: string,
  modeName: string
): boolean {
  const stateDir = join(directory, '.omc', 'state');

  // Map mode names to their state files
  const stateFiles: Record<string, string> = {
    ralph: 'ralph-state.json',
    autopilot: 'autopilot-state.json',
    ultrawork: 'ultrawork-state.json',
    ultraqa: 'ultraqa-state.json',
  };

  const stateFile = stateFiles[modeName];
  if (!stateFile) return false;

  const filePath = join(stateDir, stateFile);
  if (!existsSync(filePath)) return false;

  try {
    const content = readFileSync(filePath, 'utf-8');
    const state = JSON.parse(content);

    // Check for completed state: active=false with a completed_at timestamp
    if (state.active === false && state.completed_at) {
      // Only trigger if completed recently (within last 30 seconds)
      const completedAt = new Date(state.completed_at).getTime();
      const age = Date.now() - completedAt;
      return age < 30_000;
    }

    // For autopilot, check phase === 'complete'
    if (state.phase === 'complete' && state.active === false) {
      return true;
    }
  } catch {
    // State file unreadable
  }

  return false;
}

/**
 * Check if architect verification just passed
 */
export function checkArchitectJustVerified(directory: string): boolean {
  const verificationFile = join(directory, '.omc', 'state', 'ralph-verification.json');

  if (!existsSync(verificationFile)) return false;

  try {
    const content = readFileSync(verificationFile, 'utf-8');
    const state = JSON.parse(content);

    if (state.status === 'approved' && state.completed_at) {
      const completedAt = new Date(state.completed_at).getTime();
      const age = Date.now() - completedAt;
      return age < 30_000;
    }
  } catch {
    // Verification file unreadable
  }

  return false;
}
