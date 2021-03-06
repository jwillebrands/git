local GIT_LastBoss = {
	--Changed to mobIDs to rule out errors.
	
	--Outlands dungeons.
	--Hellfire Citadel
	["Hellfire Ramparts"] = 17307, --Nazan keeps Vazruden the Herald's mobID.
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
	
	--25 man raids
	["Serpentshrine Cavern"] = 21212,
	["The Eye"] = 19622,
	["Hyjal Summit"] = 17968,
	["Black Temple"] = 22917,
	["Sunwell Plateau"] = 25315,
	
	["Magtheridon's Lair"] = 17257,
	["Gruul's Lair"] = 19044,
	
}
--Create Records table, will be overwritten by SavedVars record table if there is one.
GIT_Records = {}

--Declare some locals we'll need throughout the addon.
local GITDebug = false
local starttime, difficulty
local lastupdate = 0
local GetTime = GetTime
local reftable

--List of valid channels for report function
local ValidChan = {
	["guild"] = "GUILD",
	["/g"] = "GUILD",
	["g"] = "GUILD",
	["party"] = "PARTY",
	["/p"] = "PARTY",
	["p"] = "PARTY",
	["raid"] = "RAID",
	["/r"] = "RAID",
	["r"] = "RAID",
}

-- *** Utility functions ***
--Return HH:MM:SS from seconds, rounding up seconds.
local function SecondsToHHMMSS(seconds)
	local hh = math.floor(seconds/3600)
	local mm = math.floor((seconds-hh*3600)/60)
	local ss = ceil(seconds-hh*3600-mm*60)
	return string.format("%.2d:%.2d:%.2d",hh, mm, ss)
end

--Split up msg into Cmd and SubCmd for slash handler.
local function GetCmd(msg)
	if msg then
		local Cmd,SubCmd = string.match(msg, "^(%S+)%s?(.*)$")
		return Cmd,SubCmd
	end
end

--Fancy prefix and less typing. ^^
local function GIT_Print(msg)
	return DEFAULT_CHAT_FRAME:AddMessage("|cffffff78GIT|r - "..msg)
end

--Return string containing keys in 't' seperated by 'seperator'
local function ConcatTableKeys(t, seperator)
	local text = ""
	for k,v in pairs(t) do
		text = text..k
		if (next(t, k)) then
			text = text..seperator
		end
	end
	return text
end

--Get amount of keys in associative table.
local function GetAssocTableKeys(t)
	local num=0
	for k,v in pairs(t) do
		num = num+1
	end
	return num
end

--Create color escape sequence (|caarrggbb) from CLASS
local function GenerateColorSequence(class)
	local r,g,b = RAID_CLASS_COLORS[class].r, RAID_CLASS_COLORS[class].g, RAID_CLASS_COLORS[class].b
	return string.format("|cff%02x%02x%02x", r*255,g*255,b*255)
end

--Create our frame and register the event we're interested in.
local frame = CreateFrame("Frame","GITFrame",UIParent)
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
--We set the width later so it changes dynamically depending on instance text.
frame:SetHeight(16)
frame:SetWidth(1)
frame:SetMovable()
frame:EnableMouse()
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frame:SetUserPlaced(true)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

--Yay we're gonna have a visible timer! \o/
local instancetext = frame:CreateFontString("GITFrameInstance", "OVERLAY")
instancetext:SetPoint("TOP", frame, "TOP")
instancetext:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")


local timertext = frame:CreateFontString("GITTimerText", "OVERLAY")
timertext:SetPoint("TOP", frame, "BOTTOM")
timertext:SetFont(STANDARD_TEXT_FONT, 12)

--Save party layout to Saved Var.
local function GIT_SaveParty(zone, difficulty)
	GIT_Records[zone][difficulty]["playername"] = UnitName("player")
	GIT_Records[zone][difficulty]["playerclass"] = strjoin(",",UnitClass("player"))
	
	local name
	if GetNumRaidMembers() > 0 then
		for i=1, GetNumRaidMembers() do
			name = UnitName("raid"..i)
			GIT_Records[zone][difficulty]["party"..i.."name"] = name
			GIT_Records[zone][difficulty]["party"..i.."class"] = (name and strjoin(",", UnitClass("raid"..i)) or nil)
		end
	else
		for i=1, GetNumPartyMembers() do
			local name = UnitName("party"..i)
			GIT_Records[zone][difficulty]["party"..i.."name"] = name
			GIT_Records[zone][difficulty]["party"..i.."class"] = (name and strjoin(",", UnitClass("party"..i)) or nil)
		end
	end
