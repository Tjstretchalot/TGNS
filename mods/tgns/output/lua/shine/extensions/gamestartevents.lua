local Plugin = {}

function Plugin:SetGameState(gamerules, newState, oldState)
	if oldState ~= kGameState.Started and newState == kGameState.Started then
		TGNS.ExecuteEventHooks("GameStarted")
	end
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("gamestartevents", Plugin )