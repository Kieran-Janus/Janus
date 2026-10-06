--!strict
--[[
	SERVER-WIDE ANNOUNCEMENTS (Config.Announce)

	A banner every player in the server sees at the top of the screen, for big moments:
	"<name> conquered the Tormented Tower!", or someone unboxing a CRAZY skin. The words of each
	announcement live with its feature (Config.TowerParkour.Text.Announce, Config.Crates...);
	here is how the banners look. Change colours, sizes and how long they stay freely.

	Styles:
	  Big    a normal big moment
	  Huge   a once-in-a-lifetime moment (bigger, longer, rainbow words)
]]

export type Style = {
	Seconds: number, -- how long the banner stays
	TextSize: number, -- the biggest the words get (they shrink to fit)
	Color: Color3, -- the words
	Background: Color3,
	Rainbow: boolean, -- the words cycle through the rainbow
	Width: number, -- pixels wide (it shrinks on small screens)
	Height: number,
	Sound: { SoundId: string, Volume: number },
}

return {
	Styles = {
		Big = {
			Seconds = 5,
			TextSize = 30,
			Color = Color3.fromRGB(255, 215, 80),
			Background = Color3.fromRGB(30, 18, 40),
			Rainbow = false,
			Width = 560,
			Height = 64,
			Sound = { SoundId = "rbxassetid://1841209502", Volume = 0.5 },
		},
		Huge = {
			Seconds = 9,
			TextSize = 44,
			Color = Color3.fromRGB(255, 255, 255),
			Background = Color3.fromRGB(40, 10, 50),
			Rainbow = true,
			Width = 720,
			Height = 96,
			Sound = { SoundId = "rbxassetid://9045119921", Volume = 0.8 },
		},
	} :: { [string]: Style },
	MaxQueue = 4, -- banners waiting their turn (older ones are dropped)
}
