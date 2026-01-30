/**
 * Clear Suggestions Hook
 *
 * Adaptive /clear suggestions system that intelligently recommends session
 * resets when it would improve reliability and performance.
 *
 * Features:
 * - 5 semantic triggers for context-aware suggestions
 * - 5-minute cooldown between suggestions
 * - Maximum 2 suggestions per session
 * - Non-intrusive messaging explaining WHY clearing helps
 * - Lists preserved artifacts (plans, notes, decisions)
 *
 * Complements (doesn't replace) existing /compact suggestions.
 */

import type {
  ClearSuggestionTrigger,
  ClearSuggestionState,
  ClearSuggestionConfig,
  ClearSuggestionResult,
  ClearSuggestionInput,
  PreservedArtifact,
} from './types.js';

import {
  CLEAR_SUGGESTION_COOLDOWN_MS,
  MAX_CLEAR_SUGGESTIONS,
  WORKFLOW_COMPLETE_MESSAGE,
  ARCHITECT_VERIFIED_MESSAGE,
  PLANNING_COMPLETE_MESSAGE,
  CONTEXT_ARTIFACTS_MESSAGE,
  DEGRADATION_SIGNALS_MESSAGE,
  formatPreservedArtifacts,
} from './constants.js';

import {
  detectWorkflowComplete,
  detectArchitectVerified,
  detectPlanningComplete,
  detectContextWithArtifacts,
  detectDegradationSignals,
  isToolFailure,
  discoverPreservedArtifacts,
  checkModeJustCompleted,
  checkArchitectJustVerified,
} from './triggers.js';

import type { ExecutionMode } from '../mode-registry/types.js';

/**
 * In-memory session state tracking
 */
const sessionStates = new Map<string, ClearSuggestionState>();

/**
 * Get or create session state
 */
function getSessionState(sessionId: string): ClearSuggestionState {
  let state = sessionStates.get(sessionId);
  if (!state) {
    state = {
      sessionId,
      lastSuggestionTime: 0,
      suggestionCount: 0,
      consecutiveFailures: 0,
      failureTimestamps: [],
    };
    sessionStates.set(sessionId, state);
  }
  return state;
}

/**
 * Update session state
 */
function updateSessionState(sessionId: string, updates: Partial<ClearSuggestionState>): void {
  const state = getSessionState(sessionId);
  Object.assign(state, updates);
}

/**
 * Record a suggestion was shown
 */
function recordSuggestion(sessionId: string): void {
  const state = getSessionState(sessionId);
  state.lastSuggestionTime = Date.now();
  state.suggestionCount++;
  // Clear one-time flags
  state.workflowJustCompleted = undefined;
  state.architectJustVerified = undefined;
  state.planningJustCompleted = undefined;
}

/**
 * Record a tool failure
 */
function recordFailure(sessionId: string): void {
  const state = getSessionState(sessionId);
  state.consecutiveFailures++;
  state.failureTimestamps.push(Date.now());
  // Keep only recent timestamps (last 10)
  if (state.failureTimestamps.length > 10) {
    state.failureTimestamps = state.failureTimestamps.slice(-10);
  }
}

/**
 * Reset failure count (called on successful tool execution)
 */
function resetFailures(sessionId: string): void {
  const state = getSessionState(sessionId);
  state.consecutiveFailures = 0;
}

/**
 * Check if cooldown has elapsed
 */
function isCooldownElapsed(sessionId: string, config?: ClearSuggestionConfig): boolean {
  const state = getSessionState(sessionId);
  const cooldownMs = config?.cooldownMs ?? CLEAR_SUGGESTION_COOLDOWN_MS;
  const elapsed = Date.now() - state.lastSuggestionTime;
  return elapsed >= cooldownMs;
}

/**
 * Check if max suggestions reached
 */
function isMaxSuggestionsReached(sessionId: string, config?: ClearSuggestionConfig): boolean {
  const state = getSessionState(sessionId);
  const maxSuggestions = config?.maxSuggestions ?? MAX_CLEAR_SUGGESTIONS;
  return state.suggestionCount >= maxSuggestions;
}

