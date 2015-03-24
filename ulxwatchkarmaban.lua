if SERVER then
    hook.Add( "TTTKarmaLow", "HM_WatchKarmaBan", function( ply )
        local Timestamp = os.time()
        local TimeStr = os.date( "%d.%m.%Y %X" , Timestamp )

        local reason = ply:GetPData("WatchReason", "") or ""
        reason = reason .. "[low karma ban: "..TimeStr.."]"
        ply:SetPData("Watched", "true")
        ply:SetPData("WatchReason",reason)
        return true
    end )
end
