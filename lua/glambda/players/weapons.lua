local IsValid = IsValid
local CurTime = CurTime
local RandomPairs = RandomPairs
local game_GetAmmoMax = game.GetAmmoMax
local string_match = string.match
local table_Count = table.Count

-- Makes us select the given weapon by its classname
function GLAMBDA.Player:SelectWeapon( weapon )
    if self:GetNoWeaponSwitch() then return false end
    if GLAMBDA:RunHook( "GLambda_OnPlayerCanSelectWeapon", self, weapon ) == true then return false end
    if self:GetCurrentWeapon( weapon ) then return false end

    local wepEnt = self:GetWeapon( weapon )
    if !IsValid( wepEnt ) then
        wepEnt = self:Give( weapon )
        if !IsValid( wepEnt ) then return false end

        -- local ammoType = wepEnt:GetPrimaryAmmoType()
        -- if ammoType > 0 and self:GetAmmoCount( ammoType ) <= wepEnt:GetMaxClip1() + 1 then
        --     self:GiveAmmo( wepEnt:GetMaxClip1() * 3, ammoType )
        -- end

        if wepEnt.IsTFAWeapon then
            wepEnt:RandomizeAttachments()
        elseif wepEnt.ARC9 then
            wepEnt:QueueForRandomize()
        end
    end

    self.CmdSelectWeapon = wepEnt
    return true
end

-- Makes us select a random weapon
function GLAMBDA.Player:SelectRandomWeapon( filter )
    local curWep = self:GetCurrentWeapon()
    local favWpn = self.FavoriteWeapon

    if favWpn then 
        local wpnData = GLAMBDA.WeaponList[ favWpn ]
        if wpnData and self:IsWeaponAllowed( favWpn ) and ( !filter or filter( favWpn, wpnData, curWep ) ) then
            local wpnCount = table_Count( GLAMBDA.WeaponList )
            if GLAMBDA:Random( wpnCount * 2 ) >= wpnCount and self:SelectWeapon( favWpn ) then return true end
        end
    end

    for name, data in RandomPairs( GLAMBDA.WeaponList ) do
        if !self:IsWeaponAllowed( name ) then continue end
        if filter and filter( name, data, curWep ) == false then continue end
        if !self:SelectWeapon( name ) then continue end
        return true
    end

    return false
end

-- Makes us select a random lethal weapon
function GLAMBDA.Player:SelectLethalWeapon()
    return self:SelectRandomWeapon( function( name, data )
        local isLethal = data.IsLethalWeapon
        return ( isLethal == nil and true or isLethal )
    end )
end

-- Makes us select our spawn weapon
function GLAMBDA.Player:SelectSpawnWeapon()
    local spawnWep = self.ForceWeapon
    if !GLAMBDA:GetConVar( "combat_keepforcewep" ) then
        spawnWep = GLAMBDA:GetConVar( "combat_forcespawnwpn" )
    end
    if !spawnWep or #spawnWep == 0 then
        spawnWep = ( self.SpawnWeapon or "weapon_physgun" )
    end

    if spawnWep == "random" then return self:SelectRandomWeapon() end
    return self:SelectWeapon( spawnWep )
end

--

-- Returns if the given weapon is allowed
function GLAMBDA.Player:IsWeaponAllowed( wepClass )
    local permitTbl = GLAMBDA.WeaponPermissions[ wepClass ]
    return ( permitTbl == nil or permitTbl == true )
end

-- Returns the classname of our current weapon
-- If 'class' is specified, returns if the current weapon is the one instead
function GLAMBDA.Player:GetCurrentWeapon( class )
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) then return end

    local wepClass = curWep:GetClass()
    if !class then return wepClass end

    return ( class == wepClass )
end

-- Returns the amount of ammo in our weapon's clip
-- If secondary is true, returns the secondary ammo clip instead, like AR2 balls and SMG grenades
function GLAMBDA.Player:GetWeaponClip( secondary )
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) then return -1 end
    return ( secondary and curWep:Clip2() or curWep:Clip1() )
end

-- Returns the amount of current ammo in our weapon, excluding the clip
function GLAMBDA.Player:GetWeaponAmmo()
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) then return -1 end

    local ammoType = curWep:GetPrimaryAmmoType()
    return self:GetAmmoCount( ammoType ), ammoType
end

-- Returns the max amount of ammo our weapon can have
function GLAMBDA.Player:GetWeaponMaxAmmo()
    local _, ammoType = self:GetWeaponAmmo()
    return ( !ammoType and -1 or game_GetAmmoMax( ammoType ) )
end

-- Returns if we are currently reloading our weapon
function GLAMBDA.Player:IsReloadingWeapon()
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) then return false end

    if curWep.ARC9 then return curWep:GetReloading() end
    return string_match( curWep:GetSequenceActivityName( curWep:GetSequence() ), "RELOAD" )
end

--

local fallbackDefaults = {
    IsMeleeWeapon = function( weapon )
        if weapon.IsTFAWeapon then return weapon.IsMelee end
    end,
    Automatic = function( weapon )
        if weapon.IsTFAWeapon then
            return ( weapon.Primary.Automatic == true  )
        elseif weapon.ARC9 then
            return ( weapon:GetCurrentFiremode() == -1 )
        end
    end,
    AttackDelay = function( weapon )
        if weapon.IsTFAWeapon and !weapon.Primary.Automatic or weapon.ARC9 and weapon:GetCurrentFiremode() != -1 then
            return { 0.2, 0.3 }
        end
    end,
    NoSprintAttack = function( weapon )
        return ( weapon.IsTFAWeapon or weapon.ARC9 and !weapon:GetProcessedValue( "ShootWhileSprint", true ) )
    end,
    AttackDistance = function( weapon )
        if weapon.ARC9 then
            local range = ( ( weapon.RangeMin + weapon.RangeMax ) * 0.5 )
            return range
        end
        if weapon.RangeFalloffLUT then
            return ( weapon.RangeFalloffLUT.lut.range * 0.2 )
        end
    end,
    KeepDistance = function( weapon )
        if weapon.ARC9 then
            local range = ( ( ( weapon.RangeMin + weapon.RangeMax ) * 0.5 ) * 0.5 )
            return range
        end
        if weapon.RangeFalloffLUT then
            return ( ( weapon.RangeFalloffLUT.lut.range * 0.2 ) * 0.5 )
        end
    end
}

-- Returns the given stat of our current weapon
function GLAMBDA.Player:GetWeaponStat( name, fallback )
    local stat
    local curWep = self:GetActiveWeapon()
    if IsValid( curWep ) then
        stat = GLAMBDA.WeaponList[ curWep:GetClass() ]
        if stat then stat = stat[ name ] end
    end

    if stat == nil then
        local defFunc = fallbackDefaults[ name ]
        if defFunc then stat = defFunc( curWep ) end
        if !stat then stat = fallback end
    end
    return stat
end