local CurTime = CurTime
local table_remove = table.remove
local table_Random = table.Random
local IsValid = IsValid
local isnumber = isnumber
local istable = istable
local util_IsInWorld = ( SERVER and util.IsInWorld )
local isvector = isvector
local Vector = Vector
local isangle = isangle
local Angle = Angle
local table_Copy = table.Copy
local isstring = isstring
local coroutine_wait = coroutine.wait

--

-- Called every think
function GLAMBDA.Player:Think()
    local isTyping = self:HandleTextTyping()
    if isTyping != nil then self:SetNW2Bool( "glambda_istexttyping", isTyping ) end

    --
    
    local isDead = !self:Alive()
    local isDisabled = self:IsDisabled()
    GLAMBDA:RunHook( "GLambda_OnPlayerThink", self, isDead, isDisabled )

    if isDead or isDisabled then
        self.NextIdleLineT = ( CurTime() + GLAMBDA:Random( 5, 10 ) )
        self.NextUniversalActionT = ( CurTime() + GLAMBDA:Random( 10, 15, true ) )

        return 
    end

    if CurTime() >= self.NextUniversalActionT then
        self.NextUniversalActionT = ( CurTime() + GLAMBDA:Random( 10, 15, true ) )
        
        local UAFunc = table_Random( GLAMBDA.UniversalActions )
        UAFunc( self )
    end
    
    if CurTime() >= self.NextIdleLineT then 
        self.NextIdleLineT = ( CurTime() + GLAMBDA:Random( 5, 10 ) )
        if onFire and self:IsSpeaking() then self.NextIdleLineT = ( self.NextIdleLineT - 5 ) end
        
        if !self:IsSpeaking() and !self:IsTyping() then 
            local onFire = self:IsOnFire()
            if self:GetSpeechChance( 100 ) then
                if onFire or self:IsPanicking() then
                    self:PlayVoiceLine( "panic" )
                elseif self:InCombat() then
                    self:PlayVoiceLine( "taunt" )
                else
                    self:PlayVoiceLine( "idle" )
                end
            elseif !self:InCombat() and !self:IsPanicking() and self:CanType() and self:GetTextingChance( 100 ) then
                self:TypeMessage( "idle" )
            end
        end
    end

    if ( CurTime() - self.LastNPCCheckT ) >= 1 then
        self.LastNPCCheckT = CurTime()

        local enemy = self:GetEnemy()
        if self:InCombat() and !self:CanTarget( enemy ) then
            enemy = nil
            self:SetEnemy( enemy )
            
            self:SetState()
            self:CancelMovement()
        end

        if GLAMBDA:GetConVar( "combat_attackhostilenpcs" ) and ( !self:InCombat() or self:GetState( "Retreat" ) and !IsValid( enemy ) ) then
            local npcs = self:FindInSphere( nil, 1500, function( ent )
                if !ent:IsNPC() and !ent:IsNextBot() or !ent.Disposition or !self:CanTarget( ent ) then return false end
                return ( ent:Disposition( self:GetPlayer() ) == D_HT and self:IsVisible( ent ) )
            end )
            if #npcs != 0 then
                self:AttackTarget( GLAMBDA:Random( npcs ) )
            end
        end
    end

    if !self:OnGround() and self:WaterLevel() == 0 and !self:IsSpeaking( "fall" ) then
        local selfVel = self:GetVelocity()
        local horizSpeed = ( selfVel:Length2D() / 5 )

        local fallSpeed = -selfVel.z
        if fallSpeed < 0 then fallSpeed = ( -fallSpeed / 2 ) end

        if ( fallSpeed + horizSpeed ) > 526.5 then
            self:PlayVoiceLine( "fall" )
        end
    end

    --

    self:HandleWeapon()
end

