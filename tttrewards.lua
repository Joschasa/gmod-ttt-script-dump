if SERVER then
    -- 1) Track MVP Serverside
    -- Needs edit in KMapVote! hook.Call( "KMapVoteMapWon" )
    local function findmvp()
        local max_frags = 0

        -- find highest frag count
        for k, v in pairs(player.GetAll()) do
            max_frags = math.max(v:Frags(), max_frags)
        end
        if max_frags == 0 then return end

        -- find player with highest frags (=score), MVProw + 1, MVPcount + 1
        for k, v in pairs(player.GetAll()) do
            if v:Frags() == max_frags then
                local mvpcount = tonumber(v:GetPData("MVPcount", 0)) or 0
                v:SetPData("MVPcount", mvpcount + 1)
                local mvpinrow = tonumber(v:GetPData("MVProw", 0)) or 0
                v:SetPData("MVProw", mvpinrow + 1)
            else
                v:SetPData("MVProw", 0)
            end
        end
    end
    hook.Add("KMapVoteMapWon", "HM_RewardPlayersMVP", findmvp)

    -- 2) Send MVP to the clients
    local function broadcastmvp(ply, steamid, uniqueid)
        local mvpcount = tonumber(ply:GetPData("MVPcount", 0)) or 0
        local mvpinrow = tonumber(ply:GetPData("MVProw", 0)) or 0
        ply:SetNWInt("MVPcount", mvpcount)
        ply:SetNWInt("MVProw", mvpinrow)
    end
    hook.Add("PlayerAuthed", "HM_RewardPlayersMVPBC", broadcastmvp)


    -- hook.Add("PlayerSay", "HM_TestMVP", function( ply, text, public )
    --     text = string.lower( text )
    --     if ( string.sub( text, 1 ) == "!mvp" ) then
    --         -- local mvpcount = tonumber(v:GetPData("MVPcount", 0)) or 0
    --         -- v:SetPData("MVPcount", mvpcount + 1)
    --         local mvpinrow = tonumber(ply:GetPData("MVProw", 0))
    --         ply:SetPData("MVProw", mvpinrow + 1)
    --         return ""
    --     end
    -- end)

    -- 3) Display MVP (integrated into gamemodes/terrortown/gamemode/vgui/sb_row.lua)

    -- Reward max karma (-50)
    local function rewardplayer()
        local karmavar = GetConVar("ttt_karma_max"):GetInt() - 50
        for k, v in pairs(player.GetAll()) do
            if not v:IsSpec() then
                -- if v:GetRole() == ROLE_TRAITOR then
                -- reward, if best player last map
                -- elseif v:GetRole() == ROLE_INNOCENT then
                -- nothing? +hp?
                -- else
                if v:GetRole() == ROLE_DETECTIVE then
                    if math.Round(v:GetBaseKarma()) >= karmavar then
                        v:AddCredits(1)
                        v:ChatPrint("You got 1 credit for your karma!")
                    end
                end
            end
        end
    end
    hook.Add("TTTBeginRound", "HM_RewardPlayers", rewardplayer)
end
