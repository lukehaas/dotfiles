
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Left", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()
  local currentWidth = f.w
  local halfWidth = max.w / 2

  f.x = max.x
  f.y = max.y
  if currentWidth == halfWidth and f.x == 0 then
    f.w = max.w / 3
  else
    f.w = halfWidth
  end
  f.h = max.h
  win:setFrame(f)
end)


hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Right", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()
  local currentWidth = f.w
  local halfWidth = max.w / 2

  f.y = max.y
  if currentWidth == halfWidth and (f.x + f.w) >= max.w then
    f.x = max.x + (max.w / 3) + (max.w / 3)
    f.w = max.w / 3
  else
    f.x = max.x + (max.w / 2)
    f.w = halfWidth
  end
  f.h = max.h
  win:setFrame(f)
end)
  
hs.hotkey.bind({"cmd", "alt", "ctrl"}, "F", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w
  f.h = max.h
  win:setFrame(f)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "Up", function()
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local screenFrame = screen:frame()
  local nextScreenFrame = screen:next():frame()

  f.x = ((((f.x - screenFrame.x) / screenFrame.w) * nextScreenFrame.w) + nextScreenFrame.x)
  f.y = ((((f.y - screenFrame.y) / screenFrame.h) * nextScreenFrame.h) + nextScreenFrame.y)
  f.h = ((f.h / screenFrame.h) * nextScreenFrame.h)
  f.w = ((f.w / screenFrame.w) * nextScreenFrame.w)

  win:setFrame(f)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "=", function()
  -- expand size by 5% on sides that aren't touching a screen edge
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()
  local inc = max.w / 20
  local hInc = inc
  local vInc = inc
  -- hs.alert.show(max.w)
  if f.x > max.x and (f.x - inc) >= max.x then
    f.x = f.x - inc
    hInc = inc * 2
  elseif (f.x - inc) < max.x then
    f.x = max.x
    vInc = inc * 2
  end

  if f.y > max.y and (f.y - inc) > max.y then
    f.y = f.y - inc
  elseif (f.y - inc) < max.y then
    f.y = max.y
  end

  if f.w < max.w and (f.w + hInc) <= max.w then
    f.w = f.w + hInc
  elseif (f.w + hInc) > max.w then
    f.w = max.w
  end

  if f.h < max.h and (f.h + vInc) < max.h then
    f.h = f.h + vInc
  elseif (f.h + vInc) > max.h then
    f.h = max.h
  end

  win:setFrame(f)
end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "-", function()
  -- reduce size by 5% on sides that aren't touching a screen edge
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()
  local inc = max.w / 20
  local hInc = inc
  local vInc = inc

  if f.x > max.x and f.x < (max.x + max.w) then
    f.x = f.x + inc
    hInc = inc * 2
  end

  if f.y > max.y and f.y < (max.y + max.h) then
    f.y = f.y + inc
    vInc = inc * 2
  end

  if f.w < max.w and f.w > 0 then
    f.w = f.w - hInc
  end

  if f.h < max.h and f.h > 0 then
    f.h = f.h - vInc
  end

  if f.x == max.x and f.w == max.w then -- new
    f.x = f.x + inc
    f.w = f.w - (inc * 2)
  end

  win:setFrame(f)
end)


hs.hotkey.bind({"cmd", "alt", "ctrl"}, "A", function()
  -- Move window to left
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = 0

  win:setFrame(f)

end)

hs.hotkey.bind({"cmd", "alt", "ctrl"}, "D", function()
  -- Move window to right
  local win = hs.window.focusedWindow()
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.w - f.w

  win:setFrame(f)

end)
