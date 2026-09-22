include("shared.lua")

function ENT:Initialize()
	local parent = self:GetParent()
	
	self:SetNoDraw(true)	

	self.sequenceOrder = self.sequenceOrder or 1
	self.spawnTime = CurTime()

	self.base = self.base
	self.arrow = self.arrow
end

function ENT:Think()

	local time = CurTime() - self.spawnTime
	local cycleSpeed = time * math.pi
	
	if IsValid(self.base) then
		local baseScaleVal = 1.2 + (0.2 * math.sin(cycleSpeed))
		self.base:SetModelScale(baseScaleVal, 0)
	end

	if IsValid(self.arrow) then
		local floatZ = (math.sin(cycleSpeed) + 1) * 4 	
		local spinYaw = (time * 72) % 360
		
		self.arrow:SetLocalPos(Vector(0, 0, floatZ))
		self.arrow:SetLocalAngles(Angle(0, spinYaw, 0))
		
		local phys = self.arrow:GetPhysicsObject()
		if IsValid(phys) then
			-- Physics position must be in world coordinates; sync it from the arrow's updated world position
			phys:SetPos(self.arrow:GetPos())
			phys:SetAngles(self.arrow:GetAngles())
			phys:Wake()
		end
	end

	if self.lastSequenceOrder ~= self.sequenceOrder then
		self:UpdateNumberScale()
		self.lastSequenceOrder = self.sequenceOrder
	end
	
	self:CheckIsLookingAtNumber()

	self:NextThink(CurTime())
	return true
end

surface.CreateFont("Waymarker_Font", {
	font = "Trebuchet MS", 
	size = 96,             
	weight = 500,
	antialias = true,
	shadow = false,
	additive = false
})

function ENT:UpdateNumberScale()

	surface.SetFont("Waymarker_Font")
	local textStr = tostring(self.sequenceOrder)
	local fullWidth, _ = surface.GetTextSize(textStr)

	local scaleFactor = 0.175
	local sideBearingPixelsPerSide = 1.32

	self.numWidth = (fullWidth * scaleFactor) - (2 * sideBearingPixelsPerSide * scaleFactor)
end

function ENT:CheckIsLookingAtNumber()

	local pos = self:GetPos() + Vector(0, 0, 24)
	local rayStart = EyePos()
	local rayDir = EyeAngles():Forward()

	local t = (pos - rayStart):Dot(rayDir)

	if t >= 0 then
		local hitPos = rayStart + (rayDir * t)
		
		local diff = hitPos - pos
		local localX = diff:Dot(EyeAngles():Right())
		local localY = diff:Dot(EyeAngles():Up())
		
		if math.abs(localX) <= ((self.numWidth or 1) / 2) and math.abs(localY) <= 6 then
			self.IsLookAtNumber = true
			self.numLookDistance = t
		else
			self.IsLookAtNumber = false
			self.numLookDistance = nil
		end
	end
end

local function DrawWaypointNumbers()
	local ply = LocalPlayer()
	local wep = IsValid(ply) and ply:GetActiveWeapon()
	local targetEnt = (IsValid(wep) and wep.GetClass and wep:GetClass() == "weapon_doncombinesummoner") and wep.CommandTargetEnt or nil

	for _, ent in ipairs(ents.FindByClass("doncombine_waymarker")) do
		if IsValid(ent) then
			local parent = ent:GetParent()
			local target = IsValid(parent) and parent or ent
			
			local textPos = target:GetPos() + Vector(0, 0, 24)
			
			local ang = EyeAngles()
			ang:RotateAroundAxis(ang:Up(), -90)
			ang:RotateAroundAxis(ang:Forward(), 90)

			local isTargeted = (ent == targetEnt)
			local scale = 0.175
			
			cam.Start3D2D(textPos, ang, scale)
				local textStr = tostring(ent.sequenceOrder or 1)
				
				if isTargeted then
					draw.SimpleTextOutlined(textStr, "Waymarker_Font", 0, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(255, 100, 100, 65))
				else
					draw.SimpleText(textStr, "Waymarker_Font", 0, 0, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			cam.End3D2D()
		end
	end
end
hook.Add("PostDrawTranslucentRenderables", "DrawWaypointNumbersHook", DrawWaypointNumbers)