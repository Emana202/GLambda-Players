local AddCSLuaFile = AddCSLuaFile
local pairs = pairs
local undo_Create = SERVER and undo.Create
local undo_SetPlayer = SERVER and undo.SetPlayer
local undo_SetCustomUndoText = SERVER and undo.SetCustomUndoText
local undo_AddEntity = SERVER and undo.AddEntity
local undo_Finish = SERVER and undo.Finish
local IsValid = IsValid
local CurTime = CurTime
local net_Start = net.Start
local net_WritePlayer = net.WritePlayer
local net_Broadcast = SERVER and net.Broadcast
local timer_Simple = timer.Simple

--

AddCSLuaFile()

ENT.Base = "base_point"

function ENT:Initialize()
    local ply = GLAMBDA:CreateLambdaPlayer()
    if !ply then self:Remove() return end

    local collBounds = ply:GetCollisionBounds()
    local spawnPos = ply:TraceHull( self:GetPos(), ( self:GetPos() - vector_up * 36 ), collBounds.mins, collBounds.maxs, COLLISION_GROUP_PLAYER, MASK_PLAYERSOLID ).HitPos
    ply:SetPos( spawnPos )

    local spawnAng = self:GetAngles()
    ply:SetAngles( spawnAng )
    ply:SetEyeAngles( spawnAng )

    ply.Spawner = self    
    self:SetPos( spawnPos )
    self:SetOwner( ply:GetPlayer() )
    self.gb_PlyInitialized = false
end

function ENT:InitializePlayer( creator )
    self.gb_PlyInitialized = true
    local ply = self:GetOwner()
    local GLACE = ply:GetGlaceObject()

    local presetCvar = creator:GetInfo( "glambda_player_personalitypreset" )
    if presetCvar == "custom" then
        local personaTbl = {}
        for persName, persData in pairs( GLAMBDA.Personalities ) do
            local infoNum = creator:GetInfoNum( persData[ 2 ], 30 )
            personaTbl[ persName ] = infoNum
        end
        GLACE:BuildPersonalityTable( personaTbl )
    elseif presetCvar == "customrng" then
        local personaTbl = {}
        for persName, persData in pairs( GLAMBDA.Personalities ) do
            local infoNum = creator:GetInfoNum( persData[ 2 ], 30 )
            personaTbl[ persName ] = GLAMBDA:Random( infoNum )
        end
        GLACE:BuildPersonalityTable( personaTbl )
    else
        GLACE:BuildPersonalityTable( GLAMBDA.PersonalityPresets[ presetCvar ] )
    end

    local spawnVP = creator:GetInfo( "glambda_player_spawn_vp" )
    if GLAMBDA.VoiceProfiles[ spawnVP ] then
        GLACE.VoiceProfile = spawnVP
    end

    local spawnWep = GLACE.ForceWeapon
    if !GLAMBDA:GetConVar( "combat_keepforcewep" ) then
        spawnWep = GLAMBDA:GetConVar( "combat_forcespawnwpn" )
    end
    if !spawnWep or #spawnWep == 0 then
        spawnWep = creator:GetInfo( "glambda_player_spawnweapon" )
        if spawnWep and #spawnWep != 0 then
            if spawnWep == "random" then
                GLACE:SelectRandomWeapon()
            else
                GLACE:SelectWeapon( spawnWep )
            end
            GLACE.SpawnWeapon = spawnWep
        end
    end

    local undoName = "GLambda Player ( " .. ply:Nick() .. " )"
    undo_Create( undoName )
        undo_SetPlayer( creator )
        undo_SetCustomUndoText( "Undone " .. undoName )
        undo_AddEntity( self )
    undo_Finish( undoName )
end

function ENT:Think()
    if !self.gb_PlyInitialized then
        local creator = self:GetCreator()
        if IsValid( creator ) then self:InitializePlayer( creator ) end
    else
        self:NextThink( CurTime() )
        return true
    end
end

function ENT:OnRemove()
    local ply = self:GetOwner()
    if !IsValid( ply ) then return end
    
    net_Start( "glambda_playerremove" )
        net_WritePlayer( ply )
    net_Broadcast()

    local plyNick = self:GetCreator():Nick()
    timer_Simple( 0, function() if IsValid( ply ) then ply:Kick( "GLambda: Removed by " .. plyNick ) end end )
end