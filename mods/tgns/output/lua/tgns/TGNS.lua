Script.Load("lua/tgns/shared/TGNSCommonShared.lua")
Script.Load("lua/tgns/shared/TGNSComprehension.lua")
Script.Load("lua/tgns/shared/TGNSMenuDisplayer.lua")
Script.Load("lua/tgns/shared/TGNSJsonFileTranscoder.lua")
if Server then
	Script.Load("lua/tgns/server/TGNSAverageCalculator.lua")
	Script.Load("lua/tgns/server/TGNSCommonServer.lua")
	Script.Load("lua/tgns/server/TGNSMessageDisplayer.lua")
	Script.Load("lua/tgns/server/TGNSScoreboardPlayerHider.lua")
	Script.Load("lua/tgns/server/TGNSClientKicker.lua")
	Script.Load("lua/tgns/server/TGNSDataRepository.lua")
	Script.Load("lua/tgns/server/TGNSPlayerDataRepository.lua")
	Script.Load("lua/tgns/server/TGNSConnectedTimesTracker.lua")
	Script.Load("lua/tgns/server/TGNSMonthlyNumberGetter.lua")
	Script.Load("lua/tgns/server/TGNSNs2StatsProxy.lua")
	Script.Load("lua/tgns/server/TGNSPlayerBlacklistRepository.lua")
	Script.Load("lua/tgns/server/TGNSPlayerPreferredRepository.lua")
	Script.Load("lua/tgns/server/TGNSScoreboardMessageChanger.lua")
	Script.Load("lua/tgns/server/TGNSServerInfoGetter.lua")
	Script.Load("lua/tgns/server/TGNSSessionDataRepository.lua")
elseif Client then
	Script.Load("lua/tgns/client/TGNSCommonClient.lua")
end