function GLAMBDA.Player:Think()
    local queuedText = self:GetNW2String( "glambda_queuedtext", "" )
    if #queuedText != 0 and CurTime() >= self.NextTextTypeT then
        local typedText = self.TypedTextMsg
        local typedLen = #typedText
        if typedLen >= #queuedText then
            self:Say( typedText )
            self:SetNW2String( "glambda_queuedtext", "" )
            self.TypedTextMsg = ""
        else
            local nextChar = queuedText[ typedLen + 1 ]
            self.TypedTextMsg = typedText .. nextChar
            self.NextTextTypeT = ( CurTime() + ( 1 / ( self:GetTextPerMinute() / 60 ) ) )
        end
    end

    if !self:Alive() or self:IsDisabled() then
        self.NextIdleLineT = ( CurTime() + GLAMBDA:Random( 5, 10 ) )
        self.NextUniversalActionT = ( CurTime() + GLAMBDA:Random( 10, 15, true ) )
        return 
    end

    if CurTime() >= self.NextUniversalActionT then
        local UAFunc = table.Random( GLAMBDA.UniversalActions )
        UAFunc( self )
        self.NextUniversalActionT = ( CurTime() + GLAMBDA:Random( 10, 15, true ) )
    end
    
    if CurTime() >= self.NextIdleLineT and !self:IsSpeaking() and !self:IsTyping() then 
        if self:GetSpeechChance( 100 ) then
            if self:InCombat() then
                self:PlayVoiceLine( "taunt" )
            elseif self:IsPanicking() then
                self:PlayVoiceLine( "panic" )
            else
                self:PlayVoiceLine( "idle" )
            end
        elseif !self:InCombat() and !self:IsPanicking() and self:CanType() and self:GetTextingChance( 100 ) then
            self:TypeMessage( "idle" )
        end

        self.NextIdleLineT = ( CurTime() + GLAMBDA:Random( 5, 10 ) )
    end

    if ( CurTime() - self.NextNPCCheckT ) >= 1 then
        self.NextNPCCheckT = CurTime()

        local enemy = self:GetEnemy()
        if self:InCombat() and !self:CanTarget( enemy ) then
            enemy = nil
            self:SetEnemy( enemy )
            
            self:SetState()
            self:CancelMovement()
        end

        if !self:InCombat() or self:GetState( "Retreat" ) and !IsValid( enemy ) then
            local npcs = self:FindInSphere( nil, 1500, function( ent )
                if !ent:IsNPC() and !ent:IsNextBot() or !ent.Disposition or !self:CanTarget( ent ) then return false end
                return ( ent:Disposition( self:GetPlayer() ) == D_HT and self:IsVisible( ent ) )
            end )
            if #npcs != 0 then
                local rndNpc = npcs[ GLAMBDA:Random( #npcs ) ]
                if self:IsPanicking() then
                    self:SetEnemy( rndNpc )
                else
                    self:AttackTarget( rndNpc )
                end
            end
        end
    end

    local weapon = self:GetActiveWeapon()
    if IsValid( weapon ) then
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
        end

        local enemy = self:GetEnemy()
        if self:InCombat() or self:GetState( "Retreat" ) and IsValid( enemy ) then
            local isMelee = self:GetWeaponStat( "IsMeleeWeapon" )
            if !isMelee and !weapon:HasAmmo() then
                self:SelectLethalWeapon()
            end
            
            local isReloading = self:IsReloadingWeapon()
            local isPanicking = self:IsPanicking()
            local attackRange = self:GetWeaponStat( "AttackDistance", ( isMelee and 100 or 1000 ) )
            if isPanicking and !isMelee then attackRange = ( attackRange * 0.8 ) end
            
            local canShoot = self:GetWeaponStat( "IsLethalWeapon", true )
            if canShoot then
                local fireTr = self:Trace( nil, enemy, nil, MASK_SHOT_PORTAL )
                canShoot = ( fireTr.Fraction >= 0.9 or fireTr.Entity == enemy )
            end
            
            local aimFunc = self:GetWeaponStat( "OverrideAim" )
            local aimPos = ( aimFunc and aimFunc( self, weapon, enemy ) or enemy )

            if canShoot and self:InRange( aimPos, attackRange, self:EyePos() ) then
                self:LookTo( aimPos, 0.25, GLAMBDA:Random( 1, 3 ), 3 )
                if aimPos == enemy then aimPos = aimPos:WorldSpaceCenter() end

                local canSprint = true
                if weapon.IsTFAWeapon then 
                    canSprint = false
                elseif weapon.ARC9 and !weapon:GetProcessedValue( "ShootWhileSprint", true ) then
                    canSprint = false
                end
                self:SetSprint( canSprint )

                local canFire = ( ( aimPos - self:EyePos() ):GetNormalized():Dot( self:GetAimVector() ) >= 0.95 )
                if canFire then
                    local specialFire = self:GetWeaponStat( "SpecialAttack" )
                    if !specialFire or !specialFire( self, weapon, enemy ) then
                        if self:GetWeaponStat( "HasSecondaryFire" ) and GLAMBDA:Random() <= self:GetWeaponStat( "SecondaryFireChance" ) then
                            self:PressKey( IN_ATTACK2 )
                        elseif self:GetWeaponStat( "Automatic", isMelee ) then
                            if !isReloading then
                                self:HoldKey( IN_ATTACK )
                            end
                        elseif CurTime() >= self.NextWeaponAttackT and CurTime() >= weapon:GetNextPrimaryFire() then
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
            else
                self:SetSprint( true )
            end

            if self:GetIsMoving() and !self:GetState( "Retreat" ) then
                if CurTime() >= self.NextCombatPathUpdateT then
                    local keepDist = self:GetWeaponStat( "KeepDistance", ( isMelee and 50 or 500 ) )
                    
                    if isReloading or canShoot and self:InRange( enemy, keepDist ) then
                        local moveAng = ( self:GetPos() - enemy:GetPos() ):Angle()
                        local potentialPos = ( self:GetPos() + moveAng:Forward() * GLAMBDA:Random( ( self:GetRunSpeed() * -0.5 ), keepDist ) + moveAng:Right() * GLAMBDA:Random( -keepDist, keepDist ) )

                        self.CombatPathPosition = ( util.IsInWorld( potentialPos ) and potentialPos or self:Trace( self:GetPos(), potentialPos ).HitPos )
                    else
                        self.CombatPathPosition = enemy
                    end
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
    end
end

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
                        stateArg = table.Copy( stateArg )
                    end

                    local result = statefunc( self, stateArg )
                    if result and curState == self:GetState() then 
                        self:SetState( isstring( result ) and result )
                    end
                end
            end

            coroutine.wait( 0.1 )
        else
            if ( CurTime() - self.LastDeathTime ) >= GLAMBDA:GetConVar( "player_respawn_time" ) and ( !self:IsSpeaking() or !GLAMBDA:GetConVar( "voice_norespawn" ) ) and !self:IsTyping() then
                if !GLAMBDA:GetConVar( "player_respawn" ) then
                    self:Kick()
                    return
                end

                self:Spawn()
                self:OnPlayerRespawn()
            end

            coroutine.wait( GLAMBDA:Random( 0.1, 0.33, true ) )
        end
    end
end

--

function GLAMBDA.Player:OnPlayerRespawn()
    local spawner = self.Spawner
    if IsValid( spawner ) and !GLAMBDA:GetConVar( "player_respawn_spawnpoints" ) then
        local spawnPos = spawner:GetPos()
        self:SetPos( spawnPos )

        spawnPos.z = self:EyePos().z
        self:LookTowards( spawnPos + spawner:GetForward() * 1, 1 )
    end

    self:SimpleTimer( 0, function()
        local spawnWep = GLAMBDA:GetConVar( "combat_spawnweapon" )
        if spawnWep == "random" then
            self:SelectRandomWeapon()
        else
            self:SelectWeapon( spawnWep )
        end

        if !GLAMBDA:GetConVar( "combat_spawnbehavior_initialspawn" ) then
            self:ApplySpawnBehavior()
        end
    end )
end

function GLAMBDA.Player:OnHurt( attacker, healthLeft, damage )
    if healthLeft <= 0 then return end

    if !self:IsPanicking() and attacker != self and IsValid( attacker ) then
        local chance = self:GetCowardnessChance()
        if chance <= 20 then
            chance = ( chance * GLAMBDA:Random( 1.0, 2.5, true ) )
        elseif chance > 60 then
            chance = ( chance / GLAMBDA:Random( 1.5, 2.5, true ) )
        end

        local hpThreshold = GLAMBDA:Random( ( chance / 4 ), chance )
        if healthLeft <= hpThreshold then
            self:RetreatFrom( self:CanTarget( attacker ) and attacker or nil )
            return
        end
    end

    local enemy = self:GetEnemy()
    if attacker != self and attacker != enemy and IsValid( attacker ) and ( !attacker:IsPlayer() or GLAMBDA:Random( 2 ) == 1 ) and ( !IsValid( enemy ) or self:SqrRangeTo( attacker ) <= self:SqrRangeTo( enemy ) ) and self:CanTarget( attacker ) then
        self:AttackTarget( attacker )
    end
end

function GLAMBDA.Player:OnKilled( attacker )
    if self:CanType() and self:GetTextingChance( 100 ) then
        self:TypeMessage( "death" .. ( attacker:IsPlayer() and "byplayer" or "" ), attacker )
    elseif !self:IsTyping() then
        self:PlayVoiceLine( "death" )
    end

    self:SetEnemy( nil )
    self:SetState()
    self:CancelMovement()

    if GLAMBDA:GetConVar( "building_undoondeath" ) then
        self:UndoCommand( true )
    end

    self.LastDeathTime = CurTime()
end

function GLAMBDA.Player:OnOtherKilled( victim, dmginfo )
    local enemy = self:GetEnemy()
    if victim == enemy then
        self:SetEnemy( nil )
        self:SetState()
        self:CancelMovement()
    end
    if !self:Alive() then return end

    local attacker = dmginfo:GetAttacker()
    if attacker == self:GetPlayer() then
        if victim == enemy then 
            if self:GetSpeechChance( 100 ) and ( !self:IsSpeaking() or GLAMBDA:Random( 3 ) == 1 ) then
                self:PlayVoiceLine( "kill" )
            elseif self:GetTextingChance( 100 ) and !self:IsSpeaking() and !self:IsTyping() and self:CanType() then
                self:TypeMessage( "kill", victim )
            end

            if GLAMBDA:Random( 10 ) == 1 then
                self:SetState( "TBaggingPosition", victim:GetPos() )
                self:DevMsg( "I killed my enemy. It's t-bagging time..." )
                return
            end
        end

        if self:GetCowardnessChance( 150 ) then
            self:RetreatFrom( nil, nil, ( self:GetSpeechChance( 100 ) and GLAMBDA:Random( 3 ) == 1 ) )
            self:CancelMovement()

            self:DevMsg( "I killed someone. Retreating..." )
            return
        end
    elseif victim == enemy and self:GetSpeechChance( 100 ) and self:InRange( attacker, 1000 ) and ( attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot() ) then
        if self:IsVisible( attacker ) then
            self:LookTo( attacker, 0.33, 2, 2 )
        end

        self:PlayVoiceLine( "assist" )
    end

    if attacker != self and self:InRange( victim, 1500 ) and self:IsVisible( victim ) then
        local witnessChance = GLAMBDA:Random( 10 )
        if witnessChance == 1 or ( attacker == victim or attacker:IsWorld() ) and witnessChance > 6 then
            self:SetState( "Laughing", { victim, self:GetMovePosition() } )
            self:CancelMovement()
            self:DevMsg( "I killed or saw someone die. Laugh at this person!" )
        elseif victim != enemy then
            if witnessChance == 2 then
                self:LookTo( victim:WorldSpaceCenter(), 0.33, GLAMBDA:Random( 2, 4 ), 2 )

                if self:GetSpeechChance( 100 ) then
                    self:PlayVoiceLine( "witness" )
                elseif self:GetTextingChance( 100 ) and !self:IsSpeaking() and !self:IsTyping() and self:CanType() then
                    self:TypeMessage( "witness", victim )
                end
            end
            
            if !self:InCombat() and self:GetCowardnessChance( 200 ) then
                local targ = ( ( self:CanTarget( attacker ) and self:IsVisible( attacker ) and GLAMBDA:Random( 3 ) == 1 ) and attacker or nil )
                self:LookTo( targ or victim:WorldSpaceCenter(), 0.33, GLAMBDA:Random( 3 ), 2 )
                
                self:RetreatFrom( targ, nil, !self:IsSpeaking( "witness" ) )
                self:CancelMovement()
                
                self:DevMsg( "I saw someone die. Retreating..." )
            end
        end
    end
end

function GLAMBDA.Player:OnDisconnect()
    self:UndoCommand( true )
    
    local spawner = self.Spawner
    if IsValid( spawner ) then
        spawner:SetOwner()
        spawner:Remove()
    end
end

function GLAMBDA.Player:OnStuck()
    self:PressKey( IN_JUMP )
    if !self:OnGround() then
        self:PressKey( IN_DUCK )
    end
end