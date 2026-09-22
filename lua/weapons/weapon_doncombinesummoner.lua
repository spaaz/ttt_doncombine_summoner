if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName       = "DoncomSummoner"
	SWEP.ShopName = "Doncombine Summoner"
	SWEP.Author			= "Spaaz"
	SWEP.Contact			= "";
	SWEP.Instructions	= "Summons a Doncombine hostile to everyone except you."
	SWEP.Slot = 0
	SWEP.SlotPos = 1
	SWEP.IconLetter		= "M"
   	SWEP.Icon = "Doncombine64.png"
   	SWEP.EquipMenuData = {
      		type = "Weapon",
      		desc = "Summons a Doncombine hostile to \neveryone except you and any traitor\nteamates you may have."
   	};
	SWEP.CommandTargetEnt = nil
	SWEP.CanRightClick = true
end

	SWEP.Base = "weapon_tttbase"
	SWEP.InLoadoutFor = nil
	SWEP.AllowDrop = true
	SWEP.IsSilent = false
	SWEP.NoSights = false
	SWEP.LimitedStock = true

	SWEP.Spawnable = true
	SWEP.AdminOnly = false

	SWEP.HoldType              = "revolver"
	SWEP.ReloadHoldType        = "pistol"
	SWEP.ViewModel  = "models/weapons/v_pist_glock18.mdl"
	SWEP.WorldModel = "models/weapons/w_pist_glock18.mdl"
	SWEP.Kind = 42
	SWEP.CanBuy = { ROLE_TRAITOR }
	SWEP.AutoSpawnable = false

	SWEP.Primary.ClipSize		= 1
	SWEP.Primary.DefaultClip	= 1
	SWEP.Primary.Automatic		= false
	SWEP.Primary.Ammo		= "none"

	SWEP.Weight					= 7
	SWEP.DrawAmmo				= true
	SWEP.doncom			= nil
	
function SWEP:PrimaryAttack()
	if not SERVER then return end
	
	local ply = self:GetOwner()
	
	local tr = ply:GetEyeTrace()
	local tracedata = {}
	
	tracedata.pos = tr.HitPos + Vector(0,0,2)
	
	if self:Clip1() > 0 then
		
		
		local myPosition = ply:EyePos() + ( ply:GetAimVector() * 16 )
		local data = EffectData()
		data:SetOrigin( myPosition )

		util.Effect("MuzzleFlash", data)

        local spawnereasd = FindRespawnLocCust(tracedata.pos)
        if spawnereasd == false then
			ply:PrintMessage(HUD_PRINTTALK, "Can't Place there." )
        else
			if engine.ActiveGamemode() == "terrortown" then
				self:TakePrimaryAmmo(1)
			end
			
			tracedata.pos = spawnereasd
			place_doncom(tracedata, self, ply)
		
		end

	else
		self:EmitSound( "Weapon_AR2.Empty" )
	end
end


function SWEP:Equip()
	if ( not IsValid( self.Owner ) ) then return end
		if engine.ActiveGamemode() == "terrortown" then
			self.Owner:PrintMessage(HUD_PRINTTALK, "Doncombine Summoner:\nSummons a Doncombine hostile to everyone except\nyou and any traitor teamates you may have.")
		end
end

function FindRespawnLocCust(pos, ply)
    local offsets = {Vector(0,0,0)}

    for i = 0, 360, 15 do
        table.insert( offsets, Vector( math.sin( i ), math.cos( i ), 0 ) )
    end

	local midsize = Vector( 44, 44, 85 )
	local tstart   = pos + Vector( 0, 0, midsize.z / 2 )

	for i = 1, #offsets do
		local o = offsets[ i ]
		local v = tstart + o * midsize * 1.5

		local t = {
			start = v,
			endpos = v,
			filter = target,
			mins = midsize / -2,
			maxs = midsize / 2
		}

		local tr = util.TraceHull( t )

		if not tr.Hit then return ( v - Vector( 0, 0, midsize.z/2 ) ) end
		
	end 

	return false
