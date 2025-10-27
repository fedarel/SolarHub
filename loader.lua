-- Whitelist check at the start of loader.lua
if not getgenv().key then
    error("❌ Please set getgenv().key before loading!")
    return
end

-- Load and run whitelist authentication
loadstring(game:HttpGet("https://raw.githubusercontent.com/fedarel/SolarHub/refs/heads/main/whitelist.lua"))()

-- Check if authenticated
if not getgenv().whitelistData or not getgenv().whitelistData.authenticated then
    error("❌ Whitelist authentication failed!")
    return
end

-- Rest of your loader code below...
print("✓ Loading SolarHub...")
