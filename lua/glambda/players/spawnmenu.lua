local drawToolEffects = GetConVar( "gmod_drawtooleffects" )

--

function GLAMBDA.Player:SpawnEntity( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_SENT( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnWeapon( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_Weapon( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnNPC( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_NPC( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnProp( model )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    GMODSpawnProp( self:GetPlayer(), model, 0 )
end

--

local toolTr = {
    mask = ( CONTENTS_SOLID + CONTENTS_MOVEABLE + CONTENTS_MONSTER + CONTENTS_WINDOW + CONTENTS_DEBRIS + CONTENTS_GRATE + CONTENTS_AUX ),
    mins = Vector(),
    maxs = Vector()
}
function GLAMBDA.Player:GetToolTrace()
    return ( util.TraceHull( table.Merge( util.GetPlayerTrace( self:GetPlayer() ), toolTr, true ) ) )
end

local drawToolEffects = GetConVar( "gmod_drawtooleffects" )
function GLAMBDA.Player:EmitToolgunFire()
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) or curWep:GetClass() != "gmod_tool" then return end

	curWep:EmitSound( "Airboat.FireGunRevDown" )
	curWep:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    
	self:SetAnimation( PLAYER_ATTACK1 )
	if !IsFirstTimePredicted() or !drawToolEffects:GetBool() then return end

    local eyeTrace = self:GetEyeTrace()
    local hitPos = eyeTrace.HitPos

    local effectData = EffectData()
	effectData:SetOrigin( hitPos )
	effectData:SetNormal( eyeTrace.HitNormal )
	effectData:SetEntity( eyeTrace.Entity )
	effectData:SetAttachment( eyeTrace.PhysicsBone )
	util.Effect( "selection_indicator", effectData )

	effectData = EffectData()
	effectData:SetOrigin( hitPos )
	effectData:SetStart( self:GetShootPos() )
	effectData:SetAttachment( 1 )
	effectData:SetEntity( curWep )
	util.Effect( "ToolTracer", effectData )
end

function GLAMBDA.Player:FindToolTarget( dist, filter )
    local findEnts = self:FindInSphere( nil, ( dist or 400 ), function( ent )
        if filter and !filter( ent ) then return end
        if ent:IsPlayer() and !self:CanTarget( ent ) then return end
        return ( self:IsVisible( ent ) )
    end )

    if #findEnts == 0 then return end
    return findEnts[ GLAMBDA:Random( #findEnts ) ]
end