AddCSLuaFile( 'shared.lua' )
include( 'shared.lua' )

function ENT:SpawnFunction( tr )

	if not tr.Hit then return end
	
	local ent = ents.Create( "npc_doncombine" )
	ent:Spawn()
	ent:Activate()
	
	return ent

end

function ENT:Initialize()	

	self:SetModel( "models/items/battery.mdl" )
	self:SetNoDraw(true)
	self:DrawShadow(false)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetName(self.PrintName)
	self:SetOwner(self.Owner)

	self.npc = ents.Create( "npc_hunter" )
	self.npc:SetPos(self:GetPos())
	self.npc:SetAngles(self:GetAngles())
	self.npc:SetSpawnEffect(false)
	--self.npc:SetKeyValue("SpawnFlags",1280)
	self.npc:Spawn()
	self.npc:Activate()
	self.npc:SetName("Doncombine")
	--PrintMessage(HUD_PRINTTALK,tostring(self.npc:GetSpawnFlags()))
	self:SetParent(self.npc)
	local doncomhealth = GetConVar("ttt_doncombine_health"):GetFloat()
	self.npc:SetHealth(doncomhealth)
	self.npc:SetMaxHealth(doncomhealth)

	if( IsValid(self.npc))then
		local min,max = self.npc:GetCollisionBounds()
		local hull = self.npc:GetHullType()
		self.npc:SetModel("models/doncombine.mdl")
		self.npc:SetSolid(SOLID_BBOX)
		self.npc:SetName("Doncombine")
		self.npc:SetMoveType( MOVETYPE_STEP ) 
		self.npc:SetPos(self.npc:GetPos())
		self.npc:SetHullType(hull)
		self.npc:SetHullSizeNormal()
		self.npc:SetCollisionBounds(min,max)
		self.npc:DropToFloor()
		self.npc:SetModelScale(1)
	end
	
end


