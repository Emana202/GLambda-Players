local ignorePlys = GetConVar( "ai_ignoreplayers" )
local aiDisabled = GetConVar( "ai_disabled" )

--

function GLAMBDA.Player:GetState( checkState )
    local curState = self.State
    if checkState then return ( curState == checkState ) end
    return curState
end

function GLAMBDA.Player:IsVisible( ent )
    local result = self:Trace( nil, ent )
    return ( result.Fraction == 1.0 or result.Entity == ent )
end

function GLAMBDA.Player:IsSpeaking( voiceType )
    return ( ( !voiceType or self.LastPlayedVoiceType == voiceType ) and RealTime() <= self:GetSpeechEndTime() )
end

function GLAMBDA.Player:InCombat()
    return ( self:GetState( "Combat" ) and IsValid( self:GetEnemy() ) )
end

function GLAMBDA.Player:IsPanicking()
    return ( self:GetState( "Retreat" ) and CurTime() <= self.RetreatEndTime )
end

--

function GLAMBDA.Player:MoveToPos( pos, options )
    options = options or {}
    self:SetGoalTolerance( options.tol or 30 )

    self:ComputePathTo( pos )
    while ( self:IsGeneratingPath() ) do coroutine.yield() end

    local path = self:GetPath()
    if !IsValid( path ) then return "failed" end

    self:SetIsMoving( true )

    local shouldSprint = options.sprint
    self:SetSprint( shouldSprint == nil and ( path:GetLength() > 1000 ) or shouldSprint )

    local pathResult = "ok"
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
        if self.AbortMovement then
            self.AbortMovement = false
            pathResult = "abort"
            break
        end
        if timeout and path:GetAge() > timeout then
            pathResult = "timeout"
            break
        end

        if !aiDisabled:GetBool() then
            if callback and CurTime() >= nextCallbackTime then
                if callback( self ) == true then
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
                local time = math.max( updateTime, updateTime * ( path:GetLength() / 400 ) )
                if path:GetAge() >= time then self:RecomputePath() end
            end

            self:UpdateOnPath()
        end

        coroutine.yield()
    end

    self:SetIsMoving( false )
    return pathResult
end

function GLAMBDA.Player:CancelMovement()
    self.AbortMovement = self:GetIsMoving()
end

--

