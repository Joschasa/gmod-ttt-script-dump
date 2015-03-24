if SERVER then

    -- Util Stuff
    util.AddNetworkString("countingresults")

    -- Localizing Variables
    -- local traitornumber = 0
    -- local innocentnumber = 0
    -- local detectivenumber = 0

    local function rolecounter()

        local traitornumber = 0
        local innocentnumber = 0
        local detectivenumber = 0

        for k, v in pairs(player.GetAll()) do
            if not v:IsSpec() then
                if v:GetRole() == ROLE_TRAITOR then
                    traitornumber = traitornumber + 1
                elseif v:GetRole() == ROLE_INNOCENT then
                    innocentnumber = innocentnumber + 1
                elseif v:GetRole() == ROLE_DETECTIVE then
                    detectivenumber = detectivenumber + 1
                end
            end
        end

        net.Start("countingresults")
        net.WriteUInt(traitornumber, 8)
        net.WriteUInt(innocentnumber, 8)
        net.WriteUInt(detectivenumber, 8)
        net.Broadcast()

    end
    hook.Add("TTTBeginRound", "rolecounter", rolecounter)

    -- local function rolecounterreset()

    -- traitornumber = 0
    -- innocentnumber = 0
    -- detectivenumber = 0

    -- end
    -- hook.Add("TTTEndRound", "rolecounterreset", rolecounterreset)


elseif CLIENT then

    local function showingamount()

        local traitornum = net.ReadUInt(8)
        local innocentnum = net.ReadUInt(8)
        local detectivenum = net.ReadUInt(8)

        local traitorstring = " traitor";
        if(traitornum > 1) then traitorstring = " traitors"; end
        local innocentstring = " innocent";
        if(innocentnum > 1) then innocentstring = " innocents"; end
        local detectivestring = " detective";
        if(detectivenum > 1) then detectivestring = " detectives"; end

        if(detectivenum > 0) then
            chat.AddText(
            Color(255, 255, 255), "There are ",
            Color(255, 0, 0), tostring(traitornum).. traitorstring,
            Color(255, 255, 255), ", ",
            Color(0, 0, 255), tostring(detectivenum).. detectivestring,
            Color(255, 255, 255), " and ",
            Color(0, 255, 0), tostring(innocentnum).. innocentstring,
            Color(255, 255, 255), "."
            )
        else
            chat.AddText(
            Color(255, 255, 255), "There are ",
            Color(255, 0, 0), tostring(traitornum).. traitorstring,
            Color(255, 255, 255), " and ",
            Color(0, 255, 0), tostring(innocentnum).. innocentstring,
            Color(255, 255, 255), "."
            )
        end

    end

    net.Receive("countingresults", showingamount)

end
