--!strict
-- Server entry point. Add a new service = add a line here.
local Services = script.Parent:WaitForChild("Services")

local DataService = require(Services.DataService)
local MapService = require(Services.MapService)
local PumpkinService = require(Services.PumpkinService)
local VotingService = require(Services.VotingService)
local GameService = require(Services.GameService)
local AIService = require(Services.AIService)

DataService.Start()
MapService.Start()
PumpkinService.Start()
VotingService.Start()
AIService.Start()
GameService.Start()
