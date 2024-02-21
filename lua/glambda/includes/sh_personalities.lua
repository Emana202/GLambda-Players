GLAMBDA.Personalities = {}

--

function GLAMBDA:CreatePersonalityType( personaName, func )
    local infoName = "personality_" .. string.lower( personaName ) .. "chance"
    self:CreateConVar( infoName, 30, "The chance " .. personaName .. " will be executed.\nPersonality Preset should be set to 'Custom' for this slider to affect newly spawned players!", nil, true, true, 0, 100, { 
        name = personaName .. " Chance", 
        category = "Client Settings" 
    } )
    self.Personalities[ personaName ] = { ( func or false ), "glambda_" .. infoName }
end

--

GLAMBDA:CreatePersonalityType( "Combat", function( self )
    local rndCombat = GLAMBDA:Random( 4 )

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
    -- self:SetState( "SpawnSomething" )

    for name, buildTbl in RandomPairs( GLAMBDA.Buildings ) do
        if !buildTbl[ 1 ]:GetBool() then continue end
    
        local result
        local ok, msg = pcall( function() result = buildTbl[ 2 ]( self ) end )

        if !ok and name != "sents" and name != "npcs" then 
            ErrorNoHaltWithStack( name .. " Building function had a error! If this is from a addon, report it to the author!", msg ) 
        end
        if result then 
            self:DevMsg( "Used a building function: " .. name ) 
            break 
        end
    end
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
    },
    [ "builder" ] = {
        [ "Build" ] = 80,
        [ "Combat" ] = 5,
    }
}

function GLAMBDA:CreatePersonalityPreset( presetName, personaData )
    self.PersonalityPresets[ presetName ] = personaData
end