GLAMBDA.UniversalActions = {
    [ "Killbind" ] = function( self )
        if GLAMBDA:Random( 150 ) != 1 then return end
        self:Kill()
        return true
    end,
    [ "SelectRandomWeapon" ] = function( self )
        if GLAMBDA:Random( 3 ) != 1 then return end
        
        if self:InCombat() then
            self:SelectLethalWeapon()
        else
            self:SelectRandomWeapon()
        end
    end,
    [ "Undo" ] = function( self )
        self:Timer( "Undo", GLAMBDA:Random( 0.3, 0.6, true ), GLAMBDA:Random( 6 ), function()
            self:UndoCommand()
        end )
    end,
    [ "Do 'act *'" ] = function( self )
        if !self:GetState( "Idle" ) or GLAMBDA:Random( 2 ) != 1 then return end
        self:CancelMovement()
        self:SetState( "UseActTaunt" )
    end,
    [ "Bunnyhop" ] = function( self )
        if !self:GetState( "Idle" ) or !self:GetIsMoving() or GLAMBDA:Random( 2 ) != 1 then return end
        self:PressKey( IN_JUMP )

        self:Timer( "BunnyhopJump", 1, GLAMBDA:Random( 4, 15 ), function() 
            if !self:GetIsMoving() or !self:GetState( "Idle" ) then return true end
            self:PressKey( IN_JUMP )
        end )
    end,
    [ "UseMedkit" ] = function( self )
        if self:Health() >= self:GetMaxHealth() or !self:GetState( "Idle" ) and !self:GetState( "Retreat" ) or GLAMBDA:Random( 2 ) != 1 then return end
        self:SelectWeapon( "weapon_medkit" )
    end
}

function GLAMBDA:AddUniversalAction( uaName, func )
    self.UniversalActions[ uaName ] = func
end