end

-- *** Timer functions ***

local function ToggleTimer()
	if (not frame:IsShown()) then
		frame:Show()
	else
		frame:Hide()
	end
end

local function GIT_OnUpdate(elapsed,zone,record)
	lastupdate = lastupdate + elapsed
	--We don't really care about milliseconds, so we'll just update the frame once per second.
	if (lastupdate >= 1) then
		--Set timer text.
		local currentduration = GetTime() - starttime
		
		--Do fancy coloring depending on record.
		local color
		if (record) then
			if (record > currentduration+300) then
				color = "\124cff00ff00"
			elseif (record > currentduration) then
				color = "\124cffffff00"
			else
				color = "\124cffff0000"
			end
		end
		if (color) then
			timertext:SetText(color..SecondsToHHMMSS(currentduration).."\124r / "..SecondsToHHMMSS(record))
		else
			timertext:SetText(SecondsToHHMMSS(currentduration))
		end
		lastupdate = 0
	end	
end

--Stop timer without evaluating record. (for failed/aborted runs)
local function StopTimer()
	GIT_Print("Timer stopped.")
	starttime = nil
	frame:SetScript("OnUpdate", nil)
	frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

--Stop timer and evaluate record.
local function EvalTimer(zone)
	if (not zone or zone == "") then
		--Function was called from slash command, get instance name from frame.
		zone = instancetext:GetText()
	end
	if (not GIT_LastBoss[zone]) then
		return GIT_Print("Unkown zone ("..zone.."), could not save record.")
	end
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
		if GIT_Records[zone] then 
			GIT_Records[zone][difficulty] = {["time"] = total}
		else
			GIT_Records[zone] = {[difficulty] = {["time"] = total}}
		end
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
	
--Event handler. Simple if-elseif block, no point using fancy tables for just 2 events in my opinion.
local function GIT_OnEvent(event, timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...)
	local zone = GetRealZoneText()
	if (event == "COMBAT_LOG_EVENT_UNFILTERED") then
		if (subevent == "UNIT_DIED") then
			--If the unit that died is the last boss of that zone, end the timer 
			if (GIT_LastBoss[zone] == tonumber(destGUID:sub(6,12),16)) then
				EvalTimer(zone)
			end
		end
	elseif (event == "PLAYER_REGEN_DISABLED") then
		--Only continue if starttime = nil (ie. there is no timer running) and current zone is in the LastBoss list.
		if (not starttime and GIT_LastBoss[GetRealZoneText()]) then
			--Set difficulty to current dungeon difficulty. (1. normal, 2. heroic)
			difficulty = (GetCurrentDungeonDifficulty() == 2 and "heroic" or "normal")
			GIT_Print(string.format("Timer for %s (%s) started. Good luck!", zone, difficulty))
			starttime = GetTime()
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			
			--Set frame text to current instance and initiate frame's OnUpdate.
			instancetext:SetText(GetRealZoneText())
			frame:SetWidth(instancetext:GetWidth())
			frame:SetScript("OnUpdate", function(self,elapsed) GIT_OnUpdate(elapsed,zone,GIT_Records[zone] and GIT_Records[zone][difficulty] and GIT_Records[zone][difficulty].time or nil) end)
		end
	elseif (event == "PLAYER_ENTERING_WORLD") then
		--If frame has no known position set it to center of screen.
		if (not frame:GetPoint()) then
			frame:SetPoint("CENTER")
		end
	end
end
--Set OnEvent handler to call GIT_OnEvent.
frame:SetScript("OnEvent", function(frame, event, ...) GIT_OnEvent(event, ...) end)

