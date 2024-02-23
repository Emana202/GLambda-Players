GLAMBDA.Player = {}

local includePath = "glambda/players/"
local includeFiles = file.Find( includePath .. "*", "LUA", "nameasc" )

for _, lua in ipairs( includeFiles ) do
    include( includePath .. lua )
end

--

function GLAMBDA:CreateLambdaPlayer()
    if game.SinglePlayer() then 
        ErrorNoHalt( "GLambda Players: Trying to create a player in a single player session. (Create a multiplayer one instead!)" ) 
        return
    end
    if player.GetCount() == game.MaxPlayers() then 
        ErrorNoHalt( "GLambda Players: No more players can be spawned. (Player Limit Reached!)" ) 
        return
    end

    --

    
    local names = self.Nicknames
    local ply = player.CreateNextBot( #names != 0 and names[ GLAMBDA:Random( #names ) ] or "GLambda Player" )
    ply.gb_IsLambdaPlayer = true
    
    local rndPm = self:GetRandomPlayerModel()
    local pfps = GLAMBDA.ProfilePictures
    if #pfps == 0 then
        ply.gb_ProfilePicture = "spawnicons/" .. string.sub( rndPm, 1, #rndPm - 4 ) .. ".png"
    else
        ply.gb_ProfilePicture = pfps[ GLAMBDA:Random( #pfps ) ]
    end

    --

    local GLACE = GLAMBDA:ApplyPlayerFunctions( ply )
    GLACE:SetThread( coroutine.create( function() 
        GLACE:ThreadedThink() 
        print( "GLambda Players: " .. ply:Name() .. "'s Threaded Think has stopped executing!" ) 
    end ) )

    local navigator = ents.Create( "glace_navigator" )
    navigator:SetOwner( ply )
    navigator:Spawn()
    
    GLACE:SetNavigator( navigator ) 
    navigator:SetPos( GLACE:GetPos() )

    -- Network this player to clients
    net.Start( "glambda_waitforplynet" )
        net.WriteUInt( ply:UserID(), 12 )
        net.WriteString( ply.gb_ProfilePicture )
    net.Broadcast()

    --

    for name, func in pairs( self.Player ) do
        if !isfunction( func ) then continue end

        GLACE[ name ] = function( glace, ... ) 
            return self.Player[ name ]( glace, ... ) 
        end
    end

    --
    
    GLACE.State = "Idle"
    GLACE.TypedTextMsg = ""

    GLACE.TextKeyEnt = nil
    
    GLACE.CombatPathPosition = vector_origin

    GLACE.NextTextTypeT = 0
    GLACE.NextCombatPathUpdateT = 0
    GLACE.NextAmmoCheckT = 0
    GLACE.NextWeaponAttackT = 0
    GLACE.NextWeaponThinkT = 0
    GLACE.NextIdleLineT = ( CurTime() + GLAMBDA:Random( 5, 10 ) )
    GLACE.NextUniversalActionT = ( CurTime() + GLAMBDA:Random( 10, 15, true ) ) 
    GLACE.LastDeathTime = 0
    GLACE.RetreatEndTime = 0
    GLACE.NextNPCCheckT = CurTime()
    GLACE.NextSprayUseT = 0

    GLACE.LookTo_Pos = nil
    GLACE.LookTo_Smooth = 1
    GLACE.LookTo_EndT = nil
    GLACE.LookTo_Priority = -1

    --

    ply:SetNW2Vector( "glambda_plycolor", Vector( GLAMBDA:Random( 0.0, 1.0, true ), GLAMBDA:Random( 0.0, 1.0, true ), GLAMBDA:Random( 0.0, 1.0, true ) ) )
    ply:SetNW2Vector( "glambda_wpncolor", Vector( GLAMBDA:Random( 0.0, 1.0, true ), GLAMBDA:Random( 0.0, 1.0, true ), GLAMBDA:Random( 0.0, 1.0, true ) ) )
    
    ply:SetNW2String( "glambda_queuedtext", "" )

    --

    GLACE:CreateGetSetFuncs( "Enemy" )
    GLACE:CreateGetSetFuncs( "StateArg" )
    GLACE:CreateGetSetFuncs( "ThreadState" )
    GLACE:CreateGetSetFuncs( "IsMoving" )
    GLACE:CreateGetSetFuncs( "AbortMovement" )
    GLACE:CreateGetSetFuncs( "LastVoiceType" )
    GLACE:CreateGetSetFuncs( "SpeechEndTime" )
    GLACE:CreateGetSetFuncs( "VoicePitch" )
    GLACE:CreateGetSetFuncs( "TextPerMinute" )

    --

    GLACE:SetSpeechEndTime( 0 )
    GLACE:SetTextPerMinute( GLAMBDA:Random( 3, 10 ) * 100 )
    GLACE:SetVoicePitch( GLAMBDA:Random( self:GetConVar( "voice_pitch_min" ), self:GetConVar( "voice_pitch_max" ) ) )

    --

    GLACE:SetPlayerModel( rndPm )
    GLACE:InitializeHooks( ply, GLACE )
    GLACE:BuildPersonalityTable()

    --

    GLACE:SimpleTimer( 0, function()
        local spawnWep = self:GetConVar( "combat_spawnweapon" )
        if spawnWep == "random" then
            GLACE:SelectRandomWeapon()
        else
            GLACE:SelectWeapon( spawnWep )
        end

        GLACE:ApplySpawnBehavior()
    end )

    local voiceProfile
    if GLAMBDA:Random( 100 ) <= self:GetConVar( "player_vp_chance" ) then
        local profiles = table.GetKeys( self.VoiceProfiles )
        voiceProfile = profiles[ GLAMBDA:Random( #profiles ) ]
    end
    GLACE.VoiceProfile = voiceProfile

    --

    return GLACE
end

-- concommand.Add( "glacebase_spawnlambdaplayer", GLAMBDA.CreatePlayer )