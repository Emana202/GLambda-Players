function GLAMBDA.Player:SpawnEntity( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_SENT( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnNPC( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_NPC( self:GetPlayer(), classname, tr )
end