local file_Find = file.Find
local ipairs = ipairs
local include = include
local FindMetaTable = FindMetaTable
local game_SinglePlayer = game.SinglePlayer
local ErrorNoHalt = ErrorNoHalt
local player_GetCount = player.GetCount
local game_MaxPlayers = game.MaxPlayers
local player_CreateNextBot = SERVER and player.CreateNextBot
local string_sub = string.sub
local pairs = pairs
local table_Merge = table.Merge
local table_Copy = table.Copy
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local IsValid = IsValid
local isfunction = isfunction
local coroutine_create = coroutine.create
local print = print
local ents_Create = SERVER and ents.Create
local net_Start = net.Start
local net_WriteUInt = net.WriteUInt
local net_WriteString = net.WriteString
local net_Broadcast = SERVER and net.Broadcast
local CurTime = CurTime
local Vector = Vector
local table_GetKeys = table.GetKeys
local RandomPairs = RandomPairs
local player_GetAll = player.GetAll

--

GLAMBDA.Player = {}

local includePath = "glambda/players/"
local includeFiles = file_Find( includePath .. "*.lua", "LUA", "nameasc" )

for _, lua in ipairs( includeFiles ) do
    include( includePath .. lua )
end

--

local ENT = FindMetaTable( "Entity" )
local PLAYER = FindMetaTable( "Player" )

--

function GLAMBDA:CreateLambdaPlayer()
    if game_SinglePlayer() then 
        ErrorNoHalt( "GLambda Players: Trying to create a player in a single player session. (Create a multiplayer one instead!)" ) 
        return
    end
    if player_GetCount() == game_MaxPlayers() then 
        ErrorNoHalt( "GLambda Players: No more players can be spawned. (Player Limit Reached!)" ) 
        return
    end

    --
    
    local profile, name, pfp, model
    if self:Random( 100 ) <= self:GetConVar( "player_profile_chance" ) then
        local profiles = self.PlayerProfiles
        if profiles then 
            for _, profData in RandomPairs( profiles ) do
                local profName = self:GetProfileInfo( profData, "Name" )
                local nameBusy = false
                for _, ply in ipairs( player_GetAll() ) do
                    if ply:Name() != profName then continue end
                    nameBusy = true; break
                end
                if nameBusy then continue end

                profile = profData
                name = profName
                model = self:GetProfileInfo( profile, "PlayerModel" )
                pfp = self:GetProfileInfo( profile, "ProfilePicture" )
                break
            end
        end
    end

    if !name then
        local names = self.Nicknames
        name = ( #names != 0 and names[ self:Random( #names ) ] or "GLambda Player" )
    end

    local ply = player_CreateNextBot( name )
    ply.gb_IsLambdaPlayer = true

    if !model then model = self:GetRandomPlayerModel() end
    if !pfp then
        local pfps = self.ProfilePictures
        if #pfps == 0 then
            pfp = "spawnicons/" .. string_sub( model, 1, ( #model - 4 ) ) .. ".png"
        else
            pfp = pfps[ self:Random( #pfps ) ]
        end
    end
    ply.gb_ProfilePicture = pfp

    -- Creates a GLACE object for the specified player
    local GLACE = { _PLY = ply }

    -- We copy these meta tables so we can run them on the GLACE table and it will be detoured to the player itself
    for name, func in pairs( table_Merge( table_Copy( ENT ), table_Copy( PLAYER ), true ) ) do
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
    
    GLACE:SetThread( coroutine_create( function() 
        GLACE:ThreadedThink() 
        print( "GLambda Players: " .. ply:Name() .. "'s Threaded Think has stopped executing!" ) 
    end ) )

    local navigator = ents_Create( "glace_navigator" )
    navigator:SetOwner( ply )
    navigator:Spawn()
    
    GLACE:SetNavigator( navigator ) 
    navigator:SetPos( GLACE:GetPos() )

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
    GLACE.NextIdleLineT = ( CurTime() + self:Random( 5, 10 ) )
    GLACE.NextUniversalActionT = ( CurTime() + self:Random( 10, 15, true ) ) 
    GLACE.LastDeathTime = 0
    GLACE.RetreatEndTime = 0
    GLACE.NextNPCCheckT = CurTime()
    GLACE.NextSprayUseT = 0

    GLACE.LookTo_Pos = nil
    GLACE.LookTo_Smooth = 1
    GLACE.LookTo_EndT = nil
    GLACE.LookTo_Priority = -1

    --

    ply:SetNW2Vector( "glambda_plycolor", ( self:GetProfileInfo( profile, "PlayerColor" ) or Vector( self:Random( 0, 1, true ), self:Random( 0, 1, true ), self:Random( 0, 1, true ) ) ) )
    ply:SetNW2Vector( "glambda_wpncolor", ( self:GetProfileInfo( profile, "WeaponColor" ) or Vector( self:Random( 0, 1, true ), self:Random( 0, 1, true ), self:Random( 0, 1, true ) ) ) )

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
    GLACE:SetTextPerMinute( self:Random( 3, 10 ) * 100 )
    GLACE:SetVoicePitch( self:GetProfileInfo( profile, "VoicePitch" ) or self:Random( self:GetConVar( "voice_pitch_min" ), self:GetConVar( "voice_pitch_max" ) ) )

    --

    GLACE:SetPlayerModel( model, ( profile == nil ) )
    GLACE:InitializeHooks( ply, GLACE )


    local persona = self:GetProfileInfo( profile, "Personality" )
    if persona then
        for name, _ in pairs( self.Personalities ) do
            if name == "Speech" then
                persona[ name ] = profile.voice
            elseif name == "Texting" then
                persona[ name ] = profile.text
            else
                persona[ name ] = GLAMBDA:GetProfileInfo( persona, name )
            end
        end
    end

    GLACE:BuildPersonalityTable( persona )

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

    local voiceProfile, textProfile
    if profile then
        voiceProfile = self:GetProfileInfo( profile, "VoiceProfile" )
        textProfile = self:GetProfileInfo( profile, "TextProfile" )

        local mdlSkin = self:GetProfileInfo( profile, "SkinGroup" )
        if mdlSkin then ply:SetSkin( mdlSkin ) end

        local mdlBg = self:GetProfileInfo( profile, "BodyGroups" )
        if mdlBg then
            for index, val in pairs( mdlBg ) do
                ply:SetBodygroup( index, val )
            end
        end
    end

    if !voiceProfile and self:Random( 100 ) <= self:GetConVar( "player_vp_chance" ) then
        local profiles = table_GetKeys( self.VoiceProfiles )
        voiceProfile = profiles[ self:Random( #profiles ) ]
    end
    GLACE.VoiceProfile = voiceProfile

    if !textProfile and self:Random( 100 ) <= self:GetConVar( "player_tp_chance" ) then
        local profiles = table_GetKeys( self.TextProfiles )
        textProfile = profiles[ self:Random( #profiles ) ]
    end
    GLACE.TextProfile = textProfile

    --

    -- Network this player to clients
    net_Start( "glambda_waitforplynet" )
        net_WriteUInt( ply:UserID(), 12 )
        net_WriteString( ply.gb_ProfilePicture )
    net_Broadcast()

    return GLACE
end

-- concommand.Add( "glacebase_spawnlambdaplayer", GLAMBDA.CreatePlayer )