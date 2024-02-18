GLAMBDA.ConVars = ( GLAMBDA.ConVars or {} )

if ( CLIENT ) then
    GLAMBDA.ConVars.Settings = {}
end

function GLAMBDA:CreateConVar( name, value, desc, shouldSave, isClient, isUserinfo, min, max, settingsTbl )
    if CLIENT and !settingsTbl then
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

    local flags = FCVAR_REPLICATED
    if shouldSave == nil or shouldSave == true then flags = ( flags + FCVAR_ARCHIVE ) end
    if isUserinfo and isClient then flags = ( flags + FCVAR_USERINFO ) end

    local cvarType
    if isstring( value ) then
        cvarType = ( string.match( value, "[.]" ) and "Float" or "Text" )
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
    local cvar = CreateConVar( cvarName, value, flags, desc, min, max )

    local convarTbl = {}
    convarTbl.convar = cvar
    convarTbl.cvarType = cvarType

    if CLIENT and settingsTbl then
        self.ConVars.Settings[ #self.ConVars.Settings + 1 ] = settingsTbl

        settingsTbl.convar = cvar
        settingsTbl.cvarName = cvarName
        settingsTbl.defVal = value
        settingsTbl.isClient = isClient
        settingsTbl.desc = ( isClient and "Client-Side | " or "Server-Side | " ) .. desc .. ( isClient and "" or "\nConVar: " .. cvarName )

        local settingType = ( settingsTbl.type or cvarType )
        if settingType == "Int" or settingType == "Float" then
            settingsTbl.decimals = ( settingsTbl.decimals or ( settingType == "Float" and 1 or 0 ) )
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

function GLAMBDA:CreateConCommand( name, func, isClient, desc, settingsTbl )
    if isClient and SERVER then return end

    local cmdName = "glambda_cmd_" .. name
    if isClient or SERVER then concommand.Add( cmdName, func, nil, desc ) end

    if CLIENT and settingsTbl then
        self.ConVars.Settings[ #self.ConVars.Settings + 1 ] = settingsTbl

        settingsTbl.conCmd = cmdName
        settingsTbl.isClient = isClient
        settingsTbl.cvarType = "Button"
        settingsTbl.desc = ( isClient and "Client-Side | " or "Server-Side | " ) .. desc .. "\nConsole Command: " .. cmdName
    end
end

--

-- Developer Options --
GLAMBDA:CreateConVar( "debug_glace", false, "Enables debug mode.", false, {
    name = "Debug Mode",
    category = "Debugging"
} )

-- Combat Settings --
GLAMBDA:CreateConVar( "combat_spawnweapon", "random", "The weapon the player should (re)spawn with. Setting to 'random' will make them select random weapons.", {
    name = "Spawn Weapon",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "Random", "random" )
        
        for wepName, _ in SortedPairs( GLAMBDA.WeaponList ) do
            comboBox:AddChoice( wepName, wepName )
        end
        return false
    end,
    category = "Combat Settings"
} )
GLAMBDA:CreateConVar( "combat_targetplys", true, "If the player bots are allowed to target and attack real players.", {
    name = "Target Real Players",
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
GLAMBDA:CreateConVar( "player_personalitypreset", "random", "The personality preset the player should spawn with.", nil, true, true, {
    category = "Client Settings",
    name = "Personality Preset",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "Random", "random" )

        for preset, _ in SortedPairs( GLAMBDA.PersonalityPresets ) do
            comboBox:AddChoice( string.upper( preset[ 1 ] ) .. string.sub( preset, 2, #preset ), preset )
        end
        return false
    end
} )

-- Server Settings --
GLAMBDA:CreateConVar( "player_respawn", true, "If the players should be able to respawn when killed. Disabling will disconnect them instead.", {
    name = "Allow Respawning",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_respawntime", "3.0", "The time the player will respawn after being killed.", nil, nil, nil, 0, 60, {
    name = "Respawn Time",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_addonplymdls", false, "Allows the players to use the server's addon playermodels instead of only the default ones.", {
    name = "Addon Playermodels",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_onlyaddonpms", false, "If addon playermodels are allowed, makes the players use only them and not the default ones.", {
    name = "Only Addon Playermodels",
    category = "Server Settings",
} )
GLAMBDA:CreateConVar( "player_vp_chance", 0, "The chance that a player will be created with a random voice profile assigned to them.", nil, nil, nil, 0, 100, {
    name = "Voice Profile Chance",
    category = "Server Settings",
} )

-- Voice Settings --
GLAMBDA:CreateConVar( "voice_globalchat", true, "If the players should speak in the global voice chat.", {
    name = "Global Voice Chat",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_volume", "1.0", "The sound volume of the players' voice chat.", nil, true, nil, 0, 1, {
    name = "Voice Chat Volume",
    decimals = 2,
    category = "Voice Options",
} )

-- Utilities --
local dataUpdCooldown = 0
GLAMBDA:CreateConCommand( "updatedata", function( ply )
    if IsValid( ply ) and !ply:IsSuperAdmin() then return end
    if CurTime() < dataUpdCooldown then return end
    print( "GLambda Players: Updated data via console command. Ran by ", ( IsValid( ply ) and ply:Name() .. " | " .. ply:SteamID() or "Console" )  )

    GLAMBDA:UpdateVoiceData()
    GLAMBDA:UpdatePlayerModels()
end, false, "Updates data such as voicelines, names, ect. You must use this after any changes to custom content for changes to take effect!", { 
    name = "Update Data", category = "Utilities" 
} )