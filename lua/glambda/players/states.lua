function GLAMBDA.Player:Idle()
    if math.random( 3 ) == 1 then
        self:MoveToPos( self:GetRandomPos() )
        return
    end

    local hundreds = 0
    for _, persData in ipairs( self.Personality ) do
        if persData[ 2 ] != 100 or !isfunction( persData[ 3 ] ) then continue end
        hundreds = ( hundreds + 1 )
    end

    for _, persData in ipairs( self.Personality ) do
        if !isfunction( persData[ 3 ] ) then continue end

        local chance = persData[ 2 ]
        if hundreds != 0 and chance == 100 and math.random( 2 ) == 1 then
            self:DevMsg( persData[ 1 ] .. " one of their hundred percent chances failed" )
            hundreds = ( hundreds - 1 )
            continue
        end

        local rnd = math.random( 100 )
        if rnd <= chance then
            self:DevMsg( persData[ 1 ] .. " chance succeeded in its chance. ( " .. rnd .. " to " .. chance .. " )" )
            persData[ 3 ]( self )
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
    local rndVec = ( self:GetForward() * math.random( 16, 24 ) + self:GetRight() * math.random( -24, 24 ) - vector_up * 8 )
    if !self:Trace( nil, ( self:GetPos() + rndVec ) ).Hit then
        self:MoveToPos( self:GetRandomPos( 100 ) ) 
        if failCheck and failCheck( self ) == true then return true end
    end

    local spawnRate = math.Rand( 0.15, 0.4 )
    coroutine.wait( spawnRate )

    for i = 1, count do
        if failCheck and failCheck( self ) == true then break end

        local lookPos = ( self:GetPos() + rndVec )
        self:LookTo( lookPos, 0.5, spawnRate * 2 )

        self:SpawnEntity( classname )    
        coroutine.wait( spawnRate )
    end

    return true
end

function GLAMBDA.Player:HealUp()
    if self:Health() >= self:GetMaxHealth() then return true end

    local spawnCount = math.ceil( ( self:GetMaxHealth() - self:Health() ) / 25 )
    spawnCount = math.random( ( spawnCount / 2 ), spawnCount )

    return self:SpawnPickup( "item_healthkit", spawnCount, function( self )
        return ( !self:GetState( "HealUp" ) or self:Health() >= self:GetMaxHealth() )
    end )
end

function GLAMBDA.Player:ArmorUp()
    if self:Armor() >= self:GetMaxArmor() then return true end

    local spawnCount = math.ceil( ( self:GetMaxArmor() - self:Armor() ) / 15 )
    spawnCount = math.random( ( spawnCount / 3 ), spawnCount )

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
    
    local spawnCount = math.random( 3, 8 )
    if istable( spawnEnt ) then
        spawnEnt = spawnEnt[ math.random( #spawnEnt ) ]
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
            self:AttackTarget( findTargets[ math.random( #findTargets ) ] )
            return true
        end
    end } )

    return !self:GetCombatChance( 100 )
end

function GLAMBDA.Player:TBaggingPosition( pos )
    self:MoveToPos( pos, { sprint = true, callback = function( self )
        return ( !self:GetState( "TBaggingPosition" ) )
    end } )

    for i = 1, math.random( 4, 10 ) do
        if !self:GetState( "TBaggingPosition" ) then break end
        self:HoldKey( IN_DUCK )
        coroutine.wait( 0.4 )
    end

    return true
end

local acts = { ACT_GMOD_TAUNT_DANCE, ACT_GMOD_TAUNT_ROBOT, ACT_GMOD_TAUNT_MUSCLE, ACT_GMOD_TAUNT_CHEER }
function GLAMBDA.Player:UseActTaunt()
    self:PlayGestureAndWait( acts[ math.random( #acts ) ] )
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
    self:LookTo( target, 0.75, 1 )

    local laughDelay = ( math.random( 6 ) * 0.1 )
    self:PlayVoiceLine( "laugh", laughDelay )

    local movePos = args[ 2 ]
    local actTime = ( laughDelay * math.Rand( 0.75, 1.1 ) )
    if !movePos then
        coroutine.wait( actTime )
    else
        self:MoveToPos( movePos, { sprint = false, cbTime = actTime, callback = function( self ) return true end } )
    end

    if self:GetState( "Laughing" ) then
        if !self:IsSpeaking( "laugh" ) then self:PlayVoiceLine( "laugh", false ) end
        ErrorNoHaltWithStack( self:GetPlayer(), target )
        self:PlayGestureAndWait( ACT_GMOD_TAUNT_LAUGH )
    end
    return true
end

local retreatOptions = { sprint = true, callback = function( self )
    local target = self:GetEnemy()
    if CurTime() >= self.RetreatEndTime or IsValid( target ) and ( target:IsPlayer() and !target:Alive() or self:SqrRangeTo( target ) > ( 3000 ^ 2 ) ) then
        self:SetSprint( false )
        self.RetreatEndTime = 0
    end
end }
function GLAMBDA.Player:Retreat( pos )
    if CurTime() >= self.RetreatEndTime then return true end
    local rndPos = self:GetRandomPos( 2500 )
    self:MoveToPos( rndPos, retreatOptions )
end

function GLAMBDA.Player:SpawnSomething()
    self:LookTo( self:GetPos() + self:GetForward() * math.random( -500, 500 ) + self:GetRight() * math.random( -500, 500 ) - self:GetUp() * math.random( 0, 100 ), 0.5, 1 )
    coroutine.wait( math.random( 3, 10 ) * 0.1 )

    if self:GetState( "SpawnSomething" ) then
        local rndSpawn = math.random( 2 )
        if rndSpawn == 1 then
            local _, rndNPC = table.Random( list.Get( "NPC" ) )
            self:SpawnNPC( rndNPC )
        elseif rndSpawn == 2 then
            local _, rndENT = table.Random( list.Get( "SpawnableEntities" ) )
            self:SpawnEntity( rndENT )
        end
    end

    return true
end