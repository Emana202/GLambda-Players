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
    return ( ( !voiceType or self:GetLastVoiceType() == voiceType ) and RealTime() <= self:GetSpeechEndTime() )
end

function GLAMBDA.Player:InCombat()
    return ( self:GetState( "Combat" ) and IsValid( self:GetEnemy() ) )
end

function GLAMBDA.Player:IsPanicking()
    return ( self:GetState( "Retreat" ) and CurTime() <= self.RetreatEndTime )
end

function GLAMBDA.Player:IsDisabled()
    return ( self:IsFrozen() or aiDisabled:GetBool() )
end

function GLAMBDA.Player:CanType()
    if !GLAMBDA:GetConVar( "textchat_enabled" ) then return end

    local chatLimit = GLAMBDA:GetConVar( "textchat_limit" )
    if chatLimit <= 0 then return true end

    local count = 0
    for _, ply in ipairs( player.GetBots() ) do
        if !ply:IsGLambdaPlayer() or !ply:IsTyping() then continue end
        count = ( count + 1 )
        if count >= chatLimit then return false end
    end
    return true
end

function GLAMBDA.Player:GetNearestAimPoint( target )
    local eyePos = self:EyePos()
    local nearPoint = target:WorldSpaceCenter()
    local closeDist

    local setCount = target:GetHitboxSetCount()
    if isnumber( setCount ) then
        for hboxSet = 0, ( setCount - 1 ) do
            for hitbox = 0, ( target:GetHitBoxCount( hboxSet ) - 1 ) do
                local bone = target:GetHitBoxBone( hitbox, hboxSet )
                local bonePos = target:GetBonePosition( bone )

                local boneDist = eyePos:DistToSqr( bonePos )
                if closeDist and boneDist > closeDist then continue end

                closeDist = boneDist
                nearPoint = bonePos
            end
        end
    end

    return nearPoint
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
                local time = math.max( updateTime, updateTime * ( path:GetLength() / 400 ) )
                if path:GetAge() >= time then self:RecomputePath() end
            end

            self:AvoidCheck()
            self:DoorCheck()

            self:UpdateOnPath()
        end

        coroutine.yield()
    end

    self:SetIsMoving( false )

    return pathResult, cbResult
end

function GLAMBDA.Player:GetMovePosition()
    if !self:GetIsMoving() then return end
    local navigator = self:GetNavigator()
    return ( IsValid( navigator ) and navigator:TranslateGoal() )
end

function GLAMBDA.Player:CancelMovement()
    self:SetAbortMovement( self:GetIsMoving() )
end

--

function GLAMBDA.Player:TypeMessage( msg, keyEnt )
    local textTbl = GLAMBDA.TextMessages[ msg ]
    if textTbl then 
        for _, text in RandomPairs( textTbl ) do
            local condMet, modLine = GLAMBDA.KEYWORD:IsValidCondition( self, text )
            if condMet then msg = modLine; break end
        end
    else
        local condMet, modLine = GLAMBDA.KEYWORD:IsValidCondition( self, text )
        if !condMet then return end
        msg = modLine
    end
    msg = GLAMBDA.KEYWORD:ModifyTextKeyWords( self, msg )

    self:SetNW2String( "glambda_queuedtext", msg )
    self.TypedTextMsg = ""
    self.TextKeyEnt = keyEnt
    self:StopSpeaking()
end

function GLAMBDA.Player:StopSpeaking()
    self:SetSpeechEndTime( 0 )

    net.Start( "glambda_stopspeech" )
        net.WritePlayer( self:GetPlayer() )
    net.Broadcast()
end

