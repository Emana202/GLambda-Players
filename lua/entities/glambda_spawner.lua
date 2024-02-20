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

    local presetCvar = creator:GetInfo( "glambda_player_personalitypreset" )
    ply:GetGlaceObject():BuildPersonalityTable( GLAMBDA.PersonalityPresets[ presetCvar ] )
    PrintTable( ply:GetGlaceObject().Personality )

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