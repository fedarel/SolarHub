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

-- Check if executor supports colors
local function supportsColors()
    return rconsoleprint or printconsole or (syn and syn.crypt)
end

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
    local frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
    local currentFrame = 1
    
    colorPrint("╔══════════════════════════════════════╗", COLORS.CYAN)
    colorPrint("║     " .. COLORS.BOLD .. "WHITELIST AUTHENTICATION" .. COLORS.RESET .. COLORS.CYAN .. "     ║", COLORS.CYAN)
    colorPrint("╚══════════════════════════════════════╝", COLORS.CYAN)
    colorPrint("")
    colorPrint(frames[currentFrame] .. " " .. message .. "...", COLORS.YELLOW)
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
function WhitelistSystem:verifyKey(key)
    local hwid = getHWID()
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = os.time()
    }
    
    showLoading("Connecting to authentication server")
    
    local retries = 0
    while retries < CONFIG.MAX_RETRIES do
        colorPrint("  ⟳ Attempt " .. (retries + 1) .. "/" .. CONFIG.MAX_RETRIES, COLORS.YELLOW)
        
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

-- Main authentication function
function WhitelistSystem:authenticate(key)
    local keyValid, keyError = isValidKey(key)
    if not keyValid then
        showError(keyError)
        return false, keyError, nil
    end
    
    local success, message, data = self:verifyKey(key)
    
    if success then
        showSuccess(data.username or "Unknown", data.expiry or "Never")
        return true, message, data
    else
        showError(message)
        return false, message, nil
    end
end

-- Create global function
getgenv = getgenv or function() return _G end

-- Main entry point
getgenv().key = function()
    return {
        loadstring = function(keyString)
            -- Validate key
            local keyValid, keyError = isValidKey(keyString)
            if not keyValid then
                showError(keyError)
                return function() 
                    error("[Whitelist] Invalid key: " .. keyError)
                end
            end
            
            -- Authenticate
            local ws = setmetatable({}, WhitelistSystem)
            local success, message, data = ws:authenticate(keyString)
            
            if not success then
                return function()
                    error("[Whitelist] Authentication failed: " .. message)
                end
            end
            
            -- Return function that will execute provided code
            return function(code)
                if type(code) == "string" then
                    local func, err = loadstring(code)
                    if func then
                        colorPrint("  ▶ Executing protected script...", COLORS.CYAN)
                        colorPrint("", COLORS.RESET)
                        return pcall(func)
                    else
                        showError("Code execution error: " .. tostring(err))
                    end
                else
                    showError("Code must be a string")
                end
            end
        end
    }
end

return WhitelistSystem
