GLAMBDA = ( GLAMBDA or {} )

local function IncludeDirectory( directory )
    local files = file.Find( directory .. "*", "LUA", "nameasc" )

    for _, lua in ipairs( files ) do
        if string.StartWith( lua, "sv_" ) then
            include( directory .. lua )
        elseif string.StartWith( lua, "cl_" ) then
            if ( SERVER ) then
                AddCSLuaFile( directory .. lua )
            else
                include( directory .. lua )
            end
        elseif string.StartWith( lua, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( directory .. lua ) end
            include( directory .. lua )
        end
    end
end

-- Our main file includes
IncludeDirectory( "glambda/includes/" )
print( "GLambda Players: All base Lua include files have been loaded" )

-- The one and only, the GLambda Player --
if ( SERVER ) then AddCSLuaFile( "glambda/glambda_player.lua" ) end
include( "glambda/glambda_player.lua" )