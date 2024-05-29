local pairs = pairs
local string_match = string.match
local string_gsub = string.gsub
local table_Count = table.Count
local unpack = unpack
local string_Replace = string.Replace
local GetHostName = GetHostName
local game_GetMap = game.GetMap
local RandomPairs = RandomPairs
local file_Find = file.Find
local string_StripExtension = string.StripExtension
local IsValid = IsValid
local string_Explode = string.Explode
local ipairs = ipairs
local string_EndsWith = string.EndsWith
local string_Left = string.Left
local player_GetAll = player.GetAll
local os_date = os.date
local tonumber = tonumber

--

GLAMBDA.KEYWORD = {
    Normal = {},
    Conditional = {}
}
local KEYWORD = GLAMBDA.KEYWORD

--

function KEYWORD:AddKeyWord( keyWord, func )
    self.Normal[ keyWord ] = func
end

function KEYWORD:AddConditionalKeyWord( keyWord, func )
    self.Conditional[ keyWord ] = func
end

--

function KEYWORD:ModifyTextKeyWords( ply, text, keyEnt ) 
    if !text then return "" end

    for keyWord, func in pairs( self.Normal ) do
        keyWord = "/" .. keyWord .. "/"
        if !string_match( text, keyWord ) then continue end

        text = string_gsub( text, keyWord, function( ... )  
            local count = table_Count( { ... } )
            local packed = {}
            for i = 1, count do packed[ #packed + 1 ] = ( func( ply, keyEnt ) or keyWord ) end
            return unpack( packed )
        end )
    end

    return text
end

function KEYWORD:IsValidCondition( ply, text, keyEnt ) 
    if text then
        for keyWord, func in pairs( self.Conditional ) do
            keyWord = "|" .. keyWord .. "|"
            if !string_match( text, keyWord ) then continue end
            
            text = string_Replace( text, keyWord, "" )
            return func( ply, keyEnt ), text
        end
    end

    return true, text
end

--
--

KEYWORD:AddKeyWord( "self", function( ply ) return ply:Nick() end )
KEYWORD:AddKeyWord( "servername", function( ply ) return GetHostName() end )
KEYWORD:AddKeyWord( "deaths", function( ply ) return ply:Deaths() end )
KEYWORD:AddKeyWord( "ping", function( ply ) return ply:Ping() end )
KEYWORD:AddKeyWord( "kills", function( ply ) return ply:Frags() end )
KEYWORD:AddKeyWord( "map", function() return game_GetMap() end )

--

KEYWORD:AddKeyWord( "rndply", function( ply )
    for _, player in RandomPairs( player.GetAll() ) do
        if player != ply:GetPlayer() then return player:Nick() end
    end
end )

KEYWORD:AddKeyWord( "rndmap", function()
    local maps = file_Find( "maps*.bsp", "GAME", "namedesc" )
    return string_StripExtension( GLAMBDA:Random( maps ) )
end )

KEYWORD:AddKeyWord( "keyent", function( ply, keyEnt )
    if !IsValid( keyEnt ) then return "someone" end
    return ( keyEnt:IsPlayer() and keyEnt:Nick() or keyEnt:GetClass() )
end )

KEYWORD:AddKeyWord( "keyweapon", function( ply, keyEnt )
    if !IsValid( keyEnt ) then return "weapon" end
    return ( keyEnt.GetPrintName and keyEnt:GetPrintName() or keyEnt:GetClass() ) 
end )

KEYWORD:AddKeyWord( "weapon", function( ply ) 
    local curWep = ply:GetActiveWeapon()
    if !IsValid( curWep ) then return "weapon" end
    return ( curWep.GetPrintName and curWep:GetPrintName() or curWep:GetClass() ) 
end )

KEYWORD:AddKeyWord( "nearply", function( ply )
    local nearPlys = ply:FindInSphere( nil, 10000, function( ent )
        return ent:IsPlayer()
    end )

    if #nearPlys == 0 then return "someone" end
    return ply:GetClosest( nearPlys ):Nick()
end )

--

local numbers = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }
local endings = { "a", "b", "c" }
local propClasses = {
    [ "prop_physics" ] = true,
    [ "prop_physics_multiplayer" ] = true,
    [ "prop_dynamic" ] = true
}

local function PropPrettyName( mdl )
    local split = string_Explode( "/", mdl )
    local basename = string_StripExtension( split[ #split ] )
    basename = string_Replace( basename, "_", " " )
    
    for _, number in ipairs( numbers ) do basename = string_Replace( basename, number, "" ) end
    for _, ending in ipairs( endings ) do 
        if string_EndsWith( basename, ending ) then 
            basename = string_Left( basename, #basename - 1 ) 
            break 
        end 
    end

    return basename
end

KEYWORD:AddKeyWord( "nearprop", function( ply )
    local nearProps = ply:FindInSphere( nil, 1000, function( ent )
        return propClasses[ ent:GetClass() ]
    end )
    if #nearProps == 0 then return "someone" end

    local closeProp = ply:GetClosest( nearProps )
    return PropPrettyName( closeProp:GetModel() )
end )

--
--

KEYWORD:AddConditionalKeyWord( "highping", function( ply ) return ply:Ping() >= 150 end )
KEYWORD:AddConditionalKeyWord( "lowhp", function( ply ) return ( ply:Health() / ply:GetMaxHealth() ) < 0.4 end )
KEYWORD:AddConditionalKeyWord( "quietserver", function() return #player_GetAll() < 6 end )
KEYWORD:AddConditionalKeyWord( "activeserver", function() return #player_GetAll() > 15 end )
KEYWORD:AddConditionalKeyWord( "amtime", function() return os_date( "%p" ) == "am" end )
KEYWORD:AddConditionalKeyWord( "pmtime", function() return os_date( "%p" ) == "pm" end )

--

KEYWORD:AddConditionalKeyWord( "crowded", function( ply )
    local nearPlys = ply:FindInSphere( nil, 500, function( ent ) return ent:IsPlayer() end )
    return ( #nearPlys > 5 )
end )
KEYWORD:AddConditionalKeyWord( "alone", function( ply )
    local nearPlys = ply:FindInSphere( nil, 2000, function( ent ) return ent:IsPlayer() end )
    return ( #nearPlys == 0 )
end )

KEYWORD:AddConditionalKeyWord( "keyentishost", function( ply, keyEnt )
    return ( IsValid( keyEnt ) and keyEnt:IsPlayer() and keyEnt:IsListenServerHost() )
end )

--

local function IsCurrentDate( month, day )
    local yearMonth = os_date( "%B" )
    local weekDay = tonumber( os_date( "%d" ) )
    return ( yearMonth == month and weekDay == day )
end

KEYWORD:AddConditionalKeyWord( "addonbirthday", function() return IsCurrentDate( "February", 16 ) end )
KEYWORD:AddConditionalKeyWord( "4thjuly", function() return IsCurrentDate( "July", 4 ) end )
KEYWORD:AddConditionalKeyWord( "easter", function() return IsCurrentDate( "April", 9 ) end )
KEYWORD:AddConditionalKeyWord( "thanksgiving", function() return IsCurrentDate( "November", 24 ) end )
KEYWORD:AddConditionalKeyWord( "christmas", function() return IsCurrentDate( "December", 25 ) end )
KEYWORD:AddConditionalKeyWord( "newyears", function() return IsCurrentDate( "January", 1 ) end )

KEYWORD:AddConditionalKeyWord( "birthday", function()
    for _, birthDate in pairs( GLAMBDA.Birthdays ) do
        if !IsCurrentDate( birthDate.month, birthDate.day ) then continue end 
        return true
    end
    return false
end )