local IsValid = IsValid
local isentity = isentity
local LerpAngle = LerpAngle
local CurTime = CurTime
local ents_Create = ents.Create

-- Process the queued inputs from players
hook.Add( "StartCommand", "GlaceBase-InputProcessing", function( ply, cmd )
    if !ply:IsGLambdaPlayer() or !ply:Alive() then return end 
    
    cmd:ClearButtons()
    cmd:ClearMovement()

    local GLACE = ply:GetGlaceObject()

    local selectWep = GLACE.gb_selectweapon
    if selectWep then
        if isentity( selectWep ) and IsValid( selectWep ) then
            cmd:SelectWeapon( selectWep )
        elseif isstring( selectWep ) and ply:HasWeapon( selectWep ) then
            cmd:SelectWeapon( ply:GetWeapon( selectWep ) )
        end

        GLACE.gb_selectweapon = nil
    end

    local buttonQueue = GLACE.gb_buttonqueue
    if GLACE.gb_sprint then buttonQueue = ( buttonQueue + IN_SPEED ) end

    if buttonQueue > 0 then
        cmd:SetButtons( buttonQueue )
        GLACE.gb_buttonqueue = 0
    end
end )

-- Process movement inputs from players
hook.Add( "SetupMove", "Glacebase-MovementProcessing", function( ply,  mv, cmd )
    if !ply:IsGLambdaPlayer() or !ply:Alive() then return end 
    
    local GLACE = ply:GetGlaceObject()
    local eyePos = ply:EyePos()

    local lookPos = GLACE.gb_looktowardspos
    local smoothLook = GLACE.gb_looktowardssmooth
    if !lookPos or ( GLACE.gb_looktowardsend and CurTime() > GLACE.gb_looktowardsend or isentity( lookPos ) and !IsValid( lookPos ) ) then
        GLACE.gb_looktowardspos = nil
        lookPos = GLACE.gb_lookpos
        smoothLook = GLACE.gb_smoothlook

        if lookPos and ( GLACE.gb_lookendtime and CurTime() > GLACE.gb_lookendtime or isentity( lookPos ) and !IsValid( lookPos ) ) then
            GLACE.gb_lookpos = nil
            lookPos = nil
        end
    end
    if lookPos then
        local ang = ( ( isentity( lookPos ) and lookPos:WorldSpaceCenter() or lookPos ) - eyePos ):Angle()
        ang.z = 0
        ply:SetEyeAngles( LerpAngle( smoothLook, ply:EyeAngles(), ang ) )
    end

    local approachPos = GLACE.gb_approachpos
    if !approachPos or CurTime() > GLACE.gb_approachend then
        GLACE.gb_approachpos = nil
        approachPos = GLACE.gb_followpathpos
        
        if approachPos and CurTime() > GLACE.gb_followpathend then
            GLACE.gb_followpath = nil
            approachPos = nil
        end
    end
    if approachPos then
        if !lookPos then 
            ply:SetEyeAngles( LerpAngle( 0.2, ply:EyeAngles(), ( ( approachPos + vector_up * 70 ) - eyePos ):Angle() ) ) 
        end

        mv:SetMoveAngles( ( approachPos - ply:GetPos() ):Angle() )
        mv:SetForwardSpeed( ply:IsSprinting() and ply:GetRunSpeed() or ply:GetWalkSpeed() )
    end

    local moveInput = GLACE.gb_movementinputforward
    if moveInput then
        mv:SetForwardSpeed( moveInput )
        GLACE.gb_movementinputforward = nil
    end

    moveInput = GLACE.gb_movementinputside
    if moveInput then
        mv:SetSideSpeed( moveInput ) 
        GLACE.gb_movementinputside = nil
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