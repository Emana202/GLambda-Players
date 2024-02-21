local function OpenPropPanel( ply )
    if IsValid( ply ) and !ply:IsSuperAdmin() then 
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "Prop Panel", 800, 500 )
    PANEL:Label( "Click on models from the browser on the left to register them. Right click a row on the right to remove it", frame, TOP )
    
    local clearprops = vgui.Create( "DButton", frame )
    local resettodefault = vgui.Create( "DButton", frame )
    local filebrowser = vgui.Create( "DFileBrowser", frame )
    local proplist = vgui.Create( "DListView", frame )

    resettodefault:Dock( BOTTOM )
    resettodefault:SetText( "Reset to Default List" )
    
    clearprops:Dock( BOTTOM )
    clearprops:SetText( "Clear Prop List" )

    proplist:SetSize( 400, 1 )
    proplist:Dock( LEFT )
    proplist:AddColumn( "Allowed Props", 1 )

    function proplist:HasModel( mdl )
        for _, line in ipairs( self:GetLines() ) do 
            if line:GetColumnText( 1 ) == string.lower( mdl ) then return true end
        end
        return false
    end

    function clearprops:DoClick() proplist:Clear() end

    function resettodefault:DoClick()
        proplist:Clear()
        local defaultList = GLAMBDA.FILE:ReadFile( "materials/glambdaplayers/data/props.vmt", "json", "GAME" )
        for _, prop in ipairs( defaultList ) do proplist:AddLine( prop ) end
    end

    function proplist:OnRowRightClick( id, line )
        self:RemoveLine( id )
        surface.PlaySound( "buttons/button15.wav" )
    end

    function frame:OnClose()
        local models = {}
        for _, line in pairs( proplist:GetLines() ) do models[ #models + 1 ] = line:GetColumnText( 1 ) end
        PANEL:WriteServerFile( "glambda/proplist.json", models, "json" ) 
    end

    PANEL:RequestDataFromServer( "glambda/proplist.json", "json", function( data ) 
        if !data then return end
        for _, mdl in ipairs( data ) do proplist:AddLine( mdl ) end
    end )

    filebrowser:SetFileTypes( "*.mdl" )
    filebrowser:SetSize( 400, 1 )
    filebrowser:Dock( LEFT )
    filebrowser:SetModels( true )
    filebrowser:SetBaseFolder( "models" )

    function filebrowser:OnSelect( path, pnl )
        if proplist:HasModel( path ) then 
            GLAMBDA:SendNotification( ply, path .. " is already registered!", NOTIFY_ERROR, 3, "buttons/button10.wav" )
            return 
        end

        proplist:AddLine( string.lower( path ) )
        surface.PlaySound( "buttons/button15.wav" )
    end

    local tree = filebrowser.Tree

    timer.Simple( 0, function()
        local files = file.Find( "settings/spawnlist/*", "GAME", "nameasc" )
        
        for _, spawnlist in ipairs( files ) do 
            local tbl = util.KeyValuesToTable( GLAMBDA.FILE:ReadFile( "settings/spawnlist/" .. spawnlist, nil, "GAME" ) )
            
            local contents = tbl.contents
            if !contents then continue end

            local nodec = tree:AddNode( tbl.name, tbl.icon)

            function nodec:DoClick()
                if IsValid( filebrowser.Files ) then 
                    filebrowser.Files:Remove()
                end

                filebrowser.Files = filebrowser.Divider:Add( "DIconBrowser" )
                filebrowser.Files:SetManual( true )
                filebrowser.Files:SetBackgroundColor( Color( 234, 234, 234 ) )

                filebrowser.Divider:SetRight( filebrowser.Files )

                filebrowser.Files:Clear()

                for _, contenttbl in ipairs( contents ) do
                    if contenttbl.type != "model" then continue end

                    local icon = filebrowser.Files:Add( "SpawnIcon" )
                    icon:SetModel( contenttbl.model )

                    function icon:DoClick() 
                        local mdl = string.lower( self:GetModelName() )
                        if proplist:HasModel( mdl ) then 
                            GLAMBDA:SendNotification( ply, mdl .. " is already registered!", NOTIFY_ERROR, 3, "buttons/button10.wav" )
                            return 
                        end

                        proplist:AddLine( mdl )
                        surface.PlaySound( "buttons/button15.wav" )
                    end
                end
            end
        end
    end )
end

GLAMBDA:CreateConCommand( "panel_propspawnlist", OpenPropPanel, true, "Allows you to choose what props are allowed to be spawned by the players. You must be a super admin to use this panel.", {
    name = "Prop Spawnlist", 
    category = "Panels" 
} )