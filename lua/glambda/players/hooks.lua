local CurTime = CurTime
local IsValid = IsValid

--

function GLAMBDA.Player:OnPlayerRespawn()
    local spawner = self.Spawner
    if IsValid( spawner ) and !GLAMBDA:GetConVar( "player_respawn_spawnpoints" ) then
        local spawnPos = spawner:GetPos()
        self:SetPos( spawnPos )

        local spawnAng = spawner:GetAngles()
        self:SetAngles( spawnAng )
        self:SetEyeAngles( spawnAng )
    end

    self:SelectSpawnWeapon()
    if !GLAMBDA:GetConVar( "combat_spawnbehavior_initialspawn" ) then
        self:ApplySpawnBehavior()
    end

    GLAMBDA:RunHook( "GLambda_OnPlayerRespawn", self )
end

-- Called when this player is hurt
function GLAMBDA.Player:OnHurt( attacker, healthLeft, damage )
    GLAMBDA:RunHook( "GLambda_OnPlayerHurt", self, attacker, healthLeft, damage )
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

-- Called when this player is killed
function GLAMBDA.Player:OnKilled( attacker )
    if self:CanType() and self:GetTextingChance( 100 ) then
        self:StopSpeaking()
        self:TypeMessage( "death" .. ( attacker:IsPlayer() and "byplayer" or "" ), attacker )
    elseif !self:IsTyping() then
        self:PlayVoiceLine( "death" )
    end

    if GLAMBDA:GetConVar( "building_undoondeath" ) then
        self:UndoCommand( true )
    end

    self.LastDeathTime = CurTime()
    self:SetNoWeaponSwitch( false )
    self:ResetAI()
    self:SetNW2Bool( "glambda_playingtaunt", false )

    GLAMBDA:RunHook( "GLambda_OnPlayerKilled", self, attacker )
end

-- Called when a NPC, Nextbot, or player is killed
function GLAMBDA.Player:OnOtherKilled( victim, dmginfo )
    local enemy = self:GetEnemy()
    if victim == enemy then
        self:SetEnemy( nil )
        self:SetState()
        self:CancelMovement()
    end
    if !self:Alive() or GLAMBDA:RunHook( "GLambda_OnPlayerOtherKilled", self, victim, dmginfo ) == true then return end

    local attacker = dmginfo:GetAttacker()
    if attacker == self:GetPlayer() then
        if victim == enemy then 
            if self:GetSpeechChance( 100 ) and ( !self:IsSpeaking() or GLAMBDA:Random( 3 ) == 1 ) then
                self:PlayVoiceLine( "kill" )
            elseif self:GetTextingChance( 100 ) and self:CanType() then
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
            self:LookTo( attacker, 2, 2 )
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
                self:LookTo( victim:WorldSpaceCenter(), GLAMBDA:Random( 2, 4 ), 2 )

                if self:GetSpeechChance( 100 ) then
                    self:PlayVoiceLine( "witness" )
                elseif self:GetTextingChance( 100 ) and self:CanType() then
                    self:TypeMessage( "witness", victim )
                end
            end
            
            if !self:InCombat() and self:GetCowardnessChance( 200 ) then
                local targ = ( ( self:CanTarget( attacker ) and self:IsVisible( attacker ) and GLAMBDA:Random( 3 ) == 1 ) and attacker or nil )
                self:LookTo( targ or victim:WorldSpaceCenter(), GLAMBDA:Random( 3 ), 2 )
                
                self:RetreatFrom( targ, nil, !self:IsSpeaking( "witness" ) )
                self:CancelMovement()
                
                self:DevMsg( "I saw someone die. Retreating..." )
            end
        end
    end
end

-- Called when the Player gets disconnected/removed from the server
function GLAMBDA.Player:OnDisconnect()
    self:UndoCommand( true )
    
    local spawner = self.Spawner
    if IsValid( spawner ) then
        spawner:SetOwner()
        spawner:Remove()
    end
end

-- Called when the Player thinks it is stuck
function GLAMBDA.Player:OnStuck()
    self:PressKey( IN_JUMP )
    if !self:OnGround() then
        self:PressKey( IN_DUCK )
    end
end

-- Called when the Player isn't stuck anymore
function GLAMBDA.Player:OnUnStuck() end