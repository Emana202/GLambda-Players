local hook_Add = hook.Add
local bit_band = bit.band
local isstring = isstring
local IsValid = IsValid
local LerpAngle = LerpAngle
local CurTime = CurTime
local ents_Create = ents.Create

-- Process the queued inputs from players
hook_Add( "StartCommand", "GlaceBase-InputProcessing", function( ply, cmd )
    if !ply:IsGLambdaPlayer() then return end
    
    cmd:ClearButtons()
    cmd:ClearMovement()
    
    local GLACE = ply:GetGlace()
    if !ply:Alive() or ply:IsTyping() then 
        GLACE.CmdButtonQueue = 0
        return 
    end

    local buttonQueue = GLACE.CmdButtonQueue
    if GLACE.MoveSprint then buttonQueue = ( buttonQueue + IN_SPEED ) end
    if GLACE.MoveCrouch then buttonQueue = ( buttonQueue + IN_DUCK ) end

    local selectWep = GLACE.CmdSelectWeapon
    if selectWep then
        if isstring( selectWep ) and ply:HasWeapon( selectWep ) then
            selectWep = ply:GetWeapon( selectWep )
        end
        if IsValid( selectWep ) then
            if bit_band( buttonQueue, IN_ATTACK ) == IN_ATTACK then buttonQueue = ( buttonQueue - IN_ATTACK ) end
            if bit_band( buttonQueue, IN_ATTACK2 ) == IN_ATTACK2 then buttonQueue = ( buttonQueue - IN_ATTACK2 ) end
            cmd:SelectWeapon( selectWep )

            local equipFunc = GLACE:GetWeaponStat( "OnEquip" )
            if equipFunc then equipFunc( self, selectWep ) end
            
            GLACE.NextWeaponThinkT = 0
            GLACE.NextWeaponAttackT = ( CurTime() + 0.5 )
            
            GLAMBDA:RunHook( "GLambda_OnPlayerSelectWeapon", GLACE, selectWep )
        end

        GLACE.CmdSelectWeapon = nil
    end

    if buttonQueue > 0 then
        if !GLACE:IsDisabled() then cmd:SetButtons( buttonQueue ) end
        GLACE.CmdButtonQueue = 0
    end
end )

-- Process movement inputs from players
hook_Add( "SetupMove", "Glacebase-MovementProcessing", function( ply, mv, cmd )
    if !ply:IsGLambdaPlayer() or !ply:Alive() then return end 
    
    local GLACE = ply:GetGlace()
    if GLACE:IsDisabled() then return end

    if !ply:IsTyping() then
        local eyePos = ply:EyePos()
        local lookPos = GLACE.LookTowards_Pos
        local smoothLook = GLACE.LookTowards_Smooth
        if !lookPos or ( GLACE.LookTowards_EndT and CurTime() > GLACE.LookTowards_EndT or isentity( lookPos ) and !IsValid( lookPos ) ) then
            GLACE.LookTowards_Pos = nil
            lookPos = GLACE.LookTo_Pos
            smoothLook = GLACE.LookTo_Smooth

            if lookPos and ( GLACE.LookTo_EndT and CurTime() > GLACE.LookTo_EndT or isentity( lookPos ) and !IsValid( lookPos ) ) then
                GLACE.LookTo_Pos = nil
                lookPos = nil
            end
        end
        if lookPos then
            if ( GLACE:InCombat() or GLACE:IsPanicking() ) and lookPos == GLACE:GetEnemy() then
                lookPos = GLACE:GetNearestAimPoint( lookPos )
            end

            local ang = ( ( isentity( lookPos ) and lookPos:WorldSpaceCenter() or lookPos ) - eyePos ):Angle()
            ang.z = 0

            ply:SetEyeAngles( LerpAngle( smoothLook, ply:EyeAngles(), ang ) )
        end

        local approachPos = GLACE.MoveApproachPos
        local isApproaching = true
        if !approachPos or CurTime() > GLACE.MoveApproachEndT then
            GLACE.MoveApproachPos = nil
            approachPos = GLACE.FollowPath_Pos
            isApproaching = false

            if approachPos and CurTime() > GLACE.FollowPath_EndT then
                GLACE.FollowPath_Pos = nil
                approachPos = nil
            end
        end
        if approachPos then
            if !lookPos and !isApproaching then 
                ply:SetEyeAngles( LerpAngle( 0.066, ply:EyeAngles(), ( ( approachPos + vector_up * 70 ) - eyePos ):Angle() ) ) 
            end

            mv:SetMoveAngles( ( approachPos - ply:GetPos() ):Angle() )
            mv:SetForwardSpeed( ply:IsSprinting() and ply:GetRunSpeed() or ply:GetWalkSpeed() )
        end

        local moveInput = GLACE.MoveInputForward
        if moveInput then
            mv:SetForwardSpeed( moveInput )
            GLACE.MoveInputForward = nil
        end

        moveInput = GLACE.MoveInputSideway
        if moveInput then
            mv:SetSideSpeed( moveInput ) 
            GLACE.MoveInputSideway = nil
        end
    end

    local navigator = GLACE:GetNavigator()
    if !IsValid( navigator ) then
        navigator = ents_Create( "glace_navigator" )
        navigator:SetOwner( ply )
        navigator:Spawn()
        GLACE:SetNavigator( navigator ) 
    end

    if navigator:GetPos() != ply:GetPos() then
        navigator:SetPos( ply:GetPos() )
    end
end )