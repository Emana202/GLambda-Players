GLAMBDA.Personalities = {}

--

function GLAMBDA:CreatePersonalityType( personaName, func )
    local infoName = "personality_" .. string.lower( personaName ) .. "chance"
    self:CreateConVar( infoName, 30, 'The chance that a "' .. personaName .. '" personality chance will be executed.\nPersonality Preset should be set to "Custom" or "Custom Random" to affect newly spawned players!', nil, true, true, 0, 100, { 
        name = personaName .. " Chance", 
        category = "Client Settings" 
    } )
    self.Personalities[ personaName ] = { ( func or false ), "glambda_" .. infoName }
end

--

GLAMBDA:CreatePersonalityType( "Combat", function( self )
    local rndCombat = GLAMBDA:Random( 10 )

    if self:GetWeaponAmmo() == 0 or rndCombat == 1 then
        self:SetState( "GiveSelfAmmo" )
    elseif rndCombat == 2 then
        self:SetState( "HealUp" )
    elseif rndCombat == 3 then
        self:SetState( "ArmorUp" )
    else
        self:SetState( "FindTarget" )
    end
end )

GLAMBDA:CreatePersonalityType( "Build", function( self )
    for name, buildTbl in RandomPairs( GLAMBDA.Buildings ) do
        if !buildTbl[ 1 ]:GetBool() then continue end
    
        local result
        local ok, msg = pcall( function() result = buildTbl[ 2 ]( self ) end )

        if !ok and name != "sents" and name != "npcs" then 
            ErrorNoHaltWithStack( "GLambda Players: " .. name .. " Building function had a error! If this is from an addon, report it to the author!", msg ) 
        end
        if result then 
            self:DevMsg( "Used a building function: " .. name ) 
            break 
        end
    end
end )

GLAMBDA:CreatePersonalityType( "Toolgun", function( self )
    self:SelectWeapon( "gmod_tool" )
    self:SetNoWeaponSwitch( true )

    for name, toolTbl in RandomPairs( GLAMBDA.ToolgunTools ) do
        if !toolTbl[ 1 ]:GetBool() then continue end

        local result
        local ok, msg = pcall( function() result = toolTbl[ 2 ]( self ) end )

        if !ok then 
            ErrorNoHaltWithStack( "GLambda Players: " .. name .. " Toolgun tool function had a error! If this is from an addon, report it to the author!", msg ) 
        end
        if result then 
            self:DevMsg( "Used a toolgun tool function: " .. name ) 
            break 
        end
    end

    self:SetNoWeaponSwitch( false )
end )

--

GLAMBDA:CreatePersonalityType( "Speech" )
GLAMBDA:CreatePersonalityType( "Texting" )
GLAMBDA:CreatePersonalityType( "Cowardness" )

--

GLAMBDA.PersonalityPresets = {
    [ "fighter" ] = {
        [ "Combat" ] = 80,
        [ "Build" ] = 5,
        [ "Toolgun" ] = 5,
    },
    [ "builder" ] = {
        [ "Build" ] = 80,
        [ "Toolgun" ] = 80,
        [ "Combat" ] = 5,
    }
}

function GLAMBDA:CreatePersonalityPreset( presetName, personaData )
    self.PersonalityPresets[ presetName ] = personaData
end