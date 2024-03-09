local Material = Material
local Vector = Vector
local pairs = pairs
local EyeAngles = EyeAngles
local cam_Start3D2D = CLIENT and cam.Start3D2D
local surface_SetDrawColor = CLIENT and surface.SetDrawColor
local surface_SetMaterial = CLIENT and surface.SetMaterial
local surface_DrawTexturedRect = CLIENT and surface.DrawTexturedRect
local cam_End3D2D = CLIENT and cam.End3D2D
local EyePos = EyePos
local IsValid = IsValid
local math_Clamp = math.Clamp
local RealTime = RealTime
local CurTime = CurTime
local table_IsEmpty = table.IsEmpty
local player_Iterator = player.Iterator
local table_Empty = table.Empty
local net_Start = net.Start
local net_Send = SERVER and net.Send
local print = print

--

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

            cam_Start3D2D( ( sndData.LastSndPos + iconOffset ), ang, 1.0 )
                surface_SetDrawColor( 255, 255, 255 )
                surface_SetMaterial( voiceIcon )
                surface_DrawTexturedRect( -8, -8, 16, 16 )
            cam_End3D2D()
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
            else
                local plyVol = ( voiceVol * ply:GetVoiceVolumeScale() )
                if isGlobal then
                    snd:SetVolume( plyVol )
                    snd:Set3DEnabled( false )
                else
                    local sndVol = plyVol
                    if !sndData.Is3D then
                        sndVol = math_Clamp( plyVol - ( eyePos:Distance( lastPos ) / ( 300 * 1.5 ) ), 0, 1 )
                        snd:Set3DEnabled( false )
                    else
                        snd:Set3DEnabled( true )
                        snd:SetPos( lastPos )
                    end

                    snd:SetVolume( sndVol )
                end
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
        if !waitTbl or table_IsEmpty( waitTbl ) then return end

        for _, ply in player_Iterator() do
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
            table_Empty( waitTbl )
        end
    end )

end

if ( SERVER ) then

    hook.Add( "PlayerInitialSpawn", "GLambda_OnPlayerCreated", function( ply )
        if ply:IsBot() then return end

        net_Start( "glambda_getbirthday" )
        net_Send( ply )
    
        print( "GLambda Players: Requesting " .. ply:Name() .. "'s birthday..." )
    end )

    hook.Add( "PostGamemodeLoaded", "GLambda_OnRestStuffLoaded", function()
        GLAMBDA.GamemodeLoaded = true
        GLAMBDA:UpdatePlayerModels()
    end )

    hook.Add( "PlayerSpawnedNPC", "GLambda_OnPlayerPlySpawned", function( player, ent )
        if player:IsGLambdaPlayer() or !ent.IsGLambdaSpawner then return end
        ent:InitializePlayer( player )
    end )

end

--

hook.Add( "InitPostEntity", "GLambda_InitPostEntity", function()
    GLAMBDA.DataUpdateFuncs[ "weapons" ]()
end )