end

function place_doncom( tracedata, self, owner )	
	if not SERVER then return end

	self.doncom = ents.Create( "npc_doncombine" )
	local owner = self:GetOwner()

	if ( not IsValid( self.doncom ) ) then return end

	if tracedata.pos then
		self.doncom:SetPos( tracedata.pos )
		local isTTT = false
		if engine.ActiveGamemode() == "terrortown" then
			isTTT = true
		end
		local isTraitor = false
		local savedTeam = nil
		if IsValid(owner) then
			isTraitor = isTTT and (owner:IsActiveTraitor() or (CR_VERSION and owner:IsActiveTraitorTeam()))
			if isTraitor then
				savedTeam = CR_VERSION and ROLE_TEAM_TRAITOR or 1
			else
				savedTeam = (CR_VERSION and isTTT) and owner:GetRoleTeam(true) or 0
			end
		end
		
		self.doncom:Spawn()
		if IsValid(self.doncom.npc) then
			local npc = self.doncom.npc
			local curPly = nil
			local curPlyPos = nil
			local curDist = math.huge	
			local npcPos = npc:GetPos()
			
			npc.Summoner = owner
			npc.WasTraitorSummon = isTraitor
			npc.savedTeam = savedTeam
			npc:SetNWInt( "savedTeam", savedTeam )
			npc:SetNWEntity( "Summoner", owner )
			
			for _, ply in ipairs( player.GetAll()) do
				if (IsValid(ply) and ply:Alive()) or (isTTT and ply:IsActive()) then
					if isTTT and npc.WasTraitorSummon then
						if ply:IsActiveTraitor() or (CR_VERSION and (ply:IsActiveTraitorTeam() or ply:IsActiveJesterTeam())) then
							npc:AddEntityRelationship(ply,D_LI,99)
						else
							npc:AddEntityRelationship(ply,D_HT,99)
						end
					else
						local team = 0
						if CR_VERSION and isTTT then
							team = ply:GetRoleTeam(true)
						elseif isTTT and ply:IsActiveTraitor() then
							team = 1
						end
						if (ply == npc.Summoner and team == npc.savedTeam) or ((CR_VERSION and isTTT) and ply:IsActiveJesterTeam()) then
							npc:AddEntityRelationship(ply,D_LI,99)
						else
							npc:AddEntityRelationship(ply,D_HT,99)
						end
					end
				end
				if ( npc:Disposition( ply ) == D_HT ) then
					local plyPos = ply:GetPos()
					local dist = npcPos:DistToSqr( plyPos )

					if ( dist < curDist ) then
						curPly = ply
						curPlyPos = plyPos
						curDist = dist
					end
				end					
			end
			if curPly then
				npc:SetEnemy( curPly )
				npc:UpdateEnemyMemory( curPly, curPlyPos )
			end
		end
	end
end

function SWEP:Holster(wep)
	if CLIENT then
		DoncombineClearWaypoints()
	end
	return true
end

function SWEP:SecondaryAttack()
    if not CLIENT then return end
	if not self.CanRightClick then return end
	self.CanRightClick = false
	timer.Simple(0.2, function() self.CanRightClick = true end)

    local ply = LocalPlayer()
    if not IsValid(ply) then return end
	
	local targetEnt = nil
	local targetPos = nil
	
	if self.CommandTargetEnt then
		if self.CommandTargetEnt:GetClass() == "doncombine_waymarker" then
			targetPos = self.CommandTargetEnt:GetPos()
		else
			targetEnt = self.CommandTargetEnt
		end
	else
		local traceFilter = { ply }
		for _, ent in ipairs(ents.GetAll()) do
			if IsValid(ent) and ent:GetCollisionGroup() == COLLISION_GROUP_WEAPON then
				table.insert(traceFilter, ent)
			end
		end
		local traceData = {}
		traceData.start = ply:EyePos()
		traceData.endpos = traceData.start + (ply:EyeAngles():Forward() * 4096) 
		traceData.filter = traceFilter
		traceData.hitclientonly = true
		traceData.mask = MASK_ALL

		local tr = util.TraceLine(traceData)

		if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then
			targetPos = tr.Entity:GetPos()
		elseif tr.Hit then
			targetPos = tr.HitPos
		end
	end

    if targetPos or IsValid(targetEnt) then
        net.Start("Doncombine_IssueCommand")
            net.WriteBool(IsValid(targetEnt))
            if IsValid(targetEnt) then
                net.WriteEntity(targetEnt)
            else
                net.WriteVector(targetPos)
            end
        net.SendToServer()
    end
