---@diagnostic disable: keyword
---@meta


---@class (exact) ImGui_Viewport : userdata
---@class (exact) ImGui_TextFilter : ImGui_Resource
---@class (exact) ImGui_ListClipper : ImGui_Resource
---@class (exact) ImGui_ImageSet : ImGui_Image
---@class (exact) ImGui_Image : ImGui_Resource
---@class (exact) ImGui_Function : ImGui_Resource
---@class (exact) ImGui_Font : ImGui_Resource
---@class (exact) ImGui_DrawListSplitter : ImGui_Resource
---@class (exact) ImGui_DrawList : userdata
---@class (exact) ImGui_Resource : userdata
---@class (exact) ImGui_Context : ImGui_Resource


---Accept contents of a given type. If DragDropFlags_AcceptBeforeDelivery is set<br>
---you can peek into the payload before the mouse button is released.<br>
---@param ctx ImGui_Context
---@param type string
---@param payload string
---@param flagsIn? integer
---@return boolean retval
---@return string payload
function reaper.ImGui_AcceptDragDropPayload(ctx, type, payload, flagsIn) end

---Accept a list of dropped files. See AcceptDragDropPayload and GetDragDropPayloadFile.<br>
---@param ctx ImGui_Context
---@param count integer
---@param flagsIn? integer
---@return boolean retval
---@return integer count
function reaper.ImGui_AcceptDragDropPayloadFiles(ctx, count, flagsIn) end

---Accept a RGB color. See AcceptDragDropPayload.<br>
---@param ctx ImGui_Context
---@param rgb integer
---@param flagsIn? integer
---@return boolean retval
---@return integer rgb
function reaper.ImGui_AcceptDragDropPayloadRGB(ctx, rgb, flagsIn) end

---Accept a RGBA color. See AcceptDragDropPayload.<br>
---@param ctx ImGui_Context
---@param rgba integer
---@param flagsIn? integer
---@return boolean retval
---@return integer rgba
function reaper.ImGui_AcceptDragDropPayloadRGBA(ctx, rgba, flagsIn) end

---Vertically align upcoming text baseline to StyleVar_FramePadding.y so that it<br>
---will align properly to regularly framed items (call if you have text on a line<br>
---before a framed item).<br>
---@param ctx ImGui_Context
function reaper.ImGui_AlignTextToFramePadding(ctx) end

---Square button with an arrow shape. 'dir' is one of the Dir_* values<br>
---@param ctx ImGui_Context
---@param str_id string
---@param dir integer
---@return boolean retval
function reaper.ImGui_ArrowButton(ctx, str_id, dir) end

---Link the object's lifetime to the given context.<br>
---Objects can be draw list splitters, fonts, images, list clippers, etc.<br>
---Call Detach to let the object be garbage-collected after unuse again.
---
---List clipper objects may only be attached to the context they were created for.
---
---Fonts are (currently) a special case: they must be attached to the context<br>
---before usage. Furthermore, fonts may only be attached or detached immediately<br>
---after the context is created or before any other function calls modifying the<br>
---context per defer cycle. See "limitations" in the font API documentation.<br>
---@param ctx ImGui_Context
---@param obj ImGui_Resource
function reaper.ImGui_Attach(ctx, obj) end

---Push window to the stack and start appending to it.
---
---- Passing true to 'p_open' shows a window-closing widget in the upper-right<br>
---corner of the window, which clicking will set the boolean to false when returned.<br>
---- You may append multiple times to the same window during the same frame by<br>
---calling Begin()/End() pairs multiple times. Some information such as 'flags'<br>
---or 'p_open' will only be considered by the first call to Begin().<br>
---- Begin() return false to indicate the window is collapsed or fully clipped,<br>
---so you may early out and omit submitting anything to the window.<br>
---@param ctx ImGui_Context
---@param name string
---@param p_open? boolean
---@param flagsIn? integer
---@return boolean retval
---@return boolean? p_open
function reaper.ImGui_Begin(ctx, name, p_open, flagsIn) end

---For each independent axis of 'size':<br>
---- \> 0.0: fixed size<br>
---- = 0.0: use remaining host window size<br>
---- > 0.0: use remaining window size minus abs(size)<br>
---(Each axis can use a different mode, e.g. size = 0x400.)
---
---Returns false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting anything to the window.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param size_wIn? number
---@param size_hIn? number
---@param borderIn? boolean
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginChild(ctx, str_id, size_wIn, size_hIn, borderIn, flagsIn) end

---Helper to create a child window / scrolling region that looks like a normal<br>
---widget frame. See BeginChild.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param size_w number
---@param size_h number
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginChildFrame(ctx, str_id, size_w, size_h, flagsIn) end

---The BeginCombo/EndCombo API allows you to manage your contents and selection<br>
---state however you want it, by creating e.g. Selectable items.<br>
---@param ctx ImGui_Context
---@param label string
---@param preview_value string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginCombo(ctx, label, preview_value, flagsIn) end

---Disable all user interactions and dim items visuals<br>
---(applying StyleVar_DisabledAlpha over current colors).
---
---BeginDisabled(false) essentially does nothing useful but is provided to<br>
---facilitate use of boolean expressions.<br>
---If you can avoid calling BeginDisabled(false)/EndDisabled() best to avoid it.<br>
---@param ctx ImGui_Context
---@param disabledIn? boolean
function reaper.ImGui_BeginDisabled(ctx, disabledIn) end

---Call after submitting an item which may be dragged. when this return true,<br>
---you can call SetDragDropPayload() + EndDragDropSource()
---
---If you stop calling BeginDragDropSource() the payload is preserved however<br>
---it won't have a preview tooltip (we currently display a fallback "..." tooltip<br>
---as replacement).<br>
---@param ctx ImGui_Context
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginDragDropSource(ctx, flagsIn) end

---Call after submitting an item that may receive a payload.<br>
---If this returns true, you can call AcceptDragDropPayload + EndDragDropTarget.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_BeginDragDropTarget(ctx) end

---Lock horizontal starting position. See EndGroup.<br>
---@param ctx ImGui_Context
function reaper.ImGui_BeginGroup(ctx) end

---Open a framed scrolling region. This is essentially a thin wrapper to using<br>
---BeginChild/EndChild with some stylistic changes.
---
---The BeginListBox/EndListBox API allows you to manage your contents and selection<br>
---state however you want it, by creating e.g. Selectable or any items.
---
---- Choose frame width:<br>
---- width  > 0.0: custom<br>
---- width  > 0.0 or -FLT_MIN: right-align<br>
---- width  = 0.0 (default): use current ItemWidth<br>
---- Choose frame height:<br>
---- height > 0.0: custom<br>
---- height > 0.0 or -FLT_MIN: bottom-align<br>
---- height = 0.0 (default): arbitrary default height which can fit ~7 items
---
---See EndListBox.<br>
---@param ctx ImGui_Context
---@param label string
---@param size_wIn? number
---@param size_hIn? number
---@return boolean retval
function reaper.ImGui_BeginListBox(ctx, label, size_wIn, size_hIn) end

---Create a sub-menu entry. only call EndMenu if this returns true!<br>
---@param ctx ImGui_Context
---@param label string
---@param enabledIn? boolean
---@return boolean retval
function reaper.ImGui_BeginMenu(ctx, label, enabledIn) end

---Append to menu-bar of current window (requires WindowFlags_MenuBar flag set<br>
---on parent window). See EndMenuBar.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_BeginMenuBar(ctx) end

---Query popup state, if open start appending into the window. Call EndPopup<br>
---afterwards. WindowFlags* are forwarded to the window.
---
---Return true if the popup is open, and you can start outputting to it.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginPopup(ctx, str_id, flagsIn) end

---This is a helper to handle the simplest case of associating one named popup<br>
---to one given widget. You can pass a nil str_id to use the identifier of the last<br>
---item. This is essentially the same as calling OpenPopupOnItemClick + BeginPopup<br>
---but written to avoid computing the ID twice because BeginPopupContext*<br>
---functions may be called very frequently.
---
---If you want to use that on a non-interactive item such as Text you need to pass<br>
---in an explicit ID here.<br>
---@param ctx ImGui_Context
---@param str_idIn? string
---@param popup_flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginPopupContextItem(ctx, str_idIn, popup_flagsIn) end

---Open+begin popup when clicked on current window.<br>
---@param ctx ImGui_Context
---@param str_idIn? string
---@param popup_flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginPopupContextWindow(ctx, str_idIn, popup_flagsIn) end

---Block every interaction behind the window, cannot be closed by user, add a<br>
---dimming background, has a title bar. Return true if the modal is open, and you<br>
---can start outputting to it. See BeginPopup.<br>
---@param ctx ImGui_Context
---@param name string
---@param p_open? boolean
---@param flagsIn? integer
---@return boolean retval
---@return boolean? p_open
function reaper.ImGui_BeginPopupModal(ctx, name, p_open, flagsIn) end

---Create and append into a TabBar.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_BeginTabBar(ctx, str_id, flagsIn) end

---Create a Tab. Returns true if the Tab is selected.<br>
---Set 'p_open' to true to enable the close button.<br>
---@param ctx ImGui_Context
---@param label string
---@param p_open? boolean
---@param flagsIn? integer
---@return boolean retval
---@return boolean? p_open
function reaper.ImGui_BeginTabItem(ctx, label, p_open, flagsIn) end

---@param ctx ImGui_Context
---@param str_id string
---@param column integer
---@param flagsIn? integer
---@param outer_size_wIn? number
---@param outer_size_hIn? number
---@param inner_widthIn? number
---@return boolean retval
function reaper.ImGui_BeginTable(ctx, str_id, column, flagsIn, outer_size_wIn, outer_size_hIn, inner_widthIn) end

---Begin/append a tooltip window.<br>
---To create full-featured tooltip (with any kind of items).<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_BeginTooltip(ctx) end

---Draw a small circle + keep the cursor on the same line.<br>
---Advance cursor x position by GetTreeNodeToLabelSpacing,<br>
---same distance that TreeNode uses.<br>
---@param ctx ImGui_Context
function reaper.ImGui_Bullet(ctx) end

---Shortcut for Bullet + Text.<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_BulletText(ctx, text) end

---@param ctx ImGui_Context
---@param label string
---@param size_wIn? number
---@param size_hIn? number
---@return boolean retval
function reaper.ImGui_Button(ctx, label, size_wIn, size_hIn) end

---React on left mouse button (default).<br>
---@return integer retval
function reaper.ImGui_ButtonFlags_MouseButtonLeft() end

---React on center mouse button.<br>
---@return integer retval
function reaper.ImGui_ButtonFlags_MouseButtonMiddle() end

---React on right mouse button.<br>
---@return integer retval
function reaper.ImGui_ButtonFlags_MouseButtonRight() end

---@return integer retval
function reaper.ImGui_ButtonFlags_None() end

---Width of item given pushed settings and current cursor position.<br>
---NOT necessarily the width of last item unlike most 'Item' functions.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_CalcItemWidth(ctx) end

---@param ctx ImGui_Context
---@param text string
---@param w number
---@param h number
---@param hide_text_after_double_hashIn? boolean
---@param wrap_widthIn? number
---@return number w
---@return number h
function reaper.ImGui_CalcTextSize(ctx, text, w, h, hide_text_after_double_hashIn, wrap_widthIn) end

---@param ctx ImGui_Context
---@param label string
---@param v boolean
---@return boolean retval
---@return boolean v
function reaper.ImGui_Checkbox(ctx, label, v) end

---@param ctx ImGui_Context
---@param label string
---@param flags integer
---@param flags_value integer
---@return boolean retval
---@return integer flags
function reaper.ImGui_CheckboxFlags(ctx, label, flags, flags_value) end

---Manually close the popup we have begin-ed into.<br>
---Use inside the BeginPopup/EndPopup scope to close manually.
---
---CloseCurrentPopup() is called by default by Selectable/MenuItem when activated.<br>
---@param ctx ImGui_Context
function reaper.ImGui_CloseCurrentPopup(ctx) end

---@return integer retval
function reaper.ImGui_Col_Border() end

---@return integer retval
function reaper.ImGui_Col_BorderShadow() end

---@return integer retval
function reaper.ImGui_Col_Button() end

---@return integer retval
function reaper.ImGui_Col_ButtonActive() end

---@return integer retval
function reaper.ImGui_Col_ButtonHovered() end

---@return integer retval
function reaper.ImGui_Col_CheckMark() end

---Background of child windows.<br>
---@return integer retval
function reaper.ImGui_Col_ChildBg() end

---Background color for empty node (e.g. CentralNode with no window docked into it).<br>
---@return integer retval
function reaper.ImGui_Col_DockingEmptyBg() end

---Preview overlay color when about to docking something.<br>
---@return integer retval
function reaper.ImGui_Col_DockingPreview() end

---Rectangle highlighting a drop target<br>
---@return integer retval
function reaper.ImGui_Col_DragDropTarget() end

---Background of checkbox, radio button, plot, slider, text input.<br>
---@return integer retval
function reaper.ImGui_Col_FrameBg() end

---@return integer retval
function reaper.ImGui_Col_FrameBgActive() end

---@return integer retval
function reaper.ImGui_Col_FrameBgHovered() end

---Header* colors are used for CollapsingHeader, TreeNode, Selectable, MenuItem.<br>
---@return integer retval
function reaper.ImGui_Col_Header() end

---@return integer retval
function reaper.ImGui_Col_HeaderActive() end

---@return integer retval
function reaper.ImGui_Col_HeaderHovered() end

---@return integer retval
function reaper.ImGui_Col_MenuBarBg() end

---Darken/colorize entire screen behind a modal window, when one is active.<br>
---@return integer retval
function reaper.ImGui_Col_ModalWindowDimBg() end

---Gamepad/keyboard: current highlighted item.<br>
---@return integer retval
function reaper.ImGui_Col_NavHighlight() end

---Darken/colorize entire screen behind the CTRL+TAB window list, when active.<br>
---@return integer retval
function reaper.ImGui_Col_NavWindowingDimBg() end

---Highlight window when using CTRL+TAB.<br>
---@return integer retval
function reaper.ImGui_Col_NavWindowingHighlight() end

---@return integer retval
function reaper.ImGui_Col_PlotHistogram() end

---@return integer retval
function reaper.ImGui_Col_PlotHistogramHovered() end

---@return integer retval
function reaper.ImGui_Col_PlotLines() end

---@return integer retval
function reaper.ImGui_Col_PlotLinesHovered() end

---Background of popups, menus, tooltips windows.<br>
---@return integer retval
function reaper.ImGui_Col_PopupBg() end

---Resize grip in lower-right and lower-left corners of windows.<br>
---@return integer retval
function reaper.ImGui_Col_ResizeGrip() end

---@return integer retval
function reaper.ImGui_Col_ResizeGripActive() end

---@return integer retval
function reaper.ImGui_Col_ResizeGripHovered() end

---@return integer retval
function reaper.ImGui_Col_ScrollbarBg() end

---@return integer retval
function reaper.ImGui_Col_ScrollbarGrab() end

---@return integer retval
function reaper.ImGui_Col_ScrollbarGrabActive() end

---@return integer retval
function reaper.ImGui_Col_ScrollbarGrabHovered() end

---@return integer retval
function reaper.ImGui_Col_Separator() end

---@return integer retval
function reaper.ImGui_Col_SeparatorActive() end

---@return integer retval
function reaper.ImGui_Col_SeparatorHovered() end

---@return integer retval
function reaper.ImGui_Col_SliderGrab() end

---@return integer retval
function reaper.ImGui_Col_SliderGrabActive() end

---TabItem in a TabBar<br>
---@return integer retval
function reaper.ImGui_Col_Tab() end

---@return integer retval
function reaper.ImGui_Col_TabActive() end

---@return integer retval
function reaper.ImGui_Col_TabHovered() end

---@return integer retval
function reaper.ImGui_Col_TabUnfocused() end

---@return integer retval
function reaper.ImGui_Col_TabUnfocusedActive() end

---Table inner borders (prefer using Alpha=1.0 here).<br>
---@return integer retval
function reaper.ImGui_Col_TableBorderLight() end

---Table outer and header borders (prefer using Alpha=1.0 here).<br>
---@return integer retval
function reaper.ImGui_Col_TableBorderStrong() end

---Table header background.<br>
---@return integer retval
function reaper.ImGui_Col_TableHeaderBg() end

---Table row background (even rows).<br>
---@return integer retval
function reaper.ImGui_Col_TableRowBg() end

---Table row background (odd rows).<br>
---@return integer retval
function reaper.ImGui_Col_TableRowBgAlt() end

---@return integer retval
function reaper.ImGui_Col_Text() end

---@return integer retval
function reaper.ImGui_Col_TextDisabled() end

---@return integer retval
function reaper.ImGui_Col_TextSelectedBg() end

---@return integer retval
function reaper.ImGui_Col_TitleBg() end

---@return integer retval
function reaper.ImGui_Col_TitleBgActive() end

---@return integer retval
function reaper.ImGui_Col_TitleBgCollapsed() end

---Background of normal windows. See also WindowFlags_NoBackground.<br>
---@return integer retval
function reaper.ImGui_Col_WindowBg() end

---Returns true when opened but do not indent nor push into the ID stack<br>
---(because of the TreeNodeFlags_NoTreePushOnOpen flag).
---
---This is basically the same as calling TreeNode(label, TreeNodeFlags_CollapsingHeader).<br>
---You can remove the _NoTreePushOnOpen flag if you want behavior closer to normal<br>
---TreeNode.
---
---When 'visible' is provided: if 'true' display an additional small close button<br>
---on upper right of the header which will set the bool to false when clicked,<br>
---if 'false' don't display the header.<br>
---@param ctx ImGui_Context
---@param label string
---@param p_visible boolean
---@param flagsIn? integer
---@return boolean retval
---@return boolean p_visible
function reaper.ImGui_CollapsingHeader(ctx, label, p_visible, flagsIn) end

---Display a color square/button, hover for details, return true when pressed.<br>
---Color is in 0xRRGGBBAA or, if ColorEditFlags_NoAlpha is set, 0xRRGGBB.<br>
---@param ctx ImGui_Context
---@param desc_id string
---@param col_rgba integer
---@param flagsIn? integer
---@param size_wIn? number
---@param size_hIn? number
---@return boolean retval
function reaper.ImGui_ColorButton(ctx, desc_id, col_rgba, flagsIn, size_wIn, size_hIn) end

