GLAMBDA.WeaponList = ( GLAMBDA.WeaponList or {} )
GLAMBDA.WeaponPermissions = ( GLAMBDA.WeaponPermissions or {} )

file.CreateDir( "glambda/weapons" )

--

function GLAMBDA:AddWeapon( wepName, wepData )
    wepData = ( wepData or {} )

    if ( SERVER ) then
        net.Start( "glambda_syncweapons" )
            net.WriteString( wepName )
            net.WriteString( wepData.Name or "#" .. wepName )
            net.WriteString( wepData.Category or "" )
        net.Broadcast()
    end

    if istable( wepName ) then
        table.Merge( GLAMBDA.WeaponList, wepName )
        return
    end
    
    GLAMBDA.WeaponList[ wepName ] = wepData
end

function GLAMBDA:ReadDefaultWeapons( reset )
    local defWpns = file.Find( "materials/glambdaplayers/data/defaultwpns/*.vmt", "GAME", "nameasc" )
    if !defWpns or #defWpns == 0 then return end

    for _, wpn in ipairs( defWpns ) do
        local wpnPath = "glambda/weapons/" .. string.StripExtension( wpn ) .. ".dat"
        if !reset and file.Exists( wpnPath, "DATA" ) then continue end
        self.FILE:WriteFile( wpnPath, self.FILE:ReadFile( "materials/glambdaplayers/data/defaultwpns/" .. wpn, nil, "GAME" ) )
    end
end

--

GLAMBDA.WeaponCallbacks = {
    [ "SpecialAttack" ] = {
        Arguments = { "player", "weapon", "target" },
        InfoText = {
            "Ran when the player is about to execute its attack with this weapon. Return true to override the default action.",
            "Useful for coding in other types of attacks when the default secondary fire is not enough."
        }
    },
    [ "OverrideAim" ] = {
        Arguments = { "player", "weapon", "target", "isVisible" },
        InfoText = {
            "Ran when the player is choosing where to aim at the target with this weapon. Return a position to override it.",
            "'isVisible' returns if the target is visible to us.",
            "Useful when a weapon fires a projectile and want players to predict the target's movement with their velocity."
        }
    },
    [ "OnThink" ] = {
        Arguments = { "player", "weapon" },
        InfoText = "Runs whenever the player is holding this weapon. Returning a number will result in the next call being delayed to said number."
    },
    [ "OverrideMovePos" ] = {
        Arguments = { "player", "weapon", "target", "curPos", "isVisible", "inAttackRange", "InKeepRange" },
        InfoText = {
            "Runs whenever the player is moving in combat with this weapon. Return a position to override it.",
            "'isVisible' returns if the target is visible to us.",
            "'inAttackRange' returns if we're in the attack range. 'InKeepRange' returns if we're in the keep distance range."
        }
    },
    [ "OnEquip" ] = {
        Arguments = { "player", "weapon" },
        InfoText = {
            "Ran when the player is just equipped this weapon.",
            "Good for setting up variables for future use in other callbacks."
        }
    },
    [ "OnCanTarget" ] = {
        Arguments = { "player", "weapon", "target" },
        InfoText = {
            "Ran when the player is checking a entity if they can target and attack them with this weapon.",
            "Return true to make them targetable, false otherwise.",
            "Useful when the weapon either can only damage certain entities or is unique, like medkit."
        }
    }
}
local function MergeWeapons( fileDir, path )
    local wpns = file.Find( fileDir .. "*.dat", path, "nameasc" )
    if !wpns then return end

    for _, wpn in ipairs( wpns ) do
        local wpnData = GLAMBDA.FILE:ReadFile( fileDir .. wpn, "json" )
        if !wpnData then continue end
        
        local mountsNeed = wpnData.MountsRequired
        if mountsNeed then
            local hasMounts = true
            for _, mount in ipairs( mountsNeed ) do
                hasMounts = IsMounted( mount )
                if !hasMounts then break end
            end
            if !hasMounts then
                print( "GLambda Players: Unable to add " .. ( wpnData.Name or wepName ) .. " to weapon list [ " .. wpn .. " ]; No required mounts! " .. table.concat( mountsNeed, ", " ) )
                continue
            end
        end

        local wepName = string.StripExtension( wpn )
        for callFunc, _ in pairs( GLAMBDA.WeaponCallbacks ) do
            local funcString = wpnData[ callFunc ]
            if !funcString or !isstring( funcString ) then continue end
            
            local compiledFunc = CompileString( funcString, wepName .. " " .. callFunc .. " Callback Error" )
            if !compiledFunc then continue end

            wpnData[ callFunc ] = compiledFunc
        end

        print( "GLambda Players: Added " .. ( wpnData.Name or wepName ) .. " to weapon list [ " .. wpn .. " ]" )
        GLAMBDA.WeaponList[ wepName ] = wpnData
    end
