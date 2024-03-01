local RealTime = RealTime
local IsValid = IsValid
local CurTime = CurTime
local RandomPairs = RandomPairs
local ipairs = ipairs
local player_GetBots = player.GetBots
local isnumber = isnumber
local print = print
local tostring = tostring
local engine_TickInterval = engine.TickInterval
local bit_band = bit.band
local isentity = isentity
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local timer_Simple = timer.Simple
local timer_Create = timer.Create
local timer_Remove = timer.Remove
local util_TraceLine = util.TraceLine
local util_TraceHull = util.TraceHull
local ents_FindInSphere = ents.FindInSphere
local net_Start = net.Start
local net_WritePlayer = net.WritePlayer
local net_Broadcast = SERVER and net.Broadcast
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_WriteVector = net.WriteVector
local net_WriteFloat = net.WriteFloat
local undo_GetTable = undo.GetTable
local undo_Do_Undo = SERVER and undo.Do_Undo
local isstring = isstring
local coroutine_wait = coroutine.wait
local coroutine_create = coroutine.create
local ents_Create = SERVER and ents.Create
local string_match = string.match
local ents_GetAll = ents.GetAll
local math_abs = math.abs
local pairs = pairs
local hook_Add = hook.Add
local hook_Remove = hook.Remove
local net_Send = SERVER and net.Send
local coroutine_status = coroutine.status
local coroutine_resume = coroutine.resume
local debugoverlay_Line = debugoverlay.Line
local debugoverlay_Sphere = debugoverlay.Sphere
local Color = Color
local debugoverlay_Cross = debugoverlay.Cross
local table_Empty = table.Empty

-- Returns our current state
function GLAMBDA.Player:GetState( checkState )
    local curState = self.State
    if checkState then return ( curState == checkState ) end
    return curState
end

-- Returns if the given entity is visible to us
function GLAMBDA.Player:IsVisible( ent )
    local result = self:Trace( nil, ent )
    return ( result.Fraction == 1.0 or result.Entity == ent )
end

-- Returns if we are currently speaking in voice chat
-- If "voiceType" argument is given, also checks if we are speaking the voiceline of that type
function GLAMBDA.Player:IsSpeaking( voiceType )
    return ( ( !voiceType or self:GetLastVoiceType() == voiceType ) and RealTime() <= self:GetSpeechEndTime() )
end

-- Returns if we are currently in combat and have an enemy
function GLAMBDA.Player:InCombat()
    return ( self:GetState( "Combat" ) and IsValid( self:GetEnemy() ) )
end

-- Returns if we are currently panicking
function GLAMBDA.Player:IsPanicking()
    return ( self:GetState( "Retreat" ) and CurTime() <= self.RetreatEndTime )
end

-- Returns if our AI is disabled
function GLAMBDA.Player:IsDisabled()
    return ( self:IsFrozen() or GLAMBDA:GetConVar( "ai_disabled" ) )
end

-- Returns if we can use and type in the text chat
function GLAMBDA.Player:CanType()
    if self:IsDisabled() or !GLAMBDA:GetConVar( "textchat_enabled" ) then return end

    local chatLimit = GLAMBDA:GetConVar( "textchat_limit" )
    if chatLimit <= 0 then return true end

    local count = 0
    for _, ply in ipairs( player_GetBots() ) do
        if !ply:IsGLambdaPlayer() or !ply:IsTyping() then continue end
        count = ( count + 1 )
        if count >= chatLimit then return false end
    end
    return true
end

-- Returns the closest hitbox position of given entity
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

-- Sends a debug message to console. Only works if glambda_debug is set to 1
function GLAMBDA.Player:DevMsg( ... )
    if !GLAMBDA:GetConVar( "debug_glace" ) then return end
    print( "GLAMBDA DEBUG: " .. tostring( self:GetPlayer() ) .. " ", ... )
end

