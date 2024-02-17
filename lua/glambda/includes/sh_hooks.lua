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
            if !ply:Alive() then
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
            else
                local sndVol = 1
                if !sndData.Is3D then
                    sndVol = math.Clamp( 1 / ( curPos:DistToSqr( eyePos ) / 90000 ), 0, 1 )
                    snd:Set3DEnabled( false )
                else
                    snd:Set3DEnabled( true )
                    snd:SetPos( lastPos )
                end

                snd:SetVolume( 1 )
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

end

if ( SERVER ) then

    hook.Add( "PostGamemodeLoaded", "GLambda_OnRestStuffLoaded", function()
        GLAMBDA.GamemodeLoaded = true
        GLAMBDA:UpdatePlayerModels()
    end )

end