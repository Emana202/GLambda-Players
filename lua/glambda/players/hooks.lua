function GLAMBDA.Player:Think()
    if !self:Alive() or self:IsDisabled() then return end

    if CurTime() >= self.NextUniversalActionT then
        local UAFunc = table.Random( GLAMBDA.UniversalActions )
        UAFunc( self )
        self.NextUniversalActionT = ( CurTime() + math.Rand( 10, 15 ) )
    end
    
    if CurTime() >= self.NextIdleLineT and !self:IsSpeaking() and self:GetSpeechChance( 100 ) then
        if self:InCombat() then
            self:PlayVoiceLine( "taunt" )
        elseif self:IsPanicking() then
            self:PlayVoiceLine( "panic" )
        else
            self:PlayVoiceLine( "idle" )
        end

        self.NextIdleLineT = ( CurTime() + math.random( 5, 10 ) )
    end

    if ( CurTime() - self.NextNPCCheckT ) >= 1 then
        self.NextNPCCheckT = CurTime()

        if !self:InCombat() or self:GetState( "Retreat" ) and !IsValid( self:GetEnemy() ) then
            local npcs = self:FindInSphere( nil, 1500, function( ent )
                if !ent:IsNPC() and !ent:IsNextBot() or !ent.Disposition or !self:CanTarget( ent ) then return false end
                return ( ent:Disposition( self:GetPlayer() ) == D_HT and self:IsVisible( ent ) )
            end )
            if #npcs != 0 then
                local rndNpc = npcs[ math.random( #npcs ) ]
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

        local enemy = self:GetEnemy()
        if self:InCombat() or self:GetState( "Retreat" ) and IsValid( enemy ) then
            if !weapon:HasAmmo() then
                self:SelectLethalWeapon()
            end
            
            local canShoot = ( self:GetWeaponStat( "IsLethalWeapon", true ) and self:CanShootAt( enemy ) )
            local isMelee = self:GetWeaponStat( "IsMeleeWeapon" )
            local isPanicking = self:IsPanicking()
            local attackRange = self:GetWeaponStat( "AttackDistance", ( isMelee and 80 or 1000 ) )
            if isPanicking and !isMelee then attackRange = ( attackRange * 0.8 ) end

            local inFireRange = ( self:SqrRangeTo( enemy ) <= ( attackRange ^ 2 ) )
            if canShoot and inFireRange then
                local aimFunc = self:GetWeaponStat( "OverrideAim" )
                local aimPos = ( aimFunc and aimFunc( self, weapon, enemy ) or ( isMelee and enemy:NearestPoint( self:EyePos() ) or enemy ) )
                self:LookTowards( aimPos, 0.66 )
                
                local canSprint = true
                if weapon.IsTFAWeapon then 
                    canSprint = false
                elseif weapon.ARC9 and !weapon:GetProcessedValue( "ShootWhileSprint", true ) then
                    canSprint = false
                end
                self:SetSprint( canSprint )

                if aimFunc or self:GetEyeTrace().Entity == enemy then
                    if !self:GetWeaponStat( "SpecialAttack" ) or !self:GetWeaponStat( "SpecialAttack" )( self, weapon, enemy ) then
                        if self:GetWeaponStat( "Automatic", isMelee ) then
                            self:HoldKey( IN_ATTACK )
                        elseif CurTime() >= self.NextWeaponAttackT then
                            self:PressKey( IN_ATTACK )

                            local fireDelay = self:GetWeaponStat( "AttackDelay" )
                            if fireDelay then
                                if istable( fireDelay ) then fireDelay = math.Rand( fireDelay[ 1 ], fireDelay[ 2 ] ) end
                                self.NextWeaponAttackT = ( CurTime() + fireDelay )
                            end
                        end
                    end
                end
            else
                self:SetSprint( true )
            end

            if self:GetIsMoving() and !self:GetState( "Retreat" ) then
                local isReloading = string.match( weapon:GetSequenceActivityName( weapon:GetSequence() ), "RELOAD" )

                if CurTime() >= self.NextCombatPathUpdateT then
                    local keepDist = self:GetWeaponStat( "KeepDistance", ( isMelee and 50 or 500 ) )
                    
                    if isReloading or canShoot and self:SqrRangeTo( enemy ) <= ( keepDist ^ 2 ) then
                        local moveAng = ( self:GetPos() - enemy:GetPos() ):Angle()
                        local runSpeed = self:GetRunSpeed()
                        local potentialPos = ( self:GetPos() + moveAng:Forward() * math.random( -( runSpeed * 0.5 ), keepDist ) + moveAng:Right() * math.random( -runSpeed, runSpeed ) )

                        self.CombatPathPosition = ( util.IsInWorld( potentialPos ) and potentialPos or self:Trace( nil, potentialPos ).HitPos )
                    else
                        self.CombatPathPosition = enemy
                    end
                    self.NextCombatPathUpdateT = ( CurTime() + 0.1 )
                end

                local movePos = self.CombatPathPosition
                local preCombatMovePos = self.PreCombatMovePos
                if preCombatMovePos and isReloading and inFireRange and preCombatMovePos != enemy then
                    movePos = preCombatMovePos
                else
                    self.PreCombatMovePos = false
                end
                self:GetNavigator().gb_GoalPosition = movePos
            end

            local velocity = self:GetVelocity()
            if !isCrouched and ( isPanicking or canShoot and self:SqrRangeTo( enemy ) <= ( ( attackRange * ( isMelee and 10 or 2 ) ) ^ 2 ) ) and velocity:Length2D() >= ( self:GetRunSpeed() * 0.8 ) and math.random( isPanicking and 25 or 35 ) == 1 then
                local collBounds = self:GetCollisionBounds()
                local jumpTr = self:TraceHull( self:GetPos(), ( self:GetPos() + velocity ), collBounds.mins, collBounds.maxs, MASK_PLAYERSOLID, COLLISION_GROUP_PLAYER )

                local hitNorm = jumpTr.HitNormal
                if ( hitNorm.x == 0 and hitNorm.y == 0 and hitNorm.z <= 0 ) then self:PressKey( IN_JUMP ) end
            end
        else
            self.PreCombatMovePos = self:GetNavigator():TranslateGoal()
        end
    end
end

function GLAMBDA.Player:ThreadedThink()
    while true do
        if self:Alive() then
            if !self:IsDisabled() then
                local curState = self:GetState()
                local statefunc = self[ curState ]

                if statefunc then
                    self.ThreadState = curState
                    local stateArg = self.StateVariable

                    local result = statefunc( self, ( istable( stateArg ) and table.Copy( stateArg ) or stateArg ) )
                    if result and curState == self:GetState() then 
                        self:SetState( isstring( result ) and result )
                    end
                end
            end

            coroutine.wait( 0.1 )
        else
            if ( CurTime() - self.LastDeathTime ) >= GLAMBDA:GetConVar( "player_respawntime" ) and !self:IsSpeaking() then
                if !GLAMBDA:GetConVar( "player_respawn" ) then
                    self:Kick()
                    return
                end

                self:Spawn()
                self:OnPlayerRespawn()
            end

            coroutine.wait( math.Rand( 0.1, 0.5 ) )
        end
    end
end

--

function GLAMBDA.Player:OnPlayerRespawn()
    local spawner = self.Spawner
    if IsValid( spawner ) then
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
    if !self:IsPanicking() and attacker != self and IsValid( attacker ) then
        local chance = self:GetCowardnessChance()
        if chance <= 20 then
            chance = ( chance * math.Rand( 1.0, 2.5, true ) )
        elseif chance > 60 then
            chance = ( chance / math.Rand( 1.5, 2.5, true ) )
        end

        local hpThreshold = math.random( ( chance / 4 ), chance )
        if healthLeft <= hpThreshold then
            self:RetreatFrom( self:CanTarget( attacker ) and attacker or nil )
            return
        end
    end

    local enemy = self:GetEnemy()
    if attacker != self and attacker != enemy and IsValid( attacker ) and ( !attacker:IsPlayer() or math.random( 2 ) == 1 ) and ( !IsValid( enemy ) or self:SqrRangeTo( attacker ) <= self:SqrRangeTo( enemy ) ) and self:CanTarget( attacker ) then
        self:AttackTarget( attacker )
    end
end

function GLAMBDA.Player:OnKilled()
    self:PlayVoiceLine( "death" )

    self:SetEnemy( NULL )
    self:SetState()
    self:UndoCommand( true )

    self.LastDeathTime = CurTime()
end

function GLAMBDA.Player:OnOtherKilled( victim, dmginfo )
    local enemy = self:GetEnemy()
    if victim == enemy then
        self:SetEnemy( NULL )
        self:SetState()
        self:CancelMovement()
    end
    if !self:Alive() then return end

    local attacker = dmginfo:GetAttacker()
    if attacker == self:GetPlayer() then
        if victim == enemy then 
            if self:GetSpeechChance( 100 ) and math.random( 3 ) == 1 then
                self:PlayVoiceLine( "kill" )
            end

            if math.random( 10 ) == 1 then
                self:SetState( "TBaggingPosition", victim:GetPos() )
                self:DevMsg( "I killed my enemy. It's t-bagging time..." )
                return
            end
        end

        if self:GetCowardnessChance( 150 ) then
            self:RetreatFrom( nil, nil, ( self:GetSpeechChance( 100 ) and math.random( 3 ) == 1 ) )
            self:CancelMovement()

            self:DevMsg( "I killed someone. Retreating..." )
            return
        end
    elseif victim == enemy and self:GetSpeechChance( 100 ) and self:SqrRangeTo( attacker ) <= ( 1000 ^ 2 ) and ( attacker:IsPlayer() or attacker:IsNPC() or attacker:IsNextBot() ) then
        if self:IsVisible( attacker ) then
            self:LookTo( attacker, 0.5, 2 )
        end

        self:PlayVoiceLine( "assist" )
    end

    if attacker != self and self:SqrRangeTo( victim ) <= ( 1500 ^ 2 ) and self:IsVisible( victim ) then
        local witnessChance = math.random( 10 )
        if witnessChance == 1 or ( attacker == victim or attacker:IsWorld() ) and witnessChance > 6 then
            self:SetState( "Laughing", { victim, self:GetMovePosition() } )
            self:CancelMovement()
            self:DevMsg( "I killed or saw someone die. Laugh at this person!" )
        elseif victim != enemy then
            if witnessChance == 2 then
                self:LookTo( victim:WorldSpaceCenter(), 0.33, math.random( 2, 4 ) )

                if self:GetSpeechChance( 100 ) then
                    self:PlayVoiceLine( "witness" )
                end
            end
            
            if !self:InCombat() and self:GetCowardnessChance( 200 ) then
                local targ = ( ( self:CanTarget( attacker ) and self:IsVisible( attacker ) and math.random( 3 ) == 1 ) and attacker or nil )
                self:LookTo( targ or victim:WorldSpaceCenter(), 0.5, math.random( 3 ) )
                
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