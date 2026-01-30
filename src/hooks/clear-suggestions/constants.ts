/**
 * Clear Suggestions Constants
 *
 * Messages, thresholds, and configuration defaults for the
 * adaptive /clear suggestions system.
 */

/**
 * Cooldown period between clear suggestions (5 minutes)
 */
export const CLEAR_SUGGESTION_COOLDOWN_MS = 5 * 60 * 1000;

/**
 * Maximum suggestions per session
 */
export const MAX_CLEAR_SUGGESTIONS = 2;

/**
 * Context usage threshold to trigger context+artifacts suggestion (50%)
 */
export const CONTEXT_THRESHOLD = 0.50;

/**
 * Consecutive failure count for degradation signal
 */
export const FAILURE_THRESHOLD = 3;

/**
 * Failure window - only count failures within this window (10 minutes)
 */
export const FAILURE_WINDOW_MS = 10 * 60 * 1000;

/**
 * Message for workflow completion trigger
 */
export const WORKFLOW_COMPLETE_MESSAGE = (modeName: string, artifacts: string): string =>
  `SESSION RESET SUGGESTION

The **${modeName}** workflow has completed successfully. Starting fresh with /clear would give you:
- A clean context window for your next task
- Faster, more reliable responses
- No stale context from the completed workflow

${artifacts}
Type **/clear** to start fresh, or continue working in this session.
`;

/**
 * Message for architect verification trigger
 */
export const ARCHITECT_VERIFIED_MESSAGE = (artifacts: string): string =>
  `SESSION RESET SUGGESTION

Architect verification has **passed** - your work is approved. This is an ideal moment to reset:
- The verification cycle consumed significant context
- Your completed work is saved in project files
- A fresh session will be more responsive for the next task

${artifacts}
Type **/clear** to start fresh, or continue working in this session.
`;

/**
 * Message for planning complete trigger
 */
export const PLANNING_COMPLETE_MESSAGE = (artifacts: string): string =>
  `SESSION RESET SUGGESTION

Planning is **complete** and your plan has been saved to disk. Consider resetting:
- The planning interview used substantial context
- Your plan files are preserved and will be auto-loaded
- Execution will be more reliable in a fresh session

${artifacts}
Type **/clear** to start fresh, or continue working in this session.
`;

/**
 * Message for context+artifacts trigger
 */
export const CONTEXT_ARTIFACTS_MESSAGE = (usagePct: number, artifacts: string): string =>
  `SESSION RESET SUGGESTION

Context usage is at **${usagePct}%** but your progress is safely preserved in project files. Consider resetting:
- High context usage can cause degraded performance
- /clear reloads your CLAUDE.md and project context automatically
- Your artifacts will be available in the new session

${artifacts}
Type **/clear** to start fresh, or use **/compact** if you want to continue this session.
`;

/**
 * Message for degradation signals trigger
 */
export const DEGRADATION_SIGNALS_MESSAGE = (failureCount: number, artifacts: string): string =>
  `SESSION RESET SUGGESTION

Detected **${failureCount} consecutive failures** which may indicate context degradation. A fresh start could help:
- Accumulated context can cause tool call failures
- /clear gives you a clean slate while preserving all files
- Your work is saved on disk and will not be lost

${artifacts}
Type **/clear** to start fresh, or continue troubleshooting in this session.
`;

/**
 * Format preserved artifacts into a readable list
 */
export function formatPreservedArtifacts(
  artifacts: Array<{ type: string; description: string }>
): string {
  if (artifacts.length === 0) {
    return '';
  }

  const lines = artifacts.map(a => `  - ${a.description}`);
  return `**Preserved artifacts** (available after /clear):\n${lines.join('\n')}\n`;
}
