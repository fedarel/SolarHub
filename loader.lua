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

-- Color codes for printing
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
    
    if rconsoleprint then
        rconsoleprint(formattedMsg .. "\n")
    elseif printconsole then
        printconsole(formattedMsg)
    else
        print(formattedMsg)
    end
end

-- Loading animation
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

-- Validation
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

-- JSON encode function (since we can't use HttpService on client)
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

-- JSON decode function (basic)
local function jsonDecode(str)
    -- Remove whitespace
    str = str:gsub("%s+", "")
    
    -- Parse simple JSON object
    local result = {}
    
    -- Extract key-value pairs
    for key, value in str:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
        result[key] = value
    end
    
    -- Handle boolean values
    for key, value in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
        if value == "true" then
            result[key] = true
        elseif value == "false" then
            result[key] = false
        elseif tonumber(value) then
            result[key] = tonumber(value)
        end
    end
    
    return result
end

-- HTTP request function for client-side executors
local function makeRequest(url, method, data)
    colorPrint("  → Sending request to API...", COLORS.YELLOW)
    
    local success, response = pcall(function()
        local body = jsonEncode(data)
        
        colorPrint("  → Request URL: " .. url, COLORS.YELLOW)
        
        -- Try request function (works in most executors like Synapse, Script-Ware, etc.)
        if request then
            colorPrint("  → Using request()", COLORS.YELLOW)
            local result = request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
            return result
        end
        
        -- Try http_request
        if http_request then
            colorPrint("  → Using http_request()", COLORS.YELLOW)
            local result = http_request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
            return result
        end
        
        -- Try syn.request (Synapse X)
        if syn and syn.request then
            colorPrint("  → Using syn.request()", COLORS.YELLOW)
            local result = syn.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
            return result
        end
        
        -- Try http.request
        if http and http.request then
            colorPrint("  → Using http.request()", COLORS.YELLOW)
            local result = http.request({
                Url = url,
                Method = method,
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
            return result
        end
        
        error("No HTTP request function available! Your executor might not support HTTP requests.")
    end)
    
    if success then
        colorPrint("  ✓ Request successful", COLORS.GREEN)
        return response
    else
        colorPrint("  ✗ Request failed: " .. tostring(response), COLORS.RED)
        return nil, response
    end
end

-- Get HWID
local function getHWID()
    -- Try gethwid() first (most executors)
    if gethwid then
        return gethwid()
    end
    
    -- Try getting executor name and user ID
    if game and game:GetService("Players").LocalPlayer then
        local player = game:GetService("Players").LocalPlayer
        local userId = tostring(player.UserId)
        
        if getexecutorname then
            return getexecutorname() .. "-" .. userId
        end
        
        return "ROBLOX-" .. userId
    end
    
    -- Fallback to environment variables (non-Roblox)
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
    
    colorPrint("  HWID: " .. hwid:sub(1, 30) .. "...", COLORS.CYAN)
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = tostring(os.time())
    }
    
    showLoading("Connecting to authentication server")
    
    local retries = 0
    while retries < CONFIG.MAX_RETRIES do
        colorPrint("  Attempt " .. (retries + 1) .. "/" .. CONFIG.MAX_RETRIES .. "...", COLORS.YELLOW)
        
        local response, err = makeRequest(CONFIG.API_URL, "POST", requestData)
        
        if response then
            local success, data = pcall(function()
                -- Handle different response formats
                if type(response) == "string" then
                    colorPrint("  → Parsing string response", COLORS.YELLOW)
                    return jsonDecode(response)
                elseif type(response) == "table" then
                    if response.Body then
                        colorPrint("  → Parsing response.Body", COLORS.YELLOW)
                        return jsonDecode(response.Body)
                    elseif response.success ~= nil then
                        colorPrint("  → Using response directly", COLORS.YELLOW)
                        return response
                    end
                end
                
                error("Unknown response format")
            end)
            
            if success and data and data.success ~= nil then
                colorPrint("  ✓ Response parsed successfully", COLORS.GREEN)
                return data.success, data.message or "Success", data
            else
                colorPrint("  ✗ Failed to parse response: " .. tostring(data), COLORS.RED)
            end
        else
            colorPrint("  ✗ No response from server: " .. tostring(err), COLORS.RED)
        end
        
        retries = retries + 1
        if retries < CONFIG.MAX_RETRIES then
            colorPrint("  Waiting 2 seconds before retry...", COLORS.YELLOW)
            task.wait(2)
        end
    end
    
    return false, "Failed to connect to authentication server after " .. CONFIG.MAX_RETRIES .. " attempts", nil
end

-- Main authentication function
local function authenticateOnLoad()
    local key = getgenv().key
    
    if not key then
        showError("No key provided! Set getgenv().key before loading the script")
        return false
    end
    
    local keyValid, keyError = isValidKey(key)
    if not keyValid then
        showError(keyError)
        return false
    end
    
    local success, message, data = verifyKeyWithAPI(key)
    
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
        showError(message)
        return false
    end
end

-- Run authentication
local authSuccess = authenticateOnLoad()

if not authSuccess then
    error("[Whitelist] Authentication failed")
end

return true
