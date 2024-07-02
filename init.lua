-- Keychord for most of the actions
magic = {"cmd", "alt", "shift"}

-- No window animations please
hs.window.animationDuration = 0

log = hs.logger.new('mymodule','debug')

---------- Config reloading -----------

function reloadConfig(files)
    doReload = false
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            doReload = true
        end
    end
    if doReload then
        hs.reload()
    end
    hs.alert.show("Config reloaded")
end
local myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()

---------- Special windows ------------

function isiOSSimulator(win)
   return string.find(win:application():name(), "Simulator")
end

function isTerminal(win)
   return win:application():name() == "Terminal"
end

function shouldPreserveSize(win)
    return win:title() == "Messages"
end

SideLeft = 0
SideRight = 1

VSideTop = 2
VSideBottom = 3

function fullScreenFrame(screen)
    local frame = screen:frame()
    if screen:name() ~= "Color LCD" then
        frame.h = frame.h -- * 0.87 -- 0.78
    end
    return frame
end

function frameToSnapScreenToSide(screen, side)
    local frame = fullScreenFrame(screen)
    if side == SideRight then
        frame.x = frame.x + frame.w / 2
    end
    frame.w = frame.w / 2

    return frame
end

function frameToSnapScreenToCorner(screen, side, vside)
    local frame = frameToSnapScreenToSide(screen, side)
    if vside == VSideBottom then
        frame.y = frame.y + frame.h / 2
    end
    frame.h = frame.h / 2

    return frame
end

function frameToleranceForWindow(win)
    if isTerminal(win) then
        return 10
    end

    return 1
end

function framesMatchWithTolerance(frame1, frame2, tolerance)
    return frame1.xy:distance(frame2.xy) <= tolerance
        and frame1.x2y2:distance(frame2.x2y2) <= tolerance
end

function snapFixedSizeWindowToSide(win, side)
    side = side or SideLeft
    local winFrame = win:frame()
    local screen = win:screen()
    local screenFrame = fullScreenFrame(screen)
    local maxOffset = 1/24
    local offsetFromEdge = 20

    if side == SideLeft then
        winFrame.x = 20
    else
        winFrame.x = screenFrame.w - 20 - winFrame.w
    end
    winFrame.y = (screenFrame.h - winFrame.h) / 2 + math.random(-math.floor(screenFrame.h * maxOffset), math.floor(screenFrame.h * maxOffset))

    win:setFrame(screen:localToAbsolute(winFrame))
end

function snapWindowToSide(win, side)
    local frame = frameToSnapScreenToSide(win:screen(), side)
    win:setFrame(frame)
end

function snapWindowToCorner(win, side, vside)
    local frame = frameToSnapScreenToCorner(win:screen(), side, vside)
    win:setFrame(frame)
end

function isSnappedToSide(win, side)
    local winFrame = win:frame()
    local snappedFrame = frameToSnapScreenToSide(win:screen(), side)
    local tolerance = frameToleranceForWindow(win)

    return framesMatchWithTolerance(winFrame, snappedFrame, tolerance)
end

function isSnappedToCorner(win, side, vside)
    local winFrame = win:frame()
    local snappedFrame = frameToSnapScreenToCorner(win:screen(), side, vside)
    local tolerance = frameToleranceForWindow(win)

    return framesMatchWithTolerance(winFrame, snappedFrame, tolerance)
end

function snapFocusedWindowToCorner(side, vside)
    local win = hs.window.focusedWindow()    

    if isiOSSimulator(win) then
        snapFixedSizeWindowToSide(win, side)
        return
    end

    if isSnappedToSide(win, side) then
        -- If snapped to side, always resnap to corner.
        snapWindowToCorner(win, side, vside)
    elseif vside == VSideTop or isSnappedToCorner(win, side, vside) then
        -- Symmetrically, if snapped to corner, resnap to side.
        -- However, top corner buttons snap to side first; bottom corner buttons snap to corners immediately.
        snapWindowToSide(win, side)
    else
        snapWindowToCorner(win, side, vside)
    end
end

---------- Window resizing ------------

function hs.window:isFullScreen()
    local screen = self:screen()
    return self:frame() == screen:frame()
end

function moveWindowToScreen(win, screen)
    if screen == nil then
        log.e("No screen to move window to.")
        return
    end

    local frame = win:frame()
    local sourceScreenFrame = fullScreenFrame(win:screen())
    local targetScreenFrame = fullScreenFrame(screen)

    frame.x = 0*targetScreenFrame.x + (frame.x - sourceScreenFrame.x) * targetScreenFrame.w / sourceScreenFrame.w
    frame.y = 0*targetScreenFrame.y + (frame.y - sourceScreenFrame.y) * targetScreenFrame.h / sourceScreenFrame.h
    if not shouldPreserveSize(win) then
        frame.w = frame.w * targetScreenFrame.w / sourceScreenFrame.w
        frame.h = frame.h * targetScreenFrame.h / sourceScreenFrame.h
    end

    win:setFrame(screen:localToAbsolute(frame))
end

-- Resize window to fullscreen + some spacing + random offset
hs.hotkey.bind(magic, "I", function()
    local win = hs.window.focusedWindow()    

    local screen = win:screen()
    local frame = fullScreenFrame(screen)

    if isiOSSimulator(win) then
        snapFixedSizeWindowToSide(win, SideRight)
        return
    end

    local gap = 1/12
    local maxOffset = 1/24
    frame.x = frame.w * gap + math.random(-math.floor(frame.w * maxOffset), math.floor(frame.w * maxOffset))
    frame.y = frame.h * gap + 22 + math.random(-math.floor(frame.h * maxOffset), math.floor(frame.h * maxOffset))
    frame.w = frame.w * (1 - 2*gap)
    frame.h = frame.h * (1 - 2*gap)

    win:setFrame(screen:localToAbsolute(frame))
end)

-- Resize window to fullscreen
hs.hotkey.bind(magic, "U", function()
    local win = hs.window.focusedWindow()

    if isiOSSimulator(win) then
        snapFixedSizeWindowToSide(win, SideLeft)
        return
    end

    local screen = win:screen()
    win:setFrame(fullScreenFrame(screen))
end)

---------- Moving windows between screens ------------

hs.hotkey.bind(magic, "J", function()
    local win = hs.window.focusedWindow()
    moveWindowToScreen(win, win:screen():toSouth())
end)

hs.hotkey.bind(magic, "K", function()
    local win = hs.window.focusedWindow()    
    moveWindowToScreen(win, win:screen():toNorth())
end)

hs.hotkey.bind(magic, "L", function()
    local win = hs.window.focusedWindow()    
    moveWindowToScreen(win, win:screen():toEast())
end)

hs.hotkey.bind(magic, "H", function()
    local win = hs.window.focusedWindow()    
    moveWindowToScreen(win, win:screen():toWest())
end)

---------- Snapping windows to screen edges and corners ------------

hs.hotkey.bind(magic, "Y", function()
    snapFocusedWindowToCorner(SideLeft, VSideTop)
end)

hs.hotkey.bind(magic, "O", function()
    snapFocusedWindowToCorner(SideRight, VSideTop)
end)

hs.hotkey.bind(magic, "N", function()
    snapFocusedWindowToCorner(SideLeft, VSideBottom)
end)

hs.hotkey.bind(magic, ".", function()
    snapFocusedWindowToCorner(SideRight, VSideBottom)
end)

hs.hotkey.bind(magic, "D", function()
    hs.execute("defaults write com.apple.dock persistent-apps -array && killall Dock")
end)
