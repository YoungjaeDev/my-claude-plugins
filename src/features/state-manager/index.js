"use strict";
/**
 * State Manager
 *
 * Unified state management that standardizes state file locations:
 * - Local state: .omc/state/{name}.json
 * - Global state: ~/.omc/state/{name}.json
 *
 * Features:
 * - Type-safe read/write operations
 * - Auto-create directories
 * - Legacy location support (for migration)
 * - State cleanup utilities
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.isStateLocation = exports.DEFAULT_STATE_CONFIG = exports.StateLocation = exports.StateManager = void 0;
exports.getStatePath = getStatePath;
exports.getLegacyPaths = getLegacyPaths;
exports.ensureStateDir = ensureStateDir;
exports.readState = readState;
exports.writeState = writeState;
exports.clearState = clearState;
exports.migrateState = migrateState;
exports.listStates = listStates;
exports.cleanupOrphanedStates = cleanupOrphanedStates;
exports.createStateManager = createStateManager;
var fs = require("fs");
var path = require("path");
var os = require("os");
var types_js_1 = require("./types.js");
// Standard state directories
var LOCAL_STATE_DIR = '.omc/state';
var GLOBAL_STATE_DIR = path.join(os.homedir(), '.omc', 'state');
// Legacy state locations (for backward compatibility)
var LEGACY_LOCATIONS = {
    // Example legacy locations that might exist
    'boulder': ['.omc/boulder.json', path.join(os.homedir(), '.omc', 'boulder.json')],
    'autopilot': ['.omc/autopilot-state.json'],
    'ralph': ['.omc/ralph-state.json'],
    'ultrawork': ['.omc/ultrawork-state.json'],
    'ultraqa': ['.omc/ultraqa-state.json']
};
/**
 * Get the standard path for a state file
 */
function getStatePath(name, location) {
    var baseDir = location === types_js_1.StateLocation.LOCAL ? LOCAL_STATE_DIR : GLOBAL_STATE_DIR;
    return path.join(baseDir, "".concat(name, ".json"));
}
/**
 * Get legacy paths for a state file (for migration)
 */
function getLegacyPaths(name) {
    return LEGACY_LOCATIONS[name] || [];
}
/**
 * Ensure state directory exists
 */
function ensureStateDir(location) {
    var dir = location === types_js_1.StateLocation.LOCAL ? LOCAL_STATE_DIR : GLOBAL_STATE_DIR;
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
}
/**
 * Read state from file
 *
 * Checks standard location first, then legacy locations if enabled.
 * Returns both the data and where it was found.
 */
function readState(name, location, options) {
    var _a;
    if (location === void 0) { location = types_js_1.StateLocation.LOCAL; }
    var checkLegacy = (_a = options === null || options === void 0 ? void 0 : options.checkLegacy) !== null && _a !== void 0 ? _a : types_js_1.DEFAULT_STATE_CONFIG.checkLegacy;
    var standardPath = getStatePath(name, location);
    var legacyPaths = checkLegacy ? getLegacyPaths(name) : [];
    // Try standard location first
    if (fs.existsSync(standardPath)) {
        try {
            var content = fs.readFileSync(standardPath, 'utf-8');
            var data = JSON.parse(content);
            return {
                exists: true,
                data: data,
                foundAt: standardPath,
                legacyLocations: []
            };
        }
        catch (error) {
            // Invalid JSON or read error - treat as not found
            console.warn("Failed to read state from ".concat(standardPath, ":"), error);
        }
    }
    // Try legacy locations
    if (checkLegacy) {
        for (var _i = 0, legacyPaths_1 = legacyPaths; _i < legacyPaths_1.length; _i++) {
            var legacyPath = legacyPaths_1[_i];
            // Resolve relative paths
            var resolvedPath = path.isAbsolute(legacyPath)
                ? legacyPath
                : path.join(process.cwd(), legacyPath);
            if (fs.existsSync(resolvedPath)) {
                try {
                    var content = fs.readFileSync(resolvedPath, 'utf-8');
                    var data = JSON.parse(content);
                    return {
                        exists: true,
                        data: data,
                        foundAt: resolvedPath,
                        legacyLocations: legacyPaths
                    };
                }
                catch (error) {
                    console.warn("Failed to read legacy state from ".concat(resolvedPath, ":"), error);
                }
            }
        }
    }
    return {
        exists: false,
        legacyLocations: checkLegacy ? legacyPaths : []
    };
}
/**
 * Write state to file
 *
 * Always writes to the standard location.
 * Creates directories if they don't exist.
 */
