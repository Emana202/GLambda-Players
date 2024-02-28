local IsValid = IsValid
local CurTime = CurTime
local RandomPairs = RandomPairs
local game_GetAmmoMax = game.GetAmmoMax
local string_match = string.match

-- Makes us select the given weapon by its classname
function GLAMBDA.Player:SelectWeapon( weapon )
    if self:GetNoWeaponSwitch() then return end

    local curWep = self:GetActiveWeapon()
    if IsValid( curWep ) and curWep:GetClass() == weapon then return end

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
    local curWep = self:GetActiveWeapon()
    curWep = ( IsValid( curWep ) and curWep:GetClass() or nil )

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

--

-- Returns if the given weapon is allowed
function GLAMBDA.Player:IsWeaponAllowed( wepClass )
    local permitTbl = GLAMBDA.WeaponPermissions[ wepClass ]
    return ( !permitTbl or permitTbl == true )
end

-- Returns the classname of our current weapon
function GLAMBDA.Player:GetCurrentWeapon()
    local curWep = self:GetActiveWeapon()
    return ( IsValid( curWep ) and curWep:GetClass() or "" )
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