-- Extra Keybinds for RuneScape: Dragonwilds
--
-- Every action row in Settings > Controls has a second keyboard/mouse box. The game keeps it
-- hidden and switched off. This mod shows it, switches it on and makes room for it. Binding a
-- key, the "press any key" prompt, the "already in use" question, saving and Reset To Defaults
-- are all the game's own code. The mod adds one thing of its own: an X on a second key that
-- clears it.

local config = require("config")

local TAG = "[ExtraKeybinds] "
local function Log(msg) print(TAG .. tostring(msg) .. "\n") end
local function Debug(msg) if config.DebugLogging then Log(msg) end end

-- ESlateVisibility
local VISIBLE = 0
local COLLAPSED = 1
local HIT_TEST_INVISIBLE = 3
local SELF_HIT_TEST_INVISIBLE = 4
-- ESlateSizeRule
local FILL = 1
-- EHorizontalAlignment / EVerticalAlignment (0 is Fill)
local ALIGN_FILL, ALIGN_CENTER, ALIGN_RIGHT = 0, 2, 3
-- EPlayerMappableKeySlot::Second, the slot KeyButton2 binds
local SECOND_SLOT = 1
-- EKeyMappingSettingsInputType::KeyboardMouse
local KEYBOARD_MOUSE = 0

-- The row's own gaps (Spacer_137, _262, _382, _468), repeated in the layer that holds the X.
local GAP_BEFORE_KEYS, GAP_BETWEEN_KEYS, GAP_AFTER_KEYS = 10, 20, 10

local CLEAR_BUTTON_PACKAGE = "/Game/UI/Common/WBP_InvisibleButton"
local CLEAR_FONT = "/Game/UI/Fonts/Poppins-Regular_Font.Poppins-Regular_Font"
local CLEAR_SIZE = 30
local CLEAR_COLOR = { R = 0.60, G = 0.57, B = 0.53, A = 1 }       -- the game's dim text
local CLEAR_HOVER_COLOR = { R = 0.95, G = 0.40, B = 0.35, A = 1 }

local function Valid(obj)
    if obj == nil then return false end
    local ok, res = pcall(function() return obj:IsValid() end)
    return ok and res == true
end

local function ClassName(obj)
    local ok, name = pcall(function() return obj:GetClass():GetFName():ToString() end)
    return ok and name or ""
end

-- StaticConstructObject silently makes nothing when the name is already taken in that outer, so
-- every object gets a name of its own.
local SESSION = tostring(os.time())
local nameCount = 0
local function New(classPath, outer, name)
    nameCount = nameCount + 1
    local class = StaticFindObject(classPath)
    return StaticConstructObject(class, outer, FName(string.format("EK_%s_%s_%d", name, SESSION, nameCount)))
end

-- Gives one child of a horizontal box a share of the box's width.
local function SetFill(widget, weight)
    local slot = widget.Slot
    if not Valid(slot) then return end
    local size = slot.Size
    if size.SizeRule == FILL and math.abs(size.Value - weight) < 0.01 then return end
    slot:SetSize({ Value = weight, SizeRule = FILL })
end

------------------------------------------------------------------ which action a row is

-- A row only knows its action's name as text ("Jump"). The player controller's KeySettingsMap
-- has every action's mapping name next to that same text, so the two are matched by it.
local actionByLabel = nil   -- label -> { name = mapping name, linked = { names bound along with it } }
local actionsFrom = nil     -- address of the controller the table was read from

local function ReadActions(menu)
    local pc = menu:GetOwningPlayer()
    if not Valid(pc) then return end
    local address = pc:GetAddress()
    if actionByLabel and actionsFrom == address then return end
    local found, count = {}, 0
    pc.KeySettingsMap:ForEach(function(key, value)
        local setting = value:get()
        if not Valid(setting) or setting.bHideFromList or setting.InputType ~= KEYBOARD_MOUSE then return end
        local label = setting.DisplayName:ToString()
        if label == "" then return end
        if found[label] ~= nil then
            found[label] = false -- two actions with the same name can't be told apart
            return
        end
        local linked = {}
        local names = setting.LinkedMappingNames
        for i = 1, #names do linked[#linked + 1] = names[i]:ToString() end
        found[label] = { name = key:get():ToString(), linked = linked }
        count = count + 1
    end)
    actionByLabel, actionsFrom = found, address
    Debug("Read " .. count .. " keyboard/mouse actions")
