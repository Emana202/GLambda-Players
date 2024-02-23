local function OpenWeaponRegister( ply )
    if !ply:IsSuperAdmin() then  
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "Weapon Registration List", 800, 500 )

    local leftPanel = PANEL:BasicPanel( frame, LEFT )
    leftPanel:SetSize( 430, 1 )

    local scrollPnl = PANEL:ScrollPanel( leftPanel, false, FILL )
    local wpnLayout = vgui.Create( "DIconLayout", scrollPnl )
    wpnLayout:Dock( FILL )
    wpnLayout:SetSpaceX( 5 )
    wpnLayout:SetSpaceY( 5 )

    local wpnList = vgui.Create( "DListView", frame )
    wpnList:SetSize( 350, 1 )
    wpnList:DockMargin( 10, 0, 0, 0 )
    wpnList:Dock( LEFT )
    wpnList:AddColumn( "Weapons [Print Name]", 1 )
    wpnList:AddColumn( "Weapons [Class Name]", 2 )

    local gameList = list.Get( "Weapon" )

    local function OpenRegFrame( wpnName, wpnClass, wpnData )
        local regFrame = PANEL:Frame( ( wpnData and "Editing" or "Registering" ) .. " Weapon: " .. wpnName .. " (" .. wpnClass .. ")", 560, 600 )
        regFrame:SetBackgroundBlur( true )

        local mainPnl = PANEL:BasicPanel( regFrame, LEFT )
        mainPnl:SetSize( 550, 1 )

        wpnData = ( wpnData or {} )

        --

        PANEL:Label( "How close should the target be in order to be able to fire?", mainPnl, TOP )
        local attackDist = PANEL:NumSlider( mainPnl, TOP, ( wpnData.AttackDistance or 1000 ), "Attack Distance", 0, 10000 )

        PANEL:Label( "If the player is this close to the target, they will start to back off, keeping the distance", mainPnl, TOP )
        local keepDist = PANEL:NumSlider( mainPnl, TOP, ( wpnData.KeepDistance or 500 ), "Keep Distance", 0, 10000 )

        --

        PANEL:Label( "Is this weapon used to attack and kill things?", mainPnl, TOP )
        local isLethal = PANEL:CheckBox( mainPnl, TOP, ( wpnData.IsLethalWeapon == nil and true or wpnData.IsLethalWeapon ), "Is Lethal Weapon" )

        PANEL:Label( "Is this weapon a melee weapon?", mainPnl, TOP )
        local isMelee = PANEL:CheckBox( mainPnl, TOP, ( wpnData.IsMeleeWeapon == nil and false or wpnData.IsMeleeWeapon ), "Is Melee Weapon" )

        PANEL:Label( "Can this weapon be fired by just holding the attack key instead of tapping on it?", mainPnl, TOP )
        local fullAuto = PANEL:CheckBox( mainPnl, TOP, ( wpnData.Automatic == nil and false or wpnData.Automatic ), "Is Full-Auto" )

        PANEL:Label( "Does this weapon have a secondary fire on a right click?", mainPnl, TOP )
        local secondFire = PANEL:CheckBox( mainPnl, TOP, ( wpnData.HasSecondaryFire == nil and false or wpnData.HasSecondaryFire ), "Has Secondary Fire" )

        PANEL:Label( "If the weapon has a secondary fire, what's the chance of the player using it?", mainPnl, TOP )
        local secFireChan = PANEL:NumSlider( mainPnl, TOP, ( wpnData.SecondaryFireChance or 25 ), "Secondary Fire Chance", 1, 100 )

        function isMelee:OnChange( value )
            attackDist:SetValue( value and 100 or 1000 )
            keepDist:SetValue( value and 50 or 500 )
        end

        --

        local callbackCodes = {}
        for callback, cbData in pairs( GLAMBDA.WeaponCallbacks ) do
            local codeButton = PANEL:Button( mainPnl, TOP, 'Write Code For The "' .. callback .. '" Callback', function()
                local codeFrame = PANEL:Frame( "Coding Window", 750, 600 )
                codeFrame:SetBackgroundBlur( true )
                PANEL:Label( cbData.InfoText, codeFrame, TOP )
                PANEL:Label( "Accepted arguments: " .. table.concat( cbData.Arguments, ", " ), codeFrame, TOP )

                local codeEntry = PANEL:TextEntry( codeFrame, FILL )
                codeEntry:SetMultiline( true )
                codeEntry:SetEnterAllowed( false )
                codeEntry:SetTabbingDisabled( false )
                codeEntry:SetValue( wpnData[ callback .. "_PanelCode" ] or wpnData[ callback ] or "" )

                local codeConfirm = PANEL:Button( codeFrame, BOTTOM, "Confirm", function()
                    local entryText = codeEntry:GetText()
                    if #entryText == 0 then
                        callbackCodes[ callback ] = nil
                        return
                    end

                    local argsCode = [[
                        local args = { ... }

                    ]]
                    for index, arg in ipairs( cbData.Arguments ) do
                        argsCode = argsCode .. [[
                            local ]] .. arg .. [[ = args[ ]] .. index .. [[ ]
                        ]]
                    end
                    
                    argsCode = argsCode .. entryText
                    local compileCheck = CompileString( argsCode, "Weapon Register Error: " .. callback )
                    if !compileCheck then return end
                    
                    codeFrame:Close()
                    callbackCodes[ callback ] = { argsCode, entryText }
                end )
            end )
        end

        --

        local registerButton = PANEL:Button( mainPnl, BOTTOM, ( wpnData and "Apply Changes" or "Register Weapon" ), function()
            local compileTbl = {
                Name = wpnName,

                IsLethalWeapon = isLethal:GetChecked(),
                IsMeleeWeapon = isMelee:GetChecked(),
                Automatic = fullAuto:GetChecked(),

                HasSecondaryFire = secondFire:GetChecked(),
                SecondaryFireChance = secFireChan:GetValue(),

                AttackDistance = attackDist:GetValue(),
                KeepDistance = keepDist:GetValue(),
            }

            for cbName, cbFuncs in pairs( callbackCodes ) do
                compileTbl[ cbName ] = cbFuncs[ 1 ]
                compileTbl[ cbName .. "_PanelCode" ] = cbFuncs[ 2 ]
            end

            local inList = false
            if wpnData then
                for _, line in ipairs( wpnList:GetLines() ) do
                    if line:GetColumnText( 2 ) == wpnClass then 
                        table.Merge( wpnData, compileTbl, true )
                        line:SetSortValue( 1, wpnData )

                        inList = true
                        break
                    end
                end
            end
            if !inList then
                local line = wpnList:AddLine( wpnName, wpnClass )
                line:SetSortValue( 1, compileTbl )
            end

            for _, pnl in ipairs( wpnLayout:GetChildren() ) do
                if pnl:GetWeapon() == wpnClass then
                    pnl:Remove()
                    break
                end 
            end
            regFrame:Close()

            GLAMBDA:SendNotification( nil, ( wpnData and "Applied changes to the weapon data" or "Registered new weapon" ), NOTIFY_HINT, nil, "buttons/button15.wav" )
            GLAMBDA:AddWeapon( wpnClass, compileTbl )
            PANEL:WriteServerFile( "glambda/weapons/" .. wpnClass .. ".dat", compileTbl, "json" ) 
        end )

    end

    local function AddWeaponPanel( class )
        for _, v in ipairs( wpnLayout:GetChildren() ) do
            if v:GetWeapon() == class then return end 
        end

        local wpnPanel = wpnLayout:Add( "DPanel" )
        wpnPanel:SetSize( 100, 120 )
        wpnPanel:SetBackgroundColor( imageBgClr )
        
        local wpnImg = vgui.Create( "DImageButton", wpnPanel )
        wpnImg:SetSize( 1, 100 )
        wpnImg:Dock( TOP )
        
        local swepData = gameList[ class ]
        local iconMat = Material( swepData and swepData.IconOverride or "entities/" .. class .. ".png" )
        if iconMat:IsError() then 
            iconMat = Material( "entities/" .. class .. ".jpg" ) 
            if iconMat:IsError() then 
                iconMat = Material( "vgui/entities/" .. class ) 
            end
        end
        if !iconMat:IsError() then wpnImg:SetMaterial( iconMat ) end
        
        local wpnName = ( swepData and swepData.PrintName or class )
        PANEL:Label( wpnName, wpnPanel, TOP )

        function wpnImg:DoClick()
            OpenRegFrame( wpnName, class )
        end

        function wpnPanel:GetWeapon() return class end
    end

    function wpnList:DoDoubleClick( id, line )
        OpenRegFrame( line:GetColumnText( 1 ), line:GetColumnText( 2 ), line:GetSortValue( 1 ) )
    end

    function wpnList:OnRowRightClick( id, line )
        local wepClass = line:GetColumnText( 2 )
        GLAMBDA.WeaponList[ wepClass ] = nil
        PANEL:DeleteServerFile( "glambda/weapons/" .. wepClass .. ".dat" )

        surface.PlaySound( "buttons/button15.wav" )
        self:RemoveLine( id )
    end

    for _, v in SortedPairsByMemberValue( gameList, "Category" ) do
        if !v.Spawnable or v.AdminOnly then continue end
        AddWeaponPanel( v.ClassName )
    end

    for wepClass, wepData in SortedPairs( GLAMBDA.WeaponList ) do
        local wepName = ( wepData.Name or ( gameList[ wepClass ] and gameList[ wepClass ].PrintName or wepClass ) )
        local line = wpnList:AddLine( wepName, wepClass )
        line:SetSortValue( 1, wepData )

        for _, pnl in ipairs( wpnLayout:GetChildren() ) do
            if pnl:GetWeapon() == wepClass then
                pnl:Remove()
                break
            end 
        end
    end
end

GLAMBDA:CreateConCommand( "panel_weaponregister", OpenWeaponRegister, true, "Allows you to add and register usable weapons for the players.", {
    name = "Weapon Registration List", 
    category = "Panels" 
} )