local GetConVar = GetConVar
local Vector = Vector
local util_TraceHull = util.TraceHull
local table_Merge = table.Merge
local util_GetPlayerTrace = util.GetPlayerTrace
local IsValid = IsValid
local IsFirstTimePredicted = IsFirstTimePredicted
local EffectData = EffectData
local util_Effect = util.Effect

--

function GLAMBDA.Player:SpawnEntity( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_SENT( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnSWEP( classname, tr )
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
    return ( util_TraceHull( table_Merge( util_GetPlayerTrace( self:GetPlayer() ), toolTr, true ) ) )
end

function GLAMBDA.Player:EmitToolgunFire()
    local curWep = self:GetActiveWeapon()
    if !IsValid( curWep ) or curWep:GetClass() != "gmod_tool" then return end

	curWep:EmitSound( "Airboat.FireGunRevDown" )
	curWep:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    
	self:SetAnimation( PLAYER_ATTACK1 )
	if !IsFirstTimePredicted() or !GetConVar( "gmod_drawtooleffects" ):GetBool() then return end

    local eyeTrace = self:GetEyeTrace()
    local hitPos = eyeTrace.HitPos

    local effectData = EffectData()
	effectData:SetOrigin( hitPos )
	effectData:SetNormal( eyeTrace.HitNormal )
	effectData:SetEntity( eyeTrace.Entity )
	effectData:SetAttachment( eyeTrace.PhysicsBone )
	util_Effect( "selection_indicator", effectData )

	effectData = EffectData()
	effectData:SetOrigin( hitPos )
	effectData:SetStart( self:GetShootPos() )
	effectData:SetAttachment( 1 )
	effectData:SetEntity( curWep )
	util_Effect( "ToolTracer", effectData )
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