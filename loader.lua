-- Lua 5.1 Whitelist System with HWID Binding
-- Client-side implementation

local WhitelistSystem = {}
WhitelistSystem.__index = WhitelistSystem

-- Configuration
local CONFIG = {
    API_URL = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev:3000/api/verify", -- Replace with your API endpoint
    TIMEOUT = 10,
    MAX_RETRIES = 3,
    KEY_LENGTH = 32
}

-- Validation functions
local function isValidKey(key)
    if not key or type(key) ~= "string" then
        return false, "Key must be a string"
    end
    
    if #key ~= CONFIG.KEY_LENGTH then
        return false, "Key must be exactly " .. CONFIG.KEY_LENGTH .. " characters"
    end
    
    -- Check if key contains only alphanumeric characters
    if not key:match("^[%w]+$") then
        return false, "Key must contain only letters and numbers"
    end
    
    return true
end

-- HTTP request function (adjust based on your environment)
local function makeRequest(url, method, data)
    local success, response = pcall(function()
        if http and http.request then
            local body = game:GetService("HttpService"):JSONEncode(data)
            return http.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        elseif game then
            -- Roblox environment
            local HttpService = game:GetService("HttpService")
            local body = HttpService:JSONEncode(data)
            return HttpService:RequestAsync({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        else
            error("No HTTP library available")
        end
    end)
    
    if success then
        return response
    else
        return nil, response
    end
end

-- Get HWID (Hardware ID) - adjust based on your environment
local function getHWID()
    if gethwid then
        return gethwid()
    elseif getexecutorname then
        local executor = getexecutorname()
        local userId = game:GetService("Players").LocalPlayer.UserId
        return game:GetService("HttpService"):GenerateGUID(false) .. "-" .. executor .. "-" .. userId
    end
    
    if os and os.getenv then
        local username = os.getenv("USERNAME") or os.getenv("USER") or "unknown"
        local computername = os.getenv("COMPUTERNAME") or os.getenv("HOSTNAME") or "unknown"
        return username .. "-" .. computername
    end
    
    return "UNKNOWN-HWID"
end

-- Verify key with API
function WhitelistSystem:verifyKey(key)
    local hwid = getHWID()
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = os.time()
    }
    
    local retries = 0
    while retries < CONFIG.MAX_RETRIES do
        local response, err = makeRequest(CONFIG.API_URL, "POST", requestData)
        
        if response then
            local success, data = pcall(function()
                if type(response) == "string" then
                    return game:GetService("HttpService"):JSONDecode(response)
                else
                    return response
                end
            end)
            
            if success and data then
                return data.success, data.message, data
            end
        end
        
        retries = retries + 1
        wait(1)
    end
    
    return false, "Failed to connect to authentication server", nil
end

-- Main authentication function
function WhitelistSystem:authenticate(key)
    -- Validate key
    local keyValid, keyError = isValidKey(key)
    if not keyValid then
        return false, keyError, nil
    end
    
    print("[Whitelist] Authenticating...")
    print("[Whitelist] Key: " .. string.sub(key, 1, 8) .. "..." .. string.sub(key, -4))
    print("[Whitelist] HWID: " .. getHWID())
    
    local success, message, data = self:verifyKey(key)
    
    if success then
        print("[Whitelist] ✓ Authentication successful!")
        print("[Whitelist] User: " .. (data.username or "Unknown"))
        print("[Whitelist] Expiry: " .. (data.expiry or "Never"))
        return true, message, data
    else
        print("[Whitelist] ✗ Authentication failed: " .. message)
        return false, message, nil
    end
end

-- Create global function for easy access
getgenv = getgenv or function() return _G end

getgenv().key = function(keyString)
    -- Validate key before creating instance
    local keyValid, keyError = isValidKey(keyString)
    if not keyValid then
        error("[Whitelist] Invalid key: " .. keyError)
        return false
    end
    
    local ws = setmetatable({}, WhitelistSystem)
    local success, message, data = ws:authenticate(keyString)
    
    if not success then
        error("[Whitelist] Authentication failed: " .. message)
        return false
    end
    
    return {
        success = true,
        message = message,
        data = data,
        username = data.username,
        execute = function(code)
            if success then
                local func, err = loadstring(code)
                if func then
                    return pcall(func)
                else
                    error("[Whitelist] Code execution error: " .. tostring(err))
                end
            end
        end
    }
end

-- Alternative usage: Direct verification
getgenv().verifyKey = function(keyString)
    local keyValid, keyError = isValidKey(keyString)
    if not keyValid then
        return false, keyError, nil
    end
    
    local ws = setmetatable({}, WhitelistSystem)
    return ws:authenticate(keyString)
end

return WhitelistSystem
