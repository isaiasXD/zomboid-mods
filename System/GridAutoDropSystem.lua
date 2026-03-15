local TetrisItemCategory = require("InventoryTetris/Data/TetrisItemCategory")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local ItemUtil = require("Notloc/ItemUtil")

-- Responsible for forcing items out of the player's inventory when it slips into an invalid state
local GridAutoDropSystem = {}

GridAutoDropSystem._dropQueues = {}

function GridAutoDropSystem._processItems(playerNum, items)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:isDead() then return end

    local isDisorganized = playerObj:hasTrait(CharacterTrait.DISORGANIZED)
    local containers = ItemUtil.getAllEquippedContainers(playerObj)
    local mainInv = playerObj:getInventory()

    local gridCache = {}

    for _, item in ipairs(items) do
        local addedToContainer = false

        local currentContainer = item:getContainer()
        if currentContainer then
            local containerGrid = gridCache[currentContainer] or ItemContainerGrid.GetOrCreate(currentContainer, playerNum)
            gridCache[currentContainer] = containerGrid

            if containerGrid:canAddItem(item) and containerGrid:autoPositionItem(item, isDisorganized) then
                addedToContainer = true
            else
                for _, container in ipairs(containers) do
                    local containerGrid = ItemContainerGrid.GetOrCreate(container, playerNum)
                    if currentContainer ~= container and containerGrid:canAddItem(item) and containerGrid:autoPositionItem(item, isDisorganized) then
                        -- CORRECCIÓN B42: Verificación de seguridad antes de transferir
                        if item and container then
                            ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, currentContainer, container))
                            addedToContainer = true
                            break
                        end
                    end
                end
            end
        end

        if not addedToContainer then
            -- CORRECCIÓN B42: Verificación de seguridad antes de soltar al suelo
            if item and currentContainer and mainInv then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, currentContainer, mainInv))
            end
        end
    end
end

function GridAutoDropSystem._isHoldingMoveable(playerObj)
    local primHand = playerObj:getPrimaryHandItem()
    local secHand = playerObj:getSecondaryHandItem()

    if primHand and instanceof(primHand, "Moveable") then return true end
    if secHand and instanceof(secHand, "Moveable") then return true end
    return false
end

function GridAutoDropSystem._equipTemporary(playerObj, item)
    if GridAutoDropSystem._isHoldingMoveable(playerObj) then
        return false
    end

    local primHand = playerObj:getPrimaryHandItem()
    local secHand = playerObj:getSecondaryHandItem()
    local requiresBothHands = item:isRequiresEquippedBothHands()

    if not (primHand and instanceof(primHand, "Moveable")) then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, item, 0, true, requiresBothHands));
        return true
    end

    if not requiresBothHands and not (secHand and instanceof(secHand, "Moveable")) then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, item, 0, false, requiresBothHands));
        return true
    end

    return false
end

function GridAutoDropSystem._processQueues()
    for playerNum, itemSet in pairs(ItemContainerGrid._unpositionedItemSetsByPlayer) do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local actionQueueObj = ISTimedActionQueue.getTimedActionQueue(playerObj)
            
            -- CORRECCIÓN B42: Verificación de existencia de la cola
            local actionQueueIsEmpty = not actionQueueObj or not actionQueueObj.queue or #actionQueueObj.queue == 0
            
            if actionQueueIsEmpty then
                GridAutoDropSystem._dropQueues[playerNum] = itemSet
            end
        end
        ItemContainerGrid._unpositionedItemSetsByPlayer[playerNum] = {}
    end

    for playerNum, itemMap in pairs(GridAutoDropSystem._dropQueues) do
        local itemsToDrop = {}
        for item, _ in pairs(itemMap) do
            table.insert(itemsToDrop, item)
        end

        GridAutoDropSystem._processItems(playerNum, itemsToDrop)
        GridAutoDropSystem._dropQueues[playerNum] = nil
    end
end

Events.OnPlayerUpdate.Add(GridAutoDropSystem._processQueues)

return GridAutoDropSystem