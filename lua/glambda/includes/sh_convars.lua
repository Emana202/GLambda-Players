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
        local floatPoints = string.Explode( ".", value, false )
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
        local index = ( settingsData and settingsData.index or ( table.Count( self.ConVars.Settings ) + 1 ) )
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

----------------------
-- Console Commands --
----------------------

function GLAMBDA:CreateConCommand( name, func, isClient, desc, settingsTbl )
    if isClient and SERVER then return end

    local cmdName = "glambda_" .. name
    if isClient or SERVER then concommand.Add( cmdName, func, nil, desc ) end

    if CLIENT and settingsTbl then
        self.ConVars.Settings[ name ] = {
            index = ( table.Count( self.ConVars.Settings ) + 1 ),
            settings = settingsTbl
        }

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

        for wepName, wepData in SortedPairs( GLAMBDA.WeaponList ) do
            comboBox:AddChoice( ( wepData.Name or wepName ), wepName )
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
    name = "Personality Preset",
    category = "Client Settings",
    type = "Combo",
    options = function( panel, comboBox )
        comboBox:SetSortItems( false )
        comboBox:AddChoice( "Random", "random" )
        comboBox:AddChoice( "Custom", "custom" )
        comboBox:AddChoice( "Custom Random", "customrng" )

        for preset, _ in SortedPairs( GLAMBDA.PersonalityPresets ) do
            comboBox:AddChoice( string.upper( preset[ 1 ] ) .. string.sub( preset, 2, #preset ), preset )
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
GLAMBDA:CreateConVar( "voice_pitch_min", 100, "The minimum value of the player's voice pitch they can spawn with.", nil, nil, nil, 50, 100, {
    name = "Voice Pitch - Min",
    category = "Voice Options",
} )
GLAMBDA:CreateConVar( "voice_pitch_max", 100, "The maximum value of the player's voice pitch they can spawn with.", nil, nil, nil, 100, 200, {
    name = "Voice Pitch - Max",
    category = "Voice Options",
} )

-- Text Chat Settings --
GLAMBDA:CreateConVar( "textchat_enabled", true, "If the players are allowed to use and type in the text chat.", {
    name = "Enable Text Chat",
    category = "Text Chat Options",
} )
GLAMBDA:CreateConVar( "textchat_limit", 0, "How many total players are allowed to use text chat at once.", nil, nil, nil, 0, 128, {
    name = "Chat Limit",
    category = "Text Chat Options",
} )

-- Building Settings --
GLAMBDA:CreateConVar( "building_undoondeath", true, "If the player's spawned stuff should get undo'd on their death.", {
    name = "Undo All On Death",
    category = "Building",
} )

-- Utilities --
GLAMBDA:CreateConVar( "util_mergelambdafiles", true, "When updating the data, should it also merge the files from Lambda Players, such as voice profiles, sprays, profile pictures, and ect.\nWon't load the ones from the 'data' folder, use 'Transfer Lambda Data' for that instead!\nMake sure to update the data once you change this to actually load in the files!", {
    name = "Merge Lambda Players Files",
    category = "Utilities"
} )

--

local dataUpdCooldown = 0
GLAMBDA:CreateConCommand( "cmd_update_data", function( ply )

    local plyValid = IsValid( ply )
    if plyValid and !ply:IsSuperAdmin() then
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    if CurTime() < dataUpdCooldown then 
        if plyValid then 
            GLAMBDA:SendNotification( ply, "Command is on cooldown! Please wait 3 seconds before trying again", 1, nil, "buttons/button10.wav" )
        end
        return
    end

    dataUpdCooldown = ( CurTime() + 3 )
    print( "GLambda Players: Updated data via console command. Ran by ", ( plyValid and ply:Name() .. " | " .. ply:SteamID() or "Console" ) )
    
    GLAMBDA:UpdateData( true )
    if plyValid then GLAMBDA:SendNotification( ply, "Updated GLambda Data", 3, nil, "buttons/button15.wav" ) end

end, false, "Updates data such as voicelines, names, ect. You must use this after any changes to custom content for changes to take effect!", { 
    name = "Update Data", 
    category = "Utilities" 
} )

local userData = {
    [ "lambdaplayers/playerbirthday.json" ] = "glambda/plybirthday.json",
    [ "lambdaplayers/presets/" ] = "glambda/presets/",
}
GLAMBDA:CreateConCommand( "cmd_transferlambda_clientdata", function( ply )

    for toCopy, newCopy in pairs( userData ) do
        if toCopy[ #toCopy ] == "/" then
            local files = file.Find( toCopy .. "*", "DATA", "nameasc" )
            if !files then continue end

            for _, fileName in ipairs( files ) do
                GLAMBDA.FILE:WriteFile( newCopy .. fileName, GLAMBDA.FILE:ReadFile( toCopy .. fileName, "json" ), "json" )
            end
        end

        if !file.Exists( toCopy, "DATA" ) then continue end
        GLAMBDA.FILE:WriteFile( newCopy, GLAMBDA.FILE:ReadFile( toCopy, "json" ), "json" )
    end

    GLAMBDA:SendNotification( ply, "Transfered Lambda Data", 3, nil, "buttons/button15.wav" )
    print( "GLambda Players: Transfered Lambda client data files via console command." )

end, true, "Transfers and copies the client data files from Lambda Players to GLambda Players, such as personality presets, birthday date, and etc.", { 
    name = "Transfer Lambda Client Data", 
    category = "Utilities" 
} )

local transferFiles = {
    [ "lambdaplayers/npclist.json" ]        = "glambda/npclist.json",
    [ "lambdaplayers/entitylist.json" ]     = "glambda/entitylist.json",
    [ "lambdaplayers/proplist.json" ]       = "glambda/proplist.json",
    [ "lambdaplayers/customnames.json" ]    = "glambda/customnames.json",
    [ "lambdaplayers/profiles.json" ]       = "glambda/profiles.json",
    [ "lambdaplayers/pmblockdata.json" ]    = "glambda/pmblocklist.json",
    [ "lambdaplayers/presets/" ]            = "glambda/presets/",
    [ "lambdaplayers/nameimport/" ]         = "glambda/nameimport/",
    [ "lambdaplayers/exportednames/" ]      = "glambda/exportednames/",
}
GLAMBDA:CreateConCommand( "cmd_transferlambda_serverdata", function( ply )

    local plyValid = IsValid( ply )
    if plyValid and !ply:IsSuperAdmin() then 
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    for toCopy, newCopy in pairs( transferFiles ) do
        if toCopy[ #toCopy ] == "/" then
            local files = file.Find( toCopy .. "*", "DATA", "nameasc" )
            if !files then continue end

            for _, fileName in ipairs( files ) do
                GLAMBDA.FILE:WriteFile( newCopy .. fileName, GLAMBDA.FILE:ReadFile( toCopy .. fileName, "json" ), "json" )
            end
        end

        if !file.Exists( toCopy, "DATA" ) then continue end
        GLAMBDA.FILE:WriteFile( newCopy, GLAMBDA.FILE:ReadFile( toCopy, "json" ), "json" )
    end

    GLAMBDA:UpdateData( true )
    if plyValid then GLAMBDA:SendNotification( ply, "Transfered Lambda Data", 3, nil, "buttons/button15.wav" ) end
    print( "GLambda Players: Transfered Lambda server data files via console command. Ran by ", ( plyValid and ply:Name() .. " | " .. ply:SteamID() or "Console" ) )

end, false, "Transfers and copies the server data files from Lambda Players to GLambda Players, such as names, NPCs, props and etc. You must be a super admin to use this panel.", { 
    name = "Transfer Lambda Server Data", 
    category = "Utilities" 
} )