---Pack 0..1 RGBA values into a 32-bit integer (0xRRGGBBAA).<br>
---@param r number
---@param g number
---@param b number
---@param a number
---@return integer retval
function reaper.ImGui_ColorConvertDouble4ToU32(r, g, b, a) end

---Convert HSV values (0..1) into RGB (0..1).<br>
---@param h number
---@param s number
---@param v number
---@return number r
---@return number g
---@return number b
function reaper.ImGui_ColorConvertHSVtoRGB(h, s, v) end

---Convert a native color coming from REAPER or 0xRRGGBB to native.<br>
---This swaps the red and blue channels on Windows.<br>
---@param rgb integer
---@return integer retval
function reaper.ImGui_ColorConvertNative(rgb) end

---Convert RGB values (0..1) into HSV (0..1).<br>
---@param r number
---@param g number
---@param b number
---@return number h
---@return number s
---@return number v
function reaper.ImGui_ColorConvertRGBtoHSV(r, g, b) end

---Unpack a 32-bit integer (0xRRGGBBAA) into separate RGBA values (0..1).<br>
---@param rgba integer
---@return number r
---@return number g
---@return number b
---@return number a
function reaper.ImGui_ColorConvertU32ToDouble4(rgba) end

---Color is in 0xXXRRGGBB. XX is ignored and will not be modified.<br>
---@param ctx ImGui_Context
---@param label string
---@param col_rgb integer
---@param flagsIn? integer
---@return boolean retval
---@return integer col_rgb
function reaper.ImGui_ColorEdit3(ctx, label, col_rgb, flagsIn) end

---Color is in 0xRRGGBBAA or, if ColorEditFlags_NoAlpha is set, 0xXXRRGGBB<br>
---(XX is ignored and will not be modified).<br>
---@param ctx ImGui_Context
---@param label string
---@param col_rgba integer
---@param flagsIn? integer
---@return boolean retval
---@return integer col_rgba
function reaper.ImGui_ColorEdit4(ctx, label, col_rgba, flagsIn) end

---ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_AlphaBar() end

---ColorEdit, ColorPicker, ColorButton: display preview as a transparent color<br>
---over a checkerboard, instead of opaque.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_AlphaPreview() end

---ColorEdit, ColorPicker, ColorButton: display half opaque / half checkerboard,<br>
---instead of opaque.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_AlphaPreviewHalf() end

---ColorEdit: override _display_ type to HSV. ColorPicker:<br>
---select any combination using one or more of RGB/HSV/Hex.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_DisplayHSV() end

---ColorEdit: override _display_ type to Hex. ColorPicker:<br>
---select any combination using one or more of RGB/HSV/Hex.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_DisplayHex() end

---ColorEdit: override _display_ type to RGB. ColorPicker:<br>
---select any combination using one or more of RGB/HSV/Hex.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_DisplayRGB() end

---ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0..1.0<br>
---floats instead of 0..255 integers. No round-trip of value via integers.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_Float() end

---ColorEdit, ColorPicker: input and output data in HSV format.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_InputHSV() end

---ColorEdit, ColorPicker: input and output data in RGB format.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_InputRGB() end

---ColorEdit, ColorPicker, ColorButton: ignore Alpha component<br>
---(will only read 3 components from the input pointer).<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoAlpha() end

---ColorButton: disable border (which is enforced by default).<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoBorder() end

---ColorEdit: disable drag and drop target. ColorButton: disable drag and drop source.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoDragDrop() end

---ColorEdit, ColorPicker: disable inputs sliders/text widgets<br>
---(e.g. to show only the small preview color square).<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoInputs() end

---ColorEdit, ColorPicker: disable display of inline text label<br>
---(the label is still forwarded to the tooltip and picker).<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoLabel() end

---ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoOptions() end

---ColorEdit: disable picker when clicking on color square.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoPicker() end

---ColorPicker: disable bigger color preview on right side of the picker,<br>
---use small color square preview instead.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoSidePreview() end

---ColorEdit, ColorPicker: disable color square preview next to the inputs.<br>
---(e.g. to show only the inputs).<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoSmallPreview() end

---ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_NoTooltip() end

---@return integer retval
function reaper.ImGui_ColorEditFlags_None() end

---ColorPicker: bar for Hue, rectangle for Sat/Value.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_PickerHueBar() end

---ColorPicker: wheel for Hue, triangle for Sat/Value.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_PickerHueWheel() end

---ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.<br>
---@return integer retval
function reaper.ImGui_ColorEditFlags_Uint8() end

