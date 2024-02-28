local IsValid = IsValid
local ipairs = ipairs
local player_GetBots = player.GetBots
local pairs = pairs
local file_Find = file.Find
local file_Exists = file.Exists
local print = print

GLAMBDA:CreateConCommand( "debug_resetallai", function( ply )

    local plyValid = IsValid( ply )
    if plyValid and !ply:IsSuperAdmin() then
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    for _, ply in ipairs( player_GetBots() ) do
        if !ply:IsGLambdaPlayer() then continue end
        ply:GetGlaceObject():ResetAI()
    end

end, false, "Reset the AI of all spawned players. Useful is an error occurs that makes them stop entirely.\nYou must be a super admin in order to use this!", {
    name = "Reset All Players' AI", 
    category = "Debugging" 
} )

GLAMBDA:CreateConCommand( "debug_kickallbots", function()
    if IsValid( ply ) and !ply:IsSuperAdmin() then
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    for _, ply in ipairs( player_GetBots() ) do
        ply:Kick()
    end
end, false, "Kicks all player bots from the server, including the non-GLambda ones.\nUse this if an error occurs upon a player's spawn and they become un-removable by normal means.\nYou must be a super admin in order to use this!", {
    name = "Kick All Player Bots", 
    category = "Debugging" 
} )

--

local userData = {
    [ "lambdaplayers/playerbirthday.json" ] = "glambda/plybirthday.json",
    [ "lambdaplayers/presets/" ] = "glambda/presets/",
}
GLAMBDA:CreateConCommand( "cmd_transferlambda_clientdata", function( ply )

    for toCopy, newCopy in pairs( userData ) do
        if toCopy[ #toCopy ] == "/" then
            local files = file_Find( toCopy .. "*", "DATA", "nameasc" )
            if !files then continue end

            for _, fileName in ipairs( files ) do
                GLAMBDA.FILE:WriteFile( newCopy .. fileName, GLAMBDA.FILE:ReadFile( toCopy .. fileName, "json" ), "json" )
            end
        end

        if !file_Exists( toCopy, "DATA" ) then continue end
        GLAMBDA.FILE:WriteFile( newCopy, GLAMBDA.FILE:ReadFile( toCopy, "json" ), "json" )
    end

    GLAMBDA:SendNotification( ply, "Transfered Lambda Data", 3, nil, "buttons/button15.wav" )
    print( "GLambda Players: Transfered Lambda client data files via console command." )

end, true, "Transfers and copies the client data files from Lambda Players to GLambda Players, such as personality presets, birthday date, and etc.", { 
    name = "Transfer Lambda Client Data", 
    category = "Utilities" 
} )

local transferFiles = {
    [ "lambdaplayers/npclist.json" ]        = "glambda/npclist.json",
    [ "lambdaplayers/entitylist.json" ]     = "glambda/entitylist.json",
    [ "lambdaplayers/proplist.json" ]       = "glambda/proplist.json",
    [ "lambdaplayers/customnames.json" ]    = "glambda/customnames.json",
    [ "lambdaplayers/profiles.json" ]       = "glambda/profiles.json",
    [ "lambdaplayers/pmblockdata.json" ]    = "glambda/pmblocklist.json",
    [ "lambdaplayers/presets/" ]            = "glambda/presets/",
    [ "lambdaplayers/nameimport/" ]         = "glambda/nameimport/",
    [ "lambdaplayers/exportednames/" ]      = "glambda/exportednames/",
}
GLAMBDA:CreateConCommand( "cmd_transferlambda_serverdata", function( ply )

    local plyValid = IsValid( ply )
    if plyValid and !ply:IsSuperAdmin() then 
        GLAMBDA:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
        return 
    end

    for toCopy, newCopy in pairs( transferFiles ) do
        if toCopy[ #toCopy ] == "/" then
            local files = file_Find( toCopy .. "*", "DATA", "nameasc" )
            if !files then continue end

            for _, fileName in ipairs( files ) do
                GLAMBDA.FILE:WriteFile( newCopy .. fileName, GLAMBDA.FILE:ReadFile( toCopy .. fileName, "json" ), "json" )
            end
        end

        if !file_Exists( toCopy, "DATA" ) then continue end
        GLAMBDA.FILE:WriteFile( newCopy, GLAMBDA.FILE:ReadFile( toCopy, "json" ), "json" )
    end

    if plyValid then GLAMBDA:SendNotification( ply, "Transfered Lambda Data", 3, nil, "buttons/button15.wav" ) end
    print( "GLambda Players: Transfered Lambda server data files via console command. Ran by ", ( plyValid and ply:Name() .. " | " .. ply:SteamID() or "Console" ) )

end, false, "Transfers and copies the server data files from Lambda Players to GLambda Players, such as names, NPCs, props and etc.\nYou must be a super admin in order to use this! Make sure to update the affected data once done!", { 
    name = "Transfer Lambda Server Data", 
    category = "Utilities" 
} )