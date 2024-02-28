local util_AddNetworkString = SERVER and util.AddNetworkString
local net_Receive = net.Receive
local net_ReadPlayer = net.ReadPlayer
local IsValid = IsValid
local RealTime = RealTime
local net_ReadFloat = net.ReadFloat
local table_Merge = table.Merge
local net_ReadTable = net.ReadTable
local file_Find = file.Find
local ipairs = ipairs
local file_Delete = file.Delete
local GLAMBDA = GLAMBDA
local GetConVar = GetConVar
local net_ReadString = net.ReadString
local concommand_Run = concommand.Run
local print = print
local net_ReadUInt = net.ReadUInt
local Color = Color
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_SendToServer = CLIENT and net.SendToServer
local chat_AddText = CLIENT and chat.AddText
local RunConsoleCommand = RunConsoleCommand
local net_ReadBool = net.ReadBool
local string_EndsWith = string.EndsWith
local CreateMaterial = CreateMaterial
local Material = Material
local util_DecalEx = CLIENT and util.DecalEx
local Entity = Entity
local net_ReadVector = net.ReadVector
local sound_PlayFile = CLIENT and sound.PlayFile
local net_WritePlayer = net.WritePlayer
local net_WriteFloat = net.WriteFloat

if ( SERVER ) then

    util_AddNetworkString( "glambda_playerinit" )
    util_AddNetworkString( "glambda_waitforplynet" )
    util_AddNetworkString( "glambda_playerremove" )
    util_AddNetworkString( "glambda_playvoicesnd" )
    util_AddNetworkString( "glambda_stopspeech" )
    util_AddNetworkString( "glambda_sendsndduration" )
    util_AddNetworkString( "glambda_playgesture" )
    util_AddNetworkString( "glambda_syncweapons" )
    util_AddNetworkString( "glambda_sendnotify" )
    util_AddNetworkString( "glambda_updatedata" )
    util_AddNetworkString( "glambda_reloadfiles" )
    util_AddNetworkString( "glambda_getbirthday" )
    util_AddNetworkString( "glambda_sendbirthday" )
    util_AddNetworkString( "glambda_setupbirthday" )
    util_AddNetworkString( "glambda_updateconvar" )
    util_AddNetworkString( "glambda_runconcommand" )
    util_AddNetworkString( "glambda_spray" )
    util_AddNetworkString( "glambda_resetweaponlist" )
    util_AddNetworkString( "glambda_updatewepperms" )

    --

    net_Receive( "glambda_sendsndduration", function()
        local ply = net_ReadPlayer()
        if !IsValid( ply ) then return end
        
        local glace = ply:GetGlaceObject()
        if glace then glace:SetSpeechEndTime( RealTime() + net_ReadFloat() ) end
    end )

    --

    net_Receive( "glambda_updatewepperms", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        table_Merge( GLAMBDA.WeaponPermissions, net_ReadTable() )
    end )

    net_Receive( "glambda_resetweaponlist", function( len, ply )
        if !ply:IsSuperAdmin() then return end

        local files = file_Find( "glambda/weapons/*.dat", "DATA", "nameasc" )
        if !files then return end

        for _, fileName in ipairs( files ) do
            file_Delete( "glambda/weapons/" .. fileName, "DATA" )
        end

        GLAMBDA:ReadDefaultWeapons( true )
        GLAMBDA.DataUpdateFuncs[ "weapons" ]()
    end )

    net_Receive( "glambda_updateconvar", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        local cvar = GetConVar( net_ReadString() )
        if cvar and cvar:IsFlagSet( FCVAR_LUA_SERVER ) then cvar:SetString( net_ReadString() ) end
    end )
    
    net_Receive( "glambda_runconcommand", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        concommand_Run( ply, net_ReadString() )
    end )
    
    --

    GLAMBDA.Birthdays = ( GLAMBDA.Birthdays or {} )

    net_Receive( "glambda_sendbirthday", function( len, ply )
        local month = net_ReadString()
        if month == "NIL" then 
            print( "GLambda Players: " .. ply:Name() .. " has not set up their birthday date yet" )
            return 
        end

        print( "GLambda Players: Successfully received " .. ply:Name() .. "'s birthday!")
        GLAMBDA.Birthdays[ ply:SteamID() ] = { month = month, day = net_ReadUInt( 5 ) }
    end )

    net_Receive( "glambda_setupbirthday", function( len, ply )
        local month = net_ReadString()
        if month == "NIL" then return end

        print( "GLambda Players: " .. ply:Name() .. " changed their birthday date")
        GLAMBDA.Birthdays[ ply:SteamID() ] = { month = month, day = net_ReadUInt( 5 ) }
    end )

end