end

local function ActionForRow(row)
    if not actionByLabel then return nil end
    local ok, label = pcall(function() return row.ButtonLabel:ToString() end)
    if not ok then return nil end
    return actionByLabel[label] or nil
end

------------------------------------------------------------------ the clear button

local rowUi = {}            -- row address -> the X this mod added to that row
local uiByButton = {}       -- clear button address -> the same table
local pendingClear = nil    -- the action whose X was clicked, cleared on the next tick
local hooked = false

local function ClearButtonClass()
    local path = CLEAR_BUTTON_PACKAGE .. ".WBP_InvisibleButton_C"
    local class = StaticFindObject(path)
    if Valid(class) then return class end
    pcall(LoadAsset, CLEAR_BUTTON_PACKAGE)
    class = StaticFindObject(path)
    return Valid(class) and class or nil
end

local clearFont = nil
local function StyleClearText(text)
    pcall(function()
        if not Valid(clearFont) then
            clearFont = StaticFindObject(CLEAR_FONT)
            if not Valid(clearFont) then clearFont = LoadAsset(CLEAR_FONT) end
        end
        local font = text.Font
        if Valid(clearFont) then
            font.FontObject = clearFont
            font.TypefaceFontName = FName("Default")
        end
        font.Size = 15
        text:SetFont(font)
    end)
end

-- Adds a layer over the row with the same columns as the row itself, empty except for an X at
-- the right-hand end of the second key's column. Nothing of the game's is moved or replaced.
local function BuildClear(row, menu)
    local tree = row.WidgetTree
    local root = Valid(tree) and tree.RootWidget or nil
    if not Valid(root) or ClassName(root) ~= "Overlay" then return nil end
    local class = ClearButtonClass()
    local library = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not class or not Valid(library) then return nil end

    local columns = New("/Script/UMG.HorizontalBox", tree, "Columns")
    local layer = root:AddChildToOverlay(columns)
    layer:SetHorizontalAlignment(ALIGN_FILL)
    layer:SetVerticalAlignment(ALIGN_FILL)
    columns:SetVisibility(COLLAPSED)

    local function Column(widget, weight, left, right)
        local slot = columns:AddChildToHorizontalBox(widget)
        slot:SetSize({ Value = weight, SizeRule = FILL })
        slot:SetPadding({ Left = left, Top = 0, Right = right, Bottom = 0 })
        return slot
    end
    local function Gap(weight, left, right)
        local gap = New("/Script/UMG.Spacer", tree, "Gap")
        gap:SetVisibility(HIT_TEST_INVISIBLE)
        Column(gap, weight, left, right)
        return gap
    end

    local nameGap = Gap(config.NameWidth, 0, 0)     -- the action's name
    Gap(1.0, GAP_BEFORE_KEYS, 0)                    -- the first key

    local cell = New("/Script/UMG.Overlay", tree, "Cell")
    cell:SetVisibility(SELF_HIT_TEST_INVISIBLE)
    local cellSlot = Column(cell, 1.0, GAP_BETWEEN_KEYS, 0)   -- the second key
    cellSlot:SetHorizontalAlignment(ALIGN_RIGHT)
    cellSlot:SetVerticalAlignment(ALIGN_CENTER)

    Gap(1.0, GAP_BETWEEN_KEYS, GAP_AFTER_KEYS)      -- the controller button

    -- The click target is one of the game's own buttons (it draws nothing), because its click
    -- is a function UE4SS can hook. A plain UMG button could only be polled.
    local button = library:Create(menu, class, menu:GetOwningPlayer())
    if not Valid(button) then return nil end
    pcall(function() button:SetIsFocusable(false) end)
    local box = New("/Script/UMG.SizeBox", tree, "Box")
    box:SetWidthOverride(CLEAR_SIZE)
    box:SetHeightOverride(CLEAR_SIZE)
    box:SetContent(button)
    cell:AddChildToOverlay(box)

    local text = New("/Script/UMG.TextBlock", tree, "X")
    text:SetText(FText("X"))
    text:SetColorAndOpacity({ SpecifiedColor = CLEAR_COLOR, ColorUseRule = 0 })
    StyleClearText(text)
    text:SetVisibility(HIT_TEST_INVISIBLE)
    local textSlot = cell:AddChildToOverlay(text)
    textSlot:SetHorizontalAlignment(ALIGN_CENTER)
    textSlot:SetVerticalAlignment(ALIGN_CENTER)

    local ui = { columns = columns, nameGap = nameGap, button = button, text = text, hovered = false }
    uiByButton[button:GetAddress()] = ui
    Debug("Added a clear button to " .. row:GetFName():ToString())
    return ui
