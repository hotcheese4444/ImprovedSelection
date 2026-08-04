ReUI.Require
{
    "ReUI.Core >= 1.1.0",
    "ReUI.Actions >= 1.2.0",
    "ReUI.LINQ >= 1.1.0",
    "ReUI.Units >= 1.0.0",
}

function Main(isReplay)
    local CategoryMatcher = ReUI.Actions.CategoryMatcher
    local CategoryAction  = ReUI.Actions.CategoryAction
    local Misc            = import("/lua/keymap/misckeyactions.lua")
    local Beep            = Sound { Cue = 'UI_Camera_Save_Position', Bank = 'Interface', }
    local Boop            = Sound { Cue = 'UI_Camera_Recall_Position', Bank = 'Interface', }

    -- ================================================================
    -- CUSTOM SELECTION TABLES
    -- Keys are entity ID strings, values are unit objects.
    -- Stores units added via custom hotkeys.
    -- ================================================================
    local customMmlSniper = {}
    local customDirectFire = {}
    local customLandAA = {}
    local customShieldsDeceivers = {}
    local customDirectFireExperimental = {}

    local customGroups = {
        mmlSniper = customMmlSniper,
        directFire = customDirectFire,
        landAA = customLandAA,
        shieldsDeceivers = customShieldsDeceivers,
        directFireExperimental = customDirectFireExperimental,
    }

    -- ================================================================
    -- HELPERS
    -- ================================================================

    local function GetEntityId(unit)
        local ok, eid = pcall(function() return unit:GetEntityId() end)
        if ok then return eid end
        return nil
    end

    -- A custom assignment takes priority over category matching. This lets a
    -- unit be moved into one selection group without appearing in the others.
    local function IsAssignedToAnotherGroup(eid, groupName)
        for name, group in customGroups do
            if name ~= groupName and group[eid] then
                return true
            end
        end
        return false
    end

    -- FAF exposes control groups as selection sets on each unit.
    local function IsInControlGroup(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, selectionSets = pcall(function() return unit:GetSelectionSets() end)
        return ok and selectionSets ~= nil and next(selectionSets) ~= nil
    end

    local function IsLand(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        return cats ~= nil
            and cats['MOBILE'] ~= nil
            and cats['LAND'] ~= nil
    end

    local function AddSelectedToGroup(groupName)
        local sel = GetSelectedUnits()
        if not sel then return end

        local targetGroup = customGroups[groupName]
        for _, unit in sel do
            if IsLand(unit) then
                local eid = GetEntityId(unit)
                if eid then
                    -- Remove this unit from every group first, so custom groups
                    -- remain mutually exclusive.
                    for _, group in customGroups do
                        group[eid] = nil
                    end
                    targetGroup[eid] = unit
                end
            end
            PlaySound(Beep)
        end
        --uncomment this line if you want to clear the selection after adding to a group
        --SelectUnits({})
    end

    local function IsUnitOnScreen(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, pos = pcall(function() return unit:GetPosition() end)
        if not ok or not pos then return false end

        local worldview = import('/lua/ui/game/worldview.lua').viewLeft
        if not worldview then return false end

        local okProj, screenPos = pcall(function() return worldview:Project(pos) end)
        if not okProj or not screenPos then return false end

        local left = worldview.Left()
        local right = worldview.Right()
        local top = worldview.Top()
        local bottom = worldview.Bottom()

        local x = screenPos.x or screenPos[1]
        local y = screenPos.y or screenPos[2]

        if x and y and x >= left and x <= right and y >= top and y <= bottom then
            return true
        end
        return false
    end

    -- ================================================================
    -- CATEGORY FILTERS
    -- ================================================================

    -- MML / Sniper: (MOBILE * SILO * BUILTBYTIER3FACTORY * LAND) + SNIPER
    local function IsMmlSniper(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        if not cats then return false end

        local isMml = cats['MOBILE'] ~= nil
            and cats['SILO'] ~= nil
            and cats['BUILTBYTIER3FACTORY'] ~= nil
            and cats['LAND'] ~= nil

        local isSniper = cats['SNIPER'] ~= nil

        return isMml or isSniper
    end

    -- Direct Fire: MOBILE * LAND * DIRECTFIRE * BUILTBYTIER3FACTORY - ENGINEER - SNIPER
    local function IsDirectFire(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        if not cats then return false end

        return cats['MOBILE'] ~= nil
            and cats['LAND'] ~= nil
            and cats['DIRECTFIRE'] ~= nil
            and cats['BUILTBYTIER3FACTORY'] ~= nil
            and cats['ENGINEER'] == nil
            and cats['SNIPER'] == nil
    end

    -- Land AA: MOBILE * LAND * ANTIAIR - DIRECTFIRE - ENGINEER
    local function IsLandAA(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        if not cats then return false end

        return cats['MOBILE'] ~= nil
            and cats['LAND'] ~= nil
            and cats['ANTIAIR'] ~= nil
            and cats['DIRECTFIRE'] == nil
            and cats['ENGINEER'] == nil
    end

    -- Shields / Deceivers: (BUILTBYTIER3FACTORY * STEALTHFIELD * MOBILE - EXPERIMENTAL) + (MOBILE * SHIELD * BUILTBYTIER3FACTORY * LAND - DIRECTFIRE)
    local function IsShieldsDeceivers(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        if not cats then return false end

        local isStealth = cats['BUILTBYTIER3FACTORY'] ~= nil
            and cats['STEALTHFIELD'] ~= nil
            and cats['MOBILE'] ~= nil
            and cats['EXPERIMENTAL'] == nil

        local isShield = cats['MOBILE'] ~= nil
            and cats['SHIELD'] ~= nil
            and cats['BUILTBYTIER3FACTORY'] ~= nil
            and cats['LAND'] ~= nil
            and cats['DIRECTFIRE'] == nil

        return isStealth or isShield
    end

    -- Direct Fire Experimental: MOBILE * LAND * EXPERIMENTAL * DIRECTFIRE - SNIPER - ARTILLERY
    local function IsDirectFireExperimental(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        if not cats then return false end

        return cats['MOBILE'] ~= nil
            and cats['LAND'] ~= nil
            and cats['EXPERIMENTAL'] ~= nil
            and cats['DIRECTFIRE'] ~= nil
            and cats['SNIPER'] == nil
            and cats['ARTILLERY'] == nil
    end

    -- ================================================================
    -- ADD TO CUSTOM BINDINGS FUNCTIONS
    -- ================================================================

    local function AddToMmlSniper(_sel)
        AddSelectedToGroup('mmlSniper')
    end

    local function AddToDirectFire(_sel)
        AddSelectedToGroup('directFire')
    end

    local function AddToLandAA(_sel)
        AddSelectedToGroup('landAA')
    end

    local function AddToShieldsDeceivers(_sel)
        AddSelectedToGroup('shieldsDeceivers')
    end

    local function AddToDirectFireExperimental(_sel)
        AddSelectedToGroup('directFireExperimental')
    end

    local function RemoveSelectedFromAllGroups(_sel)
        local sel = GetSelectedUnits()
        if not sel then return end
        PlaySound(Boop)
        for _, unit in sel do
            local eid = GetEntityId(unit)
            if eid then
                for _, group in customGroups do
                    group[eid] = nil
                end
            end
        end
    end

    -- ================================================================
    -- SELECT FUNCTIONS
    -- ================================================================

    local function SelectMmlSniper(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        local selectedIds = {}

        local function AddToSelect(unit)
            local eid = GetEntityId(unit)
            if eid and not selectedIds[eid] and not IsInControlGroup(unit) then
                selectedIds[eid] = true
                table.insert(toSelect, unit)
            end
        end

        -- 1. Default matching units that are onscreen
        for _, unit in allUnits do
            local eid = GetEntityId(unit)
            if IsMmlSniper(unit) and eid and not IsAssignedToAnotherGroup(eid, 'mmlSniper') and IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        -- 2. Custom bound units that are onscreen and alive
        for eid, unit in customMmlSniper do
            if IsDestroyed(unit) then
                customMmlSniper[eid] = nil
            elseif IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        else
            SelectUnits({})
        end
    end

    local function SelectDirectFire(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        local selectedIds = {}

        local function AddToSelect(unit)
            local eid = GetEntityId(unit)
            if eid and not selectedIds[eid] and not IsInControlGroup(unit) then
                selectedIds[eid] = true
                table.insert(toSelect, unit)
            end
        end

        -- 1. Default matching units that are onscreen
        for _, unit in allUnits do
            local eid = GetEntityId(unit)
            if IsDirectFire(unit) and eid and not IsAssignedToAnotherGroup(eid, 'directFire') and IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        -- 2. Custom bound units that are onscreen and alive
        for eid, unit in customDirectFire do
            if IsDestroyed(unit) then
                customDirectFire[eid] = nil
            elseif IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        else
            SelectUnits({})
        end
    end

    local function SelectLandAA(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        local selectedIds = {}

        local function AddToSelect(unit)
            local eid = GetEntityId(unit)
            if eid and not selectedIds[eid] and not IsInControlGroup(unit) then
                selectedIds[eid] = true
                table.insert(toSelect, unit)
            end
        end

        -- 1. Default matching units that are onscreen
        for _, unit in allUnits do
            local eid = GetEntityId(unit)
            if IsLandAA(unit) and eid and not IsAssignedToAnotherGroup(eid, 'landAA') and IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        -- 2. Custom bound units that are onscreen and alive
        for eid, unit in customLandAA do
            if IsDestroyed(unit) then
                customLandAA[eid] = nil
            elseif IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        else
            SelectUnits({})
        end
    end

    local function SelectShieldsDeceivers(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        local selectedIds = {}

        local function AddToSelect(unit)
            local eid = GetEntityId(unit)
            if eid and not selectedIds[eid] and not IsInControlGroup(unit) then
                selectedIds[eid] = true
                table.insert(toSelect, unit)
            end
        end

        -- 1. Default matching units that are onscreen
        for _, unit in allUnits do
            local eid = GetEntityId(unit)
            if IsShieldsDeceivers(unit) and eid and not IsAssignedToAnotherGroup(eid, 'shieldsDeceivers') and
                IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        -- 2. Custom bound units that are onscreen and alive
        for eid, unit in customShieldsDeceivers do
            if IsDestroyed(unit) then
                customShieldsDeceivers[eid] = nil
            elseif IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        else
            SelectUnits({})
        end
    end

    local function SelectDirectFireExperimental(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        local selectedIds = {}

        local function AddToSelect(unit)
            local eid = GetEntityId(unit)
            if eid and not selectedIds[eid] and not IsInControlGroup(unit) then
                selectedIds[eid] = true
                table.insert(toSelect, unit)
            end
        end

        -- 1. Default matching units that are onscreen
        for _, unit in allUnits do
            local eid = GetEntityId(unit)
            if IsDirectFireExperimental(unit) and eid
                and not IsAssignedToAnotherGroup(eid, 'directFireExperimental')
                and IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        -- 2. Custom bound units that are onscreen and alive
        for eid, unit in customDirectFireExperimental do
            if IsDestroyed(unit) then
                customDirectFireExperimental[eid] = nil
            elseif IsUnitOnScreen(unit) then
                AddToSelect(unit)
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        else
            SelectUnits({})
        end
    end

    -- ================================================================
    -- REGISTER HOTKEYS
    -- ================================================================
    ReUI.Actions.SelectionAction("Select all onscreen mml/sniper", SelectMmlSniper, "Improved Selection")
    ReUI.Actions.SelectionAction("Select all onscreen directfire", SelectDirectFire, "Improved Selection")
    ReUI.Actions.SelectionAction("Select all onscreen land AA", SelectLandAA, "Improved Selection")
    ReUI.Actions.SelectionAction("Select all onscreen shields/deceivers", SelectShieldsDeceivers,
        "Improved Selection")

    ReUI.Actions.SelectionAction("Add selected units to MML/Sniper selection", AddToMmlSniper, "Improved Selection")
    ReUI.Actions.SelectionAction("Add selected units to Direct Fire selection", AddToDirectFire,
        "Improved Selection")
    ReUI.Actions.SelectionAction("Add selected units to Land AA selection", AddToLandAA, "Improved Selection")
    ReUI.Actions.SelectionAction("Add selected units to Shields/Deceivers selection", AddToShieldsDeceivers,
        "Improved Selection")
    ReUI.Actions.SelectionAction("Add selected units to Direct Fire Experimental selection",
        AddToDirectFireExperimental, "Improved Selection")

    -- Select All Direct Fire Land Experimentals / Interrupt Pathfinding
    -- When engineers are selected: aborts their navigation.
    -- Otherwise: selects all onscreen MOBILE LAND EXPERIMENTAL DIRECTFIRE units.
    -- :Modifiers { shift = true } means the action also fires when Shift is held.
    CategoryMatcher "Select All Direct Fire Land Experimentals/Interrupt Pathfinding"
        :Modifiers { shift = true }
        {
            CategoryAction(categories.ENGINEER - categories.COMMAND)
                :Action(function() Misc.AbortNavigation() end),
            CategoryAction()
                :Match(function(selection, category) return true end)
                :Action(function() SelectDirectFireExperimental() end),
        }
    local pinned = {}

    -- ================================================================
    -- HELPERS
    -- ================================================================

    local function IsFighter(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        -- Pure air-superiority units only:
        --   T1 Interceptors, Aeon T2 Combat Fighter (XAA0202), T3 ASFs.
        -- The BOMBER exclusion drops the T2 Fighter/Bombers
        -- (DEA0202, DRA0202, XSA0202, XNA0202), which also carry
        -- ANTIAIR + HIGHALTAIR but are dual-role ground attackers.
        -- The Aeon Combat Fighter has no BOMBER category, so it stays.
        return cats ~= nil
            and cats['HIGHALTAIR'] ~= nil
            and cats['ANTIAIR'] ~= nil
            and cats['BOMBER'] == nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsBomber(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        return cats ~= nil
            and cats['BOMBER'] ~= nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsGunship(unit)
        if unit == nil or IsDestroyed(unit) then return false end
        local ok, bp = pcall(function() return unit:GetBlueprint() end)
        if not ok or not bp then return false end
        local cats = bp.CategoriesHash
        return cats ~= nil
            and cats['GROUNDATTACK'] ~= nil
            and cats['BOMBER'] == nil
            and cats['EXPERIMENTAL'] == nil
    end

    local function IsAirCombatUnit(unit)
        return IsFighter(unit) or IsBomber(unit) or IsGunship(unit)
    end

    local function GetEntityId(unit)
        local ok, eid = pcall(function() return unit:GetEntityId() end)
        if ok then return eid end
        return nil
    end

    -- ================================================================
    -- SELECT FIGHTERS
    -- Selects all own fighters that are not currently pinned out.
    --
    -- Note: this reads ReUI's cached unit list, which can lag by a few
    -- seconds for units that were just share-transferred from an ally.
    -- An attempt to bypass the cache with engine-native
    -- UISelectionByCategory was tried and failed silently in this
    -- context, so we stay with the cached path.
    -- ================================================================
    local function SelectFighters(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsFighter(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end

        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    local function SelectBombers(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsBomber(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end
        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    local function SelectGunships(_sel)
        local ok, allUnits = pcall(function()
            return ReUI.Units.Get(categories.ALLUNITS)
        end)
        if not ok or not allUnits then return end

        local toSelect = {}
        for _, unit in allUnits do
            if IsGunship(unit) then
                local eid = GetEntityId(unit)
                if eid and not pinned[eid] then
                    table.insert(toSelect, unit)
                end
            end
        end
        if table.getn(toSelect) > 0 then
            SelectUnits(toSelect)
        end
    end

    -- ================================================================
    -- TOGGLE PIN
    -- Looks at all selected fighters, gunships, and bombers.
    -- If ANY of them are pinned -> unpin ALL of them.
    -- If NONE are pinned       -> pin ALL of them.
    -- Non-air-combat units in the selection are ignored.
    -- ================================================================
    local function TogglePin(_sel)
        RemoveSelectedFromAllGroups(_sel) -- Clear any custom group assignments first, so they don't interfere with pinning.
        local sel = GetSelectedUnits()
        if not sel then return end

        -- Collect selected air combat units only
        local airCombatUnits = {}
        for _, unit in sel do
            if IsAirCombatUnit(unit) then
                table.insert(airCombatUnits, unit)
            end
        end

        if table.getn(airCombatUnits) == 0 then return end

        -- Check if any selected air combat unit is currently pinned
        local anyPinned = false
        for _, unit in airCombatUnits do
            local eid = GetEntityId(unit)
            if eid and pinned[eid] then
                anyPinned = true
                break
            end
        end

        -- If any were pinned: unpin all. Otherwise: pin all.
        for _, unit in airCombatUnits do
            local eid = GetEntityId(unit)
            if eid then
                if anyPinned then
                    pinned[eid] = nil
                else
                    pinned[eid] = true
                end
            end
            PlaySound(Boop)
        end
    end

    -- ================================================================
    -- REGISTER HOTKEYS
    -- ================================================================
    ReUI.Actions.SelectionAction("Select Fighters", SelectFighters, "Improved Selection")
    ReUI.Actions.SelectionAction("Select Bombers", SelectBombers, "Improved Selection")
    ReUI.Actions.SelectionAction("Select Gunships", SelectGunships, "Improved Selection")
    ReUI.Actions.SelectionAction("Toggle Air Combat from Selection/Remove selected units from group", TogglePin,
        "Improved Selection")


end
