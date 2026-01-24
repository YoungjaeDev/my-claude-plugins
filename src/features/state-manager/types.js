"use strict";
/**
 * State Manager Types
 *
 * Type definitions for unified state management across
 * local (.omc/state/) and global (~/.omc/state/) locations.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.DEFAULT_STATE_CONFIG = exports.StateLocation = void 0;
exports.isStateLocation = isStateLocation;
/**
 * Location where state should be stored
 */
var StateLocation;
(function (StateLocation) {
    /** Local project state: .omc/state/{name}.json */
    StateLocation["LOCAL"] = "local";
    /** Global user state: ~/.omc/state/{name}.json */
    StateLocation["GLOBAL"] = "global";
})(StateLocation || (exports.StateLocation = StateLocation = {}));
/**
 * Type guard for StateLocation
 */
function isStateLocation(value) {
    return value === StateLocation.LOCAL || value === StateLocation.GLOBAL;
}
/**
 * Default state configuration
 */
exports.DEFAULT_STATE_CONFIG = {
    createDirs: true,
    checkLegacy: true
};
