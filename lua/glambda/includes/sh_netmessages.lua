if ( SERVER ) then

    util.AddNetworkString( "glambda_playerinit" )
    util.AddNetworkString( "glambda_playerremove" )
    util.AddNetworkString( "glambda_playvoicesnd" )
    util.AddNetworkString( "glambda_sendsndduration" )

    --

    net.Receive( "glambda_sendsndduration", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end
        
        local glace = ply:GetGlaceObject()
        if glace then glace:SetSpeechEndTime( RealTime() + net.ReadFloat() ) end
    end )

end

if ( CLIENT ) then

    net.Receive( "glambda_playerinit", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end

        ply.gl_IsLambdaPlayer = true
        ply.gl_IsVoiceMuted = false

        local profilePic = net.ReadString()
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
        ply.gl_ProfilePicture = profilePic
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
            if !IsValid( snd ) then
                print( "GLambda Players: Sound file " .. sndDir .. " failed to open!\nError ID: " .. errorName .. "#" .. errorId )
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