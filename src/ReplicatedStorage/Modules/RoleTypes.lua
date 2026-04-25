--!strict
-- Role enum.

local RoleTypes = {
	Explorer = "Explorer",
	Guide = "Guide",
	None = "None",
}

function RoleTypes.IsValid(role: string?): boolean
	return role == RoleTypes.Explorer or role == RoleTypes.Guide
end

function RoleTypes.Other(role: string): string
	if role == RoleTypes.Explorer then
		return RoleTypes.Guide
	elseif role == RoleTypes.Guide then
		return RoleTypes.Explorer
	end
	return RoleTypes.None
end

return RoleTypes
