local cmd = require("cmd")
local json = require("json")
local util = require("fnox_export_util")

local M = {}

function M.build_fnox_cmd(fnox_bin, config, profile, no_defaults, subcommand)
    local parts = { fnox_bin }
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

function M.batch_fetch(fnox_bin, config, profiles_to_run, no_defaults, on_conflict, on_failure)
    local source_map = {}
    local source_profile = {}
    local had_failure = false

    for _, prof in ipairs(profiles_to_run) do
        local cmd_str = M.build_fnox_cmd(fnox_bin, config, prof, no_defaults,
            "export --format json")
        local ok, out = pcall(cmd.exec, cmd_str)
        if not ok then
            had_failure = true
            util.handle_level(on_failure, "fnox-export: fnox export failed for profile "
                .. M.profile_name(prof) .. " (on_failure=" .. on_failure .. ")")
        else
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
