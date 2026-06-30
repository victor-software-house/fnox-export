local util = require("fnox_export_util")

local M = {}

local ENTRY_KEYS = {
    from = true,
    to = true,
    strip_prefix = true,
    replace_prefix = true,
    prefix = true,
    on_missing = true,
}

function M.has_transform(entry)
    return entry.strip_prefix ~= nil or entry.replace_prefix ~= nil or entry.prefix ~= nil
end

local function validate_optional_string(entry_idx, name, value)
    if value ~= nil and type(value) ~= "string" then
        error("fnox-export: invalid export entry " .. entry_idx
            .. ": '" .. name .. "' must be a string")
    end
end

local function normalize_entry(entry, idx, global_on_missing)
    if type(entry) == "string" then
        if entry == "" then
            error("fnox-export: invalid export entry " .. idx .. ": selector must not be empty")
        end
        return { from = entry, on_missing = global_on_missing }
    end

    if type(entry) ~= "table" then
        error("fnox-export: invalid export entry " .. idx
            .. ": expected string or table, got " .. type(entry))
    end

    for k in pairs(entry) do
        if not ENTRY_KEYS[k] then
            error("fnox-export: invalid export entry " .. idx
                .. ": unsupported key '" .. tostring(k) .. "'")
        end
    end

    if type(entry.from) ~= "string" or entry.from == "" then
        error("fnox-export: invalid export entry " .. idx
            .. ": 'from' is required and must be a non-empty string")
    end

    validate_optional_string(idx, "to", entry.to)
    validate_optional_string(idx, "strip_prefix", entry.strip_prefix)
    validate_optional_string(idx, "prefix", entry.prefix)

    if entry.replace_prefix ~= nil then
        if type(entry.replace_prefix) ~= "table" or #entry.replace_prefix ~= 2 then
            error("fnox-export: invalid export entry " .. idx
                .. ": 'replace_prefix' must be a two-item array [old, new]")
        end
        if type(entry.replace_prefix[1]) ~= "string" or type(entry.replace_prefix[2]) ~= "string" then
            error("fnox-export: invalid export entry " .. idx
                .. ": 'replace_prefix' values must be strings")
        end
    end

    if entry.to ~= nil then
        if not util.is_valid_env_name(entry.to) then
            error("fnox-export: invalid export entry " .. idx
                .. ": to target '" .. entry.to
                .. "' must match [A-Z_][A-Z0-9_]*")
        end
        if M.has_transform(entry) then
            error("fnox-export: invalid export entry " .. idx
                .. ": cannot mix 'to' with transform actions")
        end
    end

    local entry_on_missing = global_on_missing
    if entry.on_missing ~= nil then
        entry_on_missing = util.validate_level("on_missing", entry.on_missing)
    end

    return {
        from = entry.from,
        to = entry.to,
        strip_prefix = entry.strip_prefix,
        replace_prefix = entry.replace_prefix,
        prefix = entry.prefix,
        on_missing = entry_on_missing,
    }
end

function M.parse_export_entries(export_list, global_on_missing)
    local entries = {}
    for idx, entry in ipairs(export_list) do
        entries[#entries + 1] = normalize_entry(entry, idx, global_on_missing)
    end
    return entries
end

function M.is_transform_entry(entry)
    return entry.to == nil and M.has_transform(entry)
end

function M.is_selector_entry(entry)
    return entry.to == nil and not M.has_transform(entry)
end

function M.is_mapping_entry(entry)
    return entry.to ~= nil
end

return M
