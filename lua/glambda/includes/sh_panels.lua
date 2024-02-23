GLAMBDA.PANEL = {}

local PANEL = GLAMBDA.PANEL

--

if ( CLIENT ) then
    
    function PANEL:Frame( name, width, height )
        local panel = vgui.Create( "DFrame" )
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
        local editablepanel = vgui.Create( "EditablePanel", parent )
        if dock then editablepanel:Dock( dock ) end
        return editablepanel
    end

    function PANEL:NumSlider( parent, dock, default, text, min, max, decimals )
        local numslider = vgui.Create( "DNumSlider", parent )
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
        
        local checkbox = vgui.Create( "DCheckBox", basepnl )
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
        local combobox = vgui.Create( "DComboBox", parent )
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
        local textentry = vgui.Create( "DTextEntry", parent )
        if dock then textentry:Dock( dock ) end
        textentry:SetPlaceholderText( placeholder or "" )
        return textentry
    end

    function PANEL:ColorMixer( parent, dock )
        local mixer = vgui.Create( "DColorMixer", parent )
        if dock then mixer:Dock( dock ) end
        return mixer
    end

    function PANEL:Button( parent, dock, text, doclick )
        local button = vgui.Create( "DButton", parent )
        if dock then button:Dock( dock ) end
        button:SetText( text or "" )
        button.DoClick = doclick
        return button
    end

    function PANEL:ScrollPanel( parent, ishorizontal, dock )
        local class = ishorizontal and "DHorizontalScroller" or "DScrollPanel"
        local scroll = vgui.Create( class, parent )
        if dock then scroll:Dock( dock ) end
        return scroll 
    end

    function PANEL:Label( text, parent, dock )
        local panel = vgui.Create( "DLabel", parent )
        panel:SetText( text )
        if dock then panel:Dock( dock ) end

        return panel
    end

    function PANEL:URLLabel( text, url, parent, dock )
        local panel = vgui.Create( "DLabelURL", parent )
        panel:SetText( text )
        panel:SetURL( url )
        if dock then panel:Dock( dock ) end

        return panel
    end
    
    function PANEL:ExportPanel( name, parent, dock, buttontext, targettable, exporttype, exportpath )
        local button = vgui.Create( "DButton", parent )
        button:SetText( buttontext )
        button:Dock( dock )

        function button:DoClick() 
            GLAMBDA.FILE:WriteFile( exportpath, targettable, exporttype )
            Derma_Message( "Exported file to " .. "garrysmod/data/" .. exportpath, "Export", "Ok" )
        end
    end

    function PANEL:ImportPanel( name, parent, dock, buttontext, labels, searchpath, importfunction )
        local button = vgui.Create( "DButton", parent )
        button:SetText( buttontext )
        button:Dock( dock )

        function button:DoClick() 
            local panel = self:Frame( name .. " Import Panel", 400, 450 )
            for _, label in ipairs( labels ) do
                self:Label( label, panel, TOP )
            end

            local listview = vgui.Create( "DListView", panel )
            listview:Dock( FILL )
            listview:AddColumn( "Files", 1 )

            local files = file.Find( searchpath, "DATA", "nameasc" )
            for _, file in ipairs( files ) do
                local line = listview:AddLine( file )
                line:SetSortValue( 1, file )
            end

            function listview:OnClickLine( line )
                Derma_Query(
                    "Are you sure you want to import" .. line:GetSortValue( 1 ) .. "?",
                    "Confirmation:",
                    "Yes",
                    function() importfunction( string.Replace( searchpath, "*", "" ) .. line:GetSortValue( 1 ) ) end,
                    "No"
                )
            end
        end

        return panel
    end

    function PANEL:SearchBar( listview, tbl, parent, searchkeys, linetextprefix )
        linetextprefix = ( linetextprefix or "" )
        
        local panel = vgui.Create( "DTextEntry", parent )
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
                local match = string.find( string.lower( tostring( var ) ), string.lower( value ) )
                if match then local line = listview:AddLine( var .. linetextprefix ) line:SetSortValue( 1, v ) end
            end
        end

        return panel
    end

    --

    file.CreateDir( "glambda/presets" )
    
    function PANEL:ConVarPresetPanel( name, cvars, presetCat, isClient )
        if !isClient and !LocalPlayer():IsSuperAdmin() then 
            chat.AddText( "This panel requires you to be a super admin due to this handling server data!" ) 
            surface.PlaySound( "buttons/button10.wav" )
            return
        end

        local frame = PANEL:Frame( name, 300, 200 )
        PANEL:Label( "Right Click on a line for options", frame, TOP )

        local presetList = vgui.Create( "DListView", frame )
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

                    surface.PlaySound( "buttons/button15.wav" )
                    chat.AddText( "Deleted Preset " .. line:GetColumnText( 1 ) )
                end )
            end

            menu:AddOption( "Apply " .. line:GetColumnText( 1 ) .. " Preset", function()
                if isClient then
                    for k, v in pairs( line:GetSortValue( 1 ) ) do
                        GetConVar( k ):SetString( v )
                    end
                end

                local json = util.TableToJSON( line:GetSortValue( 1 ) )
                local compressed = util.Compress( json )

                surface.PlaySound( "buttons/button15.wav" )
                chat.AddText( "Applied Preset " .. line:GetColumnText( 1 ) )

                if !isClient and LocalPlayer():IsSuperAdmin() then
                    net.Start( "glambda_setconvarpreset" )
                        net.WriteUInt( #compressed, 32 )
                        net.WriteData( compressed )
                    net.SendToServer()
                end
            end )

            menu:AddOption( "View " .. line:GetColumnText( 1 ) .. " Preset", function()
                local viewframe = PANEL:Frame( line:GetColumnText( 1 ) .. " ConVar List", 300, 200 )

                local convarlist = vgui.Create( "DListView", viewframe )
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
                    chat.AddText( "You can not name a preset named the same as the default!" )
                    return 
                end
                if #str == 0 then 
                    chat.AddText( "No text was inputted!" ) 
                    return 
                end

                for k, v in ipairs( presetList:GetLines() ) do
                    if v:GetColumnText( 1 ) != str then continue end
                        
                    Derma_Query( str .. " already exists! Would you like to overwrite it with the new settings?", "File Overwrite", "Overwrite", function()
                    
                        local newpreset = {}
                        for name, _ in pairs( cvars ) do
                            newpreset[ name ] = GetConVar( name ):GetString()
                        end
        
                        surface.PlaySound( "buttons/button15.wav" )
                        chat.AddText( "Saved to Preset " .. str )
        
                        v:SetSortValue( 1, newpreset )
        
                        GLAMBDA.FILE:UpdateKeyValueFile( "glambda/presets/" .. presetCat .. ".json", { [ str ] = newpreset }, "json" ) 
                    end, "Cancel", function() end )

                    return
                end

                local newpreset = {}
                for name, _ in pairs( cvars ) do
                    newpreset[ name ] = GetConVar( name ):GetString()
                end

                surface.PlaySound( "buttons/button15.wav" )
                chat.AddText( "Saved Preset " .. str )

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

        table.Empty( tbl )
        for _, v in SortedPairs( sortTbl ) do tbl[ #tbl + 1 ] = v end
    end

    function PANEL:RequestDataFromServer( filepath, type, callback )
        net.Start( "glambda_requestdata" )
            net.WriteString( filepath )
            net.WriteString( type )
        net.SendToServer()

        local dataStr = ""
        local bytes = 0

        net.Receive( "glambda_returndata", function()
            local chunkData = net.ReadString()
            dataStr = dataStr .. chunkData
            bytes = ( bytes + #chunkData )
            
            if !net.ReadBool() then return end
            callback( dataStr != "!!NIL" and util.JSONToTable( dataStr ) )
            chat.AddText( "Received all data from server! " .. string.NiceSize( bytes ) .. " of data was received" )
        end )
    end

    function PANEL:RequestVariableFromServer( var, callback )
        net.Start( "glambda_requestvariable" )
            net.WriteString( var )
        net.SendToServer()

        local datastring = ""
        local bytes = 0

        net.Receive( "glambda_returnvariable", function() 
            local chunkdata = net.ReadString()
            local isdone = net.ReadBool()
        
            datastring = datastring .. chunkdata
            bytes = bytes + #chunkdata

            if isdone then
                callback( datastring != "!!NIL" and util.JSONToTable( datastring ) or nil )
                chat.AddText( "Received all data from server! " .. string.NiceSize( bytes ) .. " of data was received" )
            end
        end )
    end

    --

    function PANEL:UpdateSequentialFile( filename, addcontent, type ) 
        net.Start( "glambda_updatesequentialfile" )
            net.WriteString( filename )
            net.WriteType( addcontent )
            net.WriteString( type )
        net.SendToServer() 
    end

    function PANEL:UpdateKeyValueFile( filename, addcontent, type ) 
        net.Start( "glambda_updatekvfile" )
            net.WriteString( filename )
            net.WriteString( util.TableToJSON( addcontent ) )
            net.WriteString( type )
        net.SendToServer() 
    end

    function PANEL:RemoveVarFromSQFile( filename, var, type ) 
        net.Start( "glambda_removevarfromsqfile" )
            net.WriteString( filename )
            net.WriteType( var )
            net.WriteString( type )
        net.SendToServer() 
    end

    function PANEL:RemoveVarFromKVFile( filename, key, type ) 
        net.Start( "glambda_removevarfromkvfile" )
            net.WriteString( filename )
            net.WriteString( key )
            net.WriteString( type )
        net.SendToServer() 
    end

    function PANEL:WriteServerFile( filename, content, type ) 
        net.Start( "glambda_writeserverfile" )
            net.WriteString( filename )
            net.WriteString( util.TableToJSON( { content } ) )
            net.WriteString( type )
        net.SendToServer() 
    end

    function PANEL:DeleteServerFile( filename, path ) 
        net.Start( "glambda_deleteserverfile" )
            net.WriteString( filename )
        net.SendToServer() 
    end

end

--

if ( SERVER ) then

    util.AddNetworkString( "glambda_writeserverfile" )
    util.AddNetworkString( "glambda_deleteserverfile" )
    util.AddNetworkString( "glambda_removevarfromkvfile" )
    util.AddNetworkString( "glambda_removevarfromsqfile" )
    util.AddNetworkString( "glambda_updatekvfile" )
    util.AddNetworkString( "glambda_updatesequentialfile" )
    util.AddNetworkString( "glambda_requestdata" )
    util.AddNetworkString( "glambda_returndata" )

    --

    net.Receive( "glambda_writeserverfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:WriteFile( net.ReadString(), util.JSONToTable( net.ReadString() )[ 1 ], net.ReadString() )
    end )

    net.Receive( "glambda_deleteserverfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        file.Delete( net.ReadString(), "DATA" )
    end )

    net.Receive( "glambda_removevarfromkvfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:RemoveVarFromKVFile( net.ReadString(), net.ReadString(), net.ReadString() )
    end )

    net.Receive( "glambda_removevarfromsqfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:RemoveVarFromSQFile( net.ReadString(), net.ReadType(), net.ReadString() ) 
    end )
    
    net.Receive( "glambda_updatekvfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:UpdateKeyValueFile( net.ReadString(), util.JSONToTable( net.ReadString() ), net.ReadString() ) 
    end )

    net.Receive( "glambda_updatesequentialfile", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        GLAMBDA.FILE:UpdateSequentialFile( net.ReadString(), net.ReadType(), net.ReadString() ) 
    end )

    --
    
    local function DataSplit( data )
        local result, buffer = {}, {}
        for i = 0, #data do
            buffer[ #buffer + 1 ] = string.sub( data, i, i )
            if #buffer != 32768 then continue end

            result[ #result + 1 ] = table.concat( buffer )
            table.Empty( buffer )
        end

        result[ #result + 1 ] = table.concat( buffer )
        return result
    end

    net.Receive( "glambda_requestdata", function( len, ply )
        if !ply:IsSuperAdmin() then return end

        local filepath = net.ReadString()
        local _type = net.ReadString()
        local content = GLAMBDA.FILE:ReadFile( filepath, _type, "DATA" )
        local bytes, index = 0, 0

        LambdaCreateThread( function()
            print( "GLambda Players Net: Preparing to send data from " .. filepath .. " to " .. ply:Name() .. " | " .. ply:SteamID() )

            if !content or table.IsEmpty( content ) then
                net.Start( "glambda_returndata" )
                    net.WriteString( "!!NIL" ) -- JSON chunk
                    net.WriteBool( true ) -- Is done
                net.Send( ply )
            else
                content = util.TableToJSON( content )

                for key, chunk in ipairs( DataSplit( content ) ) do
                    index = ( index + 1 )

                    net.Start( "glambda_returndata" )
                        net.WriteString( chunk )
                        net.WriteBool( index == key )
                    net.Send( ply )

                    bytes = ( bytes + #chunk )
                    coroutine.wait( 0.5 )
                end
            end

            print( "GLambda Players Net: Sent " .. string.NiceSize( bytes ) .. " to " .. ply:Name() .. " | " .. ply:SteamID() )
        end )
    end )

    net.Receive( "glambda_setconvarpreset", function( len, ply )
        if !ply:IsSuperAdmin() then return end
        local bytes = net.ReadUInt( 32 )
        local convars = util.JSONToTable( util.Decompress( net.ReadData( bytes ) ))

        for k, v in pairs( convars ) do GetConVar( k ):SetString( v ) end
        print( "GLambda Players: " .. ply:Name() .. " | " .. ply:SteamID() .. " Applied a preset on the server ")
    end )

end

--

local panels = file.Find( "glambda/panels/*", "LUA", "nameasc" )
for _, luaFile in ipairs( panels ) do
    if ( SERVER ) then
        AddCSLuaFile( "glambda/panels/" .. luaFile )
    end
    if ( CLIENT ) then
        include( "glambda/panels/" .. luaFile )
        print( "GLambda Players: Included Panel [ " .. luaFile .. " ]" )
    end
end