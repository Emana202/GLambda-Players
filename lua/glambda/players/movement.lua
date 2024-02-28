local coroutine_yield = coroutine.yield
local IsValid = IsValid
local CurTime = CurTime
local math_max = math.max
local util_QuickTrace = util.QuickTrace
local Vector = Vector
local Color = Color
local FrameTime = FrameTime
local util_TraceHull = util.TraceHull
local debugoverlay_Box = debugoverlay.Box

-- Start moving to the given position
-- Use only in the coroutine threads, like state functions!
function GLAMBDA.Player:MoveToPos( pos, options )
    options = options or {}
    self:SetGoalTolerance( options.tol or 30 )

    self:ComputePathTo( pos )
    while ( self:IsGeneratingPath() ) do coroutine_yield() end

    local path = self:GetPath()
    if !IsValid( path ) then return "failed" end

    self:SetIsMoving( true )

    local shouldSprint = options.sprint
    self:SetSprint( shouldSprint == nil and ( path:GetLength() > 1000 ) or shouldSprint )

    local pathResult = "ok"
    local cbResult = nil
    local timeout = options.maxage
    local updateTime = options.updatetime
    local callback = options.callback

    local cbTime = options.callbacktime
    local nextCallbackTime = ( cbTime and ( CurTime() + cbTime ) or 0 )

    while ( IsValid( path ) ) do
        if !self:Alive() then
            pathResult = "dead"
            break
        end
        if self:GetAbortMovement() then
            self:SetAbortMovement( false )
            pathResult = "abort"
            break
        end
        if timeout and path:GetAge() > timeout then
            pathResult = "timeout"
            break
        end

        if !self:IsDisabled() then
            if callback and CurTime() >= nextCallbackTime then
                cbResult = callback( self )
                if cbResult != nil then
                    pathResult = "callback"
                    break
                end
                if cbTime then nextCallbackTime = ( CurTime() + cbTime ) end
            end

            if self:IsStuck() then
                self:ClearStuck()
                pathResult = "stuck"
                break
            end

            if updateTime then
                local time = math_max( updateTime, updateTime * ( path:GetLength() / 400 ) )
                if path:GetAge() >= time then self:RecomputePath() end
            end

            self:AvoidCheck()
            self:DoorCheck()
            self:UpdateOnPath()
        end

        coroutine_yield()
    end

    self:SetIsMoving( false )
    return pathResult, cbResult
end

--

-- Returns the position we are currently moving at
function GLAMBDA.Player:GetMovePosition()
    if !self:GetIsMoving() then return end
    local navigator = self:GetNavigator()
    return ( IsValid( navigator ) and navigator:TranslateGoal() )
end

-- Cancels and stops our movement
function GLAMBDA.Player:CancelMovement()
    self:SetAbortMovement( self:GetIsMoving() )
end

-- Clears the stuck status of the Player
function GLAMBDA.Player:ClearStuck()
    self.StuckPosition = self:GetPos()
    self.StuckTimer = CurTime() + 3
    self:DevMsg( "Stuck status removed" )

    if self:IsStuck() then
        self._ISSTUCK = false
        self:OnUnStuck()
    end
end

-- Makes the player Sprint
function GLAMBDA.Player:SetSprint( bool )
    self.MoveSprint = bool
end

-- Makes the player Crouch
function GLAMBDA.Player:SetCrouch( bool )
    self.MoveCrouch = bool
end

-- If the Player is sprinting
function GLAMBDA.Player:IsSprinting()
    return ( self.MoveSprint or self:GetPlayer():IsSprinting() )
end

-- Makes the player approach the position. Similar to CLuaLocomotion:Approach()
function GLAMBDA.Player:Approach( goal )
    self.MoveApproachPos = goal
    self.MoveApproachEndT = ( CurTime() + 0.2 )
end

-- Gets the current segment index we are on
function GLAMBDA.Player:GetCurrentSegment()
    return self:GetNavigator():GetCurrentSegment()
end

-- Gets the current path we have generated
function GLAMBDA.Player:GetPath()
    return self:GetNavigator()._PATH
end

-- Returns if the navigator has yet to finish generating a path
-- Use this to yield the thread while this is true so it waits until the path is made
function GLAMBDA.Player:IsGeneratingPath()
    return self.IsPathGenerating
end

-- Sets how far we have to be to a segment on a generated path before it is considered reached
function GLAMBDA.Player:SetGoalTolerance( distance )
    self.GoalPathTolerance = ( distance or 20 )
end

-- Gets our goal tolerance
function GLAMBDA.Player:GetGoalTolerance()
    return ( self.GoalPathTolerance or 20 )
end

-- Make the Navigator generate a path for us to a position or to a entity.
function GLAMBDA.Player:ComputePathTo( pos )
    if !IsValid( self:GetPath() ) then
        self.IsPathGenerating = true
        self.GoalPath = pos
        self:GetNavigator().gb_GoalPosition = pos
    else
        self.GoalPath = pos
        self:GetNavigator().gb_GoalPosition = pos
        self:RecomputePath()
    end
end

