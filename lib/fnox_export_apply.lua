local util = require("fnox_export_util")
local parser = require("fnox_export_parser")

local M = {}

local function apply_transform_name(src_name, transform)
    local out = src_name
    if transform.strip_prefix ~= nil then
        out = out:gsub("^" .. util.pat_escape(transform.strip_prefix), "")
    end
    if transform.replace_prefix ~= nil then
        local old_p = transform.replace_prefix[1]
        local new_p = transform.replace_prefix[2]
        out = out:gsub("^" .. util.pat_escape(old_p), util.repl_escape(new_p))
    end
    if transform.prefix ~= nil then
        out = transform.prefix .. out
    end
    return out
end

local function add_env(env_vars, env_keys, key, value)
    if not env_keys[key] then
        env_vars[#env_vars + 1] = { key = key, value = value }
        env_keys[key] = true
    end
end

function M.apply_entries(entries, source_map, keep_mapped)
    local env_vars = {}
    local env_keys = {}
    local mapped_sources = {}

    -- Process explicit mappings first so mapped source keys are dropped from
    -- later pass-through selectors unless keep_mapped = true.
    for _, entry in ipairs(entries) do
        if parser.is_mapping_entry(entry) then
            mapped_sources[entry.from] = true
            local value = source_map[entry.from]
            if value ~= nil then
                add_env(env_vars, env_keys, entry.to, value)
            else
                util.handle_level(entry.on_missing, "fnox-export: source key "
                    .. entry.from .. " not found for output " .. entry.to
                    .. " (on_missing=" .. entry.on_missing .. ")")
            end
        end
    end

    for _, entry in ipairs(entries) do
        if parser.is_transform_entry(entry) then
            local matched = false
            for src_key, value in pairs(source_map) do
                if util.glob_match(entry.from, src_key) then
                    matched = true
                    mapped_sources[src_key] = true
                    local out_name = apply_transform_name(src_key, entry)
                    if not util.is_valid_env_name(out_name) then
                        error("fnox-export: transform produced invalid env var name '"
                            .. out_name .. "' from source '" .. src_key .. "'")
                    end
                    add_env(env_vars, env_keys, out_name, value)
                end
            end
            if not matched and entry.from ~= "*" then
                util.handle_level(entry.on_missing, "fnox-export: transform 'from' pattern '"
                    .. entry.from .. "' matched no source keys (on_missing="
                    .. entry.on_missing .. ")")
            end
        end
    end

    for _, entry in ipairs(entries) do
        if parser.is_selector_entry(entry) then
            local matched = false
            for src_key, value in pairs(source_map) do
                if util.glob_match(entry.from, src_key) then
                    matched = true
                    if not mapped_sources[src_key] or keep_mapped then
                        add_env(env_vars, env_keys, src_key, value)
                    end
                end
            end
            if not matched and entry.from ~= "*" then
                util.handle_level(entry.on_missing, "fnox-export: selector '"
                    .. entry.from .. "' matched no source keys (on_missing="
                    .. entry.on_missing .. ")")
            end
        end
    end

    return env_vars
end

function M.export_all(source_map)
    local env_vars = {}
    local env_keys = {}
    for key, value in pairs(source_map) do
        add_env(env_vars, env_keys, key, value)
    end
    return env_vars
end

return M