local moveInputs = {
    [ IN_FORWARD ] = 1,
    [ IN_BACK ] = 2,
    [ IN_MOVERIGHT ] = 3,
    [ IN_MOVELEFT ] = 4
}
-- Simulates a key press on this player. 
-- This function will go on cooldown for each inkey for a very small delay so that it isn't running every tick and making it seem like it is being "held"
-- It's a key press for a reason lol
-- This shouldn't be used with movement keys like IN_FORWARD
function GLAMBDA.Player:PressKey( inkey )
    local cooldown = self.KeyPressCooldown[ inkey ]
    if cooldown and ( CurTime() - cooldown ) < engine_TickInterval() then return end

    local buttonQueue = self.CmdButtonQueue
    if bit_band( buttonQueue, inkey ) == inkey then return end -- Prevent the same key from being queued
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
function GLAMBDA.Player:HoldKey( inkey )
    local buttonQueue = self.CmdButtonQueue
    if bit_band( buttonQueue, inkey ) == inkey then return end -- Prevent the same key from being queued
    self.CmdButtonQueue = ( buttonQueue + inkey )

    local isMoveKey = moveInputs[ inkey ]
    if isMoveKey != nil then
        local moveSpeed = ( self:IsSprinting() and self:GetRunSpeed() or self:GetWalkSpeed() )
        self.MoveInputForward = ( isMoveKey == 1 and moveSpeed or ( isMoveKey == 2 and -moveSpeed ) )
        self.MoveInputSideway = ( isMoveKey == 3 and moveSpeed or ( isMoveKey == 4 and -moveSpeed ) )
    end
end

-- Removes a key from the button queue
function GLAMBDA.Player:RemoveKey( inkey )
    local buttonQueue = self.CmdButtonQueue
    if bit_band( buttonQueue, inkey ) == inkey then return end
    self.CmdButtonQueue = ( buttonQueue - inkey )
end

-- Makes the player look towards a position or entity. 
-- Similar to :LookTo() except this works like :Approach()
-- This has priority over LookTo()
function GLAMBDA.Player:LookTowards( pos, smooth )
    self.LookTowards_Pos = pos
    self.LookTowards_Smooth = ( smooth or 1 )
    self.LookTowards_EndT = ( CurTime() + 0.2 )
end

-- Makes the player look at a position or entity
-- Smooth is fraction in a LerpAngle(). Set this to 1 for the Player to instantly snap their view onto a position or entity. Set this as a decimal like 0.1 to have a more smooth look
-- endtime is the time in seconds before the Player stops looking at the pos/entity
-- Set pos to nil to stop
function GLAMBDA.Player:LookTo( pos, endtime, priority, smooth )
    if priority and self.LookTo_Pos and self.LookTo_Priority > priority then return end
    self.LookTo_Pos = pos
    self.LookTo_Smooth = ( smooth or 1 )
    self.LookTo_EndT = ( endtime and CurTime() + endtime or nil )
    self.LookTo_Priority = priority
end

-- Returns a squared distance to the position
-- Much faster than the normal way
function GLAMBDA.Player:SqrRangeTo( pos, startPos )
    if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
    pos = isentity( pos ) and pos:GetPos() or pos

    startPos = ( startPos or self:GetPos() )
    return startPos:DistToSqr( pos )
end

-- Returns a squared distance to the position on a 2D plane. This means the Z axis is removed out of the picture
function GLAMBDA.Player:SqrRangeToXY( pos, startPos )
    if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end

    pos = isentity( pos ) and pos:GetPos() or pos
    pos[ 3 ] = 0
    
    startPos = ( startPos or self:GetPos() )
    startPos[ 3 ] = 0

    return startPos:DistToSqr( pos )
end

-- Returns a distance based on source units
-- For simple in range checks, use SqrRangeTo( pos ). For example, SqrRangeTo( Vector() ) < ( 500 * 500 ) is much faster to calculate
function GLAMBDA.Player:RangeTo( pos, startPos )
    if isentity( pos ) and !IsValid( pos ) then ErrorNoHaltWithStack( "Attempt to get range from a entity that isn't valid!" ) return end
    pos = isentity( pos ) and pos:GetPos() or pos

    startPos = ( startPos or self:GetPos() )
    return startPos:Distance( pos )
end

