local config = require("hotkeyExtender.config");


local combo = {
    keyCode = tes3.scanCode.F2,
    isAltDown = false,
    isControlDown = false,
    isShiftDown = false
}

local _STATE = {
    NORMAL = 0,
    OPEN = 1,
    LISTENING = 1
}

local state = _STATE.NORMAL
local listeningHotkeyIndex = nil

local menu = nil
local hotkeyField = nil
local listeningKeyPopup = nil

local menuId = -770
local currentChildId = menuId - 1;

local hotkeys = config.hotkeys
local hotkeysNum = 1

local function getId()
    currentChildId = currentChildId - 1
    return currentChildId
end

-- helper --
local function getKeybindKey(value)
    for k, v in pairs(tes3.scanCode) do
        if v == value then
            return k
        end
    end
    return nil
end

-- BUTTON CALLBACKS --
local function closeMenu(e)
    menu:destroy()
    tes3ui.leaveMenuMode()
    state = _STATE.NORMAL
end

-- MAIN DRAWING METHODS --

local function renderHotkeyField()
    if not hotkeyField or not menu then
        return
    end
    hotkeyField:destroyChildren()
    for _, hotkey in ipairs(hotkeys) do
        if (_ > 1) then
            hotkeyField:createDivider()
        end
        local hotkeyLabel = hotkeyField:createLabel({
            id = getId(),
            text = hotkey.object and "Hotkey " .. _ or "New hotkey"
        })
        local hotkeyButton = hotkeyField:createButton({
            id = getId(),
            text = hotkey.object and string.upper(hotkey.keyName) or "Select key"
        })
        hotkeyButton:register(tes3.uiEvent.mouseClick, function(e)
            state = _STATE.LISTENING
            listeningKeyPopup = tes3ui.createMenu({ id = getId(),
            dragFrame = false,
            fixedFrame = true,
            modal = true,
            loadable = false })
            listeningKeyPopup:createLabel({ id = getId(), text = "Press the key you want to bind" })
            listeningHotkeyIndex = _
            hotkey._button = hotkeyButton
            hotkey._label = hotkeyLabel
            hotkeyButton.text = "Listening..."
        end)
        local actionButton = hotkeyField:createButton({
            id = getId(),
            text = (hotkey.action and hotkey.action.name or "Set Action")
        })
            actionButton:register(tes3.uiEvent.mouseClick, function(e)
                tes3ui.showMagicSelectMenu({
                    id = getId(),
                    title = "Select Action",
                    selectSpells = true,
                    selectPowers = true,
                    selectEnchanted = true,
                    callback = function(e)
                        hotkey.action = e.spell and e.spell or (e.item and e.item or nil)
                        hotkey.actionId = e.spell and e.spell.id or e.item.id
                        hotkey.actionType = e.spell and "spell" or "item"
                        actionButton.text = hotkey.action.name
                        renderHotkeyField()
                        if hotkey.action and hotkey.object then mwse.saveConfig("hotkeyExtender", { hotkeys = hotkeys }) end
                    end
                })
            end)
    end
    hotkeyField:getContentElement():updateLayout()
    menu:updateLayout()
end

local function addCb(e)
    hotkeys[hotkeysNum] = {
        object = nil,
        keyName = null,
        action = nil
    }
    hotkeysNum = hotkeysNum + 1
    renderHotkeyField()
end

local function renderMenu()
    if not menu then
        return
    end
    menu:createLabel({
        id = getId(),
        text = "Hotkey Map"
    })
    hotkeyField = menu:createThinBorder({
        id = getId()
    });
    hotkeyField.height = 400;
    hotkeyField.width = 200;
    hotkeyField.flowDirection = tes3.flowDirection.topToBottom;
    local addHotkey = menu:createButton({
        id = getId(),
        text = "Add hotkey"
    })
    addHotkey:register(tes3.uiEvent.mouseClick, addCb)
    local resetButton = menu:createButton({
        id = getId(),
        text = "Reset all"
    })
    local okButton = menu:createButton({
        id = getId(),
        text = "Finish"
    })
    okButton:register(tes3.uiEvent.mouseClick, closeMenu)
end

local function openMenu()
    if hotkeys[1] ~= nil then
        for _, hotkey in ipairs(hotkeys) do
            if hotkey.actionType == "spell" then
                local spells = tes3.getSpells({ target = tes3.mobilePlayer })
                for __, spell in ipairs(spells) do
                    if(spell.id == hotkey.actionId) then 
                        hotkey.action = spell
                        break
                    end
                end
            end
            if hotkey.actionType == "item" then
                for _,item in tes3.mobilePlayer.inventory do
                    if(item.id == hotkey.actionId) then
                        hotkey.action = item
                    end
                end
            end
        end
    end
    state = _STATE.OPEN
    menu = tes3ui.createMenu({
        id = menuId,
        dragFrame = false,
        fixedFrame = true,
        modal = true,
        loadable = false
    })
    tes3ui.enterMenuMode(menuId)
    renderMenu()
    renderHotkeyField()
end

local function keybindPressed(key)
    for _, hotkey in ipairs(hotkeys) do
        if hotkey.object.keyCode == key.keyCode then
            if hotkey.action.actionType == "spell" then 
                tes3.player.mobile:equipMagic({
                source = hotkey.action
            })
            else 
                tes3.player.mobile:equip({
                    item = hotkey.action
                })
            end
        end
    end
end

local function hotkeyReplacer(e)
    if state == _STATE.NORMAL then
        if not tes3.isKeyEqual({
            expected = combo,
            actual = e
        }) then
            keybindPressed(e)
            return
        end
        openMenu()
        return
    end
    if state == _STATE.OPEN then
        if tes3.isKeyEqual({ expected = combo, actual = e }) then
            closeMenu(e)
        end
    end
    if state == _STATE.LISTENING then
        if not listeningHotkeyIndex then
            return
        end
        listeningKeyPopup:destroy()
        listeningKeyPopup = nil
        local listeningHotkey = hotkeys[listeningHotkeyIndex]
        listeningHotkey.object = e
        listeningHotkey.keyName = getKeybindKey(e.keyCode)
        if listeningHotkey._button then
            listeningHotkey._button.text = listeningHotkey.keyName
        end
        if listeningHotkey._label then
            listeningHotkey._label.text = "Hotkey " .. listeningHotkeyIndex
        end
        state = _STATE.NORMAL
        renderHotkeyField()
        if listeningHotkey.action and listeningHotkey.object then mwse.saveConfig("hotkeyExtender.config", { hotkeys = hotkeys }) end
    end
end

local function initialized()
    
    event.register(tes3.event.keyDown, hotkeyReplacer)
end

event.register(tes3.event.initialized, initialized)