/**
 * Generate message for a trigger
 */
function generateMessage(
  trigger: ClearSuggestionTrigger,
  artifacts: PreservedArtifact[],
  state: ClearSuggestionState,
  contextUsageRatio?: number
): string {
  const artifactsText = formatPreservedArtifacts(
    artifacts.map(a => ({ type: a.type, description: a.description }))
  );

  switch (trigger) {
    case 'workflow_complete': {
      const modeName = state.workflowJustCompleted || 'workflow';
      const modeDisplayNames: Record<string, string> = {
        ralph: 'Ralph',
        autopilot: 'Autopilot',
        ultrawork: 'Ultrawork',
        ultraqa: 'UltraQA',
        ultrapilot: 'Ultrapilot',
        swarm: 'Swarm',
        pipeline: 'Pipeline',
        ecomode: 'Ecomode',
      };
      const displayName = modeDisplayNames[modeName] || modeName;
      return WORKFLOW_COMPLETE_MESSAGE(displayName, artifactsText);
    }
    case 'architect_verified':
      return ARCHITECT_VERIFIED_MESSAGE(artifactsText);
    case 'planning_complete':
      return PLANNING_COMPLETE_MESSAGE(artifactsText);
    case 'context_artifacts': {
      const usagePct = Math.round((contextUsageRatio ?? 0.5) * 100);
      return CONTEXT_ARTIFACTS_MESSAGE(usagePct, artifactsText);
    }
    case 'degradation_signals': {
      const failureCount = state.consecutiveFailures;
      return DEGRADATION_SIGNALS_MESSAGE(failureCount, artifactsText);
    }
    default:
      return '';
  }
}

/**
 * Main check function - evaluates all triggers and returns suggestion if appropriate
 */
export function checkClearSuggestion(
  input: ClearSuggestionInput,
  config?: ClearSuggestionConfig
): ClearSuggestionResult {
  const { sessionId, directory, toolName, toolOutput, contextUsageRatio } = input;

  // Check if disabled
  if (config?.enabled === false) {
    return { shouldSuggest: false, skipReason: 'disabled' };
  }

  // Check max suggestions
  if (isMaxSuggestionsReached(sessionId, config)) {
    return { shouldSuggest: false, skipReason: 'max_suggestions_reached' };
  }

  // Check cooldown
  if (!isCooldownElapsed(sessionId, config)) {
    return { shouldSuggest: false, skipReason: 'cooldown_active' };
  }

  // Get session state
  const state = getSessionState(sessionId);

  // Track tool failures/successes
  if (toolName && toolOutput) {
    if (isToolFailure(toolName, toolOutput)) {
      recordFailure(sessionId);
    } else {
      resetFailures(sessionId);
    }
  }

  // Check for mode completions
  const completedModes: ExecutionMode[] = ['ralph', 'autopilot', 'ultrawork', 'ultraqa'];
  for (const mode of completedModes) {
    if (checkModeJustCompleted(directory, mode)) {
      updateSessionState(sessionId, { workflowJustCompleted: mode as ExecutionMode });
      break;
    }
  }

  // Check for architect verification
  if (checkArchitectJustVerified(directory)) {
    updateSessionState(sessionId, { architectJustVerified: true });
  }

  // Discover preserved artifacts
  const artifacts = discoverPreservedArtifacts(directory);

  // Evaluate triggers in priority order
  // Priority: workflow_complete > architect_verified > planning_complete > context_artifacts > degradation_signals

  let trigger: ClearSuggestionTrigger | null = null;

  // 1. Workflow complete (highest priority - clear win)
  trigger = detectWorkflowComplete(state);
  if (trigger) {
    const message = generateMessage(trigger, artifacts, state, contextUsageRatio);
    recordSuggestion(sessionId);
    return { shouldSuggest: true, trigger, message, preservedArtifacts: artifacts };
  }

  // 2. Architect verified
  trigger = detectArchitectVerified(state);
  if (trigger) {
    const message = generateMessage(trigger, artifacts, state, contextUsageRatio);
    recordSuggestion(sessionId);
    return { shouldSuggest: true, trigger, message, preservedArtifacts: artifacts };
  }

  // 3. Planning complete
  trigger = detectPlanningComplete(state);
  if (trigger) {
    const message = generateMessage(trigger, artifacts, state, contextUsageRatio);
    recordSuggestion(sessionId);
    return { shouldSuggest: true, trigger, message, preservedArtifacts: artifacts };
  }

  // 4. Context >50% with artifacts
  trigger = detectContextWithArtifacts(contextUsageRatio, artifacts, config);
  if (trigger) {
    const message = generateMessage(trigger, artifacts, state, contextUsageRatio);
    recordSuggestion(sessionId);
    return { shouldSuggest: true, trigger, message, preservedArtifacts: artifacts };
  }

  // 5. Degradation signals (lowest priority - only if nothing else triggered)
  trigger = detectDegradationSignals(state, config);
  if (trigger) {
    const message = generateMessage(trigger, artifacts, state, contextUsageRatio);
    recordSuggestion(sessionId);
    return { shouldSuggest: true, trigger, message, preservedArtifacts: artifacts };
  }

  return { shouldSuggest: false, skipReason: 'no_triggers_fired' };
}

