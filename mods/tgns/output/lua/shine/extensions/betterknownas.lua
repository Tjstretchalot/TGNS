local PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS = 1814400
local PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE = "3-week"

local warned = {}
local bkas = {}

local pdr = TGNSPlayerDataRepository.Create("bka", function(bkaData)
	bkaData.AKAs = bkaData.AKAs ~= nil and bkaData.AKAs or {}
	bkaData.BKA = bkaData.BKA ~= nil and bkaData.BKA or ""
	bkaData.BKAPlayerModifiedAtInSeconds = bkaData.BKAPlayerModifiedAtInSeconds ~= nil and bkaData.BKAPlayerModifiedAtInSeconds or 0
	bkaData.BKAPlayerModifiedAtGmtString = bkaData.BKAPlayerModifiedAtGmtString ~= nil and bkaData.BKAPlayerModifiedAtGmtString or nil
	return bkaData
end)

local function ShowCurrentBka(client, targetSteamId, bkaHeader, akasHeader, prefix)
	local md = TGNSMessageDisplayer.Create(prefix)
	local bkaData = pdr:Load(targetSteamId)
	local player = TGNS.GetPlayerMatchingSteamId(targetSteamId)
	md:ToClientConsole(client, " ")
	if player ~= nil then
		md:ToClientConsole(client, string.format(" For: %s", TGNS.GetPlayerName(player)))
		md:ToClientConsole(client, " ")
	end
	md:ToClientConsole(client, string.format(" %s:", bkaHeader))
	if bkaData == nil or bkaData.BKA == nil or string.len(bkaData.BKA) == 0 then
		md:ToClientConsole(client, "     (none)")
	else
		md:ToClientConsole(client, string.format("     %s", bkaData.BKA))
	end
	md:ToClientConsole(client, string.format(" %s:", akasHeader))
	if bkaData == nil or bkaData.AKAs == nil or #bkaData.AKAs == 0 then
		md:ToClientConsole(client, "     (none)")
	else
		TGNS.DoFor(bkaData.AKAs, function(a) md:ToClientConsole(client, string.format("     %s", a)) end)
	end
	local whoisMd = TGNSMessageDisplayer.Create("WHOIS")
	whoisMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("%s: %s%s", TGNS.GetPlayerName(player), ((bkaData.BKA and bkaData.BKA ~= "") and string.format("%s*, ", bkaData.BKA) or ""), TGNS.Join(bkaData.AKAs, ", ")))
end

local function ShowUsage(client, targetSteamId)
	local md = TGNSMessageDisplayer.Create("BKA")
	md:ToClientConsole(client, " ")
	md:ToClientConsole(client, " Usage:")
	md:ToClientConsole(client, "     sh_aka <target> <aka>")
	md:ToClientConsole(client, "     sh_bka <target> <bka>")
	md:ToClientConsole(client, " Notes:")
	md:ToClientConsole(client, " * Keep the BKA/AKA short.")
	md:ToClientConsole(client, " * BKA is enforced.")
	md:ToClientConsole(client, " * <bka> of 'clear' removes enforced BKA name")
	md:ToClientConsole(client, " * <aka> of 'clear' removes all AKA names")
	if targetSteamId ~= nil then
		ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
	end
	md:ToClientConsole(client, " ")
end

local function AddAka(targetSteamId, newBkaName, allowClearParameterToRemoveAllAkaValues)
	local bkaData = pdr:Load(targetSteamId)
	if newBkaName ~= "clear" or not allowClearParameterToRemoveAllAkaValues then
		table.insert(bkaData.AKAs, newBkaName)
	else
		bkaData.AKAs = {}
	end
	bkaData.AKAs = TGNS.TableUnique(bkaData.AKAs)
	pdr:Save(bkaData)
end

local function OnBkaChanged(actingClient, targetClient, bkaData, newBkaName, bkaHeader, akaHeader, messagePrefix)
	bkaData.BKA = newBkaName
	pdr:Save(bkaData)
	bkas[targetClient] = newBkaName
	TGNS.UpdateAllScoreboards()
	ShowCurrentBka(actingClient, TGNS.GetClientSteamId(targetClient), bkaHeader, akaHeader, messagePrefix)
end

TGNSScoreboardMessageChanger.Add(TGNSScoreboardMessageChanger.Priority.LOWEST, function(scorePlayer, sendToPlayer, scoresMessage)
	local client = TGNS.GetClient(scorePlayer)
	local bkaName = bkas[client]
	if bkaName ~= nil and not TGNS.StringEqualsCaseInsensitive(TGNS.GetPlayerName(scorePlayer), bkaName) then
		scoresMessage.playerName = string.format("*%s", scoresMessage.playerName)
	end
end)

local function ShowWhoisUsage(client)
	local md = TGNSMessageDisplayer.Create("WHOIS")
	md:ToClientConsole(client, "Usage: sh_whois <player>")
end

local Plugin = {}

function Plugin:ClientConfirmConnect(client)
	TGNS.UpdateAllScoreboards()
end

