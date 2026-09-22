AddCSLuaFile( 'shared.lua' )
include( 'shared.lua' )

if SERVER then
	AddCSLuaFile()
end

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
	self.npc:Spawn()
	self.npc:Activate()
	self.npc:SetName("Doncombine")
	self.npc.ScoreName = "Doncombine"
	self.npc:SetNWBool( "doncombine", true )
	self.npc:SetNWString("enemyName", "")
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
		self.npc:SetCurrentWeaponProficiency(WEAPON_PROFICIENCY_PERFECT)
		self.npc:SetMaxLookDistance(8000)
	end
	
end


if SERVER then

	util.AddNetworkString("Doncombine_IssueCommand")
	util.AddNetworkString("Doncombine_SyncWaypoints")
	util.AddNetworkString("Doncombine_ClearWaypoints")
	util.AddNetworkString("Doncombine_PlayCommandSound")

	-- Track previous active weapon states to detect when players stop holding the summoner
	local previousActiveWeapons = {}
	
	local function GetPrettyClassName(class)
		class = class:gsub("npc_", "")
		class = class:gsub("_", " ")	
		return (class:gsub("(%a)([%w_]*)", function(first, rest)
			return first:upper() .. rest:lower()
		end))
	end

	local function ProcessAndSyncPlayerWaypoints()
		for _, ply in ipairs(player.GetAll()) do
			if not IsValid(ply) or not ply:Alive() then continue end

			local activeWeapon = ply:GetActiveWeapon()
			local hasSummoner = IsValid(activeWeapon) and activeWeapon:GetClass() == "weapon_doncombinesummoner"
			local wasHoldingSummoner = previousActiveWeapons[ply] or false

			-- Detect when a player stops holding the weapon
			if wasHoldingSummoner and not hasSummoner then
				net.Start("Doncombine_ClearWaypoints")
				net.Send(ply)
			end
			previousActiveWeapons[ply] = hasSummoner
			
			local isTTT = false
			if engine.ActiveGamemode() == "terrortown" then
				isTTT = true
			end

			-- If holding the summoner, compile and send unique nested waypoint segments
			if hasSummoner then
				local isTraitor = isTTT and (ply:IsActiveTraitor() or (CR_VERSION and ply:IsActiveTraitorTeam()))
				local playerTeam = 0
				if CR_VERSION then
					playerTeam = ply:GetRoleTeam(true)
				elseif isTraitor then
					playerTeam = 1
				end

				-- Gather allied Doncombines with waypoints for this specific player
				local alliedDoncombines = {}
				for _, ent in ipairs(ents.FindByClass("npc_doncombine")) do
					local npc = ent.npc
					if IsValid(npc) and npc:IsNPC() and npc.waypoints and #npc.waypoints > 0 then
						local isAllied = false
						if npc.WasTraitorSummon then
							if isTraitor then
								isAllied = true
							end
						else
							if (npc.Summoner == ply and playerTeam == npc.savedTeam) then
								isAllied = true
							end
						end

						if isAllied then
							table.insert(alliedDoncombines, npc)
						end
					end
				end

				-- Sort allied Doncombines by waypoint list length (longest first)
				table.sort(alliedDoncombines, function(a, b)
					return #a.waypoints > #b.waypoints
				end)

				-- Build nested sharedWaypoints segments, filtering overlaps
				local nestedWaypointLists = {}
				for _, npc in ipairs(alliedDoncombines) do
					local currentSegment = nil

					for _, wp in ipairs(npc.waypoints) do
						local isSharedWithPrevious = false

						-- Check against all already recorded nested lists
						for _, existingList in ipairs(nestedWaypointLists) do
							for _, existingWp in ipairs(existingList) do
								if existingWp:DistToSqr(wp) < 1 then
									isSharedWithPrevious = true
									break
								end
							end
							if isSharedWithPrevious then break end
						end

						if isSharedWithPrevious then
							-- If it overlaps with a previous list, terminate the current segment tracking
							currentSegment = nil
						else
							-- Unique waypoint: add to current segment or start a new nested list
							if not currentSegment then
								currentSegment = {}
								table.insert(nestedWaypointLists, currentSegment)
							end
							table.insert(currentSegment, wp)
						end
					end
				end

				-- Send the nested table to the client
				net.Start("Doncombine_SyncWaypoints")
					net.WriteTable(nestedWaypointLists)
				net.Send(ply)
			end
		end
	end

	local nextWaypointSync = 0
	hook.Add("Think", "DoncombineWaypointSync", function()
		if CurTime() > nextWaypointSync then
			nextWaypointSync = CurTime() + 0.5
			ProcessAndSyncPlayerWaypoints()
		end
	end)

	local nodeCount = nil

	local function ProcessDoncombineCommand(ply)
        local commandPassed = false
        local targetEnt = ply.targetEnt
        local targetPos = ply.targetPos
        
        -- Clear the player's pending target data immediately
        ply.targetEnt = nil
        ply.targetPos = nil

        if not targetEnt and not targetPos then return end
		
		local isTTT = false
		if engine.ActiveGamemode() == "terrortown" then
			isTTT = true
		end

        -- 1. Identify if the player is a traitor or standard summoner
        local isTraitor = isTTT and (ply:IsActiveTraitor() or (CR_VERSION and ply:IsActiveTraitorTeam()))
        local playerTeam = 0
        if CR_VERSION and isTTT then
            playerTeam = ply:GetRoleTeam(true)
        elseif isTraitor then
            playerTeam = 1
        end

        -- 2. Gather only the Doncombines relevant to this specific player
        local groupDoncombines = {}
        for _, ent in ipairs(ents.FindByClass("npc_doncombine")) do
            local npc = ent.npc
            if IsValid(npc) and npc:IsNPC() then
                local enemy = npc:GetEnemy()
                local hasEnemy = (IsValid(enemy) and IsEntity(enemy))

                if not hasEnemy then
                    if npc.WasTraitorSummon and isTraitor then
                        table.insert(groupDoncombines, npc)
                    elseif not npc.WasTraitorSummon then
                        if npc.Summoner == ply and playerTeam == npc.savedTeam then
                            table.insert(groupDoncombines, npc)
                        end
                    end
				end
            end
        end

        if #groupDoncombines == 0 then
			ply:PrintMessage(HUD_PRINTTALK, "No idle or patroling allied Doncombine available to command")
			net.Start("Doncombine_PlayCommandSound")
				net.WriteBool(false)
			net.Send(ply)
		return 
		end

        -- 3. Sort Doncombines by longest waypoint list first
        table.sort(groupDoncombines, function(a, b)
            local lenA = (a.waypoints and #a.waypoints) or 0
            local lenB = (b.waypoints and #b.waypoints) or 0
            return lenA > lenB
        end)

        -- 4. Build shared waypoints for this group only
        local sharedWaypoints = {}
        for _, npc in ipairs(groupDoncombines) do
            if npc.waypoints then
                for _, wp in ipairs(npc.waypoints) do
                    local isDuplicate = false
                    for _, existingWp in ipairs(sharedWaypoints) do
                        if existingWp:DistToSqr(wp) < 1 then
                            isDuplicate = true
                            break
                        end
                    end
                    if not isDuplicate then
                        table.insert(sharedWaypoints, wp)
                    end
                end
            end
        end

        -- 5. Apply waypoint mutations based on command type
        if IsValid(targetEnt) then
            local clearedCount = 0
            for _, npc in ipairs(groupDoncombines) do
                if npc == targetEnt then
                    if npc.waypoints and #npc.waypoints > 0 then
                        clearedCount = #npc.waypoints
                        npc.waypoints = nil
                    end
                    break
                end
            end

            if clearedCount > 0 then
                if clearedCount == 1 then
                    ply:PrintMessage(HUD_PRINTTALK, "Waypoint removed")
                else
                    ply:PrintMessage(HUD_PRINTTALK, tostring(clearedCount) .. " waypoints removed")
                end
                commandPassed = true
            else
                ply:PrintMessage(HUD_PRINTTALK, "Doncombine has no waypoints to remove")
            end
        elseif targetPos then
            local isInShared = false
            for _, swp in ipairs(sharedWaypoints) do
                if swp:DistToSqr(targetPos) < 1 then
                    isInShared = true
                    break
                end
            end

            if isInShared then
                local clearedCount = 0 
                for _, npc in ipairs(groupDoncombines) do
                    if npc.waypoints and #npc.waypoints > 0 then
                        local targetIndex = nil
                        for i, wp in ipairs(npc.waypoints) do
                            if wp:DistToSqr(targetPos) < 1 then
                                targetIndex = i
                                break
                            end
                        end
                        if targetIndex then
                            for i = #npc.waypoints, targetIndex, -1 do
                                clearedCount = clearedCount + 1
                                table.remove(npc.waypoints, i)
                            end
                        end
                    end
                end

                if clearedCount > 0 then
                    if clearedCount == 1 then
                        ply:PrintMessage(HUD_PRINTTALK, "Waypoint removed")
                    else
                        ply:PrintMessage(HUD_PRINTTALK, tostring(clearedCount) .. " waypoints removed")
                    end                        
                    commandPassed = true
                end
            else
                local waypointCreated = false
                local nodeCount = ai.GetNodeCount()

                for _, npc in ipairs(groupDoncombines) do
                    local refPos = nil
                    if npc.waypoints and #npc.waypoints > 0 then
                        refPos = npc.waypoints[#npc.waypoints]
                    else
                        refPos = npc:GetPos()
                    end

                    local ignoreEntities = {}
                    table.Add(ignoreEntities, player.GetAll())
                    table.Add(ignoreEntities, ents.FindByClass("npc_*"))

                    local tr = util.TraceLine({
                        start = refPos + Vector(0, 0, 64),
                        endpos = targetPos + Vector(0, 0, 64),
                        mask = MASK_SOLID,
                        filter = ignoreEntities
                    })

                    if not tr.Hit then
                        if not npc.waypoints then
                            npc.waypoints = { targetPos }
                        else
                            table.insert(npc.waypoints, targetPos)
                        end
                        waypointCreated = true
                        commandPassed = true
                    end
                end

                if waypointCreated then
                    ply:PrintMessage(HUD_PRINTTALK, "Waypoint created")
                else
                    ply:PrintMessage(HUD_PRINTTALK, "Could not find clear path")
                end
            end
        end

        net.Start("Doncombine_PlayCommandSound")
            net.WriteBool(commandPassed)
        net.Send(ply)
    end
	
	net.Receive("Doncombine_IssueCommand", function(len, ply)
        if not IsValid(ply) or not ply:Alive() then return end

        local isEntityTarget = net.ReadBool()
        if isEntityTarget then
            ply.targetEnt = net.ReadEntity()
            ply.targetPos = nil
        else
            ply.targetEnt = nil
            ply.targetPos = net.ReadVector()
        end

        ProcessDoncombineCommand(ply)
    end)
	
	local NextTime = CurTime()
	
	local function DoncombineRelationship()
		if CurTime() > NextTime then
			NextTime = CurTime() + 0.08
			for k, ent in ipairs(ents.FindByClass( "npc_doncombine" )) do
				local npc = ent.npc
				if IsValid(npc) and npc:IsNPC() then		
					if engine.ActiveGamemode() == "terrortown" then	
						for _, ply in ipairs( player.GetAll()) do
							if ply:IsActive() then
								if npc.WasTraitorSummon then
									if ply:IsActiveTraitor() or (CR_VERSION and (ply:IsActiveTraitorTeam() or ply:IsActiveJesterTeam())) then
										npc:AddEntityRelationship(ply,D_LI,99)
									else
										npc:AddEntityRelationship(ply,D_HT,99)
									end
								else
									local team = 0
									if CR_VERSION then
										team = ply:GetRoleTeam(true)
									elseif ply:IsActiveTraitor() then
										team = 1
									end	
									if (npc.savedTeam and ply == npc.Summoner and team == npc.savedTeam) or (CR_VERSION and ply:IsActiveJesterTeam()) then
										npc:AddEntityRelationship(ply,D_LI,99)
									else
										npc:AddEntityRelationship(ply,D_HT,99)
									end
								end
							end
						end
					end
					for _, ent2 in ipairs(ents.FindByClass( "npc_antlionguard" )) do
						if ent2:IsNPC() then
							npc:AddEntityRelationship(ent2,D_LI,99)
							ent2:AddEntityRelationship(npc,D_LI,99)
						end
					end
					local enemy = npc:GetEnemy()
					nodeCount = nodeCount or ai.GetNodeCount()
					local hasEnemy = (IsValid(enemy))
					local hasPlayerEnemy = (hasEnemy and enemy:IsPlayer())
					local pos = npc:GetPos()
					
					if hasEnemy then
						if hasPlayerEnemy then
							npc:SetNWString("enemyName", enemy:Nick() or "")
						else
							if enemy.ScoreName and enemy.ScoreName ~= "" then
								npc:SetNWString("enemyName", enemy.ScoreName)
							else
								local className = enemy:GetClass()
								className = className or ""
								local niceName = GetPrettyClassName(className)
								npc:SetNWString("enemyName", niceName )
							end
						end
						if npc.CommandMovePos then
							npc.SendNewCommandOrder = false
							npc.NextCommandUpdate = nil
							npc.CommandMovePos = nil
							npc.CommandMovePosSlice = nil
							npc.waypoints = nil
						end
						
						if (npc:GetEnemyLastTimeSeen()+ 5 > CurTime()) then
							if (nodeCount < 6) and hasPlayerEnemy then
								npc.lastenemy = enemy
								npc.timerset = false
								local moveto = enemy:GetPos()
								local vec = moveto - pos
								local length = vec:Length() 
								if ((npc:GetEnemyLastTimeSeen(enemy) + 1) < CurTime()) then
									local lsp = npc:GetEnemyLastSeenPos(enemy)
									moveto = lsp - moveto
									moveto:Normalize()
									moveto = npc:GetEnemyLastSeenPos(enemy) + (moveto * 45)
									if moveto then
										vec = moveto - pos
										length = vec:Length()
										if length > 80 then
											vec:Normalize()
											npc:SetLastPosition(pos + (vec * 80) + Vector(0,0,80))
											npc:SetSchedule(SCHED_FORCED_GO_RUN)
										elseif length <= 80 and length > 30 then
											npc:SetLastPosition(moveto)
											npc:SetSchedule(SCHED_FORCED_GO_RUN)
										end
									end
								elseif length > 1200 then
									if vec.z < 800 and vec.z > -800 then
										vec:Normalize()
										npc:SetLastPosition(pos + (vec * 80) + Vector(0,0,80))
										npc:SetSchedule(SCHED_FORCED_GO_RUN)
									end
								end			
							end
						end
					else
						
						npc.LastCheckPos2 = nil
						npc.StuckCheckTimer2 = nil
						npc:SetNWString("enemyName", "")
						
						-- Ensure waypoints exist and map them to CommandMovePos if needed
						if npc.waypoints and #npc.waypoints > 0 then
							if (not npc.CommandMovePos) or (npc.CommandMovePos ~= npc.waypoints[1]) then
								npc.CommandMovePos = npc.waypoints[1]
								npc.SendNewCommandOrder = true
								if not npc:IsCurrentSchedule(SCHED_FORCED_GO) then
									npc.NextCommandUpdate = CurTime() + 0.5
								end
							end
						else
							npc.SendNewCommandOrder = false
							npc.NextCommandUpdate = nil
							npc.CommandMovePos = nil
						end
						
						if npc.CommandMovePos then
							if npc.NextCommandUpdate and CurTime() > npc.NextCommandUpdate then								
								npc.NextCommandUpdate = CurTime() + 0.1
								if (not npc:IsCurrentSchedule(SCHED_FORCED_GO)) then
									npc.SendNewCommandOrder = true
								end
							end

							local squaredLength = pos:DistToSqr(npc.CommandMovePos)
							
							if npc.SendNewCommandOrder then
								if squaredLength > 6400 then
									local vec = npc.CommandMovePos - pos
									vec:Normalize()
									local abovePos = pos + (vec * 70) + Vector(0,0,80)
									
									local groundTrace = util.TraceLine({
										start = abovePos,
										endpos = abovePos - Vector(0, 0, 180),
										mask = MASK_SOLID,
										filter = { npc, ply }
									})
									
									if groundTrace.Hit then
										npc.CommandMovePosSlice = groundTrace.HitPos
										npc:SetLastPosition(npc.CommandMovePosSlice)
										npc:SetSchedule(SCHED_FORCED_GO)
										npc.SendNewCommandOrder = false
									else
										npc.CommandMovePos = nil
										npc.waypoints = nil
										npc:SetLastPosition(pos)
										npc:SetSchedule(SCHED_FORCED_GO)
										npc.SendNewCommandOrder = false
										npc.NextCommandUpdate = nil
										npc.CommandMovePosSlice = nil
									end								
								else
									npc:SetLastPosition(npc.CommandMovePos)
									npc:SetSchedule(SCHED_FORCED_GO)
									npc.SendNewCommandOrder = false
								end
							end
							
							if squaredLength < 900 then
								if npc.waypoints then
									table.remove(npc.waypoints, 1)
									if #npc.waypoints == 0 then
										npc.waypoints = nil
										npc.CommandMovePos = nil
									else
										npc.CommandMovePos = npc.waypoints[1]
									end
								else
									npc.CommandMovePos = nil
								end
							end
							
							if npc.CommandMovePosSlice then
								local squaredLength2 = pos:DistToSqr(npc.CommandMovePosSlice)
								if squaredLength2 < 900 then
									npc.SendNewCommandOrder = true
									npc.CommandMovePosSlice = nil
								end
							end
							
						end
						
						for _, ent in ipairs(ents.FindInSphere(pos, 1200)) do
							if IsValid(ent) and ent:IsNPC() or (ent:IsPlayer() and ent:Alive() and ent:Team() ~= TEAM_SPECTATOR) then
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
					
					if (CurTime() > (npc.StuckCheckTimer or 0)) and ((hasEnemy and (npc:GetEnemyLastTimeSeen()+ 5 < CurTime())) or (not hasEnemy)) then
						npc.StuckCheckTimer = CurTime() + 2
						if (not npc.waypoints) or #npc.waypoints == 0 then
							local act = math.random(24)			
							if act == 12 then
								npc:SetSchedule(108)
							elseif act == 6 then
								npc:SetSchedule(109)
							end
						end
						if npc.LastCheckPos and pos:DistToSqr(npc.LastCheckPos) < 50 then
							npc:SetLastPosition(pos)
							npc.CommandMovePos = nil
							npc.waypoints = nil
							npc:ClearBlockingEntity()
							npc:SetSchedule(116)
							npc.SendNewCommandOrder = false
							npc.NextCommandUpdate = nil

						else
							npc.LastCheckPos = pos
						end
					end
				end
			end
			if GetConVar("ttt_doncombine_is_tracking_shot"):GetBool() then
				for k, ent in ipairs(ents.FindByClass( "hunter_flechette" )) do
					if IsValid(ent.Owner) then
					
						if ent.Owner:GetName() == "Doncombine" then
							ent.ScoreName = "Doncombine Flechette"
							local enemy = ent.Owner:GetEnemy()
							if enemy then
								if !(ent:GetMoveType() == MOVETYPE_NONE) then
									local Vel = ent:GetAbsVelocity()
									if Vel:Length()>500 then
										local VelMod = enemy:GetPos() + Vector(math.random(-2,2),math.random(-2,2),25 + math.random(20)) - ent:GetPos()
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
	
		local att = dmginfo:GetAttacker()
		if IsValid(att) then
		
			local attClass = att:GetClass()
			local targetClass = target:GetClass()
			
			if attClass == "npc_hunter" and att:GetName() == "Doncombine" then
				if CR_VERSION and engine.ActiveGamemode() == "terrortown" then
					if target:IsPlayer() then
						if target:IsJesterTeam() or att.savedTeam == ROLE_TEAM_JESTER then
							dmginfo:SetDamage(0)
						end
					end
				end
				if targetClass == "npc_antlionguard" then
					dmginfo:SetDamage(0)
				end			
			elseif attClass == "npc_antlionguard" then
				if CR_VERSION and engine.ActiveGamemode() == "terrortown" then
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
			if CR_VERSION and engine.ActiveGamemode() == "terrortown" then
				if att:IsPlayer() then
					if att:IsJesterTeam() then
						dmginfo:SetDamage(0)
					end
				end
			end
		end
	end

	hook.Add( "EntityTakeDamage", "DoncombineDamage", DoncombineDamage)
end