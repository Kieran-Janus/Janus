--!strict
--[[
	Claude-powered NPC chat.

	Flow: client -> RemoteFunction "AskNpc" -> server validates + rate limits ->
	your proxy (tools/ai-proxy) -> Anthropic API -> TextService filter -> client.

	Security rules baked in:
	  * The API key never touches Roblox. Only a proxy key, held in Roblox Secrets.
	  * Persona comes from Config (server-trusted), never from the client.
	  * Every reply is run through TextService before anyone sees it.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local AIService = {}

local windowStart, windowCount = 0, 0

local lastAsked: { [Player]: number } = {}
local history: { [Player]: { [string]: { { role: string, content: string } } } } = {}

local MAX_TURNS = 8

local function filterFor(player: Player, text: string): string
	if not Config.Moderation.FilterAIText then
		return text
	end
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(text, player.UserId)
		return filtered:GetChatForUserAsync(player.UserId)
	end)
	return if ok then result else "..."
end

function AIService.Ask(player: Player, npcId: string, message: string): string
	if not Config.AI.Enabled then
		return "..."
	end
	local npc = Config.AI.Npcs[npcId]
	if typeof(message) ~= "string" or not npc then
		return "..."
	end

	local now = os.clock()
	if now - (lastAsked[player] or 0) < Config.AI.CooldownSeconds then
		return "Give me a second to think!"
	end
	lastAsked[player] = now
	-- Whole-server cap, so a few spammers can't drain the HTTP quota or the API bill.
	if now - windowStart >= 60 then
		windowStart, windowCount = now, 0
	end
	if windowCount >= Config.AI.MaxRequestsPerMinute then
		return "I'm busy, try again soon!"
	end
	windowCount += 1

	message = message:sub(1, Config.AI.MaxMessageLength)

	local convo = history[player] or {}
	history[player] = convo
	local turns = convo[npcId] or {}
	convo[npcId] = turns
	table.insert(turns, { role = "user", content = message })
	while #turns > MAX_TURNS do
		table.remove(turns, 1)
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = Config.AI.ProxyUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["x-proxy-key"] = HttpService:GetSecret(Config.AI.SecretName),
			},
			Body = HttpService:JSONEncode({
				system = npc.Persona,
				messages = turns,
				max_tokens = Config.AI.MaxReplyTokens,
			}),
		})
	end)

	if not ok or not response.Success then
		warn("[AIService] request failed:", ok and response.StatusCode or response)
		table.remove(turns) -- don't poison history with an unanswered turn
		return "Hmm, my brain is buffering. Try again!"
	end

	local decoded = HttpService:JSONDecode(response.Body)
	local reply = tostring(decoded.reply or "...")
	table.insert(turns, { role = "assistant", content = reply })
	return filterFor(player, reply)
end

function AIService.Start()
	local ask = Remotes.Function("AskNpc")
	ask.OnServerInvoke = function(player: Player, npcId: unknown, message: unknown)
		if typeof(npcId) ~= "string" or typeof(message) ~= "string" then
			return "..."
		end
		return AIService.Ask(player, npcId, message)
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAsked[player] = nil
		history[player] = nil
	end)
end

return AIService