function Plugin:ClientConfirmConnect(client)
	local bkaData = pdr:Load(TGNS.GetClientSteamId(client))
	if bkaData ~= nil and bkaData.BKA ~= nil and string.len(bkaData.BKA) > 0 then
		bkas[client] = bkaData.BKA
	end
end

function Plugin:CreateCommands()
	local whoisCommand = self:BindCommand( "sh_whois", "whois", function(client, playerPredicate)
		local md = TGNSMessageDisplayer.Create("WHOIS")
		if playerPredicate == nil or playerPredicate == "" then
			md:ToClientConsole(client, "You must specify a player.")
			ShowWhoisUsage(client)
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer ~= nil then
				local targetClient = TGNS.GetClient(targetPlayer)
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				ShowCurrentBka(client, targetSteamId, "Better Known As", "Aliases", "WHOIS")
				local logMessage = string.format("%s executed whois against %s.", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetClientNameSteamIdCombo(targetClient))
				TGNS.EnhancedLog(logMessage)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerPredicate))
				ShowWhoisUsage(client)
			end
		end
	end, true)
	whoisCommand:AddParam{ Type = "string", Optional = true }
	whoisCommand:Help( "<player> View player's aliases." )

	local bkaCommand = self:BindCommand( "sh_bka", "bka", function(client, playerName, newBkaName)
		local md = TGNSMessageDisplayer.Create("BKA")
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			if targetClient ~= nil then
				if newBkaName == nil or newBkaName == "" then
					md:ToClientConsole(client, "ERROR: No BKA name specified.")
				else
					if newBkaName == "clear" then
						newBkaName = nil
					end
					local targetSteamId = TGNS.GetClientSteamId(targetClient)
					local bkaData = pdr:Load(targetSteamId)
					OnBkaChanged(client, targetClient, bkaData, newBkaName, "BKA", "AKAs", "BKA")
				end
			else
				md:ToClientConsole(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
			end
		end
	end )
	bkaCommand:AddParam{ Type = "string", Optional = true}
	bkaCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	bkaCommand:Help( "<target> <bka> Adds a BKA name to the target.")

	local nameCommand = self:BindCommand( "sh_name", nil, function(client, newBkaName)
		local md = TGNSMessageDisplayer.Create("BKA")
		local steamId = TGNS.GetClientSteamId(client)
		local bkaData = pdr:Load(steamId)
		local bkaChangeError
		local timeRemainingBeforePlayerMayChangeOwnBkaInSeconds = bkaData.BKAPlayerModifiedAtInSeconds + PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS - TGNS.GetSecondsSinceEpoch()
		if timeRemainingBeforePlayerMayChangeOwnBkaInSeconds > 0 then
			bkaChangeError = string.format("%s cooldown in progress since %s (GMT). An admin can always edit your Better Known As.", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE, bkaData.BKAPlayerModifiedAtGmtString)
		else
			if newBkaName == "" then
				bkaChangeError = "No Better Known As name specified."
			elseif newBkaName == "clear" then
				bkaChangeError = "This Better Known As name may not be used."
			end
		end
		if bkaChangeError then
			md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
			md:ToClientConsole(client, "Usage: sh_name <name>")
		else
			if warned[client] == newBkaName then
				TGNS.ExecuteClientCommand(client, string.format("name %s", newBkaName))
				bkaData.BKAPlayerModifiedAtInSeconds = TGNS.GetSecondsSinceEpoch()
				bkaData.BKAPlayerModifiedAtGmtString = TGNS.GetCurrentDateTimeAsGmtString()
				OnBkaChanged(client, client, bkaData, newBkaName, "Better Known As", "Aliases", "BKA")
			else
				md:ToClientConsole(client, string.format("WHOA! You're setting your Better Known As name, with a %s cooldown before you can edit it again!", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE))
				md:ToClientConsole(client, "Your Better Known As name stays with you if you later choose a different player name.")
				md:ToClientConsole(client, "Any player may view your Better Known As at any time with the sh_whois command.")
				md:ToClientConsole(client, string.format("If you're sure '%s' is what you want, execute this same command again.", newBkaName))
				warned[client] = newBkaName
			end
		end
	end, true)
	nameCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	nameCommand:Help(string.format("<name> Edit your own Better Known As (%s cooldown between edits).", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE))

	local akaCommand = self:BindCommand( "sh_aka", "aka", function(client, playerName, newBkaName)
		local md = TGNSMessageDisplayer.Create()
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			if targetClient ~= nil then
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				if newBkaName ~= nil and newBkaName ~= "" then
					AddAka(targetSteamId, newBkaName, true)
					ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
				else
					ShowUsage(client, targetSteamId)
				end
			else
				md:ToClientConsole(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
			end
		end
	end )
	akaCommand:AddParam{ Type = "string", Optional = true}
	akaCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	akaCommand:Help("<target> <aka> Adds an AKA name to the target.")
end

function Plugin:PlayerNameChange(player, newName, oldName)
	if newName ~= kDefaultPlayerName and string.len(newName) > 0 then
		local steamId = TGNS.GetClientSteamId(TGNS.GetClient(player))
		AddAka(steamId, newName, false)
	end
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("betterknownas", Plugin )