/**
 * Mark planning as just completed (called by plan/ralplan skills)
 */
export function markPlanningComplete(sessionId: string): void {
  updateSessionState(sessionId, { planningJustCompleted: true });
}

/**
 * Reset session state (called on /clear)
 */
export function resetClearSuggestionState(sessionId: string): void {
  sessionStates.delete(sessionId);
}

/**
 * Get current session stats (for debugging)
 */
export function getClearSuggestionStats(sessionId: string): ClearSuggestionState | null {
  return sessionStates.get(sessionId) ?? null;
}

/**
 * Clean up stale sessions (older than 30 minutes)
 */
export function cleanupStaleSessions(): void {
  const now = Date.now();
  const maxAge = 30 * 60 * 1000; // 30 minutes

  for (const [sessionId, state] of sessionStates) {
    if (state.lastSuggestionTime > 0 && now - state.lastSuggestionTime > maxAge) {
      sessionStates.delete(sessionId);
    }
  }
}

/**
 * Create a clear suggestion hook instance
 */
export function createClearSuggestionHook(config?: ClearSuggestionConfig) {
  return {
    /**
     * PostToolUse - Check if we should suggest /clear
     */
    postToolUse: (input: {
      tool_name: string;
      session_id: string;
      directory: string;
      tool_response?: string;
      context_usage_ratio?: number;
    }): string | null => {
      const result = checkClearSuggestion(
        {
          sessionId: input.session_id,
          directory: input.directory,
          toolName: input.tool_name,
          toolOutput: input.tool_response,
          contextUsageRatio: input.context_usage_ratio,
        },
        config
      );

      if (result.shouldSuggest && result.message) {
        return result.message;
      }

      return null;
    },

    /**
     * Stop event - Reset failure tracking
     */
    stop: (input: { session_id: string }): void => {
      resetFailures(input.session_id);
    },
  };
}

// Re-export types
export type {
  ClearSuggestionTrigger,
  ClearSuggestionState,
  ClearSuggestionConfig,
  ClearSuggestionResult,
  ClearSuggestionInput,
  PreservedArtifact,
} from './types.js';

// Re-export constants
export {
  CLEAR_SUGGESTION_COOLDOWN_MS,
  MAX_CLEAR_SUGGESTIONS,
  CONTEXT_THRESHOLD,
  FAILURE_THRESHOLD,
} from './constants.js';

// Re-export trigger functions for testing
export {
  detectWorkflowComplete,
  detectArchitectVerified,
  detectPlanningComplete,
  detectContextWithArtifacts,
  detectDegradationSignals,
  isToolFailure,
  discoverPreservedArtifacts,
  checkModeJustCompleted,
  checkArchitectJustVerified,
} from './triggers.js';
