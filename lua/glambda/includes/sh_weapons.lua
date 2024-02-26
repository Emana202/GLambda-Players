GLAMBDA.WeaponList = {}

--

function GLAMBDA:AddWeapon( wepName, wepData )
    wepData = ( wepData or {} )

    if ( SERVER ) then
        net.Start( "glambda_syncweapons" )
            net.WriteString( wepName )
            net.WriteString( wepData.Name or "#" .. wepName )
        net.Broadcast()
    end

    if istable( wepName ) then
        table.Merge( GLAMBDA.WeaponList, wepName )
        return
    end
    
    GLAMBDA.WeaponList[ wepName ] = wepData
end

--

GLAMBDA.WeaponCallbacks = {
    [ "SpecialAttack" ] = {
        Arguments = { "player", "weapon", "target" },
        InfoText = "Ran when the player is about to execute its attack. Return true to override the default action."
    },
    [ "OverrideAim" ] = {
        Arguments = { "player", "weapon", "target" },
        InfoText = "Ran when the player is choosing the target aim position. Return a position to override it."
    },
    [ "OnThink" ] = {
        Arguments = { "player", "weapon" },
        InfoText = "Runs whenever the player is holding this weapon. Returning a number will result in the next call being delayed to said number."
    },
}
GLAMBDA.FILE:CreateUpdateCommand( "weapons", function()
    local wpns = file.Find( "glambda/weapons/*.dat", "DATA", "nameasc" )
    if !wpns then return end

    for _, wpn in ipairs( wpns ) do
        local wpnData = GLAMBDA.FILE:ReadFile( "glambda/weapons/" .. wpn, "json" )
        if !wpnData then continue end
        
        for callFunc, _ in pairs( GLAMBDA.WeaponCallbacks ) do
            local funcString = wpnData[ callFunc ]
            if !funcString or !isstring( funcString ) then continue end
            
            local compiledFunc = CompileString( funcString, "Test Callback Error" )
            if !compiledFunc or !isfunction( compiledFunc ) then continue end
            
            wpnData[ callFunc ] = compiledFunc
        end

        local wepName = string.StripExtension( wpn )
        GLAMBDA.WeaponList[ wepName ] = wpnData
    end
end, false, "Updates the list of weapons the players can use and equip.", "Weapon List" )