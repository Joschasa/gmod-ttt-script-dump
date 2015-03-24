--
-- !afk and !back commands for players
-- !afk  = toggle
-- !back = only back
--

if SERVER then
    util.AddNetworkString("HM_GoAFK")
    hook.Add( "PlayerSay", "HM_GoAFKH", function( ply, text, public )
        text = string.lower( text )
        -- if ( string.sub( text, 1 ) == "!test" ) then
        -- local blafasel = {}
        -- blafasel.fusel = "Tetris"
        -- ply:ChatPrint("BLaaa: "..blafasel.fusel)
        -- return ""
        -- end
        if ( string.sub( text, 1 ) == "!afk" or string.sub( text, 1 ) == "!back" ) then
            net.Start("HM_GoAFK")
            net.WriteUInt((string.sub( text, 1 ) == "!back") and 1 or 0, 1)
            net.Send(ply)
            return ""
        end
    end)
elseif CLIENT then
    net.Receive("HM_GoAFK", function()
        local comeback = tonumber( net.ReadUInt(1) )
        local isSpec = GetConVar("ttt_spectator_mode"):GetInt()
        if isSpec == 1 then
            chat.AddText(Color(220, 220, 220), "You are now ",
            Color(0, 255, 0), "back",
            Color(220, 220, 220), "."
            )
            RunConsoleCommand("ttt_spectator_mode", "0")
        elseif isSpec == 0 and comeback ~= 1 then
            chat.AddText(Color(220, 220, 220), "You are now ",
            Color(255, 0, 0), "AFK",
            Color(220, 220, 220), "."
            )
            RunConsoleCommand("ttt_spectator_mode", "1")
        else
            chat.AddText(Color(220, 220, 220), "You are already back.")
        end
    end)
end

--
-- Kick AFKler, if away for too long
--
AFKKickTimerCount = 0
if SERVER then
    util.AddNetworkString("HM_KickMe")
    net.Receive("HM_KickMe", function(_, ply)
        if #player.GetAll() >= 13 then
            if ply:CheckGroup("Co Operator") then
                -- local admins = 0
                -- for k,v in pairs(player.GetAll()) do
                -- if not IsValid(v) then continue end
                -- if v:CheckGroup("operator") then
                -- admins = admins + 1
                -- end
                -- if admins > 1 then
                -- ply:Kick("Zu lange AFK und nicht einziger Admin online")
                -- end
                -- end
            else
                ply:Kick("Du warst zu lange AFK")
            end
        end
    end)
elseif CLIENT then
    local function KickTimer(cv, old, new)
        local num = tonumber(new)
        if not num then return end
        local timername = "AFKKickTimer" --..tostring(LocalPlayer():SteamID()) timer is local, so wayne name
        if num == 0 and timer.Exists(timername) then
            timer.Destroy(timername)
            AFKKickTimerCount = 0
        elseif num == 1 and not timer.Exists(timername) then
            timer.Create(timername, 300, 0, function ()
                AFKKickTimerCount = AFKKickTimerCount + 1
                if (AFKKickTimerCount > 2) then
                    net.Start("HM_KickMe")
                    net.SendToServer()
                end
            end)
        end
    end
    cvars.AddChangeCallback("ttt_spectator_mode", KickTimer)
end

--
-- AFK should not get Karma while in spec
--
if SERVER then
    hook.Add( "TTTBeginRound", "HM_AFKKarma", function( )
        for k,v in pairs(player.GetAll()) do
            if IsValid(v) and v:IsSpec() then
                -- v:ChatPrint("Spectators won't get karma.")
                v:SetCleanRound(false)
            end
        end
    end)
end
