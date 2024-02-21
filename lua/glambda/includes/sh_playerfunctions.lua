local debugoverlay = debugoverlay
local math = math
local pairs = pairs
local RandomPairs = RandomPairs
local ipairs = ipairs
local Trace = util.TraceLine
local TraceHull = util.TraceHull

-- Creates a GLACE object for the specified player
local function CreateGlaceTable( ply )
    local GLACE = { _PLY = ply }

    -- We copy these meta tables so we can run them on the GLACE table and it will be detoured to the player itself
    local ENT = table.Copy( FindMetaTable( "Entity" ) )
    local PLAYER = table.Copy( FindMetaTable( "Player" ) )

    for name, func in pairs( table.Merge( ENT, PLAYER, true ) ) do
        GLACE[ name ] = function( tblself, ... )
            local ply = GLACE._PLY
            if !ply:IsValid() then 
                ErrorNoHaltWithStack( "Attempt to call " .. name .. " function on a Glace Player that no longer exists!" ) 
                return 
            end

            return func( ply, ... )
        end
    end

    -- Sometimes you may want to use this for non meta method functions
    function GLACE:GetPlayer() return self._PLY end -- Returns this Glace object's Player
    function GLACE:IsValid() return IsValid( self._PLY ) end -- Returns if this Glace object's Player is valid
    function GLACE:IsStuck() return self._ISSTUCK end -- Returns if the Player is stuck
    function GLACE:GetNavigator() return self._NAVIGATOR end -- Returns this Glace object's Navigating nextbot
    function GLACE:GetThread() return self._THREAD end -- Gets the current running thread
    function GLACE:SetThread( thread ) self._THREAD = thread end -- Sets the current running thread. You should never have to use this
    function GLACE:SetNavigator( nextbot ) self._NAVIGATOR = nextbot end -- Sets this Glace object's Navigating nextbot. You should never have to use this

    ply._GLACETABLE = GLACE
    return GLACE
end

-- Applies the Glace Base Methods 

