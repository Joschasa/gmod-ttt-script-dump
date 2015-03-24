if CLIENT then
    local oWeaponsGetList = weapons.GetList;
    local maps_without_skybox = {"de_deathcookin", "ttt_airbus_b3", "ttt_bb_teenroom_b2", "ttt_clue_n", "ttt_community_bowling_hm_v1", "ttt_dolls", "ttt_ferrostruct", "ttt_floodlights", "ttt_slender_v3_fix", "ttt_subway_b4", "ttt_waterworld_hm", "ttt_whitehouse_b2", "zs_snowedin"}

    function weapons.GetList()

        local tbl = oWeaponsGetList();
        local map = game.GetMap(); -- The name of the current map, without a file extension.

        --Modify weapons.GetList() returned results if it's called by cl_equip.lua's GetEquipmentForRole function
        if( string.find( tostring( debug.traceback() ), "GetEquipmentForRole" ) != nil ) then
            for k,v in pairs( tbl ) do
                if( v and v.CanBuy ) then
                    if( v.RespectSkybox ) then
                        if (table.HasValue(maps_without_skybox, map) == v.NeedsSkybox ) then
                            table.remove( tbl, k );
                        end
                    end
                end
            end
        end
        return tbl;
    end
end
