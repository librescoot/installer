#!/bin/sh

# Print the current component's OTA errors oldest-first. The stream is the
# authoritative history; the hash fields provide the compatibility view.
component="${1:-dbc}"
redis_cli="${REDIS_CLI:-redis-cli}"
redis_host="${REDIS_HOST:-localhost}"

script=$(cat <<'LUA'
local component = ARGV[1]
local limit = tonumber(ARGV[2]) or 200

local function clean(value)
  if not value then
    return ""
  end
  return (string.gsub(value, "[%c]+", " "))
end

local function format_error(fields)
  local code = clean(fields.code)
  local message = clean(fields.message)
  if code ~= "" and message ~= "" then
    return code .. ": " .. message
  end
  if message ~= "" then
    return message
  end
  return code
end

local errors = {}
local entries = redis.pcall("XREVRANGE", KEYS[1], "+", "-", "COUNT", limit)
if type(entries) == "table" and not entries.err then
  for _, entry in ipairs(entries) do
    if type(entry) == "table" and type(entry[2]) == "table" then
      local values = entry[2]
      local fields = {}
      for index = 1, #values - 1, 2 do
        fields[values[index]] = values[index + 1]
      end
      if fields.component == component then
        if fields.event == "reset" then
          break
        end
        if fields.event == "error" then
          local line = format_error(fields)
          if line ~= "" then
            table.insert(errors, 1, line)
          end
        end
      end
    end
  end
end

if #errors > 0 then
  return errors
end

local fields = {
  code = redis.call("HGET", KEYS[2], "error:" .. component),
  message = redis.call("HGET", KEYS[2], "error-message:" .. component),
}
local fallback = format_error(fields)
if fallback ~= "" then
  return {fallback}
end
return {}
LUA
)

if [ -n "${REDIS_SOCKET:-}" ]; then
  exec "$redis_cli" -s "$REDIS_SOCKET" --raw EVAL "$script" 2 ota:errors ota "$component" 200
fi
if [ -n "${REDIS_PORT:-}" ]; then
  exec "$redis_cli" -h "$redis_host" -p "$REDIS_PORT" --raw EVAL "$script" 2 ota:errors ota "$component" 200
fi
exec "$redis_cli" -h "$redis_host" --raw EVAL "$script" 2 ota:errors ota "$component" 200
