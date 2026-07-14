-- Starforge public bootstrap.
-- Upload this file and each FreePayload to a public raw host. Keep every
-- Premium payload only inside Luarmor with FFA disabled.

local STARFORGE_ROUTES = {
    {
        Name = "Gakuran",
        UniverseIds = { 9199655655 },
        PlaceIds = { 128736949265057 },
        FreePayload = "https://api.luarmor.net/files/v4/loaders/117abf4ca5de130ed531d5dc8ba635a9.lua",
        PremiumLoader = "https://api.luarmor.net/files/v4/loaders/2eb763adbc5db6ade403c3516dcaa6ad.lua",
        GetKeyUrl = "https://discord.gg/WyNsAYhAyW",
    },
    -- Add another game by copying this shape:
    -- {
    --     Name = "Another Game",
    --     UniverseIds = { 1234567890 },
    --     PlaceIds = { 123456789012345 },
    --     FreePayload = "https://raw.githubusercontent.com/you/repo/main/another-free.lua",
    --     PremiumLoader = "https://api.luarmor.net/files/v4/loaders/YOUR_LOADER.lua",
    --     GetKeyUrl = "https://discord.gg/WyNsAYhAyW",
    -- },
}

local function executorEnvironment()
    local environment = _G
    if typeof(getgenv) == "function" then
        local ok, value = pcall(getgenv)
        if ok and typeof(value) == "table" then environment = value end
    end
    return environment
end

local function contains(values, target)
    for _, value in ipairs(values or {}) do
        if tonumber(value) == tonumber(target) then return true end
    end
    return false
end

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Starforge",
            Text = tostring(text),
            Duration = 5,
        })
    end)
end

local function runRemote(url)
    if typeof(url) ~= "string" or url == "" then return false, "loader URL is missing" end
    return pcall(function()
        local source = game:HttpGet(url)
        local responseStart = tostring(source or ""):sub(1, 80):lower()
        if responseStart:match("^%s*404")
            or responseStart:find("404: not found", 1, true)
            or responseStart:find("<html", 1, true) then
            error("URL did not return Lua (check that the file exists and is public): " .. url)
        end
        local chunk, compileError = loadstring(source)
        if not chunk then error(compileError or "downloaded script could not compile") end
        return chunk()
    end)
end

local activeRoute
for _, route in ipairs(STARFORGE_ROUTES) do
    if contains(route.UniverseIds, game.GameId) or contains(route.PlaceIds, game.PlaceId) then
        activeRoute = route
        break
    end
end

if not activeRoute then
    notify("This game is not supported yet.")
    return
end

local environment = executorEnvironment()
local suppliedKey = tostring(environment.script_key or ""):gsub("^%s+", ""):gsub("%s+$", "")

if suppliedKey ~= "" then
    -- Only the Luarmor-protected payload can set this marker. The public loader
    -- clears old state before every authorization attempt.
    environment.STARFORGE_PREMIUM_AUTHORIZED = nil
    environment.script_key = suppliedKey
    script_key = suppliedKey

    local premiumOk, premiumError = runRemote(activeRoute.PremiumLoader)
    if premiumOk then
        local deadline = os.clock() + 3
        repeat
            if environment.STARFORGE_PREMIUM_AUTHORIZED == true then return end
            task.wait(0.05)
        until os.clock() >= deadline
    end

    warn("[Starforge] Premium authorization failed: " .. tostring(premiumError or "key was not accepted"))
    notify("Premium key was not accepted. Loading Free.")
end

local freeOk, freeError = runRemote(activeRoute.FreePayload)
if not freeOk then
    warn("[Starforge] Free loader failed: " .. tostring(freeError))
    notify("The Free script could not be loaded.")
end
