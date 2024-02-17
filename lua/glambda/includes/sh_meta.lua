local metaTbl = ( GLAMBDA.MetaTable or {} )
GLAMBDA.MetaTable = metaTbl

local plyMeta = FindMetaTable( "Player" )

if ( CLIENT ) then

    local panelMeta = FindMetaTable( "Panel" )

    metaTbl.SetAvatarImage = ( metaTbl.SetAvatarImage or panelMeta.SetPlayer )
    function panelMeta:SetPlayer( ply, size )
        local imagePfp = self.GLambdaAvatar
        if !imagePfp and ply.gl_IsLambdaPlayer then            
            imagePfp = vgui.Create( "DImage", self )
            imagePfp:SetSize( 32, 32 )
            imagePfp:SetMouseInputEnabled( false )
            imagePfp:SetMaterial( ply.gl_ProfilePicture )

            local parent = self:GetParent()
            if IsValid( parent ) and parent:GetName() == "DButton" then
                parent.DoClick = function() end
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
        local nwColor = self:GetNW2Vector( "lambdaglace_playercolor", false )
        return ( nwColor or metaTbl.GetPlayerColor( self ) )
    end

    metaTbl.GetWeaponColor = ( metaTbl.GetWeaponColor or plyMeta.GetWeaponColor )
    function plyMeta:GetWeaponColor()
        local nwColor = self:GetNW2Vector( "lambdaglace_weaponcolor", false )
        return ( nwColor or metaTbl.GetWeaponColor( self ) )
    end

    metaTbl.VoiceVolume = ( metaTbl.VoiceVolume or plyMeta.VoiceVolume )
    function plyMeta:VoiceVolume()
        if self.gl_IsLambdaPlayer then 
            local voiceChan = GLAMBDA.VoiceChannels[ self ]
            return ( voiceChan and voiceChan.VoiceVolume or 0 )
        end
        return metaTbl.VoiceVolume( self )
    end
    
    metaTbl.IsMuted = ( metaTbl.IsMuted or plyMeta.IsMuted )
    function plyMeta:IsMuted()
        return ( self.gl_IsLambdaPlayer and self.gl_IsVoiceMuted or metaTbl.IsMuted( self ) )
    end

    metaTbl.IsSpeaking = ( metaTbl.IsSpeaking or plyMeta.IsSpeaking )
    function plyMeta:IsSpeaking()
        if self.gl_IsLambdaPlayer then 
            local voiceChan = GLAMBDA.VoiceChannels[ self ]
            return ( voiceChan and IsValid( voiceChan.Sound ) and voiceChan.Sound:GetState() == GMOD_CHANNEL_PLAYING )
        end
        return metaTbl.IsSpeaking( self )
    end
    
    metaTbl.SetMuted = ( metaTbl.SetMuted or plyMeta.SetMuted )
    function plyMeta:SetMuted( mute )
        if self.gl_IsLambdaPlayer then
            self.gl_IsVoiceMuted = mute
            return
        end
        metaTbl.SetMuted( self, mute )
    end

end

--

function plyMeta:IsGLambdaPlayer()
    return self.gl_IsLambdaPlayer
end

function plyMeta:GetGlaceObject()
    return self._GLACETABLE
end