--!strict
--[[
	Change any words players see: on screens, buttons, signs, banners. Each line swaps a piece
	of text for your own wherever it shows up (also inside a longer line):
	    ["Stand here to play!"] = "Step in to play!",
	    ["Pumpkin Shop"] = "Pumpkin Store",
	The left side must match the game's text exactly (capitals and punctuation too). Players'
	screens do the swap (src/client/TextOverrides.luau), so it works on everything the code
	writes, even text that changes during a round.

	The easy way: the Pumpkin Tools plugin in Studio (Plugins tab > Pumpkin Tools > Text). Click
	any sign, or press Play, click "Pick text" and click anything on the screen, then type the
	new words. Those changes are saved in your place (ReplicatedStorage > TextOverrides) and
	work together with the lines here; save the place (Ctrl+S). Ask Claude Code to copy them
	into this file so they are in git too.
]]

return {
	On = true, -- false = show the game's own words everywhere
	Pairs = {
		-- ["Stand here to play!"] = "Step in to play!",
	} :: { [string]: string },
}