function writeState(name, data, location, options) {
    var _a;
    if (location === void 0) { location = types_js_1.StateLocation.LOCAL; }
    var createDirs = (_a = options === null || options === void 0 ? void 0 : options.createDirs) !== null && _a !== void 0 ? _a : types_js_1.DEFAULT_STATE_CONFIG.createDirs;
    var statePath = getStatePath(name, location);
    try {
        // Ensure directory exists
        if (createDirs) {
            ensureStateDir(location);
        }
        // Write state
        var content = JSON.stringify(data, null, 2);
        fs.writeFileSync(statePath, content, 'utf-8');
        return {
            success: true,
            path: statePath
        };
    }
    catch (error) {
        return {
            success: false,
            path: statePath,
            error: error instanceof Error ? error.message : String(error)
        };
    }
}
/**
 * Clear state from all locations (standard + legacy)
 *
 * Removes the state file from both standard and legacy locations.
 * Returns information about what was removed.
 */
function clearState(name, location) {
    var result = {
        removed: [],
        notFound: [],
        errors: []
    };
    // Determine which locations to check
    var locationsToCheck = location
        ? [location]
        : [types_js_1.StateLocation.LOCAL, types_js_1.StateLocation.GLOBAL];
    // Remove from standard locations
    for (var _i = 0, locationsToCheck_1 = locationsToCheck; _i < locationsToCheck_1.length; _i++) {
        var loc = locationsToCheck_1[_i];
        var standardPath = getStatePath(name, loc);
        try {
            if (fs.existsSync(standardPath)) {
                fs.unlinkSync(standardPath);
                result.removed.push(standardPath);
            }
            else {
                result.notFound.push(standardPath);
            }
        }
        catch (error) {
            result.errors.push({
                path: standardPath,
                error: error instanceof Error ? error.message : String(error)
            });
        }
    }
    // Remove from legacy locations
    var legacyPaths = getLegacyPaths(name);
    for (var _a = 0, legacyPaths_2 = legacyPaths; _a < legacyPaths_2.length; _a++) {
        var legacyPath = legacyPaths_2[_a];
        var resolvedPath = path.isAbsolute(legacyPath)
            ? legacyPath
            : path.join(process.cwd(), legacyPath);
        try {
            if (fs.existsSync(resolvedPath)) {
                fs.unlinkSync(resolvedPath);
                result.removed.push(resolvedPath);
            }
            else {
                result.notFound.push(resolvedPath);
            }
        }
        catch (error) {
            result.errors.push({
                path: resolvedPath,
                error: error instanceof Error ? error.message : String(error)
            });
        }
    }
    return result;
}
/**
 * Migrate state from legacy location to standard location
 *
 * Finds state in legacy locations and moves it to the standard location.
 * Deletes the legacy file after successful migration.
 */
function migrateState(name, location) {
    if (location === void 0) { location = types_js_1.StateLocation.LOCAL; }
    // Check if already in standard location
    var standardPath = getStatePath(name, location);
    if (fs.existsSync(standardPath)) {
        return {
            migrated: false
        };
    }
    // Look for legacy state
    var readResult = readState(name, location, { checkLegacy: true });
    if (!readResult.exists || !readResult.foundAt || !readResult.data) {
        return {
            migrated: false,
            error: 'No legacy state found'
        };
    }
    // Check if it's actually from a legacy location
    var isLegacy = readResult.foundAt !== standardPath;
    if (!isLegacy) {
        return {
            migrated: false
        };
    }
    // Write to standard location
    var writeResult = writeState(name, readResult.data, location);
    if (!writeResult.success) {
        return {
            migrated: false,
            error: "Failed to write to standard location: ".concat(writeResult.error)
        };
    }
    // Delete legacy file
    try {
        fs.unlinkSync(readResult.foundAt);
    }
    catch (error) {
        // Migration succeeded but cleanup failed - not critical
        console.warn("Failed to delete legacy state at ".concat(readResult.foundAt, ":"), error);
    }
    return {
        migrated: true,
        from: readResult.foundAt,
        to: writeResult.path
    };
}
/**
 * List all state files
 *
 * Returns information about all state files in the specified location(s).
 */
