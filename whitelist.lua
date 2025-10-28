-- Lua 5.1 Whitelist System with HWID Binding
-- Professional whitelist like Luarmor

local function printHeader()
    print("")
    print("════════════════════════════════════════════════════════")
    print("                 WHITELIST AUTHENTICATION                ")
    print("════════════════════════════════════════════════════════")
    print("")
end

local function printSuccess(username, expiry, isNew)
    print("")
    print("╔════════════════════════════════════════════════════════╗")
    print("║                                                        ║")
    print("║                  ✓ AUTHENTICATED ✓                     ║")
    print("║                                                        ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
    print("  → User: " .. username)
    print("  → Expiry: " .. expiry)
    if isNew then
        print("  → HWID: BOUND TO THIS DEVICE")
    else
        print("  → HWID: VERIFIED")
    end
    print("  → Status: ACTIVE")
    print("")
    print("════════════════════════════════════════════════════════")
    print("")
end

local function printError(message, kickPlayer)
    print("")
    print("╔════════════════════════════════════════════════════════╗")
    print("║                                                        ║")
    print("║              ✗ AUTHENTICATION FAILED ✗                 ║")
    print("║                                                        ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
    print("  ERROR: " .. message)
    print("")
    print("════════════════════════════════════════════════════════")
    print("")
    
    if kickPlayer and game and game:GetService("Players").LocalPlayer then
        task.wait(3)
        game:GetService("Players").LocalPlayer:Kick("\n\n" .. 
            "═══════════════════════════════════════\n" ..
            "     WHITELIST AUTHENTICATION FAILED\n" ..
            "═══════════════════════════════════════\n\n" ..
            message .. "\n\n" ..
            "Contact support if you need assistance.\n\n" ..
            "═══════════════════════════════════════"
        )
    end
end

local function printStep(message)
    print("  → " .. message)
end

-- Configuration
local CONFIG = {
    API_URL = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/api/verify",
    MAX_RETRIES = 3,
    KEY_LENGTH = 32
}

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

-- JSON encode
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
    if type(response) == "table" then
        if response.Body and type(response.Body) == "string" then
            local body = response.Body
            
            local success = body:match('"success"%s*:%s*(%a+)')
            local message = body:match('"message"%s*:%s*"([^"]+)"')
            local username = body:match('"username"%s*:%s*"([^"]+)"')
            local expiry = body:match('"expiry"%s*:%s*"([^"]+)"')
            local isNewBinding = body:match('"isNewBinding"%s*:%s*(%a+)')
            
            return {
                success = (success == "true"),
                message = message,
                username = username,
                expiry = expiry,
                isNewBinding = (isNewBinding == "true")
            }
        elseif response.success ~= nil then
            return response
        end
    elseif type(response) == "string" then
        local success = response:match('"success"%s*:%s*(%a+)')
        local message = response:match('"message"%s*:%s*"([^"]+)"')
        local username = response:match('"username"%s*:%s*"([^"]+)"')
        local expiry = response:match('"expiry"%s*:%s*"([^"]+)"')
        local isNewBinding = response:match('"isNewBinding"%s*:%s*(%a+)')
        
        return {
            success = (success == "true"),
            message = message,
            username = username,
            expiry = expiry,
            isNewBinding = (isNewBinding == "true")
        }
    end
    
    return nil
end

-- Verify key with API
local function verifyKey(key)
    local hwid = getHWID()
    
    printStep("HWID: " .. hwid:sub(1, 40) .. "...")
    
    local requestData = {
        key = key,
        hwid = hwid,
        timestamp = tostring(os.time())
    }
    
    for attempt = 1, CONFIG.MAX_RETRIES do
        printStep("Connecting to server... (Attempt " .. attempt .. "/" .. CONFIG.MAX_RETRIES .. ")")
        
        local response, err = makeRequest(CONFIG.API_URL, "POST", requestData)
        
        if response then
            printStep("Server response received")
            
            local data = parseResponse(response)
            
            if data and data.success ~= nil then
                if data.success then
                    return true, data.message, data
                else
                    -- Authentication failed - check if it's HWID mismatch
                    if data.message and data.message:find("bound to another device") then
                        return false, "HWID MISMATCH: This key is bound to another device.\n\n  Contact support to reset your HWID.", true
                    else
                        return false, data.message, false
                    end
                end
            else
                printStep("Failed to parse server response")
            end
        else
            printStep("Connection failed: " .. tostring(err))
        end
        
        if attempt < CONFIG.MAX_RETRIES then
            printStep("Retrying in 2 seconds...")
            task.wait(2)
        end
    end
    
    return false, "Failed to connect to authentication server after " .. CONFIG.MAX_RETRIES .. " attempts.\n\n  Check your internet connection.", false
end

-- Main authentication
local function authenticate()
    printHeader()
    
    local key = getgenv().key
    
    if not key then
        printError("No key provided!\n\n  Set getgenv().key before loading the script.", true)
        return false
    end
    
    printStep("Validating key format...")
    local valid, err = isValidKey(key)
    if not valid then
        printError(err, true)
        return false
    end
    
    printStep("Key format valid")
    printStep("Authenticating with server...")
    print("")
    
    local success, message, data = verifyKey(key)
    
    if success then
        printSuccess(data.username or "Unknown", data.expiry or "Never", data.isNewBinding)
        
        getgenv().whitelistData = {
            authenticated = true,
            username = data.username,
            expiry = data.expiry,
            isNewBinding = data.isNewBinding,
            timestamp = os.time()
        }
        
        return true
    else
        -- Kick player on authentication failure
        printError(message or "Authentication failed", data)
        return false
    end
end

-- Run authentication
local result = authenticate()

if not result then
    error("[Whitelist] Authentication failed - Script will not load")
end

return true
