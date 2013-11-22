local md = TGNSMessageDisplayer.Create()
local pdrCache = {}

local function CreateRole(displayName, candidatesDescription, groupName, messagePrefix, optInConsoleCommandName, persistedDataName, isClientOneOfQuery, isClientBlockerQuery, minimumRequirementsQuery, chargeStatement)
	local result = {}
	pdrCache[persistedDataName] = {}
	local pdr = TGNSPlayerDataRepository.Create(persistedDataName, function(data)
			data.optin = data.optin ~= nil and data.optin or false
			return data
		end)
	local pbr = TGNSPlayerBlacklistRepository.Create(persistedDataName)
	local ppr = TGNSPlayerPreferredRepository.Create(persistedDataName)
	result.displayName = displayName
	result.candidatesDescription = candidatesDescription
	result.groupName = groupName
	result.messagePrefix = messagePrefix
	result.optInConsoleCommandName = optInConsoleCommandName
	result.chargeStatement = chargeStatement
	result.IsClientOneOf = isClientOneOfQuery
	result.IsClientBlockerOf = isClientBlockerQuery
	function result:IsTeamEligible(teamPlayers) return TGNS.GetLastMatchingClient(teamPlayers, self.IsClientBlockerOf) == nil end
	function result:IsClientBlacklisted(client) return pbr:IsClientBlacklisted(client) end
	function result:IsClientPreferred(client) return ppr:IsClientPreferred(client) end
	function result:LoadOptInData(client)
		local pdrData
		local steamId = TGNS.GetClientSteamId(client)
		if pdrCache[persistedDataName][steamId] ~= nil then
			pdrData = pdrCache[persistedDataName][steamId]
		else
			pdrData = pdr:Load(TGNS.GetClientSteamId(client))
		end
		return pdrData
	end
	function result:SaveOptInData(pdrData)
		pdrCache[persistedDataName][pdrData.steamId] = pdrData
		pdr:Save(pdrData)
	end
	function result:IsClientEligible(client) return minimumRequirementsQuery(client) and self:LoadOptInData(client).optin and not self:IsClientBlacklisted(client) end
	return result
end

local roles = {
	//CreateRole("Temp Admin"
	//	, "Supporting Members who have signed the TGNS Primer"
	//	, "tempadmin_group"
	//	, "TEMPADMIN"
	//	, "sh_tempadmin"
	//	, "tempadmin"
	//	, TGNS.IsClientTempAdmin
	//	, TGNS.IsClientAdmin
	//	, function(client) return TGNS.IsClientSM(client) and TGNS.HasClientSignedPrimerWithGames(client) end
	//  , "As Temp Admin, your responsibility now is to enforce the rules."),
	CreateRole("Guardian"
		, "TGNS Primer signers who've played >=40 full rounds on this server"
		, "guardian_group"
		, "GUARDIAN"
		, "sh_guardian"
		, "guardian"
		, TGNS.IsClientGuardian
		, function(client) return false end
		, function(client)
			local totalGamesPlayed = Balance.GetTotalGamesPlayed(client)
			return TGNS.HasClientSignedPrimerWithGames(client) and totalGamesPlayed >= 40 and not TGNS.IsClientAdmin(client) and not TGNS.IsClientGuardian(client)
		end
		, "As Guardian, your responsibility now is to enforce the rules.")
}


local function GetCandidateClient(teamPlayers, role)
	local result = nil
	local teamIsEligible = role:IsTeamEligible(teamPlayers)
	if teamIsEligible then
		local clientsAlreadyInTheRole = TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end)
		if #clientsAlreadyInTheRole < 2 then
			TGNS.SortAscending(teamPlayers, function(p) return TGNS.ClientAction(p, function(c) return role:IsClientPreferred(c) end) and 1 or 0 end)
			result = TGNS.GetLastMatchingClient(teamPlayers, function(c,p)
				return role:IsClientEligible(c)
			end)
		end
	end
	return result
