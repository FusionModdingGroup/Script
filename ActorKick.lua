-- Functions defining what happens when player is (very) close to an enemy.
--
-- player : CPlayerPuppetEntity
-- actor  : CLeggedPuppetEntity
-- event  : CGlobalScriptAnimEvent
--

worldGlobals.A_WALKERBLUE_KICKMOD      = "Piercing";
worldGlobals.A_WALKERBLUE_KICKSTRENGTH = 200/5;
worldGlobals.A_WALKERRED_KICKMOD       = "Piercing";
worldGlobals.A_WALKERRED_KICKSTRENGTH  = 200;
worldGlobals.A_KHNUM_KICKMOD           = "Piercing";
worldGlobals.A_KHNUM_KICKSTRENGTH      = 200;
worldGlobals.A_GNAAR_KICKMOD           = "Piercing";
worldGlobals.A_GNAAR_KICKSTRENGTH      = 50;
worldGlobals.GameOverTrampoline        = function(player, inflictor, damageamount)
  local random = mthRndF();
  
  if (random > 0.5)
  then
    local placementplayer = player:GetPlacement();
    local placementinflictor = inflictor:GetPlacement();
    local inflictorheight    = inflictor:GetBoundingBoxSize().y*1.0;
    
    placementplayer:SetVect(mthVector3f(placementplayer.vx, placementinflictor.vy+inflictorheight, placementplayer.vz));
    player:SetPlacement(placementplayer);
  end
  
  return true;
end;

local interpolate_linear = function(a, b, t)
  return (1+(a-t)/(b-a));
end

local Gnaar_kick = function(x, n)
  local distance_close = 0.5;
  local distance_far   = 3.00;
  local damage_max     = worldGlobals.A_GNAAR_KICKSTRENGTH;
  
  -- 'n' defines how many gnaars are in "CloseEnough" range.
  if     (n < 5)  then return 0, "Any";                                                                                        -- [ 0, 5)
  elseif (n < 10) then return interpolate_linear(distance_close, distance_far, x)*damage_max/5, worldGlobals.A_GNAAR_KICKMOD;  -- [ 5, 10)
  else                 return damage_max, worldGlobals.A_GNAAR_KICKMOD; end                                                    -- [10, +inf)
end

local WalkerBlue_kick = function(x, n)
  local distance_close = 1.00;
  local distance_far   = 2.75;
  local damage_max     = worldGlobals.A_WALKERBLUE_KICKSTRENGTH;

  if     (x < distance_close) then return damage_max, worldGlobals.A_WALKERBLUE_KICKMOD;
  elseif (x > distance_far)   then return 0, "Any";
  else                             return interpolate_linear(distance_close, distance_far, x)*damage_max, worldGlobals.A_WALKERBLUE_KICKMOD; end
end

local WalkerRed_kick = function(x, n)
  local distance_close = 2.00;
  local distance_far   = 4.50;
  local damage_max     = worldGlobals.A_WALKERRED_KICKSTRENGTH;

  if     (x < distance_close) then return damage_max, worldGlobals.A_WALKERRED_KICKMOD;
  elseif (x > distance_far)   then return 0, "Any";
  else                             return interpolate_linear(distance_close, distance_far, x)*damage_max, worldGlobals.A_WALKERRED_KICKMOD; end
end

local Khnum_kick = function(x, n)
  return worldGlobals.A_KHNUM_KICKSTRENGTH, worldGlobals.A_KHNUM_KICKMOD;
end

--
-- actorname            : Name of the actor that is kicking.
-- boneattachmentsource : String distance calculation from this attachment.
-- closeenough          : Float distance from which "kick" function will be called (anything less than).
-- KickFunction(x, n)   : Function returning damage amount and damage type to be dealt (if actor is in closeenough range).
--                        x - distance to this specific character in range (on XZ plane, height is ignored).
--                        n - total amount of same type of actors in range.
--
-- Calculate the distance to every actor that is of opposite alignment or neutral.
-- Pass the distance to KickFunction, deal damage if damage is greater than 0.
-- KickFunction should return 0 if the actor cannot be hurt with the given distance.
--
-- actoralllist  : CPuppetEntity
-- actorkicklist : CPuppetEntity
-- nearby        : CPuppetEntity
-- target        : CPuppetEntity
-- worldInfo     : CWorldInfoEntity
--

