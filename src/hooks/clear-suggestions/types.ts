/**
 * Clear Suggestions Types
 *
 * Type definitions for the adaptive /clear suggestions system that
 * intelligently recommends session resets when it would improve
 * reliability and performance.
 */

import type { ExecutionMode } from '../mode-registry/types.js';

/**
 * Trigger types for clear suggestions
 */
export type ClearSuggestionTrigger =
  | 'workflow_complete'     // After ralph/autopilot/ultrawork finishes
  | 'architect_verified'    // After architect approval passes
  | 'planning_complete'     // After ralplan/plan skill completes
  | 'context_artifacts'     // High context but plan files exist to reload
  | 'degradation_signals';  // 3+ consecutive failures detected

/**
 * State tracking for clear suggestions within a session
 */
export interface ClearSuggestionState {
  /** Session ID being tracked */
  sessionId: string;
  /** Timestamp of last suggestion shown */
  lastSuggestionTime: number;
  /** Number of suggestions shown this session */
  suggestionCount: number;
  /** Recent failure count for degradation detection */
  consecutiveFailures: number;
  /** Timestamps of recent failures */
  failureTimestamps: number[];
  /** Whether a workflow just completed */
  workflowJustCompleted?: ExecutionMode;
  /** Whether architect just verified */
  architectJustVerified?: boolean;
  /** Whether planning just completed */
  planningJustCompleted?: boolean;
}

/**
 * Configuration for clear suggestions
 */
export interface ClearSuggestionConfig {
  /** Enable clear suggestions (default: true) */
  enabled?: boolean;
  /** Cooldown period in ms between suggestions (default: 300000 = 5 minutes) */
  cooldownMs?: number;
  /** Maximum suggestions per session (default: 2) */
  maxSuggestions?: number;
  /** Context usage threshold (default: 0.50 = 50%) */
  contextThreshold?: number;
  /** Consecutive failures threshold for degradation (default: 3) */
  failureThreshold?: number;
  /** Custom message template */
  customMessage?: string;
}

/**
 * Artifact that would be preserved after clear
 */
export interface PreservedArtifact {
  /** Type of artifact */
  type: 'plan' | 'prd' | 'spec' | 'progress' | 'notepad' | 'decision' | 'learning' | 'issue';
  /** Path to the artifact file */
  path: string;
  /** Human-readable description */
  description: string;
}

/**
 * Result from checking clear suggestion triggers
 */
export interface ClearSuggestionResult {
  /** Whether to show a suggestion */
  shouldSuggest: boolean;
  /** Which trigger fired (if any) */
  trigger?: ClearSuggestionTrigger;
  /** The suggestion message to show */
  message?: string;
  /** List of artifacts that would be preserved */
  preservedArtifacts?: PreservedArtifact[];
  /** Reason for not suggesting (for debugging) */
  skipReason?: string;
}

/**
 * Input for clear suggestion hook
 */
export interface ClearSuggestionInput {
  /** Session ID */
  sessionId: string;
  /** Working directory */
  directory: string;
  /** Tool name that just executed */
  toolName?: string;
  /** Tool output (for failure detection) */
  toolOutput?: string;
  /** Estimated context usage ratio (0-1) */
  contextUsageRatio?: number;
}
