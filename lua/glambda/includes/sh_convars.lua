local istable = istable
local isstring = isstring
local string_Explode = string.Explode
local isbool = isbool
local tostring = tostring
local GetConVar = GetConVar
local CreateConVar = CreateConVar
local table_Count = table.Count
local concommand_Add = concommand.Add
local IsValid = IsValid
local SortedPairs = SortedPairs
local string_upper = string.upper
local string_sub = string.sub
local pairs = pairs

GLAMBDA.ConVars = ( GLAMBDA.ConVars or {} )

if ( CLIENT ) then
    GLAMBDA.ConVars.Settings = ( GLAMBDA.ConVars.Settings or {} )
end

--

function GLAMBDA:CreateConVar( name, value, desc, shouldSave, isClient, isUserinfo, min, max, settingsTbl )
    if !settingsTbl then
        if istable( shouldSave ) then 
            settingsTbl = shouldSave 
            shouldSave = true
        elseif istable( isClient ) then 
            settingsTbl = isClient 
            isClient = false
        elseif istable( isUserinfo ) then 
            settingsTbl = isUserinfo 
            isUserinfo = false
        elseif istable( min ) then 
            settingsTbl = min 
            min = nil
        elseif istable( max ) then
            settingsTbl = max
            max = nil
        end
    end
    if isClient and SERVER then return end

    local flags = ( !isClient and FCVAR_REPLICATED or FCVAR_NONE )
    if shouldSave == nil or shouldSave == true then flags = ( flags + FCVAR_ARCHIVE ) end
    if isUserinfo and isClient then flags = ( flags + FCVAR_USERINFO ) end

    local cvarType
    local decimals
    if isstring( value ) then
        local floatPoints = string_Explode( ".", value, false )
        if #floatPoints != 1 then
            cvarType = "Float"
            decimals = #floatPoints[ 2 ]
        else
            cvarType = "Text"
        end
    else
        if isbool( value ) then
            cvarType = "Bool" 
            value = ( value == true and 1 or 0 )

            if !min then min = 0 end
            if !max then max = 1 end
        else
            cvarType = "Int"
        end

        value = tostring( value )
    end

    local cvarName = "glambda_" .. name
    local cvar = ( GetConVar( cvarName ) or CreateConVar( cvarName, value, flags, desc, min, max ) )

    local convarTbl = {}
    convarTbl.convar = cvar
    convarTbl.cvarType = cvarType

    if CLIENT and settingsTbl then
        local settingsData = self.ConVars.Settings[ name ]
        local index = ( settingsData and settingsData.index or ( table_Count( self.ConVars.Settings ) + 1 ) )
        self.ConVars.Settings[ name ] = {
            index = index,
            settings = settingsTbl
        }

        settingsTbl.convar = cvar
        settingsTbl.cvarName = cvarName
        settingsTbl.defVal = value
        settingsTbl.isClient = isClient
        settingsTbl.desc = ( isClient and "Client-Side | " or "Server-Side | " ) .. desc .. ( isClient and "" or "\nConVar: " .. cvarName )

        local settingType = ( settingsTbl.type or cvarType )
        if decimals or settingType == "Int" then
            settingsTbl.decimals = ( settingsTbl.decimals or ( decimals or 0 ) )
            settingType = "Slider"
        end
        settingsTbl.cvarType = settingType

        settingsTbl.min = ( cvarType == "Bool" and 0 or min )
        settingsTbl.max = ( cvarType == "Bool" and 1 or max )
    end

    self.ConVars[ name ] = convarTbl
    return cvar
end

function GLAMBDA:GetConVar( name, returnCvar )
    local cvarTbl = self.ConVars[ name ]
    if !cvarTbl then return end

    local convar = cvarTbl.convar
    if returnCvar then return  end

    local cvarType = cvarTbl.cvarType
    if cvarType == "Bool" then
        return convar:GetBool()
    elseif cvarType == "Int" then
        return convar:GetInt()
    elseif cvarType == "Float" then
        return convar:GetFloat()
    end
    return convar:GetString()
end

--

function GLAMBDA:CreateConCommand( name, func, isClient, desc, settingsTbl )
    if isClient and SERVER then return end

    local cmdName = "glambda_" .. name
    if isClient or SERVER then concommand_Add( cmdName, func, nil, desc ) end

    if CLIENT and settingsTbl then
        self.ConVars.Settings[ name ] = {
            index = ( table_Count( self.ConVars.Settings ) + 1 ),
            settings = settingsTbl
        }

        settingsTbl.conCmd = cmdName
        settingsTbl.isClient = isClient
        settingsTbl.cvarType = "Button"
        settingsTbl.desc = ( isClient and "Client-Side | " or "Server-Side | " ) .. desc .. "\nConsole Command: " .. cmdName
    end