-- Called every think however this think is within a Coroutine thread meaning you can pause executions and ect
function GLAMBDA.Player:ThreadedThink()
    while ( true ) do
        if self:Alive() then
            if !self:IsDisabled() and !self:IsTyping() then
                local curState = self:GetState()
                local statefunc = self[ curState ]

                if statefunc then
                    self:SetThreadState( curState )
                    
                    local stateArg = self:GetStateArg()
                    if isvector( stateArg ) then
                        stateArg = Vector( stateArg.x, stateArg.y, stateArg.z )
                    elseif isangle( stateArg ) then
                        stateArg = Angle( stateArg.p, stateArg.y, stateArg.r )
                    elseif istable( stateArg ) then
                        stateArg = table_Copy( stateArg )
                    end

                    local result = statefunc( self, stateArg )
                    if result and curState == self:GetState() then 
                        self:SetState( isstring( result ) and result )
                    end
                end
            end

            coroutine_wait( 0.1 )
        else
            if ( CurTime() - self.LastDeathTime ) >= GLAMBDA:GetConVar( "player_respawn_time" ) and ( !self:IsSpeaking() or !GLAMBDA:GetConVar( "voice_norespawn" ) ) and !self:IsTyping() then
                if !GLAMBDA:GetConVar( "player_respawn" ) then
                    self:Kick( "GLambda: Respawning disabled" )
                    return
                end

                self:Spawn()
                self:OnPlayerRespawn()
            end

            coroutine_wait( GLAMBDA:Random( 0.1, 0.33, true ) )
        end
    end
end

--

function GLAMBDA.Player:HandleWeapon()
    local weapon = self:GetActiveWeapon()
    if !IsValid( weapon ) then return end
    
    if CurTime() >= self.NextWeaponThinkT then
        local thinkFunc = self:GetWeaponStat( "OnThink" )
        if thinkFunc then
            local thinkTime = thinkFunc( self, weapon )
            if isnumber( thinkTime ) then self.NextWeaponThinkT = ( CurTime() + thinkTime ) end
        end
    end
    
    local wepClip = weapon:Clip1()
    if wepClip == 0 or wepClip < weapon:GetMaxClip1() and CurTime() >= self.NextAmmoCheckT then
        self:PressKey( IN_RELOAD )
        self.NextAmmoCheckT = ( CurTime() + GLAMBDA:Random( 2, 8 ) )
    end

    local enemy = self:GetEnemy()
    if !self:InCombat() and ( !self:GetState( "Retreat" ) or !IsValid( enemy ) ) then return end
    
    local isMelee = self:GetWeaponStat( "IsMeleeWeapon" )
    if !isMelee and !weapon:HasAmmo() then self:SelectLethalWeapon() end
            
    local isReloading = self:IsReloadingWeapon()
    local isPanicking = self:IsPanicking()
            
    local fireTr = self:Trace( nil, enemy, nil, MASK_SHOT_PORTAL )
    local canShoot = ( fireTr.Fraction >= 0.95 or fireTr.Entity == enemy )

    local aimFunc = self:GetWeaponStat( "OverrideAim" )
    local aimPos = ( aimFunc and aimFunc( self, weapon, enemy, canShoot ) or enemy )

    local attackRange = self:GetWeaponStat( "AttackDistance", ( isMelee and 100 or 1000 ) )
    if isPanicking and !isMelee then attackRange = ( attackRange * 0.8 ) end
    
    local canSprint = true
    local inAttackRange = self:InRange( aimPos, attackRange, self:EyePos() )
    if canShoot and inAttackRange then
        self:LookTo( aimPos, GLAMBDA:Random( 3 ), 3 )
        if aimPos == enemy then aimPos = aimPos:WorldSpaceCenter() end

        local canFire = ( ( aimPos - self:EyePos() ):GetNormalized():Dot( self:GetAimVector() ) >= 0.95 )
        if canFire and !GLAMBDA:RunHook( "GLambda_OnPlayerCanFireWeapon", self, weapon, enemy ) then
            canSprint = !self:GetWeaponStat( "NoSprintAttack", false )

            local specialFire = self:GetWeaponStat( "SpecialAttack" )
            if !specialFire or !specialFire( self, weapon, enemy ) then
                if self:GetWeaponStat( "HasSecondaryFire" ) and GLAMBDA:Random( 100 ) <= self:GetWeaponStat( "SecondaryFireChance" ) then
                    self:PressKey( IN_ATTACK2 )
                elseif self:GetWeaponStat( "Automatic", isMelee ) then
                    if !isReloading then
                        self:HoldKey( IN_ATTACK )
                    end
                elseif CurTime() >= self.NextWeaponAttackT and CurTime() > weapon:GetNextPrimaryFire() then
                    self:PressKey( IN_ATTACK )

                    local fireDelay = self:GetWeaponStat( "AttackDelay" )
                    if fireDelay then
                        if istable( fireDelay ) then fireDelay = GLAMBDA:Random( fireDelay[ 1 ], fireDelay[ 2 ], true ) end
                        self.NextWeaponAttackT = ( CurTime() + fireDelay )
                    end
                end
            end
        end

        self.NextAmmoCheckT = ( CurTime() + GLAMBDA:Random( 2, 8 ) )
    end

    if !self:GetIsMoving() then return end 
    self:SetSprint( canSprint )

    if !self:GetState( "Retreat" ) then
        if CurTime() >= self.NextCombatPathUpdateT then
            local keepDist = self:GetWeaponStat( "KeepDistance", ( isMelee and 50 or 500 ) )
            local inKeepRange = self:InRange( enemy, keepDist )

            local movePos = enemy
            if isReloading or canShoot and inKeepRange then
                local moveAng = ( self:GetPos() - enemy:GetPos() ):Angle()
                local potentialPos = ( self:GetPos() + moveAng:Forward() * GLAMBDA:Random( ( self:GetRunSpeed() * -0.5 ), keepDist ) + moveAng:Right() * GLAMBDA:Random( -keepDist, keepDist ) )

                movePos = ( util_IsInWorld( potentialPos ) and potentialPos or self:Trace( self:GetPos(), potentialPos ).HitPos )
            end

            local onMoveFunc = self:GetWeaponStat( "OverrideMovePos" )
            if onMoveFunc then
                local funcResult = onMoveFunc( self, weapon, enemy, ( movePos == enemy and enemy:GetPos() or movePos ), canShoot, inAttackRange, inKeepRange )
                if isvector( funcResult ) then movePos = funcResult end
            end

            local hookPath = GLAMBDA:RunHook( "GLambda_OnPlayerCombatPath", self, movePos, enemy )
            self.CombatPathPosition = ( hookPath or movePos )
            self.NextCombatPathUpdateT = ( CurTime() + 0.1 )
        end

        self:GetNavigator().gb_GoalPosition = self.CombatPathPosition
    end

    local velocity = self:GetVelocity()
    if !isCrouched and ( isPanicking or canShoot and self:InRange( enemy, ( attackRange * ( isMelee and 10 or 2 ) ) ) ) and velocity:Length2D() >= ( self:GetRunSpeed() * 0.8 ) and self:OnGround() and GLAMBDA:Random( isPanicking and 25 or 35 ) == 1 then
        local collBounds = self:GetCollisionBounds()
        local jumpTr = self:TraceHull( self:GetPos(), ( self:GetPos() + velocity ), collBounds.mins, collBounds.maxs, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER, { self:GetPlayer(), enemy } )

        local hitNorm = jumpTr.HitNormal
        if ( hitNorm.x == 0 and hitNorm.y == 0 and hitNorm.z <= 0 ) then self:PressKey( IN_JUMP ) end
    end
