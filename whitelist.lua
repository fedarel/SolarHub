-- Lua 5.1 Whitelist System with HWID Binding
-- Client-side implementation

print("====================================")
print("WHITELIST AUTHENTICATION STARTING")
print("====================================")

-- Configuration
local CONFIG = {
    API_URL = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/api/verify",
    MAX_RETRIES = 3,
    KEY_LENGTH = 32
}

-- Color codes
local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local CYAN = "\27[36m"
local RESET = "\27[0m"

-- Print with colors
local function colorPrint(msg, color)
    print((color or GREEN) .. msg .. RESET)
end

-- Success message
local function showSuccess(username, expiry)
    print("")
    colorPrint("╔══════════════════════════════════════╗", GREEN)
    colorPrint("║           ✓ AUTHENTICATED           ║", GREEN)
    colorPrint("╚══════════════════════════════════════╝", GREEN)
    print("")
    colorPrint("  User: " .. username, GREEN)
    colorPrint("  Expiry: " .. expiry, GREEN)
    colorPrint("  Status: Active", GREEN)
    print("")
    colorPrint("════════════════════════════════════════", GREEN)
    print("")
end

-- Error message
local function showError(message)
    print("")
    colorPrint("╔══════════════════════════════════════╗", RED)
    colorPrint("║        ✗ AUTHENTICATION FAILED       ║", RED)
    colorPrint("╚══════════════════════════════════════╝", RED)
    print("")
    colorPrint("  Error: " .. message, RED)
    print("")
    colorPrint("════════════════════════════════════════", RED)
    print("")
end

-- Validate key
local function isValidKey(key)
    if not key or type(key) ~= "string" then
        return false, "Key must be a string"
    end
    
    if #key ~= CONFIG.KEY_LENGTH then
        return false, "Key must be exactly " .. CONFIG.KEY_LENGTH .. " characters"
    end
    
    if not key:match("^[%w]+$") then
        return false, "Key must contain only letters and numbers"
    end
    
    return true
end

-- Simple JSON encode
local function jsonEncode(tbl)
    local result = "{"
    local first = true
    for k, v in pairs(tbl) do
        if not first then result = result .. "," end
        first = false
        result = result .. '"' .. tostring(k) .. '":'
        if type(v) == "string" then
            result = result .. '"' .. tostring(v) .. '"'
        else
            result = result .. tostring(v)
        end
    end
    result = result .. "}"
    return result
end

-- Get HWID
local function getHWID()
    if gethwid then
        return gethwid()
    end
    
    if game then
        local player = game:GetService("Players").LocalPlayer
        local userId = tostring(player.UserId)
        
        if getexecutorname then
            return getexecutorname() .. "-" .. userId
        end
        
        return "ROBLOX-" .. userId
    end
    
    return "UNKNOWN-HWID"
end

-- Make HTTP request
local function makeRequest(url, method, data)
    local body = jsonEncode(data)
    
    colorPrint("→ Sending authentication request...", YELLOW)
    
    local success, response = pcall(function()
        if request then
            return request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        elseif http_request then
            return http_request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        elseif syn and syn.request then
            return syn.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        else
            error("No HTTP function available")
        end
    end)
    
    if success then
        return response
    else
        return nil, response
    end
end

-- Parse JSON response
local function parseResponse(response)
    -- Check if response is a table (parsed JSON)
    if type(response) == "table" then
        -- Check if it has Body property (string)
        if response.Body and type(response.Body) == "string" then
            local body = response.Body
            
            -- Parse the JSON body manually
            local success = body:match('"success"%s*:%s*(%a+)')
            local message = body:match('"message"%s*:%s*"([^"]+)"')
            local username = body:match('"username"%s*:%s*"([^"]+)"')
            local expiry = body:match('"expiry"%s*:%s*"([^"]+)"')
            
            return {
                success = (success == "true"),
                message = message,
                username = username,
                expiry = expiry
            }
        elseif response.success ~= nil then
            -- Already parsed
            return response
        end
    elseif type(response) == "string" then
        -- Parse string JSON
        local success = response:match('"success"%s*:%s*(%a+)')
        local message = response:match('"message"%s*:%s*"([^"]+)"')
        local username = response:match('"username"%s*:%s*"([^"]+)"')
        local expiry = response:match('"expiry"%s*:%s*"([^"]+)"')
        
        return {
            success = (success == "true"),
            message = message,
            username = username,
            expiry = expiry
        }
    end
    
    return nil
end

-- Verify key with API
local function verifyKey(key)
    local hwid = getHWID()
    
    colorPrint("→ HWID: " .. hwid:sub(1, 40) .. "...", CYAN)
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = tostring(os.time())
    }
    
    for attempt = 1, CONFIG.MAX_RETRIES do
        colorPrint("→ Attempt " .. attempt .. "/" .. CONFIG.MAX_RETRIES, YELLOW)
        
        local response, err = makeRequest(CONFIG.API_URL, "POST", requestData)
        
        if response then
            colorPrint("✓ Got response from server", GREEN)
            
            local data = parseResponse(response)
            
            if data and data.success ~= nil then
                return data.success, data.message, data
            else
                colorPrint("✗ Failed to parse response", RED)
                print("Response type: " .. type(response))
                print("Response: " .. tostring(response))
            end
        else
            colorPrint("✗ Request failed: " .. tostring(err), RED)
        end
        
        if attempt < CONFIG.MAX_RETRIES then
            colorPrint("→ Retrying in 2 seconds...", YELLOW)
            task.wait(2)
        end
    end
    
    return false, "Failed to connect after " .. CONFIG.MAX_RETRIES .. " attempts", nil
end

-- Main authentication
local function authenticate()
    local key = getgenv().key
    
    if not key then
        showError("No key provided! Set getgenv().key first")
        return false
    end
    
    colorPrint("→ Validating key format...", CYAN)
    local valid, err = isValidKey(key)
    if not valid then
        showError(err)
        return false
    end
    
    colorPrint("✓ Key format valid", GREEN)
    
    local success, message, data = verifyKey(key)
    
    if success then
        showSuccess(data.username or "Unknown", data.expiry or "Never")
        
        getgenv().whitelistData = {
            authenticated = true,
            username = data.username,
            expiry = data.expiry,
            timestamp = os.time()
        }
        
        return true
    else
        showError(message or "Authentication failed")
        return false
    end
end

-- Run
local result = authenticate()

if not result then
    error("[Whitelist] Authentication failed - Script will not load")
end

print("====================================")
print("WHITELIST CHECK COMPLETE")
print("====================================")

return true