local function Kick(actor, boneattachmentsource, closeenough, KickFunction)
  local worldInfo = worldGlobals.worldInfo;
  local actorlist = worldInfo:GetAllEntitiesOfClass("CPuppetEntity");
  local i, j;
  
  for i = 1, #actorlist
  do
    local target = actorlist[i];
    local targetheight    = target:GetBoundingBoxSize().y;
    local inflictorheight = actor:GetBoundingBoxSize().y;
    local targetsmall     = (inflictorheight*(1.0/2.0) > targetheight);
    
    --print(tostring(actor:GetName()) .. " > " .. target:GetName() .. " -> " .. tostring(inflictorheight) .. " .. " .. tostring(targetheight) .. " :: " .. tostring(targetsmall));
    
    if (targetheight >= 0 and (targetsmall or actor:GetAlignment() ~= target:GetAlignment() or target:GetAlignment() == "Neutral"))
    then
      local nearby  = worldInfo:GetCharacters(actor:GetCharacterClass(), actor:GetAlignment(), target, closeenough);
      local a       = actorlist[i]:GetPlacement();
      local b       = actor:GetAttachmentAbsolutePlacement(boneattachmentsource);
      local d       = mthSqrtF((a.vx-b.vx)*(a.vx-b.vx) + (a.vz-b.vz)*(a.vz-b.vz) + (a.vy-b.vy)*(a.vy-b.vy));
      local damage_amount, damage_type = KickFunction(d, nearby);
    
      --print(":: " .. actor:GetName() .. " (class: " .. actor:GetCharacterClass() .. ") is kicking " .. target:GetName() .. "! Distance: " .. tostring(d) .. ". Damage = " .. tostring(damage_amount) .. ". Number of same nearby actors: " .. tostring(#actorlist));
      if (damage_amount > 0) then
        local dodamage = true;
        
        if (actorlist[i]:GetClassName() == "CPlayerPuppetEntity")
        then
          local player = target;
          
          if (player:GetHealth() - damage_amount <= 0 and not player:UsesGodCheat())
          then          
            dodamage = worldGlobals.GameOverTrampoline(player, actor, damage_amount)
          end
        end
        if (dodamage)
        then
          actor:InflictDamageToTarget(target, damage_amount, 0, damage_type);
        end        
      end      
    end
  end
end

RunAsync(
  function()
    RunHandled(
      WaitForever,
      OnEvery(CustomEvent("Gnaar_Nearby")),      function(event) Kick(event:GetEventThrower(), "Eye",        5, Gnaar_kick);      end,
      OnEvery(CustomEvent("Khnum_WalkL")),       function(event) Kick(event:GetEventThrower(), "L_Foot",     7, Khnum_kick);      end,
      OnEvery(CustomEvent("Khnum_WalkR")),       function(event) Kick(event:GetEventThrower(), "R_Foot",     7, Khnum_kick);      end,
      OnEvery(CustomEvent("WalkerBlue_StompL")), function(event) Kick(event:GetEventThrower(), "Step_L",     5, WalkerBlue_kick); end,
      OnEvery(CustomEvent("WalkerBlue_StompR")), function(event) Kick(event:GetEventThrower(), "Step_R",     5, WalkerBlue_kick); end,
      OnEvery(CustomEvent("WalkerBlue_Crash")),  function(event) Kick(event:GetEventThrower(), "Walker_COG", 6, WalkerBlue_kick); end,
      OnEvery(CustomEvent("WalkerRed_StompL")),  function(event) Kick(event:GetEventThrower(), "L_Foot",     6, WalkerRed_kick);  end,
      OnEvery(CustomEvent("WalkerRed_StompR")),  function(event) Kick(event:GetEventThrower(), "R_Foot",     6, WalkerRed_kick);  end,
      OnEvery(CustomEvent("WalkerRed_Crash")),   function(event) Kick(event:GetEventThrower(), "Walker_COG", 6, WalkerRed_kick);  end
    );
  end
);
