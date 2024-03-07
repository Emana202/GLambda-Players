if !COD then return end

local GetConVar = GetConVar
local onTeammates, onNPCs
local match = string.match

--

local function CanTakedown( ply, ent )
    if ent.Takedowning or ply:IsDowned() then return end

    if ent:IsPlayer() then
        onTeammates = ( onTeammates or GetConVar( "mwii_takedown_teammates" ) )
        if !onTeammates:GetBool() and ent:Team() == ply:Team() then return end
    elseif ent:IsNPC() or ent:IsNextBot() then
        onNPCs = ( onNPCs or GetConVar( "mwii_takedown_npcs" ) )
        if onNPCs:GetBool() then return end
    else
        return 
    end
 
    return ply:IsAtBack( ent )
end

--

local plyMeta = FindMetaTable( "Player" )
GLAMBDA.MetaTable.Takedown = ( GLAMBDA.MetaTable.Takedown or plyMeta.Takedown )

function plyMeta:Takedown()
    GLAMBDA.MetaTable.Takedown( self )
    if !self.Takedowning then return end

    if self:IsGLambdaPlayer() then
        local glace = self:GetGlace()
        if glace:GetSpeechChance( 100 ) then
            local selfAnim = self:GetNWString( "SVAnim" )
            local line = ( match( selfAnim, "victim" ) and "panic" or "kill" )

            glace:PlayVoiceLine( line, GLAMBDA:Random( 0.33, 1, true ) )
            print( self, selfAnim, line )
        end
    end

    --

    local targ = self.TakedowningTarget
    if !targ:IsGLambdaPlayer() then return end

    local glace = targ:GetGlace()
    if !glace:GetSpeechChance( 100 ) then return end

    local targAnim = targ:GetNWString( "SVAnim" )
    local line = ( match( targAnim, "victim" ) and "panic" or "kill" )
    
    glace:PlayVoiceLine( line, GLAMBDA:Random( 0.33, 1, true ) )
    print( targ, targAnim, line )
end

--

hook.Add( "GLambda_OnPlayerThink", "GLambdaMWIII_OnTakedownThink", function( ply, isDead, isDisabled )
    if isDead or isDisabled or ply.Takedowning or !ply:InCombat() then return end

    local enemy = ply:GetEnemy()
    if !enemy:OnGround() or !ply:OnGround() or !ply:InRange( enemy, 100 ) or !CanTakedown( ply, enemy ) then return end

    ply:LookTowards( enemy )
    if !ply:GetNWBool( "ShowExecuteButton", false ) then return end
    ply:Takedown()
end )

hook.Add( "GLambda_OnPlayerCanFireWeapon", "GLambdaMWIII_OnTakedownCanFire", function( ply, weapon, enemy )
    if ply:InRange( enemy, 1000 ) and CanTakedown( ply, enemy ) then return true end
end )

hook.Add( "GLambda_OnPlayerCombatPath", "GLambdaMWIII_OnTakedownMoveBehind", function( ply, movePos, enemy )
    if ply:InRange( enemy, 1000 ) and CanTakedown( ply, enemy ) and ply:IsVisible( enemy ) then 
        return ( enemy:GetPos() - enemy:GetForward() * 64 )
    end
end )

hook.Add( "GLambda_OnPlayerCanTarget", "GLambdaMWIII_OnTakedownIgnoreEnts", function( ply, ent )
    if ply.Takedowning then return true end

    if ent.Takedowning then
        local anim = ent:GetNWString( "SVAnim", "" )
        if #anim != 0 and match( anim, "victim" ) then return true end
    end
end )