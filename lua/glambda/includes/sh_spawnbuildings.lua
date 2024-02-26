GLAMBDA.Buildings = ( GLAMBDA.Buildings or {} )

--

function GLAMBDA:AddBuildFunction( name, settingName, desc, func )
    local cvar = self:CreateConVar( "building_allow_" .. name, true, desc, {
        name = settingName,
        category = "Building"
    } )
    GLAMBDA.Buildings[ name ] = { cvar, func }
end

--

GLAMBDA:AddBuildFunction( "props", "Allow Prop Spawning", "If the players are allowed to spawn props.", function( self )
    print( self, self.CheckLimit )
    if !self:CheckLimit( "props" ) then return end

    local propTbl = GLAMBDA.SpawnlistProps
    if #propTbl == 0 then return end

    for i = 1, GLAMBDA:Random( 4 ) do
        if !self:CheckLimit( "props" ) then return end

        self:LookTo( self:GetPos() + self:GetForward() * GLAMBDA:Random( -500, 500 ) + self:GetRight() * GLAMBDA:Random( -500, 500 ) - self:GetUp() * GLAMBDA:Random( -25, 80 ), 1, 1 )
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

        self:SpawnProp( propTbl[ GLAMBDA:Random( #propTbl ) ] )
        coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )
    end

    return true
end )

GLAMBDA:AddBuildFunction( "npcs", "Allow NPC Spawning", "If the players are allowed to spawn NPCs.", function( self )
    if !self:CheckLimit( "npcs" ) then return end

    local npcTbl = GLAMBDA.SpawnlistNPCs
    if #npcTbl == 0 then return end

    self:LookTo( self:GetPos() + self:GetForward() * GLAMBDA:Random( -500, 500 ) + self:GetRight() * GLAMBDA:Random( -500, 500 ) - self:GetUp() * GLAMBDA:Random( -25, 80 ), 1, 1 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    self:SpawnNPC( npcTbl[ GLAMBDA:Random( #npcTbl ) ] )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    return true
end )

GLAMBDA:AddBuildFunction( "sents", "Allow Entity Spawning", "If the players are allowed to spawn entities.", function( self )
    if !self:CheckLimit( "sents" ) then return end

    local entTbl = GLAMBDA.SpawnlistENTs
    if #entTbl == 0 then return end

    self:LookTo( self:GetPos() + self:GetForward() * GLAMBDA:Random( -500, 500 ) + self:GetRight() * GLAMBDA:Random( -500, 500 ) - self:GetUp() * GLAMBDA:Random( -25, 80 ), 1, 1 )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    self:SpawnEntity( entTbl[ GLAMBDA:Random( #entTbl ) ] )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    return true
end )

GLAMBDA:AddBuildFunction( "spraying", "Allow Spraying", "If the players are allowed to use their sprays.", function( self )
    if #GLAMBDA.Sprays == 0 or CurTime() <= self.NextSprayUseT then return end
    self.NextSprayUseT = ( CurTime() + 10 )

    local targetPos = ( self:EyePos() + AngleRand( -180, 180 ):Forward() * 128 )
    self:LookTo( targetPos, 1, 1 )
    
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    local trace = self:Trace( nil, targetPos )
    if !trace.Hit then return end

    net.Start( "glambda_spray" )
        net.WriteString( GLAMBDA.Sprays[ GLAMBDA:Random( #GLAMBDA.Sprays ) ] )
        net.WriteVector( trace.HitPos )
        net.WriteVector( trace.HitNormal )
    net.Broadcast()

    self:EmitSound( "SprayCan.Paint" )
    coroutine.wait( GLAMBDA:Random( 2, 10 ) * 0.1 )

    return true
end )