end

--

function GLAMBDA:AddConVarWrapper( cvarName, type )
    local cvar = GetConVar( cvarName )
    if !cvar then return end

    self.ConVars[ cvarName ] = {
        convar = cvar,
        cvarType = type
    }
end

GLAMBDA:AddConVarWrapper( "developer", "Bool" )
GLAMBDA:AddConVarWrapper( "ai_ignoreplayers", "Bool" )
GLAMBDA:AddConVarWrapper( "ai_disabled", "Bool" )
GLAMBDA:AddConVarWrapper( "sv_gravity", "Float" )

--

-- Developer Options --
GLAMBDA:CreateConVar( "debug_glace", false, "Enables debug mode.", false, {
    name = "Debug Mode",
    category = "Debugging"
} )

-- Combat Settings --
local forceWep = GLAMBDA:CreateConVar( "combat_forcespawnwpn", "", "The weapon the player will forced to (re)spawn with. Setting to 'random' will make them select random weapons.", {
    name = "Force Weapon",
    category = "Combat Settings"
} )
GLAMBDA:CreateConCommand( "combat_selectforcewpn", function( ply )
    
    if IsValid( ply ) and !ply:IsSuperAdmin() then
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    GLAMBDA:WeaponSelectPanel( forceWep, true )

end, true, "Opens a menu that allows you to select the force spawn weapon for the players.\nYou must be a super admin in order to use this!", {
    name = "Weapon Selection Menu",
    category = "Combat Settings",
} )
GLAMBDA:CreateConCommand( "combat_weaponpermsmenu", function( ply )

    if IsValid( ply ) and !ply:IsSuperAdmin() then
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    GLAMBDA:WeaponPermissionPanel()

end, true, "Opens a menu that allows you to allow and disallow certain weapons to be used by the players.\nYou must be a super admin in order to use this!", {
    name = "Weapon Permission Menu",
    category = "Combat Settings",
} )

GLAMBDA:CreateConVar( "combat_keepforcewep", false, "If the player' forced (re)spawn weapon should always be the one they were initially created with.\nWhen disabled, they'll use the one currenly set in the spawn weapon setting.", {
    name = "Keep Force Weapon",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_noplyrdming", false, "If the players shouldn't randomly start attacking other players when searching for targets to attack.\nThey'll still attack them if they get hit or damaged by them.", {
    name = "No Player RDM'ing",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_ignorefriendnpcs", false, "If the players shouldn't target and attack NPCs that are friendly to them.", {
    name = "Ignore Friendly NPCs",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_attackhostilenpcs", true, "If the players should always target and attack NPCs that are hostile to them when they see them.", {
    name = "Target Hostile NPCs On Sight",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_spawnbehavior", 0, "The combat behavior the player should perform after (re)spawning.\n1 - Attack a random player.\n2 - Attack a random NPC or Nextbot.\n3 - Attack anyone that can be targetted.", nil, nil, nil, 0, 3, {
    name = "Spawn Behavior",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_spawnbehavior_initialspawn", true, "If the combat spawn behavior should only run once after player is first created.", {
    name = "Spawn Behavior - Only On Initial Spawn",
    category = "Combat Settings",
} )
GLAMBDA:CreateConVar( "combat_spawnbehavior_getclosest", true, "If the combat spawn behavior should pick the closest target instead of a random one.", {
    name = "Spawn Behavior - Target Closest Entity",
    category = "Combat Settings",
} )

-- Client Settings --
local spawnWep = GLAMBDA:CreateConVar( "player_spawnweapon", "weapon_physgun", "The weapon your spawned players should (re)spawn with. Setting to 'random' will make them select random weapons.", nil, true, true, {
    name = "Spawn Weapon",
    category = "Client Settings"
} )
GLAMBDA:CreateConCommand( "player_selectspawnwpn", function()

    GLAMBDA:WeaponSelectPanel( spawnWep )

end, true, "Opens a menu that allows you to select the spawn weapon for the players from the weapon list.", {
    name = "Weapon Selection Menu",
    category = "Client Settings",
} )

