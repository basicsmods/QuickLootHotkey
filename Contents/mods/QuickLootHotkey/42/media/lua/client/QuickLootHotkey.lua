QuickLootHotkey = QuickLootHotkey or {}

function QuickLootHotkey.GetMousedOverItem(ISInventoryPaneObject)
    if not ISInventoryPaneObject:isReallyVisible() then
		return -- in the main menu
	end
	local item = nil
	if ISInventoryPaneObject.doController and ISInventoryPaneObject.joyselection then
		if ISInventoryPaneObject.joyselection < 0 then ISInventoryPaneObject.joyselection = #ISInventoryPaneObject.items - 1 end
		if ISInventoryPaneObject.joyselection >= #ISInventoryPaneObject.items then ISInventoryPaneObject.joyselection = 0 end
		item = ISInventoryPaneObject.items[ISInventoryPaneObject.joyselection+1]
	end
	if not ISInventoryPaneObject.doController and not ISInventoryPaneObject.dragging and not ISInventoryPaneObject.draggingMarquis and ISInventoryPaneObject:isMouseOver() then
		local x = ISInventoryPaneObject:getMouseX()
		local y = ISInventoryPaneObject:getMouseY()
		if x < ISInventoryPaneObject.column3 and y + ISInventoryPaneObject:getYScroll() >= ISInventoryPaneObject.headerHgt then
			y = y - ISInventoryPaneObject.headerHgt
			y = y / ISInventoryPaneObject.itemHgt
			ISInventoryPaneObject.mouseOverOption = math.floor(y + 1)
			item = ISInventoryPaneObject.items[ISInventoryPaneObject.mouseOverOption]
		end
	end
    return item
end

function QuickLootHotkey.KeyPressed(key)
    --print(key)
    if key == 29 then
        QuickLootHotkey.CtrlPressed = false
    end

    if key ~= 20 then
        return
    end

    local items1 = QuickLootHotkey.GetMousedOverItem(QuickLootHotkey.InventoryPaneObj1)
    local items2 = QuickLootHotkey.GetMousedOverItem(QuickLootHotkey.InventoryPaneObj2)

    if not items1 and not items2 then
        return
    end

    local items = items1
    if not items1 then
        items = items2
    end

    local item
	if items and not instanceof(items, "InventoryItem") then
		item = items.items[1]
    end

    local player = getPlayer()
    local player_num = player:getPlayerNum()

    items = ISInventoryPane.getActualItems({items})
    local playerInv = getPlayer():getInventory()
    local lootInv = getPlayerLoot(player_num).inventory

    if QuickLootHotkey.CtrlPressed then
        items = {item}
    end

    local player = getPlayer()
    local keyRing
    local inventoryItems = player:getInventory():getItems()
    local containers = {}
    for i=0,inventoryItems:size()-1 do
        local item = inventoryItems:get(i)
        if instanceof(item, "InventoryContainer") then
            if not keyRing and item:getType() == "KeyRing" then
                keyRing = item
            else
                if item:isEquipped() then
                    table.insert(containers, item)
                end
            end
        end
    end

    local function compare_containers(containerA, containerB)
        return containerA:getWeightReduction() > containerB:getWeightReduction()
    end

    table.sort(containers, compare_containers)


    if items1 then
        -- item is moving from player
        ISInventoryPaneContextMenu.onMoveItemsTo(items, lootInv, player_num)
    else
        -- item is moving to player
        if isForceDropHeavyItem(items[1]) then
            ISInventoryPaneContextMenu.equipHeavyItem(playerObj, items[1])
            return
        end
        -- for each item, for each container, check if room
        -- fallback to playerinv if necessary
        local containerRemainders = {}
        for i,container in ipairs(containers) do
            table.insert(containerRemainders, i, container:getCapacity() - container:getContentsWeight())
        end
        for i,item in ipairs(items) do
            local foundContainer
            local found = false
            if keyRing and item:getCategory() == "Key" then
                foundContainer = keyRing:getInventory()
                found = true
            end
            if not found then
                for i2,container in ipairs(containers) do
                    if item:getWeight() <= containerRemainders[i2] then
                        foundContainer = container:getInventory()
                        containerRemainders[i2] = containerRemainders[i2] - item:getWeight()
                        found = true
                        break
                    end
                end
            end
            if not found then
                foundContainer = playerInv
            end
            ISTimedActionQueue.add(ISInventoryTransferAction:new(player, item, item:getContainer(), foundContainer))
            --ISInventoryPaneContextMenu.transferItems({item}, foundContainer, player_num)
        end
    end
end

local function KeyStartPressed(key)
    if key == 29 then
        QuickLootHotkey.CtrlPressed = true
    end
end

QuickLootHotkey.updateTooltip = QuickLootHotkey.updateTooltip or ISInventoryPane.updateTooltip


function ISInventoryPane:updateTooltip()
    if not QuickLootHotkey.InventoryPaneObj1 then
        QuickLootHotkey.InventoryPaneObj1 = self
    end
    if not QuickLootHotkey.InventoryPaneObj2 and QuickLootHotkey.InventoryPaneObj1 ~= self then
        QuickLootHotkey.InventoryPaneObj2 = self
    end
    return QuickLootHotkey.updateTooltip(self)
end

Events.OnKeyPressed.Add(QuickLootHotkey.KeyPressed)
Events.OnKeyStartPressed.Add(KeyStartPressed)