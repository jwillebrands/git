local GIT_LastBoss = {
	--Outlands dungeons.
	--Hellfire Citadel
	["Hellfire Ramparts"] = "Nazan",
	["The Blood Furnace"] = "Keli'dan the Breaker",
	["The Shattered Halls"] = "Warchief Kargath Bladefist",
	
	--Coilfang Reservoir
	["The Slave Pens"] = "Quagmirran",
	["The Underbog"] = "The Black Stalker",
	["The Steamvault"] = "Warlord Kalithresh",	
	
	--Auchindoun
	["Auchenai Crypts"] = "Exarch Maladaar",
	["Mana-Tombs"] = "Nexus-Prince Shaffar",
	["Sethekk Halls"] = "Talon King Ikiss",
	["Shadow Labyrinth"] = "Murmur",
	
	--Caverns of Time
	["Old Hillsbrad Foothills"] = "Epoch Hunter",
	["The Black Morass"] = "Aeonus",
	
	--Tempest Keep
	["The Mechanar"] = "Pathaleon the Calculator",
	["The Botanica"] = "Warp Splinter",
	["The Arcatraz"] = "Harbinger Skyriss",
	
	--Magister's Terrace
	["Magisters' Terrace"] = "Kael'thas Sunstrider",
	
	--10 man Raids
	["Zul'Gurub"] = "Hakkar",
	["Karazhan"] = "Prince Malchezaar",
	["Zul'Aman"] = "Zul'jin",
}
--Create Records table, will be overwritten by SavedVars record table if there is one.
GIT_Records = {}

--Declare some locals we'll need throughout the addon.
local starttime, difficulty

--Create our frame and register the event we're interested in.
local frame = CreateFrame("Frame",nil,UIParent)
frame:RegisterEvent("PLAYER_REGEN_DISABLED")

--Return HH:MM:SS from seconds, rounding up seconds.
local function ReturnHHMMSS(seconds)
	local hh = math.floor(seconds/3600)
	local mm = math.floor((seconds-hh*3600)/60)
	local ss = ceil(seconds-hh*3600-mm*60)
	return string.format("%.2d:%.2d:%.2d",hh, mm, ss)
end

--Fancy prefix and less typing. ^^
local function GIT_Print(msg)
	return DEFAULT_CHAT_FRAME:AddMessage("|cffffff78GIT|r - "..msg)
end

--Function that saves party layout to Saved Var.
local function GIT_SaveParty(zone, difficulty)
	GIT_Records[zone][difficulty]["playername"] = UnitName("player")
	GIT_Records[zone][difficulty]["playerclass"] = UnitClass("player")
	
	--Update party members if grouped.
	if GetNumPartyMembers() > 0 then
		for i=1, GetNumPartyMembers() do
			GIT_Records[zone][difficulty]["party"..i.."name"] = UnitName("party"..i)
			GIT_Records[zone][difficulty]["party"..i.."class"] = UnitClass("party"..i)
		end
	end
end

--Event handler. Simple if-elseif block, no point using fancy tables for just 2 events in my opinion.
local function GIT_OnEvent(event, timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		if (subevent == "UNIT_DIED") then
			local zone = GetRealZoneText()
			--If the unit that died is the last boss of that zone, end the timer 
			if (GIT_LastBoss[zone] == destName) then
				--Work complete. Show time.
				local total = GetTime() - starttime
				starttime = nil
				
				--Done with combat log monitoring, reset to monitoring zone changes.
				frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				
				--Check if new record has been achieved.
				if (not GIT_Records[zone] or type(GIT_Records[zone]) ~= "table" or not GIT_Records[zone][difficulty]) then
					GIT_Print(string.format("New record for %s (%s): %s",zone, difficulty,  ReturnHHMMSS(total)))
					
					--Create table values.
					GIT_Records[zone] = {[difficulty] = {["time"] = total}}
					GIT_SaveParty(zone, difficulty)
				else
					if GIT_Records[zone][difficulty].time > total then
						GIT_Print(string.format("New record for %s (%s): %s! You were %s faster than the previous record!", zone, difficulty, ReturnHHMMSS(total), ReturnHHMMSS(GIT_Records[zone][difficulty].time-total)))
						GIT_Records[zone][difficulty].time = total
						GIT_SaveParty(zone, difficulty)
					else
						GIT_Print(string.format("The old record of %s still stands. It took you %s longer this time.", ReturnHHMMSS(GIT_Records[zone][difficulty].time), ReturnHHMMSS(total-GIT_Records[zone][difficulty].time)))
					end
				end
			end
		end
	elseif (event == "PLAYER_REGEN_DISABLED") then
		--Only continue if starttime = nil (ie. there is no timer running) and current zone is in the LastBoss list.
		if (not starttime and GIT_LastBoss[GetRealZoneText()]) then
			--Set difficulty to current dungeon difficulty. (1. normal, 2. heroic)
			difficulty = (GetCurrentDungeonDifficulty() == 2 and "heroic" or "normal")
			ChatFrame1:AddMessage(difficulty)
			GIT_Print(string.format("Timer for %s (%s) started. Good luck!", GetRealZoneText(), difficulty))
			starttime = GetTime()
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
end
--Set OnEvent handler to call GIT_OnEvent.
frame:SetScript("OnEvent", function(frame, event, ...) GIT_OnEvent(event, ...) end)

--Simple slash handler. Will be improved at some point.
local function GIT_Slash(msg)
	if (not msg or msg=="") then
		GIT_Print("Valid commands for /git are: stop")
	else
		if (msg:lower() == "stop") then
			--Reset starttime, register for zone change event.
			GIT_Print("Timer stopped.")
			starttime = nil
		else
			GIT_Print("Unrecognised command ("..msg.."), valid commands are: stop")
		end
	end
end

--Register slash command.
SlashCmdList["GIT"] = GIT_Slash
SLASH_GIT1 = "/git"