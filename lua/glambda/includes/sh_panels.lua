local vgui_Create = CLIENT and vgui.Create
local pairs = pairs
local Derma_Message = Derma_Message
local ipairs = ipairs
local file_Find = file.Find
local Derma_Query = Derma_Query
local string_Replace = string.Replace
local SortedPairs = SortedPairs
local string_find = string.find
local string_lower = string.lower
local tostring = tostring
local file_CreateDir = file.CreateDir
local LocalPlayer = LocalPlayer
local chat_AddText = CLIENT and chat.AddText
local surface_PlaySound = CLIENT and surface.PlaySound
local DermaMenu = DermaMenu
local GetConVar = GetConVar
local util_TableToJSON = util.TableToJSON
local util_Compress = util.Compress
local net_Start = net.Start
local net_WriteUInt = net.WriteUInt
local net_WriteData = net.WriteData
local net_SendToServer = CLIENT and net.SendToServer
local Derma_StringRequest = Derma_StringRequest
local table_Empty = table.Empty
local net_WriteString = net.WriteString
local net_Receive = net.Receive
local net_ReadString = net.ReadString
local net_ReadBool = net.ReadBool
local util_JSONToTable = util.JSONToTable
local string_NiceSize = string.NiceSize
local net_WriteType = net.WriteType
local util_AddNetworkString = SERVER and util.AddNetworkString
local file_Delete = file.Delete
local net_ReadType = net.ReadType
local string_sub = string.sub
local table_concat = table.concat
local LambdaCreateThread = LambdaCreateThread
local print = print
local table_IsEmpty = table.IsEmpty
local net_WriteBool = net.WriteBool
local net_Send = SERVER and net.Send
local coroutine_wait = coroutine.wait
local net_ReadUInt = net.ReadUInt
local util_Decompress = util.Decompress
local net_ReadData = net.ReadData
local AddCSLuaFile = AddCSLuaFile
local include = include

--

GLAMBDA.PANEL = ( GLAMBDA.PANEL or {} )

local PANEL = GLAMBDA.PANEL

--

