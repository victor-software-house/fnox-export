local cmd = require("cmd")
local json = require("json")
local util = require("fnox_export_util")

local M = {}

-- Set on every fnox call the plugin spawns. When `fnox` on PATH is a mise shim,
-- that call is mise again, which evaluates the env and runs this plugin; the
-- hook sees this variable and spawns nothing, so the recursion stops at one level.
M.ACTIVE_ENV = "__FNOX_EXPORT_ACTIVE"

function M.build_fnox_cmd(fnox_bin, config, profile, no_defaults, subcommand, daemon)
    local parts = { M.ACTIVE_ENV .. "=1" }
    -- Force fnox's per-user daemon on. The plugin invokes `fnox -c <path>`,
    -- whose single-file load does not merge the global fnox config, so the
    -- daemon (configured there) is otherwise skipped and every resolution pays
    -- a full provider round trip. FNOX_DAEMON=on (fnox reads it before the
    -- config) makes repeated/offsite resolutions hit the in-memory cache.
    if daemon then
        parts[#parts + 1] = "FNOX_DAEMON=on"
    end
    parts[#parts + 1] = fnox_bin
    if util.is_nonempty(config) then
        parts[#parts + 1] = "-c " .. util.shell_quote(config)
    end
    if profile and util.is_nonempty(profile) then
        parts[#parts + 1] = "-P " .. util.shell_quote(profile)
    end
    if no_defaults then
        parts[#parts + 1] = "--no-defaults"
    end
    parts[#parts + 1] = subcommand
    return table.concat(parts, " ")
end

function M.profile_name(prof)
    return (util.is_nonempty(prof)) and prof or "default"
end

local function merge_source(source_map, source_profile, key, value, prof, on_conflict)
    if source_map[key] ~= nil then
        local prev = source_profile[key]
        local cur = M.profile_name(prof)
        if on_conflict == "error" then
            error("fnox-export: duplicate source key " .. key
                .. " from profiles " .. prev .. " and " .. cur)
        elseif on_conflict == "first" then
            return
        end
    end
    source_map[key] = value
    source_profile[key] = M.profile_name(prof)
end

-- Keys a profile defines, from `fnox list`, which resolves no secret. The first
-- line is the table header (or a notice for an empty profile); each row starts
-- with one space and the key, while a wrapped description continues on a line
-- indented further.
local function parse_list_keys(out)
    local keys = {}
    local first = true
    for line in out:gmatch("[^\r\n]+") do
        if first then
            first = false
        else
            local key = line:match("^ (%S+)")
            if key ~= nil then
                keys[key] = true
            end
        end
    end
    return keys
end

-- The wanted keys the profile defines, in wanted order. `fnox export KEY...`
-- fails the whole call on a key the profile lacks, so only defined keys go in.
local function defined_keys(fnox_bin, config, prof, no_defaults, wanted)
    local out = cmd.exec(M.build_fnox_cmd(fnox_bin, config, prof, no_defaults, "list"))
    local defined = parse_list_keys(out)
    local present = {}
    for _, key in ipairs(wanted) do
        if defined[key] then
            present[#present + 1] = key
        end
    end
    return present
end

local function export_subcommand(keys)
    local parts = { "export --format json" }
    for _, key in ipairs(keys or {}) do
        parts[#parts + 1] = util.shell_quote(key)
    end
    return table.concat(parts, " ")
end

-- Runs the export for one profile. Returns false and the error on failure, true
-- and the JSON text on success, and true with nil when `wanted` names keys but
-- the profile defines none of them.
local function export_profile(fnox_bin, config, prof, no_defaults, daemon, wanted)
    local keys = nil
    if wanted ~= nil then
        local ok, result = pcall(defined_keys, fnox_bin, config, prof, no_defaults, wanted)
        if not ok then
            return false, result
        end
        -- `fnox export` with no KEY resolves the whole profile, so never run it empty.
        if #result == 0 then
            return true, nil
        end
        keys = result
    end
    return pcall(cmd.exec, M.build_fnox_cmd(fnox_bin, config, prof, no_defaults,
        export_subcommand(keys), daemon))
end

-- `wanted` is a list of source names to resolve, or nil for the whole profile.
function M.batch_fetch(fnox_bin, config, profiles_to_run, no_defaults, on_conflict, on_failure, daemon, wanted)
    local source_map = {}
    local source_profile = {}
    local had_failure = false

    for _, prof in ipairs(profiles_to_run) do
        local ok, out = export_profile(fnox_bin, config, prof, no_defaults, daemon, wanted)
        if not ok then
            had_failure = true
            util.handle_level(on_failure, "fnox-export: fnox export failed for profile "
                .. M.profile_name(prof) .. " (on_failure=" .. on_failure .. ")")
        elseif out ~= nil then
            local dec_ok, data = pcall(json.decode, out)
            if not dec_ok or type(data) ~= "table" or type(data.secrets) ~= "table" then
                had_failure = true
                util.handle_level(on_failure, "fnox-export: could not parse fnox export output for profile "
                    .. M.profile_name(prof) .. " (on_failure=" .. on_failure .. ")")
            else
                for key, value in pairs(data.secrets) do
                    merge_source(source_map, source_profile, key, value, prof, on_conflict)
                end
            end
        end
    end

    return source_map, had_failure
end

return M