end

local function AddToClient(client, role)
	TGNS.AddTempGroup(client, role.groupName)
	local player = TGNS.GetPlayer(client)
	md:ToPlayerNotifyInfo(player, string.format("You are a %s. Apply exemplarily.", role.displayName))
	md:ToPlayerNotifyInfo(player, role.chargeStatement)
	TGNS.UpdateAllScoreboards()
end

local function RemoveFromClient(client, role)
	if role.IsClientOneOf(client) then
		TGNS.PlayerAction(client, function(p) md:ToPlayerNotifyInfo(p, string.format("You are no longer a %s.", role.displayName)) end)
	end
	TGNS.RemoveTempGroup(client, role.groupName)
	TGNS.UpdateAllScoreboards()
end

local function EnsureAmongPlayers(players, role)
	local candidateClient = GetCandidateClient(players, role)
	if candidateClient ~= nil then
		AddToClient(candidateClient, role)
	end
end

local function ToggleOptIn(client, role)
	local message
	if role:IsClientBlacklisted(client) then
		message = string.format("Contact an Admin to get access to %s: tacticalgamer.com/natural-selection-contact-admin", role.displayName)
	else
		local pdrData = role:LoadOptInData(client)
		pdrData.optin = not pdrData.optin
		role:SaveOptInData(pdrData)
		if pdrData.optin then
			message = string.format("You are opted into %s. Only %s are considered.", role.displayName, role.candidatesDescription)
		else
			message = string.format("You will no longer be considered for %s.", role.displayName)
			RemoveFromClient(client, role)
		end
	end
	local roleMd = TGNSMessageDisplayer.Create(role.messagePrefix)
	roleMd:ToClientConsole(client, message)
end

local function CheckRoster()
	local playerList = TGNS.GetPlayerList()
	local marinePlayers = TGNS.GetMarinePlayers(playerList)
	local alienPlayers = TGNS.GetAlienPlayers(playerList)
	local readyRoomPlayers = TGNS.GetReadyRoomPlayers(playerList)
	local spectatorPlayers = TGNS.GetSpectatorPlayers(playerList)

	TGNS.DoFor(roles, function(role)
		EnsureAmongPlayers(readyRoomPlayers, role)
		EnsureAmongPlayers(marinePlayers, role)
		EnsureAmongPlayers(alienPlayers, role)
		EnsureAmongPlayers(spectatorPlayers, role)
	end)
end

local function RegisterCommandHook(plugin, role)
	local command = plugin:BindCommand(role.optInConsoleCommandName, nil, function(client)
		ToggleOptIn(client, role)
	end, true)
	command:Help(string.format("Toggle opt in/out of %s responsibilities.", role.displayName))
end

local Plugin = {}

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	TGNS.DoFor(roles, function(role)
		local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
		local clientIsBlockerOf = TGNS.ClientAction(player, role.IsClientBlockerOf)
		if clientIsBlockerOf then
			TGNS.DoFor(TGNS.Where(teamClients, role.IsClientOneOf), function(c) RemoveFromClient(c, role) end)
		end
		local clientIsOneOf = TGNS.ClientAction(player, role.IsClientOneOf)
		if clientIsOneOf then
			local teamPlayers = TGNS.GetPlayers(teamClients)
			local numberOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end)
			local numberOfBlockersOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientBlockerOf(c) end)
			if (numberOnNewTeam >= 2 or numberOfBlockersOnNewTeam > 0) then
				TGNS.ClientAction(player, function(c) RemoveFromClient(c, role) end)
			end
		end
	end)
end

function Plugin:ClientConfirmConnect(client)
	CheckRoster()
end

function Plugin:Initialise()
	self.Enabled = true
	TGNS.ScheduleActionInterval(10, CheckRoster)
	TGNS.DoFor(roles, function(r) RegisterCommandHook(self, r) end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("teamroles", Plugin )