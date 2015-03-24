if SERVER then
    local highping = 300
    local highpingduration = 60

    local function checkpings()
        for k, v in pairs(player.GetAll()) do
            if ( v:Ping() > highping ) then
                if ( v.highpingsince ) then
                    local duration = os.time() - v.highpingsince
                    if ( duration >= (highpingduration*0.5) ) then
                        v:ChatPrint(string.format("Fix your ping, or you will get kicked in %i seconds", (highpingduration - duration)))
                    end
                    if (duration >= highpingduration) then
                        v:Kick("Your ping is too high!")
                    end
                else
                    v.highpingsince = os.time()
                end
            else
                v.highpingsince = nil
            end
        end
    end

    timer.Create("PenguinHighpingKick", 10, 0, checkpings)
end
