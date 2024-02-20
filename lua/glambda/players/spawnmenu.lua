function GLAMBDA.Player:SpawnEntity( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_SENT( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnNPC( classname, tr )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    Spawn_NPC( self:GetPlayer(), classname, tr )
end

function GLAMBDA.Player:SpawnProp( model )
    self:EmitSound( "ui/buttonclickrelease.wav", 60 )
    GMODSpawnProp( self:GetPlayer(), model, 0 )
end