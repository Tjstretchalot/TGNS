local function GetChatMessage(...)
	local chatMessage = StringConcatArgs(...)
	if chatMessage then
		return string.sub(chatMessage, 1, kMaxChatLength)
	end
	return ""
end

local function ProcessChatCommand(sourceClient, channel, command, message)
	local label = channel.label
	Shared.Message(tostring(command))
	local sourceClientCanReceiveMessagesOnChannel = TGNS.ClientCanRunCommand(sourceClient, label)
	local name
	local chatMessage
	local md = TGNSMessageDisplayer.Create(label .. "(" .. channel.triggerChar .. ")")
	local sourcePlayer = TGNS.GetPlayer(sourceClient)
	local sourceClientName = TGNS.GetClientName(sourceClient)

	Shared.Message(tostring(sourceClientCanReceiveMessagesOnChannel))

	if sourceClientCanReceiveMessagesOnChannel and channel.canPM then
		_, _, name, chatMessage = string.find(message, "([%w%p]*) (.*)")
		chatMessage = GetChatMessage(chatMessage)
		if name ~= nil and string.len(name) > 0 then
			local targetPlayer = TGNS.GetPlayerMatchingName(name)
			if targetPlayer then
				local targetPlayerName = TGNS.GetPlayerName(targetPlayer)
				local targetClient = TGNS.GetClient(targetPlayer)
				local notification = string.format("%s->%s: %s", sourceClientName, targetPlayerName, chatMessage)
				md:ToAuthorizedNotifyInfo(notification, label)
				 if not TGNS.ClientCanRunCommand(targetClient, label) then
					md:ToPlayerNotifyInfo(targetPlayer, notification)
				end
			else
				md:ToPlayerNotifyError(sourcePlayer, string.format("'%s' does not uniquely match a player.", name))
			end
		elseif chatMessage ~= nil and string.len(chatMessage) > 0 then
			local notification = string.format("%s: %s", sourceClientName, chatMessage)
			md:ToAuthorizedNotifyInfo(notification, label)
		else
			md:ToPlayerNotifyError(sourcePlayer, "Admin usage: @<name> <message>, if name is blank only admins are messaged")
		end
	// Non-admins will send the message to all admins
	else
		Shared.Message(tostring(chatMessage))
		local chatMessage = GetChatMessage(message)
		if chatMessage then
			local notification = string.format("%s: %s", sourceClientName, chatMessage)
			md:ToAuthorizedNotifyInfo(notification, label)
			if not TGNS.ClientCanRunCommand(sourceClient, label) then
				md:ToPlayerNotifyInfo(sourcePlayer, notification)
			end
		else
			md:ToPlayerNotifyError(sourcePlayer, "Usage: @<message>")
		end
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "chatchannels.json"

function Plugin:ClientConfirmConnect(client)
	local md = TGNSMessageDisplayer.Create("ADMINCHAT")
	md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Any chat beginning with \"@\" shows only to admins. Try it!")
end

function Plugin:PlayerSay(client, networkMessage)
	local cancel = false
	local message = networkMessage.message
	message = StringTrim(message)
	if message then
		TGNS.DoForPairs(Shine.Plugins.chatchannels.Config.Channels, function(command, channel)
			if TGNS.StartsWith(message, channel.triggerChar) then
				local chatMessage = TGNS.Substring(message, 2)
				ProcessChatCommand(client, channel, command, chatMessage)
				cancel = true
			end
		end)
	end
	if cancel then
		return ""
	end
end

function Plugin:CreateCommands()
	TGNS.DoForPairs(Shine.Plugins.chatchannels.Config.Channels, function(command, channel)
		local chatCommand = self:BindCommand(command, nil, function(client, message)
			ProcessChatCommand(client, channel, command, message or "")
		end, true)
		chatCommand:AddParam{ Type = "string", TakeRestofLine = true, Optional = true }
		chatCommand:Help(channel.help)
	end)
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

Shine:RegisterExtension("chatchannels", Plugin )