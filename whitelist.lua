-- Professional Whitelist System
-- Like Luarmor - Clean & Secure

-- ════════════════════════════════════════════════════════
--                    CONFIGURATION
-- ════════════════════════════════════════════════════════

local CONFIG = {
    API_URL = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/api/verify",
    LOADER_URL = "https://raw.githubusercontent.com/fedarel/SolarHub/refs/heads/main/loader.lua",
    MAX_RETRIES = 3,
    KEY_LENGTH = 32
}

-- ════════════════════════════════════════════════════════
--                    PRINT FUNCTIONS
-- ════════════════════════════════════════════════════════

local function print_header()
    print("\n")
    print("╔════════════════════════════════════════════════════════╗")
    print("║                                                        ║")
    print("║                   WHITELIST SYSTEM                     ║")
    print("║                                                        ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
end

local function print_success(username, expiry, is_new)
    print("\n")
    print("╔════════════════════════════════════════════════════════╗")
    print("║                                                        ║")
    print("║                  ✓ AUTHENTICATED ✓                     ║")
    print("║                                                        ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
    print("  User........: " .. username)
    print("  Expiry......: " .. expiry)
    if is_new then
        print("  HWID........: LOCKED TO THIS DEVICE")
    else
        print("  HWID........: VERIFIED")
    end
    print("  Status......: ACTIVE")
    print("")
    print("════════════════════════════════════════════════════════")
    print("")
end

local function print_error(title, message)
    print("\n")
    print("╔════════════════════════════════════════════════════════╗")
    print("║                                                        ║")
    print("║                    ✗ " .. string.upper(title) .. " ✗" .. string.rep(" ", 24 - #title) .. "║")
    print("║                                                        ║")
    print("╚════════════════════════════════════════════════════════╝")
    print("")
    print("  " .. message)
    print("")
    print("════════════════════════════════════════════════════════")
    print("")
end

local function print_step(message)
    print("  → " .. message)
end

local function kick_player(reason)
    if game and game:GetService("Players").LocalPlayer then
        task.wait(2)
        game:GetService("Players").LocalPlayer:Kick(
            "\n\n╔═══════════════════════════════════════════╗\n" ..
            "║     WHITELIST AUTHENTICATION FAILED       ║\n" ..
            "╚═══════════════════════════════════════════╝\n\n" ..
            reason .. "\n\n" ..
            "═══════════════════════════════════════════\n"
        )
    end
end

-- ════════════════════════════════════════════════════════
--                    CORE FUNCTIONS
-- ════════════════════════════════════════════════════════

local function validate_key(key)
    if not key or type(key) ~= "string" then
        return false, "Key must be a string"
    end
    if #key ~= CONFIG.KEY_LENGTH then
        return false, "Key must be " .. CONFIG.KEY_LENGTH .. " characters"
    end
    if not key:match("^[%w]+$") then
        return false, "Key contains invalid characters"
    end
    return true
end

local function json_encode(tbl)
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
    return result .. "}"
end

local function get_hwid()
    if gethwid then
        return gethwid()
    end
    
    if game then
        local player = game:GetService("Players").LocalPlayer
        local user_id = tostring(player.UserId)
        
        if getexecutorname then
            return getexecutorname() .. "-" .. user_id
        end
        
        return "ROBLOX-" .. user_id
    end
    
    return "UNKNOWN-HWID"
end

local function http_request(url, method, data)
    local body = data and json_encode(data) or nil
    
    local success, response = pcall(function()
        if request then
            return request({
                Url = url,
                Method = method,
                Headers = body and {["Content-Type"] = "application/json"} or {},
                Body = body
            })
        elseif http_request then
            return http_request({
                Url = url,
                Method = method,
                Headers = body and {["Content-Type"] = "application/json"} or {},
                Body = body
            })
        elseif syn and syn.request then
            return syn.request({
                Url = url,
                Method = method,
                Headers = body and {["Content-Type"] = "application/json"} or {},
                Body = body
            })
        else
            error("No HTTP function available")
        end
    end)
    
    return success and response or nil, response
end

local function parse_json(response)
    if type(response) == "table" then
        if response.Body and type(response.Body) == "string" then
            local body = response.Body
            
            return {
                success = body:match('"success"%s*:%s*true') ~= nil,
                message = body:match('"message"%s*:%s*"([^"]+)"'),
                username = body:match('"username"%s*:%s*"([^"]+)"'),
                expiry = body:match('"expiry"%s*:%s*"([^"]+)"'),
                isNewBinding = body:match('"isNewBinding"%s*:%s*true') ~= nil,
                script = body:match('"script"%s*:%s*"([^"]+)"')
            }
        elseif response.success ~= nil then
            return response
        end
    elseif type(response) == "string" then
        return {
            success = response:match('"success"%s*:%s*true') ~= nil,
            message = response:match('"message"%s*:%s*"([^"]+)"'),
            username = response:match('"username"%s*:%s*"([^"]+)"'),
            expiry = response:match('"expiry"%s*:%s*"([^"]+)"'),
            isNewBinding = response:match('"isNewBinding"%s*:%s*true') ~= nil,
            script = response:match('"script"%s*:%s*"([^"]+)"')
        }
    end
    
    return nil
end

-- ════════════════════════════════════════════════════════
--                    AUTHENTICATION
-- ════════════════════════════════════════════════════════

local function authenticate(key)
    local hwid = get_hwid()
    
    print_step("Hardware ID: " .. hwid:sub(1, 35) .. "...")
    
    local request_data = {
        key = key,
        hwid = hwid,
        timestamp = tostring(os.time())
    }
    
    for attempt = 1, CONFIG.MAX_RETRIES do
        print_step("Contacting authentication server... (" .. attempt .. "/" .. CONFIG.MAX_RETRIES .. ")")
        
        local response, err = http_request(CONFIG.API_URL, "POST", request_data)
        
        if response then
            print_step("Response received from server")
            
            local data = parse_json(response)
            
            if data and data.success ~= nil then
                if data.success then
                    return true, data
                else
                    if data.message and data.message:find("bound to another device") then
                        return false, {
                            title = "HWID Mismatch",
                            message = "This key is bound to a different device.\n\n  Contact support to reset your HWID.",
                            kick = true
                        }
                    else
                        return false, {
                            title = "Access Denied",
                            message = data.message or "Invalid key or expired",
                            kick = true
                        }
                    end
                end
            else
                print_step("Failed to parse server response")
            end
        else
            print_step("Connection error: " .. tostring(err))
        end
        
        if attempt < CONFIG.MAX_RETRIES then
            print_step("Retrying in 2 seconds...")
            task.wait(2)
        end
    end
    
    return false, {
        title = "Connection Failed",
        message = "Could not reach authentication server.\n\n  Please check your internet connection.",
        kick = false
    }
end

-- ════════════════════════════════════════════════════════
--                    SCRIPT LOADER
-- ════════════════════════════════════════════════════════

local function load_script(script_url)
    print_step("Loading main script...")
    
    local response = http_request(script_url, "GET")
    
    if response and response.Body then
        print_step("Script loaded successfully")
        print("")
        print("════════════════════════════════════════════════════════")
        print("                  EXECUTING SCRIPT                      ")
        print("════════════════════════════════════════════════════════")
        print("")
        
        local func, err = loadstring(response.Body)
        if func then
            return pcall(func)
        else
            print_error("Script Error", "Failed to load script: " .. tostring(err))
            return false
        end
    else
        print_error("Load Failed", "Could not download the main script")
        return false
    end
end

-- ════════════════════════════════════════════════════════
--                    MAIN EXECUTION
-- ════════════════════════════════════════════════════════

print_header()

-- Check if key is set
local key = getgenv().key

if not key then
    print_error("No Key", "Please set getgenv().key before loading")
    kick_player("No authentication key provided.\n\nSet getgenv().key and try again.")
    error("[Whitelist] No key provided")
end

-- Validate key format
print_step("Validating key format...")
local valid, err = validate_key(key)
if not valid then
    print_error("Invalid Key", err)
    kick_player(err)
    error("[Whitelist] Invalid key format")
end

print_step("Key format valid")
print_step("Initiating authentication...")
print("")

-- Authenticate
local auth_success, auth_data = authenticate(key)

if auth_success then
    -- Authentication successful
    print_success(
        auth_data.username or "Unknown",
        auth_data.expiry or "Never",
        auth_data.isNewBinding
    )
    
    -- Store whitelist data
    getgenv().whitelistData = {
        authenticated = true,
        username = auth_data.username,
        expiry = auth_data.expiry,
        isNewBinding = auth_data.isNewBinding,
        timestamp = os.time()
    }
    
    -- Load the main script
    load_script(CONFIG.LOADER_URL)
    
else
    -- Authentication failed
    print_error(auth_data.title, auth_data.message)
    
    if auth_data.kick then
        kick_player(auth_data.message)
    end
    
    error("[Whitelist] Authentication failed")
end