---Color is in 0xXXRRGGBB. XX is ignored and will not be modified.<br>
---@param ctx ImGui_Context
---@param label string
---@param col_rgb integer
---@param flagsIn? integer
---@return boolean retval
---@return integer col_rgb
function reaper.ImGui_ColorPicker3(ctx, label, col_rgb, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param col_rgba integer
---@param flagsIn? integer
---@param ref_colIn? integer
---@return boolean retval
---@return integer col_rgba
function reaper.ImGui_ColorPicker4(ctx, label, col_rgba, flagsIn, ref_colIn) end

---Helper over BeginCombo/EndCombo for convenience purpose. Each item must be<br>
---null-terminated (requires REAPER v6.44 or newer for EEL and Lua).<br>
---@param ctx ImGui_Context
---@param label string
---@param current_item integer
---@param items string
---@param popup_max_height_in_itemsIn? integer
---@return boolean retval
---@return integer current_item
function reaper.ImGui_Combo(ctx, label, current_item, items, popup_max_height_in_itemsIn) end

---Max ~20 items visible.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_HeightLarge() end

---As many fitting items as possible.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_HeightLargest() end

---Max ~8 items visible (default).<br>
---@return integer retval
function reaper.ImGui_ComboFlags_HeightRegular() end

---Max ~4 items visible. Tip: If you want your combo popup to be a specific size<br>
---you can use SetNextWindowSizeConstraints prior to calling BeginCombo.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_HeightSmall() end

---Display on the preview box without the square arrow button.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_NoArrowButton() end

---Display only a square arrow button.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_NoPreview() end

---@return integer retval
function reaper.ImGui_ComboFlags_None() end

---Align the popup toward the left by default.<br>
---@return integer retval
function reaper.ImGui_ComboFlags_PopupAlignLeft() end

---No condition (always set the variable).<br>
---@return integer retval
function reaper.ImGui_Cond_Always() end

---Set the variable if the object/window is appearing after being<br>
---hidden/inactive (or the first time).<br>
---@return integer retval
function reaper.ImGui_Cond_Appearing() end

---Set the variable if the object/window has no persistently saved data<br>
---(no entry in .ini file).<br>
---@return integer retval
function reaper.ImGui_Cond_FirstUseEver() end

---Set the variable once per runtime session (only the first call will succeed).<br>
---@return integer retval
function reaper.ImGui_Cond_Once() end

---[BETA] Enable docking functionality.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_DockingEnable() end

---Master keyboard navigation enable flag.<br>
---Enable full Tabbing + directional arrows + space/enter to activate.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NavEnableKeyboard() end

---Instruct navigation to move the mouse cursor.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NavEnableSetMousePos() end

---Instruct navigation to not capture global keyboard input when<br>
---ConfigFlags_NavEnableKeyboard is set (see SetNextFrameWantCaptureKeyboard).<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NavNoCaptureKeyboard() end

---Instruct imgui to ignore mouse position/buttons.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NoMouse() end

---Instruct backend to not alter mouse cursor shape and visibility.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NoMouseCursorChange() end

---Disable state restoration and persistence for the whole context.<br>
---@return integer retval
function reaper.ImGui_ConfigFlags_NoSavedSettings() end

---@return integer retval
function reaper.ImGui_ConfigFlags_None() end

---Some calls to Begin()/BeginChild() will return false.<br>
---Will cycle through window depths then repeat. Suggested use: add<br>
---"SetConfigVar(ConfigVar_DebugBeginReturnValueLoop(), GetKeyMods() == Mod_Shift"<br>
---in your main loop then occasionally press SHIFT.<br>
---Windows should be flickering while running.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DebugBeginReturnValueLoop() end

---First-time calls to Begin()/BeginChild() will return false.<br>
---**Needs to be set at context startup time** if you don't want to miss windows.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DebugBeginReturnValueOnce() end

---Simplified docking mode: disable window splitting, so docking is limited to<br>
---merging multiple windows together into tab-bars.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DockingNoSplit() end

---Make window or viewport transparent when docking and only display docking<br>
---boxes on the target viewport.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DockingTransparentPayload() end

---Enable docking with holding Shift key<br>
---(reduce visual noise, allows dropping in wider space<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DockingWithShift() end

---Enable turning Drag* widgets into text input with a simple mouse<br>
---click-release (without moving). Not desirable on devices without a keyboard.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_DragClickToInputText() end

---ConfigFlags_*<br>
---@return integer retval
function reaper.ImGui_ConfigVar_Flags() end

---Delay on hovering before IsItemHovered(HoveredFlags_DelayNormal) returns true.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_HoverDelayNormal() end

---Delay on hovering before IsItemHovered(HoveredFlags_DelayShort) returns true.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_HoverDelayShort() end

---Enable blinking cursor (optional as some users consider it to be distracting).<br>
---@return integer retval
function reaper.ImGui_ConfigVar_InputTextCursorBlink() end

---Pressing Enter will keep item active and select contents (single-line only).<br>
---@return integer retval
function reaper.ImGui_ConfigVar_InputTextEnterKeepActive() end

---Enable input queue trickling: some types of events submitted during the same<br>
---frame (e.g. button down + up) will be spread over multiple frames, improving<br>
---interactions with low framerates.
---
---Warning: when this option is disabled mouse clicks and key presses faster<br>
---than a frame will be lost.<br>
---This affects accessiblity features and some input devices.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_InputTrickleEventQueue() end

---When holding a key/button, time before it starts repeating, in seconds<br>
---(for buttons in Repeat mode, etc.).<br>
---@return integer retval
function reaper.ImGui_ConfigVar_KeyRepeatDelay() end

---When holding a key/button, rate at which it repeats, in seconds.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_KeyRepeatRate() end

---OS X style: Text editing cursor movement using Alt instead of Ctrl, Shortcuts<br>
---using Cmd/Super instead of Ctrl, Line/Text Start and End using Cmd+Arrows<br>
---instead of Home/End, Double click selects by word instead of selecting whole<br>
---text, Multi-selection in lists uses Cmd/Super instead of Ctrl.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_MacOSXBehaviors() end

---Distance threshold to stay in to validate a double-click, in pixels.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_MouseDoubleClickMaxDist() end

---Time for a double-click, in seconds.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_MouseDoubleClickTime() end

---Distance threshold before considering we are dragging.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_MouseDragThreshold() end

---Disable default OS window decoration. Enabling decoration can create<br>
---subsequent issues at OS levels (e.g. minimum window size).<br>
---@return integer retval
function reaper.ImGui_ConfigVar_ViewportsNoDecoration() end

---Enable allowing to move windows only when clicking on their title bar.<br>
---Does not apply to windows without a title bar.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly() end

---Enable resizing of windows from their edges and from the lower-left corner.<br>
---@return integer retval
function reaper.ImGui_ConfigVar_WindowsResizeFromEdges() end

---Create a new ReaImGui context.<br>
---The context will remain valid as long as it is used in each defer cycle.
---
---The label is used for the tab text when windows are docked in REAPER<br>
---and also as a unique identifier for storing settings.<br>
---@param label string
---@param config_flagsIn? integer
---@return ImGui_Context retval
function reaper.ImGui_CreateContext(label, config_flagsIn) end

---@param draw_list ImGui_DrawList
---@return ImGui_DrawListSplitter retval
function reaper.ImGui_CreateDrawListSplitter(draw_list) end

---Load a font matching a font family name or from a font file.<br>
---The font will remain valid while it's attached to a context. See Attach.
---
---The family name can be an installed font or one of the generic fonts:<br>
---sans-serif, serif, monospace, cursive, fantasy.
---
---If 'family_or_file' specifies a path to a font file (contains a / or \\):<br>
---- The first byte of 'flags' is used as the font index within the file<br>
---- The font styles in 'flags' are simulated by the font renderer<br>
---@param family_or_file string
---@param size integer
---@param flagsIn? integer
---@return ImGui_Font retval
function reaper.ImGui_CreateFont(family_or_file, size, flagsIn) end

---Compile an EEL program.
---
---Standard EEL [math](https://www.reaper.fm/sdk/js/basiccode.php#js_basicfunc)<br>
---and [string](https://www.reaper.fm/sdk/js/strings.php#js_string_funcs)<br>
---functions are available in addition to callback-specific functions<br>
---(see InputTextCallback_*).<br>
---@param code string
---@return ImGui_Function retval
function reaper.ImGui_CreateFunctionFromEEL(code) end

---The returned object is valid as long as it is used in each defer cycle<br>
---unless attached to a context (see Attach).
---
---('flags' currently unused and reserved for future expansion)<br>
---@param file string
---@param flagsIn? integer
---@return ImGui_Image retval
function reaper.ImGui_CreateImage(file, flagsIn) end

---Requires REAPER v6.44 or newer for EEL and Lua. Load from a file using<br>
---CreateImage or explicitely specify data_sz if supporting older versions.<br>
---@param data string
---@return ImGui_Image retval
function reaper.ImGui_CreateImageFromMem(data) end

---@return ImGui_ImageSet retval
function reaper.ImGui_CreateImageSet() end

---The returned clipper object is only valid for the given context and is valid<br>
---as long as it is used in each defer cycle unless attached (see Attach).<br>
---@param ctx ImGui_Context
---@return ImGui_ListClipper retval
function reaper.ImGui_CreateListClipper(ctx) end

---Valid while used every frame unless attached to a context (see Attach).<br>
---@param default_filterIn? string
---@return ImGui_TextFilter retval
function reaper.ImGui_CreateTextFilter(default_filterIn) end

---Helper tool to diagnose between text encoding issues and font loading issues.<br>
---Pass your UTF-8 string and verify that there are correct.<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_DebugTextEncoding(ctx, text) end

---Free the resources used by a context.
---
---Calling this function is usually not required as all ReaImGui objects are<br>
---automatically garbage-collected when unused.<br>
---@param ctx ImGui_Context
function reaper.ImGui_DestroyContext(ctx) end

---Unlink the object's lifetime. Unattached objects are automatically destroyed<br>
---when left unused. You may check whether an object has been destroyed using<br>
---ValidatePtr.<br>
---@param ctx ImGui_Context
---@param obj ImGui_Resource
function reaper.ImGui_Detach(ctx, obj) end

---@return integer retval
function reaper.ImGui_Dir_Down() end

---@return integer retval
function reaper.ImGui_Dir_Left() end

---@return integer retval
function reaper.ImGui_Dir_None() end

---@return integer retval
function reaper.ImGui_Dir_Right() end

---@return integer retval
function reaper.ImGui_Dir_Up() end

---@param ctx ImGui_Context
---@param label string
---@param v number
---@param v_speedIn? number
---@param v_minIn? number
---@param v_maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v
function reaper.ImGui_DragDouble(ctx, label, v, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v_speedIn? number
---@param v_minIn? number
---@param v_maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
function reaper.ImGui_DragDouble2(ctx, label, v1, v2, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param v_speedIn? number
---@param v_minIn? number
---@param v_maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
function reaper.ImGui_DragDouble3(ctx, label, v1, v2, v3, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param v4 number
---@param v_speedIn? number
---@param v_minIn? number
---@param v_maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
---@return number v4
function reaper.ImGui_DragDouble4(ctx, label, v1, v2, v3, v4, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param values reaper.array
---@param speedIn? number
---@param minIn? number
---@param maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_DragDoubleN(ctx, label, values, speedIn, minIn, maxIn, formatIn, flagsIn) end

---AcceptDragDropPayload will returns true even before the mouse button is<br>
---released. You can then check GetDragDropPayload/is_delivery to test if the<br>
---payload needs to be delivered.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_AcceptBeforeDelivery() end

---Do not draw the default highlight rectangle when hovering over target.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_AcceptNoDrawDefaultRect() end

---Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_AcceptNoPreviewTooltip() end

---For peeking ahead and inspecting the payload before delivery.<br>
---Equivalent to DragDropFlags_AcceptBeforeDelivery |<br>
---DragDropFlags_AcceptNoDrawDefaultRect.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_AcceptPeekOnly() end

---@return integer retval
function reaper.ImGui_DragDropFlags_None() end

---Allow items such as Text, Image that have no unique identifier to be used as<br>
---drag source, by manufacturing a temporary identifier based on their<br>
---window-relative position. This is extremely unusual within the dear imgui<br>
---ecosystem and so we made it explicit.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceAllowNullID() end

---Automatically expire the payload if the source cease to be submitted<br>
---(otherwise payloads are persisting while being dragged).<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceAutoExpirePayload() end

---External source (from outside of dear imgui), won't attempt to read current<br>
---item/window info. Will always return true.<br>
---Only one Extern source can be active simultaneously.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceExtern() end

---By default, when dragging we clear data so that IsItemHovered will return<br>
---false, to avoid subsequent user code submitting tooltips. This flag disables<br>
---this behavior so you can still call IsItemHovered on the source item.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceNoDisableHover() end

---Disable the behavior that allows to open tree nodes and collapsing header by<br>
---holding over them while dragging a source item.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceNoHoldToOpenOthers() end

---By default, a successful call to BeginDragDropSource opens a tooltip so you<br>
---can display a preview or description of the source contents.<br>
---This flag disables this behavior.<br>
---@return integer retval
function reaper.ImGui_DragDropFlags_SourceNoPreviewTooltip() end

---@param ctx ImGui_Context
---@param label string
---@param v_current_min number
---@param v_current_max number
---@param v_speedIn? number
---@param v_minIn? number
---@param v_maxIn? number
---@param formatIn? string
---@param format_maxIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v_current_min
---@return number v_current_max
function reaper.ImGui_DragFloatRange2(ctx, label, v_current_min, v_current_max, v_speedIn, v_minIn, v_maxIn, formatIn, format_maxIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v integer
---@param v_speedIn? number
---@param v_minIn? integer
---@param v_maxIn? integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v
function reaper.ImGui_DragInt(ctx, label, v, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v_speedIn? number
---@param v_minIn? integer
---@param v_maxIn? integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
function reaper.ImGui_DragInt2(ctx, label, v1, v2, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param v_speedIn? number
---@param v_minIn? integer
---@param v_maxIn? integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
function reaper.ImGui_DragInt3(ctx, label, v1, v2, v3, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param v4 integer
---@param v_speedIn? number
---@param v_minIn? integer
---@param v_maxIn? integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
---@return integer v4
function reaper.ImGui_DragInt4(ctx, label, v1, v2, v3, v4, v_speedIn, v_minIn, v_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v_current_min integer
---@param v_current_max integer
---@param v_speedIn? number
---@param v_minIn? integer
---@param v_maxIn? integer
---@param formatIn? string
---@param format_maxIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v_current_min
---@return integer v_current_max
function reaper.ImGui_DragIntRange2(ctx, label, v_current_min, v_current_max, v_speedIn, v_minIn, v_maxIn, formatIn, format_maxIn, flagsIn) end

---DrawList_PathStroke, DrawList_AddPolyline: specify that shape should be<br>
---closed (Important: this is always == 1 for legacy reason).<br>
---@return integer retval
function reaper.ImGui_DrawFlags_Closed() end

---@return integer retval
function reaper.ImGui_DrawFlags_None() end

---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersAll() end

---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersBottom() end

---DrawList_AddRect, DrawList_AddRectFilled, DrawList_PathRect: enable rounding<br>
---bottom-left corner only (when rounding > 0.0, we default to all corners).<br>
---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersBottomLeft() end

---DrawList_AddRect, DrawList_AddRectFilled, DrawList_PathRect: enable rounding<br>
---bottom-right corner only (when rounding > 0.0, we default to all corners).<br>
---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersBottomRight() end

---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersLeft() end

---DrawList_AddRect, DrawList_AddRectFilled, DrawList_PathRect: disable rounding<br>
---on all corners (when rounding > 0.0). This is NOT zero, NOT an implicit flag!.<br>
---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersNone() end

---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersRight() end

---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersTop() end

---DrawList_AddRect, DrawList_AddRectFilled, DrawList_PathRect: enable rounding<br>
---top-left corner only (when rounding > 0.0, we default to all corners).<br>
---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersTopLeft() end

---DrawList_AddRect, DrawList_AddRectFilled, DrawList_PathRect: enable rounding<br>
---top-right corner only (when rounding > 0.0, we default to all corners).<br>
---@return integer retval
function reaper.ImGui_DrawFlags_RoundCornersTopRight() end

---@param splitter ImGui_DrawListSplitter
function reaper.ImGui_DrawListSplitter_Clear(splitter) end

---@param splitter ImGui_DrawListSplitter
function reaper.ImGui_DrawListSplitter_Merge(splitter) end

---@param splitter ImGui_DrawListSplitter
---@param channel_idx integer
function reaper.ImGui_DrawListSplitter_SetCurrentChannel(splitter, channel_idx) end

---@param splitter ImGui_DrawListSplitter
---@param count integer
function reaper.ImGui_DrawListSplitter_Split(splitter, count) end

---Cubic Bezier (4 control points)<br>
---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param p4_x number
---@param p4_y number
---@param col_rgba integer
---@param thickness number
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_AddBezierCubic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thickness, num_segmentsIn) end

---Quadratic Bezier (3 control points)<br>
---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param col_rgba integer
---@param thickness number
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_AddBezierQuadratic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thickness, num_segmentsIn) end

---Use "num_segments == 0" to automatically calculate tessellation (preferred).<br>
---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param col_rgba integer
---@param num_segmentsIn? integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddCircle(draw_list, center_x, center_y, radius, col_rgba, num_segmentsIn, thicknessIn) end

---Use "num_segments == 0" to automatically calculate tessellation (preferred).<br>
---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param col_rgba integer
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, col_rgba, num_segmentsIn) end

---Note: Anti-aliased filling requires points to be in clockwise order.<br>
---@param draw_list ImGui_DrawList
---@param points reaper.array
---@param col_rgba integer
function reaper.ImGui_DrawList_AddConvexPolyFilled(draw_list, points, col_rgba) end

---@param draw_list ImGui_DrawList
---@param img ImGui_Image
---@param p_min_x number
---@param p_min_y number
---@param p_max_x number
---@param p_max_y number
---@param uv_min_xIn? number
---@param uv_min_yIn? number
---@param uv_max_xIn? number
---@param uv_max_yIn? number
---@param col_rgbaIn? integer
function reaper.ImGui_DrawList_AddImage(draw_list, img, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_xIn, uv_min_yIn, uv_max_xIn, uv_max_yIn, col_rgbaIn) end

---@param draw_list ImGui_DrawList
---@param img ImGui_Image
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param p4_x number
---@param p4_y number
---@param uv1_xIn? number
---@param uv1_yIn? number
---@param uv2_xIn? number
---@param uv2_yIn? number
---@param uv3_xIn? number
---@param uv3_yIn? number
---@param uv4_xIn? number
---@param uv4_yIn? number
---@param col_rgbaIn? integer
function reaper.ImGui_DrawList_AddImageQuad(draw_list, img, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, uv1_xIn, uv1_yIn, uv2_xIn, uv2_yIn, uv3_xIn, uv3_yIn, uv4_xIn, uv4_yIn, col_rgbaIn) end

---@param draw_list ImGui_DrawList
---@param img ImGui_Image
---@param p_min_x number
---@param p_min_y number
---@param p_max_x number
---@param p_max_y number
---@param uv_min_x number
---@param uv_min_y number
---@param uv_max_x number
---@param uv_max_y number
---@param col_rgba integer
---@param rounding number
---@param flagsIn? integer
function reaper.ImGui_DrawList_AddImageRounded(draw_list, img, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_x, uv_min_y, uv_max_x, uv_max_y, col_rgba, rounding, flagsIn) end

---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param col_rgba integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, thicknessIn) end

---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param col_rgba integer
---@param num_segments integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddNgon(draw_list, center_x, center_y, radius, col_rgba, num_segments, thicknessIn) end

---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param col_rgba integer
---@param num_segments integer
function reaper.ImGui_DrawList_AddNgonFilled(draw_list, center_x, center_y, radius, col_rgba, num_segments) end

---Points is a list of x,y coordinates.<br>
---@param draw_list ImGui_DrawList
---@param points reaper.array
---@param col_rgba integer
---@param flags integer
---@param thickness number
function reaper.ImGui_DrawList_AddPolyline(draw_list, points, col_rgba, flags, thickness) end

---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param p4_x number
---@param p4_y number
---@param col_rgba integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddQuad(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thicknessIn) end

---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param p4_x number
---@param p4_y number
---@param col_rgba integer
function reaper.ImGui_DrawList_AddQuadFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba) end

---@param draw_list ImGui_DrawList
---@param p_min_x number
---@param p_min_y number
---@param p_max_x number
---@param p_max_y number
---@param col_rgba integer
---@param roundingIn? number
---@param flagsIn? integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddRect(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, roundingIn, flagsIn, thicknessIn) end

---@param draw_list ImGui_DrawList
---@param p_min_x number
---@param p_min_y number
---@param p_max_x number
---@param p_max_y number
---@param col_rgba integer
---@param roundingIn? number
---@param flagsIn? integer
function reaper.ImGui_DrawList_AddRectFilled(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, roundingIn, flagsIn) end

---@param draw_list ImGui_DrawList
---@param p_min_x number
---@param p_min_y number
---@param p_max_x number
---@param p_max_y number
---@param col_upr_left integer
---@param col_upr_right integer
---@param col_bot_right integer
---@param col_bot_left integer
function reaper.ImGui_DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_upr_left, col_upr_right, col_bot_right, col_bot_left) end

---@param draw_list ImGui_DrawList
---@param x number
---@param y number
---@param col_rgba integer
---@param text string
function reaper.ImGui_DrawList_AddText(draw_list, x, y, col_rgba, text) end

---The last pushed font is used if font is nil.<br>
---The size of the last pushed font is used if font_size is 0.<br>
---cpu_fine_clip_rect_* only takes effect if all four are non-nil.<br>
---@param draw_list ImGui_DrawList
---@param font ImGui_Font|nil
---@param font_size number
---@param pos_x number
---@param pos_y number
---@param col_rgba integer
---@param text string
---@param wrap_widthIn? number
---@param cpu_fine_clip_rect_xIn? number
---@param cpu_fine_clip_rect_yIn? number
---@param cpu_fine_clip_rect_wIn? number
---@param cpu_fine_clip_rect_hIn? number
function reaper.ImGui_DrawList_AddTextEx(draw_list, font, font_size, pos_x, pos_y, col_rgba, text, wrap_widthIn, cpu_fine_clip_rect_xIn, cpu_fine_clip_rect_yIn, cpu_fine_clip_rect_wIn, cpu_fine_clip_rect_hIn) end

---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param col_rgba integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_AddTriangle(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thicknessIn) end

---@param draw_list ImGui_DrawList
---@param p1_x number
---@param p1_y number
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param col_rgba integer
function reaper.ImGui_DrawList_AddTriangleFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba) end

---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param a_min number
---@param a_max number
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_PathArcTo(draw_list, center_x, center_y, radius, a_min, a_max, num_segmentsIn) end

---Use precomputed angles for a 12 steps circle.<br>
---@param draw_list ImGui_DrawList
---@param center_x number
---@param center_y number
---@param radius number
---@param a_min_of_12 integer
---@param a_max_of_12 integer
function reaper.ImGui_DrawList_PathArcToFast(draw_list, center_x, center_y, radius, a_min_of_12, a_max_of_12) end

---Cubic Bezier (4 control points)<br>
---@param draw_list ImGui_DrawList
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param p4_x number
---@param p4_y number
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_PathBezierCubicCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, num_segmentsIn) end

---Quadratic Bezier (3 control points)<br>
---@param draw_list ImGui_DrawList
---@param p2_x number
---@param p2_y number
---@param p3_x number
---@param p3_y number
---@param num_segmentsIn? integer
function reaper.ImGui_DrawList_PathBezierQuadraticCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, num_segmentsIn) end

---@param draw_list ImGui_DrawList
function reaper.ImGui_DrawList_PathClear(draw_list) end

---Note: Anti-aliased filling requires points to be in clockwise order.<br>
---@param draw_list ImGui_DrawList
---@param col_rgba integer
function reaper.ImGui_DrawList_PathFillConvex(draw_list, col_rgba) end

---@param draw_list ImGui_DrawList
---@param pos_x number
---@param pos_y number
function reaper.ImGui_DrawList_PathLineTo(draw_list, pos_x, pos_y) end

---@param draw_list ImGui_DrawList
---@param rect_min_x number
---@param rect_min_y number
---@param rect_max_x number
---@param rect_max_y number
---@param roundingIn? number
---@param flagsIn? integer
function reaper.ImGui_DrawList_PathRect(draw_list, rect_min_x, rect_min_y, rect_max_x, rect_max_y, roundingIn, flagsIn) end

---@param draw_list ImGui_DrawList
---@param col_rgba integer
---@param flagsIn? integer
---@param thicknessIn? number
function reaper.ImGui_DrawList_PathStroke(draw_list, col_rgba, flagsIn, thicknessIn) end

---See DrawList_PushClipRect<br>
---@param draw_list ImGui_DrawList
function reaper.ImGui_DrawList_PopClipRect(draw_list) end

---Render-level scissoring. Prefer using higher-level PushClipRect to affect<br>
---logic (hit-testing and widget culling).<br>
---@param draw_list ImGui_DrawList
---@param clip_rect_min_x number
---@param clip_rect_min_y number
---@param clip_rect_max_x number
---@param clip_rect_max_y number
---@param intersect_with_current_clip_rectIn? boolean
function reaper.ImGui_DrawList_PushClipRect(draw_list, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rectIn) end

---@param draw_list ImGui_DrawList
function reaper.ImGui_DrawList_PushClipRectFullScreen(draw_list) end

---Add a dummy item of given size. unlike InvisibleButton, Dummy() won't take the<br>
---mouse click or be navigable into.<br>
---@param ctx ImGui_Context
---@param size_w number
---@param size_h number
function reaper.ImGui_Dummy(ctx, size_w, size_h) end

---Pop window from the stack. See Begin.<br>
---@param ctx ImGui_Context
function reaper.ImGui_End(ctx) end

---See BeginChild.<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndChild(ctx) end

---See BeginChildFrame.<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndChildFrame(ctx) end

---Only call EndCombo() if BeginCombo returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndCombo(ctx) end

---See BeginDisabled.<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndDisabled(ctx) end

---Only call EndDragDropSource() if BeginDragDropSource returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndDragDropSource(ctx) end

---Only call EndDragDropTarget() if BeginDragDropTarget returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndDragDropTarget(ctx) end

---Unlock horizontal starting position + capture the whole group bounding box<br>
---into one "item" (so you can use IsItemHovered or layout primitives such as<br>
---SameLine on whole group, etc.).
---
---See BeginGroup.<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndGroup(ctx) end

---Only call EndListBox() if BeginListBox returned true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndListBox(ctx) end

---Only call EndMenu() if BeginMenu returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndMenu(ctx) end

---Only call EndMenuBar if BeginMenuBar returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndMenuBar(ctx) end

---Only call EndPopup() if BeginPopup*() returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndPopup(ctx) end

---Only call EndTabBar() if BeginTabBar() returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndTabBar(ctx) end

---Only call EndTabItem() if BeginTabItem() returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndTabItem(ctx) end

---Only call EndTable() if BeginTable() returns true!<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndTable(ctx) end

---Only call EndTooltip() if BeginTooltip() returns true.<br>
---@param ctx ImGui_Context
function reaper.ImGui_EndTooltip(ctx) end

---Return true if any window is focused.<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_AnyWindow() end

---Return true if any children of the window is focused.<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_ChildWindows() end

---Consider docking hierarchy (treat dockspace host as parent of docked window)<br>
---(when used with _ChildWindows or _RootWindow).<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_DockHierarchy() end

---Do not consider popup hierarchy (do not treat popup emitter as parent of<br>
---popup) (when used with _ChildWindows or _RootWindow).<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_NoPopupHierarchy() end

---@return integer retval
function reaper.ImGui_FocusedFlags_None() end

---FocusedFlags_RootWindow | FocusedFlags_ChildWindows<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_RootAndChildWindows() end

---Test from root window (top most parent of the current hierarchy).<br>
---@return integer retval
function reaper.ImGui_FocusedFlags_RootWindow() end

---@return integer retval
function reaper.ImGui_FontFlags_Bold() end

---@return integer retval
function reaper.ImGui_FontFlags_Italic() end

---@return integer retval
function reaper.ImGui_FontFlags_None() end

---@param func ImGui_Function
function reaper.ImGui_Function_Execute(func) end

---@param func ImGui_Function
---@param name string
---@return number retval
function reaper.ImGui_Function_GetValue(func, name) end

---Copy the values in the function's memory starting at the address stored<br>
---in the given variable into the array.<br>
---@param func ImGui_Function
---@param name string
---@param values reaper.array
function reaper.ImGui_Function_GetValue_Array(func, name, values) end

---Read from a string slot or a named string (when name starts with a `#`).<br>
---@param func ImGui_Function
---@param name string
---@return string retval
function reaper.ImGui_Function_GetValue_String(func, name) end

---@param func ImGui_Function
---@param name string
---@param value number
function reaper.ImGui_Function_SetValue(func, name, value) end

---Copy the values in the array to the function's memory at the address stored<br>
---in the given variable.<br>
---@param func ImGui_Function
---@param name string
---@param values reaper.array
function reaper.ImGui_Function_SetValue_Array(func, name, values) end

---Write to a string slot or a named string (when name starts with a `#`).<br>
---@param func ImGui_Function
---@param name string
---@param value string
function reaper.ImGui_Function_SetValue_String(func, name, value) end

---This draw list will be the first rendering one. Useful to quickly draw<br>
---shapes/text behind dear imgui contents.<br>
---@param ctx ImGui_Context
---@return ImGui_DrawList retval
function reaper.ImGui_GetBackgroundDrawList(ctx) end

---@param ctx ImGui_Context
---@return string retval
function reaper.ImGui_GetClipboardText(ctx) end

---Retrieve given style color with style alpha applied and optional extra alpha<br>
---multiplier, packed as a 32-bit value (RGBA). See Col_* for available style colors.<br>
---@param ctx ImGui_Context
---@param idx integer
---@param alpha_mulIn? number
---@return integer retval
function reaper.ImGui_GetColor(ctx, idx, alpha_mulIn) end

---Retrieve given color with style alpha applied, packed as a 32-bit value (RGBA).<br>
---@param ctx ImGui_Context
---@param col_rgba integer
---@return integer retval
function reaper.ImGui_GetColorEx(ctx, col_rgba) end

---@param ctx ImGui_Context
---@param var_idx integer
---@return number retval
function reaper.ImGui_GetConfigVar(ctx, var_idx) end

---== GetContentRegionMax() - GetCursorPos()<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetContentRegionAvail(ctx) end

---Current content boundaries (typically window boundaries including scrolling,<br>
---or current column boundaries), in windows coordinates.<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetContentRegionMax(ctx) end

---Cursor position in window<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetCursorPos(ctx) end

---Cursor X position in window<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetCursorPosX(ctx) end

---Cursor Y position in window<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetCursorPosY(ctx) end

---Cursor position in absolute screen coordinates (useful to work with the DrawList API).<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetCursorScreenPos(ctx) end

---Initial cursor position in window coordinates.<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetCursorStartPos(ctx) end

---Time elapsed since last frame, in seconds.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetDeltaTime(ctx) end

---Peek directly into the current payload from anywhere.<br>
---@param ctx ImGui_Context
---@return boolean retval
---@return string type
---@return string payload
---@return boolean is_preview
---@return boolean is_delivery
function reaper.ImGui_GetDragDropPayload(ctx) end

---Get a filename from the list of dropped files.<br>
---Returns false if index is out of bounds.<br>
---@param ctx ImGui_Context
---@param index integer
---@return boolean retval
---@return string filename
function reaper.ImGui_GetDragDropPayloadFile(ctx, index) end

---Get the current font<br>
---@param ctx ImGui_Context
---@return ImGui_Font retval
function reaper.ImGui_GetFont(ctx) end

---Get current font size (= height in pixels) of current font with current scale<br>
---applied.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetFontSize(ctx) end

---This draw list will be the last rendered one. Useful to quickly draw<br>
---shapes/text over dear imgui contents.<br>
---@param ctx ImGui_Context
---@return ImGui_DrawList retval
function reaper.ImGui_GetForegroundDrawList(ctx) end

---Get global imgui frame count. incremented by 1 every frame.<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_GetFrameCount(ctx) end

---GetFontSize + StyleVar_FramePadding.y * 2<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetFrameHeight(ctx) end

---GetFontSize + StyleVar_FramePadding.y * 2 + StyleVar_ItemSpacing.y<br>
---(distance in pixels between 2 consecutive lines of framed widgets).<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetFrameHeightWithSpacing(ctx) end

---Estimate of application framerate (rolling average over 60 frames, based on<br>
---GetDeltaTime), in frame per second. Solely for convenience.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetFramerate(ctx) end

---Read from ImGui's character input queue.<br>
---Call with increasing idx until false is returned.<br>
---@param ctx ImGui_Context
---@param idx integer
---@return boolean retval
---@return integer unicode_char
function reaper.ImGui_GetInputQueueCharacter(ctx, idx) end

---Get lower-right bounding rectangle of the last item (screen space)<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetItemRectMax(ctx) end

---Get upper-left bounding rectangle of the last item (screen space)<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetItemRectMin(ctx) end

---Get size of last item<br>
---@param ctx ImGui_Context
---@return number w
---@return number h
function reaper.ImGui_GetItemRectSize(ctx) end

---Duration the keyboard key has been down (0.0 == just pressed)<br>
---@param ctx ImGui_Context
---@param key integer
---@return number retval
function reaper.ImGui_GetKeyDownDuration(ctx, key) end

---Flags for the Ctrl/Shift/Alt/Super keys. Uses Mod_* values.<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_GetKeyMods(ctx) end

---Uses provided repeat rate/delay. Return a count, most often 0 or 1 but might<br>
---be >1 if ConfigVar_RepeatRate is small enough that GetDeltaTime > RepeatRate.<br>
---@param ctx ImGui_Context
---@param key integer
---@param repeat_delay number
---@param rate number
---@return integer retval
function reaper.ImGui_GetKeyPressedAmount(ctx, key, repeat_delay, rate) end

---Currently represents REAPER's main window (arrange view).<br>
---WARNING: This may change or be removed in the future.<br>
---@param ctx ImGui_Context
---@return ImGui_Viewport retval
function reaper.ImGui_GetMainViewport(ctx) end

---Return the number of successive mouse-clicks at the time where a click happen (otherwise 0).<br>
---@param ctx ImGui_Context
---@param button integer
---@return integer retval
function reaper.ImGui_GetMouseClickedCount(ctx, button) end

---@param ctx ImGui_Context
---@param button integer
---@return number x
---@return number y
function reaper.ImGui_GetMouseClickedPos(ctx, button) end

---Get desired mouse cursor shape, reset every frame. This is updated during the frame.<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_GetMouseCursor(ctx) end

---Mouse delta. Note that this is zero if either current or previous position<br>
---are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have<br>
---a huge delta.<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetMouseDelta(ctx) end

---Duration the mouse button has been down (0.0 == just clicked)<br>
---@param ctx ImGui_Context
---@param button integer
---@return number retval
function reaper.ImGui_GetMouseDownDuration(ctx, button) end

---Return the delta from the initial clicking position while the mouse button is<br>
---pressed or was just released. This is locked and return 0.0 until the mouse<br>
---moves past a distance threshold at least once (if lock_threshold > -1.0, uses<br>
---ConfigVar_MouseDragThreshold).<br>
---@param ctx ImGui_Context
---@param x number
---@param y number
---@param buttonIn? integer
---@param lock_thresholdIn? number
---@return number x
---@return number y
function reaper.ImGui_GetMouseDragDelta(ctx, x, y, buttonIn, lock_thresholdIn) end

---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetMousePos(ctx) end

---Retrieve mouse position at the time of opening popup we have BeginPopup()<br>
---into (helper to avoid user backing that value themselves).<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetMousePosOnOpeningCurrentPopup(ctx) end

---Vertical: 1 unit scrolls about 5 lines text. >0 scrolls Up, >0 scrolls Down.<br>
---Hold SHIFT to turn vertical scroll into horizontal scroll
---
---Horizontal: >0 scrolls Left, >0 scrolls Right.<br>
---Most users don't have a mouse with a horizontal wheel.<br>
---@param ctx ImGui_Context
---@return number vertical
---@return number horizontal
function reaper.ImGui_GetMouseWheel(ctx) end

---Get maximum scrolling amount ~~ ContentSize.x - WindowSize.x - DecorationsSize.x<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetScrollMaxX(ctx) end

---Get maximum scrolling amount ~~ ContentSize.y - WindowSize.y - DecorationsSize.y<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetScrollMaxY(ctx) end

---Get scrolling amount [0 .. GetScrollMaxX()]<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetScrollX(ctx) end

---Get scrolling amount [0 .. GetScrollMaxY()]<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetScrollY(ctx) end

---Retrieve style color as stored in ImGuiStyle structure.<br>
---Use to feed back into PushStyleColor, Otherwise use GetColor to get style color<br>
---with style alpha baked in. See Col_* for available style colors.<br>
---@param ctx ImGui_Context
---@param idx integer
---@return integer retval
function reaper.ImGui_GetStyleColor(ctx, idx) end

---@param ctx ImGui_Context
---@param var_idx integer
---@return number val1
---@return number val2
function reaper.ImGui_GetStyleVar(ctx, var_idx) end

---Same as GetFontSize<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetTextLineHeight(ctx) end

---GetFontSize + StyleVar_ItemSpacing.y<br>
---(distance in pixels between 2 consecutive lines of text).<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetTextLineHeightWithSpacing(ctx) end

---Get global imgui time. Incremented every frame.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetTime(ctx) end

---Horizontal distance preceding label when using TreeNode*() or Bullet()<br>
---== (GetFontSize + StyleVar_FramePadding.x*2) for a regular unframed TreeNode.<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetTreeNodeToLabelSpacing(ctx) end

---@return string imgui_version
---@return integer imgui_version_num
---@return string reaimgui_version
function reaper.ImGui_GetVersion() end

---Content boundaries max (roughly (0,0)+Size-Scroll) where Size can be<br>
---overridden with SetNextWindowContentSize, in window coordinates.<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetWindowContentRegionMax(ctx) end

---Content boundaries min (roughly (0,0)-Scroll), in window coordinates.<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetWindowContentRegionMin(ctx) end

---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_GetWindowDockID(ctx) end

---Get DPI scale currently associated to the current window's viewport<br>
---(1.0 = 96 DPI).<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetWindowDpiScale(ctx) end

---The draw list associated to the current window, to append your own drawing primitives<br>
---@param ctx ImGui_Context
---@return ImGui_DrawList retval
function reaper.ImGui_GetWindowDrawList(ctx) end

---Get current window height (shortcut for (select(2, GetWindowSize())).<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetWindowHeight(ctx) end

---Get current window position in screen space (useful if you want to do your own<br>
---drawing via the DrawList API).<br>
---@param ctx ImGui_Context
---@return number x
---@return number y
function reaper.ImGui_GetWindowPos(ctx) end

---Get current window size<br>
---@param ctx ImGui_Context
---@return number w
---@return number h
function reaper.ImGui_GetWindowSize(ctx) end

---Get viewport currently associated to the current window.<br>
---@param ctx ImGui_Context
---@return ImGui_Viewport retval
function reaper.ImGui_GetWindowViewport(ctx) end

---Get current window width (shortcut for (select(1, GetWindowSize())).<br>
---@param ctx ImGui_Context
---@return number retval
function reaper.ImGui_GetWindowWidth(ctx) end

---Return true even if an active item is blocking access to this item/window.<br>
---Useful for Drag and Drop patterns.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_AllowWhenBlockedByActiveItem() end

---Return true even if a popup window is normally blocking access to this item/window.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_AllowWhenBlockedByPopup() end

---IsItemHovered only: Return true even if the item is disabled.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_AllowWhenDisabled() end

---IsItemHovered only: Return true even if the position is obstructed or<br>
---overlapped by another window.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_AllowWhenOverlapped() end

---IsWindowHovered only: Return true if any window is hovered.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_AnyWindow() end

---IsWindowHovered only: Return true if any children of the window is hovered.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_ChildWindows() end

---Return true after ConfigVar_HoverDelayNormal elapsed (~0.30 sec)<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_DelayNormal() end

---Return true after ConfigVar_HoverDelayShort elapsed (~0.10 sec)<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_DelayShort() end

---IsWindowHovered only: Consider docking hierarchy (treat dockspace host as<br>
---parent of docked window) (when used with _ChildWindows or _RootWindow).<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_DockHierarchy() end

---Disable using gamepad/keyboard navigation state when active, always query mouse.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_NoNavOverride() end

---IsWindowHovered only: Do not consider popup hierarchy (do not treat popup<br>
---emitter as parent of popup) (when used with _ChildWindows or _RootWindow).<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_NoPopupHierarchy() end

---Disable shared delay system where moving from one item to the next keeps<br>
---the previous timer for a short time (standard for tooltips with long delays<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_NoSharedDelay() end

---Return true if directly over the item/window, not obstructed by another<br>
---window, not obstructed by an active popup or modal blocking inputs under them.<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_None() end

---HoveredFlags_AllowWhenBlockedByPopup |<br>
---HoveredFlags_AllowWhenBlockedByActiveItem | HoveredFlags_AllowWhenOverlapped<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_RectOnly() end

---HoveredFlags_RootWindow | HoveredFlags_ChildWindows<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_RootAndChildWindows() end

---IsWindowHovered only: Test from root window (top most parent of the current hierarchy).<br>
---@return integer retval
function reaper.ImGui_HoveredFlags_RootWindow() end

---@param ctx ImGui_Context
---@param img ImGui_Image
---@param size_w number
---@param size_h number
---@param uv0_xIn? number
---@param uv0_yIn? number
---@param uv1_xIn? number
---@param uv1_yIn? number
---@param tint_col_rgbaIn? integer
---@param border_col_rgbaIn? integer
function reaper.ImGui_Image(ctx, img, size_w, size_h, uv0_xIn, uv0_yIn, uv1_xIn, uv1_yIn, tint_col_rgbaIn, border_col_rgbaIn) end

---@param ctx ImGui_Context
---@param str_id string
---@param img ImGui_Image
---@param size_w number
---@param size_h number
---@param uv0_xIn? number
---@param uv0_yIn? number
---@param uv1_xIn? number
---@param uv1_yIn? number
---@param bg_col_rgbaIn? integer
---@param tint_col_rgbaIn? integer
---@return boolean retval
function reaper.ImGui_ImageButton(ctx, str_id, img, size_w, size_h, uv0_xIn, uv0_yIn, uv1_xIn, uv1_yIn, bg_col_rgbaIn, tint_col_rgbaIn) end

---'img' cannot be another ImageSet.<br>
---@param set ImGui_ImageSet
---@param scale number
---@param img ImGui_Image
function reaper.ImGui_ImageSet_Add(set, scale, img) end

---@param img ImGui_Image
---@return number w
---@return number h
function reaper.ImGui_Image_GetSize(img) end

---Move content position toward the right, by 'indent_w', or<br>
---StyleVar_IndentSpacing if 'indent_w' >= 0. See Unindent.<br>
---@param ctx ImGui_Context
---@param indent_wIn? number
function reaper.ImGui_Indent(ctx, indent_wIn) end

---@param ctx ImGui_Context
---@param label string
---@param v number
---@param stepIn? number
---@param step_fastIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v
function reaper.ImGui_InputDouble(ctx, label, v, stepIn, step_fastIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
function reaper.ImGui_InputDouble2(ctx, label, v1, v2, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
function reaper.ImGui_InputDouble3(ctx, label, v1, v2, v3, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param v4 number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
---@return number v4
function reaper.ImGui_InputDouble4(ctx, label, v1, v2, v3, v4, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param values reaper.array
---@param stepIn? number
---@param step_fastIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_InputDoubleN(ctx, label, values, stepIn, step_fastIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v integer
---@param stepIn? integer
---@param step_fastIn? integer
---@param flagsIn? integer
---@return boolean retval
---@return integer v
function reaper.ImGui_InputInt(ctx, label, v, stepIn, step_fastIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
function reaper.ImGui_InputInt2(ctx, label, v1, v2, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
function reaper.ImGui_InputInt3(ctx, label, v1, v2, v3, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param v4 integer
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
---@return integer v4
function reaper.ImGui_InputInt4(ctx, label, v1, v2, v3, v4, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param buf string
---@param flagsIn? integer
---@param callbackIn? ImGui_Function
---@return boolean retval
---@return string buf
function reaper.ImGui_InputText(ctx, label, buf, flagsIn, callbackIn) end

---Pressing TAB input a '\t' character into the text field.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_AllowTabInput() end

---Overwrite mode.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_AlwaysOverwrite() end

---Select entire text when first taking mouse focus.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_AutoSelectAll() end

---Callback on each iteration. User code may query cursor position, modify text buffer.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CallbackAlways() end

---Callback on character inputs to replace or discard them.<br>
---Modify 'EventChar' to replace or 'EventChar = 0' to discard.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CallbackCharFilter() end

---Callback on pressing TAB (for completion handling).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CallbackCompletion() end

---Callback on any edit (note that InputText() already returns true on edit,<br>
---the callback is useful mainly to manipulate the underlying buffer while<br>
---focus is active).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CallbackEdit() end

---Callback on pressing Up/Down arrows (for history handling).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CallbackHistory() end

---Allow 0123456789.+-*/.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CharsDecimal() end

---Allow 0123456789ABCDEFabcdef.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CharsHexadecimal() end

---Filter out spaces, tabs.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CharsNoBlank() end

---Allow 0123456789.+-*/eE (Scientific notation input).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CharsScientific() end

---Turn a..z into A..Z.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CharsUppercase() end

---In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter<br>
---(default is opposite: unfocus with Ctrl+Enter, add line with Enter).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_CtrlEnterForNewLine() end

---Return 'true' when Enter is pressed (as opposed to every time the value was<br>
---modified). Consider looking at the IsItemDeactivatedAfterEdit function.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_EnterReturnsTrue() end

---Escape key clears content if not empty, and deactivate otherwise<br>
---(constrast to default behavior of Escape to revert).<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_EscapeClearsAll() end

---Disable following the cursor horizontally.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_NoHorizontalScroll() end

---Disable undo/redo. Note that input text owns the text data while active.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_NoUndoRedo() end

---@return integer retval
function reaper.ImGui_InputTextFlags_None() end

---Password mode, display all characters as '*'.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_Password() end

---Read-only mode.<br>
---@return integer retval
function reaper.ImGui_InputTextFlags_ReadOnly() end

---@param ctx ImGui_Context
---@param label string
---@param buf string
---@param size_wIn? number
---@param size_hIn? number
---@param flagsIn? integer
---@param callbackIn? ImGui_Function
---@return boolean retval
---@return string buf
function reaper.ImGui_InputTextMultiline(ctx, label, buf, size_wIn, size_hIn, flagsIn, callbackIn) end

---@param ctx ImGui_Context
---@param label string
---@param hint string
---@param buf string
---@param flagsIn? integer
---@param callbackIn? ImGui_Function
---@return boolean retval
---@return string buf
function reaper.ImGui_InputTextWithHint(ctx, label, hint, buf, flagsIn, callbackIn) end

---Flexible button behavior without the visuals, frequently useful to build<br>
---custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.).<br>
---@param ctx ImGui_Context
---@param str_id string
---@param size_w number
---@param size_h number
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_InvisibleButton(ctx, str_id, size_w, size_h, flagsIn) end

---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsAnyItemActive(ctx) end

---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsAnyItemFocused(ctx) end

---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsAnyItemHovered(ctx) end

---Is any mouse button held?<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsAnyMouseDown(ctx) end

---Was the last item just made active (item was previously inactive).<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemActivated(ctx) end

---Is the last item active? (e.g. button being held, text field being edited.<br>
---This will continuously return true while holding mouse button on an item.<br>
---Items that don't interact will always return false.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemActive(ctx) end

---Is the last item clicked? (e.g. button/node just clicked on)<br>
---== IsMouseClicked(mouse_button) && IsItemHovered().
---
---This is NOT equivalent to the behavior of e.g. Button.<br>
---Most widgets have specific reactions based on mouse-up/down state, mouse position etc.<br>
---@param ctx ImGui_Context
---@param mouse_buttonIn? integer
---@return boolean retval
function reaper.ImGui_IsItemClicked(ctx, mouse_buttonIn) end

---Was the last item just made inactive (item was previously active).<br>
---Useful for Undo/Redo patterns with widgets that require continuous editing.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemDeactivated(ctx) end

---Was the last item just made inactive and made a value change when it was<br>
---active? (e.g. Slider/Drag moved).
---
---Useful for Undo/Redo patterns with widgets that require continuous editing. Note<br>
---that you may get false positives (some widgets such as Combo/ListBox/Selectable<br>
---will return true even when clicking an already selected item).<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemDeactivatedAfterEdit(ctx) end

---Did the last item modify its underlying value this frame? or was pressed?<br>
---This is generally the same as the "bool" return value of many widgets.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemEdited(ctx) end

---Is the last item focused for keyboard/gamepad navigation?<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemFocused(ctx) end

---Is the last item hovered? (and usable, aka not blocked by a popup, etc.).<br>
---See HoveredFlags_* for more options.<br>
---@param ctx ImGui_Context
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_IsItemHovered(ctx, flagsIn) end

---Was the last item open state toggled? Set by TreeNode.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemToggledOpen(ctx) end

---Is the last item visible? (items may be out of sight because of clipping/scrolling)<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsItemVisible(ctx) end

---Is key being held.<br>
---@param ctx ImGui_Context
---@param key integer
---@return boolean retval
function reaper.ImGui_IsKeyDown(ctx, key) end

---Was key pressed (went from !Down to Down)?<br>
---If repeat=true, uses ConfigVar_KeyRepeatDelay / ConfigVar_KeyRepeatRate.<br>
---@param ctx ImGui_Context
---@param key integer
---@param repeatIn? boolean
---@return boolean retval
function reaper.ImGui_IsKeyPressed(ctx, key, repeatIn) end

---Was key released (went from Down to !Down)?<br>
---@param ctx ImGui_Context
---@param key integer
---@return boolean retval
function reaper.ImGui_IsKeyReleased(ctx, key) end

---Did mouse button clicked? (went from !Down to Down).<br>
---Same as GetMouseClickedCount() == 1.<br>
---@param ctx ImGui_Context
---@param button integer
---@param repeatIn? boolean
---@return boolean retval
function reaper.ImGui_IsMouseClicked(ctx, button, repeatIn) end

---Did mouse button double-clicked? Same as GetMouseClickedCount() == 2.<br>
---(Note that a double-click will also report IsMouseClicked() == true)<br>
---@param ctx ImGui_Context
---@param button integer
---@return boolean retval
function reaper.ImGui_IsMouseDoubleClicked(ctx, button) end

---Is mouse button held?<br>
---@param ctx ImGui_Context
---@param button integer
---@return boolean retval
function reaper.ImGui_IsMouseDown(ctx, button) end

---Is mouse dragging? (if lock_threshold > -1.0, uses ConfigVar_MouseDragThreshold)<br>
---@param ctx ImGui_Context
---@param button integer
---@param lock_thresholdIn? number
---@return boolean retval
function reaper.ImGui_IsMouseDragging(ctx, button, lock_thresholdIn) end

---Is mouse hovering given bounding rect (in screen space).<br>
---Clipped by current clipping settings, but disregarding of other consideration<br>
---of focus/window ordering/popup-block.<br>
---@param ctx ImGui_Context
---@param r_min_x number
---@param r_min_y number
---@param r_max_x number
---@param r_max_y number
---@param clipIn? boolean
---@return boolean retval
function reaper.ImGui_IsMouseHoveringRect(ctx, r_min_x, r_min_y, r_max_x, r_max_y, clipIn) end

---@param ctx ImGui_Context
---@param mouse_pos_xIn? number
---@param mouse_pos_yIn? number
---@return boolean retval
function reaper.ImGui_IsMousePosValid(ctx, mouse_pos_xIn, mouse_pos_yIn) end

---Did mouse button released? (went from Down to !Down)<br>
---@param ctx ImGui_Context
---@param button integer
---@return boolean retval
function reaper.ImGui_IsMouseReleased(ctx, button) end

---Return true if the popup is open at the current BeginPopup level of the<br>
---popup stack.
---
---- With PopupFlags_AnyPopupId: return true if any popup is open at the current<br>
---BeginPopup() level of the popup stack.<br>
---- With PopupFlags_AnyPopupId + PopupFlags_AnyPopupLevel: return true if any<br>
---popup is open.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_IsPopupOpen(ctx, str_id, flagsIn) end

---Test if rectangle (of given size, starting from cursor position) is<br>
---visible / not clipped.<br>
---@param ctx ImGui_Context
---@param size_w number
---@param size_h number
---@return boolean retval
function reaper.ImGui_IsRectVisible(ctx, size_w, size_h) end

---Test if rectangle (in screen space) is visible / not clipped. to perform<br>
---coarse clipping on user's side.<br>
---@param ctx ImGui_Context
---@param rect_min_x number
---@param rect_min_y number
---@param rect_max_x number
---@param rect_max_y number
---@return boolean retval
function reaper.ImGui_IsRectVisibleEx(ctx, rect_min_x, rect_min_y, rect_max_x, rect_max_y) end

---Use after Begin/BeginPopup/BeginPopupModal to tell if a window just opened.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsWindowAppearing(ctx) end

---Is current window docked into another window or a REAPER docker?<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_IsWindowDocked(ctx) end

---Is current window focused? or its root/child, depending on flags.<br>
---See flags for options.<br>
---@param ctx ImGui_Context
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_IsWindowFocused(ctx, flagsIn) end

---Is current window hovered (and typically: not blocked by a popup/modal)?<br>
---See flags for options.<br>
---@param ctx ImGui_Context
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_IsWindowHovered(ctx, flagsIn) end

---@return integer retval
function reaper.ImGui_Key_0() end

---@return integer retval
function reaper.ImGui_Key_1() end

---@return integer retval
function reaper.ImGui_Key_2() end

---@return integer retval
function reaper.ImGui_Key_3() end

---@return integer retval
function reaper.ImGui_Key_4() end

---@return integer retval
function reaper.ImGui_Key_5() end

---@return integer retval
function reaper.ImGui_Key_6() end

---@return integer retval
function reaper.ImGui_Key_7() end

---@return integer retval
function reaper.ImGui_Key_8() end

---@return integer retval
function reaper.ImGui_Key_9() end

---@return integer retval
function reaper.ImGui_Key_A() end

---'<br>
---@return integer retval
function reaper.ImGui_Key_Apostrophe() end

---@return integer retval
function reaper.ImGui_Key_B() end

---\<br>
---@return integer retval
function reaper.ImGui_Key_Backslash() end

---@return integer retval
function reaper.ImGui_Key_Backspace() end

---@return integer retval
function reaper.ImGui_Key_C() end

---@return integer retval
function reaper.ImGui_Key_CapsLock() end

---,<br>
---@return integer retval
function reaper.ImGui_Key_Comma() end

---@return integer retval
function reaper.ImGui_Key_D() end

---@return integer retval
function reaper.ImGui_Key_Delete() end

---@return integer retval
function reaper.ImGui_Key_DownArrow() end

---@return integer retval
function reaper.ImGui_Key_E() end

---@return integer retval
function reaper.ImGui_Key_End() end

---@return integer retval
function reaper.ImGui_Key_Enter() end

---=<br>
---@return integer retval
function reaper.ImGui_Key_Equal() end

---@return integer retval
function reaper.ImGui_Key_Escape() end

---@return integer retval
function reaper.ImGui_Key_F() end

---@return integer retval
function reaper.ImGui_Key_F1() end

---@return integer retval
function reaper.ImGui_Key_F10() end

---@return integer retval
function reaper.ImGui_Key_F11() end

---@return integer retval
function reaper.ImGui_Key_F12() end

---@return integer retval
function reaper.ImGui_Key_F2() end

---@return integer retval
function reaper.ImGui_Key_F3() end

---@return integer retval
function reaper.ImGui_Key_F4() end

---@return integer retval
function reaper.ImGui_Key_F5() end

---@return integer retval
function reaper.ImGui_Key_F6() end

---@return integer retval
function reaper.ImGui_Key_F7() end

---@return integer retval
function reaper.ImGui_Key_F8() end

---@return integer retval
function reaper.ImGui_Key_F9() end

---@return integer retval
function reaper.ImGui_Key_G() end

---`<br>
---@return integer retval
function reaper.ImGui_Key_GraveAccent() end

---@return integer retval
function reaper.ImGui_Key_H() end

---@return integer retval
function reaper.ImGui_Key_Home() end

---@return integer retval
function reaper.ImGui_Key_I() end

---@return integer retval
function reaper.ImGui_Key_Insert() end

---@return integer retval
function reaper.ImGui_Key_J() end

---@return integer retval
function reaper.ImGui_Key_K() end

---@return integer retval
function reaper.ImGui_Key_Keypad0() end

---@return integer retval
function reaper.ImGui_Key_Keypad1() end

---@return integer retval
function reaper.ImGui_Key_Keypad2() end

---@return integer retval
function reaper.ImGui_Key_Keypad3() end

---@return integer retval
function reaper.ImGui_Key_Keypad4() end

---@return integer retval
function reaper.ImGui_Key_Keypad5() end

---@return integer retval
function reaper.ImGui_Key_Keypad6() end

---@return integer retval
function reaper.ImGui_Key_Keypad7() end

---@return integer retval
function reaper.ImGui_Key_Keypad8() end

---@return integer retval
function reaper.ImGui_Key_Keypad9() end

---@return integer retval
function reaper.ImGui_Key_KeypadAdd() end

---@return integer retval
function reaper.ImGui_Key_KeypadDecimal() end

---@return integer retval
function reaper.ImGui_Key_KeypadDivide() end

---@return integer retval
function reaper.ImGui_Key_KeypadEnter() end

---@return integer retval
function reaper.ImGui_Key_KeypadEqual() end

---@return integer retval
function reaper.ImGui_Key_KeypadMultiply() end

---@return integer retval
function reaper.ImGui_Key_KeypadSubtract() end

---@return integer retval
function reaper.ImGui_Key_L() end

---@return integer retval
function reaper.ImGui_Key_LeftAlt() end

---@return integer retval
function reaper.ImGui_Key_LeftArrow() end

---[<br>
---@return integer retval
function reaper.ImGui_Key_LeftBracket() end

---@return integer retval
function reaper.ImGui_Key_LeftCtrl() end

---@return integer retval
function reaper.ImGui_Key_LeftShift() end

---@return integer retval
function reaper.ImGui_Key_LeftSuper() end

---@return integer retval
function reaper.ImGui_Key_M() end

---@return integer retval
function reaper.ImGui_Key_Menu() end

----<br>
---@return integer retval
function reaper.ImGui_Key_Minus() end

---@return integer retval
function reaper.ImGui_Key_MouseLeft() end

---@return integer retval
function reaper.ImGui_Key_MouseMiddle() end

---@return integer retval
function reaper.ImGui_Key_MouseRight() end

---@return integer retval
function reaper.ImGui_Key_MouseWheelX() end

---@return integer retval
function reaper.ImGui_Key_MouseWheelY() end

---@return integer retval
function reaper.ImGui_Key_MouseX1() end

---@return integer retval
function reaper.ImGui_Key_MouseX2() end

---@return integer retval
function reaper.ImGui_Key_N() end

---@return integer retval
function reaper.ImGui_Key_NumLock() end

---@return integer retval
function reaper.ImGui_Key_O() end

---@return integer retval
function reaper.ImGui_Key_P() end

---@return integer retval
function reaper.ImGui_Key_PageDown() end

---@return integer retval
function reaper.ImGui_Key_PageUp() end

---@return integer retval
function reaper.ImGui_Key_Pause() end

---.<br>
---@return integer retval
function reaper.ImGui_Key_Period() end

---@return integer retval
function reaper.ImGui_Key_PrintScreen() end

---@return integer retval
function reaper.ImGui_Key_Q() end

---@return integer retval
function reaper.ImGui_Key_R() end

---@return integer retval
function reaper.ImGui_Key_RightAlt() end

---@return integer retval
function reaper.ImGui_Key_RightArrow() end

---]<br>
---@return integer retval
function reaper.ImGui_Key_RightBracket() end

---@return integer retval
function reaper.ImGui_Key_RightCtrl() end

---@return integer retval
function reaper.ImGui_Key_RightShift() end

---@return integer retval
function reaper.ImGui_Key_RightSuper() end

---@return integer retval
function reaper.ImGui_Key_S() end

---@return integer retval
function reaper.ImGui_Key_ScrollLock() end

---;<br>
---@return integer retval
function reaper.ImGui_Key_Semicolon() end

---/<br>
---@return integer retval
function reaper.ImGui_Key_Slash() end

---@return integer retval
function reaper.ImGui_Key_Space() end

---@return integer retval
function reaper.ImGui_Key_T() end

---@return integer retval
function reaper.ImGui_Key_Tab() end

---@return integer retval
function reaper.ImGui_Key_U() end

---@return integer retval
function reaper.ImGui_Key_UpArrow() end

---@return integer retval
function reaper.ImGui_Key_V() end

---@return integer retval
function reaper.ImGui_Key_W() end

---@return integer retval
function reaper.ImGui_Key_X() end

---@return integer retval
function reaper.ImGui_Key_Y() end

---@return integer retval
function reaper.ImGui_Key_Z() end

---Display text+label aligned the same way as value+label widgets<br>
---@param ctx ImGui_Context
---@param label string
---@param text string
function reaper.ImGui_LabelText(ctx, label, text) end

---This is an helper over BeginListBox/EndListBox for convenience purpose.
---
---Each item must be null-terminated (requires REAPER v6.44 or newer for EEL and Lua).<br>
---@param ctx ImGui_Context
---@param label string
---@param current_item integer
---@param items string
---@param height_in_itemsIn? integer
---@return boolean retval
---@return integer current_item
function reaper.ImGui_ListBox(ctx, label, current_item, items, height_in_itemsIn) end

---- items_count: Use INT_MAX if you don't know how many items you have<br>
---(in which case the cursor won't be advanced in the final step)<br>
---- items_height: Use -1.0 to be calculated automatically on first step.<br>
---Otherwise pass in the distance between your items, typically<br>
---GetTextLineHeightWithSpacing or GetFrameHeightWithSpacing.<br>
---@param clipper ImGui_ListClipper
---@param items_count integer
---@param items_heightIn? number
function reaper.ImGui_ListClipper_Begin(clipper, items_count, items_heightIn) end

---Automatically called on the last call of ListClipper_Step that returns false.<br>
---@param clipper ImGui_ListClipper
function reaper.ImGui_ListClipper_End(clipper) end

---@param clipper ImGui_ListClipper
---@return integer display_start
---@return integer display_end
function reaper.ImGui_ListClipper_GetDisplayRange(clipper) end

---Call ListClipper_IncludeRangeByIndices before first call to<br>
---ListClipper_Step if you need a range of items to be displayed regardless of<br>
---visibility.
---
---(Due to alignment / padding of certain items it is possible that an extra item may be included on either end of the display range).
---
---item_end is exclusive e.g. use (42, 42+1) to make item 42 never clipped.<br>
---@param clipper ImGui_ListClipper
---@param item_begin integer
---@param item_end integer
function reaper.ImGui_ListClipper_IncludeRangeByIndices(clipper, item_begin, item_end) end

---Call until it returns false. The display_start/display_end fields from<br>
---ListClipper_GetDisplayRange will be set and you can process/draw those items.<br>
---@param clipper ImGui_ListClipper
---@return boolean retval
function reaper.ImGui_ListClipper_Step(clipper) end

---Stop logging (close file, etc.)<br>
---@param ctx ImGui_Context
function reaper.ImGui_LogFinish(ctx) end

---Pass text data straight to log (without being displayed)<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_LogText(ctx, text) end

---Start logging all text output from the interface to the OS clipboard.<br>
---See also SetClipboardText.<br>
---@param ctx ImGui_Context
---@param auto_open_depthIn? integer
function reaper.ImGui_LogToClipboard(ctx, auto_open_depthIn) end

---Start logging all text output from the interface to a file.<br>
---The data is saved to $resource_path/imgui_log.txt if filename is nil.<br>
---@param ctx ImGui_Context
---@param auto_open_depthIn? integer
---@param filenameIn? string
function reaper.ImGui_LogToFile(ctx, auto_open_depthIn, filenameIn) end

---Start logging all text output from the interface to the TTY (stdout).<br>
---@param ctx ImGui_Context
---@param auto_open_depthIn? integer
function reaper.ImGui_LogToTTY(ctx, auto_open_depthIn) end

---Return true when activated. Shortcuts are displayed for convenience but not<br>
---processed by ImGui at the moment. Toggle state is written to 'selected' when<br>
---provided.<br>
---@param ctx ImGui_Context
---@param label string
---@param shortcutIn? string
---@param p_selected? boolean
---@param enabledIn? boolean
---@return boolean retval
---@return boolean? p_selected
function reaper.ImGui_MenuItem(ctx, label, shortcutIn, p_selected, enabledIn) end

---@return integer retval
function reaper.ImGui_Mod_Alt() end

---@return integer retval
function reaper.ImGui_Mod_Ctrl() end

---@return integer retval
function reaper.ImGui_Mod_None() end

---@return integer retval
function reaper.ImGui_Mod_Shift() end

---Alias for Mod_Ctrl on Linux and Windows and Mod_Super on macOS (Cmd key).<br>
---@return integer retval
function reaper.ImGui_Mod_Shortcut() end

---@return integer retval
function reaper.ImGui_Mod_Super() end

---@return integer retval
function reaper.ImGui_MouseButton_Left() end

---@return integer retval
function reaper.ImGui_MouseButton_Middle() end

---@return integer retval
function reaper.ImGui_MouseButton_Right() end

---@return integer retval
function reaper.ImGui_MouseCursor_Arrow() end

---(Unused by Dear ImGui functions. Use for e.g. hyperlinks)<br>
---@return integer retval
function reaper.ImGui_MouseCursor_Hand() end

---@return integer retval
function reaper.ImGui_MouseCursor_None() end

---When hovering something with disallowed interaction. Usually a crossed circle.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_NotAllowed() end

---(Unused by Dear ImGui functions)<br>
---@return integer retval
function reaper.ImGui_MouseCursor_ResizeAll() end

---When hovering over a vertical border or a column.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_ResizeEW() end

---When hovering over the bottom-left corner of a window.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_ResizeNESW() end

---When hovering over a horizontal border.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_ResizeNS() end

---When hovering over the bottom-right corner of a window.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_ResizeNWSE() end

---When hovering over InputText, etc.<br>
---@return integer retval
function reaper.ImGui_MouseCursor_TextInput() end

---Undo a SameLine() or force a new line when in a horizontal-layout context.<br>
---@param ctx ImGui_Context
function reaper.ImGui_NewLine(ctx) end

---Returns DBL_MIN and DBL_MAX for this system.<br>
---@return number min
---@return number max
function reaper.ImGui_NumericLimits_Double() end

---Returns FLT_MIN and FLT_MAX for this system.<br>
---@return number min
---@return number max
function reaper.ImGui_NumericLimits_Float() end

---Returns INT_MIN and INT_MAX for this system.<br>
---@return integer min
---@return integer max
function reaper.ImGui_NumericLimits_Int() end

---Set popup state to open (don't call every frame!).<br>
---ImGuiPopupFlags are available for opening options.
---
---If not modal: they can be closed by clicking anywhere outside them, or by<br>
---pressing ESCAPE.
---
---Use PopupFlags_NoOpenOverExistingPopup to avoid opening a popup if there's<br>
---already one at the same level.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param popup_flagsIn? integer
function reaper.ImGui_OpenPopup(ctx, str_id, popup_flagsIn) end

---Helper to open popup when clicked on last item. return true when just opened.<br>
---(Note: actually triggers on the mouse _released_ event to be consistent with<br>
---popup behaviors.)<br>
---@param ctx ImGui_Context
---@param str_idIn? string
---@param popup_flagsIn? integer
function reaper.ImGui_OpenPopupOnItemClick(ctx, str_idIn, popup_flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param values reaper.array
---@param values_offsetIn? integer
---@param overlay_textIn? string
---@param scale_minIn? number
---@param scale_maxIn? number
---@param graph_size_wIn? number
---@param graph_size_hIn? number
function reaper.ImGui_PlotHistogram(ctx, label, values, values_offsetIn, overlay_textIn, scale_minIn, scale_maxIn, graph_size_wIn, graph_size_hIn) end

---@param ctx ImGui_Context
---@param label string
---@param values reaper.array
---@param values_offsetIn? integer
---@param overlay_textIn? string
---@param scale_minIn? number
---@param scale_maxIn? number
---@param graph_size_wIn? number
---@param graph_size_hIn? number
function reaper.ImGui_PlotLines(ctx, label, values, values_offsetIn, overlay_textIn, scale_minIn, scale_maxIn, graph_size_wIn, graph_size_hIn) end

---Convert a position from the current platform's native coordinate position<br>
---system to ReaImGui global coordinates (or vice versa).
---
---This effectively flips the Y coordinate on macOS and applies HiDPI scaling on<br>
---Windows and Linux.<br>
---@param ctx ImGui_Context
---@param x number
---@param y number
---@param to_nativeIn? boolean
---@return number x
---@return number y
function reaper.ImGui_PointConvertNative(ctx, x, y, to_nativeIn) end

---See PushButtonRepeat<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopButtonRepeat(ctx) end

---See PushClipRect<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopClipRect(ctx) end

---See PushFont.<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopFont(ctx) end

---Pop from the ID stack.<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopID(ctx) end

---See PushItemWidth<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopItemWidth(ctx) end

---@param ctx ImGui_Context
---@param countIn? integer
function reaper.ImGui_PopStyleColor(ctx, countIn) end

---Reset a style variable.<br>
---@param ctx ImGui_Context
---@param countIn? integer
function reaper.ImGui_PopStyleVar(ctx, countIn) end

---See PushTabStop<br>
---@param ctx ImGui_Context
function reaper.ImGui_PopTabStop(ctx) end

---@param ctx ImGui_Context
function reaper.ImGui_PopTextWrapPos(ctx) end

---PopupFlags_AnyPopupId | PopupFlags_AnyPopupLevel<br>
---@return integer retval
function reaper.ImGui_PopupFlags_AnyPopup() end

---For IsPopupOpen: ignore the str_id parameter and test for any popup.<br>
---@return integer retval
function reaper.ImGui_PopupFlags_AnyPopupId() end

---For IsPopupOpen: search/test at any level of the popup stack<br>
---(default test in the current level).<br>
---@return integer retval
function reaper.ImGui_PopupFlags_AnyPopupLevel() end

---For BeginPopupContext*(): open on Left Mouse release.<br>
---Guaranteed to always be == 0 (same as MouseButton_Left).<br>
---@return integer retval
function reaper.ImGui_PopupFlags_MouseButtonLeft() end

---For BeginPopupContext*(): open on Middle Mouse release.<br>
---Guaranteed to always be == 2 (same as MouseButton_Middle).<br>
---@return integer retval
function reaper.ImGui_PopupFlags_MouseButtonMiddle() end

---For BeginPopupContext*(): open on Right Mouse release.<br>
---Guaranteed to always be == 1 (same as MouseButton_Right).<br>
---@return integer retval
function reaper.ImGui_PopupFlags_MouseButtonRight() end

---For OpenPopup*(), BeginPopupContext*(): don't open if there's already a popup<br>
---at the same level of the popup stack.<br>
---@return integer retval
function reaper.ImGui_PopupFlags_NoOpenOverExistingPopup() end

---For BeginPopupContextWindow: don't return true when hovering items,<br>
---only when hovering empty space.<br>
---@return integer retval
function reaper.ImGui_PopupFlags_NoOpenOverItems() end

---@return integer retval
function reaper.ImGui_PopupFlags_None() end

---@param ctx ImGui_Context
---@param fraction number
---@param size_arg_wIn? number
---@param size_arg_hIn? number
---@param overlayIn? string
function reaper.ImGui_ProgressBar(ctx, fraction, size_arg_wIn, size_arg_hIn, overlayIn) end

---In 'repeat' mode, Button*() functions return repeated true in a typematic<br>
---manner (using ConfigVar_KeyRepeatDelay/ConfigVar_KeyRepeatRate settings).
---
---Note that you can call IsItemActive after any Button to tell if the button is<br>
---held in the current frame.<br>
---@param ctx ImGui_Context
---@param repeat boolean
function reaper.ImGui_PushButtonRepeat(ctx, repeat) end

---@param ctx ImGui_Context
---@param clip_rect_min_x number
---@param clip_rect_min_y number
---@param clip_rect_max_x number
---@param clip_rect_max_y number
---@param intersect_with_current_clip_rect boolean
function reaper.ImGui_PushClipRect(ctx, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rect) end

---Change the current font. Use nil to push the default font.<br>
---The font object must have been registered using Attach. See PopFont.<br>
---@param ctx ImGui_Context
---@param font ImGui_Font|nil
function reaper.ImGui_PushFont(ctx, font) end

---Push string into the ID stack.<br>
---@param ctx ImGui_Context
---@param str_id string
function reaper.ImGui_PushID(ctx, str_id) end

---Push width of items for common large "item+label" widgets.
---
---- \>0.0: width in pixels<br>
---- >0.0 align xx pixels to the right of window<br>
---(so -FLT_MIN always align width to the right side)<br>
---- 0.0 = default to ~2/3 of windows width.<br>
---@param ctx ImGui_Context
---@param item_width number
function reaper.ImGui_PushItemWidth(ctx, item_width) end

---Temporarily modify a style color.<br>
---Call PopStyleColor to undo after use (before the end of the frame).<br>
---See Col_* for available style colors.<br>
---@param ctx ImGui_Context
---@param idx integer
---@param col_rgba integer
function reaper.ImGui_PushStyleColor(ctx, idx, col_rgba) end

---Temporarily modify a style variable.<br>
---Call PopStyleVar to undo after use (before the end of the frame).<br>
---See StyleVar_* for possible values of 'var_idx'.<br>
---@param ctx ImGui_Context
---@param var_idx integer
---@param val1 number
---@param val2In? number
function reaper.ImGui_PushStyleVar(ctx, var_idx, val1, val2In) end

---Allow focusing using TAB/Shift-TAB, enabled by default but you can disable it<br>
---for certain widgets<br>
---@param ctx ImGui_Context
---@param tab_stop boolean
function reaper.ImGui_PushTabStop(ctx, tab_stop) end

---Push word-wrapping position for Text*() commands.
---
----  > 0.0: no wrapping<br>
----  = 0.0: wrap to end of window (or column)<br>
---- \> 0.0: wrap at 'wrap_pos_x' position in window local space.<br>
---@param ctx ImGui_Context
---@param wrap_local_pos_xIn? number
function reaper.ImGui_PushTextWrapPos(ctx, wrap_local_pos_xIn) end

---Use with e.g. if (RadioButton("one", my_value==1)) { my_value = 1; }<br>
---@param ctx ImGui_Context
---@param label string
---@param active boolean
---@return boolean retval
function reaper.ImGui_RadioButton(ctx, label, active) end

---Shortcut to handle RadioButton's example pattern when value is an integer<br>
---@param ctx ImGui_Context
---@param label string
---@param v integer
---@param v_button integer
---@return boolean retval
---@return integer v
function reaper.ImGui_RadioButtonEx(ctx, label, v, v_button) end

---@param ctx ImGui_Context
---@param buttonIn? integer
function reaper.ImGui_ResetMouseDragDelta(ctx, buttonIn) end

---Call between widgets or groups to layout them horizontally.<br>
---X position given in window coordinates.<br>
---@param ctx ImGui_Context
---@param offset_from_start_xIn? number
---@param spacingIn? number
function reaper.ImGui_SameLine(ctx, offset_from_start_xIn, spacingIn) end

---@param ctx ImGui_Context
---@param label string
---@param p_selected boolean
---@param flagsIn? integer
---@param size_wIn? number
---@param size_hIn? number
---@return boolean retval
---@return boolean p_selected
function reaper.ImGui_Selectable(ctx, label, p_selected, flagsIn, size_wIn, size_hIn) end

---Generate press events on double clicks too.<br>
---@return integer retval
function reaper.ImGui_SelectableFlags_AllowDoubleClick() end

---Hit testing to allow subsequent widgets to overlap this one.<br>
---@return integer retval
function reaper.ImGui_SelectableFlags_AllowItemOverlap() end

---Cannot be selected, display grayed out text.<br>
---@return integer retval
function reaper.ImGui_SelectableFlags_Disabled() end

---Clicking this doesn't close parent popup window.<br>
---@return integer retval
function reaper.ImGui_SelectableFlags_DontClosePopups() end

---@return integer retval
function reaper.ImGui_SelectableFlags_None() end

---Selectable frame can span all columns (text will still fit in current column).<br>
---@return integer retval
function reaper.ImGui_SelectableFlags_SpanAllColumns() end

---Separator, generally horizontal. inside a menu bar or in horizontal layout<br>
---mode, this becomes a vertical separator.<br>
---@param ctx ImGui_Context
function reaper.ImGui_Separator(ctx) end

---Text formatted with an horizontal line<br>
---@param ctx ImGui_Context
---@param label string
function reaper.ImGui_SeparatorText(ctx, label) end

---See also the LogToClipboard function to capture GUI into clipboard,<br>
---or easily output text data to the clipboard.<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_SetClipboardText(ctx, text) end

---Picker type, etc. User will be able to change many settings, unless you pass<br>
---the _NoOptions flag to your calls.<br>
---@param ctx ImGui_Context
---@param flags integer
function reaper.ImGui_SetColorEditOptions(ctx, flags) end

---@param ctx ImGui_Context
---@param var_idx integer
---@param value number
function reaper.ImGui_SetConfigVar(ctx, var_idx, value) end

---Cursor position in window<br>
---@param ctx ImGui_Context
---@param local_pos_x number
---@param local_pos_y number
function reaper.ImGui_SetCursorPos(ctx, local_pos_x, local_pos_y) end

---Cursor X position in window<br>
---@param ctx ImGui_Context
---@param local_x number
function reaper.ImGui_SetCursorPosX(ctx, local_x) end

---Cursor Y position in window<br>
---@param ctx ImGui_Context
---@param local_y number
function reaper.ImGui_SetCursorPosY(ctx, local_y) end

---Cursor position in absolute screen coordinates.<br>
---@param ctx ImGui_Context
---@param pos_x number
---@param pos_y number
function reaper.ImGui_SetCursorScreenPos(ctx, pos_x, pos_y) end

---The type is a user defined string of maximum 32 characters.<br>
---Strings starting with '_' are reserved for dear imgui internal types.<br>
---Data is copied and held by imgui.<br>
---@param ctx ImGui_Context
---@param type string
---@param data string
---@param condIn? integer
---@return boolean retval
function reaper.ImGui_SetDragDropPayload(ctx, type, data, condIn) end

---Allow last item to be overlapped by a subsequent item. sometimes useful with<br>
---invisible buttons, selectables, etc. to catch unused area.<br>
---@param ctx ImGui_Context
function reaper.ImGui_SetItemAllowOverlap(ctx) end

---Make last item the default focused item of a window.<br>
---@param ctx ImGui_Context
function reaper.ImGui_SetItemDefaultFocus(ctx) end

---Focus keyboard on the next widget. Use positive 'offset' to access sub<br>
---components of a multiple component widget. Use -1 to access previous widget.<br>
---@param ctx ImGui_Context
---@param offsetIn? integer
function reaper.ImGui_SetKeyboardFocusHere(ctx, offsetIn) end

---Set desired mouse cursor shape. See MouseCursor_* for possible values.<br>
---@param ctx ImGui_Context
---@param cursor_type integer
function reaper.ImGui_SetMouseCursor(ctx, cursor_type) end

---Request capture of keyboard shortcuts in REAPER's global scope for the next frame.<br>
---@param ctx ImGui_Context
---@param want_capture_keyboard boolean
function reaper.ImGui_SetNextFrameWantCaptureKeyboard(ctx, want_capture_keyboard) end

---Set next TreeNode/CollapsingHeader open state.<br>
---Can also be done with the TreeNodeFlags_DefaultOpen flag.<br>
---@param ctx ImGui_Context
---@param is_open boolean
---@param condIn? integer
function reaper.ImGui_SetNextItemOpen(ctx, is_open, condIn) end

---Set width of the _next_ common large "item+label" widget.
---
---- \>0.0: width in pixels<br>
---- >0.0 align xx pixels to the right of window<br>
---(so -FLT_MIN always align width to the right side)<br>
---@param ctx ImGui_Context
---@param item_width number
function reaper.ImGui_SetNextItemWidth(ctx, item_width) end

---Set next window background color alpha. Helper to easily override the Alpha<br>
---component of Col_WindowBg/Col_ChildBg/Col_PopupBg.<br>
---You may also use WindowFlags_NoBackground for a fully transparent window.<br>
---@param ctx ImGui_Context
---@param alpha number
function reaper.ImGui_SetNextWindowBgAlpha(ctx, alpha) end

---Set next window collapsed state.<br>
---@param ctx ImGui_Context
---@param collapsed boolean
---@param condIn? integer
function reaper.ImGui_SetNextWindowCollapsed(ctx, collapsed, condIn) end

---Set next window content size (~ scrollable client area, which enforce the<br>
---range of scrollbars). Not including window decorations (title bar, menu bar,<br>
---etc.) nor StyleVar_WindowPadding. set an axis to 0.0 to leave it automatic.<br>
---@param ctx ImGui_Context
---@param size_w number
---@param size_h number
function reaper.ImGui_SetNextWindowContentSize(ctx, size_w, size_h) end

---@param ctx ImGui_Context
---@param dock_id integer
---@param condIn? integer
function reaper.ImGui_SetNextWindowDockID(ctx, dock_id, condIn) end

---Set next window to be focused / top-most.<br>
---@param ctx ImGui_Context
function reaper.ImGui_SetNextWindowFocus(ctx) end

---Set next window position. Use pivot=(0.5,0.5) to center on given point, etc.<br>
---@param ctx ImGui_Context
---@param pos_x number
---@param pos_y number
---@param condIn? integer
---@param pivot_xIn? number
---@param pivot_yIn? number
function reaper.ImGui_SetNextWindowPos(ctx, pos_x, pos_y, condIn, pivot_xIn, pivot_yIn) end

---Set next window scrolling value (use > 0.0 to not affect a given axis).<br>
---@param ctx ImGui_Context
---@param scroll_x number
---@param scroll_y number
function reaper.ImGui_SetNextWindowScroll(ctx, scroll_x, scroll_y) end

---Set next window size. set axis to 0.0 to force an auto-fit on this axis.<br>
---@param ctx ImGui_Context
---@param size_w number
---@param size_h number
---@param condIn? integer
function reaper.ImGui_SetNextWindowSize(ctx, size_w, size_h, condIn) end

---Set next window size limits. Use -1,-1 on either X/Y axis to preserve the<br>
---current size. Use FLT_MAX (second return value of NumericLimits_Float) for no<br>
---maximum size. Sizes will be rounded down.<br>
---@param ctx ImGui_Context
---@param size_min_w number
---@param size_min_h number
---@param size_max_w number
---@param size_max_h number
---@param custom_callbackIn? ImGui_Function
function reaper.ImGui_SetNextWindowSizeConstraints(ctx, size_min_w, size_min_h, size_max_w, size_max_h, custom_callbackIn) end

---Adjust scrolling amount to make given position visible.<br>
---Generally GetCursorStartPos() + offset to compute a valid position.<br>
---@param ctx ImGui_Context
---@param local_x number
---@param center_x_ratioIn? number
function reaper.ImGui_SetScrollFromPosX(ctx, local_x, center_x_ratioIn) end

---Adjust scrolling amount to make given position visible.<br>
---Generally GetCursorStartPos() + offset to compute a valid position.<br>
---@param ctx ImGui_Context
---@param local_y number
---@param center_y_ratioIn? number
function reaper.ImGui_SetScrollFromPosY(ctx, local_y, center_y_ratioIn) end

---Adjust scrolling amount to make current cursor position visible.<br>
---center_x_ratio=0.0: left, 0.5: center, 1.0: right.<br>
---When using to make a "default/current item" visible,<br>
---consider using SetItemDefaultFocus instead.<br>
---@param ctx ImGui_Context
---@param center_x_ratioIn? number
function reaper.ImGui_SetScrollHereX(ctx, center_x_ratioIn) end

---Adjust scrolling amount to make current cursor position visible.<br>
---center_y_ratio=0.0: top, 0.5: center, 1.0: bottom.<br>
---When using to make a "default/current item" visible,<br>
---consider using SetItemDefaultFocus instead.<br>
---@param ctx ImGui_Context
---@param center_y_ratioIn? number
function reaper.ImGui_SetScrollHereY(ctx, center_y_ratioIn) end

---Set scrolling amount [0 .. GetScrollMaxX()]<br>
---@param ctx ImGui_Context
---@param scroll_x number
function reaper.ImGui_SetScrollX(ctx, scroll_x) end

---Set scrolling amount [0 .. GetScrollMaxY()]<br>
---@param ctx ImGui_Context
---@param scroll_y number
function reaper.ImGui_SetScrollY(ctx, scroll_y) end

---Notify TabBar or Docking system of a closed tab/window ahead<br>
---(useful to reduce visual flicker on reorderable tab bars).<br>
---For tab-bar: call after BeginTabBar and before Tab submissions.<br>
---Otherwise call with a window name.<br>
---@param ctx ImGui_Context
---@param tab_or_docked_window_label string
function reaper.ImGui_SetTabItemClosed(ctx, tab_or_docked_window_label) end

---Set a text-only tooltip, typically use with IsItemHovered. override any<br>
---previous call to SetTooltip.<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_SetTooltip(ctx, text) end

---(Not recommended) Set current window collapsed state.<br>
---Prefer using SetNextWindowCollapsed.<br>
---@param ctx ImGui_Context
---@param collapsed boolean
---@param condIn? integer
function reaper.ImGui_SetWindowCollapsed(ctx, collapsed, condIn) end

---Set named window collapsed state.<br>
---@param ctx ImGui_Context
---@param name string
---@param collapsed boolean
---@param condIn? integer
function reaper.ImGui_SetWindowCollapsedEx(ctx, name, collapsed, condIn) end

---(Not recommended) Set current window to be focused / top-most.<br>
---Prefer using SetNextWindowFocus.<br>
---@param ctx ImGui_Context
function reaper.ImGui_SetWindowFocus(ctx) end

---Set named window to be focused / top-most. Use an empty name to remove focus.<br>
---@param ctx ImGui_Context
---@param name string
function reaper.ImGui_SetWindowFocusEx(ctx, name) end

---(Not recommended) Set current window position - call within Begin/End.<br>
---Prefer using SetNextWindowPos, as this may incur tearing and minor side-effects.<br>
---@param ctx ImGui_Context
---@param pos_x number
---@param pos_y number
---@param condIn? integer
function reaper.ImGui_SetWindowPos(ctx, pos_x, pos_y, condIn) end

---Set named window position.<br>
---@param ctx ImGui_Context
---@param name string
---@param pos_x number
---@param pos_y number
---@param condIn? integer
function reaper.ImGui_SetWindowPosEx(ctx, name, pos_x, pos_y, condIn) end

---(Not recommended) Set current window size - call within Begin/End.<br>
---Set size_w and size_h to 0 to force an auto-fit.<br>
---Prefer using SetNextWindowSize, as this may incur tearing and minor side-effects.<br>
---@param ctx ImGui_Context
---@param size_w number
---@param size_h number
---@param condIn? integer
function reaper.ImGui_SetWindowSize(ctx, size_w, size_h, condIn) end

---Set named window size. Set axis to 0.0 to force an auto-fit on this axis.<br>
---@param ctx ImGui_Context
---@param name string
---@param size_w number
---@param size_h number
---@param condIn? integer
function reaper.ImGui_SetWindowSizeEx(ctx, name, size_w, size_h, condIn) end

---Create About window.<br>
---Display ReaImGui version, Dear ImGui version, credits and build/system information.<br>
---@param ctx ImGui_Context
---@param p_open? boolean
---@return boolean? retval
function reaper.ImGui_ShowAboutWindow(ctx, p_open) end

---Create Debug Log window. display a simplified log of important dear imgui events.<br>
---@param ctx ImGui_Context
---@param p_open? boolean
---@return boolean? retval
function reaper.ImGui_ShowDebugLogWindow(ctx, p_open) end

---Create Metrics/Debugger window.<br>
---Display Dear ImGui internals: windows, draw commands, various internal state, etc.<br>
---@param ctx ImGui_Context
---@param p_open? boolean
---@return boolean? retval
function reaper.ImGui_ShowMetricsWindow(ctx, p_open) end

---Create Stack Tool window. Hover items with mouse to query information about<br>
---the source of their unique ID.<br>
---@param ctx ImGui_Context
---@param p_open? boolean
---@return boolean? retval
function reaper.ImGui_ShowStackToolWindow(ctx, p_open) end

---@param ctx ImGui_Context
---@param label string
---@param v_rad number
---@param v_degrees_minIn? number
---@param v_degrees_maxIn? number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v_rad
function reaper.ImGui_SliderAngle(ctx, label, v_rad, v_degrees_minIn, v_degrees_maxIn, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v number
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v
function reaper.ImGui_SliderDouble(ctx, label, v, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
function reaper.ImGui_SliderDouble2(ctx, label, v1, v2, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
function reaper.ImGui_SliderDouble3(ctx, label, v1, v2, v3, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 number
---@param v2 number
---@param v3 number
---@param v4 number
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v1
---@return number v2
---@return number v3
---@return number v4
function reaper.ImGui_SliderDouble4(ctx, label, v1, v2, v3, v4, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param values reaper.array
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_SliderDoubleN(ctx, label, values, v_min, v_max, formatIn, flagsIn) end

---Clamp value to min/max bounds when input manually with CTRL+Click.<br>
---By default CTRL+Click allows going out of bounds.<br>
---@return integer retval
function reaper.ImGui_SliderFlags_AlwaysClamp() end

---Make the widget logarithmic (linear otherwise).<br>
---Consider using SliderFlags_NoRoundToFormat with this if using a format-string<br>
---with small amount of digits.<br>
---@return integer retval
function reaper.ImGui_SliderFlags_Logarithmic() end

---Disable CTRL+Click or Enter key allowing to input text directly into the widget.<br>
---@return integer retval
function reaper.ImGui_SliderFlags_NoInput() end

---Disable rounding underlying value to match precision of the display format<br>
---string (e.g. %.3f values are rounded to those 3 digits).<br>
---@return integer retval
function reaper.ImGui_SliderFlags_NoRoundToFormat() end

---@return integer retval
function reaper.ImGui_SliderFlags_None() end

---@param ctx ImGui_Context
---@param label string
---@param v integer
---@param v_min integer
---@param v_max integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v
function reaper.ImGui_SliderInt(ctx, label, v, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v_min integer
---@param v_max integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
function reaper.ImGui_SliderInt2(ctx, label, v1, v2, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param v_min integer
---@param v_max integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
function reaper.ImGui_SliderInt3(ctx, label, v1, v2, v3, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param v1 integer
---@param v2 integer
---@param v3 integer
---@param v4 integer
---@param v_min integer
---@param v_max integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v1
---@return integer v2
---@return integer v3
---@return integer v4
function reaper.ImGui_SliderInt4(ctx, label, v1, v2, v3, v4, v_min, v_max, formatIn, flagsIn) end

---Button with StyleVar_FramePadding=(0,0) to easily embed within text.<br>
---@param ctx ImGui_Context
---@param label string
---@return boolean retval
function reaper.ImGui_SmallButton(ctx, label) end

---Ascending = 0->9, A->Z etc.<br>
---@return integer retval
function reaper.ImGui_SortDirection_Ascending() end

---Descending = 9->0, Z->A etc.<br>
---@return integer retval
function reaper.ImGui_SortDirection_Descending() end

---@return integer retval
function reaper.ImGui_SortDirection_None() end

---Add vertical spacing.<br>
---@param ctx ImGui_Context
function reaper.ImGui_Spacing(ctx) end

---Global alpha applies to everything in Dear ImGui.<br>
---@return integer retval
function reaper.ImGui_StyleVar_Alpha() end

---Alignment of button text when button is larger than text.<br>
---Defaults to (0.5, 0.5) (centered).<br>
---@return integer retval
function reaper.ImGui_StyleVar_ButtonTextAlign() end

---Padding within a table cell.<br>
---@return integer retval
function reaper.ImGui_StyleVar_CellPadding() end

---Thickness of border around child windows. Generally set to 0.0 or 1.0.<br>
---(Other values are not well tested and more CPU/GPU costly).<br>
---@return integer retval
function reaper.ImGui_StyleVar_ChildBorderSize() end

---Radius of child window corners rounding. Set to 0.0 to have rectangular windows.<br>
---@return integer retval
function reaper.ImGui_StyleVar_ChildRounding() end

---Additional alpha multiplier applied by BeginDisabled.<br>
---Multiply over current value of Alpha.<br>
---@return integer retval
function reaper.ImGui_StyleVar_DisabledAlpha() end

---Thickness of border around frames. Generally set to 0.0 or 1.0.<br>
---(Other values are not well tested and more CPU/GPU costly).<br>
---@return integer retval
function reaper.ImGui_StyleVar_FrameBorderSize() end

---Padding within a framed rectangle (used by most widgets).<br>
---@return integer retval
function reaper.ImGui_StyleVar_FramePadding() end

---Radius of frame corners rounding.<br>
---Set to 0.0 to have rectangular frame (used by most widgets).<br>
---@return integer retval
function reaper.ImGui_StyleVar_FrameRounding() end

---Minimum width/height of a grab box for slider/scrollbar.<br>
---@return integer retval
function reaper.ImGui_StyleVar_GrabMinSize() end

---Radius of grabs corners rounding. Set to 0.0 to have rectangular slider grabs.<br>
---@return integer retval
function reaper.ImGui_StyleVar_GrabRounding() end

---Horizontal indentation when e.g. entering a tree node.<br>
---Generally == (GetFontSize + StyleVar_FramePadding.x*2).<br>
---@return integer retval
function reaper.ImGui_StyleVar_IndentSpacing() end

---Horizontal and vertical spacing between within elements of a composed widget<br>
---(e.g. a slider and its label).<br>
---@return integer retval
function reaper.ImGui_StyleVar_ItemInnerSpacing() end

---Horizontal and vertical spacing between widgets/lines.<br>
---@return integer retval
function reaper.ImGui_StyleVar_ItemSpacing() end

---Thickness of border around popup/tooltip windows. Generally set to 0.0 or 1.0.<br>
---(Other values are not well tested and more CPU/GPU costly).<br>
---@return integer retval
function reaper.ImGui_StyleVar_PopupBorderSize() end

---Radius of popup window corners rounding.<br>
---(Note that tooltip windows use StyleVar_WindowRounding.)<br>
---@return integer retval
function reaper.ImGui_StyleVar_PopupRounding() end

---Radius of grab corners for scrollbar.<br>
---@return integer retval
function reaper.ImGui_StyleVar_ScrollbarRounding() end

---Width of the vertical scrollbar, Height of the horizontal scrollbar.<br>
---@return integer retval
function reaper.ImGui_StyleVar_ScrollbarSize() end

---Alignment of selectable text. Defaults to (0.0, 0.0) (top-left aligned).<br>
---It's generally important to keep this left-aligned if you want to lay<br>
---multiple items on a same line.<br>
---@return integer retval
function reaper.ImGui_StyleVar_SelectableTextAlign() end

---Alignment of text within the separator.<br>
---Defaults to (0.0, 0.5) (left aligned, center).<br>
---@return integer retval
function reaper.ImGui_StyleVar_SeparatorTextAlign() end

---Thickness of border in SeparatorText()<br>
---@return integer retval
function reaper.ImGui_StyleVar_SeparatorTextBorderSize() end

---Horizontal offset of text from each edge of the separator + spacing on other<br>
---axis. Generally small values. .y is recommended to be == StyleVar_FramePadding.y.<br>
---@return integer retval
function reaper.ImGui_StyleVar_SeparatorTextPadding() end

---Radius of upper corners of a tab. Set to 0.0 to have rectangular tabs.<br>
---@return integer retval
function reaper.ImGui_StyleVar_TabRounding() end

---Thickness of border around windows. Generally set to 0.0 or 1.0.<br>
---(Other values are not well tested and more CPU/GPU costly).<br>
---@return integer retval
function reaper.ImGui_StyleVar_WindowBorderSize() end

---Minimum window size. This is a global setting.<br>
---If you want to constrain individual windows, use SetNextWindowSizeConstraints.<br>
---@return integer retval
function reaper.ImGui_StyleVar_WindowMinSize() end

---Padding within a window.<br>
---@return integer retval
function reaper.ImGui_StyleVar_WindowPadding() end

---Radius of window corners rounding. Set to 0.0 to have rectangular windows.<br>
---Large values tend to lead to variety of artifacts and are not recommended.<br>
---@return integer retval
function reaper.ImGui_StyleVar_WindowRounding() end

---Alignment for title bar text.<br>
---Defaults to (0.0,0.5) for left-aligned,vertically centered.<br>
---@return integer retval
function reaper.ImGui_StyleVar_WindowTitleAlign() end

---Automatically select new tabs when they appear.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_AutoSelectNewTabs() end

---Resize tabs when they don't fit.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_FittingPolicyResizeDown() end

---Add scroll buttons when tabs don't fit.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_FittingPolicyScroll() end

---Disable behavior of closing tabs (that are submitted with p_open != nil)<br>
---with middle mouse button. You can still repro this behavior on user's side<br>
---with if(IsItemHovered() && IsMouseClicked(2)) p_open = false.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_NoCloseWithMiddleMouseButton() end

---Disable scrolling buttons (apply when fitting policy is<br>
---TabBarFlags_FittingPolicyScroll).<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_NoTabListScrollingButtons() end

---Disable tooltips when hovering a tab.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_NoTooltip() end

---@return integer retval
function reaper.ImGui_TabBarFlags_None() end

---Allow manually dragging tabs to re-order them + New tabs are appended at<br>
---the end of list.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_Reorderable() end

---Disable buttons to open the tab list popup.<br>
---@return integer retval
function reaper.ImGui_TabBarFlags_TabListPopupButton() end

---Create a Tab behaving like a button. Return true when clicked.<br>
---Cannot be selected in the tab bar.<br>
---@param ctx ImGui_Context
---@param label string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_TabItemButton(ctx, label, flagsIn) end

---Enforce the tab position to the left of the tab bar (after the tab list popup button).<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_Leading() end

---Disable behavior of closing tabs (that are submitted with p_open != nil) with<br>
---middle mouse button. You can still repro this behavior on user's side with<br>
---if(IsItemHovered() && IsMouseClicked(2)) p_open = false.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_NoCloseWithMiddleMouseButton() end

---Don't call PushID(tab->ID)/PopID() on BeginTabItem/EndTabItem.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_NoPushId() end

---Disable reordering this tab or having another tab cross over this tab.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_NoReorder() end

---Disable tooltip for the given tab.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_NoTooltip() end

---@return integer retval
function reaper.ImGui_TabItemFlags_None() end

---Trigger flag to programmatically make the tab selected when calling BeginTabItem.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_SetSelected() end

---Enforce the tab position to the right of the tab bar (before the scrolling buttons).<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_Trailing() end

---Append '*' to title without affecting the ID, as a convenience to avoid using<br>
---the ### operator. Also: tab is selected on closure and closure is deferred by<br>
---one frame to allow code to undo it without flicker.<br>
---@return integer retval
function reaper.ImGui_TabItemFlags_UnsavedDocument() end

---Set cell background color (top-most color).<br>
---@return integer retval
function reaper.ImGui_TableBgTarget_CellBg() end

---@return integer retval
function reaper.ImGui_TableBgTarget_None() end

---Set row background color 0 (generally used for background,<br>
---automatically set when TableFlags_RowBg is used).<br>
---@return integer retval
function reaper.ImGui_TableBgTarget_RowBg0() end

---Set row background color 1 (generally used for selection marking).<br>
---@return integer retval
function reaper.ImGui_TableBgTarget_RowBg1() end

---Default as a hidden/disabled column.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_DefaultHide() end

---Default as a sorting column.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_DefaultSort() end

---Overriding/master disable flag: hide column, won't show in context menu<br>
---(unlike calling TableSetColumnEnabled which manipulates the user accessible state).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_Disabled() end

---Ignore current Indent value when entering cell (default for columns > 0).<br>
---Indentation changes _within_ the cell will still be honored.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IndentDisable() end

---Use current Indent value when entering cell (default for column 0).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IndentEnable() end

---Status: is enabled == not hidden by user/api (referred to as "Hide" in<br>
---_DefaultHide and _NoHide) flags.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IsEnabled() end

---Status: is hovered by mouse.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IsHovered() end

---Status: is currently part of the sort specs.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IsSorted() end

---Status: is visible == is enabled AND not clipped by scrolling.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_IsVisible() end

---Disable clipping for this column<br>
---(all NoClip columns will render in a same draw command).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoClip() end

---TableHeadersRow will not submit label for this column.<br>
---Convenient for some small columns. Name will still appear in context menu.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoHeaderLabel() end

---Disable header text width contribution to automatic column width.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoHeaderWidth() end

---Disable ability to hide/disable this column.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoHide() end

---Disable manual reordering this column, this will also prevent other columns<br>
---from crossing over this column.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoReorder() end

---Disable manual resizing.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoResize() end

---Disable ability to sort on this field<br>
---(even if TableFlags_Sortable is set on the table).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoSort() end

---Disable ability to sort in the ascending direction.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoSortAscending() end

---Disable ability to sort in the descending direction.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_NoSortDescending() end

---@return integer retval
function reaper.ImGui_TableColumnFlags_None() end

---Make the initial sort direction Ascending when first sorting on this column (default).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_PreferSortAscending() end

---Make the initial sort direction Descending when first sorting on this column.<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_PreferSortDescending() end

---Column will not stretch. Preferable with horizontal scrolling enabled<br>
---(default if table sizing policy is _SizingFixedFit and table is resizable).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_WidthFixed() end

---Column will stretch. Preferable with horizontal scrolling disabled<br>
---(default if table sizing policy is _SizingStretchSame or _SizingStretchProp).<br>
---@return integer retval
function reaper.ImGui_TableColumnFlags_WidthStretch() end

---Draw all borders.<br>
---@return integer retval
function reaper.ImGui_TableFlags_Borders() end

---Draw horizontal borders.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersH() end

---Draw inner borders.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersInner() end

---Draw horizontal borders between rows.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersInnerH() end

---Draw vertical borders between columns.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersInnerV() end

---Draw outer borders.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersOuter() end

---Draw horizontal borders at the top and bottom.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersOuterH() end

---Draw vertical borders on the left and right sides.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersOuterV() end

---Draw vertical borders.<br>
---@return integer retval
function reaper.ImGui_TableFlags_BordersV() end

---Right-click on columns body/contents will display table context menu.<br>
---By default it is available in TableHeadersRow.<br>
---@return integer retval
function reaper.ImGui_TableFlags_ContextMenuInBody() end

---Enable hiding/disabling columns in context menu.<br>
---@return integer retval
function reaper.ImGui_TableFlags_Hideable() end

---Disable clipping rectangle for every individual columns<br>
---(reduce draw command count, items will be able to overflow into other columns).<br>
---Generally incompatible with TableSetupScrollFreeze.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoClip() end

---Make outer width auto-fit to columns, overriding outer_size.x value. Only<br>
---available when ScrollX/ScrollY are disabled and Stretch columns are not used.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoHostExtendX() end

---Make outer height stop exactly at outer_size.y (prevent auto-extending table<br>
---past the limit). Only available when ScrollX/ScrollY are disabled.<br>
---Data below the limit will be clipped and not visible.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoHostExtendY() end

---Disable keeping column always minimally visible when ScrollX is off and table<br>
---gets too small. Not recommended if columns are resizable.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoKeepColumnsVisible() end

---Disable inner padding between columns (double inner padding if<br>
---TableFlags_BordersOuterV is on, single inner padding if BordersOuterV is off).<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoPadInnerX() end

---Default if TableFlags_BordersOuterV is off. Disable outermost padding.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoPadOuterX() end

---Disable persisting columns order, width and sort settings in the .ini file.<br>
---@return integer retval
function reaper.ImGui_TableFlags_NoSavedSettings() end

---@return integer retval
function reaper.ImGui_TableFlags_None() end

---Default if TableFlags_BordersOuterV is on. Enable outermost padding.<br>
---Generally desirable if you have headers.<br>
---@return integer retval
function reaper.ImGui_TableFlags_PadOuterX() end

---Disable distributing remainder width to stretched columns (width allocation<br>
---on a 100-wide table with 3 columns: Without this flag: 33,33,34. With this<br>
---flag: 33,33,33).<br>
---With larger number of columns, resizing will appear to be less smooth.<br>
---@return integer retval
function reaper.ImGui_TableFlags_PreciseWidths() end

---Enable reordering columns in header row<br>
---(need calling TableSetupColumn + TableHeadersRow to display headers).<br>
---@return integer retval
function reaper.ImGui_TableFlags_Reorderable() end

---Enable resizing columns.<br>
---@return integer retval
function reaper.ImGui_TableFlags_Resizable() end

---Set each RowBg color with Col_TableRowBg or Col_TableRowBgAlt (equivalent of<br>
---calling TableSetBgColor with TableBgTarget_RowBg0 on each row manually).<br>
---@return integer retval
function reaper.ImGui_TableFlags_RowBg() end

---Enable horizontal scrolling. Require 'outer_size' parameter of BeginTable to<br>
---specify the container size. Changes default sizing policy.<br>
---Because this creates a child window, ScrollY is currently generally<br>
---recommended when using ScrollX.<br>
---@return integer retval
function reaper.ImGui_TableFlags_ScrollX() end

---Enable vertical scrolling.<br>
---Require 'outer_size' parameter of BeginTable to specify the container size.<br>
---@return integer retval
function reaper.ImGui_TableFlags_ScrollY() end

---Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable),<br>
---matching contents width.<br>
---@return integer retval
function reaper.ImGui_TableFlags_SizingFixedFit() end

---Columns default to _WidthFixed or _WidthAuto (if resizable or not resizable),<br>
---matching the maximum contents width of all columns.<br>
---Implicitly enable TableFlags_NoKeepColumnsVisible.<br>
---@return integer retval
function reaper.ImGui_TableFlags_SizingFixedSame() end

---Columns default to _WidthStretch with default weights proportional to each<br>
---columns contents widths.<br>
---@return integer retval
function reaper.ImGui_TableFlags_SizingStretchProp() end

---Columns default to _WidthStretch with default weights all equal,<br>
---unless overriden by TableSetupColumn.<br>
---@return integer retval
function reaper.ImGui_TableFlags_SizingStretchSame() end

---Hold shift when clicking headers to sort on multiple column.<br>
---TableGetGetSortSpecs may return specs where (SpecsCount > 1).<br>
---@return integer retval
function reaper.ImGui_TableFlags_SortMulti() end

---Allow no sorting, disable default sorting.<br>
---TableGetColumnSortSpecs may return specs where (SpecsCount == 0).<br>
---@return integer retval
function reaper.ImGui_TableFlags_SortTristate() end

---Enable sorting. Call TableNeedSort/TableGetColumnSortSpecs to obtain sort specs.<br>
---Also see TableFlags_SortMulti and TableFlags_SortTristate.<br>
---@return integer retval
function reaper.ImGui_TableFlags_Sortable() end

---Return number of columns (value passed to BeginTable).<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_TableGetColumnCount(ctx) end

---Return column flags so you can query their Enabled/Visible/Sorted/Hovered<br>
---status flags. Pass -1 to use current column.<br>
---@param ctx ImGui_Context
---@param column_nIn? integer
---@return integer retval
function reaper.ImGui_TableGetColumnFlags(ctx, column_nIn) end

---Return current column index.<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_TableGetColumnIndex(ctx) end

---Return "" if column didn't have a name declared by TableSetupColumn.<br>
---Pass -1 to use current column.<br>
---@param ctx ImGui_Context
---@param column_nIn? integer
---@return string retval
function reaper.ImGui_TableGetColumnName(ctx, column_nIn) end

---Sorting specification for one column of a table.<br>
---Call while incrementing 'id' from 0 until false is returned.
---
---- ColumnUserID:  User id of the column (if specified by a TableSetupColumn call)<br>
---- ColumnIndex:   Index of the column<br>
---- SortOrder:     Index within parent SortSpecs (always stored in order starting<br>
---from 0, tables sorted on a single criteria will always have a 0 here)<br>
---- SortDirection: SortDirection_Ascending or SortDirection_Descending<br>
---(you can use this or SortSign, whichever is more convenient for your sort<br>
---function)
---
---See TableNeedSort.<br>
---@param ctx ImGui_Context
---@param id integer
---@return boolean retval
---@return integer column_user_id
---@return integer column_index
---@return integer sort_order
---@return integer sort_direction
function reaper.ImGui_TableGetColumnSortSpecs(ctx, id) end

---Return current row index.<br>
---@param ctx ImGui_Context
---@return integer retval
function reaper.ImGui_TableGetRowIndex(ctx) end

---Submit one header cell manually (rarely used). See TableSetupColumn.<br>
---@param ctx ImGui_Context
---@param label string
function reaper.ImGui_TableHeader(ctx, label) end

---Submit all headers cells based on data provided to TableSetupColumn +<br>
---submit context menu.<br>
---@param ctx ImGui_Context
function reaper.ImGui_TableHeadersRow(ctx) end

---Return true once when sorting specs have changed since last call,<br>
---or the first time. 'has_specs' is false when not sorting.
---
---See TableGetColumnSortSpecs.<br>
---@param ctx ImGui_Context
---@return boolean retval
---@return boolean has_specs
function reaper.ImGui_TableNeedSort(ctx) end

---Append into the next column (or first column of next row if currently in<br>
---last column). Return true when column is visible.<br>
---@param ctx ImGui_Context
---@return boolean retval
function reaper.ImGui_TableNextColumn(ctx) end

---Append into the first cell of a new row.<br>
---@param ctx ImGui_Context
---@param row_flagsIn? integer
---@param min_row_heightIn? number
function reaper.ImGui_TableNextRow(ctx, row_flagsIn, min_row_heightIn) end

---Identify header row (set default background color + width of its contents<br>
---accounted different for auto column width).<br>
---@return integer retval
function reaper.ImGui_TableRowFlags_Headers() end

---For TableNextRow.<br>
---@return integer retval
function reaper.ImGui_TableRowFlags_None() end

---Change the color of a cell, row, or column.<br>
---See TableBgTarget_* flags for details.<br>
---@param ctx ImGui_Context
---@param target integer
---@param color_rgba integer
---@param column_nIn? integer
function reaper.ImGui_TableSetBgColor(ctx, target, color_rgba, column_nIn) end

---Change user-accessible enabled/disabled state of a column, set to false to<br>
---hide the column. Note that end-user can use the context menu to change this<br>
---themselves (right-click in headers, or right-click in columns body with<br>
---TableFlags_ContextMenuInBody).
---
---- Require table to have the TableFlags_Hideable flag because we are manipulating<br>
---user accessible state.<br>
---- Request will be applied during next layout, which happens on the first call to<br>
---TableNextRow after Begin_Table.<br>
---- For the getter you can test<br>
---(TableGetColumnFlags() & TableColumnFlags_IsEnabled) != 0.<br>
---@param ctx ImGui_Context
---@param column_n integer
---@param v boolean
function reaper.ImGui_TableSetColumnEnabled(ctx, column_n, v) end

---Append into the specified column. Return true when column is visible.<br>
---@param ctx ImGui_Context
---@param column_n integer
---@return boolean retval
function reaper.ImGui_TableSetColumnIndex(ctx, column_n) end

---Use to specify label, resizing policy, default width/weight, id,<br>
---various other flags etc.<br>
---@param ctx ImGui_Context
---@param label string
---@param flagsIn? integer
---@param init_width_or_weightIn? number
---@param user_idIn? integer
function reaper.ImGui_TableSetupColumn(ctx, label, flagsIn, init_width_or_weightIn, user_idIn) end

---Lock columns/rows so they stay visible when scrolled.<br>
---@param ctx ImGui_Context
---@param cols integer
---@param rows integer
function reaper.ImGui_TableSetupScrollFreeze(ctx, cols, rows) end

---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_Text(ctx, text) end

---Shortcut for PushStyleColor(Col_Text, color); Text(text); PopStyleColor();<br>
---@param ctx ImGui_Context
---@param col_rgba integer
---@param text string
function reaper.ImGui_TextColored(ctx, col_rgba, text) end

---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_TextDisabled(ctx, text) end

---@param filter ImGui_TextFilter
function reaper.ImGui_TextFilter_Clear(filter) end

---Helper calling InputText+TextFilter_Set<br>
---@param filter ImGui_TextFilter
---@param ctx ImGui_Context
---@param labelIn? string
---@param widthIn? number
---@return boolean retval
function reaper.ImGui_TextFilter_Draw(filter, ctx, labelIn, widthIn) end

---@param filter ImGui_TextFilter
---@return string retval
function reaper.ImGui_TextFilter_Get(filter) end

---@param filter ImGui_TextFilter
---@return boolean retval
function reaper.ImGui_TextFilter_IsActive(filter) end

---@param filter ImGui_TextFilter
---@param text string
---@return boolean retval
function reaper.ImGui_TextFilter_PassFilter(filter, text) end

---@param filter ImGui_TextFilter
---@param filter_text string
function reaper.ImGui_TextFilter_Set(filter, filter_text) end

---Shortcut for PushTextWrapPos(0.0); Text(text); PopTextWrapPos();.<br>
---Note that this won't work on an auto-resizing window if there's no other<br>
---widgets to extend the window width, yoy may need to set a size using<br>
---SetNextWindowSize.<br>
---@param ctx ImGui_Context
---@param text string
function reaper.ImGui_TextWrapped(ctx, text) end

---TreeNode functions return true when the node is open, in which case you need<br>
---to also call TreePop when you are finished displaying the tree node contents.<br>
---@param ctx ImGui_Context
---@param label string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_TreeNode(ctx, label, flagsIn) end

---Helper variation to easily decorelate the id from the displayed string.<br>
---Read the [FAQ](https://dearimgui.com/faq) about why and how to use ID.<br>
---To align arbitrary text at the same level as a TreeNode you can use Bullet.<br>
---@param ctx ImGui_Context
---@param str_id string
---@param label string
---@param flagsIn? integer
---@return boolean retval
function reaper.ImGui_TreeNodeEx(ctx, str_id, label, flagsIn) end

---Hit testing to allow subsequent widgets to overlap this one.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_AllowItemOverlap() end

---Display a bullet instead of arrow.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_Bullet() end

---TreeNodeFlags_Framed | TreeNodeFlags_NoTreePushOnOpen | TreeNodeFlags_NoAutoOpenOnLog<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_CollapsingHeader() end

---Default node to be open.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_DefaultOpen() end

---Use FramePadding (even for an unframed text node) to vertically align text<br>
---baseline to regular widget height.<br>
---Equivalent to calling AlignTextToFramePadding.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_FramePadding() end

---Draw frame with background (e.g. for CollapsingHeader).<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_Framed() end

---No collapsing, no arrow (use as a convenience for leaf nodes).<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_Leaf() end

---Don't automatically and temporarily open node when Logging is active<br>
---(by default logging will automatically open tree nodes).<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_NoAutoOpenOnLog() end

---Don't do a TreePush when open (e.g. for CollapsingHeader)<br>
---= no extra indent nor pushing on ID stack.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_NoTreePushOnOpen() end

---@return integer retval
function reaper.ImGui_TreeNodeFlags_None() end

---Only open when clicking on the arrow part.<br>
---If TreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or<br>
---double-click all box to open.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_OpenOnArrow() end

---Need double-click to open node.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_OpenOnDoubleClick() end

---Draw as selected.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_Selected() end

---Extend hit box to the right-most edge, even if not framed.<br>
---This is not the default in order to allow adding other items on the same line.<br>
---In the future we may refactor the hit system to be front-to-back,<br>
---allowing natural overlaps and then this can become the default.<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_SpanAvailWidth() end

---Extend hit box to the left-most and right-most edges (bypass the indented area).<br>
---@return integer retval
function reaper.ImGui_TreeNodeFlags_SpanFullWidth() end

---Unindent()+PopID()<br>
---@param ctx ImGui_Context
function reaper.ImGui_TreePop(ctx) end

---Indent()+PushID(). Already called by TreeNode when returning true,<br>
---but you can call TreePush/TreePop yourself if desired.<br>
---@param ctx ImGui_Context
---@param str_id string
function reaper.ImGui_TreePush(ctx, str_id) end

---Move content position back to the left, by 'indent_w', or<br>
---StyleVar_IndentSpacing if 'indent_w' >= 0<br>
---@param ctx ImGui_Context
---@param indent_wIn? number
function reaper.ImGui_Unindent(ctx, indent_wIn) end

---@param ctx ImGui_Context
---@param label string
---@param size_w number
---@param size_h number
---@param v number
---@param v_min number
---@param v_max number
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return number v
function reaper.ImGui_VSliderDouble(ctx, label, size_w, size_h, v, v_min, v_max, formatIn, flagsIn) end

---@param ctx ImGui_Context
---@param label string
---@param size_w number
---@param size_h number
---@param v integer
---@param v_min integer
---@param v_max integer
---@param formatIn? string
---@param flagsIn? integer
---@return boolean retval
---@return integer v
function reaper.ImGui_VSliderInt(ctx, label, size_w, size_h, v, v_min, v_max, formatIn, flagsIn) end

---Return whether the pointer of the specified type is valid.
---
---Supported types are:
---
---- ImGui_Context*<br>
---- ImGui_DrawList*<br>
---- ImGui_DrawListSplitter*<br>
---- ImGui_Font*<br>
---- ImGui_Function*<br>
---- ImGui_Image*<br>
---- ImGui_ImageSet*<br>
---- ImGui_ListClipper*<br>
---- ImGui_TextFilter*<br>
---- ImGui_Viewport*<br>
---@param pointer userdata
---@param type string
---@return boolean retval
function reaper.ImGui_ValidatePtr(pointer, type) end

---Center of the viewport.<br>
---@param viewport ImGui_Viewport
---@return number x
---@return number y
function reaper.ImGui_Viewport_GetCenter(viewport) end

---Main Area: Position of the viewport<br>
---@param viewport ImGui_Viewport
---@return number x
---@return number y
function reaper.ImGui_Viewport_GetPos(viewport) end

---Main Area: Size of the viewport.<br>
---@param viewport ImGui_Viewport
---@return number w
---@return number h
function reaper.ImGui_Viewport_GetSize(viewport) end

---Center of the viewport's work area.<br>
---@param viewport ImGui_Viewport
---@return number x
---@return number y
function reaper.ImGui_Viewport_GetWorkCenter(viewport) end

--->= Viewport_GetPos<br>
---@param viewport ImGui_Viewport
---@return number x
---@return number y
function reaper.ImGui_Viewport_GetWorkPos(viewport) end

--->= Viewport_GetSize<br>
---@param viewport ImGui_Viewport
---@return number w
---@return number h
function reaper.ImGui_Viewport_GetWorkSize(viewport) end

---Resize every window to its content every frame.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_AlwaysAutoResize() end

---Always show horizontal scrollbar (even if ContentSize.x > Size.x).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_AlwaysHorizontalScrollbar() end

---Ensure child windows without border uses StyleVar_WindowPadding<br>
---(ignored by default for non-bordered child windows, because more convenient).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_AlwaysUseWindowPadding() end

---Always show vertical scrollbar (even if ContentSize.y > Size.y).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_AlwaysVerticalScrollbar() end

---Allow horizontal scrollbar to appear (off by default).<br>
---You may use SetNextWindowContentSize(width, 0.0) prior to calling Begin() to<br>
---specify width. Read code in the demo's "Horizontal Scrolling" section.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_HorizontalScrollbar() end

---Has a menu-bar.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_MenuBar() end

---Disable drawing background color (WindowBg, etc.) and outside border.<br>
---Similar as using SetNextWindowBgAlpha(0.0).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoBackground() end

---Disable user collapsing window by double-clicking on it.<br>
---Also referred to as Window Menu Button (e.g. within a docking node).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoCollapse() end

---WindowFlags_NoTitleBar | WindowFlags_NoResize | WindowFlags_NoScrollbar |<br>
---WindowFlags_NoCollapse<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoDecoration() end

---Disable docking of this window.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoDocking() end

---Disable taking focus when transitioning from hidden to visible state.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoFocusOnAppearing() end

---WindowFlags_NoMouseInputs | WindowFlags_NoNavInputs | WindowFlags_NoNavFocus<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoInputs() end

---Disable catching mouse, hovering test with pass through.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoMouseInputs() end

---Disable user moving the window.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoMove() end

---WindowFlags_NoNavInputs | WindowFlags_NoNavFocus<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoNav() end

---No focusing toward this window with gamepad/keyboard navigation<br>
---(e.g. skipped by CTRL+TAB).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoNavFocus() end

---No gamepad/keyboard navigation within the window.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoNavInputs() end

---Disable user resizing with the lower-right grip.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoResize() end

---Never load/save settings in .ini file.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoSavedSettings() end

---Disable user vertically scrolling with mouse wheel.<br>
---On child window, mouse wheel will be forwarded to the parent unless<br>
---NoScrollbar is also set.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoScrollWithMouse() end

---Disable scrollbars (window can still scroll with mouse or programmatically).<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoScrollbar() end

---Disable title-bar.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_NoTitleBar() end

---Default flag.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_None() end

---Show the window above all non-topmost windows.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_TopMost() end

---Display a dot next to the title. When used in a tab/docking context,<br>
---tab is selected when clicking the X + closure is not assumed<br>
---(will wait for user to stop submitting the tab).<br>
---Otherwise closure is assumed when pressing the X,<br>
---so if you keep submitting the tab may reappear at end of tab bar.<br>
---@return integer retval
function reaper.ImGui_WindowFlags_UnsavedDocument() end
