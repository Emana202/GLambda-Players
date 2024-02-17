local debugoverlay = debugoverlay
local math = math
local pairs = pairs
local RandomPairs = RandomPairs
local ipairs = ipairs
local Trace = util.TraceLine
local TraceHull = util.TraceHull

-- Creates a GLACE object for the specified player
local function CreateGlacetable( ply )
    local GLACE = { _PLY = ply }

    -- We copy these meta tables so we can run them on the GLACE table and it will be detoured to the player itself
    local ENT = FindMetaTable( "Entity" )
    for k, v in pairs( ENT ) do
        GLACE[ k ] = function( tblself, ... )
            if !IsValid( GLACE:GetPlayer() ) then ErrorNoHaltWithStack( "Attempt to call " .. k .. " on a Glace Player that no longer exists!" ) return end
            local result = v( GLACE:GetPlayer(), ... )
            return result
        end
    end

    local PLAYER = FindMetaTable( "Player" )
    for k, v in pairs( PLAYER ) do
        GLACE[ k ] = function( tblself, ... )
            if !IsValid( GLACE:GetPlayer() ) then ErrorNoHaltWithStack( "Attempt to call " .. k .. " on a Glace Player that no longer exists!" ) return end
            local result = v( GLACE:GetPlayer(), ... )
            return result
        end
    end

    -- Sometimes you may want to use this for non meta method functions
    function GLACE:GetPlayer() return self._PLY end -- Returns this Glace object's Player


    function GLACE:IsValid() return IsValid( self:GetPlayer() ) end -- Returns if this Glace object's Player is valid
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
    local GLACE = CreateGlacetable( ply )


    if SERVER then

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
            
            self.m_stuckpos = GLACE:GetPos()
            self.m_stucktimer = CurTime() + 3

            self:DevMsg( "Stuck status removed" )

            if self:IsStuck() then self._ISSTUCK = false self:OnUnStuck() end
        end

        -- Sends a debug message to console. Only works if glambda_debug is set to 1
        function GLACE:DevMsg( ... )
            if !GLAMBDA:GetConVar( "glambda_debug" ) then return end
            print( "GLACE DEBUG: " .. tostring( self:GetPlayer() ) .. " ", ... )
        end

        -- Simulates a key press on this player. 
        -- This function will go on cooldown for each inkey for a very small delay so that it isn't running every tick and making it seem like it is being "held"
        -- It's a key press for a reason lol
        -- This shouldn't be used with movement keys like IN_FORWARD
        GLACE.gb_buttonqueue = 0 -- The key presses we've done this tick
        GLACE.gb_keypresscooldowns = {} -- Table for keeping cooldowns for each inkey
        function GLACE:PressKey( inkey )
            if self.gb_keypresscooldowns[ inkey ] and CurTime() < self.gb_keypresscooldowns[ inkey ] then return end -- Cooldown
            if bit.band( self.gb_buttonqueue, inkey ) == inkey then return end -- Prevent the same key from being queued
            self.gb_buttonqueue = self.gb_buttonqueue + inkey

            GLACE.gb_movementinputforward = inkey == IN_FORWARD and ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() ) or inkey == IN_BACK and ( self:IsSprinting() and -self:GetRunSpeed() or -self:GetWalkSpeed() )
            GLACE.gb_movementinputside = inkey == IN_MOVERIGHT and ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() ) or inkey == IN_MOVELEFT and ( self:IsSprinting() and -self:GetRunSpeed() or -self:GetWalkSpeed() )
            self.gb_keypresscooldowns[ inkey ] = CurTime() + engine.TickInterval()
        end

        -- Pretty much the same above except there is no delay which means this can be run every tick and simulate a held key
        -- This is perfect for using movement keys like IN_FORWARD
        function GLACE:HoldKey( inkey )
            if bit.band( self.gb_buttonqueue, inkey ) == inkey then return end -- Prevent the same key from being queued
            self.gb_buttonqueue = self.gb_buttonqueue + inkey
            GLACE.gb_movementinputforward = inkey == IN_FORWARD and ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() ) or inkey == IN_BACK and ( self:IsSprinting() and -self:GetRunSpeed() or -self:GetWalkSpeed() )
            GLACE.gb_movementinputside = inkey == IN_MOVERIGHT and ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() ) or inkey == IN_MOVELEFT and ( self:IsSprinting() and -self:GetRunSpeed() or -self:GetWalkSpeed() )
        end

        -- Removes a key from the button queue
        function GLACE:RemoveKey( inkey )
            if bit.band( self.gb_buttonqueue, inkey ) == inkey then self.gb_buttonqueue = self.gb_buttonqueue - inkey end
        end

        -- Makes the player Sprint
        function GLACE:SetSprint( bool )
            self.gb_sprint = bool
        end

        -- If the Player is sprinting
        function GLACE:IsSprinting()
            return self.gb_sprint or self:GetPlayer():IsSprinting()
        end

        -- Makes the player approach the position. Similar to CLuaLocomotion:Approach()
        function GLACE:Approach( goal )
            self.gb_approachpos = goal
            self.gb_approachend = CurTime() + 0.5
        end

        -- Makes the player look towards a position or entity. 
        -- Similar to :LookTo() except this works like :Approach()
        -- This has priority over GLACE:LookTo()
        function GLACE:LookTowards( pos, smooth )
            self.gb_looktowardspos = pos
            self.gb_looktowardssmooth = smooth or 1
            self.gb_looktowardsend = CurTime() + 0.2
        end

        -- Makes the player look at a position or entity
        -- Smooth is fraction in a LerpAngle(). Set this to 1 for the Player to instantly snap their view onto a position or entity. Set this as a decimal like 0.1 to have a more smooth look
        -- endtime is the time in seconds before the Player stops looking at the pos/entity
        -- Set pos to nil to stop
        function GLACE:LookTo( pos, smooth, endtime )
            self.gb_lookpos = pos
            self.gb_lookendtime = endtime and CurTime() + endtime or nil
            self.gb_smoothlook = smooth or 1
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
            return self.gb_pathgenerating
        end

        -- Sets how far we have to be to a segment on a generated path before it is considered reached
        function GLACE:SetGoalTolerance( distance )
            self.gb_goaltolerance = distance or 20
        end

        -- Gets our goal tolerance
        function GLACE:GetGoalTolerance()
            return self.gb_goaltolerance or 20
        end

        -- Make the Navigator generate a path for us to a position or to a entity.
        function GLACE:ComputePathTo( pos )
            if !IsValid( self:GetPath() ) then
                self.gb_pathgenerating = true
                self.gb_pathgoal = pos
                self:GetNavigator().gb_GoalPosition = pos
            else
                self.gb_pathgoal = pos
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
            self.gb_PathStuckCheck = CurTime() + 0.25
            local segment = path:GetAllSegments()[ self:GetCurrentSegment() ]
            local tol = path:GetGoalTolerance()

            if !segment then return end

            local xypos = ( segment.pos * 1 )
            xypos[ 3 ] = 0

            local selfpos = self:GetPos()
            selfpos[ 3 ] = 0

            if selfpos:DistToSqr( xypos ) <= ( tol * tol ) then

                -- We reached the end. There's no where else to go so stop
                if self:GetCurrentSegment() == #path:GetAllSegments() then
                    path:Invalidate()
                    self.gb_followpathpos = nil
                    self.gb_followpathend = nil
                    return
                end

                -- Go to the next segment
                self:GetNavigator():IncrementSegment()
                segment = path:GetAllSegments()[ self:GetCurrentSegment() ]
            end

            local how = segment.type

            if how == 2 then self:PressKey( IN_JUMP ) end

            self.gb_followpathpos = segment.pos
            self.gb_followpathend = CurTime() + 0.5
        end

        -- The function path finding will use to well path find
        function GLACE:PathfindingGenerator()
            local navi = self:GetNavigator()
            return function( area, fromArea, ladder, elevator, length )

                if ( !IsValid( fromArea ) ) then
            
                    -- first area in path, no cost
                    return 0
                
                else
                
                    if ( !navi.loco:IsAreaTraversable( area ) ) then
                        -- our locomotor says we can't move here
                        return -1
                    end
            
                    -- compute distance traveled along path so far
                    local dist = 0
            
                    if ( IsValid( ladder ) ) then
                        dist = ladder:GetBottom():Distance( ladder:GetTop() )
                    elseif ( length > 0 ) then
                        -- optimization to avoid recomputing length
                        dist = length
                    else
                        dist = ( area:GetCenter() - fromArea:GetCenter() ):GetLength()
                    end
            
                    local cost = dist + fromArea:GetCostSoFar()
            
                    -- check height change
                    local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange( area )
                    if ( deltaZ >= self:GetStepSize() ) then
                        if ( deltaZ >= self:GetJumpPower() ) then
                            -- too high to reach
                            return -1
                        end
            
                        -- jumping is slower than flat ground
                        local jumpPenalty = 5
                        cost = cost + jumpPenalty * dist
                    elseif ( deltaZ < -600 ) then
                        -- too far to drop
                        return -1
                    end
            
                    return cost
                end
            end
        end

        -- Nextbot's Move to pos function translated to Glace base's methods!
        function GLACE:MoveToPos( pos, updatetime, maxage )
            options = options or {}

            self:ComputePathTo( pos )

            while self:IsGeneratingPath() do coroutine.yield() end
            local path = self:GetPath()
            if !IsValid( path ) then return "failed" end
        
            while ( path:IsValid() ) do
        
                self:UpdateOnPath()
        
                if maxage and path:GetAge() > options.maxage then
                    return "timeout"
                end

                if self:IsStuck() then
                    self:ClearStuck()
                    return "stuck"
                end

                if updatetime then 
                    local time = math.max( updatetime, updatetime * ( self._PATH:GetLength() / 400 ) )
        
                    if self._PATH:GetAge() > time then
                        self._PATH:Compute( self, self:TranslateGoal() ) 
                        self.gb_CurrentSeg = 1 
                    end
                end
        
                coroutine.yield()
        
            end
        
            return "ok"
        
        end
        

        -- Returns a squared distance to the position
        function GLACE:SqrRangeTo( pos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
            pos = isentity( pos ) and pos:GetPos() or pos
            return self:GetPos():DistToSqr( pos )
        end

        -- Returns a squared distance to the position on a 2d plane. This means the z axis is removed out of the picture
        function GLACE:SqrRangeToXY( pos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
            local selfpos = self:GetPos()
            pos = isentity( pos ) and pos:GetPos() or pos
            pos[ 3 ] = 0
            selfpos[ 3 ] = 0
            
            return selfpos:DistToSqr( pos )
        end

        -- Returns a distance based on source units
        -- For simple in range checks, use GLACE:SqrRangeTo( pos ). for example, GLACE:SqrRangeTo( Vector() ) < ( 500 * 500 ) it is much faster to calculate
        function GLACE:RangeTo( pos )
            if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
            pos = isentity( pos ) and pos:GetPos() or pos
            return self:GetPos():Distance( pos )
        end

        -- Returns a normalized vector from the player's position to the other pos or entity
        function GLACE:NormalTo( pos )
            pos = isentity( pos ) and pos:GetPos() or pos
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
            local timername = "glacebase_timer_" .. self:GetPlayer():EntIndex() .. "" ..  name
            timer.Create( timername, delay, reps, function()
                if !IsValid( self ) then timer.Remove( timername ) return end
                func()
            end )
        end

        -- Removes a named timer
        function GLACE:RemoveTimer( name )
            timer.Remove( "glacebase_timer_" .. self:GetPlayer():EntIndex() .. "" ..  name )
        end

        local vistrace = {} -- Recycled table

        -- Returns whether the Player can see the ent in question.
        function GLACE:CanSee( ent, sightdistance )
            sightdistance = sightdistance or 8000
            if self:SqrRangeTo( ent ) > ( sightdistance * sightdistance ) then return false end -- Distance check

            -- "FOV" check
            -- Doing a actual cone check is quite expensive. This is very similar to a cone check but not the same.
            -- It still does the job at a cheaper price.
            local norm = ( ent:GetPos() - self:GetPos() ):GetNormalized()
            local dot = norm:Dot( self:GetAimVector() )
        
            if dot < 0.4 then return false end
        
            -- Finally tracing out sight line
            vistrace.start = self:EyePos()
            vistrace.endpos = ent:WorldSpaceCenter()
            vistrace.filter = self:GetPlayer()
            local result = Trace( vistrace )

            --if ent:IsPlayer() and ent:InVehicle() and result.Entity == ent:GetVehicle() then return true end


            return ( result.Fraction == 1.0 or result.Entity == ent )
        end

        -- Returns if we can safely shoot this entity
        function GLACE:CanShootAt( ent ) 
            local result = self:Trace( nil, ent, COLLISION_GROUP_NONE, MASK_SHOT_PORTAL )
            return ( result.Fraction == 1.0 or result.Entity == ent )
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
            pos = pos or self:GetPos()
            local entities = {}
            for k, v in ipairs( ents.FindInSphere( pos, dist ) ) do
                if IsValid( v ) and !v.gb_IsGlaceNavigator and v != self:GetPlayer() and ( !filter or filter( v ) ) then
                    entities[ #entities + 1 ] = v
                end
            end
            return entities
        end

        -- Returns the closest entity in a table
        function GLACE:GetClosest( tbl )
            local closest
            local dist 
            for i = 1, #tbl do
                local v = tbl[ i ] 
                if !IsValid( v ) then continue end

                local testdist = self:SqrRangeTo( v )
        
                if !closest then closest = v dist = testdist continue end
                
                if testdist < dist then
                    closest = v 
                    dist = testdist
                end
            end
            return closest
        end

        -- A function for creating get and set functions easily.
        -- func( old, new ) arg is optional. It will be called when the value changes
        function GLACE:CreateGetSetFuncs( name, func )
            self[ "Get" .. name ] = function( self )
                return self[ "gb_getsetvar" .. name ]
            end
            self[ "Set" .. name ] = function( self, val )
               if func then func( self[ "Get" .. name ]( self ), val ) end
               self[ "gb_getsetvar" .. name ] = val
            end
        end

        -- Gets a random position within the distance.
        function GLACE:GetRandomPos( dist, pos )
            pos = pos or self:GetPos()
            dist = dist or 1500
            local navareas = navmesh.Find( pos, dist, 100, self:GetStepSize() )
            
            local area = navareas[ math.random( #navareas ) ] 
            return IsValid( area ) and area:GetRandomPoint() or pos
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

            
            local area = GLAMBDA.NavAreaCache[ math.random( #GLAMBDA.NavAreaCache ) ] 
            local pos = IsValid( area ) and area:GetRandomPoint() or self:GetPos()
            return pos
        end

        local cooldown = 0
        -- Performs a check that will make this Player open doors
        function GLACE:DoorCheck()
            local ent = util.QuickTrace( self:EyePos(), self:GetAimVector() * 50, self:GetPlayer() ).Entity
            
            if IsValid( ent ) then
                self:LookTowards( ent:WorldSpaceCenter() )

                if CurTime() > cooldown then
                    self:PressKey( IN_USE )
                    cooldown = CurTime() + 2
                end

            end
        end

        local tracetable = {} -- Recycled table
        local leftcol = Color( 255, 0, 0 )
        local rightcol = Color( 0, 255, 0 )

        -- Fires 2 hull traces that will make the player try to move out of the way of whatever is blocking the way
        function GLACE:AvoidCheck()

            local mins = Vector( -16, -16, -10 )
            local maxs = Vector( 16, 16, 10 )

            tracetable.start = self:GetPos() + Vector( 0, 0, self:GetStepSize() ) + self:GetRight() * 20
            tracetable.endpos = tracetable.start 
            tracetable.mins = mins
            tracetable.maxs = maxs
            tracetable.filter = self:GetPlayer()

            debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, rightcol )
            local rightresult = TraceHull( tracetable )

            tracetable.start = self:GetPos() + Vector( 0, 0, self:GetStepSize() ) - self:GetRight() * 20
            tracetable.endpos = tracetable.start 
            tracetable.mins = mins
            tracetable.maxs = maxs
            tracetable.filter = self:GetPlayer()

            debugoverlay.Box( tracetable.start, tracetable.mins, tracetable.maxs, 0.1, leftcol )
            local leftresult = TraceHull( tracetable )

            tracetable.start = self:EyePos() - self:GetForward() * 70
            tracetable.endpos = self:EyePos() + self:GetForward() * 50
            tracetable.filter = ply
            debugoverlay.Line( tracetable.start, tracetable.endpos, 0.1, color_white, true )
            local eyeresult = Trace( tracetable )

            local righthit = rightresult.Hit
            local lefthit = leftresult.Hit

            -- Something is blocking our lower body.. Jump
            if righthit and lefthit and !eyeresult.Hit then
                self:PressKey( IN_JUMP )
            elseif eyeresult.Hit and !lefthit and !righthit then -- Something is blocking our head.. Crouch
                self:HoldKey( IN_DUCK )
            end

            if righthit and !lefthit then  -- Move to the left
                self:SetVelocity( self:GetRight() * -50 )
            elseif lefthit and !righthit then -- Move to the right
                self:SetVelocity( self:GetRight() * 50 )
            end
        end


        -- Some weapon related functions

        -- Makes the Player select a certain weapon entity or weapon class they have
        function GLACE:SelectWeapon( weapon )
            self.gb_selectweapon = weapon
        end

        -- Makes the Player select a random weapon they have.
        -- filternoammo will make the player only select weapons with ammo if possible
        function GLACE:SelectRandomWeapon( filternoammo )
            local weps = self:GetWeapons()

            for k, wep in RandomPairs( weps ) do
                if IsValid( wep ) and wep != self:GetActiveWeapon() and ( !filternoammo or wep:HasAmmo() ) then
                    self:SelectWeapon( wep )
                end
            end
        end

        -- Makes the player automatically switch to a weapon with ammo if their current weapon is completely out of ammo
        function GLACE:SetAutoSwitchWeapon( bool )
            local id = tostring( self )
            if bool then
                hook.Add( "Tick", "glacebase-autoswitch" .. id, function()
                    if !IsValid( self ) then hook.Remove( "Tick", "glacebase-autoswitch" .. id ) return end
                    local wep = self:GetActiveWeapon()

                    if IsValid( wep ) and !wep:HasAmmo() then
                        self:SelectRandomWeapon( true )
                    end
                end )
            else
                hook.Remove( "Tick", "glacebase-autoswitch" .. id )
            end
        end

        -- Makes the player automatically reload when their weapon's clip is empty or when they haven't shot for 3 seconds
        function GLACE:SetAutoReload( bool )
            local id = tostring( self )
            if bool then
                hook.Add( "Tick", "glacebase-autoreload" .. id, function()
                    if !IsValid( self ) then hook.Remove( "Tick", "glacebase-autoreload" .. id ) return end
                    local wep = self:GetActiveWeapon()

                    if IsValid( wep ) and wep:Clip1() == 0 then
                        self:PressKey( IN_RELOAD )
                    elseif IsValid( wep ) and wep:Clip1() < wep:GetMaxClip1() and wep:GetNextPrimaryFire() + 3 < CurTime() then -- Sometimes you might need a full clip
                        self:PressKey( IN_RELOAD )
                    end
                end )
            else
                hook.Remove( "Tick", "glacebase-autoreload" .. id )
            end
        end

        -- Returns if the current weapon has ammo
        function GLACE:CurWeaponHasAmmo()
            return self:GetActiveWeapon():HasAmmo()
        end

        ---- ----


    end

    return GLACE
end