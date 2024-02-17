function GLAMBDA.Player:SwitchToWeapon( weapon )
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

    self:SelectWeapon( wepEnt )

    self.NextWeaponThinkT = 0

    return true
end

function GLAMBDA.Player:SelectRandomWeapon( filter )
    local curWep = self:GetActiveWeapon()
    curWep = ( IsValid( curWep ) and curWep:GetClass() or nil )

    for name, data in RandomPairs( GLAMBDA.WeaponList ) do
        if filter and filter( name, data, curWep ) == false then continue end

        local mountsNeed = data.MountsRequired
        if mountsNeed then
            local hasMounts = true
            for _, mount in ipairs( mountsNeed ) do
                hasMounts = IsMounted( mount )
                if !hasMounts then break end
            end
            if !hasMounts then continue end
        end

        if !self:SwitchToWeapon( name ) then continue end
        return true
    end

    return false
end

function GLAMBDA.Player:SelectLethalWeapon()
    return self:SelectRandomWeapon( function( name, data )
        local isLethal = data.IsLethalWeapon
        return ( isLethal == nil and true or isLethal )
    end )
end

function GLAMBDA.Player:GetWeaponAmmo()
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) then return -1 end

    local ammoType = curWep:GetPrimaryAmmoType()
    return self:GetAmmoCount( ammoType ), ammoType
end

function GLAMBDA.Player:GetWeaponMaxAmmo()
    local _, ammoType = self:GetWeaponAmmo()
    return ( !ammoType and -1 or game.GetAmmoMax( ammoType ) )
end

--

local fallbackDefaults = {
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
    end
}

function GLAMBDA.Player:GetWeaponStat( name, fallback )
    local stat
    local curWep = self:GetActiveWeapon()
    if IsValid( curWep ) then
        stat = GLAMBDA.WeaponList[ curWep:GetClass() ]
        if stat then stat = stat[ name ] end
    end

    if stat == nil then
        local defFunc = fallbackDefaults[ name ]
        if defFunc then stat = defFunc( curWep )  end
        if !stat then stat = fallback end
    end
    return stat
end