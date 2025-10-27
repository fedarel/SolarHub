-- Lua 5.1 Whitelist System with HWID Binding
-- Client-side implementation

local WhitelistSystem = {}
WhitelistSystem.__index = WhitelistSystem

-- Configuration
local CONFIG = {
    API_URL = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/api/verify",
    TIMEOUT = 10,
    MAX_RETRIES = 3,
    KEY_LENGTH = 32
}

-- Color codes for printing (ANSI escape codes - works in most terminals/executors)
local COLORS = {
    GREEN = "\27[32m",
    RED = "\27[31m",
    YELLOW = "\27[33m",
    CYAN = "\27[36m",
    RESET = "\27[0m",
    BOLD = "\27[1m"
}

-- Enhanced print function with colors
local function colorPrint(message, color)
    color = color or COLORS.GREEN
    local formattedMsg = color .. message .. COLORS.RESET
    
    -- Try different print methods based on executor
    if rconsoleprint then
        rconsoleprint(formattedMsg .. "\n")
    elseif printconsole then
        printconsole(formattedMsg)
    else
        print(formattedMsg)
    end
end

-- Animated loading effect
local function showLoading(message)
    colorPrint("╔══════════════════════════════════════╗", COLORS.CYAN)
    colorPrint("║     " .. COLORS.BOLD .. "WHITELIST AUTHENTICATION" .. COLORS.RESET .. COLORS.CYAN .. "     ║", COLORS.CYAN)
    colorPrint("╚══════════════════════════════════════╝", COLORS.CYAN)
    colorPrint("")
    colorPrint("⟳ " .. message .. "...", COLORS.YELLOW)
end

-- Success message
local function showSuccess(username, expiry)
    colorPrint("")
    colorPrint("╔══════════════════════════════════════╗", COLORS.GREEN)
    colorPrint("║           ✓ AUTHENTICATED           ║", COLORS.GREEN)
    colorPrint("╚══════════════════════════════════════╝", COLORS.GREEN)
    colorPrint("")
    colorPrint("  User: " .. username, COLORS.GREEN)
    colorPrint("  Expiry: " .. expiry, COLORS.GREEN)
    colorPrint("  Status: Active", COLORS.GREEN)
    colorPrint("")
    colorPrint("════════════════════════════════════════", COLORS.GREEN)
    colorPrint("")
end

-- Error message
local function showError(message)
    colorPrint("")
    colorPrint("╔══════════════════════════════════════╗", COLORS.RED)
    colorPrint("║        ✗ AUTHENTICATION FAILED       ║", COLORS.RED)
    colorPrint("╚══════════════════════════════════════╝", COLORS.RED)
    colorPrint("")
    colorPrint("  Error: " .. message, COLORS.RED)
    colorPrint("")
    colorPrint("════════════════════════════════════════", COLORS.RED)
    colorPrint("")
end

-- Validation functions
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

-- HTTP request function
local function makeRequest(url, method, data)
    local success, response = pcall(function()
        if http and http.request then
            local HttpService = game:GetService("HttpService")
            local body = HttpService:JSONEncode(data)
            return http.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        elseif game then
            local HttpService = game:GetService("HttpService")
            local body = HttpService:JSONEncode(data)
            local result = HttpService:RequestAsync({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
            return result
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

-- Get HWID
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
local function verifyKeyWithAPI(key)
    local hwid = getHWID()
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = os.time()
    }
    
    showLoading("Connecting to authentication server")
    
    local retries = 0
    while retries < CONFIG.MAX_RETRIES do
        colorPrint("  Attempt " .. (retries + 1) .. "/" .. CONFIG.MAX_RETRIES .. "...", COLORS.YELLOW)
        
        local response, err = makeRequest(CONFIG.API_URL, "POST", requestData)
        
        if response then
            local success, data = pcall(function()
                local HttpService = game:GetService("HttpService")
                if type(response) == "string" then
                    return HttpService:JSONDecode(response)
                elseif response.Body then
                    return HttpService:JSONDecode(response.Body)
                else
                    return response
                end
            end)
            
            if success and data then
                return data.success, data.message, data
            end
        end
        
        retries = retries + 1
        if retries < CONFIG.MAX_RETRIES then
            wait(1)
        end
    end
    
    return false, "Failed to connect to authentication server", nil
end

-- Main authentication function that runs when script loads
local function authenticateOnLoad()
    -- Check if key is set
    local key = getgenv().key
    
    if not key then
        showError("No key provided! Set getgenv().key before loading the script")
        error("[Whitelist] Authentication required")
        return false
    end
    
    -- Validate key format
    local keyValid, keyError = isValidKey(key)
    if not keyValid then
        showError(keyError)
        error("[Whitelist] Invalid key: " .. keyError)
        return false
    end
    
    -- Verify with API
    local success, message, data = verifyKeyWithAPI(key)
    
    if success then
        showSuccess(data.username or "Unknown", data.expiry or "Never")
        
        -- Store authentication data globally for script access
        getgenv().whitelistData = {
            authenticated = true,
            username = data.username,
            expiry = data.expiry,
            timestamp = os.time()
        }
        
        return true
    else
        showError(message)
        error("[Whitelist] Authentication failed: " .. message)
        return false
    end
end

-- Run authentication automatically when this script loads
local authSuccess = authenticateOnLoad()

-- If authentication failed, stop script execution
if not authSuccess then
    return false
end

return true
