GLAMBDA.Player = {}

local includePath = "glambda/players/"
local includeFiles = file.Find( includePath .. "*.lua", "LUA", "nameasc" )

for _, lua in ipairs( includeFiles ) do
    include( includePath .. lua )
end

--

local ENT = FindMetaTable( "Entity" )
local PLAYER = FindMetaTable( "Player" )

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

    -- Creates a GLACE object for the specified player

    local GLACE = { _PLY = ply }

    -- We copy these meta tables so we can run them on the GLACE table and it will be detoured to the player itself
    for name, func in pairs( table.Merge( table.Copy( ENT ), table.Copy( PLAYER ), true ) ) do
        GLACE[ name ] = function( tblself, ... )
            local ply = GLACE._PLY
            if !ply:IsValid() then 
                ErrorNoHaltWithStack( "Attempt to call " .. name .. " function on a GLambda Player that no longer exists!" ) 
                return 
            end

            return func( ply, ... )
        end
    end

    -- Sometimes you may want to use this for non meta method functions
    function GLACE:GetPlayer() return self._PLY end -- Returns this Glace object's Player
    function GLACE:IsValid() return IsValid( self._PLY ) end -- Returns if this Glace object's Player is valid
    function GLACE:IsStuck() return self._ISSTUCK end -- Returns if the Player is stuck
    function GLACE:GetNavigator() return self._NAVIGATOR end -- Returns this Glace object's Navigating nextbot
    function GLACE:GetThread() return self._THREAD end -- Gets the current running thread
    function GLACE:SetThread( thread ) self._THREAD = thread end -- Sets the current running thread. You should never have to use this
    function GLACE:SetNavigator( nextbot ) self._NAVIGATOR = nextbot end -- Sets this Glace object's Navigating nextbot. You should never have to use this

    ply._GLACETABLE = GLACE
    
    --

    for name, func in pairs( self.Player ) do
        if !isfunction( func ) then continue end

        GLACE[ name ] = function( glace, ... ) 
            return self.Player[ name ]( glace, ... ) 
        end
    end
    
    --
    
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
    
    GLACE.State = "Idle"
    GLACE.CmdSelectWeapon = "weapon_physgun"
    GLACE.ForceWeapon = self:GetConVar( "combat_forcespawnwpn" )
    
    GLACE.CurrentTextMsg = false
    GLACE.TypedTextMsg = ""
    GLACE.TextKeyEnt = nil
    GLACE.QueuedMessages = {}
    
    GLACE.CombatPathPosition = vector_origin

    GLACE.DoorOpenCooldown = 0
    GLACE.CmdButtonQueue = 0 -- The key presses we've done this tick
    GLACE.KeyPressCooldown = {} -- Table for keeping cooldowns for each inkey

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
    GLACE:CreateGetSetFuncs( "NoWeaponSwitch" )

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
        local spawnWep = GLACE.ForceWeapon
        if spawnWep and #spawnWep != 0 then
            if spawnWep == "random" then
                GLACE:SelectRandomWeapon()
            else
                GLACE:SelectWeapon( spawnWep )
            end
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