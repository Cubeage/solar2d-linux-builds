local composer = require("composer")
local widget = require("widget")
local scene = composer.newScene()

function scene:create()
    self.smokeRect = display.newRect(self.view, 40, 80, 30, 30)
    self.view:insert(widget.newButton({ label = "Runtime smoke", x = 160, y = 160 }))
    self.smokeCreated = true
end

scene:addEventListener("create", scene)
return scene