--Debug function so I don't have to reloadUI each time. Enables a logging of a Dampscale Basilisk in Terokkar Forest for testing purposes.
local function EnableDebug()
	if (not GITDebug) then
		GITDebug = true
		GIT_LastBoss["Terokkar Forest"] = 18461
		return GIT_Print("Debugging enabled.")
	else
		GITDebug = false
		GIT_LastBoss["Terokkar Forest"] = nil
		return GIT_Print("Debugging disabled.")
	end
end

--Generate reference table for records.
local function GenerateRefTable()
	reftable = {}
	for k,v in pairs(GIT_Records) do
		for x,y in pairs(v) do
			reftable[#reftable+1] = k.." - "..x
		end
	end
end

--Generate record. If override is given, no color codes are used so output can be sent to chat channels.
local function GenerateRecord(input,override)
	if (not reftable or #reftable ~= GetAssocTableKeys(GIT_Records)) then
		GenerateRefTable()
	end
	zone,difficulty = input:match("^(.*) %- (.*)")
	local name,localclass,class = GIT_Records[zone][difficulty].playername, strsplit(",",GIT_Records[zone][difficulty].playerclass)
	local output = string.format("Current record for %s (%s): %s. Set by: %s%s (%s)%s", zone, difficulty, SecondsToHHMMSS(GIT_Records[zone][difficulty].time), override and "" or GenerateColorSequence(class), name, localclass, override and "" or "|r")
	for i=1,24 do
		name = GIT_Records[zone][difficulty]["party"..i.."name"]
		if (name) then
			localclass, class = strsplit(",",GIT_Records[zone][difficulty]["party"..i.."class"])
		else
			break
		end
		output = output .. string.format(", %s%s (%s)%s", override and "" or GenerateColorSequence(class), name, localclass, override and "" or "|r")
	end
	return output
end

--Output record
local function ShowRecord(msg)
	if (not reftable or #reftable ~= GetAssocTableKeys(GIT_Records)) then
		GenerateRefTable()
	end
	if (msg == "") then
		for i,v in ipairs(reftable) do
			GIT_Print("/git showrecord "..i.." - "..v)
		end
	else
		sel = tonumber(msg)
		if (sel) then
			if (reftable[sel]) then
				GIT_Print(GenerateRecord(reftable[sel]))
			else
				GIT_Print("Number not found in reference table: " .. sel)
			end
		else
			GIT_Print("Invalid input:".. msg)
		end
	end
end

--Report record
local function ReportRecord(msg)
	if (not reftable or #reftable ~= GetAssocTableKeys(GIT_Records)) then
		GenerateRefTable()
	end
	if (msg == "") then
		for i,v in ipairs(reftable) do
			GIT_Print("/git report "..i.." - "..v)
		end
	else
		sel,channel = GetCmd(msg)
		sel = tonumber(sel)
		channel = channel:lower()
		if (sel) then
			if (reftable[sel]) then
				--Check if specified channel is allowed
				if ValidChan[channel] then
					SendChatMessage(GenerateRecord(reftable[sel],true), ValidChan[channel])
				else
					GIT_Print("Invalid channel: "..channel)
				end
			else
				GIT_Print("Number not found in reference table: " .. sel)
			end
		else
			GIT_Print("Invalid input. Number expected, got: "..GetCmd(msg))
		end
	end
end

-- *** Slash Command setup ***
--Command table for slash handler.
local SlashCommands = {
	save = EvalTimer,
	stop = StopTimer,
	showrecord = ShowRecord,
	report = ReportRecord,
	toggle = ToggleTimer,
	debug = EnableDebug,
}

--Simple slash handler. Will be improved at some point.
local function GIT_Slash(msg)
	if (not msg or msg=="") then
		GIT_Print("Valid commands for /git are: "..ConcatTableKeys(SlashCommands, " | "))
	else
		Cmd, SubCmd = GetCmd(msg)
		if SlashCommands[Cmd:lower()] then
			SlashCommands[Cmd:lower()](SubCmd)
		else
			GIT_Print("Unrecognised command ("..Cmd.."). Valid commands are: "..ConcatTableKeys(SlashCommands, " | "))
		end
	end
end

--Register slash command.
SlashCmdList["GIT"] = GIT_Slash
SLASH_GIT1 = "/git"