end

function SWEP:Reload()
	return false
end

function SWEP:Think()
	if not CLIENT then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

	local traceData = {}
	traceData.start = ply:EyePos()
	traceData.endpos = traceData.start + (ply:EyeAngles():Forward() * 4096) 
	traceData.filter = ply
	traceData.hitclientonly = true
	traceData.mask = MASK_ALL

	local tr = util.TraceLine(traceData)

    local targetEnt = nil
	local bestNumberWaymarker = nil
    local lowestDist = math.huge

    local directEntity = tr.Entity
	
    if IsValid(directEntity) then
        if directEntity:GetClass() == "class C_PhysPropClientside" and IsValid(directEntity:GetParent()) then
            local parent = directEntity:GetParent()
            if parent:GetClass() == "doncombine_waymarker" then
                targetEnt = parent
            end
        end
		if directEntity:GetNWBool("doncombine", false) then
			targetEnt = directEntity
		end
    end

	for _, ent in ipairs(ents.FindByClass("doncombine_waymarker")) do
		if IsValid(ent) then
			if ent.IsLookAtNumber and ent.numLookDistance < lowestDist then
				lowestDist = ent.numLookDistance
				bestNumberWaymarker = ent
			end
		end
	end

    if bestNumberWaymarker then
        local traceDist = tr.Hit and traceData.start:Distance(tr.HitPos) or math.huge
        if lowestDist <= traceDist then
            targetEnt = bestNumberWaymarker
        end
    end

    self.CommandTargetEnt = targetEnt
end

