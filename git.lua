local GIT_LastBoss = {
	["Terokkar Forest"] = "Dampscale Basilisk",
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
GIT_Records = {}
local starttime
local frame = CreateFrame("Frame",nil,UIParent)

local function ReturnHHMMSS(seconds)
	local hh = math.floor(seconds/3600)
	local mm = math.floor((seconds-hh*3600)/60)
	local ss = ceil(seconds-hh*3600-mm*60)
	return string.format("%.2d:%.2d:%.2d",hh, mm, ss)
end

local function GIT_Print(msg)
	return DEFAULT_CHAT_FRAME:AddMessage("|cffffff78GIT|r - "..msg)
end

local function GIT_OnEvent(timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	if (subevent == "UNIT_DIED") then
		local zone = GetRealZoneText()
		if (GIT_LastBoss[zone] == destName) then
			--Work complete. Show time.
			local total = GetTime() - starttime
			starttime = nil
			if (not GIT_Records[zone]) then
				GIT_Print(string.format("New record for %s: %s",zone, ReturnHHMMSS(total)))
				GIT_Records[zone] = total
			else
				if GIT_Records[zone] > total then
					GIT_Print(string.format("New record for %s: %s! You were %s faster than the previous record!", zone, ReturnHHMMSS(total), ReturnHHMMSS(GIT_Records[zone]-total)))
					GIT_Records[zone] = total
				else
					GIT_Print(string.format("The old record of %s still stands. It took you %s longer this time.", ReturnHHMMSS(GIT_Records[zone]), ReturnHHMMSS(total-GIT_Records[zone])))
				end
			end
		end
	end
end
frame:SetScript("OnEvent", function(frame, event, ...) GIT_OnEvent(...) end)

local function GIT_Slash(msg)
	if (not msg or msg=="") then
		GIT_Print("Valid commands for GIT are: SHOW | START")
	else
		if (msg:lower() == "start") then
			--Check if we 
			if GIT_LastBoss[GetRealZoneText()] then
				starttime = GetTime()
				frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				GIT_Print("Timer started for "..GetRealZoneText()..". Good luck!")
			end
		end
	end
end

--Register slash command.
SlashCmdList["GIT"] = GIT_Slash
SLASH_GIT1 = "/git"