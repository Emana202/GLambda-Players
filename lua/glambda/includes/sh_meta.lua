local FindMetaTable = FindMetaTable
local vgui_Create = CLIENT and vgui.Create
local IsValid = IsValid

local metaTbl = ( GLAMBDA.MetaTable or {} )
GLAMBDA.MetaTable = metaTbl

local plyMeta = FindMetaTable( "Player" )

if ( CLIENT ) then

    local panelMeta = FindMetaTable( "Panel" )

    metaTbl.SetAvatarImage = ( metaTbl.SetAvatarImage or panelMeta.SetPlayer )
    function panelMeta:SetPlayer( ply, size )
        local imagePfp = self.GLambdaAvatar
        if !imagePfp and ply:IsGLambdaPlayer() then            
            imagePfp = vgui_Create( "DImage", self )
            imagePfp:SetSize( 32, 32 )
            imagePfp:SetMouseInputEnabled( false )
            imagePfp:SetMaterial( ply.gb_ProfilePicture )

            local parent = self:GetParent()
            if IsValid( parent ) and parent:GetName() == "DButton" then
                parent.DoClick = function() end
                parent.Paint = function() return true end
            end

            self.Paint = function() return true end
            self.GLambdaAvatar = imagePfp

            return
        end

        metaTbl.SetAvatarImage( self, ply, size )
    end

    --

    metaTbl.GetPlayerColor = ( metaTbl.GetPlayerColor or plyMeta.GetPlayerColor )
    function plyMeta:GetPlayerColor()
        local realClr = metaTbl.GetPlayerColor( self )
        if self:IsGLambdaPlayer() then 
            return ( self:GetNW2Vector( "glambda_plycolor", realClr ) )
        end
        return realClr
    end

    metaTbl.GetWeaponColor = ( metaTbl.GetWeaponColor or plyMeta.GetWeaponColor )
    function plyMeta:GetWeaponColor()
        local realClr = metaTbl.GetWeaponColor( self )
        if self:IsGLambdaPlayer() then 
            return ( self:GetNW2Vector( "glambda_wpncolor", realClr ) )
        end
        return realClr
    end

    metaTbl.VoiceVolume = ( metaTbl.VoiceVolume or plyMeta.VoiceVolume )
    function plyMeta:VoiceVolume()
        local realVol = metaTbl.VoiceVolume( self )
        if self:IsGLambdaPlayer() then 
            local voiceChan = GLAMBDA.VoiceChannels[ self ]
            return ( voiceChan and voiceChan.VoiceVolume or realVol )
        end
        return realVol
    end
    
    metaTbl.IsMuted = ( metaTbl.IsMuted or plyMeta.IsMuted )
    function plyMeta:IsMuted()
        return ( self:IsGLambdaPlayer() and self.gb_IsVoiceMuted or metaTbl.IsMuted( self ) )
    end

    metaTbl.IsSpeaking = ( metaTbl.IsSpeaking or plyMeta.IsSpeaking )
    function plyMeta:IsSpeaking()
        if self:IsGLambdaPlayer() then 
            local voiceChan = GLAMBDA.VoiceChannels[ self ]
            if voiceChan and IsValid( voiceChan.Sound ) then
                return ( voiceChan.Sound:GetState() == GMOD_CHANNEL_PLAYING )
            end
        end
        return metaTbl.IsSpeaking( self )
    end
    
    metaTbl.SetMuted = ( metaTbl.SetMuted or plyMeta.SetMuted )
    function plyMeta:SetMuted( mute )
        if self:IsGLambdaPlayer() then
            self.gb_IsVoiceMuted = mute
            return
        end
        metaTbl.SetMuted( self, mute )
    end

end

--

metaTbl.IsTyping = ( metaTbl.IsTyping or plyMeta.IsTyping )
function plyMeta:IsTyping()
    local realOne = metaTbl.IsTyping( self )
    if self:IsGLambdaPlayer() then 
        return self:GetNW2Bool( "glambda_istexttyping", realOne )
    end
    return realOne
end

metaTbl.IsPlayingTaunt = ( metaTbl.IsPlayingTaunt or plyMeta.IsPlayingTaunt )
function plyMeta:IsPlayingTaunt()
    local realOne = metaTbl.IsPlayingTaunt( self )
    if self:IsGLambdaPlayer() then 
        return self:GetNW2Bool( "glambda_playingtaunt", realOne )
    end
    return realOne
end

function plyMeta:IsGLambdaPlayer()
    return self.gb_IsLambdaPlayer
end

function plyMeta:GetGlaceObject()
    return self._GLACETABLE
end