if ( CLIENT ) then

    GLAMBDA.WaitingForNetwork = {}

    local color_client = Color( 255, 145, 0 )

    --

    net_Receive( "glambda_getbirthday", function()
        local birthdayData = GLAMBDA.FILE:ReadFile( "glambda/plybirthday.json", "json" )

        net_Start( "glambda_sendbirthday" )
        if birthdayData then
            net_WriteString( birthdayData.month )
            net_WriteUInt( birthdayData.day, 5 )
        else
            net_WriteString( "NIL" )
            net_WriteUInt( 1, 5 )
        end
        net_SendToServer()
    end )

    net_Receive( "glambda_reloadfiles", function()
        GLAMBDA:LoadFiles()
        chat_AddText( color_client, "Reloaded all GLambda-related files for your Client" )
        RunConsoleCommand( "spawnmenu_reload" )
    end )

    net_Receive( "glambda_sendnotify", function()
        GLAMBDA:SendNotification( nil, net_ReadString(), net_ReadUInt( 3 ), net_ReadFloat(), net_ReadString() )
    end )

    net_Receive( "glambda_updatedata", function()
        local dataName = net_ReadString()
        local updFunc = GLAMBDA.DataUpdateFuncs[ dataName ]
        if !updFunc then return end

        updFunc()
        chat_AddText( 'GLambda: "' .. dataName .. '" data was updated by the Server' )

        if net_ReadBool() then
            RunConsoleCommand( "spawnmenu_reload" )
        end
    end )

    net_Receive( "glambda_syncweapons", function()
        local wepClass = net_ReadString()
        local wepName = net_ReadString()
        if wepName[ 1 ] == "#" then wepName = wepClass end

        local wepCat = net_ReadString()
        GLAMBDA.WeaponList[ wepClass ] = { Name = wepName, Category = wepCat }
    end )

    net_Receive( "glambda_playerinit", function()
        local ply = net_ReadPlayer()
        if !IsValid( ply ) then return end

        GLAMBDA:InitializeLambda( ply, net_ReadString() )
    end )

    net_Receive( "glambda_waitforplynet", function()
        GLAMBDA.WaitingForNetwork[ net_ReadUInt( 12 ) ] = {
            net_ReadString()
        }
    end )

    net_Receive( "glambda_playgesture", function()
        local ply = net_ReadPlayer()
        if !IsValid( ply ) then return end

        local act = net_ReadFloat()
        ply:AnimRestartGesture( GESTURE_SLOT_VCD, act, true )
    end )
    
    GLAMBDA.SprayDecals = ( GLAMBDA.SprayDecals or 1 )
    net_Receive( "glambda_spray", function()
        local material
        local sprayPath = net_ReadString()

        if string_EndsWith( sprayPath, ".vtf" ) then
            material = CreateMaterial( "GLambda_SprayMaterial#" .. GLAMBDA.SprayDecals, "LightmappedGeneric", {
                [ "$basetexture" ] = sprayPath,
                [ "$translucent" ] = 1,

                [ "Proxies" ] = {
                    [ "AnimatedTexture" ] = {
                        [ "animatedTextureVar" ] = "$basetexture",
                        [ "animatedTextureFrameNumVar" ] = "$frame",
                        [ "animatedTextureFrameRate" ] = 10
                    }
                }
            })
            GLAMBDA.SprayDecals = ( GLAMBDA.SprayDecals + 1 )
        else
            material = Material( sprayPath )
        end
        if !material or material:IsError() then return end

        local texWidth = material:Width()
        local texHeight = material:Height()
    
        -- Sizing the Spray
        local widthPower = 256
        local heightPower = 256
        if texWidth > texHeight then
            heightPower = 128
        elseif texHeight > texWidth then
            widthPower = 128
        end
        if texWidth < 256 then
            texWidth = ( texWidth / 256 )
        else
            texWidth = ( widthPower / ( texWidth * 4 ) )
        end
        if texHeight < 256 then
            texHeight = ( texHeight / 256 )
        else
            texHeight = ( heightPower / ( texHeight * 4 ) )
        end
    
        -- Place the spray
        util_DecalEx( material, Entity( 0 ), net_ReadVector(), net_ReadVector(), color_white, texWidth, texHeight )
    end )

    --

    local function StopCurrentVoice( ply )
        GAMEMODE:PlayerEndVoice( ply )

        local voiceChan = GLAMBDA.VoiceChannels[ ply ]
        if !voiceChan then return end
        
        local snd = voiceChan.Sound    
        if IsValid( snd ) then snd:Stop() end
    end

    net_Receive( "glambda_playerremove", function()
        local ply = net_ReadPlayer()
        StopCurrentVoice( ply )
    end )

    net_Receive( "glambda_stopspeech", function()
        local ply = net_ReadPlayer()
        StopCurrentVoice( ply )
    end )

    local function PlaySoundFile( ply, sndDir, sndPitch, origin, delay, is3d )
        if !IsValid( ply ) then return end
        StopCurrentVoice( ply )

        sound_PlayFile( sndDir, "noplay" .. ( is3d and " 3d" or "" ), function( snd, errId, errName )
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

            net_Start( "glambda_sendsndduration" )
                net_WritePlayer( ply )
                net_WriteFloat( ( sndLength / playRate ) + delay )
            net_SendToServer()
        end )
    end
    net_Receive( "glambda_playvoicesnd", function()
        PlaySoundFile( net_ReadPlayer(), net_ReadString(), net_ReadUInt( 8 ), net_ReadVector(), net_ReadFloat(), true )
    end )

end