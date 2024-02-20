GLAMBDA.WeaponList = {
    -- Half-Life 2 --
    weapon_crowbar = {
        Name = "Crowbar",
        IsMeleeWeapon = true
    },
    weapon_stunstick = {
        Name = "Stunstick",
        IsMeleeWeapon = true
    },
    weapon_pistol = {
        Name = "9mm Pistol",
        AttackDelay = { 0.1, 0.25 },
        AmmoEntity = "item_ammo_pistol"
    },
    weapon_357 = {
        Name = ".357 Magnum",
        AttackDelay = { 1, 2 },
        AmmoEntity = "item_ammo_357"
    },
    weapon_smg1 = {
        Name = "SMG",
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
        Name = "Shotgun",
        AttackDistance = 700,
        KeepDistance = 450,
        AmmoEntity = "item_box_buckshot",

        SpecialAttack = function( self, weapon, target )
            if math.random( 8 ) != 1 or weapon:Clip1() < 2 or !self:InRange( target, 300 ) then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_ar2 = {
        Name = "Pulse-Rifle",
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
        Name = "Crossbow",
        KeepDistance = 700,
        AttackDelay = { 2, 4 },
        AmmoEntity = "item_ammo_crossbow",

        OverrideAim = function( self, weapon, target )
            return ( target:WorldSpaceCenter() + target:GetVelocity() * 0.1 )
        end,
    },
    weapon_frag = {
        Name = "Frag Grenade",
        AttackDistance = 1000,
        AmmoEntity = "weapon_frag",

        OverrideAim = function( self, weapon, target )
            local targPos = target:GetPos()
            return ( targPos - vector_up * ( self:RangeTo( targPos ) * 0.2 ) )
        end,

        SpecialAttack = function( self, weapon, target )
            if !self:InRange( target, 350 ) or math.random( 4 ) == 1 then return end
            self:PressKey( IN_ATTACK2 )
            return true
        end
    },
    weapon_rpg = {
        Name = "RPG Launcher",
        KeepDistance = 600,
        AmmoEntity = "item_rpg_round",

        OverrideAim = function( self, weapon, target )
            return target:GetPos()
        end,
    },
    
    -- Garry's Mod --
    weapon_physgun = {
        Name = "Physgun",
        IsLethalWeapon = false
    },
    gmod_tool = {
        Name = "Tool Gun",
        IsLethalWeapon = false
    },
    weapon_fists = {
        Name = "Fists",
        IsMeleeWeapon = true,

        SpecialAttack = function( self, weapon, target )
            if math.random( 2 ) == 1 then self:PressKey( IN_ATTACK2 ) return true end
        end
    },
    weapon_medkit = {
        Name = "Medkit",
        KeepDistance = 40,
        AttackDistance = 64,
        IsLethalWeapon = false,
        
        OnThink = function( self, wepent )
            if self:Health() < self:GetMaxHealth() then
                self:PressKey( IN_ATTACK2 )
            end

            if self:GetState( "Idle" ) and !self:GetCombatChance( 100 ) and math.random( 2 ) == 1 then
                local healEnts = self:FindInSphere( nil, 1000, function( ent )
                    return ( self:CanTarget( ent ) and ent:Health() < ent:GetMaxHealth() )
                end )
                if #healEnts != 0 then
                    self:SetState( "HealWithMedkit", healEnts[ math.random( #healEnts ) ] )
                    self:CancelMovement()
                end
            end

            return 1
        end
    },
    gmod_camera = {
        Name = "Camera",
        KeepDistance = 400,
        AttackDistance = 500,
        IsLethalWeapon = false,
        
        OnThink = function( self, wepent )
            if self:GetState( "Idle" ) and math.random( 8 ) == 1 then
                self:LookTo( self:EyePos() + VectorRand( -500, 500 ), 0.33, 1.5, 3 )

                self:SimpleTimer( math.Rand( 0.33, 1.0 ), function()
                    if self:GetActiveWeapon() != wepent then return end
                    self:PressKey( IN_ATTACK )
                end )
            end

            return 1
        end
    },
    weapon_flechettegun = {
        Name = "Flechette Gun",
        AttackDistance = 1000,
        Automatic = true,
        MountsRequired = { "ep2" },

        OverrideAim = function( self, weapon, target )
            return ( target:WorldSpaceCenter() + target:GetVelocity() * 0.1 )
        end
    }
}

function GLAMBDA:AddWeapon( wepName, wepData )
    if ( CLIENT ) then return end
    wepData = ( wepData or {} )

    net.Start( "glambda_syncweapons" )
        net.WriteString( wepName )
        net.WriteString( wepData.Name or "#" .. wepName )
    net.Broadcast()

    if istable( wepName ) then
        table.Merge( GLAMBDA.WeaponList, wepName )
        return
    end

    GLAMBDA.WeaponList[ wepName ] = wepData
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
            if math.random( 8 ) != 1 or weapon:Clip1() < 2 or !self:InRange( target, 400 ) then return end
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