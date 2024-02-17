GLAMBDA.Player = {}

local includePath = "glambda/players/"
local includeFiles = file.Find( includePath .. "*", "LUA", "nameasc" )

for _, lua in ipairs( includeFiles ) do
    include( includePath .. lua )
end

--

local defNames = {
    "Sorry_an_Error_has_Occurred",
	"I am the Spy",
	"engineer gaming",
	"Ze Uberman",
	"Regret",
	"Sora",
	"Sky",
	"Scarf",
	"Graves",
	"bruh moment",
	"Garrys Mod employee",
	"i havent eaten in 69 days",
	"DOORSTUCK89",
	"PickUp That Can Cop",
	"Never gonna give you up",
	"The Lemon Arsonist",
	"Cave Johnson",
	"Chad",
	"Speedy",
	"Alan",
	"Alpha",
	"Bravo",
	"Delta",
	"Charlie",
	"Echo",
	"Foxtrot",
	"Golf",
	"Hotel",
	"India",
	"Juliet",
	"Kilo",
	"Lima",
	"Lina",
}

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

    local ply = player.CreateNextBot( defNames[ math.random( #defNames ) ] )
    
    ply.gl_IsLambdaPlayer = true
    ply.gl_ProfilePicture = GLAMBDA.ProfilePictures[ math.random( #GLAMBDA.ProfilePictures ) ] 

    ply:SetNW2Vector( "lambdaglace_playercolor", Vector( math.Rand( 0.0, 1.0 ), math.Rand( 0.0, 1.0 ), math.Rand( 0.0, 1.0 ) ) )
    ply:SetNW2Vector( "lambdaglace_weaponcolor", Vector( math.Rand( 0.0, 1.0 ), math.Rand( 0.0, 1.0 ), math.Rand( 0.0, 1.0 ) ) )

    --

    local mdlTbl = GLAMBDA.PlayerModels
    local mdlList = mdlTbl.Default

    local defCount = #mdlList
    local mdlCount = defCount
    if GLAMBDA:GetConVar( "player_addonplymdls" ) then
        mdlCount = ( mdlCount + #mdlTbl.Addons )
    end

    local mdlIndex = math.random( mdlCount )
    if mdlIndex > defCount then
        mdlIndex = ( mdlIndex - defCount )
        mdlList = mdlTbl.Addons
    end

    ply.gb_playermodel = mdlList[ mdlIndex ]
    ply:SetModel( ply.gb_playermodel )

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
    net.Start( "glambda_playerinit" )
        net.WritePlayer( ply )
        net.WriteString( ply.gl_ProfilePicture )
    net.Broadcast()

    GLAMBDA:InitializeHooks( ply, GLACE )

    --

    for name, func in pairs( GLAMBDA.Player ) do
        if !isfunction( func ) then continue end

        GLACE[ name ] = function( self, ... ) 
            return GLAMBDA.Player[ name ]( self, ... ) 
        end
    end

    --

    GLACE:BuildPersonalityTable()

    --

    GLACE.AbortMovement = false
    
    GLACE.State = "Idle"
    GLACE.ThreadState = "Idle"
    GLACE.LastPlayedVoiceType = nil
    
    GLACE.CombatPathPosition = vector_origin
    GLACE.PreCombatMovePos = false

    GLACE.StateVariable = nil
    GLACE.NextCombatPathUpdateT = 0
    GLACE.NextAmmoCheckT = 0
    GLACE.NextWeaponAttackT = 0
    GLACE.NextWeaponThinkT = 0
    GLACE.NextIdleLineT = ( CurTime() + math.random( 5, 10 ) )
    GLACE.NextUniversalActionT = ( CurTime() + math.Rand( 10, 15 ) ) 
    GLACE.LastDeathTime = 0
    GLACE.RetreatEndTime = 0
    GLACE.NextNPCCheckT = CurTime()

    --

    GLACE:CreateGetSetFuncs( "Enemy" )
    GLACE:CreateGetSetFuncs( "IsMoving" )
    GLACE:CreateGetSetFuncs( "SpeechEndTime" )

    --
    
    GLACE:SetSpeechEndTime( 0 )
    GLACE:SetAutoReload( true )
    GLACE:SetAutoSwitchWeapon( false )

    local spawnWep = GLAMBDA:GetConVar( "player_spawnweapon" )
    if spawnWep == "random" then
        GLACE:SelectRandomWeapon()
    else
        GLACE:SwitchToWeapon( spawnWep )
    end

    return GLACE
end

concommand.Add( "glacebase_spawnlambdaplayer", GLAMBDA.CreatePlayer )