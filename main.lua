local Draft = RegisterMod("draftmode",1)
local json = require("json")

--configurable data

local settings = {
	enabled = true,
	disableAU = false,
	numItems = 4,
	minQuality = 0,
	maxQuality = 4,
	activesAllowed = true,
	pools = { 
		{pool=ItemPoolType.POOL_TREASURE,label="Treasure Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_SHOP,label="Shop Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_BOSS,label="Boss Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_DEVIL,label="Devil Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_ANGEL,label="Angel Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_CURSE,label="Curse Room Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_LIBRARY,label="Library Item Pool",enabled=true,default="on"},
		{pool=ItemPoolType.POOL_SECRET,label="Secret Item Pool",enabled=true,default="on"}
	}, 
	currentPool = 3, --default:boss
	removeBoss = true,
	removeTreasure = false,
	removeShop = false,
	removeChest = false,
	removeLibrary = false,
	removePlanetarium = false,
	ignoreChaos = false,
	pullDuplicates = false,
	optionsDisappear = true,
	cutOffStage = 8, --womb II
	preset=0, --0 = default, -1 = custom
	version=5.0
}

--further configurable data initialization

if REPENTANCE then --additional config for repentance owners
	--pools
	table.insert(settings.pools, {pool=ItemPoolType.POOL_ULTRA_SECRET,label="Ultra Secret Item Pool",enabled=false,default="off"})
	table.insert(settings.pools, {pool=ItemPoolType.POOL_PLANETARIUM,label="Planetarium Item Pool",enabled=false,default="off"})
	table.insert(settings.pools, {pool=ItemPoolType.POOL_BOMB_BUM,label="Bomb (Bum) Item Pool",enabled=false,default="off"})
	table.insert(settings.pools, {pool=ItemPoolType.POOL_BABY_SHOP,label="Familiar (Baby Shop) Item Pool",enabled=false,default="off"})
end

table.insert(settings.pools, {pool='irandom',label="Random Individual Item Pool",enabled=null})
table.insert(settings.pools, {pool='orandom',label="Random Overall Item Pool",enabled=null})
table.insert(settings.pools, {pool='universal',label="Universal Item Pool",enabled=null})
table.insert(settings.pools, {pool='trandom',label="True Random",enabled=null})

--adjustable data

