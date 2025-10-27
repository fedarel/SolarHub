-- Simple test to see if script even runs
print("====================================")
print("WHITELIST SCRIPT STARTED")
print("====================================")

-- Check if key exists
local key = getgenv().key
print("Key found: " .. tostring(key))

if not key then
    print("ERROR: No key set!")
    return
end

print("Key length: " .. #key)

-- Test HWID
local function getHWID()
    if gethwid then
        print("Using gethwid()")
        return gethwid()
    end
    
    if game then
        local player = game:GetService("Players").LocalPlayer
        print("Using player UserId")
        return "ROBLOX-" .. tostring(player.UserId)
    end
    
    return "UNKNOWN"
end

local hwid = getHWID()
print("HWID: " .. hwid)

-- Test HTTP request
print("Testing HTTP request...")

local function testRequest()
    -- Try request()
    if request then
        print("request() function exists")
        local response = request({
            Url = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/health",
            Method = "GET"
        })
        print("Response: " .. tostring(response))
        if response and response.Body then
            print("Body: " .. response.Body)
        end
        return true
    end
    
    -- Try http_request()
    if http_request then
        print("http_request() function exists")
        local response = http_request({
            Url = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/health",
            Method = "GET"
        })
        print("Response: " .. tostring(response))
        if response and response.Body then
            print("Body: " .. response.Body)
        end
        return true
    end
    
    -- Try syn.request
    if syn and syn.request then
        print("syn.request() function exists")
        local response = syn.request({
            Url = "https://e663dd99-d6c1-4842-bfa2-cd784e91e9c5-00-1mpetcow43qg8.riker.replit.dev/health",
            Method = "GET"
        })
        print("Response: " .. tostring(response))
        if response and response.Body then
            print("Body: " .. response.Body)
        end
        return true
    end
    
    print("ERROR: No HTTP function available!")
    return false
end

local success = testRequest()
print("HTTP test result: " .. tostring(success))

print("====================================")
print("TEST COMPLETE")
print("====================================")