if ( SERVER ) then
	local NextTime = CurTime()
	local function DoncombineRelationship()
		if CurTime() > NextTime then
			NextTime = CurTime() + 0.08
			for k, ent in ipairs(ents.FindByClass( "npc_doncombine" )) do
				local npc = ent.npc
				if IsValid(npc) and npc:IsNPC() then		
					if engine.ActiveGamemode() == "terrortown" then	
						for _, ply in ipairs( player.GetAll()) do
							if ply:Alive() and not ply:IsSpec() then
								if ply:IsActiveTraitor() or (CR_VERSION and ply:IsActiveTraitorTeam()) then
									npc:AddEntityRelationship(ply,D_LI,99)
								else
									npc:AddEntityRelationship(ply,D_HT,99)
								end
							end
						end
					end
					for j, ent2 in ipairs(ents.FindByClass( "npc_antlionguard" )) do
						if ent2:IsNPC() then
							npc:AddEntityRelationship(ent2,D_LI,99)
							ent2:AddEntityRelationship(npc,D_LI,99)
						end
					end
					local enemy = npc:GetEnemy()
					if IsValid(enemy) and IsEntity(enemy) and enemy:IsPlayer() and (npc:GetEnemyLastTimeSeen()+ 8 > CurTime()) then
						npc.lastenemy = enemy
						npc.timerset = false
						local pos = npc:GetPos()
						local moveto = enemy:GetPos()
						local vec = moveto - pos
						local length = vec:Length() 
						if npc:GetEnemyLastTimeSeen(enemy) + 1 < CurTime() then
							local lsp = npc:GetEnemyLastSeenPos(enemy)
							moveto = lsp - moveto
							moveto:Normalize()
							moveto = npc:GetEnemyLastSeenPos(enemy) + (moveto * 30)
							if moveto then
								vec = moveto - pos
								length = vec:Length()
								if length > 80 then
									vec:Normalize()
									npc:SetLastPosition(pos + (vec * 80) + Vector(0,0,80))
									npc:SetSchedule(SCHED_FORCED_GO_RUN)
								elseif length <= 80 and length > 30 then
									vec:Normalize()
									npc:SetLastPosition(moveto)
									npc:SetSchedule(SCHED_FORCED_GO_RUN)
								end
							end
						elseif length > 1200 then
							if vec.z < 400 and vec.z > -400 then
								vec:Normalize()
								npc:SetLastPosition(pos + (vec * 80) + Vector(0,0,80))
								npc:SetSchedule(SCHED_FORCED_GO_RUN)
							end
						end
					else
						for _, ent in ipairs(ents.FindInSphere(npc:GetPos(),1200)) do
							if ent:IsPlayer() and ent:Alive() then
								local dis = npc:Disposition(ent)
								if dis == 1 then
									if npc:IsLineOfSightClear(ent) then
										npc:SetEnemy( ent )
										npc:UpdateEnemyMemory( ent, ent:GetPos() )
									end
								end
							end
						end
					end
				end
			end
			if GetConVar("ttt_doncombine_is_tracking_shot"):GetBool() then
				for k, ent in ipairs(ents.FindByClass( "hunter_flechette" )) do
					if IsValid(ent.Owner) then
					
						if ent.Owner:GetName() == "Doncombine" then
							local enemy = ent.Owner:GetEnemy()
							if enemy then
								if !(ent:GetMoveType() == MOVETYPE_NONE) then
									local Vel = ent:GetAbsVelocity()
									if Vel:Length()>500 then
										local VelMod = enemy:GetPos() + Vector(0,0,20) - ent:GetPos()
										local LenMod = VelMod:Length()*-2 + 2000
										if LenMod > 0 then

											Vel:Normalize()
											VelMod:Normalize()
											local Dot = Vel:Dot(VelMod)
											VelMod = VelMod - Vel*Dot
		
											VelMod = VelMod*LenMod + ent:GetAbsVelocity()
											VelMod:Normalize()
											ent:SetAngles(VelMod:Angle()+ Angle(-8,0,0))

											ent:SetVelocity( (VelMod * 2500)-ent:GetAbsVelocity())
										end
									end
								end
							end
						end
					end 
				end					
			end
		end
	end
	
	hook.Add("Think", "DoncombineRelationship", DoncombineRelationship)

	local function DoncombineDamage(target, dmginfo)

		if IsValid(dmginfo:GetAttacker():GetClass()) then
			if dmginfo:GetAttacker():GetClass() == "npc_hunter" and dmginfo:GetAttacker():GetName() == "Doncombine" then
				if GetGlobalBool( "CRismounted", false ) and engine.ActiveGamemode() == "terrortown" then
					if target:IsPlayer() then
						if target:IsJesterTeam() and !target:GetNWBool("KillerClownActive", false) then
							dmginfo:SetDamage(0)
						end
					end
				end
				if target:GetClass() == "npc_antlionguard" then
					dmginfo:SetDamage(0)
				end			
			elseif dmginfo:GetAttacker():GetClass() == "npc_antlionguard" then
				if GetGlobalBool( "CRismounted", false ) and engine.ActiveGamemode() == "terrortown" then
					if target:IsPlayer() then
						if target:IsJesterTeam() then
							dmginfo:SetDamage(0)
						end
					end
				end
				if target:GetClass() == "npc_hunter" and target:GetName() == "Doncombine" then
					dmginfo:SetDamage(0)
				end	
			end
		end
		if target:GetClass() == "npc_hunter" and target:GetName() == "Doncombine" then
			if dmginfo:IsBulletDamage() and GetConVar("ttt_doncombine_extra_armor"):GetBool() then
				if dmginfo:GetDamage() <= 12 then
					dmginfo:ScaleDamage( 0.5 )
				elseif dmginfo:GetDamage() < 24 then
					dmginfo:ScaleDamage( dmginfo:GetDamage()/24 )
				end
			end
			--PrintMessage(HUD_PRINTTALK,tostring(dmginfo:IsBulletDamage())..":"..tostring(dmginfo:GetDamage()))
		end
	end

	hook.Add( "EntityTakeDamage", "DoncombineDamage", DoncombineDamage)
end