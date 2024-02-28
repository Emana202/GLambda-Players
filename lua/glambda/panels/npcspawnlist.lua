local Color = Color
local vgui_Create = CLIENT and vgui.Create
local list_Get = list.Get
local ipairs = ipairs
local Material = Material
local SortedPairsByMemberValue = SortedPairsByMemberValue
local pairs = pairs

local imageBgClr = Color( 72, 72, 72 )
local cachedMats = {}

local function OpenNPCPanel( ply )
    if !ply:IsSuperAdmin() then  
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "NPC Spawnlist", 800, 500 )
    PANEL:Label( "Click on a NPC on the left to register it for use. Right click a row to the right to unregister it", frame, TOP )

    local leftPanel = PANEL:BasicPanel( frame, LEFT )
    leftPanel:SetSize( 430, 1 )

    local resetDefault = PANEL:Button( frame, BOTTOM, "Reset to Default List" )

    local scrollPnl = PANEL:ScrollPanel( leftPanel, false, FILL )
    local npcLayout = vgui_Create( "DIconLayout", scrollPnl )
    npcLayout:Dock( FILL )
    npcLayout:SetSpaceX( 5 )
    npcLayout:SetSpaceY( 5 )

    local npcList = vgui_Create( "DListView", frame )
    npcList:SetSize( 350, 1 )
    npcList:DockMargin( 10, 0, 0, 0 )
    npcList:Dock( LEFT )
    npcList:AddColumn( "NPCs [Print Name]", 1 )
    npcList:AddColumn( "NPCs [Class Name]", 2 )

    local gameList = list_Get( "NPC" )

    local function AddNPCPanel( class )
        for _, v in ipairs( npcLayout:GetChildren() ) do
            if v:GetNPC() == class then return end 
        end

        local npcPanel = npcLayout:Add( "DPanel" )
        npcPanel:SetSize( 100, 120 )
        npcPanel:SetBackgroundColor( imageBgClr )
        
        local npcImg = vgui_Create( "DImageButton", npcPanel )
        npcImg:SetSize( 1, 100 )
        npcImg:Dock( TOP )
        
        local npcData = gameList[ class ]
        local iconMat = cachedMats[ class ]
        if !iconMat then
            iconMat = Material( npcData and npcData.IconOverride or "entities/" .. class .. ".png" )
            if iconMat:IsError() then 
                iconMat = Material( "entities/" .. class .. ".jpg" ) 
                if iconMat:IsError() then 
                    iconMat = Material( "vgui/entities/" .. class ) 
                end
            end
            if !iconMat:IsError() then
                npcImg:SetMaterial( iconMat )
                cachedMats[ class ] = iconMat
            else
                cachedMats[ class ] = false
            end
        else
            npcImg:SetMaterial( iconMat )
        end

        local npcName = ( npcData and npcData.Name or class )
        PANEL:Label( npcName, npcPanel, TOP )
        
        function npcImg:DoClick()
            npcList:AddLine( npcName, class )
            npcPanel:Remove()
        end

        function npcPanel:GetNPC() return class end
    end

    function npcList:OnRowRightClick( id, line )
        AddNPCPanel( line:GetColumnText( 2 ) )
        self:RemoveLine( id )
    end

    for _, v in SortedPairsByMemberValue( gameList, "Category" ) do
        if v.AdminOnly then continue end
        if v.Class == "glambda_spawner" then continue end -- no
        AddNPCPanel( v.Class )
    end
    
    function resetDefault:DoClick()
        npcList:Clear()
        
        local defList = GLAMBDA.FILE:ReadFile( "materials/glambdaplayers/data/defaultnpcs.vmt", "json", "GAME", false )
        if !defList then return end -- what

        for _, class in ipairs( defList ) do
            npcList:AddLine( ( gameList[ class ] and gameList[ class ].Name or class ), class )

            for _, panel in pairs( npcLayout:GetChildren() ) do
                if panel:GetNPC() == class then 
                    panel:Remove()
                    break
                end 
            end
        end
    end

    function frame:OnClose()
        local classes = {}
        for _, line in pairs( npcList:GetLines() ) do classes[ #classes + 1 ] = line:GetColumnText( 2 ) end
        PANEL:WriteServerFile( "glambda/npclist.json", classes, "json" ) 
    end

    PANEL:RequestDataFromServer( "glambda/npclist.json", "json", function( data )
        if !data then return end

        for _, class in ipairs( data ) do
            npcList:AddLine( ( gameList[ class ] and gameList[ class ].Name or class ), class )

            for _, pnl in ipairs( npcLayout:GetChildren() ) do
                if pnl:GetNPC() == class then
                    pnl:Remove()
                    break
                end 
            end
        end
    end )
end

GLAMBDA:CreateConCommand( "panel_npcspawnlist", OpenNPCPanel, true, "Allows you to choose what NPCs are allowed to be spawned by the players. You must be a super admin to use this panel.", {
    name = "NPC Spawnlist", 
    category = "Panels" 
} )