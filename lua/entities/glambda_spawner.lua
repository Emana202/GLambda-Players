AddCSLuaFile()

ENT.Base = "base_point"

function ENT:Initialize()
    local ply = GLAMBDA:CreateLambdaPlayer()
    if !ply then self:Remove() return end

    local collBounds = ply:GetCollisionBounds()
    local spawnPos = ply:TraceHull( self:GetPos(), ( self:GetPos() - vector_up * 36 ), collBounds.mins, collBounds.maxs, COLLISION_GROUP_PLAYER, MASK_PLAYERSOLID ).HitPos
    
    ply:SetPos( spawnPos )
    ply:SetEyeAngles( self:GetAngles() )
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

    local undoName = "GLambda Player ( " .. ply:Nick() .. " )"
    undo.Create( undoName )
        undo.SetPlayer( creator )
        undo.SetCustomUndoText( "Undone " .. undoName )
        undo.AddEntity( self )
    undo.Finish( undoName )
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
    
    net.Start( "glambda_playerremove" )
        net.WritePlayer( ply )
    net.Broadcast()

    timer.Simple( 0, function() if IsValid( ply ) then ply:Kick() end end )
end