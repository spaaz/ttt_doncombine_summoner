local Category = "Combine"

local NPC = {	Name = "Doncombine",
				Class = "npc_doncombine",
				Category = Category }

list.Set( "NPC", "idoncombine", NPC )

local NPC = {	Name = "Hunter",
				Class = "npc_hunter",
				Category = Category }

list.Set( "NPC", "ihunter", NPC )

game.AddParticles( "particles/hunter_flechette.pcf" )
game.AddParticles( "particles/hunter_intro.pcf" )
game.AddParticles( "particles/hunter_projectile.pcf" )
game.AddParticles( "particles/hunter_shield_impact.pcf" )

if SERVER then
  	resource.AddWorkshop( "2457576268" )
	--SetGlobalBool( "CRismounted", false )
	--for k, addon in ipairs( engine.GetAddons()) do
		--if addon.mounted then
			--if addon.wsid == "2421039084" then
				--SetGlobalBool( "CRismounted", true )
			--end
		--end
	--end
end

CreateConVar( "ttt_doncombine_health", 360 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Initial health of a Doncombine" )

CreateConVar( "ttt_doncombine_is_tracking_shot", 1 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "If the Doncombine projectiles will track it's target" )

CreateConVar( "ttt_doncombine_extra_armor", 1 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "If the Doncombine has extra armor" )