if CLIENT then

	local heartForegroundMat = Material("vgui/ttt/sprite_npc_heart_foreground", "noclamp smooth")
	local heartBackgroundMat = Material("vgui/ttt/sprite_npc_heart_background", "noclamp smooth")
	
	net.Receive("Doncombine_PlayCommandSound", function(len)
        local isSuccess = net.ReadBool()
        
        if isSuccess then
            surface.PlaySound("buttons/button9.wav")
        else
            surface.PlaySound("buttons/button2.wav")
        end
    end)

	local function DrawDoncombineSprites()
		local client = LocalPlayer()
		local isTTT = false
		if engine.ActiveGamemode() == "terrortown" then
			isTTT = true
		end
		if (CR_VERSION and isTTT) and client:IsJesterTeam() then return end
		if isTTT and (not client:IsActive()) and (not (client:IsTraitor() or (CR_VERSION and client:IsTraitorTeam()))) then return end

		for _, npc in ipairs(ents.FindByClass("npc_hunter")) do
			if IsValid(npc) and npc:GetNWBool( "doncombine", false ) then

				local Summoner = npc:GetNWEntity( "Summoner", nil )
				local savedTeam = npc:GetNWInt( "savedTeam", -1 )
				local clientTeam = 0
				if (CR_VERSION and isTTT) then
					clientTeam = client:GetRoleTeam(true)
				elseif isTTT and client:IsTraitor() then
					clientTeam = 1
				end

				if ((clientTeam == 1) and (savedTeam == 1)) or (Summoner and (Summoner == client) and (clientTeam == savedTeam)) then
					local pos = npc:GetPos() + Vector(0, 0, npc:OBBMaxs().z + 15)
					local dir = client:GetForward() * -1
					local color = (clientTeam == 1) and Color(200, 25, 25, 255) or Color(75, 75, 75, 255)
					color = ColorAlpha(color, 130)
					
					render.SetMaterial(heartBackgroundMat)						
					render.DrawQuadEasy( pos, dir, 8, 8, color, 180)
					
					render.SetMaterial(heartForegroundMat)						
					render.DrawQuadEasy( pos, dir, 8, 8, Color(255, 255, 255, 255), 180)
					
				end
			end
		end
	end
	hook.Add("PostDrawTranslucentRenderables", "DrawDoncombineSprites", DrawDoncombineSprites)
	
	hook.Add("HUDPaint", "DrawDoncombineSummonerHUD", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_doncombinesummoner" then
			local scrW, scrH = ScrW(), ScrH()
			if IsValid(wep.CommandTargetEnt) then			
				draw.SimpleText("RMB:Remove Waypoint/s", "TargetID", scrW / 2 + 1, scrH / 2 + 21, Color(0, 0, 0, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("RMB:Remove Waypoint/s", "TargetID", scrW / 2, scrH / 2 + 20, Color(255, 0, 0, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("RMB:Create Waypoint", "TargetID", scrW / 2 + 1, scrH / 2 + 21, Color(0, 0, 0, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw.SimpleText("RMB:Create Waypoint", "TargetID", scrW / 2, scrH / 2 + 20, Color(0, 255, 0, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			for _, npc in ipairs(ents.FindByClass( "npc_hunter" )) do
				if IsValid(npc) and npc:GetNWBool("doncombine", false) then
					
					local isTTT = false
					if engine.ActiveGamemode() == "terrortown" then
						isTTT = true
					end
		
					local Summoner = npc:GetNWEntity( "Summoner", nil )
					local savedTeam = npc:GetNWInt( "savedTeam", -1 )
					local enemyName = npc:GetNWString("enemyName", "")
					local clientTeam = 0
					if (CR_VERSION and isTTT) then
						clientTeam = ply:GetRoleTeam(true)
					elseif isTTT and ply:IsTraitor() then
						clientTeam = 1
					end	
				
					if ((clientTeam == 1) and (savedTeam == 1)) or (Summoner and (Summoner == ply) and (clientTeam == savedTeam)) then
						local screenPos = (npc:GetPos() + Vector(0,0,60)):ToScreen()
						if screenPos.visible then
							local DisText = (tostring(math.floor(0.01905 * (ply:GetPos() - npc:GetPos()):Length())).."m")
							local IsAttacking = not (enemyName == "")
							local StatText = IsAttacking and "Attacking " .. enemyName or "Idle/Patroling"
							local color = IsAttacking and Color(255,0,0,150) or Color(0,255,0,150)
							surface.SetFont("TargetID")
							local _, textHight = surface.GetTextSize(StatText)
							
							local x = screenPos.x
							local y = screenPos.y - textHight - 4
							
							draw.SimpleText("Allied Doncombine", "TargetID", x + 1, y + 1,  Color(0,0,0,50),TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText("Allied Doncombine", "TargetID", x, y,  Color(255,255,255,150),TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							
							y = y + textHight + 4
							
							surface.SetFont("TargetIDSmall")
							_, textHight = surface.GetTextSize(StatText)
							
							draw.SimpleText(StatText, "TargetIDSmall", x + 1, y + 1,  Color(0,0,0,50),TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(StatText, "TargetIDSmall", x, y, color,TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)	
							
							y = y + textHight + 4
							
							draw.SimpleText(DisText, "TargetIDSmall", x + 1, y + 1,  Color(0,0,0,50),TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
							draw.SimpleText(DisText, "TargetIDSmall", x, y, Color(255,255,255,150),TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)							
						end
					end
				end
			end	
		end
	end)

	hook.Add("PreDrawHalos", "DoncombineSummonerHalos", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_doncombinesummoner" and IsValid(wep.CommandTargetEnt) then
			if wep.CommandTargetEnt:GetNWBool("doncombine", false) then
				halo.Add({wep.CommandTargetEnt}, Color(255, 100, 100), 2, 2, 2, true, true)
			elseif wep.CommandTargetEnt:GetClass() == "doncombine_waymarker" and IsValid(wep.CommandTargetEnt.arrow) and IsValid(wep.CommandTargetEnt.base) then
				halo.Add({wep.CommandTargetEnt.arrow}, Color(255, 100, 100), 2, 2, 2, true, true)
				halo.Add({wep.CommandTargetEnt.base}, Color(255, 100, 100), 2, 2, 2, true, true)
			end
		end
	end)
	
	net.Receive("Doncombine_SyncWaypoints", function(len)
		local nestedWaypointLists = net.ReadTable()
		local syncedLocations = {}

		-- 1. Check existing waymarkers against the updated nested list
		for _, ent in ipairs(ents.FindByClass("doncombine_waymarker")) do
			if IsValid(ent) then
				local foundPos, foundIndex = nil, nil

				for _, subList in ipairs(nestedWaypointLists) do
					for idx, wpPos in ipairs(subList) do
						if ent:GetPos():DistToSqr(wpPos) < 1 then
							foundPos = wpPos
							foundIndex = idx
							break
						end
					end
					if foundPos then break end
				end

				if foundPos then

					ent.sequenceOrder = foundIndex		
					table.insert(syncedLocations, foundPos)
				else
					if IsValid(ent) then
						if ent.arrow and IsValid(ent.arrow) then
							ent.arrow:Remove()
						end
						if ent.base and IsValid(ent.base) then
							ent.base:Remove()
						end
						ent:Remove()
					end
				end
			end
		end

		-- 2. Create new client-side custom waymarkers for remaining updated locations
		for _, subList in ipairs(nestedWaypointLists) do
			for idx, wpPos in ipairs(subList) do
				local alreadySynced = false
				for _, syncedPos in ipairs(syncedLocations) do
					if syncedPos:DistToSqr(wpPos) < 1 then
						alreadySynced = true
						break
					end
				end
				if not alreadySynced then
				
					-- Spawn model elements
					local base = ents.CreateClientProp("models/waymarker/waymarker_base.mdl")
					if IsValid(base) then
						base:SetPos(wpPos)
						base.IsWaymarker = true
						base:Spawn()
					end
					
					local arrow = ents.CreateClientProp("models/waymarker/waymarker_arrow.mdl")
					if IsValid(arrow) then							
						arrow:SetPos(wpPos)
						arrow.IsWaymarker = true
						arrow:Spawn()
					end
					
					local models = {base, arrow}
					for _, mdl in ipairs(models) do
						local phys = mdl:GetPhysicsObject()
						if IsValid(phys) then
							phys:EnableGravity(false)
							phys:EnableMotion(mdl ~= base)
							phys:Wake()
						end
						mdl:SetCollisionGroup(COLLISION_GROUP_WORLD)
					end
					
					if IsValid(base) and IsValid(arrow) then
						
						local marker = ents.CreateClientside("doncombine_waymarker")
						if IsValid(marker) then
							marker:SetPos(wpPos)
							marker.sequenceOrder = idx
							marker.base = base
							marker.arrow = arrow
							marker:Spawn()
						
							base:SetParent(marker)
							arrow:SetParent(marker)
						
							table.insert(syncedLocations, wpPos)
						
						end
					end
				end
			end
		end
	end)
	
	function DoncombineClearWaypoints()
		for _, ent in ipairs(ents.FindByClass("doncombine_waymarker")) do
			if IsValid(ent) then
				if ent.arrow and IsValid(ent.arrow) then
					ent.arrow:Remove()
				end
				if ent.base and IsValid(ent.base) then
					ent.base:Remove()
				end
				ent:Remove()
			end		
		end
	end
	
	net.Receive("TTT_BeginRound", function()
        DoncombineClearWaypoints()
    end)
	
	net.Receive("Doncombine_ClearWaypoints", function()
		DoncombineClearWaypoints()
	end)
end