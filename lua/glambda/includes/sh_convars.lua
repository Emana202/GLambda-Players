GLAMBDA.ConVars = ( GLAMBDA.ConVars or {} )

function GLAMBDA:CreateConVar( name, value, desc, shouldSave, isClient, isUserinfo, min, max )
    if isClient and SERVER then return end

    local cvarTbl = self.ConVars[ name ]
    if !cvarTbl then
        local flags = FCVAR_REPLICATED
        if shouldSave == nil or shouldSave == true then flags = ( flags + FCVAR_ARCHIVE ) end
        if isUserinfo and isClient then flags = ( flags + FCVAR_USERINFO ) end

        local cvarType
        if isstring( value ) then
            cvarType = 1
        else
            if isbool( value ) then
                cvarType = 2 
                value = tonumber( value )
            else
                cvarType = 3
            end

            value = tostring( value )
            if cvarType == 3 and string.match( value, "." ) then
                cvarType = 4
            end
        end

        local cvar = CreateConVar( "glambda_" .. name, value, flags, desc, min, max )
        self.ConVars[ name ] = {
            cvar = cvar,
            type = cvarType
        }
        return cvar
    end

    return self.ConVars[ name ].cvar
end

function GLAMBDA:GetConVar( name, returnCvar )
    local cvarTbl = self.ConVars[ name ]
    if !cvarTbl then return end

    local convar = cvarTbl.cvar
    if returnCvar then return  end

    local type = cvarTbl.type
    if type == 2 then
        return convar:GetBool()
    elseif type == 3 then
        return convar:GetInt()
    elseif type == 4 then
        return convar:GetFloat()
    end
    return convar:GetString()
end

--

GLAMBDA:CreateConVar( "debug_glace", false, "Enables debug mode.", false )

GLAMBDA:CreateConVar( "player_personalitypreset", "random", "The personality preset the player should spawn with.", nil, true, true )

GLAMBDA:CreateConVar( "player_respawn", true, "If the players should be able to respawn when killed. Disabling will disconnect them instead." )
GLAMBDA:CreateConVar( "player_respawntime", 3.0, "The time the player will respawn after being killed.", nil, nil, nil, 0 )
GLAMBDA:CreateConVar( "player_spawnweapon", "random", "The weapon the player should (re)spawn with. Setting to 'random' will make them select random weapons." )
GLAMBDA:CreateConVar( "player_addonplymdls", false, "Allows the players to use the server's addon playermodels instead of only the default ones." )