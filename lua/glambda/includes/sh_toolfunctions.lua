local string_lower = string.lower
local string_match = string.match
local IsValid = IsValid
local VectorRand = VectorRand
local coroutine_wait = coroutine.wait
local util_IsValidPhysicsObject = util.IsValidPhysicsObject
local table_Random = table.Random
local list_Get = list.Get
local util_Decal = util.Decal
local undo_Create = SERVER and undo.Create
local undo_AddEntity = SERVER and undo.AddEntity
local constraint_Rope = SERVER and constraint.Rope
local constraint_Weld = SERVER and constraint.Weld
local undo_SetPlayer = SERVER and undo.SetPlayer
local undo_Finish = SERVER and undo.Finish
local ColorRand = ColorRand
local constraint_RemoveAll = SERVER and constraint.RemoveAll
local construct_SetPhysProp = SERVER and construct.SetPhysProp
local timer_Simple = timer.Simple
local EffectData = EffectData
local util_Effect = util.Effect
local util_SpriteTrail = SERVER and util.SpriteTrail

local transformTbl = {}

local function DefFilter( ent )
    return ( !ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
end

GLAMBDA.ToolgunTools = ( GLAMBDA.ToolgunTools or {} )

--

function GLAMBDA:AddToolgunTool( name, func, contextMenu )
    local cvar = self:CreateConVar( "tools_allow_" .. string_lower( name ), true, 'If the players are allowed to use the "' .. name .. '" ' .. ( contextMenu and "function from context menu." or "toolgun tool." ), {
        name = "Allow " .. name .. ( contextMenu and " Context Menu Function" or " Tool" ),
        category = "Tools"
    } )
    GLAMBDA.ToolgunTools[ name ] = { cvar, func, contextMenu }
end

--

GLAMBDA:AddToolgunTool( "Balloon", function( self )
    if !self:CheckLimit( "balloons" ) then return end

    local targetEnt = ( GLAMBDA:Random( 2 ) == 1 )
    if targetEnt then targetEnt = self:FindToolTarget( DefFilter ) end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    
    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() then
        local attachRope = ( GLAMBDA:Random( 3 ) != 1 )
        if !attachRope or util_IsValidPhysicsObject( hitEnt, trace.PhysicsBone ) then
            local hitPos = trace.HitPos
            local rndBallon = table_Random( list_Get( "BalloonModels" ) )

            local clrR = GLAMBDA:Random( 0, 255 )
            local clrG = GLAMBDA:Random( 0, 255 )
            local clrB = GLAMBDA:Random( 0, 255 )
            local force = ( GLAMBDA:Random( 5, 100 ) * 10 )

            local balloon = MakeBalloon( self:GetPlayer(), clrR, clrG, clrB, force, {
                Pos = hitPos,
                Model = rndBallon.model,
                Skin = rndBallon.skin
            } )
            if IsValid( balloon ) then
                local ballPos = balloon:GetPos()
                local nearPos = balloon:NearestPoint( ballPos - ( trace.HitNormal * 512 ) )
                local offset = ( ballPos - nearPos )
                
                local newPos = ( hitPos + offset )
                balloon:SetPos( newPos )

                undo_Create( "Balloon" )
                    undo_AddEntity( balloon )

                    if attachRope then
                        local physBone = trace.PhysicsBone
                        local ropeStart = balloon:WorldToLocal( newPos )
                        local ropeEnd = hitEnt:WorldToLocal( hitPos )
                        if IsValid( hitEnt ) then
                            local phys = hitEnt:GetPhysicsObjectNum( physBone )
                            if IsValid( phys ) then ropeEnd = phys:WorldToLocal( hitPos ) end
                        end

                        local ropeLength = GLAMBDA:Random( 25, 500 )
                        local constr, rope = constraint_Rope( balloon, hitEnt, 0, physBone, ropeStart, ropeEnd, 0, ropeLength, 0, 0.5, "cable/rope" )
                        if IsValid( constr ) then
                            undo_AddEntity( constr )
                            self:AddCleanup( "balloons", constr )
                        end
                        if IsValid( rope ) then
                            undo_AddEntity( rope )
                            self:AddCleanup( "balloons", rope )
                        end
                    end

                    undo_SetPlayer( self:GetPlayer() )
                undo_Finish()

                self:EmitToolgunFire( trace )
                coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
            end
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Colour", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --
    
    local trace = self:GetToolTrace()
    local traceEnt = trace.Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() then 
        if IsValid( traceEnt.AttachedEntity ) then traceEnt = traceEnt.AttachedEntity end
        traceEnt:SetColor( ColorRand( false ) ) 
        
        self:EmitToolgunFire( trace )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    end

    --

    return true
end )

local function OnDynamiteExplode( self, delay, ply )
    local shouldRemove = self:GetShouldRemove()
    delay = ( delay or self:GetDelay() )

    if delay == 0 then
        self:GLambdaExplode( 0, ply )
        if shouldRemove then return end
    end
    self:GLambdaExplode( self.BlowDelay, ply )
end
GLAMBDA:AddToolgunTool( "Dynamite", function( self )
    if !self:CheckLimit( "dynamite" ) then return true end

    self:LookTo( ( self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() then
        local _, model = table_Random( list_Get( "DynamiteModels" ) )
        local damage = GLAMBDA:Random( 0, 500 )
        local remove = ( GLAMBDA:Random( 3 ) != 1 )
        local delay = GLAMBDA:Random( 1, 10 )

        local hitPos = trace.HitPos
        local dynamite = MakeDynamite( self:GetPlayer(), hitPos, angle_zero, 52, damage, model, remove, delay )
        if IsValid( dynamite ) then
            local curPos = dynamite:GetPos()
            local offset = ( curPos - dynamite:NearestPoint( curPos - ( trace.HitNormal * 512 ) ) )
            
            dynamite.GLambdaExplode = dynamite.Explode
            dynamite.Explode = OnDynamiteExplode
            dynamite.BlowDelay = delay

            dynamite:Explode( nil, self:GetPlayer() )
            dynamite:SetPos( hitPos + offset )
        
            undo_Create( "Dynamite" )
                undo_AddEntity( dynamite )
                undo_SetPlayer( self:GetPlayer() )
            undo_Finish()
            
            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Remover", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local traceEnt = trace.Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() then
        constraint_RemoveAll( traceEnt )
        timer_Simple( 1, function() if IsValid( traceEnt ) then traceEnt:Remove() end end )

        traceEnt:SetNotSolid( true )
        traceEnt:SetMoveType( MOVETYPE_NONE )
        traceEnt:SetNoDraw( true )

        local effectData = EffectData()
        effectData:SetOrigin( traceEnt:GetPos() )
        effectData:SetEntity( traceEnt )
        util_Effect( "entity_remove", effectData, true, true )
        
        self:EmitToolgunFire( trace )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    end

    --

    return true
end )

local ropeMaterials = { "cable/redlaser", "cable/cable2", "cable/rope", "cable/blue_elec", "cable/xbeam", "cable/physbeam", "cable/hydra" }
GLAMBDA:AddToolgunTool( "Rope", function( self )
    local firstTarg = ( GLAMBDA:Random( 3 ) != 1 )
    if firstTarg then firstTarg = self:FindToolTarget( DefFilter ) end

    self:LookTo( ( firstTarg or VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local firstTr = self:GetToolTrace()
    local firstEnt = firstTr.Entity
    if !IsValid( firstEnt ) or !firstEnt:IsPlayer() then
        self:EmitToolgunFire( firstTr )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

        local secondTarg = ( GLAMBDA:Random( 3 ) != 1 )
        if secondTarg then 
            secondTarg = self:FindToolTarget( function( ent )
                return ( ent != firstTarg and DefFilter( ent ) )
            end )
        end
    
        self:LookTo( ( secondTarg or VectorRand( -500, 500 ) ), 2, 4, 0.66 )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

        --

        local secTr = self:GetToolTrace()
        local secEnt = secTr.Entity
        if !IsValid( secEnt ) or !secEnt:IsPlayer() then
            local addLength = GLAMBDA:Random( 0, 500 )
            local forceLimit = GLAMBDA:Random( 0, 1000 )
            local width = GLAMBDA:Random( 0.5, 10, true )
            local material = ropeMaterials[ GLAMBDA:Random( #ropeMaterials ) ]
            local rigid = ( GLAMBDA:Random( 2 ) == 1 )
            local color = ColorRand( false )

            local constr, rope = constraint_Rope( firstEnt, secEnt, firstTr.PhysicsBone, secTr.PhysicsBone, firstTr.HitPos, secTr.HitPos, ( firstTr.HitPos - secTr.HitPos ):Length(), addLength, forceLimit, width, material, rigid, color )
    		if IsValid( constr ) then
                local ply = self:GetPlayer()

                undo_Create( "Rope" )
                    undo_AddEntity( constr )
                    if IsValid( rope ) then undo_AddEntity( rope ) end
                    undo_SetPlayer( ply )
                undo_Finish()
    
                ply:AddCleanup( "ropeconstraints", constr )
                if IsValid( rope ) then ply:AddCleanup( "ropeconstraints", rope ) end
                
                self:EmitToolgunFire( secTr )
                coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
            end
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Trails", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --
    
    local trace = self:GetToolTrace()
    local traceEnt = trace.Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() then 
        if IsValid( traceEnt.SToolTrail ) then
            traceEnt.SToolTrail:Remove()
            traceEnt.SToolTrail = nil
        end

        local material = table_Random( list_Get( "trail_materials" ) )
		local length = GLAMBDA:Random( 0.1, 10, true )
		local endSize = GLAMBDA:Random( 1, 128 )
		local startSize = GLAMBDA:Random( 1, 128 )

        local trail = util_SpriteTrail( traceEnt, 0, ColorRand( true ), false, startSize, endSize, length, 1 / ( ( startSize + endSize ) * 0.5 ), material .. ".vmt" )
        if IsValid( trail ) then
            traceEnt.SToolTrail = trail

            local ply = self:GetPlayer()
            ply:AddCleanup( "trails", trail )

            undo_Create( "Trail" )
                undo_AddEntity( trail )
                undo_SetPlayer( ply )
            undo_Finish()

            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Material", function( self )
    local targetEnt = self:FindToolTarget( DefFilter ) 
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --
    
    local trace = self:GetToolTrace()
    local traceEnt = trace.Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() then 
        if IsValid( traceEnt.AttachedEntity ) then traceEnt = traceEnt.AttachedEntity end

        local material = table_Random( list_Get( "OverrideMaterials" ) )
        traceEnt:SetMaterial( material ) 

        self:EmitToolgunFire( trace )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Thruster", function( self )
    if !self:CheckLimit( "thrusters" ) then return true end

    local targetEnt = ( GLAMBDA:Random( 3 ) != 1 )
    if targetEnt then targetEnt = self:FindToolTarget( DefFilter ) end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    local hitBone = trace.PhysicsBone
    if ( !IsValid( hitEnt ) or !hitEnt:IsPlayer() ) and util_IsValidPhysicsObject( hitEnt, hitBone ) then 
        local spawnPos = trace.HitPos
        local spawnAng = trace.HitNormal:Angle()
        spawnAng.p = ( spawnAng.p + 90 )

        local ply = self:GetPlayer()
        local _, rndMdl = table_Random( list_Get( "ThrusterModels" ) )
        local force = GLAMBDA:Random( 10000 )
        local effect = table_Random( list_Get( "ThrusterEffects" ) ).thruster_effect
        local damageable = ( GLAMBDA:Random( 2 ) == 1 )
        local soundname = table_Random( list_Get( "ThrusterSounds" ) ).thruster_soundname
        local collision = ( GLAMBDA:Random( 4 ) == 1 )

        local thruster = MakeThruster( ply, rndMdl, spawnAng, spawnPos, 45, 42, force, true, effect, damageable, soundname )
        if IsValid( thruster ) then
            local min = thruster:OBBMins()
            thruster:SetPos( spawnPos - trace.HitNormal * min.z )
            
            undo_Create( "Thruster" )
                undo_AddEntity( thruster )
        
                if IsValid( hitEnt ) then
                    local weld = constraint_Weld( thruster, hitEnt, 0, hitBone, 0, collision, true )
                    if IsValid( weld ) then
                        ply:AddCleanup( "thrusters", weld )
                        undo_AddEntity( weld )
                    end
        
                    if collision then
                        local phys = thruster:GetPhysicsObject()
                        if IsValid( phys ) then phys:EnableCollisions( false ) end

                        thruster:SetCollisionGroup( COLLISION_GROUP_WORLD )
                        thruster.nocollide = true
                    end
                end

                undo_SetPlayer( ply )
            undo_Finish()

            local onOffTime = ( CurTime() + GLAMBDA:Random( 15 ) )
            self:Timer( "ThrusterRandOnOff_" .. tostring( thruster ), 1, 0, function()
                if !IsValid( thruster ) then return true end
                if CurTime() < onOffTime then return end

                thruster:Switch( GLAMBDA:Random( 2 ) == 1 )
                onOffTime = ( CurTime() + GLAMBDA:Random( 15 ) )
            end )

            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Weld", function( self )
    local targetEnt = self:FindToolTarget( DefFilter )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local firstTr = self:GetToolTrace()
    local firstEnt = firstTr.Entity
    local firstBone = firstTr.PhysicsBone
    if IsValid( firstEnt ) and !firstEnt:IsPlayer() and util_IsValidPhysicsObject( firstEnt, firstBone ) then
        self:EmitToolgunFire( firstTr )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        if !IsValid( firstEnt ) then return true end

        targetEnt = ( GLAMBDA:Random( 4 ) == 1 )
        if targetEnt then 
            targetEnt = self:FindToolTarget( function( ent )
                return ( ent != firstEnt and DefFilter( ent ) )
            end )
        end
    
        self:LookTo( ( targetEnt or VectorRand( -500, 500 ) ), 2, 4, 0.66 )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        if !IsValid( firstEnt ) then return true end

        --

        local secTr = self:GetToolTrace()
        local secEnt = secTr.Entity
        local secBone = secTr.PhysicsBone
        if !IsValid( secEnt ) or !secEnt:IsPlayer() and util_IsValidPhysicsObject( secEnt, secBone ) then
            local forcelimit = GLAMBDA:Random( 0, 1000 )
            local nocollide = ( GLAMBDA:Random( 2 ) == 1 )

            local constr = constraint_Weld( firstEnt, secEnt, firstBone, secBone, forcelimit, nocollide )
            if IsValid( constr ) then
                local ply = self:GetPlayer()

                undo_Create( "Weld" )
                    undo_AddEntity( constr )
                    undo_SetPlayer( ply )
                undo_Finish()
                
                ply:AddCleanup( "constraints", constr )

                self:EmitToolgunFire( secTr )
                coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
            end
        end
    end

    --

    return true 
end )

GLAMBDA:AddToolgunTool( "PhysProp", function( self )
    local targetEnt = self:FindToolTarget( DefFilter )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    local hitBone = trace.PhysicsBone
    if IsValid( hitEnt ) and !hitEnt:IsPlayer() and util_IsValidPhysicsObject( hitEnt, hitBone ) then
        local gravity = ( GLAMBDA:Random( 2 ) == 1 )
        local material = table_Random( list_Get( "PhysicsMaterials" ) ).physprop_material

        construct_SetPhysProp( self:GetPlayer(), hitEnt, hitBone, nil, { GravityToggle = gravity, Material = material } )
        DoPropSpawnedEffect( hitEnt )

        self:EmitToolgunFire( trace )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "FacePoser", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( !ent:IsPlayer() and ent.GetFlexNum and ent:GetFlexNum() != 0 )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local traceEnt = trace.Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() and traceEnt.GetFlexNum then
        for i = 0, ( traceEnt:GetFlexNum() - 1 ) do
            if GLAMBDA:Random( 4 ) == 1 then continue end
            traceEnt:SetFlexWeight( i, ( GLAMBDA:Random() * GLAMBDA:Random( 1, 5, true ) ) )
        end

        self:EmitToolgunFire( trace )
        coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Ignite", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        if ent:IsNPC() or ent:IsNextBot() or ent:IsRagdoll() then return true end
        local class = ent:GetClass()
        return ( class == "item_item_crate" or class == "simple_physics_prop" or string_match( class, "prop_physics*" ) != nil )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    if !IsValid( targetEnt ) then return end

    --

    if targetEnt:IsOnFire() then
        targetEnt:Extinguish() 
    else 
        targetEnt:Ignite( 360 )
    end
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    return true
end, true )

GLAMBDA:AddToolgunTool( "KeepUpright", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( ent:GetClass() == "prop_physics" and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
    if !IsValid( targetEnt ) then return end

    --

    if targetEnt:GetNWBool( "IsUpright" ) then
        constraint.RemoveConstraints( targetEnt, "Keepupright" )
        targetEnt:SetNWBool( "IsUpright", false )
    else
        local const = constraint.Keepupright( targetEnt, targetEnt:GetPhysicsObject():GetAngles(), 0, 999999 )
        if const then targetEnt:SetNWBool( "IsUpright", true ) end
    end

    --

    return true
end, true )

GLAMBDA:AddToolgunTool( "Paint", function( self )
    local targetEnt = ( GLAMBDA:Random( 4 ) == 1 )
    if targetEnt then
        targetEnt = self:FindToolTarget( function( ent )
            return ( !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
        end )
    end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if IsValid( hitEnt ) or hitEnt:IsWorld() then
        local hitBone
        if trace.PhysicsBone and trace.PhysicsBone < hitEnt:GetPhysicsObjectCount() then 
            hitBone = hitEnt:GetPhysicsObjectNum( trace.PhysicsBone )
        end
        if !IsValid( hitBone ) then hitBone = hitEnt:GetPhysicsObject() end
        if !IsValid( hitBone ) then hitBone = hitEnt end

        if IsValid( hitBone ) then
            local pos1 = ( trace.HitPos + trace.HitNormal )
            local pos2 = ( trace.HitPos - trace.HitNormal )            

            local decals = list_Get( "PaintMaterials" )
            util_Decal( decals[ GLAMBDA:Random( #decals ) ], pos1, pos2, self:GetPlayer() )

            self:GetActiveWeapon():EmitSound( "SprayCan.Paint" )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

local ropeOffset = Vector( 0, 0, 6.5 )
GLAMBDA:AddToolgunTool( "Light", function( self )
    if !self:CheckLimit( "lights" ) then return true end

    local targetEnt = ( GLAMBDA:Random( 3 ) == 1 )
    if targetEnt then targetEnt = self:FindToolTarget( DefFilter ) end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local attach = ( GLAMBDA:Random( 3 ) != 1 )

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    local hitBone = trace.PhysicsBone
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() and ( !attach or util_IsValidPhysicsObject( hitEnt, hitBone ) ) then
        local ply = self:GetPlayer()
        local r = GLAMBDA:Random( 0, 255 )
        local g = GLAMBDA:Random( 0, 255 )
        local b = GLAMBDA:Random( 0, 255 )
        local brght = GLAMBDA:Random( 1, 6, true )
        local size = GLAMBDA:Random( 100, 1024 )
        
        local hitPos = trace.HitPos
        transformTbl.Pos = ( hitPos + trace.HitNormal * 8 )

        local ang = trace.HitNormal:Angle()
        ang.p = ( ang.p - 90 )
        transformTbl.Angle = ang

        local light = MakeLight( ply, r, g, b, brght, size, true, true, 37, transformTbl )
        if IsValid( light ) then
            undo_Create( "Light" )
                undo_AddEntity( light )

                if attach then
                    local length = GLAMBDA:Random( 256 )
        
                    local LPos2 = hitEnt:WorldToLocal( hitPos )
                    if IsValid( hitEnt ) then
                        local phys = hitEnt:GetPhysicsObjectNum( hitBone )
                        if IsValid( phys ) then LPos2 = phys:WorldToLocal( hitPos ) end
                    end
        
                    local constr, rope = constraint_Rope( light, hitEnt, 0, hitBone, ropeOffset, LPos2, 0, length, 0, 1, "cable/rope" )
                    if IsValid( constr ) then
                        undo_AddEntity( constr )
                        ply:AddCleanup( "lights", constr )
                    end
                    if IsValid( rope ) then
                        undo_AddEntity( rope )
                        ply:AddCleanup( "lights", rope )
                    end
                end

                undo_SetPlayer( ply )
            undo_Finish()

            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Lamp", function( self )
    if !self:CheckLimit( "lamps" ) then return true end

    self:LookTo( self:GetPos() + VectorRand( -500, 500 ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() then
        local ply = self:GetPlayer()
        local r = GLAMBDA:Random( 0, 255 )
        local g = GLAMBDA:Random( 0, 255 )
        local b = GLAMBDA:Random( 0, 255 )
        local bright = GLAMBDA:Random( 0.5, 8, true )
        local distance = GLAMBDA:Random( 64, 2048 )
        local fov = GLAMBDA:Random( 10, 170 )

        local _, texture = table_Random( list_Get( "LampTextures" ) )
        local _, mdl = table_Random( list_Get( "LampModels" ) )

        transformTbl.Pos = trace.HitPos
        transformTbl.Angle = angle_zero

        local lamp = MakeLamp( ply, r, g, b, 37, true, texture, mdl, fov, distance, bright, true, transformTbl )
        if IsValid( lamp ) then
            local curPos = lamp:GetPos()
            local nearPoint = lamp:NearestPoint( curPos - ( trace.HitNormal * 512 ) )
            local lampOffset = ( curPos - nearPoint )
            lamp:SetPos( trace.HitPos + lampOffset )

            undo_Create( "Lamp" )
                undo_AddEntity( lamp )
                undo_SetPlayer( ply )
            undo_Finish()

            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Emitter", function( self )
	if !self:CheckLimit( "emitters" ) then return true end

    local targetEnt = ( GLAMBDA:Random( 3 ) == 1 )
    if targetEnt then targetEnt = self:FindToolTarget( DefFilter ) end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 2, 4, 0.66 )
    coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    local hitBone = trace.PhysicsBone
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() and util_IsValidPhysicsObject( hitEnt, hitBone ) then
        local ply = self:GetPlayer()
        local delay = GLAMBDA:Random( 0.1, 2, true )
        local scale = GLAMBDA:Random( 0, 6, true )
        
        local pos = trace.HitPos
        local norm = trace.HitNormal
        local shouldWeld = ( IsValid( hitEnt ) or hitEnt:IsWorld() and GLAMBDA:Random( 2 ) == 1 )
        if !shouldWeld then pos = ( pos + norm ) end
    
        local ang = norm:Angle()
        ang:RotateAroundAxis( norm, 0 )

        transformTbl.Pos = pos
        transformTbl.Ang = ang

        local _, effect = table_Random( list_Get( "EffectType" ) )
        local emitter = MakeEmitter( ply, 51, delay, true, effect, true, nil, scale, transformTbl )
        if IsValid( emitter ) then
            undo_Create( "Emitter" )
                undo_AddEntity( emitter )
        
                if shouldWeld then
                    local weld = constraint_Weld( emitter, hitEnt, 0, hitBone, 0, true, true )
                    if IsValid( weld ) then
                        ply:AddCleanup( "emitters", weld )
                        undo_AddEntity( weld )
                    end
        
                    local phys = emitter:GetPhysicsObject()
                    if IsValid( phys ) then phys:EnableCollisions( false ) end
                    
                    emitter.nocollide = true
                end

                undo_SetPlayer( ply )
            undo_Finish()

            self:EmitToolgunFire( trace )
            coroutine_wait( GLAMBDA:Random( 5, 15 ) * 0.1 )
        end
    end

    --

    return true
end )