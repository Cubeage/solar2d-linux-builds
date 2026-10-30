local receipt = assert(os.getenv("SOLAR2D_SMOKE_RECEIPT"))
local complete = false
local function finish(ok, detail)
    if complete then return end
    complete = true
    local file = assert(io.open(receipt, "w"))
    file:write(require("json").encode({ ok = ok, detail = detail }))
    file:close()
    os.exit(ok and 0 or 1)
end
local function guarded(callback)
    return function(...)
        local ok, message = pcall(callback, ...)
        if not ok then finish(false, tostring(message)) end
    end
end
Runtime:addEventListener("unhandledError", function(event)
    finish(false, tostring(event.errorMessage))
    return true
end)

guarded(function()
    assert(_VERSION == "Lua 5.1", "wrong Lua ABI")
    local composer = require("composer")
    local widget = require("widget")
    local json = require("json")
    assert(composer.newScene and widget.newButton and json.encode)
    local openssl = require("plugin.openssl")
    local bytes = openssl.random(4, true)
    assert(type(bytes) == "string" and #bytes == 4, "secure entropy unavailable")
    local more = openssl.random(32, true)
    assert(type(more) == "string" and #more == 32, "secure entropy unavailable")
    local bindingVersion, luaVersion, cryptoVersion = openssl.version()
    assert(luaVersion:find("Lua 5.1", 1, true), "native module uses wrong Lua")
    assert(cryptoVersion:find("OpenSSL 3.", 1, true), "expected system OpenSSL 3")
    assert(openssl.rand_status(), "OpenSSL entropy is not ready")

    local scene = composer.newScene()
    local rect = display.newRect(scene.view, 40, 80, 30, 30)
    scene.view:insert(widget.newButton({ label = "Runtime smoke", x = 160, y = 160 }))
    local frames, transitioned, timed = 0, false, false
    Runtime:addEventListener("enterFrame", function() frames = frames + 1 end)
    transition.to(rect, { time = 100, x = 80, onComplete = function() transitioned = true end })
    timer.performWithDelay(50, function() timed = true end)
    timer.performWithDelay(350, guarded(function()
        assert(frames >= 3 and transitioned and timed, "runtime callbacks did not finish")
        local path = assert(system.pathForFile("runtime-smoke.txt", system.DocumentsDirectory))
        local file = assert(io.open(path, "w"))
        file:write("runtime documents receipt")
        file:close()
        file = assert(io.open(path, "r"))
        assert(file:read("*a") == "runtime documents receipt", "Documents readback failed")
        file:close()
        finish(true, {
            lua = _VERSION, solar2d = system.getInfo("build"), openssl = cryptoVersion,
            binding = bindingVersion, frames = frames, timer = timed,
            transition = transitioned, documents = true, nativeRandom = true
        })
    end))
end)()
