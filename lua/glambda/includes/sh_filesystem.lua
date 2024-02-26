GLAMBDA.FILE = {}

local FILE = GLAMBDA.FILE

file.CreateDir( "glambda" )

--

function FILE:WriteFile( filename, content, type )
	local f = file.Open( filename, ( ( type == "binary" or type == "compressed" ) and "wb" or "w" ), "DATA" )
	if !f then return end

    if type == "json" then
        content = util.TableToJSON( content, true )
    elseif type == "compressed" then
        content = util.TableToJSON( content )
        content = util.Compress( content )
    end

	f:Write( content )
	f:Close()
end

function FILE:ReadFile( filename, type, path )
	local f = file.Open( filename, ( type == "compressed" and "rb" or "r" ), ( path or "DATA" ) )
	if !f then return end

    local str = f:Read( f:Size() )
	f:Close()

    if str and #str != 0 then 
        if type == "json" then
            str = util.JSONToTable( str ) or {}
        elseif type == "compressed" then
            str = util.Decompress( str ) or ""
            str = util.JSONToTable( str ) or {}
        end
    end
	return str
end

--

function FILE:MergeDirectory( dir, tbl, path, addDirs, addFunc )
    if dir[ #dir ] != "/" then dir = dir .. "/" end
    tbl = ( tbl or {} )

    local files, dirs = file.Find( dir .. "*", ( path or "GAME" ), "nameasc" )    
    if files then  
        for _, fileName in ipairs( files ) do
            if addFunc then addFunc( fileName, dir, tbl ) continue end
            tbl[ #tbl + 1 ] = dir .. fileName
        end
    end
    if dirs and ( addDirs == nil or addDirs == true ) then
        for _, addDir in ipairs( dirs ) do self:MergeDirectory( dir .. addDir, tbl ) end
    end

    return tbl
end

--

GLAMBDA.DataUpdateFuncs = ( GLAMBDA.DataUpdateFuncs or {} )

function FILE:CreateUpdateCommand( name, func, isClient, desc, settingName, reloadMenu )
    local dataUpdCooldown = 0
    local function cmdFunc( ply )
        if !isClient and IsValid( ply ) then 
            if !ply:IsSuperAdmin() then 
                GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
                return 
            end
            if CurTime() < dataUpdCooldown then 
                GLAMBDA:SendNotification( ply, "Command is on cooldown! Please wait 3 seconds before trying again", 1, nil, "buttons/button10.wav" )
                return
            end

            dataUpdCooldown = ( CurTime() + 3 )
            GLAMBDA:SendNotification( ply, "Updated Data for " .. settingName .. "!", 3, nil, "buttons/button15.wav" )
        end

        func()

        if !isClient and ( SERVER ) then
            net.Start( "glambda_updatedata" )
                net.WriteString( name )
                net.WriteBool( reloadMenu )
            net.Broadcast()
        end
    end

    GLAMBDA:CreateConCommand( "cmd_updatedata_" .. name, cmdFunc, isClient, desc, { name = "Update " .. settingName, category = "Data Updating" } )
    GLAMBDA.DataUpdateFuncs[ name ] = cmdFunc
end

--

FILE:CreateUpdateCommand( "names", function()
    local defaultNames = FILE:ReadFile( "materials/glambdaplayers/data/names.vmt", "json", "GAME" )
    local customNames = FILE:ReadFile( "glambda/customnames.json", "json" )
    
    local mergeTbl = table.Add( defaultNames, customNames )
    GLAMBDA.Nicknames = FILE:MergeDirectory( "materials/glambdaplayers/data/customnames/", mergeTbl, nil, nil, function( fileName, fileDir, tbl )
        local nameTbl = {}
        local filePath = fileDir .. fileName
        if string.EndsWith( filePath, ".json" ) then
            local jsonContents = FILE:ReadFile( filePath, "json", "GAME" )
            for _, name in ipairs( jsonContents ) do
                if table.HasValue( default, name ) then continue end
                nameTbl[ #nameTbl + 1 ] = name
            end
        else
            local txtContents = FILE:ReadFile( filePath, nil, "GAME" )
            if txtContents then
                for _, name in ipairs( string.Explode( "\n", txtcontents ) ) do
                    if table.HasValue( default, name ) then continue end
                    nameTbl[ #nameTbl + 1 ] = name
                end
            end
        end
        tbl[ #tbl + 1 ] = nameTbl
    end )
end, false, "Updates the list of nicknames the players will use as names.", "Nicknames" )

FILE:CreateUpdateCommand( "pfps", function()
    local pfps = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/custompfps/", pfps )
    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then FILE:MergeDirectory( "materials/lambdaplayers/custom_profilepictures/", pfps ) end
    GLAMBDA.ProfilePictures = pfps
end, false, "Updates the list of profile pictures the players will spawn with.", "Profile Pictures" )

FILE:CreateUpdateCommand( "voicelines", function()
    local voiceLines = {}
    for _, data in ipairs( GLAMBDA.VoiceTypes ) do
        local lineTbl = FILE:MergeDirectory( "sound/" .. data.pathCvar:GetString() )
        voiceLines[ data.name ] = lineTbl
    end
    GLAMBDA.VoiceLines = voiceLines
end, false, "Updates the list of voicelines the players will use to speak in voice chat.", "Voicelines" )

local function MergeVoiceProfiles( tbl, path )
    local fullPath = "sound/" .. path
    local _, profileFiles = file.Find( fullPath .. "*", "GAME", "nameasc" )

    for _, profile in ipairs( profileFiles ) do
        local profileTbl = {}

        for _, data in ipairs( GLAMBDA.VoiceTypes ) do
            local typeName = data.name
            local typePath = fullPath .. profile .. "/" .. typeName .. "/"
    
            local voicelines = file.Find( typePath .. "*", "GAME", "nameasc" )
            if !voicelines or #voicelines == 0 then continue end
    
            local lineTbl = FILE:MergeDirectory( typePath )
            profileTbl[ typeName ] = lineTbl
        end
    
        tbl[ profile ] = profileTbl
    end
end
FILE:CreateUpdateCommand( "voiceprofiles", function()
    local voiceProfiles = {}
    MergeVoiceProfiles( voiceProfiles, "glambdaplayers/voiceprofiles/" )

    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then 
        MergeVoiceProfiles( voiceProfiles, "lambdaplayers/voiceprofiles/" )

        local _, zetaVPs = file.Find( "sound/zetaplayer/custom_vo/vp_*", "GAME", "nameasc" )
        for _, profile in ipairs( zetaVPs ) do
            local profileTbl = {}

            for _, data in ipairs( GLAMBDA.VoiceTypes ) do
                local typeName = data.name
                local typePath = "sound/zetaplayer/custom_vo/" .. profile .. "/" .. typeName .. "/"
        
                local voicelines = file.Find( typePath .. "*", "GAME", "nameasc" )
                if !voicelines or #voicelines == 0 then continue end
        
                local lineTbl = FILE:MergeDirectory( typePath )
                profileTbl[ typeName ] = lineTbl
            end
        
            voiceProfiles[ profile ] = profileTbl
        end
    end

    GLAMBDA.VoiceProfiles = voiceProfiles
end, false, "Updates the list of voice profiles the players will use to speak as.", "Voice Profiles", true )

local function MergeTextMessages( fileName, fileDir, tbl )
    local content = FILE:ReadFile( fileDir .. fileName, "json", "GAME" )
    if !content then
        local txtContents = FILE:ReadFile( fileDir .. fileName, nil, "GAME" )
        if !txtContents then return end
        content = string.Explode( "\n", txtContents )
    end

    local name = string.StripExtension( fileName )
    local textType = string.Explode( "_", name )[ 1 ]

    local typeTbl = ( tbl[ textType ] or {} )
    table.Add( typeTbl, content )
    tbl[ textType ] = typeTbl
end
FILE:CreateUpdateCommand( "textmsgs", function()
    local textTbl = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/texttypes/", textTbl, nil, nil, MergeTextMessages )
    FILE:MergeDirectory( "data/glambdaplayers/texttypes/", textTbl, nil, nil, MergeTextMessages )
    
    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then 
        FILE:MergeDirectory( "lambdaplayers/data/texttypes/", textTbl, nil, nil, MergeTextMessages )
        FILE:MergeDirectory( "lambdaplayers/texttypes/", textTbl, nil, nil, MergeTextMessages )
    end

    GLAMBDA.TextMessages = textTbl
end, false, "Updates the list of text messages the players will use to speak in text chat.", "Text Messages" )

-- function FILE:GetTextProfiles()
--     local textProfiles = {}

--     local profilePath = "materials/lambdaplayers/textprofiles/"
--     local _, profileFiles = file.Find( profilePath .. "*", "GAME", "nameasc" )
--     for _, profile in ipairs( profileFiles ) do
--         textProfiles[ profile ] = {}

--         for _, texttype in ipairs( file.Find( profileFiles .. profile .. "/*", "GAME", "nameasc" ) ) do
--             textProfiles[ profile ][ string.StripExtension( texttype ) ] = {}

--             local content = self:ReadFile( profileFiles .. profile .. "/" .. texttype, "json", "GAME" )
--             if !content then
--                 local txtcontents = self:ReadFile( profileFiles .. profile .. "/" .. texttype, nil, "GAME" )
--                 content = txtcontents and string.Explode( "\n", txtcontents ) or nil
--             end
--             if content then table_Add( textProfiles[ profile ][ string.StripExtension( texttype ) ], content ) end
--         end
--     end

--     return textProfiles
-- end

FILE:CreateUpdateCommand( "sprays", function()
    local sprayTbl = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/sprays/", sprayTbl )
    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then FILE:MergeDirectory( "materials/lambdaplayers/sprays/", sprayTbl ) end
    GLAMBDA.Sprays = sprayTbl
end, false, "Updates the list of images and materials the players will use as their spray.", "Sprays" )

--

FILE:CreateUpdateCommand( "proplist", function()
    local content = FILE:ReadFile( "glambda/proplist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no props registered to spawn!" ) end
    GLAMBDA.SpawnlistProps = ( content or {} )
end, false, "Updates the spawnlist of props the players can spawn from their spawnmenu.", "Spawnmenu Props" )

FILE:CreateUpdateCommand( "entitylist", function()
    local content = FILE:ReadFile( "glambda/entitylist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no entities registered to spawn!" ) end
    GLAMBDA.SpawnlistENTs = ( content or {} )
end, false, "Updates the spawnlist of entities the players can spawn from their spawnmenu.", "Spawnmenu Entities" )

FILE:CreateUpdateCommand( "npclist", function()
    local content = FILE:ReadFile( "glambda/npclist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no NPCs registered to spawn!" ) end
    GLAMBDA.SpawnlistNPCs = ( content or {} )
end, false, "Updates the spawnlist of NPCs the players can spawn from their spawnmenu.", "Spawnmenu NPCs" )

-- function FILE:GetMaterials()
--     if IsValid( ply ) and !ply:IsSuperAdmin() then 
--         GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
--         return 
--     end

--     local defaultMats = self:ReadFile( "materials/glambdaplayers/data/materials.vmt", "json", "GAME" )
--     local customMats = self:ReadFile( "glambda/custommaterials.json", "json" )
    
--     local mergeTbl = table.Add( defaultMats, customMats )
--     for _, mat in ipairs( list.Get( "OverrideMaterials" ) ) do
--         if !table.HasValue( mergeTbl, mat ) then mergeTbl[ #mergeTbl + 1 ] = mat end
--     end
--     GLAMBDA.ToolMaterials = mergeTbl
-- end
-- GLAMBDA:CreateConCommand( "cmd_updatedata_materiallist", FILE.GetMaterials, false, "", {
--     name = "Update Toolgun Materials",
--     category = "Data Updating"
-- } )