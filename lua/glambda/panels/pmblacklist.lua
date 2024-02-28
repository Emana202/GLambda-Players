local IsValid = IsValid
local vgui_Create = CLIENT and vgui.Create
local SortedPairs = SortedPairs
local player_manager_AllValidModels = player_manager.AllValidModels
local pairs = pairs
local chat_AddText = CLIENT and chat.AddText

local function OpenPMBlacklistPanel( ply )
    if IsValid( ply ) and !ply:IsSuperAdmin() then 
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "Playermodel Blacklisting", 600, 500 )
    PANEL:Label( "Click on playermodels to the left to block them. Right click a row on the right to unblock a model", frame, TOP )

    local leftPanel = PANEL:BasicPanel( frame, LEFT )
    leftPanel:SetSize( 290, 1 )

    local rightPanel = PANEL:BasicPanel( frame, LEFT )
    rightPanel:SetSize( 300, 1 )
    rightPanel:DockMargin( 10, 0, 0, 0 )

    local pmScroll = PANEL:ScrollPanel( leftPanel, false, FILL )
    local mdlLayout = vgui_Create( "DIconLayout", pmScroll )
    mdlLayout:Dock( FILL )
    mdlLayout:SetSpaceX( 5 )
    mdlLayout:SetSpaceY( 5 )

    local blockList = vgui_Create( "DListView", rightPanel )
    blockList:Dock( FILL )
    blockList:AddColumn( "Blocked Playermodels", 1 )
    
    function blockList:OnRowRightClick( id, line )
        local icon = mdlLayout:Add( "SpawnIcon" )
        local mdl = line:GetColumnText( 1 )
        icon:SetModel( mdl )

        function icon:DoClick()
            blockList:AddLine( mdl )
            self:Remove()
        end

        self:RemoveLine( id )
    end

    for k, mdl in SortedPairs( player_manager_AllValidModels() ) do
        local icon = mdlLayout:Add( "SpawnIcon" )
        icon:SetModel( mdl )

        function icon:DoClick()
            blockList:AddLine( mdl )
            self:Remove()
        end
    end

    function frame:OnClose()
        local mdls = {}
        for _, line in pairs( blockList:GetLines() ) do 
            mdls[ #mdls + 1 ] = line:GetColumnText( 1 ) 
        end

        PANEL:WriteServerFile( "glambda/pmblocklist.json", mdls, "json" ) 
        chat_AddText( "Remember to Update Data after any changes!" )
    end

    --

    PANEL:RequestDataFromServer( "glambda/pmblocklist.json", "json", function( data )
        if !data then return end

        for _, mdl in pairs( data ) do 
            blockList:AddLine( mdl )

            for _, icon in pairs( mdlLayout:GetChildren() ) do
                if icon:GetModelName() != mdl then continue end 
                icon:Remove(); break
            end
        end
    end )
end

GLAMBDA:CreateConCommand( "panel_pmblacklist", OpenPMBlacklistPanel, true, "Allows you to put playermodels into a blacklist to never be used by the players. You must be a super admin to use this panel.", {
    name = "Playermodel Blacklist", 
    category = "Panels" 
} )