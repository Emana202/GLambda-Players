local file_CreateDir = file.CreateDir
local chat_AddText = CLIENT and chat.AddText
local vgui_Create = CLIENT and vgui.Create
local string_Explode = string.Explode
local ipairs = ipairs
local table_HasValue = table.HasValue
local table_RemoveByValue = table.RemoveByValue
local table_Merge = table.Merge

file_CreateDir( "glambda/nameimport" )
file_CreateDir( "glambda/exportednames" )

local function OpenNamePanel( ply )
    if !ply:IsSuperAdmin() then  
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", NOTIFY_ERROR, nil, "buttons/button10.wav" )
        return
    end
    local PANEL = GLAMBDA.PANEL

    local frame = PANEL:Frame( "Custom Name Editor", 300, 300 )
    function frame:OnClose() chat_AddText( "Remember to Update Data after any changes!" ) end

    local names = {}
    local hasData = false

    local listView = vgui_Create( "DListView", frame )
    listView:Dock( FILL )
    listView:AddColumn( "Names", 1 )

    local addNameEntry = vgui_Create( "DTextEntry", frame )
    addNameEntry:SetPlaceholderText( "Enter names here!" )
    addNameEntry:Dock( BOTTOM )

    PANEL:Label( "Remove a name by right clicking on it", frame, TOP )
    PANEL:Label( "Remember to Update Data after any changes!", frame, TOP )

    local searchName = PANEL:SearchBar( listView, names, frame )
    searchName:Dock( TOP )

    local labels = {
        "Place exported customnames.vmt files or .txt files that are formatted like",
        "Garry",
        "Spanish Skeleton",
        "Oliver",
        "In the garrysmod/data/glambda/nameimport folder to be able to import them"
    }

    PANEL:ExportPanel( "Name", frame, BOTTOM, "Export Names to file", names, "json", "glambda/exportednames/nameexport.vmt" )

    PANEL:ImportPanel( "Name", frame, BOTTOM, "Import .TXT/.JSON/.VMT files", labels, "glambda/nameimport/*", function( path )
        local fileContent = LAMBDAFS:ReadFile( path, "json" )
        if !fileContent then
            fileContent = LAMBDAFS:ReadFile( path ) 
            fileContent = string_Explode( "\n", fileContent )
        end
        
        local count = 0
        for _, name in ipairs( fileContent ) do
            if table_HasValue( names, name ) then continue end
            PANEL:UpdateSequentialFile( "glambda/customnames.json", name, "json" )

            local line = listView:AddLine( name )
            line:SetSortValue( 1, name )

            count = ( count + 1 )
            names[ #names + 1 ] = name
        end
        chat_AddText( "Imported " .. count .. " names to Server's Custom Names" )
    end )

    function addNameEntry:OnEnter( value )
        if #value == 0 or !hasData then return end
        addNameEntry:SetText( "" )

        if table_HasValue( names, value ) then
            chat_AddText( "Server already has this name!" )
            return 
        end

        local line = listView:AddLine( value )
        line:SetSortValue( 1, value )

        
        names[ #names + 1 ] = value
        chat_AddText( "Added " .. value .. " to the Server's Custom Names" )
        PANEL:UpdateSequentialFile( "glambda/customnames.json", value, "json" )
    end

    function listView:OnRowRightClick( id, line )
        chat_AddText( "Removed " .. line:GetSortValue( 1 ) .. " from the Server's names!" ) 
        table_RemoveByValue( names , line:GetSortValue( 1 ) )

        PANEL:RemoveVarFromSQFile( "glambda/customnames.json", line:GetSortValue( 1 ), "json" ) 
        listView:RemoveLine( id )
    end

    chat_AddText( "Requesting Names from Server.." )
    PANEL:RequestDataFromServer( "glambda/customnames.json", "json", function( data )
        hasData = true
        if !data then return end

        PANEL:SortStrings( data )
        table_Merge( names, data ) 

        for _, name in ipairs( data ) do
            local line = listView:AddLine( name )
            line:SetSortValue( 1, name )
        end

        listView:InvalidateLayout()
    end )
end

GLAMBDA:CreateConCommand( "panel_nicknamelist", OpenNamePanel, true, "Allows you to create and remove custom names for the players. You must be a super admin to use this panel.", {
    name = "Custom Names", 
    category = "Panels" 
} )