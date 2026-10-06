--!strict
--[[
	PHOTO SPOT DANCES (Config.Dances; on/off: Config.Features.Dances)

	At the Photo Spot ("Strike a pose") a bar of spooky, silly dances opens. Pick one and your
	character dances for everyone to see; walking or jumping stops it.

	Roblox only plays animations owned by the game's creator, so these dances are made in code:
	the server checks you're at the Photo Spot and sets the Dance attribute on your character,
	and every player's screen moves that character's joints (R15 and R6 both work).

	Each line is one dance button:
	  Id           which code dance it is (don't change it; a new Id with no code does a happy
	               bounce). Order here = order of the buttons.
	  Label        the words on the button (change freely)
	  AnimationId  optional: an animation you uploaded ("rbxassetid://123..."). When set, your
	               animation plays instead of the code dance. "" = use the code dance.
]]

export type Dance = { Id: string, Label: string, AnimationId: string }

return {
	List = {
		{ Id = "ZombieShuffle", Label = "Zombie Shuffle", AnimationId = "" },
		{ Id = "SkeletonRattle", Label = "Skeleton Rattle", AnimationId = "" },
		{ Id = "GhostFloat", Label = "Ghost Float", AnimationId = "" },
		{ Id = "PumpkinHeadSpin", Label = "Pumpkin Head Spin", AnimationId = "" },
		{ Id = "MonsterMash", Label = "Monster Mash", AnimationId = "" },
		{ Id = "BatFlap", Label = "Bat Flap", AnimationId = "" },
		{ Id = "ScaredyCatShiver", Label = "Scaredy Cat Shiver", AnimationId = "" },
		{ Id = "WitchyCackle", Label = "Witchy Cackle", AnimationId = "" },
		{ Id = "MummyWobble", Label = "Mummy Wobble", AnimationId = "" },
		{ Id = "SpookyFloss", Label = "Spooky Floss", AnimationId = "" },
	} :: { Dance },
	StopLabel = "Stop", -- the button that stops dancing
	Speed = 1, -- how fast every code dance moves (2 = twice as fast)
	Cooldown = 0.4, -- seconds between dance changes (stops spamming)
	MaxDrift = 3, -- studs you can drift from where you started before the dance stops
	Columns = 6, -- buttons per row in the dance bar
}
