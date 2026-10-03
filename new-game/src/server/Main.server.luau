--!strict
-- Server entry point. Add a new service = add a line here.
local Services = script.Parent:WaitForChild("Services")

local DataService = require(Services.DataService)
local GameService = require(Services.GameService)
local AIService = require(Services.AIService)

DataService.Start()
AIService.Start()
GameService.Start()
