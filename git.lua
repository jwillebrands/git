local GIT_LastBoss = {
	--["Terokkar Forest"] = 18461,
	--Changed to mobIDs to rule out errors.
	
	--Outlands dungeons.
	--Hellfire Citadel
	["Hellfire Ramparts"] = 17536,
	["The Blood Furnace"] = 17377,
	["The Shattered Halls"] = 16808,
	
	--Coilfang Reservoir
	["The Slave Pens"] = 17942,
	["The Underbog"] = 17882,
	["The Steamvault"] = 17798,	
	
	--Auchindoun
	["Auchenai Crypts"] = 18373,
	["Mana-Tombs"] = 18344,
	["Sethekk Halls"] = 18473,
	["Shadow Labyrinth"] = 18708,
	
	--Caverns of Time
	["Old Hillsbrad Foothills"] = 18096,
	["The Black Morass"] = 17881,
	
	--Tempest Keep
	["The Mechanar"] = 19220,
	["The Botanica"] = 17977,
	["The Arcatraz"] = 20912,
	
	--Magister's Terrace
	["Magisters' Terrace"] = 24664,
	
	--10 man Raids
	["Zul'Gurub"] = 14834,
	["Karazhan"] = 15690,
	["Zul'Aman"] = 23863,
}
--Create Records table, will be overwritten by SavedVars record table if there is one.
GIT_Records = {}

--Declare some locals we'll need throughout the addon.
local starttime, difficulty, lastupdate
local GetTime = GetTime

--Return HH:MM:SS from seconds, rounding up seconds.
local function SecondsToHHMMSS(seconds)
	local hh = math.floor(seconds/3600)
	local mm = math.floor((seconds-hh*3600)/60)
	local ss = ceil(seconds-hh*3600-mm*60)
	return string.format("%.2d:%.2d:%.2d",hh, mm, ss)
end

--Fancy prefix and less typing. ^^
local function GIT_Print(msg)
	return DEFAULT_CHAT_FRAME:AddMessage("|cffffff78GIT|r - "..msg)
end

--Create our frame and register the event we're interested in.
local frame = CreateFrame("Frame","GITFrame",UIParent)
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
--We set the width later so it changes dynamically depending on instance text.
frame:SetHeight(16)
frame:SetMovable()
frame:EnableMouse()
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetUserPlaced(true)
frame:RegisterEvent("VARIABLES_LOADED")

--Yay we're gonna have a visible timer! \o/
local instancetext = frame:CreateFontString("GITFrameInstance", "OVERLAY")
instancetext:SetPoint("TOP", frame, "TOP")
instancetext:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")


local timertext = frame:CreateFontString("GITTimerText", "OVERLAY")
timertext:SetPoint("TOP", frame, "BOTTOM")
timertext:SetFont(STANDARD_TEXT_FONT, 12)

--Update frame's dimensions whenever it's shown.
frame:SetScript("OnShow", function(self) self:SetWidth(max(instancetext:GetWidth(), timertext:GetWidth())) self:SetHeight(instancetext:GetHeight() + timertext:GetHeight()) end)

local function GIT_OnUpdate()
	--We don't really care about milliseconds, so we'll just update the frame once per second.
	if (not lastupdate or GetTime() - lastupdate > 1) then
		--Set timer text.
		timertext:SetText(SecondsToHHMMSS(GetTime() - starttime)..(GIT_Records[instancetext:GetText()] and GIT_Records[instancetext:GetText()][difficulty] and GIT_Records[instancetext:GetText()][difficulty].time and " / "..SecondsToHHMMSS(GIT_Records[instancetext:GetText()][difficulty].time) or ""))
		lastupdate = GetTime()
	end
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
			if (GIT_LastBoss[zone] == tonumber(destGUID:sub(6,12),16)) then
				--Work complete. Show time.
				local total = GetTime() - starttime
				starttime = nil
				
				--Done with combat log monitoring, reset to monitoring zone changes. Also stop the frame's OnUpdate.
				frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
				frame:SetScript("OnUpdate",nil)
				
				--Check if new record has been achieved.
				if (not GIT_Records[zone] or type(GIT_Records[zone]) ~= "table" or not GIT_Records[zone][difficulty]) then
					GIT_Print(string.format("New record for %s (%s): %s",zone, difficulty,  SecondsToHHMMSS(total)))
					
					--Create table values.
					GIT_Records[zone] = {[difficulty] = {["time"] = total}}
					GIT_SaveParty(zone, difficulty)
				else
					if GIT_Records[zone][difficulty].time > total then
						GIT_Print(string.format("New record for %s (%s): %s! You were %s faster than the previous record!", zone, difficulty, SecondsToHHMMSS(total), SecondsToHHMMSS(GIT_Records[zone][difficulty].time-total)))
						GIT_Records[zone][difficulty].time = total
						GIT_SaveParty(zone, difficulty)
					else
						GIT_Print(string.format("The old record of %s still stands. It took you %s longer this time.", SecondsToHHMMSS(GIT_Records[zone][difficulty].time), SecondsToHHMMSS(total-GIT_Records[zone][difficulty].time)))
					end
				end
			end
		end
	elseif (event == "PLAYER_REGEN_DISABLED") then
		--Only continue if starttime = nil (ie. there is no timer running) and current zone is in the LastBoss list.
		if (not starttime and GIT_LastBoss[GetRealZoneText()]) then
			--Set difficulty to current dungeon difficulty. (1. normal, 2. heroic)
			difficulty = (GetCurrentDungeonDifficulty() == 2 and "heroic" or "normal")
			GIT_Print(string.format("Timer for %s (%s) started. Good luck!", GetRealZoneText(), difficulty))
			starttime = GetTime()
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			
			--Set frame text to current instance and initiate frame's OnUpdate.
			instancetext:SetText(GetRealZoneText())
			frame:SetWidth(instancetext:GetWidth())
			frame:SetScript("OnUpdate", GIT_OnUpdate)
		end
	elseif (event == "VARIABLES_LOADED") then
		--If frame has no known position set it to center of screen.
		if (not frame:GetPoint()) then
			frame:SetPoint("CENTER")
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
			frame:SetScript("OnUpdate", nil)
		else
			GIT_Print("Unrecognised command ("..msg.."), valid commands are: stop")
		end
	end
end

--Register slash command.
SlashCmdList["GIT"] = GIT_Slash
SLASH_GIT1 = "/git"