-- Returns if the given position in is range
function GLAMBDA.Player:InRange( pos, range, startPos )
    return ( self:SqrRangeTo( pos, startPos ) <= ( range * range ) )
end

-- Returns a normalized vector from the player's position to the other pos or entity
function GLAMBDA.Player:NormalTo( pos )
    pos = ( isentity( pos ) and pos:GetPos() or pos )
    return ( pos - self:GetPos() ):GetNormalized()
end

-- Creates a simple timer
function GLAMBDA.Player:SimpleTimer( delay, func )
    timer_Simple( delay, function() 
        if !IsValid( self ) then return end
        func()
    end )
end

-- Creates a named timer
function GLAMBDA.Player:Timer( name, delay, reps, func )
    local timername = "glacebase_timer_" .. self:GetPlayer():EntIndex() .. name
    timer_Create( timername, delay, reps, function()
        if !IsValid( self ) then timer_Remove( timername ) return end
        if func() == true then timer_Remove( timername ) return end
    end )
end

-- Removes a named timer
function GLAMBDA.Player:RemoveTimer( name )
    timer_Remove( "glacebase_timer_" .. self:GetPlayer():EntIndex() .. name )
end

-- Simple trace
local normaltrace = {}
function GLAMBDA.Player:Trace( start, endpos, col, mask, filter )
    normaltrace.start = start or self:EyePos()
    normaltrace.endpos = ( isentity( endpos ) and endpos:WorldSpaceCenter() or endpos )
    normaltrace.filter = filter or self:GetPlayer()
    normaltrace.mask = mask or MASK_SOLID
    normaltrace.collisiongroup = col or COLLISION_GROUP_NONE
    
    return util_TraceLine( normaltrace )
end

-- Hull trace
local hulltrace = {}
function GLAMBDA.Player:TraceHull( start, endpos, mins, maxs, col, mask, filter )
    hulltrace.start = start or self:EyePos()
    hulltrace.endpos = ( isentity( endpos ) and endpos:WorldSpaceCenter() or endpos )
    hulltrace.mins = mins
    hulltrace.maxs = maxs
    hulltrace.filter = filter or self:GetPlayer()
    hulltrace.mask = mask or MASK_SOLID
    hulltrace.collisiongroup = col or COLLISION_GROUP_NONE
    
    return util_TraceHull( hulltrace )
end

