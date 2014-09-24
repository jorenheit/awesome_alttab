local cairo = require("lgi").cairo
local mouse = mouse
local screen = screen
local wibox = require('wibox')
local table = table
local timer = timer
local keygrabber = keygrabber
local math = require('math')
local awful = require('awful')
local gears_surface = require("gears.surface")
local client = client
awful.client = require('awful.client')

module("alttab")

local surface = cairo.ImageSurface(cairo.Format.RGB24,20,20)
local cr = cairo.Context(surface)

-- Create a wibox to contain all the client-widgets
local preview_wbox = wibox({ bg = "#aaaaaaa0",
			     width = screen[mouse.screen].geometry.width })

preview_wbox.ontop = true
preview_wbox.visible = false
local preview_widgets = {}
local preview_live_timer = {}

local altTabTable = {}
local altTabIndex = 1

local function preview()

   local preview_live_timer = timer( {timeout = 1/30} ) -- 30 fps
   local preview_widgets = {}

   -- Make the wibox the right size, based on the number of clients
   local n = math.max(5, #altTabTable)
   local W = screen[mouse.screen].geometry.width
   local w = W / n
   local h = w * 3 / 4
   local x = 0
   local y = (screen[mouse.screen].geometry.height - h) / 2
   preview_wbox:geometry({x = x, y = y, width = W, height = h})

   -- create a list that holds the clients to preview, from left to right
   local leftRightTab = {}
   local nLeft
   local nRight
   if #altTabTable == 2 then
      nLeft = 0
      nRight = 2
   else
      nLeft = math.floor(#altTabTable / 2)
      nRight = math.ceil(#altTabTable / 2)
   end

   for i = 1, nLeft do
      table.insert(leftRightTab, altTabTable[#altTabTable - nLeft + i])
   end
   for i = 1, nRight do
      table.insert(leftRightTab, altTabTable[i])
   end

   -- create all the widgets
   for i = 1, #leftRightTab do
      preview_widgets[i] = wibox.widget.base.make_widget()
      preview_widgets[i].fit = function(preview_widget, width, height)
   	 return preview_wbox.width / n, preview_wbox.height
      end
      
      preview_widgets[i].draw = function(preview_widget, preview_wbox, cr, width, height)
   	 if width ~= 0 and height ~= 0 then
   	    local c = leftRightTab[i]
	    local a = 0.7
	    if c == altTabTable[altTabIndex] then
	       a = 0.9
	    end

   	    local cg = c:geometry()
   	    local sx = a * width / cg.width 
   	    local sy = a * height / cg.height
	    
	    cr:translate((1-a)/2 * width, (1-a)/2 * height)
	    cr:scale(sx, sy)
	    cr:set_source_surface(gears_surface(c.content), 0, 0)
	    cr:paint()

	    cr:scale(1/sx, 1/sy)
	    cr:translate((a-1)/2 * width, (a-1)/2 * height)
	    cr:set_source_rgba(0, 0, 1, 1)
	    cr.line_width = 3

	    cr:move_to(0, 0)
	    cr:line_to(width,0)

	    cr:move_to(0, height)
	    cr:line_to(width, height)
	    cr:stroke()
   	 end
      end

      preview_live_timer:connect_signal("timeout", function() 
					   preview_widgets[i]:emit_signal("widget::updated") 
      end)

   end

   -- Spacers left and right
   local spacer = wibox.widget.base.make_widget()
   spacer.fit = function(leftSpacer, width, height)
      return (W - w * #altTabTable) / 2, preview_wbox.height
   end
   spacer.draw = function(preview_widget, preview_wbox, cr, width, height) 
	    cr:set_source_rgba(0, 0, 1, 1)
	    cr.line_width = 3

	    cr:move_to(0, 0)
	    cr:line_to(width,0)

	    cr:move_to(0, height)
	    cr:line_to(width, height)
	    cr:stroke()
   end

   --layout
   preview_layout = wibox.layout.fixed.horizontal()
   
   preview_layout:add(spacer)
   for i = 1, #leftRightTab do
      preview_layout:add(preview_widgets[i])
   end
   preview_layout:add(spacer)

   preview_wbox:set_widget(preview_layout)
   preview_live_timer:start()
end


local function cycle(altTabTable, altTabIndex, altTabMinimized, dir)
   -- Switch to next client
   altTabIndex = altTabIndex + dir
   if altTabIndex > #altTabTable then
      altTabIndex = 1 -- wrap around
   elseif altTabIndex < 1 then
      altTabIndex = #altTabTable -- wrap around
   end

   return altTabIndex
end

local function switch(dir, alt, tab, shift_tab)

   altTabTable = {}
   local altTabMinimized = {}

   -- Get focus history for current tag
   local s = mouse.screen;
   local idx = 0
   local c = awful.client.focus.history.get(s, idx)

   while c do
      table.insert(altTabTable, c)
      table.insert(altTabMinimized, c.minimized)
      idx = idx + 1
      c = awful.client.focus.history.get(s, idx)
   end

   -- Minimized clients will not appear in the focus history
   -- Find them by cycling through all clients, and adding them to the list
   -- if not already there.
   -- This will preserve the history AND enable you to focus on minimized clients

   local t = awful.tag.selected(s)
   local all = client.get(s)
   

   for i = 1, #all do
      local c = all[i]
      local ctags = c:tags();

      -- check if the client is on the current tag
      local isCurrentTag = false
      for j = 1, #ctags do
	 if t == ctags[j] then
	    isCurrentTag = true
	    break
	 end
      end

      if isCurrentTag then
	 -- check if client is already in the history
	 -- if not, add it
	 local addToTable = true
	 for k = 1, #altTabTable do
	    if altTabTable[k] == c then
	       addToTable = false
	       break
	    end
	 end


	 if addToTable then
	    table.insert(altTabTable, c)
	    table.insert(altTabMinimized, c.minimized)
	 end
      end
   end

   if #altTabTable == 0 then
      return
   elseif #altTabTable == 1 then 
      altTabTable[1].minimized = false
      altTabTable[1]:raise()
      return
   end


   -- reset index
   altTabIndex = 1
   local previewDelay = 0.1
   local previewDelayTimer = timer({timeout = previewDelay})
   previewDelayTimer:connect_signal("timeout", function() 
				          preview_wbox.visible = true
					  previewDelayTimer:stop()
					  preview(altTabTable, altTabIndex) 
   end)
   previewDelayTimer:start()

   -- Now that we have collected all windows, we should run a keygrabber
   -- as long as the user is alt-tabbing:
   keygrabber.run(
      function (mod, key, event)  
	 -- Stop alt-tabbing when the alt-key is released
	 if key == alt and event == "release" then
	    
	    local c
	    for i = 1, altTabIndex - 1 do
	       c = altTabTable[altTabIndex - i]
	       c:raise()
	       client.focus = c
	    end

	    c = altTabTable[altTabIndex]
	    c:raise()
	    client.focus = c                  

	    preview_wbox.visible = false
	    previewDelayTimer:stop()
	    preview_live_timer:stop()
	    keygrabber.stop()

      	    -- Move to next client on each Tab-press
	 elseif key == tab and event == "press" then
	    altTabIndex = cycle(altTabTable, altTabIndex, altTabMinimized, 1)
	    
      	    -- Move to previous client on Shift-Tab
	 elseif key == shift_tab and event == "press" then
	    altTabIndex = cycle(altTabTable, altTabIndex, altTabMinimized, -1)
	 end
      end
   )

   -- switch to next client
   altTabIndex = cycle(altTabTable, altTabIndex, altTabMinimized, dir)

end -- function altTab

return switch
