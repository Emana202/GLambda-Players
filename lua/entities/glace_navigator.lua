AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.gb_IsGlaceNavigator = true

function ENT:Initialize()

    self:SetModel( "models/player/police.mdl" )
    self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
    self:SetNoDraw( true )

    self.gb_CurrentSeg = 1

end

function ENT:OnInjured() end
function ENT:OnKilled() end

function ENT:Think()
    if CLIENT then return end

    if !IsValid( self:GetOwner() ) then self:Remove() end

    self:NextThink( CurTime() )
    return true
end

function ENT:GetPath() return self._PATH end
function ENT:GetCurrentSegment() return self.gb_CurrentSeg end
function ENT:IncrementSegment() self.gb_CurrentSeg = math.Clamp( self.gb_CurrentSeg + 1, 1, #self._PATH:GetAllSegments() ) end

function ENT:TranslateGoal()
    local goalPos = self.gb_GoalPosition
    return ( isvector( goalPos ) and goalPos or ( ( isentity( goalPos ) and goalPos:IsValid() ) and goalPos:GetPos() ) )
end

function ENT:PathToPos()
    if !IsValid( self:GetOwner() ) then return end
    local GLACE = self:GetOwner():GetGlaceObject()
    
    local goalPos = self.gb_GoalPosition
    if !goalPos or ( isentity( goalPos ) and !IsValid( goalPos ) ) then
        GLACE.IsPathGenerating = false
        return 
    end

    self._PATH = Path( "Follow" )
    self._PATH:SetMinLookAheadDistance( 10 )
	self._PATH:SetGoalTolerance( GLACE.GoalPathTolerance or 20 )

    local costFunctor = GLACE:PathGenerator()
	self._PATH:Compute( self, self:TranslateGoal(), costFunctor )
    GLACE.IsPathGenerating = false

    if !self._PATH:IsValid() then return end
    self.gb_CurrentSeg = 1

    while self._PATH:IsValid() do
        if !GLACE:IsValid() then break end

        goalPos = self.gb_GoalPosition
        if !goalPos or ( isentity( goalPos ) and !IsValid( goalPos ) ) then break end

        if self.gb_forcerecompute then 
            self._PATH:Compute( self, self:TranslateGoal(), costFunctor )
            self.gb_CurrentSeg = 1
            self.gb_forcerecompute = false
        end

        if GLAMBDA:GetConVar( "debug_glace" ) then self._PATH:Draw() end
        self._PATH:MoveCursorToClosestPosition( GLACE:GetPos() )
        
        coroutine.yield()
    end
end

function ENT:RunBehaviour()

    while true do
        self:PathToPos()
        coroutine.yield()
    end

end