-- fnox-export: a mise environment plugin that exports scoped fnox secrets
-- into mise environment variables using a flat, from-based grammar.
--
-- The plugin performs one batched `fnox export --format json` per profile and
-- filters the result locally.
--
-- The plugin is generic and public-safe: it contains no secret names, provider
-- names, or personal data. The `profiles`, `export` list, and transforms all
-- live in the consuming project's mise.toml.

local cmd = require("cmd")
local util = require("fnox_export_util")
local parser = require("fnox_export_parser")
local fnox = require("fnox_export_fnox")
local apply = require("fnox_export_apply")

local function normalize_profiles(opts)
    local profile_single = opts.profile
    local profiles = opts.profiles

    if profile_single ~= nil and profiles ~= nil then
        error("fnox-export: cannot set both 'profile' and 'profiles'")
    end

    if profiles ~= nil then
        if type(profiles) == "string" then
            profiles = { profiles }
        end
        if type(profiles) ~= "table" then
            error("fnox-export: 'profiles' must be a string or array of strings")
        end
        for _, p in ipairs(profiles) do
            if type(p) ~= "string" then
                error("fnox-export: 'profiles' must contain only strings")
            end
        end
    else
        profiles = {}
    end

    if profile_single ~= nil then
        if type(profile_single) ~= "string" then
            error("fnox-export: 'profile' must be a string")
        end
        profiles = { profile_single }
    end

    return profiles
end

local function normalize_export_list(opts)
    local export_list = opts.export
    if export_list ~= nil then
        if type(export_list) == "string" then
            export_list = { export_list }
        end
        if type(export_list) ~= "table" then
            error("fnox-export: 'export' must be a string or array")
        end
    end
    return export_list
end

local function collect_watch_files(fnox_bin, config, profiles, no_defaults)
    local watch_files = {}
    if util.is_nonempty(config) then
        watch_files[#watch_files + 1] = config
        return watch_files
    end

    local watch_prof = #profiles > 0 and profiles[1] or nil
    local ok, out = pcall(cmd.exec,
        fnox.build_fnox_cmd(fnox_bin, nil, watch_prof, no_defaults, "config-files"))
    if ok and util.is_nonempty(out) then
        for _, line in ipairs(util.split_lines(out)) do
            watch_files[#watch_files + 1] = line
        end
    end

    watch_files[#watch_files + 1] = "fnox.toml"
    watch_files[#watch_files + 1] = "fnox.local.toml"
    for _, prof in ipairs(profiles) do
        if util.is_nonempty(prof) then
            watch_files[#watch_files + 1] = "fnox." .. prof .. ".toml"
            watch_files[#watch_files + 1] = "fnox." .. prof .. ".local.toml"
        end
    end
    return watch_files
end

function PLUGIN:MiseEnv(ctx)
    local opts = ctx.options or {}
    local fnox_bin = util.is_nonempty(opts.fnox_bin) and opts.fnox_bin or "fnox"
    local config = opts.config
    local profiles = normalize_profiles(opts)

    local on_missing = util.validate_level("on_missing", opts.on_missing or "silent")
    local on_failure = util.validate_level("on_failure", opts.on_failure or "warn")

    if opts.fetch ~= nil then
        error("fnox-export: unsupported option 'fetch'; fnox-export always uses batched export")
    end

    local no_defaults = opts.no_defaults
    if no_defaults == nil then
        no_defaults = #profiles > 0 or util.is_nonempty(config)
    end

    local on_conflict = opts.on_conflict or "last"
    if on_conflict ~= "last" and on_conflict ~= "first" and on_conflict ~= "error" then
        error("fnox-export: invalid on_conflict value '" .. tostring(opts.on_conflict) .. "'")
    end

    local export_list = normalize_export_list(opts)
    local entries = nil
    local export_all_mode = false

    if export_list ~= nil and #export_list > 0 then
        entries = parser.parse_export_entries(export_list, on_missing)
    elseif #profiles > 0 or util.is_nonempty(config) then
        export_all_mode = true
    else
        if not opts.unsafe_default_all then
            return util.make_result(false, { "fnox.toml", "fnox.local.toml" }, {})
        end
        export_all_mode = true
    end

    local watch_files = collect_watch_files(fnox_bin, config, profiles, no_defaults)
    local profiles_to_run = #profiles > 0 and profiles or { "" }

    local source_map, had_failure = fnox.batch_fetch(fnox_bin, config,
        profiles_to_run, no_defaults, on_conflict, on_failure)

    local env_vars
    if export_all_mode then
        env_vars = apply.export_all(source_map)
    else
        env_vars = apply.apply_entries(entries, source_map, opts.keep_mapped == true)
    end

    return util.make_result(not had_failure, watch_files, env_vars)
end
