if ( SERVER ) then
    
    GLAMBDA.Personalities = {}

    function GLAMBDA:CreatePersonalityType( personaName, func )
        self.Personalities[ personaName ] = ( func or true )
    end
    
    --

    GLAMBDA:CreatePersonalityType( "Combat", function( self )
        local rndCombat = math.random( 6 )

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
        self:SetState( "SpawnSomething" )
    end )

    --

    GLAMBDA:CreatePersonalityType( "Speech" )
    GLAMBDA:CreatePersonalityType( "Texting" )
    GLAMBDA:CreatePersonalityType( "Cowardness" )

end

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