local randomPool = math.random(#settings.pools)
local loaded = false
local debugged = false
local generated = false
local cleaned=false
local cleanedBR=false
local cleanedTR=false
local floorXL=false
local tkeeper=false
local cleanedXL=0
local numPlayers

local looping = false
local loopCounter = 0

local spawnedItems = {}
local eligibleItems = {}

--fixed data
local bools = {false,true}

local presets = {[-1]="Custom",[0]="Default","Easy","Hard","Randomizer"}

local stages = {"Basement I", "Basement II", "Caves I", "Caves II", "Depths I", "Depths II", "Womb I", "Womb II"}
local types = {"","a","b","c","d"}
local questItems = {CollectibleType.COLLECTIBLE_POLAROID,CollectibleType.COLLECTIBLE_NEGATIVE,CollectibleType.COLLECTIBLE_KEY_PIECE_1,CollectibleType.COLLECTIBLE_KEY_PIECE_2,CollectibleType.COLLECTIBLE_BROKEN_SHOVEL_2,CollectibleType.COLLECTIBLE_MOMS_SHOVEL}
local rerollDice = {CollectibleType.COLLECTIBLE_D6,CollectibleType.COLLECTIBLE_D100}
local rerollCards = {Card.RUNE_PERTHRO}

if REPENTANCE then
	table.insert(questItems,CollectibleType.COLLECTIBLE_BROKEN_SHOVEL_1)
	table.insert(questItems,CollectibleType.COLLECTIBLE_DADS_NOTE)	
	table.insert(questItems,CollectibleType.COLLECTIBLE_DOGMA)	
	table.insert(questItems,CollectibleType.COLLECTIBLE_KNIFE_PIECE_1)	
	table.insert(questItems,CollectibleType.COLLECTIBLE_KNIFE_PIECE_2)	

	table.insert(rerollDice,CollectibleType.COLLECTIBLE_ETERNAL_D6)
	table.insert(rerollDice,CollectibleType.COLLECTIBLE_D_INFINITY)

	table.insert(rerollCards,Card.CARD_SOUL_EDEN)
end

--helper functions

function table.length(table)
	local i=0
	for _,v in pairs(table) do
		if v~=nil then
			i=i+1
		end
	end
	return i
end

function table.find(table,val)
	for _,v in pairs(table) do
		if type(v)==type(val) then
			if v==val then
				return true
			end
		end
	end
	return false
end

function table.foundat(table,val)
	for k,v in pairs(table) do
		if type(v)==type(val) then
			if v==val then
				return k
			end
		end
	end
	return nil
end

function table.empty(table)
	for k,v in pairs(table) do
		if v~=nil then
			return false
		end
	end
	return true
end

--[[function table.print(table)
	for k,v in pairs(table) do
		print("["..tostring(table).."] Key: "..k.." = "..v)
	end
	print("Table Length: "..#table)
end]]

function bool(boolean)
	if boolean then
		return 'On'
	end
	return 'Off'
end

function boolalt(boolean)
	if boolean then
		return 'Included'
	end
	return 'Not Included'
end

--draft specific helper functions

function display()
	local curTable = settings.pools[settings.currentPool]
	local toDisplay = curTable.label
	return toDisplay
end

function checkx(num,i)	
	local factor = (560/(num+1))
	return ((factor*i)+40)
end 

function checky(p)	
	local factor = ((640/5)+40*p)
	return factor
end 

function misc()
	local x = settings.pools[math.random(#settings.pools)]
	repeat x = settings.pools[math.random(#settings.pools)] until x.enabled
	return x
end

function tkDetect()
	for i=0,Game():GetNumPlayers()-1,1 do
		if Isaac.GetPlayer(i):GetPlayerType()==PlayerType.PLAYER_KEEPER_B then 
			return true 
		end
	end
	return false
end

function realNumPlayers()
	local fNum = Game():GetNumPlayers()
	local CIs = {}
	for i=0,fNum-1 do
		local pci = Isaac.GetPlayer(i).ControllerIndex
		if pci and not table.find(CIs,pci) then
			table.insert(CIs,pci)
		end
	end
	return table.length(CIs)
end

function checkForDupes(item)
	for i=0,(numPlayers-1),1 do
		if Game():GetPlayer(i):HasCollectible(item,true) then
			return true
		end
		if REPENTANCE then
			for x=0,ActiveSlot.SLOT_POCKET2 do
				if (Game():GetPlayer(i):GetActiveItem(x)) == item then
					return true
				end
			end
		end
	end
	return table.find(spawnedItems,item)
end

function eligibleUpdate()
	local tlost=false
	if REPENTANCE then
		for i=0,(numPlayers-1),1 do
			if Isaac.GetPlayer(i):GetPlayerType()==PlayerType.PLAYER_THELOST_B then
				tlost=true
			end
		end
	end

	local config=Isaac.GetItemConfig()
	eligibleItems={}
	for i=1,config:GetCollectibles().Size-1,1 do
		if config:GetCollectible(i)~=nil then
			local itemToCheck = config:GetCollectible(i)
			if 
			((settings.activesAllowed) or (not settings.activesAllowed and itemToCheck.Type~=ItemType.ITEM_ACTIVE)) 
			and (not checkForDupes(i) or settings.pullDuplicates) 
			and not table.find(questItems,i) 
			and (i~=CollectibleType.COLLECTIBLE_THERES_OPTIONS or not settings.removeBoss) 
			and (i~=CollectibleType.COLLECTIBLE_MORE_OPTIONS or not settings.removeTreasure)
			and itemToCheck.Type~=(ItemType.ITEM_NULL or ItemType.ITEM_TRINKET)
			then
				if REPENTANCE then
					if (itemToCheck.Quality<=settings.maxQuality and itemToCheck.Quality>=settings.minQuality) then
						table.insert(eligibleItems,i)
						for y=0,(numPlayers-1),1 do
							if Game():GetPlayer(y):HasCollectible(CollectibleType.COLLECTIBLE_SACRED_ORB,true) then
								if (itemToCheck.Quality<2) then
									table.remove(eligibleItems,table.foundat(eligibleItems,i))
								end
								if (itemToCheck.Quality==2) then
									if math.random(0,100)<=33 then
										table.remove(eligibleItems,table.foundat(eligibleItems,i))
									end
								end
							end
						end
						if (settings.minQuality>1 and i==CollectibleType.COLLECTIBLE_SACRED_ORB and settings.removeBoss and settings.removeTreasure) then
							table.remove(eligibleItems,table.foundat(eligibleItems,i))
						end
						if tlost and itemToCheck.Quality<2 then
							if math.random(0,100)<=20 then
								table.remove(eligibleItems,table.foundat(eligibleItems,i))
							end
						end
					end
				else
					table.insert(eligibleItems,i)
				end
				if (settings.ignoreChaos and i==CollectibleType.COLLECTIBLE_CHAOS) then
					table.remove(eligibleItems,table.foundat(eligibleItems,i))
				end
			end
		end
	end
end

function interpret()
	local game = Game()
	local level = game:GetLevel()
  	local seed = level:GetCurrentRoom():GetAwardSeed() + (realNumPlayers()-1)
	local ItemPool = game:GetItemPool()
	local curTable = settings.pools[settings.currentPool]
	local actualPool = curTable.pool

	if not looping then
		loopCounter=0
	else
		loopCounter=loopCounter+1
	end

	--check for chaos
	for i=0,(numPlayers-1),1 do
		if game:GetPlayer(i):HasCollectible(CollectibleType.COLLECTIBLE_CHAOS,true) and not settings.ignoreChaos then
			return 0
		elseif game:GetPlayer(i):HasCollectible(CollectibleType.COLLECTIBLE_CHAOS,true) and settings.ignoreChaos then
			game:GetPlayer(i):RemoveCollectible(CollectibleType.COLLECTIBLE_CHAOS,true)
		end
	end

	eligibleUpdate()

	if type(actualPool)=='number' then
		local itemGen =  ItemPool:GetCollectible(actualPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
		ItemPool:AddRoomBlacklist(itemGen)
		if (table.find(eligibleItems,itemGen)) and table.length(eligibleItems)>0 then
			table.insert(spawnedItems,itemGen)
			table.remove(eligibleItems,table.foundat(eligibleItems,itemGen))
			looping=false
			return itemGen
		elseif table.length(eligibleItems)>0 and loopCounter<200 then
			looping=true
			return interpret()
		else
			looping=false
			return ItemPool:GetCollectible(actualPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
		end
	elseif type(actualPool)=='string' then
		if actualPool=='universal' then
			if table.length(eligibleItems)>0 then
				local itemGen = eligibleItems[math.random(#eligibleItems)]
				ItemPool:AddRoomBlacklist(itemGen)
				table.insert(spawnedItems,itemGen)
				table.remove(eligibleItems,table.foundat(eligibleItems,itemGen))
				return itemGen
			else
				return CollectibleType.COLLECTIBLE_NULL
			end
		elseif actualPool=='irandom' then
			local randomPool = misc().pool
			local itemGen = ItemPool:GetCollectible(randomPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
			ItemPool:AddRoomBlacklist(itemGen)
			if (table.find(eligibleItems,itemGen)) and table.length(eligibleItems)>0 then
				table.insert(spawnedItems,itemGen)
				table.remove(eligibleItems,table.foundat(eligibleItems,itemGen))
				looping=false
				return itemGen
			elseif table.length(eligibleItems)>0 and loopCounter<math.floor((Isaac.GetItemConfig():GetCollectibles().Size-1)/3) then
				looping=true
				return interpret()
			else
				looping=false
				return ItemPool:GetCollectible(randomPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
			end
		elseif actualPool=='orandom' then
			local curTable = settings.pools[randomPool]
			local actualPool = curTable.pool
			local itemGen = ItemPool:GetCollectible(actualPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
			ItemPool:AddRoomBlacklist(itemGen)
			if (table.find(eligibleItems,itemGen)) and table.length(eligibleItems)>0 then
				table.insert(spawnedItems,itemGen)
				table.remove(eligibleItems,table.foundat(eligibleItems,itemGen))
				looping=false
				return itemGen
			elseif table.length(eligibleItems)>0 and loopCounter<math.floor((Isaac.GetItemConfig():GetCollectibles().Size-1)/3) then
				looping=true
				return interpret()
			else
				looping=false
				return ItemPool:GetCollectible(actualPool, false, seed, CollectibleType.COLLECTIBLE_NULL)
			end
		else
			return CollectibleType.COLLECTIBLE_NULL
		end
	else
		return CollectibleType.COLLECTIBLE_NULL
	end

end 

function cleanRoom(rt, setting)
	if not Game():IsGreedMode() and setting and settings.enabled and Game():GetLevel():GetAbsoluteStage() < settings.cutOffStage then
  		local room = Game():GetRoom()
		local slots = {DoorSlot.LEFT0, DoorSlot.LEFT1, DoorSlot.UP0, DoorSlot.UP1, DoorSlot.RIGHT0, DoorSlot.RIGHT1, DoorSlot.DOWN0, DoorSlot.DOWN1}
		if room:GetType()~=rt then
			for _,doorSlot in pairs(slots) do
				local door = room:GetDoor(doorSlot)
				if door~=nil then
					if door:IsRoomType(rt) then
						door:Close(true)
						door:SetLocked(true)
						door:Bar()
						room:RemoveDoor(doorSlot)
					end
				end
			end
		else
		    for i, entity in pairs(Isaac.GetRoomEntities()) do
		      if entity.Variant == 100 then
		        entity:Remove()
		      end
		    end
		    if REPENTANCE then
		    	Isaac.GetPlayer(0):UsePill(PillEffect.PILLEFFECT_TELEPILLS, PillColor.PILL_NULL,UseFlag.USE_NOANIM)
		    end
		end
	end

end

--this is made by pedroff_1
if not ModCallbacks.MC_POST_ITEM_PICKUP and not REPENTANCE then
  
  local Mod = RegisterMod("Post Item Pickup Callback",1)
  
  function PostItemPickup (_,player)
    local itemqueue = player.QueuedItem
    if itemqueue and itemqueue.Item then
      local list = PostItemPickupFunctions
      if list[itemqueue.Item.ID] then
        for i,v in pairs(list[itemqueue.Item.ID]) do
          v(_,player)
        end
      end
      list = PostItemPickupFunctions[-1]
      if list then
        for i,v in pairs(list) do
          v(_,player,itemqueue.Item.ID)
        end
      end
      player:FlushQueueItem()
      
    end
    
  end

  Mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, PostItemPickup)
  local addCallbackOld = Isaac.AddCallback
  ModCallbacks.MC_POST_ITEM_PICKUP = 271
  
  PostItemPickupFunctions = PostItemPickupFunctions or {}
  
  
  function  addCallbackNew(mod,callback,func,arg1,arg2,arg3,arg4)
    if callback == ModCallbacks.MC_POST_ITEM_PICKUP then
      arg1 = arg1 or -1
      PostItemPickupFunctions[arg1] = PostItemPickupFunctions[arg1] or {}
      PostItemPickupFunctions[arg1][tostring(func)]= func
    else
      addCallbackOld(mod,callback,func,arg1,arg2,arg3,arg4)
    end

  end
  Isaac.AddCallback = addCallbackNew
  
end
--back to mine

function Draft:Load()
	if Draft:HasData() and not loaded then
		local data = json.decode(Draft:LoadData())
		if data and data.version==settings.version then
			settings=data
		end
	end

	if ModConfigMenu and not loaded then
		local cat="General"
		ModConfigMenu.AddSpace("Draft Mode",cat)

		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.enabled end,
			Display = function() return "Enable Draft Mode: "..bool(settings.enabled) end,
			OnChange = function()
				settings.preset=-1
				settings.enabled = not settings.enabled
			end,
			Info = {
				"Whether or not draft mode is active. \n(default: on)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.disableAU end,
			Display = function() return "Disable Achievements/Unlocks: "..bool(settings.disableAU) end,
			OnChange = function()
				settings.preset=-1
				settings.disableAU = not settings.disableAU
			end,
			Info = {
				"Whether or not achievements and unlocks are disabled. \n(default: off)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function() return settings.currentPool end,
			Display = function() return "Current Pool: "..display() end,
			Minimum = 1,
			Maximum = #settings.pools,
			OnChange = function(currentNum)
				settings.preset=-1
				settings.currentPool = currentNum
			end,
			Info = {
				"The currently selected item pool from which items are randomly pulled from for the draft. \n(default: Boss Item Pool)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function() return settings.numItems end,
			Display = function() return "Number of Items: "..settings.numItems end,
			Minimum = 0,
			OnChange = function(currentNum)
				settings.preset=-1
				settings.numItems = currentNum
			end,
			Info = {
				[[How many item choices should you have? 
				(default: 4)
				*Try not to go over 20!!*]]
			}
		})

		if REPENTANCE then
			ModConfigMenu.AddSetting("Draft Mode", cat, { 
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function() return settings["minQuality"] end,
				Display = function() return "Minimum Quality: "..settings["minQuality"] end,
				Minimum = 0,
				Maximum = 4,
				OnChange = function(currentNum)
					settings.preset=-1
					if currentNum>settings["maxQuality"] then
						currentNum=settings["maxQuality"]
					end
					settings["minQuality"] = currentNum
				end,
				Info = {
					"The minimum quality for items being drafted. \n(default: 0)"
				}
			})
			ModConfigMenu.AddSetting("Draft Mode", cat, { 
				Type = ModConfigMenu.OptionType.NUMBER,
				CurrentSetting = function() return settings["maxQuality"] end,
				Display = function() return "Maximum Quality: "..settings["maxQuality"] end,
				Minimum = 0,
				Maximum = 4,
				OnChange = function(currentNum)
					settings.preset=-1
					if currentNum<settings["minQuality"] then
						currentNum=settings["minQuality"]
					end
					settings["maxQuality"] = currentNum
				end,
				Info = {
					"The maximum quality for items being drafted. \n(default: 4)"
				}
			})

		end

		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.activesAllowed end,
			Display = function() return "Draft Active Items: "..bool(settings.activesAllowed) end,
			OnChange = function()
				settings.preset=-1
				settings.activesAllowed = not settings.activesAllowed
			end,
			Info = {
				"Whether or not active items can be drafted. \n(default: on)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.pullDuplicates end,
			Display = function() return "Draft Duplicates: "..bool(settings.pullDuplicates) end,
			OnChange = function()
				settings.preset=-1
				settings.pullDuplicates = not settings.pullDuplicates
			end,
			Info = {
				"Whether or not items in the player's inventory can be drafted. \n(default: off)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.ignoreChaos end,
			Display = function() return "Ignore Chaos: "..bool(settings.ignoreChaos) end,
			OnChange = function()
				settings.preset=-1
				settings.ignoreChaos = not settings.ignoreChaos
			end,
			Info = {
				"Whether or not Chaos is ignored. \n(default: off)"
			}
		})
		if REPENTANCE then
			ModConfigMenu.AddSetting("Draft Mode", cat, { 
				Type = ModConfigMenu.OptionType.BOOLEAN,
				CurrentSetting = function() return settings.optionsDisappear end,
				Display = function() return "Item Choices Disappear: "..bool(settings.optionsDisappear) end,
				OnChange = function()
					settings.preset=-1
					settings.optionsDisappear = not settings.optionsDisappear
				end,
				Info = {
					"Whether or not other item choices disappear after picking one. \n(default: on)"
				}
			})
		end
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.removeBoss end,
			Display = function() return "Disable Boss Rewards: "..bool(settings.removeBoss) end,
			OnChange = function()
				settings.preset=-1
				settings.removeBoss = not settings.removeBoss
			end,
			Info = {
				"Whether or not item rewards for defeating the boss don't drop. \n(default: on)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.removeTreasure end,
			Display = function() return "Disable Treasure Rooms: "..bool(settings.removeTreasure) end,
			OnChange = function()
				settings.preset=-1
				settings.removeTreasure = not settings.removeTreasure
			end,
			Info = {
				"Whether or not treasure rooms and their rewards appear. \n(default: off)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.removeShop end,
			Display = function() return "Disable Shop Rooms: "..bool(settings.removeShop) end,
			OnChange = function()
				settings.preset=-1
				settings.removeShop = not settings.removeShop
			end,
			Info = {
				"Whether or not shop rooms and their rewards appear. \n(default: off)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.removeChest end,
			Display = function() return "Disable Chest Rooms: "..bool(settings.removeChest) end,
			OnChange = function()
				settings.preset=-1
				settings.removeChest = not settings.removeChest
			end,
			Info = {
				"Whether or not chest rooms and their rewards appear. \n(default: off)"
			}
		})
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.BOOLEAN,
			CurrentSetting = function() return settings.removeLibrary end,
			Display = function() return "Disable Library Rooms: "..bool(settings.removeLibrary) end,
			OnChange = function()
				settings.preset=-1
				settings.removeLibrary = not settings.removeLibrary
			end,
			Info = {
				"Whether or not library rooms and their rewards appear. \n(default: off)"
			}
		})
		if REPENTANCE then
			ModConfigMenu.AddSetting("Draft Mode", cat, { 
				Type = ModConfigMenu.OptionType.BOOLEAN,
				CurrentSetting = function() return settings.removePlanetarium end,
				Display = function() return "Disable Planetarium Rooms: "..bool(settings.removePlanetarium) end,
				OnChange = function()
					settings.preset=-1
					settings.removePlanetarium = not settings.removePlanetarium
				end,
				Info = {
					"Whether or not planetarium rooms and their rewards appear. \n(default: off)"
				}
			})
		end
		ModConfigMenu.AddSetting("Draft Mode", cat, { 
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function() return settings.cutOffStage end,
			Display = function() return "Cut Off Stage: "..stages[settings.cutOffStage] end,
			Minimum = 1,
			Maximum = #stages,
			OnChange = function(currentNum)
				settings.preset=-1
				settings.cutOffStage = currentNum
			end,
			Info = {
				"The stage at which draft mode turns off and normal gameplay resumes. \n(default: Womb II)"
			}
		})

		for _,v in pairs(settings.pools) do
			if v.enabled~=null then
				ModConfigMenu.AddSetting("Draft Mode", "R. Pools", { 
					Type = ModConfigMenu.OptionType.BOOLEAN,
					CurrentSetting = function() return v.enabled end,
					Display = function() return v.label..": "..boolalt(v.enabled) end,
					OnChange = function()
						v.enabled = not v.enabled
					end,
					Info = {
						"Whether or not "..v.label.." is included in random pool drawing. ".." \n(default: "..v.default..")"
					}
				})
			end
		end

		ModConfigMenu.AddSetting("Draft Mode", "Extra", { 
			Type = ModConfigMenu.OptionType.NUMBER,
			CurrentSetting = function() return settings.preset end,
			Display = function() return "Preset: "..presets[settings.preset] end,
			Minimum = 0,
			Maximum = (#presets),
			OnChange = function(currentNum)
				settings.preset=currentNum
				if(settings.preset==0) then --default
					settings.disableAU = false
					settings.numItems = 4
					settings.minQuality = 0
					settings.maxQuality = 4
					settings.activesAllowed = true
					settings.currentPool = 3
					settings.removeBoss = true
					settings.removeTreasure = false
					settings.removeShop = false
					settings.removeChest = false
					settings.removeLibrary = false
					settings.removePlanetarium = false
					settings.ignoreChaos = false
					settings.pullDuplicates = false
					settings.optionsDisappear=true
					settings.cutOffStage = 8
				end
				if(settings.preset==1) then --easy
					settings.disableAU = false
					settings.numItems = 8
					settings.minQuality = 0
					settings.maxQuality = 4
					settings.activesAllowed = true
					settings.currentPool = (#settings.pools-1)
					settings.removeBoss = true
					settings.removeTreasure = false
					settings.removeShop = false
					settings.removeChest = false
					settings.removeLibrary = false
					settings.removePlanetarium = false
					settings.ignoreChaos = false
					settings.pullDuplicates = false
					settings.optionsDisappear=true
					settings.cutOffStage = 8
				end
				if(settings.preset==2) then --hard
					settings.disableAU = false
					settings.numItems = 3
					settings.minQuality = 0
					settings.maxQuality = 4
					settings.activesAllowed = true
					settings.currentPool = 3
					settings.removeBoss = true
					settings.removeTreasure = true
					settings.removeShop = false
					settings.removeChest = false
					settings.removeLibrary = false
					settings.removePlanetarium = true
					settings.ignoreChaos = false
					settings.pullDuplicates = false
					settings.optionsDisappear=true
					settings.cutOffStage = 8
				end
				if(settings.preset==3) then --randomizer
					settings.numItems = math.random(1,20)
					settings.minQuality = math.random(0,4)
					settings.maxQuality = math.random(settings.minQuality,4)
					settings.activesAllowed = bools[math.random(#bools)]
					settings.currentPool = math.random(#settings.pools)
					settings.removeBoss = bools[math.random(#bools)]
					settings.removeTreasure = bools[math.random(#bools)]
					settings.removeShop = bools[math.random(#bools)]
					settings.removeChest = bools[math.random(#bools)]
					settings.removeLibrary = bools[math.random(#bools)]
					settings.removePlanetarium = bools[math.random(#bools)]
					settings.ignoreChaos = bools[math.random(#bools)]
					settings.pullDuplicates = bools[math.random(#bools)]
					settings.cutOffStage = math.random(1,8)
				end
			end,
			Info = {
				"Current active configuration preset. Information on each one can be found in the workshop page's discussions."
			}
		})

		ModConfigMenu.AddSetting("Draft Mode", "Extra", { 
			Type = ModConfigMenu.OptionType.TEXT,
			CurrentSetting = function() return settings.version end,
			Display = function() return "Version: "..settings.version end,
			Info = {
				"Current Version of the mod. Use this to identify when an update is pushed so you aren't confused when your config resets."
			}
		})
	end
	loaded=true
end

function Draft:Save()
	Draft:SaveData(json.encode(settings))
end

function Draft:Game(iscontinued) --credit to tem for reference
	if settings.disableAU and not iscontinued then
		if not Options.DebugConsoleEnabled then
			Options.DebugConsoleEnabled=true
			debugged=true
		end
		Isaac.ExecuteCommand("seed "..Game():GetSeeds():GetStartSeedString())
	elseif not settings.disableAU and debugged and Options.DebugConsoleEnabled then
		debugged=false
		Options.DebugConsoleEnabled=false
	end
end

function Draft:Spawn()
  	local level = Game():GetLevel()

	if not Game():IsGreedMode() and settings.enabled and level:GetAbsoluteStage() < settings.cutOffStage and settings.numItems>0 then
		generated=false

		tkeeper=tkDetect()

		numPlayers = realNumPlayers()

		math.randomseed(level:GetCurrentRoom():GetAwardSeed())
		repeat randomPool=math.random(#settings.pools) until (settings.pools[randomPool].enabled)
		cleaned = false
		cleanedBR = false
		cleanedTR = false
		cleanedXL = 0
		spawnedItems = {}

		if REPENTANCE then
			if (level:IsAscent()) then 
				return 
		 	end --dad's note
		end

		if level:CanStageHaveCurseOfLabyrinth(level:GetStage()) and level:GetCurses()>0  then
			if tostring(level:GetCurseName())=="Curse of the Labyrinth!" then
				floorXL=true
			else
				floorXL=false
		end
		else	
			floorXL=false
		end

		if level:GetAbsoluteStage()==1 then
			local shift=0
			for p=0,Game():GetNumPlayers()-1,1 do
				Game():GetPlayer(p).Position=Vector(320,280+shift)
				shift=shift+1
			end
		end

		local index=1
		for y = 1,realNumPlayers(),1 do
			index=index+1
			for i=1,settings.numItems do
				local item = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, interpret(), Vector(checkx(settings.numItems,i),checky(y)+5), Vector(0,0), nil)

				if REPENTANCE then
					if settings.optionsDisappear then
						item:ToPickup().OptionsPickupIndex=1+index
					end
					if tkeeper then
						item:ToPickup().ShopItemId = -1
						item:ToPickup().Price = 15
					end
				end

				if floorXL then
				    local itemXL = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, interpret(), Vector(checkx(settings.numItems,i),555-checky(y)), Vector(0,0), nil)

				    if REPENTANCE then
						if settings.optionsDisappear then
							itemXL:ToPickup().OptionsPickupIndex=10+index
						end
						if tkeeper then
							itemXL:ToPickup().ShopItemId = -1
							itemXL:ToPickup().Price = 15
						end
				  	end
				end
			end
		end
		Game():GetItemPool():ResetRoomBlacklist()
		generated=true
	end
end

--ab
function Draft:Update()
	if Game():IsGreedMode()~=true and settings.enabled and settings.optionsDisappear then
	  local game = Game()
	  local level = game:GetLevel()

	  cleanedXL=cleanedXL+1
	  if level:GetCurrentRoomIndex() == 84 and level:GetAbsoluteStage() <= settings.cutOffStage and not cleaned and not floorXL then
	    for i, entity in pairs(Isaac.GetRoomEntities()) do
	      if entity.Variant == 100 then
	        entity:Remove()
	      end
	    end
	   cleaned=true
	  end

	  if level:GetCurrentRoomIndex() == 84 and level:GetAbsoluteStage() <= settings.cutOffStage and cleanedXL == 2 and floorXL then
	    for i, entity in pairs(Isaac.GetRoomEntities()) do
	      if entity.Variant == 100 then
	        entity:Remove()
	      end
	    end
	    cleanedXL=cleanedXL+1
	  end
	end
end

--not just ab
function Draft:mapUpdate()
	if (not Game():IsGreedMode()) and settings.enabled and Game():GetLevel():GetAbsoluteStage() < settings.cutOffStage then
		local game = Game()
		local level = game:GetLevel()
		local rooms = level:GetRooms()

		for i=1,rooms:__len() do
			local room = rooms:Get(i)
			if room then
				if 
				(room.Data.Type==RoomType.ROOM_TREASURE and settings.removeTreasure) or
				(room.Data.Type==RoomType.ROOM_SHOP and settings.removeShop) or
				(room.Data.Type==RoomType.ROOM_CHEST and settings.removeChest) or
				(room.Data.Type==RoomType.ROOM_LIBRARY and settings.removeLibrary) or
				(REPENTANCE and room.Data.Type==(24 or RoomType.ROOM_PLANETARIUM) and settings.removePlanetarium)
				then
					if room.DisplayFlags and not MinimapAPI then
						if room.DisplayFlags ~= (1 << -1) then
							room.DisplayFlags = (1 << -1)
						end
					end
					if MinimapAPI then
						MinimapAPI:RemoveRoom(MinimapAPI:GridIndexToVector(room.GridIndex))
					end
				end
			end
		end
	end
end

function Draft:CleanRooms()
	cleanRoom(RoomType.ROOM_TREASURE,settings.removeTreasure)
	cleanRoom(RoomType.ROOM_SHOP,settings.removeShop)
	cleanRoom(RoomType.ROOM_CHEST,settings.removeChest)
	cleanRoom(RoomType.ROOM_LIBRARY,settings.removeLibrary)
	if REPENTANCE then
		cleanRoom(RoomType.ROOM_PLANETARIUM,settings.removePlanetarium)
	end
end

function Draft:CleanBoss()
	if Game():IsGreedMode()~=true and settings.enabled and settings.removeBoss then
		local game = Game()
		local level = game:GetLevel()
		if not floorXL then--not xl
		  if level:GetCurrentRoom():GetType() == 5 and level:GetAbsoluteStage() ~= 6  and not cleanedBR and level:GetAbsoluteStage() < settings.cutOffStage then
		    for i, entity in pairs(Isaac.GetRoomEntities()) do
		      if entity.Variant == 100 and not table.find(questItems,entity.SubType) then
		        entity:Remove()
		        cleanedBR=true
		      end
		    end
		  end
		else--xl
		  if level:GetCurrentRoom():GetType() == 5 and level:GetAbsoluteStage() ~= 6 and level:GetAbsoluteStage() < settings.cutOffStage then
		    for i, entity in pairs(Isaac.GetRoomEntities()) do
		      if entity.Variant == 100 and not table.find(questItems,entity.SubType) then
		        entity:Remove()
		      end
		    end
		  end
		end
	end
end

function Draft:iReroll(item)
	local game = Game()
	local level = game:GetLevel()
	
	if level:GetCurrentRoomIndex()==84 and level:GetAbsoluteStage()<settings.cutOffStage and settings.enabled and generated and not game:IsGreedMode() and table.find(rerollDice,item) then	
	    tkeeper=tkDetect()
	    for k, entity in pairs(Isaac.GetRoomEntities()) do
	      if entity.Variant == 100 then
		    if (Isaac.GetItemConfig()):GetCollectible(entity.SubType).Type~=(ItemType.ITEM_TRINKET or ItemType.ITEM_NULL) then
		    	local pos = entity.Position
		    	local opi=nil
			    if REPENTANCE then
		    		opi = entity:ToPickup().OptionsPickupIndex
		    	end
			  	entity:Remove()
		    	local item = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, interpret(), pos, Vector(0,0), nil)
			    if REPENTANCE then
			    	if settings.optionsDisappear then
			    		item:ToPickup().OptionsPickupIndex=opi
			    	end
					if tkeeper then
						item:ToPickup().ShopItemId = -1
						item:ToPickup().Price = 15
					end
			  	end
		    end
	      end
	    end
		return true
	end
end

function Draft:cReroll(player,IH,BA)
	local game = Game()
	local level = game:GetLevel()
	
	if player and player:ToPlayer() then
		if player:ToPlayer():GetMainTwin()==player:ToPlayer():GetPlayerType() and level:GetCurrentRoomIndex()==84 and level:GetAbsoluteStage()<settings.cutOffStage and settings.enabled and generated and not game:IsGreedMode() and IH==InputHook.IS_ACTION_PRESSED and BA==ButtonAction.ACTION_PILLCARD and table.find(rerollCards,player:GetCard(0)) then
		    tkeeper=tkDetect()
		    for k, entity in pairs(Isaac.GetRoomEntities()) do
		      if entity.Variant == 100 then
			    if (Isaac.GetItemConfig()):GetCollectible(entity.SubType).Type~=(ItemType.ITEM_TRINKET or ItemType.ITEM_NULL) then
			    	local pos = entity.Position
			    	local opi=nil
				    if REPENTANCE then
			    		opi = entity:ToPickup().OptionsPickupIndex
			    	end
				  	entity:Remove()
			    	local item = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, interpret(), pos, Vector(0,0), nil)
				    if REPENTANCE then
				    	if settings.optionsDisappear then
				    		item:ToPickup().OptionsPickupIndex=opi
				    	end
						if tkeeper then
							item:ToPickup().ShopItemId = -1
							item:ToPickup().Price = 15
						end
				  	end
			    end
		      end
		    end
		    return false
		end
	end
end

function Draft:PlayerUpdate()
	local game = Game()
	local level = game:GetLevel()
	local stage = level:GetStage()
	local stype = level:GetStageType()

	local curNumPlayers = realNumPlayers()

	if level:GetCurrentRoomIndex()==84 and level:GetCurrentRoom():IsFirstVisit() and level:GetAbsoluteStage()<settings.cutOffStage and settings.enabled and generated and not game:IsGreedMode() then
		if curNumPlayers~=numPlayers then
			if floorXL then
			 	Isaac.ExecuteCommand("curse "..2)
			end
			  	Isaac.ExecuteCommand("stage "..stage..types[stype+1])
		  	if floorXL then
		  		Isaac.ExecuteCommand("curse "..0)
		  	end
		end
	end
end

Draft:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, Draft.Load)
Draft:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,Draft.Spawn)
Draft:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Draft.CleanRooms)
Draft:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Draft.CleanRooms)

if not REPENTANCE then
	Draft:AddCallback(ModCallbacks.MC_POST_ITEM_PICKUP, Draft.Update)
end

Draft:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, Draft.CleanBoss)

Draft:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, Draft.iReroll)
Draft:AddCallback(ModCallbacks.MC_INPUT_ACTION, Draft.cReroll)

Draft:AddCallback(ModCallbacks.MC_POST_UPDATE, Draft.PlayerUpdate)
Draft:AddCallback(ModCallbacks.MC_POST_UPDATE, Draft.mapUpdate)

Draft:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Draft.Game)

Draft:AddCallback(ModCallbacks.MC_POST_GAME_END, Draft.Save)
Draft:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Draft.Save)