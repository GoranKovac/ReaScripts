--@noindex
--NoIndex: true
local r = reaper

local WND = {
  ["Media Explorer"] = true
}

local SCRIPT_START_TIME = r.time_precise()
local prev_wnd =   r.JS_Window_FromPoint( r.GetMousePosition() )
local PIE_KEY
local pie_id = "_RS4d29f3707604c3725652ed7a634cf9a2f390a588"

for k in io.lines(r.GetResourcePath().."/reaper-kb.ini") do
    if k:match(pie_id) then
       PIE_KEY = k:match("KEY %d+ (%d+)")
    end
end

local MAIN_HWND = r.GetMainHwnd()
local function TriggerPie(title, info)
  if (WND[title] or info:match("^fx_")) and r.JS_Window_GetFocus() ~= MAIN_HWND then
     r.JS_Window_SetFocus( r.GetMainHwnd())
     r.JS_WindowMessage_Post( MAIN_HWND, "WM_KEYDOWN", PIE_KEY, 0, 0, 0 )
  end
end

local parent_title
local function Main()
     local x,y  = r.GetMousePosition()
     local wnd = r.JS_Window_FromPoint( x, y )
     local track, info = r.GetThingFromPoint(x, y)

     if prev_wnd ~= wnd then
        local wnd_id = r.JS_Window_GetLongPtr( wnd, "ID" )
        parent_title = r.JS_Window_GetTitle( r.JS_Window_GetParent( wnd ))
        prev_wnd = wnd
     end

     if prev_wnd == wnd then
       local key_state = r.JS_VKeys_GetState(SCRIPT_START_TIME-0.1)
       if key_state:byte(PIE_KEY) ~= 0 then
          SCRIPT_START_TIME = reaper.time_precise()+0.1
          TriggerPie(parent_title, info)
       end
     end
     r.defer(Main)
end

r.atexit(function() end)
Main()