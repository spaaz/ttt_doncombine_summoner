if SERVER then
	AddCSLuaFile()
end

if CLIENT then
	SWEP.PrintName       = "DoncomSummoner"
	SWEP.ShopName = "Doncombine Summoner"
	SWEP.Author			= "Spaaz (with credit to AviLouden,TRGraphix,Mangonaut,Jenssons)"
	SWEP.Contact			= "";
	SWEP.Instructions	= "Target on upside of a flat surface"
	SWEP.Slot = 0
	SWEP.SlotPos = 1
	SWEP.IconLetter		= "M"
   	SWEP.Icon = "Doncombine64.png"
   	SWEP.EquipMenuData = {
      		type = "Weapon",
      		desc = "Summons a Doncombine hostile to anyone\nnot on the traitor team"
   	};
end

	SWEP.Base = "weapon_tttbase"
	SWEP.InLoadoutFor = nil
	SWEP.AllowDrop = true
	SWEP.IsSilent = false
	SWEP.NoSights = false
	SWEP.LimitedStock = true

	SWEP.Spawnable = true
	SWEP.AdminOnly = false

	SWEP.HoldType		= "pistol"
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

	local ply = self:GetOwner()
	
	local tr = ply:GetEyeTrace()
	local tracedata = {}
	
	tracedata.pos = tr.HitPos + Vector(0,0,2)
    
	if (!SERVER) then return end
	
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
		
			place_doncom(tracedata, self)
		
		end

	else
		self:EmitSound( "Weapon_AR2.Empty" )
	end
end


function SWEP:Equip()
	if ( !IsValid( self.Owner ) ) then return end
		if engine.ActiveGamemode() == "terrortown" then
			self.Owner:PrintMessage(HUD_PRINTTALK, "Doncombine Summoner:\nSummons a Doncombine hostile to anyone\nnot on the traitor team")
		end
end

function FindRespawnLocCust(pos, ply)
    local offsets = {}

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
		--ply:LagCompensation( true )
            local tr = util.TraceHull( t )
		--ply:LagCompensation( false )

            if not tr.Hit then return ( v - Vector( 0, 0, midsize.z/2 ) ) end
            
        end 

        return false
end

function place_doncom( tracedata, self )
	
	if ( CLIENT ) then return end

	self.doncom = ents.Create( "npc_doncombine" )
	local owner = self:GetOwner()

	if ( !IsValid( self.doncom ) ) then return end

            local spawnereasd = FindRespawnLocCust(tracedata.pos, owner)
            if spawnereasd == false then
            else
				self.doncom:SetPos( spawnereasd )
				self.doncom:Spawn()
				if IsValid(self.doncom.npc) then
					local npc = self.doncom.npc
					local curPly = nil
					local curPlyPos = nil
					local curDist = math.huge	
					local npcPos = npc:GetPos()	
					for _, ply in ipairs( player.GetAll()) do
					if engine.ActiveGamemode() == "terrortown" then
						if ply:Alive() and not ply:IsSpec() then	
								if ply:IsActiveTraitor() or (CR_VERSION and ply:IsActiveTraitorTeam()) then
									npc:AddEntityRelationship(ply,D_LI,99)
								else
									npc:AddEntityRelationship(ply,D_HT,99)
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
					end
					if curPly then
						npc:SetEnemy( curPly )
						npc:UpdateEnemyMemory( curPly, curPlyPos )
					end
				end
            end

	
	--local phys = self.doncom:GetPhysicsObject()
	--if ( !IsValid( phys ) ) then self.doncom:Remove() return end
end


	
	function SWEP:SecondaryAttack()

		self:PrimaryAttack()

	end

	function SWEP:Reload()
		return false
	end

if CLIENT then

end