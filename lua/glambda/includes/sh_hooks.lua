if ( CLIENT ) then

    GLAMBDA.VoiceChannels = ( GLAMBDA.VoiceChannels or {} )

    --

    local voiceIcon = Material( "voice/icntlk_pl" )
    local iconOffset = Vector( 0, 0, 80 )

    hook.Add( "PreDrawEffects", "GLambda_DrawVoiceIcons", function()
        for _, sndData in pairs( GLAMBDA.VoiceChannels ) do
            if sndData.PlayTime then continue end

            local ang = EyeAngles()
            ang:RotateAroundAxis( ang:Up(), -90 )
            ang:RotateAroundAxis( ang:Forward(), 90 )

            cam.Start3D2D( ( sndData.LastSndPos + iconOffset ), ang, 1.0 )
                surface.SetDrawColor( 255, 255, 255 )
                surface.SetMaterial( voiceIcon )
                surface.DrawTexturedRect( -8, -8, 16, 16 )
            cam.End3D2D()
        end
    end )

    hook.Add( "Tick", "GLambda_UpdateVoiceSounds", function()
        local eyePos = EyePos()
        local isGlobal = GLAMBDA:GetConVar( "voice_globalchat" )
        local voiceVol = GLAMBDA:GetConVar( "voice_volume" )

        for ply, sndData in pairs( GLAMBDA.VoiceChannels ) do
            local snd = sndData.Sound
            local playTime = sndData.PlayTime
    
            if !IsValid( ply ) or !IsValid( snd ) or !playTime and snd:GetState() == GMOD_CHANNEL_STOPPED then
                if IsValid( snd ) then snd:Stop() end
                if IsValid( ply ) then GAMEMODE:PlayerEndVoice( ply ) end

                GLAMBDA.VoiceChannels[ ply ] = nil
                continue
            end

            local srcEnt = ply
            local observeEnt = ply:GetObserverTarget()
            if IsValid( observeEnt ) then 
                srcEnt = observeEnt
            elseif !ply:Alive() then
                local ragdoll = ply:GetRagdollEntity()
                if IsValid( ragdoll ) then srcEnt = ragdoll end
            end

            local lastPos = sndData.LastSndPos
            if !srcEnt:IsDormant() then
                lastPos = srcEnt:GetPos()
                sndData.LastSndPos = lastPos
            end

            if ply:IsMuted() then
                snd:SetVolume( 0 )
            elseif isGlobal then
                snd:SetVolume( voiceVol )
                snd:Set3DEnabled( false )
            else
                local sndVol = voiceVol
                if !sndData.Is3D then
                    sndVol = math.Clamp( voiceVol / ( eyePos:DistToSqr( lastPos ) / 90000 ), 0, 1 )
                    snd:Set3DEnabled( false )
                else
                    snd:Set3DEnabled( true )
                    snd:SetPos( lastPos )
                end

                snd:SetVolume( sndVol )
            end

            local leftC, rightC = snd:GetLevel()
            local voiceLvl = ( ( leftC + rightC ) / 2 )
            sndData.VoiceVolume = voiceLvl

            if playTime and RealTime() >= playTime then
                sndData.PlayTime = false
                snd:Play()
                GAMEMODE:PlayerStartVoice( ply )
            end
        end
    end )

    --

    local lastNetworkTime = CurTime()
    hook.Add( "Think", "GLambda_NetworkInitPlayers", function( ply )
        local waitTbl = GLAMBDA.WaitingForNetwork
        if !waitTbl or table.IsEmpty( waitTbl ) then return end

        for _, ply in player.Iterator() do
            local userId = ply:UserID()
            local netTbl = waitTbl[ userId ]

            if !netTbl then continue end
            lastNetworkTime = CurTime()

            GLAMBDA:InitializeLambda( ply, netTbl[ 1 ] )
            waitTbl[ userId ] = nil
            return
        end

        if ( CurTime() - lastNetworkTime ) > 10 then
            lastNetworkTime = CurTime()
            table.Empty( waitTbl )
        end
    end )

end

if ( SERVER ) then

    hook.Add( "PlayerInitialSpawn", "GLambda_OnPlayerCreated", function( ply )
        if ply:IsBot() then return end

        net.Start( "glambda_getbirthday" )
        net.Send( ply )
    
        print( "GLambda Players: Requesting " .. ply:Name() .. "'s birthday..." )
    end )

    hook.Add( "PostGamemodeLoaded", "GLambda_OnRestStuffLoaded", function()
        GLAMBDA.GamemodeLoaded = true
        GLAMBDA:UpdatePlayerModels()
    end )

end