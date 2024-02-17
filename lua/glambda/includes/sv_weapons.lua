GLAMBDA.WeaponList = {
    -- Half-Life 2 --
    weapon_crowbar = {
        IsMeleeWeapon = true
    },
    weapon_stunstick = {
        IsMeleeWeapon = true
    },
    weapon_pistol = {
        AttackDelay = { 0.1, 0.33 },
        AmmoEntity = "item_ammo_pistol"
    },
    weapon_357 = {
        AttackDelay = { 1.5, 2 },
        AmmoEntity = "item_ammo_357"
    },
    weapon_smg1 = {
        Automatic = true,
        AmmoEntity = "item_ammo_smg1",
        AltFireAmmo = "item_ammo_smg1_grenade",

        SpecialAttack = function( self, weapon, target )
            if math.random( 150 ) != 1 or weapon:Clip2() == 0 then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_shotgun = {
        AttackDistance = 700,
        KeepDistance = 450,
        AmmoEntity = "item_box_buckshot",

        SpecialAttack = function( self, weapon, target )
            if math.random( 8 ) != 1 or weapon:Clip1() < 2 or self:SqrRangeTo( target ) > ( 300 ^ 2 ) then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_ar2 = {
        Automatic = true,
        AmmoEntity = "item_ammo_ar2",
        AltFireAmmo = "item_ammo_ar2_altfire",

        SpecialAttack = function( self, weapon, target )
            if math.random( 150 ) != 1 or weapon:Clip2() == 0 then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_crossbow = {
        KeepDistance = 700,
        AttackDelay = { 2, 4 },
        AmmoEntity = "item_ammo_crossbow"
    },
    weapon_frag = {
        AttackDistance = 700,
        AmmoEntity = "weapon_frag",

        OverrideAim = function( self, weapon, target )
            local targPos = target:GetPos()
            return ( targPos - vector_up * ( self:RangeTo( targPos ) * 0.25 ) )
        end,

        SpecialAttack = function( self, weapon, target )
            if self:SqrRangeTo( target ) > ( 350 ^ 2 ) then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_rpg = {
        KeepDistance = 600,
        AmmoEntity = "item_rpg_round"
    },
    
    -- Garry's Mod --
    weapon_physgun = {
        IsLethalWeapon = false
    },
    gmod_tool = {
        IsLethalWeapon = false
    },
    weapon_fists = {
        IsMeleeWeapon = true
    },
    weapon_medkit = {
        KeepDistance = 40,
        AttackDistance = 64,
        IsLethalWeapon = false,

        OnThink = function( self, wepent )
            if self:Health() < self:GetMaxHealth() then
                self:PressKey( IN_ATTACK2 )
            end
        end
    },
    gmod_camera = {
        KeepDistance = 400,
        AttackDistance = 500,
        IsLethalWeapon = false
    },
    weapon_flechettegun = {
        AttackDistance = 1000,
        Automatic = true,
        MountsRequired = { "ep2" }
    }
}

function GLAMBDA:AddWeapon( wepName, wepData )
    if istable( wepName ) then
        table.Merge( GLAMBDA.WeaponList, wepName )
        return
    end
    GLAMBDA.WeaponList[ wepName ] = ( wepData or {} )
end

-- Test --
--[[
GLAMBDA:AddWeapon( {
    weapon_hl1_crowbar = {
        IsMeleeWeapon = true
    },
    weapon_hl1_glock = {
        AttackDelay = { 0.2, 0.33 },
        AmmoEntity = { "hl1_ammo_9mmclip", "hl1_ammo_9mmar", "hl1_ammo_9mmbox" }
    },
    weapon_hl1_357 = {
        AttackDelay = { 1.5, 2 },
        AmmoEntity = "hl1_ammo_357"
    },
    weapon_hl1_mp5 = {
        Automatic = true,
        AmmoEntity = { "hl1_ammo_9mmclip", "hl1_ammo_9mmar", "hl1_ammo_9mmbox" },
        AltFireAmmo = "hl1_ammo_argrenades",

        SpecialAttack = function( self, weapon, target )
            if math.random( 150 ) != 1 or weapon:Clip2() == 0 then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_hl1_shotgun = {
        AttackDistance = 700,
        KeepDistance = 450,
        AmmoEntity = "hl1_ammo_buckshot",

        SpecialAttack = function( self, weapon, target )
            if math.random( 8 ) != 1 or weapon:Clip1() < 2 or self:SqrRangeTo( target ) > ( 300 ^ 2 ) then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    }
} )
GLAMBDA:AddWeapon( "rust_eoka", {
    Automatic = true,
    AttackDistance = 500,
    KeepDistance = 300,
    NoSprintAttack = true
} )
GLAMBDA:AddWeapon( "tfa_cs_knife", {
    IsMeleeWeapon = true,

    SpecialAttack = function( self, weapon, target )
        if math.random( 4 ) != 1 then return end
        self:PressKey( IN_ATTACK2 )
        return true
    end
} )
GLAMBDA:AddWeapon( "tfusion_combustible_lemon", {
    AttackDistance = 600,

    SpecialAttack = function( self, weapon, target )
        if math.random( 2 ) != 1 then return end
        self:PressKey( IN_ATTACK2 )
        return true
    end
} )
]]