function GLAMBDA.Player:PlayVoiceLine( voiceType, delay )
    if !self:Alive() and voiceType != "death" then return end

    local voiceProfile, voiceTbl = self.VoiceProfile
    local vpTbl = GLAMBDA.VoiceProfiles
    if voiceProfile and vpTbl[ voiceProfile ] then
        voiceTbl = vpTbl[ voiceProfile ][ voiceType ]
    end
    if !voiceTbl or #voiceTbl == 0 then
        voiceTbl = GLAMBDA.VoiceLines[ voiceType ]
        if !voiceTbl or #voiceTbl == 0 then return end
    end

    self:SetLastVoiceType( voiceType )
    if !isnumber( delay ) then
        delay = ( delay == nil and GLAMBDA:Random( 0.1, 0.66, true ) or 0 )
    end
    self:SetSpeechEndTime( RealTime() + 4 )

    net.Start( "glambda_playvoicesnd" )
        net.WritePlayer( self:GetPlayer() )
        net.WriteString( voiceTbl[ GLAMBDA:Random( #voiceTbl ) ] )
        net.WriteUInt( self:GetVoicePitch(), 8 )
        net.WriteVector( self:GetPos() )
        net.WriteFloat( delay )
    net.Broadcast()
end

function GLAMBDA.Player:SetState( state, data )
    state = ( state or "Idle" )
    if self:GetState( state ) then return end
    self.State = state
    self:SetStateArg( data )
end

function GLAMBDA.Player:UndoCommand( undoAll )
    local index = self:GetPlayer():UniqueID()
    local undoTbl = undo.GetTable()[ index ]
    if !undoTbl then return end

    if !undoAll then
        self:EmitSound( "buttons/button15.wav.wav", 60 )
        undo.Do_Undo( undoTbl[ #undoTbl ] )
        return
    end
    for _, tbl in ipairs( undoTbl ) do undo.Do_Undo( tbl ) end
end

function GLAMBDA.Player:PlayGestureAndWait( index )
    local isSeq = isstring( index )
    local seqID = ( isSeq and self:LookupSequence( index ) or self:SelectWeightedSequence( index ) )
    if seqID <= 0 then return end

    net.Start( "glambda_playgesture" )
        net.WritePlayer( self:GetPlayer() )
        net.WriteFloat( isSeq and self:GetSequenceActivity( seqID ) or index )
    net.Broadcast()

    local seqDur = self:SequenceDuration( seqID )
    self:Freeze( true )

    coroutine.wait( seqDur )
    self:Freeze( false )
end

--

function GLAMBDA.Player:CanTarget( ent )
    if ent == self:GetPlayer() then return false end
    if ent.gb_IsGlaceNavigator then return false end
    if ent.IsDrGNextbot and ent:IsDown() then return false end

    if ent:IsPlayer() then
        if !ent:Alive() then return false end
        if ent:IsFlagSet( FL_NOTARGET ) then return false end
        
        if !ent:IsGLambdaPlayer() then 
            if ignorePlys:GetBool() then return false end
            if !GLAMBDA:GetConVar( "combat_targetplys" ) then return false end
        end
    elseif ent:IsNPC() or ent:IsNextBot() then
        if ent:IsFlagSet( FL_NOTARGET ) then return false end
        if ent:GetInternalVariable( "m_lifeState" ) != 0 then return false end

        local class = ent:GetClass()
        if class == "rd_target" then return false end
        if string.match( class, "bullseye" ) then return false end
    else
        return false
    end

    return true
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
        
        if ( speakLine == nil or speakLine == true ) and self:GetSpeechChance( 50 ) then
            self:PlayVoiceLine( "panic" )
        end
    end
    
    local retreatTime = ( CurTime() + ( timeout or GLAMBDA:Random( 10, 15 ) ) )
    if retreatTime > self.RetreatEndTime then self.RetreatEndTime = retreatTime end
    
    local ene = self:GetEnemy()
    if !alreadyPanic or IsValid( ene ) then self:SetEnemy( target ) end
end

function GLAMBDA.Player:ApplySpawnBehavior()
    local spawnBehav = GLAMBDA:GetConVar( "combat_spawnbehavior" )
    if spawnBehav == 0 then return end
    
    local closeTarget, searchDist
    local selfZ = self:GetPos().z
    
    local getClosest = GLAMBDA:GetConVar( "combat_spawnbehavior_getclosest" )
    local pairGen = ( getClosest and ipairs or RandomPairs )

    for _, ent in pairGen( ents.GetAll() ) do
        if !IsValid( ent ) or !self:CanTarget( ent ) then continue end
        if spawnBehav == 1 and !ent:IsPlayer() or spawnBehav == 2 and !ent:IsNPC() and !ent:IsNextBot() then continue end

        if !getClosest then
            closeTarget = ent
            break
        end

        local entDist = self:SqrRangeTo( ent )
        local heightDiff = math.abs( selfZ - ent:GetPos().z )
        if searchDist and ( entDist + ( heightDiff * heightDiff ) ) > searchDist then continue end

        closeTarget = ent
        searchDist = entDist
    end
    
    if !closeTarget then return end
    self:AttackTarget( closeTarget )
end

function GLAMBDA.Player:SetPlayerModel( mdl )
    mdl = ( mdl or self.SpawnPlayerModel )
    self:SetModel( mdl )
    
    if mdl != self.SpawnPlayerModel then
        local pmSkin = self:GetSkin()
        local pmBodygroups = nil

        if GLAMBDA:GetConVar( "player_rngbodygroups" ) then
            local skinCount = self:SkinCount()
            if skinCount > 0 then 
                pmSkin = GLAMBDA:Random( 0, ( skinCount - 1 ) )
                self:SetSkin( pmSkin ) 
            end

            pmBodygroups = {}
            for _, bg in ipairs( self:GetBodyGroups() ) do
                local subMdls = #bg.submodels
                if subMdls == 0 then continue end
                
                local rndBg = GLAMBDA:Random( 0, subMdls )
                pmBodygroups[ bg.id ] = rndBg
                self:SetBodygroup( bg.id, rndBg )
            end
        end

        self.PlySkin = pmSkin
        self.PlyBodygroups = pmBodygroups
        self.SpawnPlayerModel = mdl
    else
        self:SetSkin( self.PlySkin )

        local pmBodygroups = self.PlyBodygroups
        if pmBodygroups then
            for id, bg in pairs( pmBodygroups ) do
                self:SetBodygroup( id, bg )
            end
        end
    end
end

--

function GLAMBDA.Player:Hook( hookName, uniqueName, func )
    local hookIdent = "GLambda-PlayerHook-#" .. self:EntIndex() .. "-" .. uniqueName
    self:DevMsg( "Created a hook: " .. hookName .. " | " .. uniqueName )

    hook.Add( hookName, hookIdent, function( ... )
        if !IsValid( self ) then hook.Remove( hookName, hookIdent ) return end
        return func( ... )
    end )
end

function GLAMBDA.Player:InitializeHooks()
    local ply = self:GetPlayer()

    -- Sometimes the real players join the server mid-game, so we need to network the bots to them
    self:Hook( "PlayerInitialSpawn", "NetworkToSpawnedPlayer", function( player )
        if player == ply or player:IsBot() then return end

        net.Start( "glambda_playerinit" )
            net.WritePlayer( ply )
            net.WriteString( ply.gb_ProfilePicture )
        net.Send( player )
    end )

    -- Reset the player's playermodel | Call respawn hook
    self:Hook( "PlayerSpawn", "PlayerSpawn", function( player )
        if player != ply then return end
        self:OnRespawn()

        -- To make sure models are set
        self:SimpleTimer( 0, function()
            if !self.SpawnPlayerModel then return end 
            self:SetPlayerModel( self.SpawnPlayerModel )
        end )
    end )

    -- On Killed hook
    self:Hook( "PlayerDeath", "PlayerDeath", function( player, inflictor, attacker ) 
        if player != ply then return end
        self:OnKilled( attacker, inflictor )
    end )

    -- Update our navigator on map cleanup
    self:Hook( "PostCleanupMap", "PostCleanupMap", function()
        local navigator = self:GetNavigator()
        if !IsValid( navigator ) then
            navigator = ents.Create( "glace_navigator" )
            navigator:SetOwner( ply )
            navigator:Spawn()
            self:SetNavigator( navigator ) 
        end

        navigator:SetPos( self:GetPos() )
        if self.GoalPath then self:ComputePathTo( self.GoalPath )  end
    end )

    -- On hurt hook
    self:Hook( "PlayerHurt", "PlayerHurt", function( player, attacker, healthremaining, damage )
        if player != ply then return end
        self:OnHurt( attacker, healthremaining, damage )
    end )

    -- On someone killed hook
    self:Hook( "PostEntityTakeDamage", "PostEntityTakeDamage", function( victim, info, tookdmg )
        if victim == ply or ( !victim:IsNPC() and ( !victim:IsNextBot() or victim.gb_IsGlaceNavigator ) and !victim:IsPlayer() ) or victim:Health() > 0 or !tookdmg  then return end
        self:OnOtherKilled( victim, info )
    end )

    -- On our disconnect
    self:Hook( "PlayerDisconnected", "PlayerDisconnected", function( player )
        if player != ply then return end
        self:OnDisconnect()
    end )

    -- On someone's text message
    self:Hook( "PlayerSay", "PlayerSay", function( player, text )
        if player == ply or self:IsTyping() or self:IsSpeaking() or self:IsDisabled() or !self:CanType() then return end
        if self:InCombat() or self:IsPanicking() then return end

        local replyChan = ( string.match( text, self:Nick() ) and 100 or 200 )
        if !self:GetTextingChance( replyChan ) then return end

        local replyTime = ( GLAMBDA:Random( 5, 20 ) / 10 )
        self:SimpleTimer( replyTime, function()
            if !IsValid( player ) or self:IsTyping() or self:IsSpeaking() or self:IsDisabled() or !self:CanType() then return end
            if self:InCombat() or self:IsPanicking() then return end
            self:TypeMessage( "response", ply )
        end )
    end )

    --

    local STUCK_RADIUS = 10000
    self.StuckPosition = self:GetPos()
    self.StuckTimer = CurTime() + 3
    self.StillStuckTimer = CurTime() + 1

    -- Think and the Threaded think
    self:Hook( "Think", "Think", function() 
        self:Think()

        if coroutine.status( self:GetThread() ) != "dead" then
            local ok, msg = coroutine.resume( self:GetThread() )
            if !ok then ErrorNoHaltWithStack( msg ) end
        end

        if GLAMBDA:GetConVar( "glambda_debug" ) then
            debugoverlay.Line( self:EyePos(), self:GetEyeTrace().HitPos, 0.1, color_white, true ) 
        end

        -- STUCK MONITOR --
        -- The following stuck monitoring system is a recreation of Source Engine's Stuck Monitoring for Nextbots
        if IsValid( self:GetPath() ) and self:Alive() and ( !self.GoalPathStuckChecl or CurTime() < self.GoalPathStuckChecl ) then
            if self:IsStuck() then
                -- we are/were stuck - have we moved enough to consider ourselves "dislodged"
                if !self:InRange( self.StuckPosition, STUCK_RADIUS ) then
                    self:ClearStuck()
                elseif CurTime() > self.StillStuckTimer then
                    -- Still stuck
                    self:DevMsg( "IS STILL STUCK\n", self:GetPos() )
                    debugoverlay.Sphere( self:GetPos(), 100, 1, Color( 255, 0, 0 ), true )

                    self:OnStuck()
                    self.StillStuckTimer = CurTime() + 1
                end
            else
                self.StillStuckTimer = CurTime() + 1

                -- We have moved. Reset the timer and position
                if !self:InRange( self.StuckPosition, STUCK_RADIUS ) then
                    self.StuckTimer = CurTime() + 3
                    self.StuckPosition = self:GetPos()
                else -- We are within the stuck radius. If we've been here too long, then, we are probably stuck
                    debugoverlay.Line( self:WorldSpaceCenter(), self.StuckPosition, 1, Color( 255, 0, 0 ), true )

                    if CurTime() > self.StuckTimer then
                        debugoverlay.Sphere( self:GetPos(), 100, 2, Color( 255, 0, 0 ), true )
                        self:DevMsg( "IS STUCK AT\n", self:GetPos() )
                        
                        self._ISSTUCK = true
                        self:OnStuck()
                    end
                end
            end
            
            debugoverlay.Cross( self.StuckPosition, 5, 1, color_white, true )
        else -- Reset the stuck status
            self.StillStuckTimer = CurTime() + 1
            self.StuckTimer = CurTime() + 3
            self.StuckPosition = self:GetPos()
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

    for persName, persData in pairs( GLAMBDA.Personalities ) do
        local personaChance = ( overrideTbl and overrideTbl[ persName ] )
        personaTbl[ persName ] = { ( personaChance or GLAMBDA:Random( 0, 100 ) ), persData[ 1 ] }

        self[ "Get" .. persName .. "Chance" ] = function( self, rndNum ) 
            local chance = self.Personality[ 1 ][ persName ][ 1 ] 
            return ( rndNum == nil and chance or ( GLAMBDA:Random( rndNum ) <= chance ) )
        end
        self[ "Set" .. persName .. "Chance" ] = function( self, value ) self.Personality[ 1 ][ persName ][ 1 ] = value end
    end
    
    local sortedTbl = table.ClearKeys( personaTbl, true )
    table.sort( sortedTbl, function( a, b ) return ( a[ 1 ] > b[ 1 ] ) end )

    self.Personality = { personaTbl, sortedTbl }
end