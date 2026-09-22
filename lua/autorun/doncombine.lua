local Category = "Combine"

local NPC = {	Name = "Doncombine",
				Class = "npc_doncombine",
				Category = Category }

list.Set( "NPC", "idoncombine", NPC )

if SERVER then
  	resource.AddWorkshop( "2457576268" )
end

CreateConVar( "ttt_doncombine_health", 360 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "Initial health of a Doncombine" )

CreateConVar( "ttt_doncombine_is_tracking_shot", 1 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "If the Doncombine projectiles will track it's target" )

CreateConVar( "ttt_doncombine_extra_armor", 1 ,{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, "If the Doncombine has extra armor" )




