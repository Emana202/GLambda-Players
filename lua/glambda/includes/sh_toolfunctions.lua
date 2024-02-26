GLAMBDA.ToolgunTools = ( GLAMBDA.ToolgunTools or {} )

--

function GLAMBDA:AddToolgunTool( name, func )
    local cvar = self:CreateConVar( "tools_allow_" .. string.lower( name ), true, 'If the players are allowed to use the "' .. name .. '" toolgun tool.', {
        name = "Allow " .. name .. " Tool",
        category = "Tools"
    } )
    GLAMBDA.ToolgunTools[ name ] = { cvar, func }
end

--

GLAMBDA:AddToolgunTool( "Balloon", function( self )
    if !self:CheckLimit( "balloons" ) then return end

    local targetEnt = ( GLAMBDA:Random( 2 ) == 1 )
    if targetEnt then 
        targetEnt = self:FindToolTarget( nil, function( ent )
            return ( !ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
        end ) 
    end

    self:LookTo( ( targetEnt or self:GetPos() + VectorRand( -500, 500 ) ), 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 3, 10 ) * 0.1 )
    
    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() then
        local attachRope = ( GLAMBDA:Random( 3 ) != 1 )
        if !attachRope or util.IsValidPhysicsObject( hitEnt, trace.PhysicsBone ) then
            local hitPos = trace.HitPos
            local rndBallon = table.Random( list.Get( "BalloonModels" ) )

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

                undo.Create( "Balloon" )
                    undo.AddEntity( balloon )

                    if attachRope then
                        local physBone = trace.PhysicsBone
                        local ropeStart = balloon:WorldToLocal( newPos )
                        local ropeEnd = hitEnt:WorldToLocal( hitPos )
                        if IsValid( hitEnt ) then
                            local phys = hitEnt:GetPhysicsObjectNum( physBone )
                            if IsValid( phys ) then ropeEnd = phys:WorldToLocal( hitPos ) end
                        end

                        local ropeLength = GLAMBDA:Random( 25, 500 )
                        local constr, rope = constraint.Rope( balloon, hitEnt, 0, physBone, ropeStart, ropeEnd, 0, ropeLength, 0, 0.5, "cable/rope" )
                        if IsValid( constr ) then
                            undo.AddEntity( constr )
                            self:AddCleanup( "balloons", constr )
                        end
                        if IsValid( rope ) then
                            undo.AddEntity( rope )
                            self:AddCleanup( "balloons", rope )
                        end
                    end

                    undo.SetPlayer( self:GetPlayer() )
                undo.Finish()

                self:EmitToolgunFire()
                coroutine.wait( GLAMBDA:Random( 3, 10 ) * 0.1 )
            end
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Colour", function( self )
    local targetEnt = self:FindToolTarget( nil, function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --
    
    local traceEnt = self:GetToolTrace().Entity
    if IsValid( traceEnt ) then 
        if IsValid( traceEnt.AttachedEntity ) then traceEnt = traceEnt.AttachedEntity end
        traceEnt:SetColor( ColorRand( false ) ) 
        
        self:EmitToolgunFire()
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Dynamite", function( self )
    if !self:CheckLimit( "dynamite" ) then return true end

    self:LookTo( ( self:GetPos() + VectorRand( -500, 500 ) ), 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --

    local trace = self:GetToolTrace()
    local hitEnt = trace.Entity
    if !IsValid( hitEnt ) or !hitEnt:IsPlayer() then
        local _, model = table.Random( list.Get( "DynamiteModels" ) )
        local damage = GLAMBDA:Random( 0, 500 )
        local remove = ( GLAMBDA:Random( 3 ) != 1 )
        local delay = GLAMBDA:Random( 1, 10 )

        local hitPos = trace.HitPos
        local dynamite = MakeDynamite( self:GetPlayer(), hitPos, angle_zero, 52, damage, model, remove, delay )
        if IsValid( dynamite ) then
            local curPos = dynamite:GetPos()
            local offset = ( curPos - dynamite:NearestPoint( curPos - ( trace.HitNormal * 512 ) ) )
            
            dynamite:Explode( nil, self:GetPlayer() )
            dynamite:SetPos( hitPos + offset )
        
            undo.Create( "Dynamite" )
                undo.AddEntity( dynamite )
                undo.SetPlayer( self:GetPlayer() )
            undo.Finish()
            
            self:EmitToolgunFire()
            coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Remover", function( self )
    local targetEnt = self:FindToolTarget( nil, function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --

    local traceEnt = self:GetToolTrace().Entity
    if IsValid( traceEnt ) and !traceEnt:IsPlayer() then
        constraint.RemoveAll( traceEnt )
        timer.Simple( 1, function() if IsValid( traceEnt ) then traceEnt:Remove() end end )

        traceEnt:SetNotSolid( true )
        traceEnt:SetMoveType( MOVETYPE_NONE )
        traceEnt:SetNoDraw( true )

        local effectData = EffectData()
        effectData:SetOrigin( traceEnt:GetPos() )
        effectData:SetEntity( traceEnt )
        util.Effect( "entity_remove", effectData, true, true )
        
        self:EmitToolgunFire()
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
    end

    --

    return true
end )

local ropeMaterials = { "cable/redlaser", "cable/cable2", "cable/rope", "cable/blue_elec", "cable/xbeam", "cable/physbeam", "cable/hydra" }
GLAMBDA:AddToolgunTool( "Rope", function( self )
    local firstTarg = ( GLAMBDA:Random( 3 ) != 1 )
    if firstTarg then 
        firstTarg = self:FindToolTarget( nil, function( ent )
            return ( !ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
        end ) 
    end

    self:LookTo( ( firstTarg or VectorRand( -500, 500 ) ), 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --

    local firstTr = self:GetToolTrace()
    local firstEnt = firstTr.Entity
    if !IsValid( firstEnt ) or !firstEnt:IsPlayer() then
        self:EmitToolgunFire()
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

        local secondTarg = ( GLAMBDA:Random( 3 ) != 1 )
        if secondTarg then 
            secondTarg = self:FindToolTarget( nil, function( ent )
                return ( ent != firstTarg and !ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
            end )
        end
    
        self:LookTo( ( secondTarg or VectorRand( -500, 500 ) ), 1, 1, 0.66 )
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

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

            local constr, rope = constraint.Rope( firstEnt, secEnt, firstTr.PhysicsBone, secTr.PhysicsBone, firstTr.HitPos, secTr.HitPos, ( firstTr.HitPos - secTr.HitPos ):Length(), addLength, forceLimit, width, material, rigid, color )
    		if IsValid( constr ) then
                local ply = self:GetPlayer()

                undo.Create( "Rope" )
                    undo.AddEntity( constr )
                    if IsValid( rope ) then undo.AddEntity( rope ) end
                    undo.SetPlayer( ply )
                undo.Finish()
    
                ply:AddCleanup( "ropeconstraints", constr )
                if IsValid( rope ) then ply:AddCleanup( "ropeconstraints", rope ) end
                
                self:EmitToolgunFire()
                coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
            end
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Trails", function( self )
    local targetEnt = self:FindToolTarget( nil, function( ent )
        return ( ent:IsNPC() or ent:IsNextBot() or !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end )
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --
    
    local traceEnt = self:GetToolTrace().Entity
    if IsValid( traceEnt ) then 
        if IsValid( traceEnt.SToolTrail ) then
            traceEnt.SToolTrail:Remove()
            traceEnt.SToolTrail = nil
        end

        local material = table.Random( list.Get( "trail_materials" ) )
		local length = GLAMBDA:Random( 0.1, 10, true )
		local endSize = GLAMBDA:Random( 1, 128 )
		local startSize = GLAMBDA:Random( 1, 128 )

        local trail = util.SpriteTrail( traceEnt, 0, ColorRand( true ), false, startSize, endSize, length, 1 / ( ( startSize + endSize ) * 0.5 ), material .. ".vmt" )
        if IsValid( trail ) then
            traceEnt.SToolTrail = trail

            local ply = self:GetPlayer()
            ply:AddCleanup( "trails", trail )

            undo.Create( "Trail" )
                undo.AddEntity( trail )
                undo.SetPlayer( ply )
            undo.Finish()

            self:EmitToolgunFire()
            coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
        end
    end

    --

    return true
end )

GLAMBDA:AddToolgunTool( "Material", function( self )
    local targetEnt = self:FindToolTarget( function( ent )
        return ( !ent:IsNPC() and !ent:IsNextBot() and !ent:IsPlayer() and IsValid( ent:GetPhysicsObject() ) )
    end ) 
    if !IsValid( targetEnt ) then return true end

    self:LookTo( targetEnt, 1, 1, 0.66 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    --
    
    local traceEnt = self:GetToolTrace().Entity
    if IsValid( traceEnt ) then 
        if IsValid( traceEnt.AttachedEntity ) then traceEnt = traceEnt.AttachedEntity end

        local material = table.Random( list.Get( "OverrideMaterials" ) )
        traceEnt:SetMaterial( material ) 

        self:EmitToolgunFire()
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
    end

    --

    return true
end )