-- Every single function/hook is documented so dig in
function GLAMBDA:ApplyPlayerFunctions( ply )
    local GLACE = CreateGlaceTable( ply )

    if ( SERVER ) then

        ---- HOOKS ----

        -- Called every think
        function GLACE:Think() end 

        -- Called every think however this think is within a Coroutine thread meaning you can pause executions and ect
        function GLACE:ThreadedThink() end 

        -- Called when this player is killed
        function GLACE:OnKilled( attacker, inflictor ) end

        -- Called when this player is hurt
        function GLACE:OnHurt( attacker, healthremaining, damage ) end

        -- Called when a NPC, Nextbot, or player is killed
        function GLACE:OnOtherKilled( victim, CTakeDamageInfo ) end

        -- Called when the Player thinks it is stuck
        function GLACE:OnStuck() end

        -- Called when the Player isn't stuck anymore
        function GLACE:OnUnStuck() end

        -- Called when the Player respawns
        function GLACE:OnRespawn() end

        -- Called when the Player gets disconnected/removed from the server
        function GLACE:OnDisconnect() end

        ---- ----
        
        ---- Player Functions ----

        -- Clears the stuck status of the Player
        function GLACE:ClearStuck()
            self.StuckPosition = GLACE:GetPos()
            self.StuckTimer = CurTime() + 3
            self:DevMsg( "Stuck status removed" )

            if self:IsStuck() then
                self._ISSTUCK = false
                self:OnUnStuck()
            end
        end

        -- Sends a debug message to console. Only works if glambda_debug is set to 1
        function GLACE:DevMsg( ... )
            if !GLAMBDA:GetConVar( "glambda_debug" ) then return end
            print( "GLAMBDA DEBUG: " .. tostring( self:GetPlayer() ) .. " ", ... )
        end

        local moveInputs = {
            [ IN_FORWARD ] = 1,
            [ IN_BACK ] = 2,
            [ IN_MOVERIGHT ] = 3,
            [ IN_MOVELEFT ] = 4
        }
        GLACE.CmdButtonQueue = 0 -- The key presses we've done this tick
        GLACE.KeyPressCooldown = {} -- Table for keeping cooldowns for each inkey

        -- Simulates a key press on this player. 
        -- This function will go on cooldown for each inkey for a very small delay so that it isn't running every tick and making it seem like it is being "held"
        -- It's a key press for a reason lol
        -- This shouldn't be used with movement keys like IN_FORWARD
        
        function GLACE:PressKey( inkey )
            local cooldown = self.KeyPressCooldown[ inkey ]
            if cooldown and ( CurTime() - cooldown ) < engine.TickInterval() then return end

            local buttonQueue = self.CmdButtonQueue
            if bit.band( buttonQueue, inkey ) == inkey then return end -- Prevent the same key from being queued
            self.CmdButtonQueue = ( buttonQueue + inkey )

            local isMoveKey = moveInputs[ inkey ]
            if isMoveKey != nil then
                local moveSpeed = ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() )
                self.MoveInputForward = ( isMoveKey == 1 and moveSpeed or ( isMoveKey == 2 and -moveSpeed ) )
                self.MoveInputSideway = ( isMoveKey == 3 and moveSpeed or ( isMoveKey == 4 and -moveSpeed ) )
            end
            self.KeyPressCooldown[ inkey ] = CurTime()
        end

        -- Pretty much the same above except there is no delay which means this can be run every tick and simulate a held key
        -- This is perfect for using movement keys like IN_FORWARD
        function GLACE:HoldKey( inkey )
            local buttonQueue = self.CmdButtonQueue
            if bit.band( buttonQueue, inkey ) == inkey then return end -- Prevent the same key from being queued
            self.CmdButtonQueue = ( buttonQueue + inkey )

            local isMoveKey = moveInputs[ inkey ]
            if isMoveKey != nil then
                local moveSpeed = ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() )
                self.MoveInputForward = ( isMoveKey == 1 and moveSpeed or ( isMoveKey == 2 and -moveSpeed ) )
                self.MoveInputSideway = ( isMoveKey == 3 and moveSpeed or ( isMoveKey == 4 and -moveSpeed ) )
            end
        end

        -- Removes a key from the button queue
        function GLACE:RemoveKey( inkey )
            local buttonQueue = self.CmdButtonQueue
            if bit.band( buttonQueue, inkey ) == inkey then return end
            self.CmdButtonQueue = ( buttonQueue - inkey )
        end

        -- Makes the player Sprint
        function GLACE:SetSprint( bool )
            self.MoveSprint = bool
        end

        -- Makes the player Crouch
        function GLACE:SetCrouch( bool )
            self.MoveCrouch = bool
        end

        -- If the Player is sprinting
        function GLACE:IsSprinting()
            return ( self.MoveSprint or self:GetPlayer():IsSprinting() )
        end

        -- Makes the player approach the position. Similar to CLuaLocomotion:Approach()
        function GLACE:Approach( goal )
            self.MoveApproachPos = goal
            self.MoveApproachEndT = ( CurTime() + 0.2 )
        end

        -- Makes the player look towards a position or entity. 
        -- Similar to :LookTo() except this works like :Approach()
        -- This has priority over GLACE:LookTo()
        function GLACE:LookTowards( pos, smooth )
            self.LookTowards_Pos = pos
            self.LookTowards_Smooth = ( smooth or 1 )
            self.LookTowards_EndT = ( CurTime() + 0.2 )
        end

        -- Makes the player look at a position or entity
        -- Smooth is fraction in a LerpAngle(). Set this to 1 for the Player to instantly snap their view onto a position or entity. Set this as a decimal like 0.1 to have a more smooth look
        -- endtime is the time in seconds before the Player stops looking at the pos/entity
        -- Set pos to nil to stop
        function GLACE:LookTo( pos, smooth, endtime, priority )
            if priority and self.LookTo_Pos and self.LookTo_Priority > priority then return end
            self.LookTo_Pos = pos
            self.LookTo_Smooth = ( smooth or 1 )
            self.LookTo_EndT = ( endtime and CurTime() + endtime or nil )
            self.LookTo_Priority = priority
        end

        -- Gets the current segment index we are on
        function GLACE:GetCurrentSegment()
            return self:GetNavigator():GetCurrentSegment()
        end

        -- Gets the current path we have generated
        function GLACE:GetPath()
            return self:GetNavigator()._PATH
        end

        -- Returns if the navigator has yet to finish generating a path
        -- Use this to yield the thread while this is true so it waits until the path is made
        function GLACE:IsGeneratingPath()
            return self.IsPathGenerating
        end

        -- Sets how far we have to be to a segment on a generated path before it is considered reached
        function GLACE:SetGoalTolerance( distance )
            self.GoalPathTolerance = ( distance or 20 )
        end

        -- Gets our goal tolerance
        function GLACE:GetGoalTolerance()
            return ( self.GoalPathTolerance or 20 )
        end

        -- Make the Navigator generate a path for us to a position or to a entity.
        function GLACE:ComputePathTo( pos )
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
        function GLACE:RecomputePath()
            self:GetNavigator().gb_forcerecompute = true
        end

        -- Update the player along the generated path from GLACE:ComputePathTo( pos, updatetime )
        function GLACE:UpdateOnPath()
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

        -- The function path finding will use to well path find
        function GLACE:PathfindingGenerator()
            local navi = self:GetNavigator()
            local jumpPenalty = 5

            return function( area, fromArea, ladder, elevator, length )
                if !IsValid( fromArea ) then
                    -- First area in path, no cost
                    return 0
                else
                    if !navi.loco:IsAreaTraversable( area ) then
                        -- Our locomotor says we can't move here
                        return -1
                    end
            
                    -- Compute distance traveled along path so far
                    local dist = 0
                    if IsValid( ladder ) then
                        dist = ladder:GetBottom():Distance( ladder:GetTop() )
                    elseif length > 0 then
                        -- Optimization to avoid recomputing length
                        dist = length
                    else
                        dist = ( area:GetCenter() - fromArea:GetCenter() ):GetLength()
                    end
                    local cost = ( dist + fromArea:GetCostSoFar() )            

                    -- Check height change
                    local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange( area )
                    if deltaZ > self:GetStepSize() then
                        if deltaZ > self:GetJumpPower() then
                            -- Too high to reach
                            return -1
                        end
            
                        -- Jumping is slower than flat ground
                        cost = ( cost + jumpPenalty * dist )
                    elseif deltaZ < -600 then
                        -- Too far to drop
                        return -1
                    end

                    return cost
                end
            end
        end
        
        -- Returns a squared distance to the position
        -- Much faster than the normal way
        function GLACE:SqrRangeTo( pos, startPos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
            pos = isentity( pos ) and pos:GetPos() or pos

            startPos = ( startPos or self:GetPos() )
            return startPos:DistToSqr( pos )
        end

        -- Returns a squared distance to the position on a 2D plane. This means the Z axis is removed out of the picture
        function GLACE:SqrRangeToXY( pos, startPos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end

            pos = isentity( pos ) and pos:GetPos() or pos
            pos[ 3 ] = 0
            
            startPos = ( startPos or self:GetPos() )
            startPos[ 3 ] = 0

            return startPos:DistToSqr( pos )
        end

        -- Returns a distance based on source units
        -- For simple in range checks, use GLACE:SqrRangeTo( pos ). For example, GLACE:SqrRangeTo( Vector() ) < ( 500 * 500 ) is much faster to calculate
        function GLACE:RangeTo( pos, startPos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
            pos = isentity( pos ) and pos:GetPos() or pos

            startPos = ( startPos or self:GetPos() )
            return startPos:Distance( pos )
        end

        -- Returns if the given position in is range
        function GLACE:InRange( pos, range, startPos )
            return ( self:SqrRangeTo( pos, startPos ) <= ( range * range ) )
        end

        -- Returns a normalized vector from the player's position to the other pos or entity
        function GLACE:NormalTo( pos )
            pos = ( isentity( pos ) and pos:GetPos() or pos )
            return ( pos - self:GetPos() ):GetNormalized()
        end

        -- Creates a simple timer
        function GLACE:SimpleTimer( delay, func )
            timer.Simple( delay, function() 
                if !IsValid( self ) then return end
                func()
            end )
        end

        -- Creates a named timer
        function GLACE:Timer( name, delay, reps, func )
            local timername = "glacebase_timer_" .. self:GetPlayer():EntIndex() .. name
            timer.Create( timername, delay, reps, function()
                if !IsValid( self ) then timer.Remove( timername ) return end
                func()
            end )
        end

        -- Removes a named timer
        function GLACE:RemoveTimer( name )
            timer.Remove( "glacebase_timer_" .. self:GetPlayer():EntIndex() .. name )
        end

        -- Simple trace
        local normaltrace = {}
        function GLACE:Trace( start, endpos, col, mask, filter )
            normaltrace.start = start or self:EyePos()
            normaltrace.endpos = ( isentity( endpos ) and endpos:WorldSpaceCenter() or endpos )
            normaltrace.filter = filter or self:GetPlayer()
            normaltrace.mask = mask or MASK_SOLID
            normaltrace.collisiongroup = col or COLLISION_GROUP_NONE
            
            return Trace( normaltrace )
        end

        -- Hull trace
        local hulltrace = {}
        function GLACE:TraceHull( start, endpos, mins, maxs, col, mask, filter )
            hulltrace.start = start or self:EyePos()
            hulltrace.endpos = ( isentity( endpos ) and endpos:WorldSpaceCenter() or endpos )
            hulltrace.mins = mins
            hulltrace.maxs = maxs
            hulltrace.filter = filter or self:GetPlayer()
            hulltrace.mask = mask or MASK_SOLID
            hulltrace.collisiongroup = col or COLLISION_GROUP_NONE
            
            return TraceHull( hulltrace )
        end

        -- Simple Find in sphere function with a filter function
        -- Return true in the filter function to let a entity be included in the returned table
        function GLACE:FindInSphere( pos, dist, filter )
            local entities = {}
            local ply = self:GetPlayer()
            for _, ent in ipairs( ents.FindInSphere( ( pos or self:GetPos() ), dist ) ) do
                if ent == ply or !IsValid( ent ) or ent.gb_IsGlaceNavigator or filter and !filter( ent ) then continue end
                entities[ #entities + 1 ] = ent
            end
            return entities
        end

        -- Returns the closest entity in a table
        function GLACE:GetClosest( tbl )
            local closest, dist 
            for i = 1, #tbl do
                local v = tbl[ i ] 
                if !IsValid( v ) then continue end

                local testdist = self:SqrRangeTo( v )
                if closest and testdist > dist then continue end

                closest = v 
                dist = testdist
            end
            
            return closest
        end

        -- A function for creating get and set functions easily.
        -- func( old, new ) arg is optional. It will be called when the value changes
        -- Returning true in the function will prevent the value change from happening
        function GLACE:CreateGetSetFuncs( name, func )
            self[ "Get" .. name ] = function( self )
                return self[ "gb_getsetvar" .. name ]
            end
            self[ "Set" .. name ] = function( self, val )
               if func and func( self[ "Get" .. name ]( self ), val ) == true then return end
               self[ "gb_getsetvar" .. name ] = val
            end
        end

        -- Gets a random position within the distance.
        function GLACE:GetRandomPos( dist, pos )
            pos = ( pos or self:GetPos() )
            local navareas = navmesh.Find( pos, ( dist or 1500 ), 100, self:GetStepSize() )

            local area = navareas[ GLAMBDA:Random( #navareas ) ] 
            return ( IsValid( area ) and area:GetRandomPoint() or pos )
        end

        -- Gets a random position. This caches the nav area result for faster runs
        function GLACE:GetRandomPosCache()
            if !GLAMBDA.NavAreaCache then
                local navareas = navmesh.GetAllNavAreas()
                GLAMBDA.NavAreaCache = {}
    
                for k, nav in ipairs( navareas ) do
                    if IsValid( nav ) and nav:GetSizeX() > 60 and nav:GetSizeY() > 60 then
                        GLAMBDA.NavAreaCache[ #GLAMBDA.NavAreaCache + 1 ] = nav
                    end
                end
            end

            
            local area = GLAMBDA.NavAreaCache[ GLAMBDA:Random( #GLAMBDA.NavAreaCache ) ] 
            local pos = IsValid( area ) and area:GetRandomPoint() or self:GetPos()
            return pos
        end

        local QuickTrace = util.QuickTrace

        GLACE.DoorOpenCooldown = 0
        -- Performs a check that will make this Player open doors
        function GLACE:DoorCheck()
            local ent = QuickTrace( self:EyePos(), self:GetAimVector() * 50, self:GetPlayer() ).Entity
            if !IsValid( ent ) then return end
            
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
        function GLACE:AvoidCheck()
            local selfPos = self:GetPos()
            local selfRight = self:GetRight()
            local selfForward = self:GetForward()
        
            tracetable.start = ( selfPos + vector_up * self:GetStepSize() + selfForward * 30 + selfRight * 12.5 )
            tracetable.endpos = tracetable.start
            tracetable.filter = self:GetPlayer()
        
            local rightresult = TraceHull( tracetable )
            debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, ( rightresult.Hit and hitcol or safecol ), false )
        
            tracetable.start = ( tracetable.start - selfRight * 25 )
            tracetable.endpos = tracetable.start
        
            local leftresult = TraceHull( tracetable )
            debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, ( leftresult.Hit and hitcol or safecol ), false )
        
            if leftresult.Hit and rightresult.Hit then -- Back up
                self:Approach( self:GetPos() - selfForward * 50, 0.25 )
            end
            if leftresult.Hit and !rightresult.Hit then -- Move to the right
                self:Approach( self:GetPos() + selfRight * 50 )
            elseif rightresult.Hit and !leftresult.Hit then  -- Move to the left
                self:Approach( self:GetPos() - selfRight * 50 )
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
            local headhit = Trace( tracetable ).Hit

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

        ---- ----

    end

    return GLACE
end