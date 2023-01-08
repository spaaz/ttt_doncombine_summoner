local TROPHY = {}
TROPHY.id = "hitthebaby"
TROPHY.title = "Hit the baby"
TROPHY.desc = "On the innocent team, crowbar a doncombine 10 times in a single round"
TROPHY.rarity = 2

function TROPHY:Trigger()
    self.roleMessage = ROLE_INNOCENT
	self:AddHook( "TTTBeginRound", function()
		for _, ply in ipairs(player.GetAll()) do
			ply.doncombinehits = 0
        end
	end)
    self:AddHook("EntityTakeDamage", function(tgt,dinfo)
		if tgt:GetClass() == "npc_hunter" then
			local wep = dinfo:GetInflictor()
			local att = dinfo:GetAttacker()
			if att and att:IsPlayer() then
				wep = att:GetActiveWeapon()
			elseif wep and wep:IsPlayer() then
				att = wep
				wep = wep:GetActiveWeapon()
			end
			if wep and att:IsPlayer() and ((!CR_VERSION and !att:IsActiveTraitor()) or (CR_VERSION and (att:IsInnocentTeam()))) then
				if wep:GetClass() == "weapon_zm_improvised" then
					if tgt:GetName() == "Doncombine" then
						if att.doncombinehits < 9 then
							att.doncombinehits = att.doncombinehits + 1
						else
							self:Earn(att)
						end
					end
				end
			end	
			

		end
    end)
end

function TROPHY:Condition()
    return scripted_ents.Get("npc_doncombine") ~= nil
end

RegisterTTTTrophy(TROPHY)