-- Simple Find in sphere function with a filter function
-- Return true in the filter function to let a entity be included in the returned table
function GLAMBDA.Player:FindInSphere( pos, dist, filter )
    local entities = {}
    local ply = self:GetPlayer()
    for _, ent in ipairs( ents_FindInSphere( ( pos or self:GetPos() ), dist ) ) do
        if ent == ply or !IsValid( ent ) or ent.gb_IsGlaceNavigator or filter and !filter( ent ) then continue end
        entities[ #entities + 1 ] = ent
    end
    return entities
end

-- Returns the closest entity in a table
function GLAMBDA.Player:GetClosest( tbl )
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
function GLAMBDA.Player:CreateGetSetFuncs( name, func )
    self[ "Get" .. name ] = function( self )
        return self[ "gb_getsetvar" .. name ]
    end
    self[ "Set" .. name ] = function( self, val )
        if func and func( self[ "Get" .. name ]( self ), val ) == true then return end
        self[ "gb_getsetvar" .. name ] = val
    end
end

--

-- Returns a modified version of given message with keywords and conditions
-- If msg is a text type, will return a random modified message from the message tbl
function GLAMBDA.Player:GetTextLine( msg, keyEnt )
    local textProfile, textTbl = self.TextProfile
    local tpTbl = GLAMBDA.TextProfiles
    if textProfile and tpTbl[ textProfile ] then
        textTbl = tpTbl[ textProfile ][ msg ]
    end
    if !textTbl or #textTbl == 0 then
        textTbl = GLAMBDA.TextMessages[ msg ]
        if textTbl then
            local rndMsg
            for _, text in RandomPairs( textTbl ) do
                local condMet, modLine = GLAMBDA.KEYWORD:IsValidCondition( self, text, keyEnt )
                if !condMet then continue end 
                rndMsg = modLine; break
            end

            if !rndMsg then return false end
            msg = rndMsg
        else
            local condMet, modLine = GLAMBDA.KEYWORD:IsValidCondition( self, msg, keyEnt )
            if !condMet then return false end
            msg = modLine
        end
    end

    return GLAMBDA.KEYWORD:ModifyTextKeyWords( self, msg, keyEnt )
end

-- Puts the given text message or text type and key entity into our text chat queue
function GLAMBDA.Player:TypeMessage( msg, keyEnt )
    self.QueuedMessages[ #self.QueuedMessages + 1 ] = { msg, keyEnt }
end

-- Makes us stop our current speech in voice chat
function GLAMBDA.Player:StopSpeaking()
    self:SetSpeechEndTime( 0 )

    net_Start( "glambda_stopspeech" )
        net_WritePlayer( self:GetPlayer() )
    net_Broadcast()
end

-- Plays a random voiceline from the given voicetype in a voice chat
-- "delay" argument delays the play for the given amount
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

    net_Start( "glambda_playvoicesnd" )
        net_WritePlayer( self:GetPlayer() )
        net_WriteString( voiceTbl[ GLAMBDA:Random( #voiceTbl ) ] )
        net_WriteUInt( self:GetVoicePitch(), 8 )
        net_WriteVector( self:GetPos() )
        net_WriteFloat( delay )
    net_Broadcast()
end

-- Sets our current state to the given one
-- "data" argument is a variable that'll be used while executing the state, can be a table if you have multiple
function GLAMBDA.Player:SetState( state, data )
    state = ( state or "Idle" )
    if self:GetState( state ) then return end
    self.State = state
    self:SetStateArg( data )
end

-- Undo's our last spawned entity
-- If "undoAll" is true, undo's every entity we have spawned
function GLAMBDA.Player:UndoCommand( undoAll )
    local index = self:GetPlayer():UniqueID()
    local undoTbl = undo_GetTable()[ index ]
    if !undoTbl then return end

    if !undoAll then
        self:EmitSound( "buttons/button15.wav.wav", 60 )
        undo_Do_Undo( undoTbl[ #undoTbl ] )
        return
    end
    for _, tbl in ipairs( undoTbl ) do undo_Do_Undo( tbl ) end
end

-- Plays a given gesture animation and waits until it's finished
-- Accepts both activity IDs and sequence names
-- Only usable in coroutine threads!
function GLAMBDA.Player:PlayGestureAndWait( index )
    local isSeq = isstring( index )
    local seqID = ( isSeq and self:LookupSequence( index ) or self:SelectWeightedSequence( index ) )
    if seqID <= 0 then return end

    net_Start( "glambda_playgesture" )
        net_WritePlayer( self:GetPlayer() )
        net_WriteFloat( isSeq and self:GetSequenceActivity( seqID ) or index )
    net_Broadcast()

    local seqDur = self:SequenceDuration( seqID )
    self:Freeze( true )
    self:SetNW2Bool( "glambda_playingtaunt", true )

    coroutine_wait( seqDur )
    self:Freeze( false )
    self:SetNW2Bool( "glambda_playingtaunt", false )
end

-- Resets our AI by creating a new thread coroutine and setting state to idle, and etc.
function GLAMBDA.Player:ResetAI()
    self:SetEnemy( nil )
    self:SetState()
    self:CancelMovement()
    
    self:SetThread( coroutine_create( function() 
        self:ThreadedThink() 
        print( "GLambda Players: " .. self:Name() .. "'s Threaded Think has stopped executing!" ) 
    end ) )

    local navigator = self:GetNavigator()
    if IsValid( navigator ) then navigator:Remove() end

    navigator = ents_Create( "glace_navigator" )
    navigator:SetOwner( self:GetPlayer() )
    navigator:Spawn()
    self:SetNavigator( navigator )

    if navigator:GetPos() != self:GetPos() then
        navigator:SetPos( self:GetPos() )
    end
end

--

-- Returns if we can target the given entity
function GLAMBDA.Player:CanTarget( ent )
    if ent.gb_IsGlaceNavigator then return false end
    if ent.IsDrGNextbot and ent:IsDown() then return false end
    if ent == self:GetPlayer() then return false end
    if ent:IsFlagSet( FL_NOTARGET ) then return false end

    local wepTargetFunc = self:GetWeaponStat( "OnCanTarget" )
    if wepTargetFunc and !wepTargetFunc( self, self:GetActiveWeapon(), ent ) then return false end

    if ent:IsPlayer() then
        if !ent:Alive() then return false end
        
        if !ent:IsGLambdaPlayer() then 
            if GLAMBDA:GetConVar( "ai_ignoreplayers" ) then return false end
            if !GLAMBDA:GetConVar( "combat_targetplys" ) then return false end
        end
    elseif ent:IsNPC() or ent:IsNextBot() then
        if ent:GetInternalVariable( "m_lifeState" ) != 0 then return false end
        if GLAMBDA:GetConVar( "combat_ignorefriendnpcs" ) then
            local dispFunc = ent.Disposition
            if dispFunc and dispFunc( ent, self:GetPlayer() ) != D_HT then return false end
        end

        local class = ent:GetClass()
        if class == "rd_target" then return false end
        if string_match( class, "bullseye" ) then return false end
    else
        return false
    end

    return true
end

-- Makes us attack the given entity
-- If we are panicking, sets the retreat target to the entity instead
function GLAMBDA.Player:AttackTarget( ent )
    self:SetEnemy( ent )
    if self:IsPanicking() then return end

    if !self:IsSpeaking() and self:GetSpeechChance( 100 ) then
        self:PlayVoiceLine( "taunt" )
    end
    self:CancelMovement()
    self:SetState( "Combat" )
end

-- Makes us start panicking and run away
-- "timeout" argument decides when we should stop panicking
-- "speakLine" argument decides what voicetype we should say when starting
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

-- Applies the combat spawn behavior settings to us
function GLAMBDA.Player:ApplySpawnBehavior()
    local spawnBehav = GLAMBDA:GetConVar( "combat_spawnbehavior" )
    if spawnBehav == 0 then return end
    
    local closeTarget, searchDist
    local selfZ = self:GetPos().z
    
    local getClosest = GLAMBDA:GetConVar( "combat_spawnbehavior_getclosest" )
    local pairGen = ( getClosest and ipairs or RandomPairs )

    for _, ent in pairGen( ents_GetAll() ) do
        if !IsValid( ent ) or !self:CanTarget( ent ) then continue end
        if spawnBehav == 1 and !ent:IsPlayer() or spawnBehav == 2 and !ent:IsNPC() and !ent:IsNextBot() then continue end

        if !getClosest then
            closeTarget = ent
            break
        end

        local entDist = self:SqrRangeTo( ent )
        local heightDiff = math_abs( selfZ - ent:GetPos().z )
        if searchDist and ( entDist + ( heightDiff * heightDiff ) ) > searchDist then continue end

        closeTarget = ent
        searchDist = entDist
    end
    
    if !closeTarget then return end
    self:AttackTarget( closeTarget )
end

-- Sets our playermodel to the given model
function GLAMBDA.Player:SetPlayerModel( mdl, noBg )
    mdl = ( mdl or self.SpawnPlayerModel )
    self:SetModel( mdl )
    
    if mdl != self.SpawnPlayerModel then
        local pmSkin = self:GetSkin()
        local pmBodygroups = nil

        if !noBg and GLAMBDA:GetConVar( "player_rngbodygroups" ) then
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

-- Creates a hook that'll be automatically removed once we are disconnected from the server
function GLAMBDA.Player:Hook( hookName, uniqueName, func )
    local hookIdent = "GLambda-PlayerHook-#" .. self:EntIndex() .. "-" .. uniqueName
    self:DevMsg( "Created a hook: " .. hookName .. " | " .. uniqueName )

    hook_Add( hookName, hookIdent, function( ... )
        if !IsValid( self ) then hook_Remove( hookName, hookIdent ) return end
        return func( ... )
    end )
end

-- !!! DON'T TOUCH ANYTHING BELOW !!! -- 

function GLAMBDA.Player:InitializeHooks()
    local ply = self:GetPlayer()

    -- Sometimes the real players join the server mid-game, so we need to network the bots to them
    self:Hook( "PlayerInitialSpawn", "NetworkToSpawnedPlayer", function( player )
        if player == ply or player:IsBot() then return end

        net_Start( "glambda_playerinit" )
            net_WritePlayer( ply )
            net_WriteString( ply.gb_ProfilePicture )
        net_Send( player )
    end )

    -- Reset the player's playermodel
    self:Hook( "PlayerSpawn", "PlayerSpawn", function( player )
        if player != ply then return end

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
            navigator = ents_Create( "glace_navigator" )
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
        if player == ply or !self:CanType() then return end

        local replyChan = 250
        replyChan = ( replyChan + ( #self.QueuedMessages * 200 ) )
        if string_match( text, self:Nick() ) then replyChan = ( replyChan * 0.33 ) end
        if !self:GetTextingChance( replyChan ) then return end

        local replyTime = ( GLAMBDA:Random( 5, 20 ) / 10 )
        self:SimpleTimer( replyTime, function()
            if !IsValid( player ) or !self:CanType() then return end
            self:TypeMessage( "response", player )
        end )
    end )

    --

    local STUCK_RADIUS = 100
    self.StuckPosition = self:GetPos()
    self.StuckTimer = CurTime() + 3
    self.StillStuckTimer = CurTime() + 1

    -- Think and the Threaded think
    self:Hook( "Think", "Think", function() 
        self:Think()

        if coroutine_status( self:GetThread() ) != "dead" then
            local ok, msg = coroutine_resume( self:GetThread() )
            if !ok then ErrorNoHaltWithStack( msg ) end
        end

        if GLAMBDA:GetConVar( "glambda_debug" ) then
            debugoverlay_Line( self:EyePos(), self:GetEyeTrace().HitPos, 0.1, color_white, true ) 
        end

        -- STUCK MONITOR --
        -- The following stuck monitoring system is a recreation of Source Engine's Stuck Monitoring for Nextbots
        if IsValid( self:GetPath() ) and self:Alive() and !self:IsDisabled() and !self:IsTyping() and ( !self.GoalPathStuckChecl or CurTime() < self.GoalPathStuckChecl ) then
            if self:IsStuck() then
                -- we are/were stuck - have we moved enough to consider ourselves "dislodged"
                if !self:InRange( self.StuckPosition, STUCK_RADIUS ) then
                    self:ClearStuck()
                elseif CurTime() > self.StillStuckTimer then
                    -- Still stuck
                    self:DevMsg( "IS STILL STUCK\n", self:GetPos() )
                    debugoverlay_Sphere( self:GetPos(), 100, 1, Color( 255, 0, 0 ), true )

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
                    debugoverlay_Line( self:WorldSpaceCenter(), self.StuckPosition, 1, Color( 255, 0, 0 ), true )

                    if CurTime() > self.StuckTimer then
                        debugoverlay_Sphere( self:GetPos(), 100, 2, Color( 255, 0, 0 ), true )
                        self:DevMsg( "IS STUCK AT\n", self:GetPos() )
                        
                        self._ISSTUCK = true
                        self:OnStuck()
                    end
                end
            end
            
            debugoverlay_Cross( self.StuckPosition, 5, 1, color_white, true )
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
        table_Empty( personaTbl )
    else
        personaTbl = {}
    end

    for persName, persData in pairs( GLAMBDA.Personalities ) do
        local personaChance = ( overrideTbl and overrideTbl[ persName ] )
        personaTbl[ persName ] = { ( personaChance or GLAMBDA:Random( 0, 100 ) ), persData[ 1 ] }

        self[ "Get" .. persName .. "Chance" ] = function( self, rndNum ) 
            local chance = self.Personality[ persName ][ 1 ] 
            return ( rndNum == nil and chance or ( GLAMBDA:Random( rndNum ) <= chance ) )
        end
        self[ "Set" .. persName .. "Chance" ] = function( self, value ) self.Personality[ persName ][ 1 ] = value end
    end

    self.Personality = personaTbl
end