end

local function UpdateClear(row, menu, keyboardRow, nameWeight)
    local address = row:GetAddress()
    local ui = rowUi[address]
    if ui and not (Valid(ui.columns) and Valid(ui.button)) then
        rowUi[address] = nil
        ui = nil
    end

    -- The X belongs on rows whose second box holds a key. The box's switcher shows page 1 for a
    -- key and page 0 for the empty dash.
    local action = keyboardRow and ActionForRow(row) or nil
    local show = false
    if action then
        local ok, page = pcall(function() return row.KeyButton2.ButtonVisibilitySwitcher:GetActiveWidgetIndex() end)
        show = ok and page == 1
    end

    if not ui then
        if not show then return end
        ui = BuildClear(row, menu)
        if not ui then return end
        rowUi[address] = ui
    end
    ui.action = show and action or nil

    local want = show and SELF_HIT_TEST_INVISIBLE or COLLAPSED
    if ui.columns:GetVisibility() ~= want then ui.columns:SetVisibility(want) end
    if not show then return end

    SetFill(ui.nameGap, nameWeight)
    local hovered = ui.button:IsHovered() == true
    if hovered ~= ui.hovered then
        ui.hovered = hovered
        ui.text:SetColorAndOpacity({ SpecifiedColor = hovered and CLEAR_HOVER_COLOR or CLEAR_COLOR, ColorUseRule = 0 })
    end
end

local menus = {}    -- every Controls page (KeyBindingWidget) the game has made; see FindMenus