GLAMBDA:CreateConVar( "player_personalitypreset", "random", "The personality preset the player should spawn with.", nil, true, true, {
    name = "Personality Preset",
    category = "Client Settings",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "Random", "random" )
        comboBox:AddChoice( "Custom", "custom" )
        comboBox:AddChoice( "Custom Random", "customrng" )

        for preset, _ in SortedPairs( GLAMBDA.PersonalityPresets ) do
            comboBox:AddChoice( string_upper( preset[ 1 ] ) .. string_sub( preset, 2, #preset ), preset )
        end
        return false
    end
} )
GLAMBDA:CreateConCommand( "panel_custompersonalitypresets", function( ply )

    local tbl = {}
    for persName, persData in pairs( GLAMBDA.Personalities ) do
        tbl[ persName ] = 30
    end
    GLAMBDA.PANEL:ConVarPresetPanel( "Custom Personality Preset Editor", tbl, "custompersonalities", true )

end, true, "Allow you to create custom personality presets and load them.", {
    name = "Custom Personality Presets",
    category = "Client Settings"
} )
GLAMBDA:CreateConVar( "player_spawn_vp", "", "The voice profile your newly spawned player will have upon creation.", nil, true, true, {
    name = "Voice Profile",
    category = "Client Settings",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "None", "" )
        for vp, _ in SortedPairs( GLAMBDA.VoiceProfiles ) do
            comboBox:AddChoice( vp, vp )
        end
        return false
    end
} )
GLAMBDA:CreateConVar( "player_spawn_tp", "", "The text profile your newly spawned player will have upon creation.", nil, true, true, {
    name = "Text Profile",
    category = "Client Settings",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "None", "" )
        for tp, _ in SortedPairs( GLAMBDA.TextProfiles ) do
            comboBox:AddChoice( tp, tp )
        end
        return false
    end
} )

-- Server Settings --
GLAMBDA:CreateConVar( "player_respawn", true, "If the players should be able to respawn when killed. Disabling will disconnect them instead.", {
    name = "Allow Respawning",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_respawn_time", "5.0", "The time the player will respawn after being killed.", nil, nil, nil, 0, 60, {
    name = "Respawn Time",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_respawn_spawnpoints", false, "If the players should respawn in the map spawnpoints instead of the place they were created.", {
    name = "Respawn In Spawnpoints",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_vp_chance", 0, "The chance that a player will be created with a random voice profile assigned to them.", nil, nil, nil, 0, 100, {
    name = "Voice Profile Chance",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_tp_chance", 0, "The chance that a player will be created with a random text profile assigned to them.", nil, nil, nil, 0, 100, {
    name = "Text Profile Chance",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_profile_chance", 0, "The chance that a player will be created with a random player profile assigned to them.", nil, nil, nil, 0, 100, {
    name = "Player Profile Chance",
    category = "Server Settings",
} )

-- Playermodel Settings --
GLAMBDA:CreateConVar( "player_addonplymdls", false, "Allows the players to use the server's addon playermodels instead of only the default ones.", {
    name = "Addon Playermodels",
    category = "Playermodel Options",
} )
GLAMBDA:CreateConVar( "player_onlyaddonpms", false, "If addon playermodels are allowed, makes the players use only them and not the default ones.", {
    name = "Only Addon Playermodels",
    category = "Playermodel Options",
} )
GLAMBDA:CreateConVar( "player_rngbodygroups", true, "If the player's playermodel should have its skin and bodygroups randomized.", {
    name = "Random Skin & Bodygroups",
    category = "Playermodel Options",
} )

-- Voice Settings --
GLAMBDA:CreateConVar( "voice_globalchat", true, "If the players should speak in the global voice chat.", {
    name = "Global Voice Chat",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_volume", "1.00", "The sound volume of the players' voice chat.", nil, true, nil, 0, 1, {
    name = "Voice Chat Volume",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_norespawn", true, "If the players that are currently speaking can't respawn until they finish their speech.", {
    name = "No Respawn On Speech",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_pitch_min", 100, "The minimum value of the player's voice pitch they can spawn with.", nil, nil, nil, 30, 100, {
    name = "Voice Pitch - Min",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_pitch_max", 100, "The maximum value of the player's voice pitch they can spawn with.", nil, nil, nil, 100, 255, {
    name = "Voice Pitch - Max",
    category = "Voice Options",
} )

-- Text Chat Settings --
GLAMBDA:CreateConVar( "textchat_enabled", true, "If the players are allowed to use and type in the text chat.", {
    name = "Enable Text Chat",
    category = "Text Chat Options",
} )
GLAMBDA:CreateConVar( "textchat_limit", 2, "How many total players are allowed to use text chat at once.", nil, nil, nil, 0, 128, {
    name = "Chat Limit",
    category = "Text Chat Options",
} )

-- Building Settings --
GLAMBDA:CreateConVar( "building_undoondeath", true, "If the player's spawned stuff should get undo'd on their death.", {
    name = "Undo All On Death",
    category = "Building",
} )

-- Data Updating --
GLAMBDA:CreateConVar( "util_mergelambdafiles", true, "When updating the data, should it also merge the files from Lambda Players, such as voice profiles, sprays, profile pictures, and ect.\nWon't load the ones from the 'data' folder, use 'Transfer Lambda Data' for that instead!\nMake sure to update the data once you change this to actually load in the files!", {
    name = "Merge Lambda Players Files",
    category = "Data Updating"
} )