if ( CLIENT ) then
    
    function PANEL:Frame( name, width, height )
        local panel = vgui_Create( "DFrame" )
        panel:SetSize( width, height )
        panel:SetSizable( true )
        panel:SetTitle( name )
        panel:SetDeleteOnClose( true )
        panel:SetIcon( "glambdaplayers/icon/glambda.png" )
        panel:Center()
        panel:MakePopup()

        return panel
    end

    function PANEL:BasicPanel( parent, dock )
        local editablepanel = vgui_Create( "EditablePanel", parent )
        if dock then editablepanel:Dock( dock ) end
        return editablepanel
    end

    function PANEL:NumSlider( parent, dock, default, text, min, max, decimals )
        local numslider = vgui_Create( "DNumSlider", parent )
        if dock then numslider:Dock( dock ) end
        numslider:SetText( text or "" )
        numslider:SetMin( min )
        numslider:SetMax( max )
        numslider:SetDecimals( decimals or 0 )
        numslider:SetValue( default )
        return numslider
    end

    function PANEL:CheckBox( parent, dock, default, text )
        local basepnl = self:BasicPanel( parent, dock )
        basepnl:SetSize( 400, 16 )
        
        local checkbox = vgui_Create( "DCheckBox", basepnl )
        checkbox:SetSize( 16, 16 )
        checkbox:Dock( LEFT )
        checkbox:SetChecked( default or false )

        local lbl = self:Label( text, basepnl, LEFT )
        lbl:SetSize( 400, 100 )
        lbl:DockMargin( 5, 0, 0, 0 )

        return checkbox, basepnl, lbl
    end

    function PANEL:ComboBox( parent, dock, options, sequential )
        local choiceindexes = { keys = {}, values = {} }
        local combobox = vgui_Create( "DComboBox", parent )
        if dock then combobox:Dock( dock ) end

        for k, v in pairs( options ) do 
            local keyName = ( sequential and v or k )
            local index = combobox:AddChoice( keyName, v )
            
            choiceindexes.keys[ k ] = index
            choiceindexes.values[ v ] = index
        end

        function combobox:SelectOptionByKey( key )
            if choiceindexes.keys[ key ] then
                combobox:ChooseOptionID( choiceindexes.keys[ key ] )
            elseif choiceindexes.values[ key ] then
                combobox:ChooseOptionID( choiceindexes.values[ key ] )
            elseif key == nil then
                combobox:Clear()
            end
        end

        return combobox
    end

    function PANEL:TextEntry( parent, dock, placeholder )
        local textentry = vgui_Create( "DTextEntry", parent )
        if dock then textentry:Dock( dock ) end
        textentry:SetPlaceholderText( placeholder or "" )
        return textentry
    end

    function PANEL:ColorMixer( parent, dock )
        local mixer = vgui_Create( "DColorMixer", parent )
        if dock then mixer:Dock( dock ) end
        return mixer
    end

    function PANEL:Button( parent, dock, text, doclick )
        local button = vgui_Create( "DButton", parent )
        if dock then button:Dock( dock ) end
        button:SetText( text or "" )
        button.DoClick = doclick
        return button
    end

    function PANEL:ScrollPanel( parent, ishorizontal, dock )
        local class = ishorizontal and "DHorizontalScroller" or "DScrollPanel"
        local scroll = vgui_Create( class, parent )
        if dock then scroll:Dock( dock ) end
        return scroll 
    end

    function PANEL:Label( text, parent, dock )
        local panel = vgui_Create( "DLabel", parent )
        panel:SetText( text )
        if dock then panel:Dock( dock ) end

        return panel
    end

    function PANEL:URLLabel( text, url, parent, dock )
        local panel = vgui_Create( "DLabelURL", parent )
        panel:SetText( text )
        panel:SetURL( url )
        if dock then panel:Dock( dock ) end

        return panel
    end
    
    function PANEL:ExportPanel( name, parent, dock, buttontext, targettable, exporttype, exportpath )
        local button = vgui_Create( "DButton", parent )
        button:SetText( buttontext )
        button:Dock( dock )

        function button:DoClick() 
            GLAMBDA.FILE:WriteFile( exportpath, targettable, exporttype )
            Derma_Message( "Exported file to " .. "garrysmod/data/" .. exportpath, "Export", "Ok" )
        end
    end

    function PANEL:ImportPanel( name, parent, dock, buttontext, labels, searchpath, importfunction )
        local button = vgui_Create( "DButton", parent )
        button:SetText( buttontext )
        button:Dock( dock )

        function button:DoClick() 
            local panel = self:Frame( name .. " Import Panel", 400, 450 )
            for _, label in ipairs( labels ) do
                self:Label( label, panel, TOP )
            end

            local listview = vgui_Create( "DListView", panel )
            listview:Dock( FILL )
            listview:AddColumn( "Files", 1 )

            local files = file_Find( searchpath, "DATA", "nameasc" )
            for _, file in ipairs( files ) do
                local line = listview:AddLine( file )
                line:SetSortValue( 1, file )
            end

            function listview:OnClickLine( line )
                Derma_Query(
                    "Are you sure you want to import" .. line:GetSortValue( 1 ) .. "?",
                    "Confirmation:",
                    "Yes",
                    function() importfunction( string_Replace( searchpath, "*", "" ) .. line:GetSortValue( 1 ) ) end,
                    "No"
                )
            end
        end

        return panel
    end

    function PANEL:SearchBar( listview, tbl, parent, searchkeys, linetextprefix )
        linetextprefix = ( linetextprefix or "" )
        
        local panel = vgui_Create( "DTextEntry", parent )
        panel:SetPlaceholderText( "Search Bar" )

        panel.l_searchtable = tbl

        function panel:SetSearchTable( tbl )
            panel.l_searchtable = tbl
        end

        function panel:OnEnter( value )
            listview:Clear()
            if #value == 0 then 
                for k, v in SortedPairs( panel.l_searchtable ) do
                    local line = listview:AddLine( ( searchkeys and k or v ) .. linetextprefix ) 
                    line:SetSortValue( 1, v )
                end
                
                return 
            end
            
            for k, v in SortedPairs( panel.l_searchtable ) do
                local var = ( searchkeys and k or v )
                local match = string_find( string_lower( tostring( var ) ), string_lower( value ) )
                if match then local line = listview:AddLine( var .. linetextprefix ) line:SetSortValue( 1, v ) end
            end
        end

        return panel
    end

    --

    file_CreateDir( "glambda/presets" )
    
    function PANEL:ConVarPresetPanel( name, cvars, presetCat, isClient )
        if !isClient and !LocalPlayer():IsSuperAdmin() then 
            chat_AddText( "This panel requires you to be a super admin due to this handling server data!" ) 
            surface_PlaySound( "buttons/button10.wav" )
            return
        end

        local frame = PANEL:Frame( name, 300, 200 )
        PANEL:Label( "Right Click on a line for options", frame, TOP )

        local presetList = vgui_Create( "DListView", frame )
        presetList:Dock( FILL )
        presetList:AddColumn( "Presets", 1 )

        local line = presetList:AddLine( "[ Default ]" )
        line:SetSortValue( 1, cvars )

        local presetFile = GLAMBDA.FILE:ReadFile( "glambda/presets/" .. presetCat .. ".json", "json" )
        if presetFile then
            for k, v in SortedPairs( presetFile ) do
                local line = presetList:AddLine( k )
                line:SetSortValue( 1, v )
            end
        end

        function presetList:OnRowRightClick( id, line )
            local menu = DermaMenu( false, presetList )

            if line:GetColumnText( 1 ) != "[ Default ]" then 
                menu:AddOption( "Delete " .. line:GetColumnText( 1 ), function()
                    GLAMBDA.FILE:RemoveVarFromKVFile( "glambda/presets/" .. presetCat .. ".json", line:GetColumnText( 1 ), "json" )
                    presetList:RemoveLine( id )

                    surface_PlaySound( "buttons/button15.wav" )
                    chat_AddText( "Deleted Preset " .. line:GetColumnText( 1 ) )
                end )
            end

            menu:AddOption( "Apply " .. line:GetColumnText( 1 ) .. " Preset", function()
                if isClient then
                    for k, v in pairs( line:GetSortValue( 1 ) ) do
                        GetConVar( k ):SetString( v )
                    end
                end

                local json = util_TableToJSON( line:GetSortValue( 1 ) )
                local compressed = util_Compress( json )

                surface_PlaySound( "buttons/button15.wav" )
                chat_AddText( "Applied Preset " .. line:GetColumnText( 1 ) )

                if !isClient and LocalPlayer():IsSuperAdmin() then
                    net_Start( "glambda_setconvarpreset" )
                        net_WriteUInt( #compressed, 32 )
                        net_WriteData( compressed )
                    net_SendToServer()
                end
            end )

            menu:AddOption( "View " .. line:GetColumnText( 1 ) .. " Preset", function()
                local viewframe = PANEL:Frame( line:GetColumnText( 1 ) .. " ConVar List", 300, 200 )

                local convarlist = vgui_Create( "DListView", viewframe )
                convarlist:Dock( FILL )
                convarlist:AddColumn( "ConVar", 1 )
                convarlist:AddColumn( "Value", 2 )

                for k, v in SortedPairs( line:GetSortValue( 1 ) ) do
                    convarlist:AddLine( k, v )
                end
            end )
        end

        PANEL:Button( frame, BOTTOM, "Save Current Settings", function()
            Derma_StringRequest( "Save Preset", "Enter the name of this preset", "", function( str )
                if str == "[ Default ]" then
                    chat_AddText( "You can not name a preset named the same as the default!" )
                    return 
                end
                if #str == 0 then 
                    chat_AddText( "No text was inputted!" ) 
                    return 
                end

                for k, v in ipairs( presetList:GetLines() ) do
                    if v:GetColumnText( 1 ) != str then continue end
                        
                    Derma_Query( str .. " already exists! Would you like to overwrite it with the new settings?", "File Overwrite", "Overwrite", function()
                    
                        local newpreset = {}
                        for name, _ in pairs( cvars ) do
                            newpreset[ name ] = GetConVar( name ):GetString()
                        end
        
                        surface_PlaySound( "buttons/button15.wav" )
                        chat_AddText( "Saved to Preset " .. str )
        
                        v:SetSortValue( 1, newpreset )
        
                        GLAMBDA.FILE:UpdateKeyValueFile( "glambda/presets/" .. presetCat .. ".json", { [ str ] = newpreset }, "json" ) 
                    end, "Cancel", function() end )

                    return
                end

                local newpreset = {}
                for name, _ in pairs( cvars ) do
                    newpreset[ name ] = GetConVar( name ):GetString()
                end

                surface_PlaySound( "buttons/button15.wav" )
                chat_AddText( "Saved Preset " .. str )

                local line = presetList:AddLine( str )
                line:SetSortValue( 1, newpreset )

                GLAMBDA.FILE:UpdateKeyValueFile( "glambda/presets/" .. presetCat .. ".json", { [ str ] = newpreset }, "json" ) 
            end, nil, "Confirm", "Cancel" )
        end )
    end

    --
    
    function PANEL:SortStrings( tbl )
        local sortTbl = {}
        for _, v in pairs( tbl ) do sortTbl[ v ] = v end

        table_Empty( tbl )
        for _, v in SortedPairs( sortTbl ) do tbl[ #tbl + 1 ] = v end
    end

    function PANEL:RequestDataFromServer( filepath, type, callback )
        net_Start( "glambda_requestdata" )
            net_WriteString( filepath )
            net_WriteString( type )
        net_SendToServer()

        local dataStr = ""
        local bytes = 0

        net_Receive( "glambda_returndata", function()
            local chunkData = net_ReadString()
            dataStr = dataStr .. chunkData
            bytes = ( bytes + #chunkData )
            
            if !net_ReadBool() then return end
            callback( dataStr != "!!NIL" and util_JSONToTable( dataStr ) )
            chat_AddText( "Received all data from server! " .. string_NiceSize( bytes ) .. " of data was received" )
        end )
    end

    function PANEL:RequestVariableFromServer( var, callback )
        net_Start( "glambda_requestvariable" )
            net_WriteString( var )
        net_SendToServer()

        local datastring = ""
        local bytes = 0

        net_Receive( "glambda_returnvariable", function() 
            local chunkdata = net_ReadString()
            local isdone = net_ReadBool()
        
            datastring = datastring .. chunkdata
            bytes = bytes + #chunkdata

            if isdone then
                callback( datastring != "!!NIL" and util_JSONToTable( datastring ) or nil )
                chat_AddText( "Received all data from server! " .. string_NiceSize( bytes ) .. " of data was received" )
            end
        end )
    end

    --

    function PANEL:UpdateSequentialFile( filename, addcontent, type ) 
        net_Start( "glambda_updatesequentialfile" )
            net_WriteString( filename )
            net_WriteType( addcontent )
            net_WriteString( type )
        net_SendToServer() 
    end

    function PANEL:UpdateKeyValueFile( filename, addcontent, type ) 
        net_Start( "glambda_updatekvfile" )
            net_WriteString( filename )
            net_WriteString( util_TableToJSON( addcontent ) )
            net_WriteString( type )
        net_SendToServer() 
    end

    function PANEL:RemoveVarFromSQFile( filename, var, type ) 
        net_Start( "glambda_removevarfromsqfile" )
            net_WriteString( filename )
            net_WriteType( var )
            net_WriteString( type )
        net_SendToServer() 
    end

    function PANEL:RemoveVarFromKVFile( filename, key, type ) 
        net_Start( "glambda_removevarfromkvfile" )
            net_WriteString( filename )
            net_WriteString( key )
            net_WriteString( type )
        net_SendToServer() 
    end

    function PANEL:WriteServerFile( filename, content, type ) 
        net_Start( "glambda_writeserverfile" )
            net_WriteString( filename )
            net_WriteString( util_TableToJSON( { content } ) )
            net_WriteString( type )
        net_SendToServer() 
    end

    function PANEL:DeleteServerFile( filename, path ) 
        net_Start( "glambda_deleteserverfile" )
            net_WriteString( filename )
        net_SendToServer() 
    end

end

--

if ( SERVER ) then

    util_AddNetworkString( "glambda_writeserverfile" )
    util_AddNetworkString( "glambda_deleteserverfile" )
    util_AddNetworkString( "glambda_removevarfromkvfile" )
    util_AddNetworkString( "glambda_removevarfromsqfile" )
    util_AddNetworkString( "glambda_updatekvfile" )
    util_AddNetworkString( "glambda_updatesequentialfile" )
    util_AddNetworkString( "glambda_requestdata" )
    util_AddNetworkString( "glambda_returndata" )

    --

    net_Receive( "glambda_writeserverfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:WriteFile( net_ReadString(), util_JSONToTable( net_ReadString() )[ 1 ], net_ReadString() )
    end )

    net_Receive( "glambda_deleteserverfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        file_Delete( net_ReadString(), "DATA" )
    end )

    net_Receive( "glambda_removevarfromkvfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:RemoveVarFromKVFile( net_ReadString(), net_ReadString(), net_ReadString() )
    end )

    net_Receive( "glambda_removevarfromsqfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:RemoveVarFromSQFile( net_ReadString(), net_ReadType(), net_ReadString() ) 
    end )
    
    net_Receive( "glambda_updatekvfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:UpdateKeyValueFile( net_ReadString(), util_JSONToTable( net_ReadString() ), net_ReadString() ) 
    end )

    net_Receive( "glambda_updatesequentialfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:UpdateSequentialFile( net_ReadString(), net_ReadType(), net_ReadString() ) 
    end )

    --
    
    local function DataSplit( data )
        local result, buffer = {}, {}
        for i = 0, #data do
            buffer[ #buffer + 1 ] = string_sub( data, i, i )
            if #buffer != 32768 then continue end

            result[ #result + 1 ] = table_concat( buffer )
            table_Empty( buffer )
        end

        result[ #result + 1 ] = table_concat( buffer )
        return result
    end

    net_Receive( "glambda_requestdata", function( len, ply )
        if !ply:IsSuperAdmin() then return end

        local filepath = net_ReadString()
        local _type = net_ReadString()
        local content = GLAMBDA.FILE:ReadFile( filepath, _type, "DATA" )
        local bytes, index = 0, 0

        LambdaCreateThread( function()
            print( "GLambda Players Net: Preparing to send data from " .. filepath .. " to " .. ply:Name() .. " | " .. ply:SteamID() )

            if !content or table_IsEmpty( content ) then
                net_Start( "glambda_returndata" )
                    net_WriteString( "!!NIL" ) -- JSON chunk
                    net_WriteBool( true ) -- Is done
                net_Send( ply )
            else
                content = util_TableToJSON( content )

                for key, chunk in ipairs( DataSplit( content ) ) do
                    index = ( index + 1 )

                    net_Start( "glambda_returndata" )
                        net_WriteString( chunk )
                        net_WriteBool( index == key )
                    net_Send( ply )

                    bytes = ( bytes + #chunk )
                    coroutine_wait( 0.5 )
                end
            end

            print( "GLambda Players Net: Sent " .. string_NiceSize( bytes ) .. " to " .. ply:Name() .. " | " .. ply:SteamID() )
        end )
    end )

    net_Receive( "glambda_setconvarpreset", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        local bytes = net_ReadUInt( 32 )
        local convars = util_JSONToTable( util_Decompress( net_ReadData( bytes ) ))

        for k, v in pairs( convars ) do GetConVar( k ):SetString( v ) end
        print( "GLambda Players: " .. ply:Name() .. " | " .. ply:SteamID() .. " Applied a preset on the server ")
    end )

end

--

local panels = file_Find( "glambda/panels/*.lua", "LUA", "nameasc" )
for _, luaFile in ipairs( panels ) do
    if ( SERVER ) then
        AddCSLuaFile( "glambda/panels/" .. luaFile )
    end
    if ( CLIENT ) then
        include( "glambda/panels/" .. luaFile )
        print( "GLambda Players: Included Panel [ " .. luaFile .. " ]" )
    end
end