end

function GLAMBDA.Player:HandleTextTyping()
    if CurTime() <= self.NextTextTypeT then return end 

    if self:IsSpeaking() or self:Alive() and ( self:InCombat() or self:IsPanicking() ) then
        self.NextTextTypeT = ( CurTime() + GLAMBDA:Random( 0.1, 1, true ) )
        return false
    end

    local queuedText = self.CurrentTextMsg
    if !queuedText then
        local queuedMsgs = self.QueuedMessages
        if #queuedMsgs == 0 then return false end

        local msgTbl = queuedMsgs[ 1 ]
        local textLine = self:GetTextLine( msgTbl[ 1 ], msgTbl[ 2 ] )
        
        if textLine then
            queuedText = textLine
            self.CurrentTextMsg = textLine
            self.TextKeyEnt = keyEnt
            self.TypedTextMsg = ""
        end
        table_remove( queuedMsgs, 1 )
    end
    if !queuedText then return false end

    local typedText = self.TypedTextMsg
    local typedLen = #typedText
    if typedLen >= #queuedText then
        self:Say( typedText )
        self.CurrentTextMsg = false
        self.TypedTextMsg = ""
        return false
    end

    local nextChar = queuedText[ typedLen + 1 ]
    self.TypedTextMsg = typedText .. nextChar
    self.NextTextTypeT = ( CurTime() + ( 1 / ( self:GetTextPerMinute() / 60 ) ) )
    return true
end