function GLAMBDA.Player:PlayVoiceLine( voiceType, delay )
    local voiceTbl = GLAMBDA.VoiceLines[ voiceType ]
    if !voiceTbl then return end
    self.LastPlayedVoiceType = voiceType

    if !isnumber( delay ) then
        delay = ( delay == nil and math.Rand( 0.1, 0.75 ) or 0 )
    end
    self:SetSpeechEndTime( RealTime() + 4 )

    net.Start( "glambda_playvoicesnd" )
        net.WritePlayer( self:GetPlayer() )
        net.WriteString( voiceTbl[ math.random( #voiceTbl ) ] )
        net.WriteVector( self:GetPos() )
        net.WriteFloat( delay )
    net.Broadcast()
end

function GLAMBDA.Player:SetState( state, data )
    state = ( state or "Idle" )
    if self:GetState( state ) then return end
    self.State = state
    self.StateVariable = data
end

function GLAMBDA.Player:UndoCommand( undoAll )
    local index = self:GetPlayer():UniqueID()
    local undoTbl = undo.GetTable()[ index ]
    if !undoTbl then return end

    if !undoAll then
        undo.Do_Undo( undoTbl[ #undoTbl ] )
        return
    end
    for _, tbl in ipairs( undoTbl ) do undo.Do_Undo( tbl ) end
end

--

function GLAMBDA.Player:InitializeHooks( ply, GLACE )
    -- Sometimes real players join mid game so we need to network this player to them
    hook.Add( "PlayerInitialSpawn", ply, function( plyself, player )
        net.Start( "glambda_playerinit" )
            net.WritePlayer( ply )
            net.WriteString( ply.gl_ProfilePicture )
        net.Send( player )
    end )

    -- Reset the player's playermodel | Call respawn hook
    hook.Add( "PlayerSpawn", ply, function( plyself, player )
        if player != ply then return end
        GLACE:OnRespawn()

        -- To make sure models are set
        GLACE:SimpleTimer( 0, function()
            if !ply.gb_playermodel then return end 
            ply:SetModel( ply.gb_playermodel )
        end )
    end )

    -- On Killed hook
    hook.Add( "PlayerDeath", ply, function( plyself, player, inflictor, attacker ) 
        if player != ply then return end
        GLACE:OnKilled( attacker, inflictor )
    end )

    -- Update our navigator on map cleanup
    hook.Add( "PostCleanupMap", ply, function()
        local navigator = GLACE:GetNavigator()
        if !IsValid( navigator ) then
            navigator = ents.Create( "glace_navigator" )
            navigator:SetOwner( ply )
            navigator:Spawn()
            GLACE:SetNavigator( navigator ) 
        end

        navigator:SetPos( GLACE:GetPos() )
        if GLACE.gb_pathgoal then GLACE:ComputePathTo( GLACE.gb_pathgoal )  end
    end )

    -- On hurt hook
    hook.Add( "PlayerHurt", ply, function( plyself, player, attacker, healthremaining, damage )
        if player != ply then return end
        GLACE:OnHurt( attacker, healthremaining, damage )
    end )

    -- On someone killed hook
    hook.Add( "PostEntityTakeDamage", ply, function( plyself, victim, info, tookdmg )
        if victim == ply or ( !victim:IsNPC() and !victim:IsNextBot() and !victim:IsPlayer() ) or victim:Health() > 0 or !tookdmg  then return end
        GLACE:OnOtherKilled( victim, info )
    end )

    -- On our disconnect
    hook.Add( "PlayerDisconnected", ply, function( plyself, player )
        if player != ply then return end
        GLACE:OnDisconnect()
    end )

    --

    local STUCK_RADIUS = 10000
    GLACE.m_stuckpos = GLACE:GetPos()
    GLACE.m_stucktimer = CurTime() + 3
    GLACE.m_stillstucktimer = CurTime() + 1

    -- Think and the Threaded think
    hook.Add( "Think", ply, function() 
        GLACE:Think()

        if coroutine.status( GLACE:GetThread() ) != "dead" then
            local ok, msg = coroutine.resume( GLACE:GetThread() )
            if !ok then ErrorNoHaltWithStack( msg ) end
        end

        if GLAMBDA:GetConVar( "glambda_debug" ) then
            debugoverlay.Line( GLACE:EyePos(), GLACE:GetEyeTrace().HitPos, 0.1, color_white, true ) 
        end

        -- STUCK MONITOR --
        -- The following stuck monitoring system is a recreation of Source Engine's Stuck Monitoring for Nextbots
        if IsValid( GLACE:GetPath() ) and GLACE:Alive() and ( !GLACE.gb_PathStuckCheck or CurTime() < GLACE.gb_PathStuckCheck ) then
            if GLACE:IsStuck() then
                -- we are/were stuck - have we moved enough to consider ourselves "dislodged"
                if GLACE:SqrRangeTo( GLACE.m_stuckpos ) > STUCK_RADIUS then
                    GLACE:ClearStuck()
                elseif CurTime() > GLACE.m_stillstucktimer then
                    -- Still stuck
                    GLACE:DevMsg( "IS STILL STUCK\n", GLACE:GetPos() )
                    debugoverlay.Sphere( GLACE:GetPos(), 100, 1, Color( 255, 0, 0 ), true )

                    GLACE:OnStuck()
                    GLACE.m_stillstucktimer = CurTime() + 1
                end
            else
                GLACE.m_stillstucktimer = CurTime() + 1

                -- We have moved. Reset the timer and position
                if GLACE:SqrRangeTo( GLACE.m_stuckpos ) > STUCK_RADIUS then
                    GLACE.m_stucktimer = CurTime() + 3
                    GLACE.m_stuckpos = GLACE:GetPos()
                else -- We are within the stuck radius. If we've been here too long, then, we are probably stuck
                    debugoverlay.Line( GLACE:WorldSpaceCenter(), GLACE.m_stuckpos, 1, Color( 255, 0, 0 ), true )

                    if CurTime() > GLACE.m_stucktimer then
                        debugoverlay.Sphere( GLACE:GetPos(), 100, 2, Color( 255, 0, 0 ), true )
                        GLACE:DevMsg( "IS STUCK AT\n", GLACE:GetPos() )
                        
                        GLACE._ISSTUCK = true
                        GLACE:OnStuck()
                    end
                end
            end
            
            debugoverlay.Cross( GLACE.m_stuckpos, 5, 1, color_white, true )
        else -- Reset the stuck status
            GLACE.m_stillstucktimer = CurTime() + 1
            GLACE.m_stucktimer = CurTime() + 3
            GLACE.m_stuckpos = GLACE:GetPos()
        end
    end )
end

function GLAMBDA.Player:BuildPersonalityTable( overrideTbl )
    local personaTbl = self.Personality
    if personaTbl then
        table.Empty( personaTbl )
    else
        personaTbl = {}
    end

    local index = 0
    for persName, persFunc in pairs( GLAMBDA.Personalities ) do
        index = ( #personaTbl + 1 )

        local personaChance = ( overrideTbl and overrideTbl[ persName ] )
        personaTbl[ index ] = { persName, ( personaChance or math.random( 0, 100 ) ), persFunc }

        self[ "Get" .. persName .. "Chance" ] = function( self, rndNum ) 
            local chance = self.Personality[ index ][ 2 ] 
            return ( rndNum == nil and chance or ( math.random( rndNum ) <= chance ) )
        end
        self[ "Set" .. persName .. "Chance" ] = function( self, value ) self.Personality[ index ][ 2 ] = value end
    end

    table.sort( personaTbl, function( a, b ) return a[ 2 ] > b[ 2 ] end )
    self.Personality = personaTbl
end

--

function GLAMBDA.Player:CanTarget( ent )
    return ( ent:IsPlayer() and ent:Alive() and ( !ignorePlys:GetBool() or ent.gl_IsLambdaPlayer ) or ( ent:IsNPC() or ent:IsNextBot() ) and ent:GetInternalVariable( "m_lifeState" ) == 0 )
end

function GLAMBDA.Player:AttackTarget( ent )
    self:SetEnemy( ent )
    if self:IsPanicking() then return end

    if !self:IsSpeaking() and self:GetSpeechChance( 100 ) then
        self:PlayVoiceLine( "taunt" )
    end
    self:CancelMovement()
    self:SetState( "Combat" )
end

function GLAMBDA.Player:RetreatFrom( target, timeout, speakLine )
    local alreadyPanic = self:IsPanicking()
    if !alreadyPanic then
        self:CancelMovement()
        self:SetState( "Retreat" )

        if ( speakLine == nil or speakLine == true ) and self:GetSpeechChance() > 0 then
            self:PlayVoiceLine( "panic" )
        end
    end

    local retreatTime = ( CurTime() + ( timeout or math.random( 10, 15 ) ) )
    if retreatTime > self.RetreatEndTime then self.RetreatEndTime = retreatTime end

    local ene = self:GetEnemy()
    if !alreadyPanic or IsValid( ene ) then self:SetEnemy( target ) end
end