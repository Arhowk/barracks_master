if BuildingEvents == nil then
  BuildingEvents = class({})
end

-- A player picked a hero
function BuildingEvents:OnPlayerPickHero(keys)

  local hero = EntIndexToHScript(keys.heroindex)
  local player = EntIndexToHScript(keys.player)
  local playerID = hero:GetPlayerID()

  -- Initialize Variables for Tracking
  player.units = {} -- This keeps the handle of all the units of the player, to iterate for unlocking upgrades
  player.structures = {} -- This keeps the handle of the constructed units, to iterate for unlocking upgrades
  player.buildings = {} -- This keeps the name and quantity of each building
  player.upgrades = {} -- This kees the name of all the upgrades researched
  player.lumber = 0 -- Secondary resource of the player

  -- Create city center in front of the hero
  local position = hero:GetAbsOrigin() + hero:GetForwardVector() * 300
  local city_center_name = "bm_melee_barracks"
  local building = BuildingHelper:PlaceBuilding(player, city_center_name, position, true, 5) 

  -- Set health to test repair
  building:SetHealth(building:GetMaxHealth()/3)

  -- These are required for repair to know how many resources the building takes
  building.GoldCost = 100
  building.LumberCost = 100
  building.BuildTime = 15

  -- Add the building to the player structures list
  player.buildings[city_center_name] = 1
  table.insert(player.structures, building)

  CheckAbilityRequirements( hero, player )
  CheckAbilityRequirements( building, player )

  -- Add the hero to the player units list
  table.insert(player.units, hero)
  hero.state = "idle" --Builder state

  --[[
  -- Spawn some peasants around the hero
  local position = hero:GetAbsOrigin()
  local numBuilders = 5
  local angle = 360/numBuilders
  for i=1,5 do
    local rotate_pos = position + Vector(1,0,0) * 100
    local builder_pos = RotatePosition(position, QAngle(0, angle*i, 0), rotate_pos)

    local builder = CreateUnitByName("peasant", builder_pos, true, hero, hero, hero:GetTeamNumber())
    builder:SetOwner(hero)
    builder:SetControllableByPlayer(playerID, true)
    table.insert(player.units, builder)
    builder.state = "idle"

    -- Go through the abilities and upgrade
    CheckAbilityRequirements( builder, player )
  end
  ]]

  -- Give Initial Resources
  hero:SetGold(5000, false)
  ModifyLumber(player, 5000)

  -- Lumber tick
  Timers:CreateTimer(1, function()
    ModifyLumber(player, 10)
    return 10
  end)

  -----------------------
  -- Give item to hero --
  -----------------------
  hero:AddItemByName("item_travel_boots")
  hero:AddItemByName("item_boar")
  hero:AddItemByName("item_techies")  
  hero:AddItemByName("item_blink")

  -- Give a building ability
  -- Legacy: local item = CreateItem("item_build_wall", hero, hero)
  -- Legacy: hero:AddItem(item)

  -- Learn all abilities (this isn't necessary on creatures)
  for i=0,15 do
    local ability = hero:GetAbilityByIndex(i)
    if ability then ability:SetLevel(ability:GetMaxLevel()) end
  end
  hero:SetAbilityPoints(0)

end

-- An entity died
function BuildingEvents:OnEntityKilled( event )

  -- The Unit that was Killed
  local killedUnit = EntIndexToHScript(event.entindex_killed)
  -- The Killing entity
  local killerEntity
  if event.entindex_attacker then
    killerEntity = EntIndexToHScript(event.entindex_attacker)
  end

  -- Player owner of the unit
  local player = killedUnit:GetPlayerOwner()

  -- Building Killed
  if IsCustomBuilding(killedUnit) then

     -- Building Helper grid cleanup
    BuildingHelper:RemoveBuilding(killedUnit, true)

    -- Check units for downgrades
    local building_name = killedUnit:GetUnitName()
        
    -- Substract 1 to the player building tracking table for that name
    if player.buildings[building_name] then
      player.buildings[building_name] = player.buildings[building_name] - 1
    end

    -- possible unit downgrades
    for k,units in pairs(player.units) do
        CheckAbilityRequirements( units, player )
    end

    -- possible structure downgrades
    for k,structure in pairs(player.structures) do
      CheckAbilityRequirements( structure, player )
    end
  end

  -- Cancel queue of a builder when killed
  if IsBuilder(killedUnit) then
    BuildingHelper:ClearQueue(killedUnit)
  end

  -- Table cleanup
  if player then
    -- Remake the tables
    local table_structures = {}
    for _,building in pairs(player.structures) do
      if building and IsValidEntity(building) and building:IsAlive() then
        --print("Valid building: "..building:GetUnitName())
        table.insert(table_structures, building)
      end
    end
    player.structures = table_structures
    
    local table_units = {}
    for _,unit in pairs(player.units) do
      if unit and IsValidEntity(unit) then
        table.insert(table_units, unit)
      end
    end
    player.units = table_units    
  end
end

-- Called whenever a player changes its current selection, it keeps a list of entity indexes
function BuildingEvents:OnPlayerSelectedEntities( event )
  local pID = event.pID

  GameRules.SELECTED_UNITS[pID] = event.selected_entities

  -- This is for Building Helper to know which is the currently active builder
  local mainSelected = GetMainSelectedEntity(pID)
  if IsValidEntity(mainSelected) and IsBuilder(mainSelected) then
    local player = PlayerResource:GetPlayer(pID)
    player.activeBuilder = mainSelected
  end
end