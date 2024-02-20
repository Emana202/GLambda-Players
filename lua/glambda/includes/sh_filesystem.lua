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

function FILE:GetNicknames()
    local defaultNames = self:ReadFile( "materials/glambdaplayers/data/names.vmt", "json", "GAME" )
    local customNames = self:ReadFile( "glambda/customnames.json", "json" )
    
    local mergeTbl = table.Add( defaultNames, customNames )
    return self:MergeDirectory( "materials/glambdaplayers/data/customnames/", mergeTbl, nil, nil, function( fileName, fileDir, tbl )
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
end

function FILE:GetProfilePictures()
    local pfpTbl = {}
    self:MergeDirectory( "materials/glambdaplayers/data/custompfps/", pfpTbl )
    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then self:MergeDirectory( "materials/lambdaplayers/custom_profilepictures/", pfpTbl ) end
    return pfpTbl
end

function FILE:GetVoiceLines()
    local voiceLines = {}
    for _, data in ipairs( GLAMBDA.VoiceTypes ) do
        local lineTbl = self:MergeDirectory( "sound/" .. data.pathCvar:GetString() )
        voiceLines[ data.name ] = lineTbl
    end
    return voiceLines
end

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
function FILE:GetVoiceProfiles()
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
        
                local lineTbl = self:MergeDirectory( typePath )
                profileTbl[ typeName ] = lineTbl
            end
        
            voiceProfiles[ profile ] = profileTbl
        end
    end

    return voiceProfiles
end

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
function FILE:GetTextMessages()
    local textTbl = {}
    self:MergeDirectory( "materials/glambdaplayers/data/texttypes/", textTbl, nil, nil, MergeTextMessages )
    self:MergeDirectory( "data/glambdaplayers/texttypes/", textTbl, nil, nil, MergeTextMessages )
    return textTbl
end

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

function FILE:GetSprays()
    local sprayTbl = {}
    self:MergeDirectory( "materials/glambdaplayers/sprays/", sprayTbl )
    if GLAMBDA:GetConVar( "util_mergelambdafiles" ) then self:MergeDirectory( "materials/lambdaplayers/sprays/", sprayTbl ) end
    return sprayTbl
end

--

function FILE:GetSpawnmenuProps()
    local content = self:ReadFile( "glambda/proplist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no props registered to spawn!" ) end
    return ( content or {} )
end

function FILE:GetSpawnmenuENTs()
    local content = self:ReadFile( "glambda/entitylist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no entities registered to spawn!" ) end
    return ( content or {} )
end

function FILE:GetSpawnmenuNPCs()
    local content = self:ReadFile( "glambda/npclist.json", "json" )
    if !content or #content == 0 then ErrorNoHalt( "GLambda Players: You have no NPCs registered to spawn!" ) end
    return ( content or {} )
end

function FILE:GetMaterials()
    local defaultMats = self:ReadFile( "materials/glambdaplayers/data/materials.vmt", "json", "GAME" )
    local customMats = self:ReadFile( "glambda/custommaterials.json", "json" )
    
    local mergeTbl = table.Add( defaultMats, customMats )
    for _, mat in ipairs( list.Get( "OverrideMaterials" ) ) do
        if !table.HasValue( mergeTbl, mat ) then mergeTbl[ #mergeTbl + 1 ] = mat end
    end
    return mergeTbl
end