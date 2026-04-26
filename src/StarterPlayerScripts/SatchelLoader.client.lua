--!strict
-- Replaces the default Roblox Backpack CoreGui with the vendored Satchel
-- module (https://github.com/ryanlua/satchel). Satchel itself disables
-- the CoreGui Backpack from inside the module — we just need to
-- require it so its top-level setup runs.

local Satchel = require(script.Parent:WaitForChild("Satchel"))
-- Reference the table so the Luau optimizer doesn't strip the require.
local _ = Satchel
