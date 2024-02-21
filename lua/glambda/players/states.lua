function GLAMBDA.Player:Idle()
    if GLAMBDA:Random( 3 ) == 1 then
        self:MoveToPos( self:GetRandomPos() )
        return
    end

    local hundreds = 0
    local personaTbl = self.Personality[ 2 ]

    for _, persData in pairs( personaTbl ) do
        if persData[ 1 ] != 100 or !persData[ 2 ] then continue end
        hundreds = ( hundreds + 1 )
    end

    for _, persData in ipairs( personaTbl ) do
        if !persData[ 2 ] then continue end

        local chance = persData[ 1 ]
        if hundreds != 0 and chance == 100 and GLAMBDA:Random( 2 ) == 1 then
            self:DevMsg( persData[ "__key" ] .. " one of their hundred percent chances failed" )
            hundreds = ( hundreds - 1 )
            continue
        end

        local rnd = GLAMBDA:Random( 100 )
        if rnd <= chance then
            self:DevMsg( persData[ "__key" ] .. " chance succeeded in its chance. ( " .. rnd .. " to " .. chance .. " )" )
            persData[ 2 ]( self )
            return
        end
    end
end

function GLAMBDA.Player:Combat()
    if !IsValid( self:GetEnemy() ) then return true end
    if !self:GetWeaponStat( "IsLethalWeapon", true ) then self:SelectLethalWeapon() end

    local isMelee = self:GetWeaponStat( "IsMeleeWeapon" )
    self:MoveToPos( self:GetEnemy(), { sprint = true, updatetime = ( isMelee and 0.1 or 0.33 ) } )
end

--

function GLAMBDA.Player:SpawnPickup( classname, count, failCheck )
    local rndVec = ( self:GetForward() * GLAMBDA:Random( 15, 20 ) + self:GetRight() * GLAMBDA:Random( -15, 20 ) - vector_up * 8 )
    if !self:Trace( nil, ( self:GetPos() + rndVec ) ).Hit then
        self:MoveToPos( self:GetRandomPos( 100 ) ) 
        if failCheck and failCheck( self ) == true then return true end
    end

    local spawnRate = GLAMBDA:Random( 0.15, 0.4, true )
    coroutine.wait( spawnRate )

    for i = 1, count do
        if failCheck and failCheck( self ) == true then break end

        local lookPos = ( self:GetPos() + rndVec )
        self:LookTo( lookPos, 0.5, spawnRate * 2, 1 )

        self:SpawnEntity( classname )    
        coroutine.wait( spawnRate )
    end

    return true
end

function GLAMBDA.Player:HealUp()
    if self:Health() >= self:GetMaxHealth() then return true end

    local spawnCount = math.ceil( ( self:GetMaxHealth() - self:Health() ) / 25 )
    spawnCount = GLAMBDA:Random( ( spawnCount / 2 ), spawnCount )

    return self:SpawnPickup( "item_healthkit", spawnCount, function( self )
        return ( !self:GetState( "HealUp" ) or self:Health() >= self:GetMaxHealth() )
    end )
end

function GLAMBDA.Player:ArmorUp()
    if self:Armor() >= self:GetMaxArmor() then return true end

    local spawnCount = math.ceil( ( self:GetMaxArmor() - self:Armor() ) / 15 )
    spawnCount = GLAMBDA:Random( ( spawnCount / 3 ), spawnCount )

    return self:SpawnPickup( "item_battery", spawnCount, function( self )
        return ( !self:GetState( "ArmorUp" ) or self:Armor() >= self:GetMaxArmor() )
    end )
end

