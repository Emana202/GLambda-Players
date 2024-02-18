if ( SERVER ) then

    util.AddNetworkString( "glambda_playerinit" )
    util.AddNetworkString( "glambda_playerremove" )
    util.AddNetworkString( "glambda_playvoicesnd" )
    util.AddNetworkString( "glambda_sendsndduration" )
    util.AddNetworkString( "glambda_playgesture" )
    util.AddNetworkString( "glambda_syncweapons" )

    --

    net.Receive( "glambda_sendsndduration", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end
        
        local glace = ply:GetGlaceObject()
        if glace then glace:SetSpeechEndTime( RealTime() + net.ReadFloat() ) end
    end )

end

if ( CLIENT ) then

    net.Receive( "glambda_syncweapons", function()
        local wepName = net.ReadString()
        GLAMBDA.WeaponList[ wepName ] = wepName
    end )

    net.Receive( "glambda_playerinit", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end

        ply.gl_IsLambdaPlayer = true
        ply.gl_IsVoiceMuted = false

        local profilePic = net.ReadString()
        if #profilePic == 0 then
            local plyMdl = ply:GetModel()
            profilePic = Material( "spawnicons/" .. string.sub( plyMdl, 1, #plyMdl - 4 ) .. ".png" )
        else
            if !string.EndsWith( profilePic, ".vtf" ) then
                profilePic = Material( profilePic )
            else
                profilePic = CreateMaterial( "GLambda_PfpMaterial_" .. RealTime(), "UnlitGeneric", {
                    [ "$basetexture" ] = profilePic,
                    [ "$translucent" ] = 1,

                    [ "Proxies" ] = {
                        [ "AnimatedTexture" ] = {
                            [ "animatedTextureVar" ] = "$basetexture",
                            [ "animatedTextureFrameNumVar" ] = "$frame",
                            [ "animatedTextureFrameRate" ] = 10
                        }
                    }
                } )
            end
            if !profilePic or profilePic:IsError() then
                local plyMdl = ply:GetModel()
                profilePic = Material( "spawnicons/" .. string.sub( plyMdl, 1, #plyMdl - 4 ) .. ".png" )
            end
        end
        ply.gl_ProfilePicture = profilePic
    end )

    net.Receive( "glambda_playgesture", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end

        local act = net.ReadFloat()
        ply:AnimRestartGesture( GESTURE_SLOT_VCD, act, true )
    end )

    local function StopCurrentVoice( ply )
        GAMEMODE:PlayerEndVoice( ply )

        local voiceChan = GLAMBDA.VoiceChannels[ ply ]
        if !voiceChan then return end
        
        local snd = voiceChan.Sound    
        if IsValid( snd ) then snd:Stop() end
    end

    net.Receive( "glambda_playerremove", function()
        local ply = net.ReadPlayer()
        StopCurrentVoice( ply )
    end )

    local function PlaySoundFile( ply, sndDir, origin, delay, is3d )
        if !IsValid( ply ) then return end
        StopCurrentVoice( ply )

        sound.PlayFile( sndDir, "noplay" .. ( is3d and " 3d" or "" ), function( snd, errId, errName )
            if errId == 21 then
                PlaySoundFile( ply, sndDir, origin, delay, false )
                return
            elseif !IsValid( snd ) then
                print( "GLambda Players: Sound file " .. sndDir .. " failed to open!\nError ID: " .. errName .. "#" .. errId )
                return
            end

            local sndLength = snd:GetLength()
            if sndLength <= 0 or !IsValid( ply ) then
                snd:Stop()
                return
            end
            
            local playTime = ( RealTime() + delay )
            local voiceChan = GLAMBDA.VoiceChannels[ ply ]
            if voiceChan then
                StopCurrentVoice( ply )

                voiceChan.Sound = snd
                voiceChan.LastSndPos = origin
                voiceChan.PlayTime = playTime
                voiceChan.VoiceVolume = 0
                voiceChan.Is3D = is3d
            else
                GLAMBDA.VoiceChannels[ ply ] = {
                    Sound = snd,
                    VoiceVolume = 0,
                    PlayTime = playTime,
                    LastSndPos = origin,
                    Is3D = is3d
                }
            end
            
            snd:Set3DFadeDistance( 300, 0 )
            snd:SetVolume( ply:IsMuted() and 0 or GLAMBDA:GetConVar( "voice_volume" ) )
            snd:Set3DEnabled( GLAMBDA:GetConVar( "voice_globalchat" ) or is3d )

            net.Start( "glambda_sendsndduration" )
                net.WritePlayer( ply )
                net.WriteFloat( sndLength + delay )
            net.SendToServer()
        end )
    end
    net.Receive( "glambda_playvoicesnd", function()
        PlaySoundFile( net.ReadPlayer(), net.ReadString(), net.ReadVector(), net.ReadFloat(), true )
    end )

end