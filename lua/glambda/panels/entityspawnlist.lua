local imageBgClr = Color( 72, 72, 72 )

local function OpenEntityPanel( ply )
    if !ply:IsSuperAdmin() then  
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "Entity Spawnlist", 800, 500 )
    PANEL:Label( "Click on an entity on the left to register it for use. Right click a row to the right to unregister it", frame, TOP )

    local leftPanel = PANEL:BasicPanel( frame, LEFT )
    leftPanel:SetSize( 430, 1 )

    local resetDefault = PANEL:Button( frame, BOTTOM, "Reset to Default List" ) 

    local scrollPnl = PANEL:ScrollPanel( leftPanel, false, FILL )
    local entLayout = vgui.Create( "DIconLayout", scrollPnl )
    entLayout:Dock( FILL )
    entLayout:SetSpaceX( 5 )
    entLayout:SetSpaceY( 5 )

    local entList = vgui.Create( "DListView", frame )
    entList:SetSize( 350, 1 )
    entList:DockMargin( 10, 0, 0, 0 )
    entList:Dock( LEFT )
    entList:AddColumn( "ENTs [Print Name]", 1 )
    entList:AddColumn( "ENTs [Class Name]", 2 )

    local gameList = list.Get( "SpawnableEntities" )

    local function AddENTPanel( class )
        for _, v in ipairs( entLayout:GetChildren() ) do
            if v:GetENT() == class then return end 
        end

        local entPanel = entLayout:Add( "DPanel" )
        entPanel:SetSize( 100, 120 )
        entPanel:SetBackgroundColor( imageBgClr )
        
        local entImg = vgui.Create( "DImageButton", entPanel )
        entImg:SetSize( 1, 100 )
        entImg:Dock( TOP )
        
        local iconMat = Material( "entities/" .. class .. ".png" )
        if iconMat:IsError() then 
            iconMat = Material( "entities/" .. class .. ".jpg" ) 
            if iconMat:IsError() then 
                iconMat = Material( "vgui/entities/" .. class ) 
            end
        end
        if !iconMat:IsError() then entImg:SetMaterial( iconMat ) end
        
        local entName = ( gameList[ class ] and gameList[ class ].PrintName or class )
        PANEL:Label( entName, entPanel, TOP )
        
        function entImg:DoClick()
            entList:AddLine( entName, class )
            entPanel:Remove()
        end

        function entPanel:GetENT() return class end
    end

    function entList:OnRowRightClick( id, line )
        AddENTPanel( line:GetColumnText( 2 ) )
        self:RemoveLine( id )
    end

    local npcList = list.Get( "NPC" )
    for _, v in SortedPairsByMemberValue( gameList, "Category" ) do
        local class = v.ClassName
        local isNPC = false
        for _, npc in pairs( npcList ) do 
            if npc.Class == class then 
                isNPC = true
                break
            end 
        end
        if !isNPC then AddENTPanel( class ) end
    end
    
    function resetDefault:DoClick()
        entList:Clear()
        
        local defList = GLAMBDA.FILE:ReadFile( "materials/glambdaplayers/data/defaultentities.vmt", "json", "GAME", false )
        if !defList then return end -- what

        for _, class in ipairs( defList ) do
            entList:AddLine( ( gameList[ class ] and gameList[ class ].PrintName or class ), class )

            for _, panel in pairs( entLayout:GetChildren() ) do
                if panel:GetENT() == class then 
                    panel:Remove()
                    break
                end 
            end
        end
    end

    function frame:OnClose()
        local classes = {}
        for _, line in pairs( entList:GetLines() ) do classes[ #classes + 1 ] = line:GetColumnText( 2 ) end
        PANEL:WriteServerFile( "glambda/entitylist.json", classes, "json" ) 
    end

    PANEL:RequestDataFromServer( "glambda/entitylist.json", "json", function( data )
        if !data then return end

        for _, class in ipairs( data ) do
            entList:AddLine( ( gameList[ class ] and gameList[ class ].PrintName or class ), class )

            for _, pnl in ipairs( entLayout:GetChildren() ) do
                if pnl:GetENT() == class then
                    pnl:Remove()
                    break
                end 
            end
        end
    end )
end

GLAMBDA:CreateConCommand( "panel_entityspawnlist", OpenEntityPanel, true, "Allows you to choose what entities are allowed to be spawned by the players. You must be a super admin to use this panel.", {
    name = "Entity Spawnlist", 
    category = "Panels" 
} )