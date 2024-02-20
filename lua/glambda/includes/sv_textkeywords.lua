GLAMBDA.KEYWORD = {
    Normal = {},
    Conditional = {}
}
local KEYWORD = GLAMBDA.KEYWORD

--

function KEYWORD:AddKeyWord( type, keyWord, func )
    self[ type ][ keyWord ] = func
end

function KEYWORD:ModifyTextKeyWords( ply, text ) 
    if !text then return "" end

    for keyWord, func in pairs( self.Normal ) do
        if !string.match( text, keyWord ) then continue end

        text = string.gsub( text, keyWord, function( ... )  
            local count = table.Count( { ... } )
            local packed = {}
            for i = 1, count do  packed[ #packed + 1 ] = ( func( ply ) or keyWord ) end
            return unpack( packed )
        end )
    end

    return text
end

function KEYWORD:IsValidCondition( ply, text ) 
    if text then
        for keyWord, func in pairs( self.Conditional ) do
            if !string.match( text, keyWord ) then continue end
            text = string.Replace( text, keyWord, "" )
            return func( ply ), text
        end
    end

    return true, text
end

--
--

KEYWORD:AddKeyWord( "Normal", "/self/", function( ply ) return ply:Nick() end )
KEYWORD:AddKeyWord( "Normal", "/servername/", function( ply ) return GetHostName() end )
KEYWORD:AddKeyWord( "Normal", "/deaths/", function( ply ) return ply:Deaths() end )
KEYWORD:AddKeyWord( "Normal", "/ping/", function( ply ) return ply:Ping() end )
KEYWORD:AddKeyWord( "Normal", "/kills/", function( ply ) return ply:Frags() end )
KEYWORD:AddKeyWord( "Normal", "/map/", function() return game.GetMap() end )

--

KEYWORD:AddKeyWord( "Normal", "/rndply/", function( ply )
    for _, player in RandomPairs( player.GetAll() ) do
        if player != ply:GetPlayer() then return player:Nick() end
    end
end )

KEYWORD:AddKeyWord( "Normal", "/rndmap/", function()
    local maps = file.Find( "maps/gm_*", "GAME", "namedesc" )
    return string.StripExtension( maps[ LambdaRNG( #maps ) ] )
end )

KEYWORD:AddKeyWord( "Normal", "/keyent/", function( ply )
    local keyEnt = ply.TextKeyEnt
    if !IsValid( keyEnt ) then return "someone" end
    return ( keyEnt:IsPlayer() and keyEnt:Nick() or keyEnt:GetClass() )
end )

KEYWORD:AddKeyWord( "Normal", "/keyweapon/", function( ply )
    local keyEnt = ply.TextKeyEnt
    if !IsValid( keyEnt ) then return "weapon" end
    return ( keyEnt.GetPrintName and keyEnt:GetPrintName() or keyEnt:GetClass() ) 
end )

KEYWORD:AddKeyWord( "Normal", "/weapon/", function( ply ) 
    local curWep = ply:GetActiveWeapon()
    if !IsValid( curWep ) then return "weapon" end
    return ( curWep.GetPrintName and curWep:GetPrintName() or curWep:GetClass() ) 
end )

KEYWORD:AddKeyWord( "Normal", "/nearply/", function( ply )
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
    local split = string.Explode( "/", mdl )
    local basename = string.StripExtension( split[ #split ] )
    basename = string.Replace( basename, "_", " " )
    
    for _, number in ipairs( numbers ) do basename = string.Replace( basename, number, "" ) end
    for _, ending in ipairs( endings ) do 
        if string.EndsWith( basename, ending ) then 
            basename = string.Left( basename, #basename - 1 ) 
            break 
        end 
    end

    return basename
end

KEYWORD:AddKeyWord( "Normal", "/nearprop/", function( ply )
    local nearProps = ply:FindInSphere( nil, 1000, function( ent )
        return propClasses[ ent:GetClass() ]
    end )
    if #nearProps == 0 then return "someone" end

    local closeProp = ply:GetClosest( nearProps )
    return PropPrettyName( closeProp:GetModel() )
end )

--
--

KEYWORD:AddKeyWord( "Conditional", "|highping|", function( ply ) return ply:Ping() >= 150 end )
KEYWORD:AddKeyWord( "Conditional", "|lowhp|", function( ply ) return ( ply:Health() / ply:GetMaxHealth() ) < 0.4 end )
KEYWORD:AddKeyWord( "Conditional", "|quietserver|", function() return #player.GetAll() < 6 end )
KEYWORD:AddKeyWord( "Conditional", "|activeserver|", function() return #player.GetAll() > 15 end )
KEYWORD:AddKeyWord( "Conditional", "|amtime|", function() return os.date( "%p" ) == "am" end )
KEYWORD:AddKeyWord( "Conditional", "|pmtime|", function() return os.date( "%p" ) == "pm" end )

--

KEYWORD:AddKeyWord( "Conditional", "|crowded|", function( ply )
    local nearPlys = ply:FindInSphere( nil, 500, function( ent ) return ent:IsPlayer() end )
    return ( #nearPlys > 5 )
end )
KEYWORD:AddKeyWord( "Conditional", "|alone|", function( ply )
    local nearPlys = ply:FindInSphere( nil, 2000, function( ent ) return ent:IsPlayer() end )
    return ( #nearPlys == 0 )
end )

KEYWORD:AddKeyWord( "Conditional", "|keyentishost|", function( ply )
    local keyEnt = ply.TextKeyEnt
    return ( IsValid( keyEnt ) and keyEnt:IsPlayer() and keyEnt:IsListenServerHost() )
end )

--

local function IsCurrentDate( month, day )
    local yearMonth = os.date( "%B" )
    local weekDay = tonumber( os.date( "%d" ) )
    return ( yearMonth == month and weekDay == day )
end

KEYWORD:AddKeyWord( "Conditional", "|addonbirthday|", function() return IsCurrentDate( "February", 16 ) end )
KEYWORD:AddKeyWord( "Conditional", "|4thjuly|", function() return IsCurrentDate( "July", 4 ) end )
KEYWORD:AddKeyWord( "Conditional", "|easter|", function() return IsCurrentDate( "April", 9 ) end )
KEYWORD:AddKeyWord( "Conditional", "|thanksgiving|", function() return IsCurrentDate( "November", 24 ) end )
KEYWORD:AddKeyWord( "Conditional", "|christmas|", function() return IsCurrentDate( "December", 25 ) end )
KEYWORD:AddKeyWord( "Conditional", "|newyears|", function() return IsCurrentDate( "January", 1 ) end )

KEYWORD:AddKeyWord( "Conditional", "|birthday|", function()
    for _, birthDate in pairs( GLAMBDA.Birthdays ) do
        if !IsCurrentDate( birthdaydata.month, birthdaydata.day ) then continue end 
        return true
    end
    return false
end )