function GLAMBDA.Player:GiveSelfAmmo()
    local spawnEnt = self:GetWeaponStat( "AmmoEntity" )
    if !spawnEnt then return true end

    local ammoCount, ammoType = self:GetWeaponAmmo()
    local maxAmmo = game.GetAmmoMax( ammoType )
    if ammoCount >= maxAmmo then return true end
    
    local spawnCount = GLAMBDA:Random( 3, 8 )
    if istable( spawnEnt ) then
        spawnEnt = spawnEnt[ GLAMBDA:Random( #spawnEnt ) ]
    end

    return self:SpawnPickup( spawnEnt, spawnCount, function( self )
        if !self:GetState( "GiveSelfAmmo" ) then return true end
        local ammoCount, curType = self:GetWeaponAmmo()
        return ( !curType or curType != ammoType or ammoCount >= maxAmmo )
    end )
end

--

function GLAMBDA.Player:FindTarget()
    self:MoveToPos( self:GetRandomPos(), { cbTime = 1, callback = function( self )
        if self:InCombat() or !self:GetState( "FindTarget" ) then return true end

        local findTargets = self:FindInSphere( nil, 1500, function( ent )
            return ( self:CanTarget( ent ) and self:IsVisible( ent ) )
        end )
        if #findTargets != 0 then
            self:AttackTarget( findTargets[ GLAMBDA:Random( #findTargets ) ] )
            return true
        end
    end } )

    return !self:GetCombatChance( 100 )
end

function GLAMBDA.Player:TBaggingPosition( pos )
    self:MoveToPos( pos, { sprint = true, callback = function( self )
        return ( !self:GetState( "TBaggingPosition" ) )
    end } )

    for i = 1, GLAMBDA:Random( 4, 10 ) do
        if !self:GetState( "TBaggingPosition" ) then break end
        self:HoldKey( IN_DUCK )
        coroutine.wait( 0.4 )
    end

    return true
end

local acts = { ACT_GMOD_TAUNT_DANCE, ACT_GMOD_TAUNT_ROBOT, ACT_GMOD_TAUNT_MUSCLE, ACT_GMOD_TAUNT_CHEER }
function GLAMBDA.Player:UseActTaunt()
    self:PlayGestureAndWait( acts[ GLAMBDA:Random( #acts ) ] )
    return true
end

function GLAMBDA.Player:Laughing( args )
    if !args or !istable( args ) then return true end

    local target = args[ 1 ]
    if isentity( target ) and !IsValid( target ) then return true end

    if target:IsPlayer() then
        local ragdoll = target:GetRagdollEntity()
        if IsValid( ragdoll ) then target = ragdoll end
    end
    self:LookTo( target, 0.75, 1, 4 )

    local laughDelay = ( GLAMBDA:Random( 2, 8 ) * 0.1 )
    if self:GetSpeechChance( 25 ) then
        self:PlayVoiceLine( "laugh", laughDelay )
    end

    local movePos = args[ 2 ]
    local actTime = ( laughDelay * GLAMBDA:Random( 0.75, 1.1, true ) )
    if !movePos then
        coroutine.wait( actTime )
    else
        self:MoveToPos( movePos, { sprint = false, cbTime = actTime, callback = function( self ) return true end } )
    end

    if self:GetState( "Laughing" ) then
        if !self:IsSpeaking( "laugh" ) and self:GetSpeechChance( 25 ) then 
            self:PlayVoiceLine( "laugh", false ) 
        end

        self:PlayGestureAndWait( ACT_GMOD_TAUNT_LAUGH )
    end
    return true
end

local retreatOptions = { sprint = true, callback = function( self )
    local target = self:GetEnemy()
    if CurTime() >= self.RetreatEndTime or IsValid( target ) and ( target:IsPlayer() and !target:Alive() or !self:InRange( target, 3000 ) ) then
        self:SetSprint( false )
        self.RetreatEndTime = 0
    end
end }
function GLAMBDA.Player:Retreat( pos )
    if CurTime() >= self.RetreatEndTime then return true end
    local rndPos = self:GetRandomPos( 2500 )
    self:MoveToPos( rndPos, retreatOptions )
end

function GLAMBDA.Player:HealWithMedkit( ent )
    if !IsValid( ent ) or !self:CanTarget( ent ) or ent:Health() >= ent:GetMaxHealth() or self:GetCurrentWeapon() != "weapon_medkit" then
        return true
    end

    if self:InRange( ent, 70 ) then
        self:LookTo( ent, 1, 1, 3 )
        self:PressKey( IN_ATTACK )
    else
        local path, cancelled = self:MoveToPos( ent, { sprint = !self:InRange( ent, 300 ), updatetime = 0.25, tol = 48, callback = function()
            if !IsValid( ent ) or !self:CanTarget( ent ) or ent:Health() >= ent:GetMaxHealth() or self:GetCurrentWeapon() != "weapon_medkit" then return true end
            if self:InRange( ent, 70 ) then return false end
        end } )
        if cancelled == true then return true end
    end
end