local function ClearSecondKey(action)
    local settings = nil
    for _, candidate in ipairs(FindAllOf("EnhancedInputUserSettings") or {}) do
        local ok, profile = pcall(function() return candidate:GetActiveKeyProfile() end)
        if ok and Valid(profile) then settings = candidate end
    end
    if not settings then
        Log("Could not find the game's keybind settings; nothing was cleared.")
        return
    end
    -- The game binds an action's linked names along with it (Building also opens and closes the
    -- build menu, for example), so they are cleared along with it too.
    local names = { action.name }
    for _, name in ipairs(action.linked) do names[#names + 1] = name end
    for _, name in ipairs(names) do
        pcall(function()
            settings:UnMapPlayerKey({ MappingName = FName(name), Slot = SECOND_SLOT, bCreateMatchingSlotIfNeeded = false }, {})
        end)
    end
    settings:ApplySettings()
    settings:SaveSettings()
    Log("Cleared the second key of " .. action.name)
    -- Have the game fill its rows again, so the box shows the dash.
    for _, menu in ipairs(menus) do
        pcall(function()
            if Valid(menu) and Valid(menu.KeyBindingList) then menu.KeyBindingList:RegenerateAllEntries() end
        end)
    end
end

local function HookClicks()
    if hooked then return end
    local ok = pcall(RegisterHook, "/Script/CommonUI.CommonButtonBase:HandleButtonClicked", function(self)
        pcall(function()
            local ui = uiByButton[self:get():GetAddress()]
            -- Cleared on the next tick, not here: the click is still being handled by the button
            -- that the row refresh would rebuild.
            if ui and ui.action and Valid(ui.button) then pendingClear = ui.action end
        end)
    end)
    hooked = ok
    if ok then Debug("Hooked button clicks") end
end

------------------------------------------------------------------ the rows

local function FixRow(row, menu)
    local key1, key2, pad = row.KeyButton1, row.KeyButton2, row.GamepadButton
    if not (Valid(key1) and Valid(key2) and Valid(pad)) then return end

    -- The game shows KeyButton1 on rows that have a keyboard/mouse key. Those get the second box.
    local keyboardRow = key1:GetVisibility() == VISIBLE
    if keyboardRow then
        if key2:GetVisibility() ~= VISIBLE then key2:SetVisibility(VISIBLE) end
        local enabled = key1:GetIsEnabled()
        if key2:GetIsEnabled() ~= enabled then key2:SetIsEnabled(enabled) end
    end

    local shown = 0
    for _, button in ipairs({ key1, key2, pad }) do
        if button:GetVisibility() ~= COLLAPSED then shown = shown + 1 end
    end
    local nameWeight = config.NameWidth + (3 - shown)

    if shown > 0 then -- not a category heading
        -- Three boxes at the game's width leave no room for the action's name, so the name and
        -- the boxes share the row instead. Boxes the row doesn't have give their share to the
        -- name, which keeps the columns lined up from row to row.
        local box = key1:GetParent()
        if Valid(box) then
            local label = box:GetChildAt(0)
            if Valid(label) then SetFill(label, nameWeight) end
            SetFill(key1, 1.0)
            SetFill(key2, 1.0)
            SetFill(pad, 1.0)
            -- The gap in front of the second box is hidden along with it.
            local gap = box:GetChildAt(box:GetChildIndex(key2) - 1)
            if Valid(gap) and ClassName(gap) == "Spacer" and gap:GetVisibility() == COLLAPSED then
                gap:SetVisibility(SELF_HIT_TEST_INVISIBLE)
            end
        end
    end

    UpdateClear(row, menu, keyboardRow and shown == 3, nameWeight)
end

-- The main menu and the in-game menu each have their own Controls page. The blueprint's template
-- turns up in searches too; it has no list, so it's skipped.
local nextSearch = 0
local errors = 0

local function AddMenu(widget)
    if not Valid(widget) then return end
    local address = widget:GetAddress()
    for _, known in ipairs(menus) do
        if Valid(known) and known:GetAddress() == address then return end
    end
    menus[#menus + 1] = widget
end

local function Forget(map)
    for address, ui in pairs(map) do
        if not (Valid(ui.columns) and Valid(ui.button)) then map[address] = nil end
    end
end

local function FixMenu(menu)
    local list = menu.KeyBindingList
    if not Valid(list) or not menu:IsVisible() then return end
    ReadActions(menu)
    -- The game hides the second box again each time it reuses a row (scrolling, rebinding), so
    -- the rows on screen are checked every tick.
    local rows = list:GetDisplayedEntryWidgets()
    for i = 1, #rows do
        local row = rows[i]:get()
        if Valid(row) then FixRow(row, menu) end
    end
end

local watching = false
local function WatchForMenus()
    if watching then return end
    -- Fails while the game's classes aren't loaded yet; Tick tries again.
    watching = pcall(NotifyOnNewObject, "/Script/Dominion.KeyBindingWidget", function(widget)
        menus[#menus + 1] = widget
    end)
    if watching then Debug("Watching for Controls pages") end
end

local function Report(ok, err)
    if ok or errors >= 5 then return end
    errors = errors + 1
    Log("Error: " .. tostring(err))
end

local function Tick()
    if pendingClear then
        local action = pendingClear
        pendingClear = nil
        Report(pcall(ClearSecondKey, action))
    end

    -- New pages are reported by NotifyOnNewObject. This search is the safety net, and it walks
    -- every object in the game, so it runs rarely once the notification is in place.
    local now = os.clock()
    if now >= nextSearch then
        WatchForMenus()
        HookClicks()
        nextSearch = now + (watching and 10.0 or 2.0)
        for i = #menus, 1, -1 do
            if not Valid(menus[i]) then table.remove(menus, i) end
        end
        Forget(rowUi)
        Forget(uiByButton)
        for _, widget in ipairs(FindAllOf("KeyBindingWidget") or {}) do AddMenu(widget) end
    end

    for _, menu in ipairs(menus) do
        if Valid(menu) then Report(pcall(FixMenu, menu)) end
    end
end

WatchForMenus()

-- LoopInGameThreadWithDelay keeps this on the game thread. (LoopAsync + ExecuteInGameThread ran
-- the same Lua state on two threads and broke other mods' loops.)
ExtraKeybindsLoop = LoopInGameThreadWithDelay(config.PollMs, function() pcall(Tick) end)
Log("Loaded. Settings > Controls now has a second key box on every action.")