function listStates(options) {
    var _a;
    var results = [];
    var includeLegacy = (_a = options === null || options === void 0 ? void 0 : options.includeLegacy) !== null && _a !== void 0 ? _a : false;
    var pattern = options === null || options === void 0 ? void 0 : options.pattern;
    // Helper to check if name matches pattern
    var matchesPattern = function (name) {
        if (!pattern)
            return true;
        // Simple glob: * matches anything
        var regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
        return regex.test(name);
    };
    // Helper to add state files from a directory
    var addStatesFromDir = function (dir, location, isLegacy) {
        if (isLegacy === void 0) { isLegacy = false; }
        if (!fs.existsSync(dir))
            return;
        try {
            var files = fs.readdirSync(dir);
            for (var _i = 0, files_1 = files; _i < files_1.length; _i++) {
                var file = files_1[_i];
                if (!file.endsWith('.json'))
                    continue;
                var name_1 = file.slice(0, -5); // Remove .json
                if (!matchesPattern(name_1))
                    continue;
                var filePath = path.join(dir, file);
                var stats = fs.statSync(filePath);
                results.push({
                    name: name_1,
                    path: filePath,
                    location: location,
                    size: stats.size,
                    modified: stats.mtime,
                    isLegacy: isLegacy
                });
            }
        }
        catch (error) {
            console.warn("Failed to list states from ".concat(dir, ":"), error);
        }
    };
    // Check standard locations
    if (!(options === null || options === void 0 ? void 0 : options.location) || options.location === types_js_1.StateLocation.LOCAL) {
        addStatesFromDir(LOCAL_STATE_DIR, types_js_1.StateLocation.LOCAL);
    }
    if (!(options === null || options === void 0 ? void 0 : options.location) || options.location === types_js_1.StateLocation.GLOBAL) {
        addStatesFromDir(GLOBAL_STATE_DIR, types_js_1.StateLocation.GLOBAL);
    }
    // Check legacy locations if requested
    if (includeLegacy) {
        // Add logic to scan legacy locations
        // This would require knowing all possible legacy locations
        // For now, we skip this as legacy locations are name-specific
    }
    return results;
}
/**
 * Cleanup orphaned state files
 *
 * Removes state files that haven't been modified in a long time.
 * Useful for cleaning up abandoned states.
 */
function cleanupOrphanedStates(options) {
    var _a, _b, _c, _d;
    var maxAgeDays = (_a = options === null || options === void 0 ? void 0 : options.maxAgeDays) !== null && _a !== void 0 ? _a : 30;
    var dryRun = (_b = options === null || options === void 0 ? void 0 : options.dryRun) !== null && _b !== void 0 ? _b : false;
    var exclude = (_c = options === null || options === void 0 ? void 0 : options.exclude) !== null && _c !== void 0 ? _c : [];
    var result = {
        deleted: [],
        wouldDelete: dryRun ? [] : undefined,
        spaceFreed: 0,
        errors: []
    };
    var cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - maxAgeDays);
    var states = listStates({ includeLegacy: false });
    var _loop_1 = function (state) {
        // Skip excluded patterns
        if (exclude.some(function (pattern) {
            var regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
            return regex.test(state.name);
        })) {
            return "continue";
        }
        // Check if old enough
        if (state.modified > cutoffDate) {
            return "continue";
        }
        // Delete or record for dry run
        if (dryRun) {
            (_d = result.wouldDelete) === null || _d === void 0 ? void 0 : _d.push(state.path);
            result.spaceFreed += state.size;
        }
        else {
            try {
                fs.unlinkSync(state.path);
                result.deleted.push(state.path);
                result.spaceFreed += state.size;
            }
            catch (error) {
                result.errors.push({
                    path: state.path,
                    error: error instanceof Error ? error.message : String(error)
                });
            }
        }
    };
    for (var _i = 0, states_1 = states; _i < states_1.length; _i++) {
        var state = states_1[_i];
        _loop_1(state);
    }
    return result;
}
/**
 * State Manager Class
 *
 * Object-oriented interface for managing a specific state.
 */
var StateManager = /** @class */ (function () {
    function StateManager(name, location) {
        if (location === void 0) { location = types_js_1.StateLocation.LOCAL; }
        this.name = name;
        this.location = location;
    }
    StateManager.prototype.read = function (options) {
        return readState(this.name, this.location, options);
    };
    StateManager.prototype.write = function (data, options) {
        return writeState(this.name, data, this.location, options);
    };
    StateManager.prototype.clear = function () {
        return clearState(this.name, this.location);
    };
    StateManager.prototype.migrate = function () {
        return migrateState(this.name, this.location);
    };
    StateManager.prototype.exists = function () {
        return this.read({ checkLegacy: false }).exists;
    };
    StateManager.prototype.get = function () {
        return this.read().data;
    };
    StateManager.prototype.set = function (data) {
        return this.write(data).success;
    };
    StateManager.prototype.update = function (updater) {
        var current = this.get();
        var updated = updater(current);
        return this.set(updated);
    };
    return StateManager;
}());
exports.StateManager = StateManager;
/**
 * Create a state manager for a specific state
 */
function createStateManager(name, location) {
    if (location === void 0) { location = types_js_1.StateLocation.LOCAL; }
    return new StateManager(name, location);
}
// Re-export enum, constants, and functions from types
var types_js_2 = require("./types.js");
Object.defineProperty(exports, "StateLocation", { enumerable: true, get: function () { return types_js_2.StateLocation; } });
Object.defineProperty(exports, "DEFAULT_STATE_CONFIG", { enumerable: true, get: function () { return types_js_2.DEFAULT_STATE_CONFIG; } });
Object.defineProperty(exports, "isStateLocation", { enumerable: true, get: function () { return types_js_2.isStateLocation; } });