end
GLAMBDA.FILE:CreateUpdateCommand( "weapons", function()
    table.Empty( GLAMBDA.WeaponList )

    MergeWeapons( "glambda/weapons/", "DATA" )
    MergeWeapons( "materials/glambdaplayers/data/weapons/", "GAME" )
end, false, "Updates the list of weapons the players can use and equip.", "Weapon List", true )

if ( CLIENT ) then

    function GLAMBDA:WeaponSelectPanel( wepSelectVar, includeNone, includeRnd, showAll, showNotif, onSelectFunc )
        showNotif = ( showNotif == nil and true or showNotif )
        includeRnd = ( includeRnd == nil and true or includeRnd )
        includeNone = ( includeNone == nil and false or includeNone )
        
        local PANEL = GLAMBDA.PANEL
        local WEAPONS = GLAMBDA.WeaponList
    
        local mainframe = PANEL:Frame( "Weapon Selection Menu", 700, 500 )
        local mainscroll = PANEL:ScrollPanel( mainframe, true, FILL )
    
        local weplinelist = {}
        local weplistlist = {}
        local catDone = {}
        local wepList = list.Get( "Weapon" )
    
        local isCvar = ( type( wepSelectVar ) == "ConVar" )
        local currentWep = ( isCvar and wepSelectVar:GetString() or wepSelectVar )
        if #currentWep == 0 then
            currentWep = "None"
        elseif currentWep == "random" then
            currentWep = "Random Weapon"
        else
            currentWep = ( WEAPONS[ currentWep ] and WEAPONS[ currentWep ].Name or "!!NON-EXISTENT WEAPON!!" )
        end
        PANEL:Label( "Currenly selected weapon: " .. currentWep, mainframe, TOP )
    
        for _, wepData in pairs( WEAPONS ) do
            local wepCat = wepData.Category
            if catDone[ wepCat ] then continue end
            catDone[ wepCat ] = true

            local originlist = vgui.Create( "DListView", mainscroll )
            originlist:SetSize( 200, 400 )
            originlist:Dock( LEFT )
            originlist:AddColumn( wepCat, 1 )
            originlist:SetMultiSelect( false )
    
            function originlist:DoDoubleClick( id, line )
                local selectedWep = line:GetSortValue( 1 )
                if ( !onSelectFunc or onSelectFunc( selectedWep ) != true ) and isCvar then
                    wepSelectVar:SetString( selectedWep )
                end
    
                if showNotif then
                    notification.AddLegacy( "Selected " .. line:GetColumnText( 1 ) .. " from " .. wepCat .. " as a weapon!", NOTIFY_GENERIC, 3 )
                end
                surface.PlaySound( "buttons/button15.wav" )
    
                mainframe:Close()
            end
    
            mainscroll:AddPanel( originlist )
    
            for wepClass, wepData in pairs( WEAPONS ) do
                if wepData.Category != wepCat then continue end
                if !showAll and GLAMBDA.WeaponPermissions[ wepClass ] == false then continue end
                if !wepList[ wepClass ] then continue end
    
                local line = originlist:AddLine( wepData.Name )
                line:SetSortValue( 1, wepClass )
    
                function line:OnSelect()
                    for _, v in ipairs( weplinelist ) do
                        if v != line then v:SetSelected( false ) end
                    end
                end

                weplinelist[ #weplinelist + 1 ] = line
            end
            if #originlist:GetLines() == 0 then
                originlist:Remove()
                continue
            end
    
            originlist:SortByColumn( 1 )
            weplistlist[ #weplistlist + 1 ] = originlist
        end
    
        if #weplistlist > 0 then
            function mainframe:OnSizeChanged( width )
                local columnWidth = math.max( 200, ( width - 10 ) / #weplistlist )
                for _, list in ipairs( weplistlist ) do
                    list:SetWidth( columnWidth )
                end
            end
    
            mainframe:OnSizeChanged( mainframe:GetWide() )
        else
            PANEL:Label( "You currently have every weapon restricted and disallowed to be used by the players!", mainframe, TOP )
        end
    
        if includeNone then
            PANEL:Button( mainframe, BOTTOM, "Select None", function()
                local selectedWep = ""
                if ( !onSelectFunc or onSelectFunc( selectedWep ) != true ) and isCvar then
                    wepSelectVar:SetString( selectedWep )
                end

                if showNotif then
                    notification.AddLegacy( "Selected none as a weapon!", NOTIFY_GENERIC, 3 )
                end
                surface.PlaySound( "buttons/button15.wav" )
        
                mainframe:Close()
            end )
        end
    
        if includeRnd then
            PANEL:Button( mainframe, BOTTOM, "Select Random", function()
                local selectedWep = "random"
                if ( !onSelectFunc or onSelectFunc( selectedWep ) != true ) and isCvar then
                    wepSelectVar:SetString( selectedWep )
                end
    
                if showNotif then
                    notification.AddLegacy( "Selected random as a weapon!", NOTIFY_GENERIC, 3 )
                end
                surface.PlaySound( "buttons/button15.wav" )
    
                mainframe:Close()
            end )
        end
    end

    function GLAMBDA:WeaponPermissionPanel()
        local PANEL = GLAMBDA.PANEL
        local WEAPONS = GLAMBDA.WeaponList

        local mainframe = PANEL:Frame( "Weapon Permissions Menu", 700, 500 )
        local mainscroll = PANEL:ScrollPanel( mainframe, true, FILL )
        PANEL:Label( "Press the weapon category button to toggle all weapons at once", mainframe, TOP )
    
        local weporiginlist = {}
        local wepcheckboxlist = {}
    
        local catDone = {}
        for _, wepData in pairs( WEAPONS ) do
            local wepCat = wepData.Category
            if catDone[ wepCat ] then continue end
            catDone[ wepCat ] = true

            wepcheckboxlist[ wepCat ] = {}
    
            local originpanel = vgui.Create( "DPanel", mainscroll )
            originpanel:Dock( LEFT )
            originpanel:SetSize( 200, 400 )
            weporiginlist[ #weporiginlist + 1 ] = originpanel
    
            PANEL:Button( originpanel, TOP, wepCat, function()
                local checkedcount, uncheckcount = 0, 0
                for _, checkbox in pairs( wepcheckboxlist[ wepCat ] ) do
                    if checkbox:GetChecked() then
                        checkedcount = ( checkedcount + 1 )
                    else
                        uncheckcount = ( uncheckcount + 1 )
                    end
                end
    
                for cvarName, checkbox in pairs( wepcheckboxlist[ wepCat ] ) do
                    local value = ( checkedcount <= uncheckcount )
                    checkbox:SetChecked( value )
                end
            end )
    
            local originscroll = PANEL:ScrollPanel( originpanel, false, FILL )
            mainscroll:AddPanel( originpanel )
            
            for wepClass, wepData in SortedPairs( WEAPONS ) do
                if wepData.Category != wepCat then continue end
                
                local checkbox, checkpanel, lbl = PANEL:CheckBox( originscroll, TOP, true, wepData.Name )
                checkpanel:DockMargin( 2, 2, 0, 2 )
                lbl:SetTextColor( color_black )

                wepcheckboxlist[ wepCat ][ wepClass ] = checkbox
            end
        end
    
        function mainframe:OnSizeChanged( width )
            local columnWidth = math.max( 200, ( width - 10 ) / #weporiginlist )
            for _, list in ipairs( weporiginlist ) do
                list:SetWidth( columnWidth )
            end
        end
        mainframe:OnSizeChanged( mainframe:GetWide() )
        
        function mainframe:OnClose()
            local permTbl = {}
            for _, wepTbl in pairs( wepcheckboxlist ) do
                for wepClass, box in pairs( wepTbl ) do
                    permTbl[ wepClass ] = box:GetChecked()
                end
            end

            net.Start( "glambda_updatewepperms" )
                net.WriteTable( permTbl )
            net.SendToServer()

            table.Merge( GLAMBDA.WeaponPermissions, permTbl )
            PANEL:UpdateKeyValueFile( "glambda/weaponpermissions.json", permTbl, "json" ) 
        end
        
        PANEL:RequestDataFromServer( "glambda/weaponpermissions.json", "json", function( data )
            if !data then return end

            for wepClass, permit in pairs( data ) do
                for _, wepTbl in pairs( wepcheckboxlist ) do
                    local box = wepTbl[ wepClass ]
                    if !box then continue end

                    box:SetChecked( permit )
                    break
                end
            end
        end )
    end

end