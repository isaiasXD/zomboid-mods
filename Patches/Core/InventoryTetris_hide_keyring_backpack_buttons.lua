---@diagnostic disable: duplicate-set-field

require("ISUI/ISInventoryPage")
require("ISUI/ISInventoryPaneContextMenu")

Events.OnGameBoot.Add(function()

    -- Ensure the keyringList is reset on refresh
    local og_refreshBackpacks = ISInventoryPage.refreshBackpacks
    function ISInventoryPage:refreshBackpacks()
        self.tetrisKeyRings = self.tetrisKeyRings or {}
        table.wipe(self.tetrisKeyRings)
        og_refreshBackpacks(self)
    end

    -- Removes the keyring backpack buttons from the visible backpack buttons in the inventory page
    local og_addContainerButton = ISInventoryPage.addContainerButton
    function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
        local button = og_addContainerButton(self, container, texture, name, tooltip)

        local containingItem = container:getContainingItem()
        
        -- CORRECCIÓN B42: Validación segura del Llavero
        local isKeyRing = false
        if containingItem then
            if containingItem:getType() == "KeyRing" then
                isKeyRing = true
            elseif containingItem.hasTag and containingItem:hasTag("KeyRing") then
                isKeyRing = true
            end
        end

        if (isKeyRing) then
            if self.containerButtonPanel and button then
                self.containerButtonPanel:removeChild(button)
            end
            
            if self.backpacks and #self.backpacks > 0 then
                self.backpacks[#self.backpacks] = nil
            end

            table.insert(self.buttonPool, 1, button)

            self.tetrisKeyRings = self.tetrisKeyRings or {}
            table.insert(self.tetrisKeyRings, container)
        end

        return button;
    end

    -- Inject the keyrings back into the list of containers for context menu operations
    local og_getContainers = ISInventoryPaneContextMenu.getContainers

    ---@param character IsoPlayer
    ---@return ArrayList|nil
    ISInventoryPaneContextMenu.getContainers = function(character)
        local containerList = og_getContainers(character)
        if not containerList then
            return nil
        end

        local playerNum = character:getPlayerNum()
        local playerInv = getPlayerInventory(playerNum)
        if not playerInv then return containerList end
        
        local invPage = playerInv.inventoryPane.inventoryPage
        if not invPage or not invPage.tetrisKeyRings then
            return containerList
        end

        for _, keyRingContainer in ipairs(invPage.tetrisKeyRings) do
            containerList:add(keyRingContainer)
        end

        return containerList
    end
end)