-- Makes the Navigator recompute the path
function GLAMBDA.Player:RecomputePath()
    self:GetNavigator().gb_forcerecompute = true
end

-- Update the player along the generated path from ComputePathTo( pos, updatetime )
function GLAMBDA.Player:UpdateOnPath()
    local path = self:GetPath()
    if !IsValid( path ) then return end -- Do not move if there is no path
    self.GoalPathStuckChecl = ( CurTime() + 0.25 )

    local curSeg = self:GetCurrentSegment()
    local allSegs = path:GetAllSegments() 
    local segment = allSegs[ curSeg ]
    if !segment then return end

    local xypos = ( segment.pos * 1 )
    xypos.z = 0

    local selfpos = self:GetPos()
    selfpos.z = 0

    local tol = path:GetGoalTolerance()
    if selfpos:DistToSqr( xypos ) <= ( tol * tol ) then
        -- We reached the end. There's no where else to go so stop
        if curSeg == #allSegs then
            path:Invalidate()
            self.FollowPath_Pos = nil
            self.FollowPath_EndT = nil
            return
        end

        -- Go to the next segment
        self:GetNavigator():IncrementSegment()
        segment = allSegs[ self:GetCurrentSegment() ]
    end

    local how = segment.type
    if how == 2 then self:PressKey( IN_JUMP ) end
    
    self.FollowPath_Pos = segment.pos
    self.FollowPath_EndT = ( CurTime() + 0.5 )
end

local doorClasses = {
    ["prop_door_rotating"] = true,
    ["func_door"] = true,
    ["func_door_rotating"] = true
}
-- Performs a check that will make this Player open doors
function GLAMBDA.Player:DoorCheck()
    local ent = util_QuickTrace( self:EyePos(), self:GetAimVector() * 50, self:GetPlayer() ).Entity
    if !IsValid( ent ) or !doorClasses[ ent:GetClass() ] then return end
    
    self:LookTowards( ent:WorldSpaceCenter() )
    if CurTime() < self.DoorOpenCooldown then return end

    self:PressKey( IN_USE )
    self.DoorOpenCooldown = ( CurTime() + 2 )
end

local tracetable = { -- Recycled table
    mins = Vector( -10, -10, 0 ),
    maxs = Vector( 10, 10, 20 )
}
local hitcol = Color( 255, 0, 0, 10 )
local safecol = Color( 0, 255, 0, 10 )

-- Fires 2 hull traces that will make the player try to move out of the way of whatever is blocking the way
function GLAMBDA.Player:AvoidCheck()
    if !self:OnGround() then return end

    local selfPos = ( self:GetPos() - self:GetVelocity() * FrameTime() * 2 )
    local selfRight = self:GetRight()
    local selfForward = self:GetForward()

    tracetable.start = ( selfPos + vector_up * self:GetStepSize() + selfForward * 10 + selfRight * 12.5 )
    tracetable.endpos = tracetable.start
    tracetable.filter = self:GetPlayer()

    local rightresult = util_TraceHull( tracetable )
    debugoverlay_Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, ( rightresult.Hit and hitcol or safecol ), false )

    tracetable.start = ( tracetable.start - selfRight * 25 )
    tracetable.endpos = tracetable.start

    local leftresult = util_TraceHull( tracetable )
    debugoverlay_Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, ( leftresult.Hit and hitcol or safecol ), false )

    if leftresult.Hit and rightresult.Hit then
        self:PressKey( IN_JUMP )
        return
    end

    if leftresult.Hit and !rightresult.Hit then -- Move to the right
        self:Approach( selfPos + selfRight * 50 )
    elseif rightresult.Hit and !leftresult.Hit then  -- Move to the left
        self:Approach( selfPos - selfRight * 50 )
    end

    --[[
    tracetable.filter = self:GetPlayer()
    local startPos = ( self:GetPos() + vector_up * self:GetStepSize() )
    local rightDir = ( self:GetRight() * 20 )

    tracetable.start = ( startPos + rightDir )
    tracetable.endpos = tracetable.start 

    debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, rightcol )
    local righthit = TraceHull( tracetable ).Hit

    tracetable.start = ( startPos - rightDir )
    tracetable.endpos = tracetable.start 

    debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, leftcol )
    local lefthit = TraceHull( tracetable ).Hit

    local eyePos = self:EyePos()
    local fwdDir = self:GetForward()
    tracetable.start = ( eyePos - fwdDir * 70 )
    tracetable.endpos = ( eyePos + fwdDir * 50 )

    debugoverlay.Line( tracetable.start, tracetable.endpos, 0.1, color_white, true )
    local headhit = util.TraceLine( tracetable ).Hit

    -- Something is blocking our lower body... Jump!
    if righthit and lefthit and !headhit then
        self:PressKey( IN_JUMP )
    elseif headhit and !lefthit and !righthit then -- Something is blocking our head... Crouch!
        self:HoldKey( IN_DUCK )
    end

    if righthit and !lefthit then  -- Move to the left
        self:Approach( self:GetPos() + self:GetRight() * -50 )
    elseif lefthit and !righthit then -- Move to the right
        self:Approach( self:GetPos() + self:GetRight() * 50 )
    end
    ]]
end