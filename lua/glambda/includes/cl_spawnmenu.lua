local function AddGLambdaPlayerTab()
    spawnmenu.AddToolTab( "GLambda Players", "GLambda Players", "lambdaplayers/icon/lambda.png" )
end
hook.Add( "AddToolMenuTabs", "AddGLambdaPlayerTab", AddGLambdaPlayerTab )

--

local clientClr = Color( 255, 145, 0 )
local serverClr = Color( 0, 174, 255 )

local function InstallMPConVarHandling( PANEL, convar, panelType, isClientside )
    if panelType == "Bool" then
        function PANEL:OnChange( val )
            if isClientside then
                RunConsoleCommand( convar, val and "1" or "0" )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( convar )
                    net.WriteString( val and "1" or "0" )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can change Server-Side settings!" )
            end
        end
    elseif panelType == "Text" then 
        function PANEL:OnChange()
            local val = self:GetText()

            if isClientside then
                RunConsoleCommand( convar, val )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( convar )
                    net.WriteString( val )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can change Server-Side settings!" )
            end
        end
    elseif panelType == "Slider" then 
        function PANEL:OnValueChanged( val )
            if isClientside then
                RunConsoleCommand( convar, tostring( val ) )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( convar )
                    net.WriteString( tostring( val ) )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can change Server-Side settings!" )
            end
        end
    elseif panelType == "Color" then 
        function PANEL:ValueChanged( col )
            local rvar = self:GetConVarR()
            local gvar = self:GetConVarG()
            local bvar = self:GetConVarB()

            if isClientside then
                RunConsoleCommand( rvar, tostring( col.r ) )
                RunConsoleCommand( gvar, tostring( col.g ) )
                RunConsoleCommand( bvar, tostring( col.b ) )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( rvar )
                    net.WriteString( tostring( col.r ) )
                net.SendToServer()

                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( gvar )
                    net.WriteString( tostring( col.g ) )
                net.SendToServer()

                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( bvar )
                    net.WriteString( tostring( col.b ) )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can change Server-Side settings!" )
            end
        end
    elseif panelType == "Combo" then 
        function PANEL:OnSelect( index, val, data )
            if isClientside then
                RunConsoleCommand( convar, tostring( data ) )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_updateconvar" )
                    net.WriteString( convar )
                    net.WriteString( tostring( data ) )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can change Server-Side settings!" )
            end
        end
    elseif panelType == "Button" then 
        function PANEL:DoClick()
            if isClientside then
                RunConsoleCommand( convar )
            elseif LocalPlayer():IsSuperAdmin() then
                net.Start( "lambdaplayers_runconcommand" )
                    net.WriteString( convar )
                net.SendToServer()
            else
                chat.AddText( "Only Super Admins can run Server-Side Console Commands!" )
            end
        end
    end
end

local function AddGLambdaPlayersOptions()
    if game.SinglePlayer() then return end
    
    local categories = {}
    local cvarSettings = GLAMBDA.ConVars.Settings
    for _, tbl in pairs( cvarSettings ) do categories[ tbl.category ] = true end

    for catName, _ in pairs( categories ) do
        spawnmenu.AddToolMenuOption( "GLambda Players", "GLambda Players", "glambda_spawnmenucat_" .. catName , catName, "", "", function( panel )
            for _, cvarTbl in ipairs( cvarSettings ) do
                if cvarTbl.category != catName then continue end

                local settingPanel, label
                local cvarName = cvarTbl.cvarName

                if cvarTbl.cvarType == "Slider" then
                    settingPanel = panel:NumSlider( cvarTbl.name, cvarTbl.cvarName, cvarTbl.min, cvarTbl.max, cvarTbl.decimals or 2 )
                    label = panel:ControlHelp( cvarTbl.desc .. "\nDefault Value: " .. cvarTbl.defVal )
                elseif cvarTbl.cvarType == "Bool" then
                    settingPanel = panel:CheckBox( cvarTbl.name, cvarTbl.cvarName )
                    label = panel:ControlHelp( cvarTbl.desc .. "\nDefault Value: " .. ( tobool( cvarTbl.defVal ) == true and "True" or "False") )
                elseif cvarTbl.cvarType == "Text" then
                    settingPanel = panel:TextEntry( cvarTbl.name, cvarTbl.cvarName )
                    label = panel:ControlHelp( cvarTbl.desc .. "\nDefault Value: " .. cvarTbl.defVal )
                elseif cvarTbl.cvarType == "Button" then
                    cvarName = cvarTbl.conCmd
                    settingPanel = panel:Button( cvarTbl.name, cvarTbl.conCmd )
                    label = panel:ControlHelp( cvarTbl.desc )
                elseif cvarTbl.cvarType == "Combo" then
                    settingPanel = panel:ComboBox( cvarTbl.name, cvarTbl.cvarName )

                    local options = cvarTbl.options
                    if isfunction( options ) then
                        local result = options( panel, settingPanel )
                        if result != nil then options = result end
                    end
                    if options != false then
                        for k, j in pairs( options ) do
                            settingPanel:AddChoice( k, j )
                        end
                    end

                    label = panel:ControlHelp( cvarTbl.desc .. "\nDefault Value: " .. cvarTbl.defVal )
                elseif cvarTbl.cvarType == "Color" then
                    panel:Help( cvarTbl.name )

                    settingPanel = vgui.Create( "DColorMixer", panel )
                    panel:AddItem( settingPanel )

                    settingPanel:SetConVarR( cvarTbl.red )
                    settingPanel:SetConVarG( cvarTbl.green )
                    settingPanel:SetConVarB( cvarTbl.blue )

                    label = panel:ControlHelp( cvarTbl.desc .. "\nDefault Color: " .. cvarTbl.defVal )
                else
                    continue
                end

                local isClient = cvarTbl.isClient
                if label then label:SetColor( isClient and clientClr or serverClr ) end
                InstallMPConVarHandling( settingPanel, cvarName, cvarTbl.cvarType, isClient )
            end
        end )
    end
end
hook.Add( "PopulateToolMenu", "AddGLambdaPlayersOptions", AddGLambdaPlayersOptions )