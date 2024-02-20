if ( SERVER ) then

    util.AddNetworkString( "glambda_playerinit" )
    util.AddNetworkString( "glambda_waitforplynet" )
    util.AddNetworkString( "glambda_playerremove" )
    util.AddNetworkString( "glambda_playvoicesnd" )
    util.AddNetworkString( "glambda_stopspeech" )
    util.AddNetworkString( "glambda_sendsndduration" )
    util.AddNetworkString( "glambda_playgesture" )
    util.AddNetworkString( "glambda_syncweapons" )
    util.AddNetworkString( "glambda_sendnotify" )
    util.AddNetworkString( "glambda_updatedata" )
    util.AddNetworkString( "glambda_reloadfiles" )
    util.AddNetworkString( "glambda_getbirthday" )
    util.AddNetworkString( "glambda_sendbirthday" )
    util.AddNetworkString( "glambda_setupbirthday" )

    --

    net.Receive( "glambda_sendsndduration", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end
        
        local glace = ply:GetGlaceObject()
        if glace then glace:SetSpeechEndTime( RealTime() + net.ReadFloat() ) end
    end )

    --

    GLAMBDA.Birthdays = ( GLAMBDA.Birthdays or {} )

    net.Receive( "glambda_sendbirthday", function( len, ply )
        local month = net.ReadString()
        if month == "NIL" then 
            print( "GLambda Players: " .. ply:Name() .. " has not set up their birthday date yet" )
            return 
        end

        print( "GLambda Players: Successfully received " .. ply:Name() .. "'s birthday!")
        GLAMBDA.Birthdays[ ply:SteamID() ] = { month = month, day = net.ReadUInt( 5 ) }
    end )

    net.Receive( "glambda_setupbirthday", function( len, ply )
        local month = net.ReadString()
        if month == "NIL" then return end

        print( "GLambda Players: " .. ply:Name() .. " changed their birthday date")
        GLAMBDA.Birthdays[ ply:SteamID() ] = { month = month, day = net.ReadUInt( 5 ) }
    end )

end

if ( CLIENT ) then

    GLAMBDA.WaitingForNetwork = {}

    local color_client = Color( 255, 145, 0 )

    --

    net.Receive( "glambda_getbirthday", function()
        local birthdayData = GLAMBDA.FILE:ReadFile( "glambda/plybirthday.json", "json" )

        net.Start( "glambda_sendbirthday" )
        if birthdayData then
            net.WriteString( birthdayData.month )
            net.WriteUInt( birthdayData.day, 5 )
        else
            net.WriteString( "NIL" )
            net.WriteUInt( 1, 5 )
        end
        net.SendToServer()
    end )

    net.Receive( "glambda_reloadfiles", function()
        GLAMBDA:LoadFiles()
        chat.AddText( color_client, "Reloaded all GLambda-related files for your Client" )
        RunConsoleCommand( "spawnmenu_reload" )
    end )

    net.Receive( "glambda_sendnotify", function()
        GLAMBDA:SendNotification( nil, net.ReadString(), net.ReadUInt( 3 ), net.ReadFloat(), net.ReadString() )
    end )

    net.Receive( "glambda_updatedata", function()
        GLAMBDA:UpdateData( true )
        chat.AddText( "GLambda Data was updated by the Server" )
    end )

    net.Receive( "glambda_syncweapons", function()
        local wepClass = net.ReadString()
        local wepName = net.ReadString()

        if wepName[ 1 ] == "#" then wepName = wepClass end
        GLAMBDA.WeaponList[ wepClass ] = { Name = wepName }
    end )

    net.Receive( "glambda_playerinit", function()
        local ply = net.ReadPlayer()
        if !IsValid( ply ) then return end

        GLAMBDA:InitializeLambda( ply, net.ReadString() )
    end )

    net.Receive( "glambda_waitforplynet", function()
        GLAMBDA.WaitingForNetwork[ net.ReadUInt( 12 ) ] = {
            net.ReadString()
        }
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

    net.Receive( "glambda_stopspeech", function()
        local ply = net.ReadPlayer()
        StopCurrentVoice( ply )
    end )

    local function PlaySoundFile( ply, sndDir, sndPitch, origin, delay, is3d )
        if !IsValid( ply ) then return end
        StopCurrentVoice( ply )

        sound.PlayFile( sndDir, "noplay" .. ( is3d and " 3d" or "" ), function( snd, errId, errName )
            if errId == 21 then
                PlaySoundFile( ply, sndDir, sndPitch, origin, delay, false )
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

            local playRate = ( sndPitch / 100 )
            snd:SetPlaybackRate( playRate )
            snd:Set3DFadeDistance( 300, 0 )

            snd:SetVolume( ply:IsMuted() and 0 or GLAMBDA:GetConVar( "voice_volume" ) )
            snd:Set3DEnabled( GLAMBDA:GetConVar( "voice_globalchat" ) or is3d )

            net.Start( "glambda_sendsndduration" )
                net.WritePlayer( ply )
                net.WriteFloat( ( sndLength / playRate ) + delay )
            net.SendToServer()
        end )
    end
    net.Receive( "glambda_playvoicesnd", function()
        PlaySoundFile( net.ReadPlayer(), net.ReadString(), net.ReadUInt( 8 ), net.ReadVector(), net.ReadFloat(), true )
    end )

end