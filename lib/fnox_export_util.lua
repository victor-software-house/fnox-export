local log = require("log")

local M = {}

function M.is_nonempty(s)
    return type(s) == "string" and s ~= ""
end

function M.shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function M.split_lines(s)
    local out = {}
    for line in s:gmatch("[^\r\n]+") do
        out[#out + 1] = line
    end
    return out
end

function M.make_result(cacheable, watch_files, env)
    return {
        cacheable = cacheable,
        watch_files = watch_files,
        redact = true,
        env = env,
    }
end

function M.pat_escape(s)
    return (s:gsub("[%%%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"))
end

function M.repl_escape(s)
    return (s:gsub("%%", "%%%%"))
end

function M.has_wildcard(glob)
    return glob:find("*", 1, true) ~= nil
end

function M.glob_match(glob, key)
    if glob == "*" then
        return true
    end
    if not M.has_wildcard(glob) then
        return glob == key
    end
    local pattern = "^"
    for i = 1, #glob do
        local ch = glob:sub(i, i)
        if ch == "*" then
            pattern = pattern .. ".*"
        else
            pattern = pattern .. M.pat_escape(ch)
        end
    end
    pattern = pattern .. "$"
    return key:match(pattern) ~= nil
end

function M.is_valid_env_name(name)
    return type(name) == "string" and name:match("^[A-Z_][A-Z0-9_]*$") ~= nil
end

function M.validate_level(name, value)
    if value ~= "silent" and value ~= "warn" and value ~= "error" then
        error("fnox-export: invalid " .. name .. " value '" .. tostring(value)
            .. "' (expected silent, warn, or error)")
    end
    return value
end

function M.env(name)
    if os == nil or os.getenv == nil then
        return nil
    end
    return os.getenv(name)
end

function M.env_truthy(name)
    local value = M.env(name)
    if value == nil or value == "" then
        return false
    end
    local normalized = string.lower(value)
    return normalized ~= "0" and normalized ~= "false" and normalized ~= "no" and normalized ~= "off"
end

function M.env_level(name)
    local value = M.env(name)
    if value == nil or value == "" then
        return nil
    end
    return M.validate_level(name, value)
end

function M.handle_level(level, message)
    if level == "error" then
        error(message)
    elseif level == "warn" then
        log.warn(message)
    end
end

return M
