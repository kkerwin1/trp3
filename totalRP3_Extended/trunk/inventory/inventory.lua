----------------------------------------------------------------------------------
-- Total RP 3: Inventory system
--	---------------------------------------------------------------------------
--	Copyright 2015 Sylvain Cossement (telkostrasz@totalrp3.info)
--
--	Licensed under the Apache License, Version 2.0 (the "License");
--	you may not use this file except in compliance with the License.
--	You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
--	Unless required by applicable law or agreed to in writing, software
--	distributed under the License is distributed on an "AS IS" BASIS,
--	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--	See the License for the specific language governing permissions and
--	limitations under the License.
----------------------------------------------------------------------------------
local Globals, Events, Utils = TRP3_API.globals, TRP3_API.events, TRP3_API.utils;
local _G, assert, tostring, tinsert, wipe, pairs = _G, assert, tostring, tinsert, wipe, pairs;
local getItemClass, isContainerByClassID = TRP3_API.inventory.getItemClass, TRP3_API.inventory.isContainerByClassID;
local isContainerByClass, getItemTextLine = TRP3_API.inventory.isContainerByClass, TRP3_API.inventory.getItemTextLine;

local EMPTY = {};

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- INVENTORY MANAGEMENT API
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local playerInventory;
local CONTAINER_SLOT_MAX = 1000;

--- Add an item to a container.
-- Returns:
-- 0 if OK
-- 1 if container full
-- 2 if too many item already possessed (unique)
function TRP3_API.inventory.addItem(container, itemID, itemData)
	-- Checking data
	local container = container or playerInventory;
	assert(isContainerByClassID(container.id), "Is not a container ! ID: " .. tostring(container.id));
	local itemClass = getItemClass(itemID);
	assert(itemClass, "Unknown item class: " .. tostring(itemID));
	if not container.content then
		container.content = {};
	end
	itemData = itemData or EMPTY;

	-- Finding an empty slot
	local slot = itemData.containerSlot;
	if not slot then
		for i = 1, CONTAINER_SLOT_MAX do
			if not container.content[tostring(i)] then
				slot = tostring(i);
				break;
			end
		end
	end
	if not slot then
		-- Container is full
		return 1;
	end

	-- Adding item instance
	if container.content[slot] then
		assert(container.content[slot].id == itemID, ("Mismatch itemID in slot %s: %s vs %s"):format(slot, container.content[slot].id, itemID));
		container.content[slot].count = container.content[slot].count + (itemData.count or 1);
	else
		container.content[slot] = {
			id = itemID,
			count = itemData.count or 1,
			instanceId = Utils.str.id(),
		};
	end

	return 0;
end

function TRP3_API.inventory.getItem(container, slotID)
	-- Checking data
	local container = container or playerInventory;
	assert(isContainerByClassID(container.id), "Is not a container ! ID: " .. tostring(container.id));
	if not container.content then
		container.content = {};
	end

	return container.content[slotID];
end

local function swapContainersSlots(container1, slot1, container2, slot2)

end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Target bar button
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local displayDropDown = TRP3_API.ui.listbox.displayDropDown;

local playerInvText = ("%s's inventory"):format(Globals.player);
local PLAYER_INV_BUTTON_MAX_ENTRIES = 10;

local function playerInventoryButtonSelection(selectedSlot)
	if selectedSlot == 0 then
		message("Opening all inventory");
	elseif playerInventory.content[selectedSlot] then -- Check again, as maybe the slot was deleted
		local classID = playerInventory.content[selectedSlot].id;
		local class = getItemClass(classID);
		if isContainerByClass(class) then
			TRP3_API.inventory.switchContainerBySlotID(playerInventory, selectedSlot);
		else
			message("Using item");
		end
	end
end

local dropdownItems = {};
local function playerInventoryButtonClick(button)
	wipe(dropdownItems);
	tinsert(dropdownItems,{playerInvText, nil});
	tinsert(dropdownItems,{"Show all inventory", 0}); -- TODO: locals
	local i = 1;
	local found = 0;
	while i <= CONTAINER_SLOT_MAX and found <= PLAYER_INV_BUTTON_MAX_ENTRIES do
		local slot = tostring(i);
		if playerInventory.content[slot] then
			local classID = playerInventory.content[slot].id;
			local class = getItemClass(classID);
			tinsert(dropdownItems,{getItemTextLine(class), slot});
			found = found + 1;
		end
		i = i + 1;
	end
	displayDropDown(button, dropdownItems, playerInventoryButtonSelection, 0, true);
end

local function initPlayerInventoryButton()
	if TRP3_API.target then
		TRP3_API.target.registerButton({
			id = "aa_player_d_inventory",
			onlyForType = TRP3_API.ui.misc.TYPE_CHARACTER,
			configText = playerInvText,
			condition = function(targetType, unitID)
				return unitID == Globals.player_id;
			end,
			onClick = function(unitID, _, _, button)
				playerInventoryButtonClick(button);
			end,
			tooltip = playerInvText,
			tooltipSub = "Click: Show content", -- TODO: locals
			icon = "inv_misc_bag_16"
		});
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- INIT
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function initPlayerInventory()
	-- Structures
	local playerProfile = TRP3_API.profile.getPlayerCurrentProfile();
	if not playerProfile.inventory then
		playerProfile.inventory = {};
	end
	playerInventory = playerProfile.inventory;
	playerInventory.id = "main";
	if not playerInventory.content then
		playerInventory.content = {};
	end

	TRP3_API.inventory.EVENT_ON_SLOT_USE = "EVENT_ON_SLOT_USE";
	TRP3_API.inventory.EVENT_ON_SLOT_SWAP = "EVENT_ON_SLOT_SWAP";
	TRP3_API.events.registerEvent(TRP3_API.inventory.EVENT_ON_SLOT_USE);
	TRP3_API.events.registerEvent(TRP3_API.inventory.EVENT_ON_SLOT_SWAP);
	TRP3_API.events.listenToEvent(TRP3_API.inventory.EVENT_ON_SLOT_SWAP, swapContainersSlots);

	-- UI
	TRP3_API.events.listenToEvent(TRP3_API.events.WORKFLOW_ON_LOADED, function()
		initPlayerInventoryButton();
	end);
end

local function onStart()
	initPlayerInventory();
end

local MODULE_STRUCTURE = {
	["name"] = "Inventory",
	["description"] = "Inventory system for characters and companions",
	["version"] = 1.000,
	["id"] = "trp3_inventory",
	["onStart"] = onStart,
	["minVersion"] = 12,
};

TRP3_API.module.registerModule(MODULE_STRUCTURE);