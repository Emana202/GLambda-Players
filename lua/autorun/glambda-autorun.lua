if game.SinglePlayer() then return end
GLAMBDA = ( GLAMBDA or {} )

--

local initialized = false
function GLAMBDA:LoadFiles( caller )
    if ( SERVER ) and IsValid( caller ) then
        if !caller:IsSuperAdmin() then return end -- Nuh uh.
        PrintMessage( HUD_PRINTTALK, "SERVER is reloading all GLambda-related files..." )
    end

    -- Our main include files
    local dirPath = "glambda/includes/"
    local files = file.Find( dirPath .. "*", "LUA", "nameasc" )

    for _, luaFile in ipairs( files ) do
        if string.StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "GLambda Players: Included Server-Side Lua file [ " .. luaFile .. " ]" )
        elseif string.StartWith( luaFile, "cl_" ) then
            if ( SERVER ) then
                AddCSLuaFile( dirPath .. luaFile )
            else
                include( dirPath .. luaFile )
                print( "GLambda Players: Included Client-Side Lua file [ " .. luaFile .. " ]" )
            end
        elseif string.StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "GLambda Players: Included Shared Lua file [ " .. luaFile .. " ]" )
        end
    end

    print( "GLambda Players: All base Lua include files have been loaded" )

    -- The one and only, the GLambda Player --
    if ( SERVER ) then AddCSLuaFile( "glambda/glambda_player.lua" ) end
    include( "glambda/glambda_player.lua" )

    if ( SERVER ) then 
        if IsValid( caller ) then
            PrintMessage( HUD_PRINTTALK, "SERVER has reloaded all GLambda-related files" )
        end
        
        if initialized then
            net.Start( "glambda_reloadfiles" )
            net.Broadcast()
        end
        initialized = true
    end
end
GLAMBDA:LoadFiles()

--

function GLAMBDA:UpdateData( reload )
    if ( SERVER ) then
        if !file.Exists( "glambda/npclist.json", "DATA" ) then
            self.FILE:WriteFile( "glambda/npclist.json", self.FILE:ReadFile( "materials/glambdaplayers/data/defaultnpcs.vmt", nil, "GAME" ) )
        end
    
        if !file.Exists( "glambda/entitylist.json", "DATA" ) then
            self.FILE:WriteFile( "glambda/entitylist.json", self.FILE:ReadFile( "materials/glambdaplayers/data/defaultentities.vmt", nil, "GAME" ) )
        end
    
        if !file.Exists( "glambda/proplist.json", "DATA" ) then
            self.FILE:WriteFile( "glambda/proplist.json", self.FILE:ReadFile( "materials/glambdaplayers/data/props.vmt", nil, "GAME" ) )
        end
    end

    self.Nicknames       = ( !reload and self.Nicknames or self.FILE:GetNicknames() )
    self.ProfilePictures = ( !reload and self.ProfilePictures or self.FILE:GetProfilePictures() )
    self.VoiceLines      = ( !reload and self.VoiceLines or self.FILE:GetVoiceLines() )
    self.VoiceProfiles   = ( !reload and self.VoiceProfiles or self.FILE:GetVoiceProfiles() )
    self.TextMessages    = ( !reload and self.TextMessages or self.FILE:GetTextMessages() )
    self.SpawnlistProps  = ( !reload and self.SpawnlistProps or self.FILE:GetSpawnmenuProps() )
    self.SpawnlistENTs   = ( !reload and self.SpawnlistENTs or self.FILE:GetSpawnmenuENTs() )
    self.SpawnlistNPCs   = ( !reload and self.SpawnlistNPCs or self.FILE:GetSpawnmenuNPCs() )
    self.ToolMaterials   = ( !reload and self.ToolMaterials or self.FILE:GetMaterials() )
    self.Sprays          = ( !reload and self.Sprays or self.FILE:GetSprays() )

    if ( SERVER ) then
        self:UpdatePlayerModels()

        if reload then
            net.Start( "glambda_updatedata" )
            net.Broadcast()
        end
    end
end
GLAMBDA:UpdateData()

--

list.Set( "NPC", "glambda_spawner", {
    Name = "GLambda Player",
    Class = "glambda_spawner",
    Category = "GLambda Players"
} )

concommand.Add( "glambda_debug_reloadfiles", GLAMBDA.LoadFiles )