local Vector = Vector
local ipairs = ipairs
local string_Explode = string.Explode
local string_upper = string.upper
local string_Left = string.Left
local string_Right = string.Right
local string_Implode = string.Implode
local vgui_Create = CLIENT and vgui.Create
local SortedPairs = SortedPairs
local table_Merge = table.Merge
local surface_PlaySound = CLIENT and surface.PlaySound
local DermaMenu = DermaMenu
local chat_AddText = CLIENT and chat.AddText
local table_Empty = table.Empty
local pairs = pairs
local file_Exists = file.Exists
local print = print
local table_concat = table.concat
local string_EndsWith = string.EndsWith
local CreateMaterial = CreateMaterial
local Material = Material
local player_manager_AllValidModels = player_manager.AllValidModels
local Angle = Angle
local RealTime = RealTime
local IsValid = IsValid
local math_ceil = math.ceil
local table_IsEmpty = table.IsEmpty
local string_match = string.match
local string_Replace = string.Replace

--

local PANEL = GLAMBDA.PANEL
local FILE = GLAMBDA.FILE

local vector_white = Vector( 1, 1, 1 )

local voiceProfPaths = {
    "sound/glambdaplayers/voiceprofiles/",
    "sound/lambdaplayers/voiceprofiles/",
    "sound/zetaplayer/custom_vo/"
}
local profilePicPaths = {
    "glambdaplayers/data/custompfps/",
    "lambdaplayers/custom_profilepictures/"
}
local pfpFileTypes = {
    ".jpg",
    ".png",
    ".vtf"
}

local function MakeNiceName( str )
    local newName = {}
    for _, s in ipairs( string_Explode( "_", str ) ) do
        if #s == 1 then newName[ #newName + 1 ] = string_upper( s ) continue end
        newName[ #newName + 1 ] = string_upper( string_Left( s, 1 ) ) .. string_Right( s, ( #s - 1 ) )
    end
    return string_Implode( " ", newName )
end

local function OpenProfileEditor( ply )
    local frame = PANEL:Frame( "Profile Editor", 1000, 500 )

    local rightPnl = PANEL:BasicPanel( frame )
    rightPnl:SetSize( 200, 200 )
    rightPnl:Dock( RIGHT )

    local profileList = vgui_Create( "DListView", rightPnl )
    profileList:Dock( FILL )
    profileList:AddColumn( "Profiles", 1 )
    
    local CompileSettings, ImportProfile, UpdateSBSliders
    local profiles = {}
    local profileInfo = {}

    local searchBar = PANEL:SearchBar( profileList, profiles, rightPnl, true )
    searchBar:Dock( TOP )

    local localProfiles = FILE:ReadFile( "glambda/profiles.json", "json" )
    if localProfiles then
        for name, data in SortedPairs( localProfiles ) do
            local line = profileList:AddLine( name .. " | LOCAL" )
            line.gl_IsLocalProfile = true
            line:SetSortValue( 1, data )
        end

        table_Merge( profiles, localProfiles )
    end

    local function UpdateProfileLine( name, newInfo, isLocal )
        for _, line in ipairs( profileList:GetLines() ) do
            local info = line:GetSortValue( 1 )
            if info.Name == profilename then line:SetSortValue( 1, newInfo ) return end
        end

        local line = profileList:AddLine( newInfo.Name .. " | " .. ( isLocal and "Local" or "Server" ) )
        line.gl_IsLocalProfile = isLocal
        line:SetSortValue( 1, newInfo )
    end

    function profileList:DoDoubleClick( id, line )
        ImportProfile( line:GetSortValue( 1 ) )
        surface_PlaySound( "buttons/button15.wav" )
    end

    function profileList:OnRowRightClick( id, line )
        local jerma = DermaMenu( false, rightPnl )
        jerma:AddOption( "Cancel", function() end )

        local profName = line:GetSortValue( 1 ).Name
        jerma:AddOption( "Delete " .. profName .. "?", function()
            if line.gl_IsLocalProfile then
                FILE:RemoveVarFromKVFile( "glambda/profiles.json", profName, "json" )
                chat_AddText( "Deleted " .. profName .. " from your Profiles")
            else
                PANEL:RemoveVarFromKVFile( "glambda/profiles.json", profName, "json" ) 
                chat_AddText( "Deleted " .. profName .. " from the Server's Profiles")
            end

            surface_PlaySound( "buttons/button15.wav" )
            profileList:RemoveLine( id )
        end )
    end

    PANEL:Button( rightPnl, BOTTOM, "Save To Local", function()
        local compInfo = CompileSettings()
        local profName = compInfo.Name

        chat_AddText( "Saved " .. profName .. " to your Profiles!" )
        surface_PlaySound( "buttons/button15.wav" )
        
        UpdateProfileLine( profName, compInfo, true )
        FILE:UpdateKeyValueFile( "glambda/profiles.json", { [ profName ] = compInfo }, "json" ) 
    end )
    PANEL:Button( rightPnl, BOTTOM, "Save To Server", function()
        if !ply:IsSuperAdmin() then
            chat_AddText( "You must be a Super Admin to save profiles to the Server! " )
            surface_PlaySound( "buttons/button10.wav" )
            return
        end

        local compInfo = CompileSettings()
        local profName = compInfo.Name

        surface_PlaySound( "buttons/button15.wav" )
        chat_AddText( "Saved " .. profName .. " to the Server's Profiles." )

        local line = profileList:AddLine( profName .. " | Server" )
        line.gl_IsLocalProfile = false
        line:SetSortValue( 1, compInfo )

        UpdateProfileLine( profName, compInfo, true )
        PANEL:UpdateKeyValueFile( "glambda/profiles.json", { [ profName ] = compInfo }, "json" ) 
    end )

    PANEL:Button( rightPnl, BOTTOM, "Request Profiles from Server", function()
        if ply:IsListenServerHost() then
            chat_AddText( "You are the server host!" )
            surface_PlaySound( "buttons/button10.wav" )
            return
        end
        if !ply:IsSuperAdmin() then
            chat_AddText( "You must be a super admin to request the Server's Profiles!" )
            surface_PlaySound( "buttons/button10.wav" )
            return
        end

        PANEL:RequestDataFromServer( "glambda/profiles.json", "json", function( data )
            if !data then
                chat_AddText( "The Server has no profiles to send!" )
                surface_PlaySound( "buttons/button10.wav" )
                return
            end

            profileList:Clear()
            table_Empty( profiles )
            table_Merge( profiles, data )

            for name, data in SortedPairs( data ) do
                local line = profilelist:AddLine( name .. " | Server" )
                line.gl_IsLocalProfile = false
                line:SetSortValue( 1, data )
            end
        end )
    end )

    PANEL:Button( rightPnl, BOTTOM, "Validate Profiles", function()
        local hasIssues = false
        for name, data in pairs( profiles ) do
            local model = data.PlayerModel
            if model and !file_Exists( model, "GAME" ) then
                hasIssues = true
                print( "GLambda Profile " .. name .. " Validation: Invalid Playermodel! [ " .. model .. " ]" )
            end

            local vp = data.VoiceProfile
            if vp then
                local noVP = true
                for _, path in ipairs( voiceProfPaths ) do
                    noVP = !file_Exists( voiceProfPaths .. vp, "GAME" )
                    if !noVP then break end
                end
                if noVP then
                    hasIssues = true
                    print( "GLambda Profile " .. name .. " Validation: Invalid Voice Profile! [ " .. vp .. " ]" )
                end
            end

            local pfp = data.ProfilePicture
            if pfp and !file_Exists( "materials/" .. pfp, "GAME" ) then 
                hasIssues = true
                print( "GLambda Profile " .. name .. " Validation: Invalid Profile Picture! [ " .. pfp .. " ]" ) 
            end
        end

        chat_AddText( "Validation complete. " .. ( hasIssues and "Some issues were found. Check the console for info" or "No issues were found" ) )
    end )

    --

    local scrollPnl = PANEL:ScrollPanel( frame, true, FILL )

    local mainPnl = PANEL:BasicPanel( scrollPnl, LEFT )
    mainPnl:SetSize( 300, 200 )
    mainPnl:Dock( LEFT )
    scrollPnl:AddPanel( mainPnl )

    local mainScroll = PANEL:ScrollPanel( mainPnl, false, FILL )

    --

    PANEL:Label( "Player Name", mainScroll, TOP )
    local plyName = PANEL:TextEntry( mainScroll, TOP, "Enter a name here" )

    PANEL:Label( "Player Model", mainScroll, TOP )
    PANEL:Label( "Leave blank for random", mainScroll, TOP )
    local plyMdl = PANEL:TextEntry( mainScroll, TOP, "Enter a model path" )

    --

    PANEL:Label( "Profile Picture", mainScroll, TOP )
    PANEL:Label( "Enter a file path relative to", mainScroll, TOP )
    PANEL:Label( profilePicPaths[ 1 ], mainScroll, TOP )
    PANEL:Label( "Leave blank for random", mainScroll, TOP )
    PANEL:URLLabel( "Click here to learn about Profile Pictures", "https://github.com/IcyStarFrost/Lambda-Players/wiki/Adding-Custom-Content#profile-pictures", mainScroll, TOP )

    local pfpPreview = vgui_Create( "DImage", mainScroll )
    pfpPreview:Dock( TOP ) 
    pfpPreview:SetSize( 200, 200 )
    local plyPfp = PANEL:TextEntry( mainScroll, TOP, "Enter a file path" )

    local foundPfpPath = profilePicPaths[ 1 ]
    function plyPfp:OnChange() 
        local text = plyPfp:GetText()
        
        for _, path in ipairs( profilePicPaths ) do
            local fullPath = "materials/" .. path
            for _, imgExt in ipairs( pfpFileTypes ) do
                if !file_Exists( fullPath .. text .. imgExt, "GAME" ) then continue end
                text = text .. imgExt; break
            end
            if !file_Exists( fullPath .. text, "GAME" ) then continue end

            local pfpMat
            if string_EndsWith( text, ".vtf" ) then
                pfpMat = CreateMaterial( "GLambda_PfpMaterial_" .. path .. text, "UnlitGeneric", {
                    [ "$baseTexture" ] = path .. text,
                    [ "$translucent" ] = 1,

                    [ "Proxies" ] = {
                        [ "AnimatedTexture" ] = {
                            [ "animatedTextureVar" ] = "$basetexture",
                            [ "animatedTextureFrameNumVar" ] = "$frame",
                            [ "animatedTextureFrameRate" ] = 10
                        }
                    }
                })
            else
                pfpMat = Material( path .. text )
            end

            pfpPreview:SetMaterial( pfpMat )
            foundPfpPath = path
            break
        end
    end

    --

    PANEL:Label( "Voice Profile", mainScroll, TOP )
    PANEL:URLLabel( "Click here to learn about Voice Profiles", "https://github.com/IcyStarFrost/Lambda-Players/wiki/Adding-Custom-Content#voice-profiles", mainScroll, TOP )

    local comboTbl = { "None" }
    for name, _ in SortedPairs( GLAMBDA.VoiceProfiles ) do
        comboTbl[ #comboTbl + 1 ] = name
    end
    local plyVP = PANEL:ComboBox( mainScroll, TOP, comboTbl, true )
    plyVP:SelectOptionByKey( "None" )

    --

    PANEL:Label( "Text Profile", mainScroll, TOP )
    PANEL:URLLabel( "Click here to learn about Text Profiles", "https://github.com/IcyStarFrost/Lambda-Players/wiki/Adding-Custom-Content#text-profiles", mainScroll, TOP )

    local comboTbl = { "None" }
    for name, _ in SortedPairs( GLAMBDA.TextProfiles ) do
        comboTbl[ #comboTbl + 1 ] = name
    end
    local plyTP = PANEL:ComboBox( mainScroll, TOP, comboTbl, true )
    plyTP:SelectOptionByKey( "None" )

    --

    PANEL:Label( "The Profile's voice pitch", mainScroll, TOP )
    local plyVcPitch = PANEL:NumSlider( mainScroll, TOP, 100, "Voice Pitch", 30, 255, 0 )

    --

    PANEL:Label( "Spawn Weapon", mainScroll, TOP )
    local spawnWpnLbl = PANEL:Label( "The weapon to spawn with: None", mainScroll, TOP )
    
    local plySpawnWpn = ""
    local function SetSpawnWeapon( wpn )
        plySpawnWpn = wpn
        spawnWpnLbl:SetText( "The weapon to spawn with: " .. ( GLAMBDA.WeaponList[ wpn ] and GLAMBDA.WeaponList[ wpn ].Name or "None" ) )
    end
    PANEL:Button( mainScroll, TOP, "Select Spawn Weapon", function()
        GLAMBDA:WeaponSelectPanel( plySpawnWpn, true, false, true, false, function( selectWep )
            SetSpawnWeapon( selectWep )
        end )
    end )

    --

    PANEL:Label( "Favorite Weapon", mainScroll, TOP )
    local favWpnLbl = PANEL:Label( "The favorite weapon to use: None", mainScroll, TOP )
    
    local plyFavWpn = ""
    local function SetFavoriteWeapon( wpn )
        plyFavWpn = wpn
        favWpnLbl:SetText( "The favorite weapon to use: " .. ( GLAMBDA.WeaponList[ wpn ] and GLAMBDA.WeaponList[ wpn ].Name or "None" ) )
    end
    PANEL:Button( mainScroll, TOP, "Select Favorite Weapon", function()
        GLAMBDA:WeaponSelectPanel( plyFavWpn, true, false, true, false, function( selectWep )
            SetFavoriteWeapon( selectWep )
        end )
    end )

    --

    local persSliders = {}
    local persPnl = PANEL:BasicPanel( scrollPnl )
    persPnl:SetSize( 250, 200 )
    persPnl:Dock( LEFT )
    scrollPnl:AddPanel( persPnl )

    local persScroll = PANEL:ScrollPanel( persPnl, false, FILL )

    PANEL:Label( "-- Personality Settings --", persScroll, TOP )
    local usePersona = PANEL:CheckBox( persScroll, TOP, true, "Use Personality Sliders" )
    PANEL:Label( "If this Profile should use these sliders:", persScroll, TOP )

    for name, _ in SortedPairs( GLAMBDA.Personalities ) do 
        local numSlider = PANEL:NumSlider( persScroll, TOP, 30, name, 0, 100, 0 )
        persSliders[ name ] = numSlider
    end

    --

    local mainPnl2 = PANEL:BasicPanel( scrollPnl )
    mainPnl2:SetSize( 320, 200 )
    mainPnl2:Dock( LEFT )
    scrollPnl:AddPanel( mainPnl2 )

    PANEL:Label( "-- Easy Playermodel Selections --", mainPnl2, TOP )
    PANEL:Label( "Click on a model to easily use it", mainPnl2, TOP )
    local mainScroll2 = PANEL:ScrollPanel( mainPnl2, false, FILL )

    local pmList = vgui_Create( "DIconLayout", mainScroll2 )
    pmList:Dock( FILL )
    pmList:SetSpaceY( 12 )
    pmList:SetSpaceX( 12 )

    for _, mdl in SortedPairs( player_manager_AllValidModels() ) do
        local mdlButton = pmList:Add( "SpawnIcon" )
        mdlButton:SetModel( mdl )

        function mdlButton:DoClick()
            plyMdl:SetText( mdlButton:GetModelName() )
            plyMdl:OnChange()
        end
    end

    --

    local plyMdlPrevPnl = PANEL:BasicPanel( scrollPnl )
    plyMdlPrevPnl:SetSize( 300, 200 )
    plyMdlPrevPnl:Dock( LEFT )
    scrollPnl:AddPanel( plyMdlPrevPnl )

    PANEL:Label( "-- Playermodel Preview --", plyMdlPrevPnl, TOP )

    local plyMdlPreview = vgui_Create( "DModelPanel", plyMdlPrevPnl )
    plyMdlPreview:SetSize( 300, 400 )
    plyMdlPreview:Dock( TOP )
    plyMdlPreview:SetModel( "" )
    plyMdlPreview:SetFOV( 45 )

    local mdlPreviewAng = Angle()
    function plyMdlPreview:LayoutEntity( ent )
        mdlPreviewAng.y = ( RealTime() * 20 % 360 )
        ent:SetAngles( mdlPreviewAng )
    end

    function plyMdlPreview:UpdateColors( clrVec )
        if !clrVec or !self:GetEntity() then return end
        self:GetEntity().GetPlayerColor = function() return clrVec end
    end

    function plyMdl:OnChange() 
        local mdlPath = plyMdl:GetText()
        if !file_Exists( mdlPath, "GAME" ) then return end

        plyMdlPreview:SetModel( mdlPath )
        UpdateSBSliders()
    end

    --

    local clrFrame = PANEL:BasicPanel( scrollPnl )
    clrFrame:SetSize( 200, 200 )
    clrFrame:Dock( LEFT )
    scrollPnl:AddPanel( clrFrame )

    local clrScroll = PANEL:ScrollPanel( clrFrame, false, FILL )

    PANEL:Label( "-- Playermodel Color --", clrScroll, TOP )
    local usePlyClr = PANEL:CheckBox( clrScroll, TOP, true, "Use Playermodel Color" )
    local plyColor = PANEL:ColorMixer( clrScroll, TOP )

    function plyColor:ValueChanged( col )
        plyMdlPreview:UpdateColors( Vector( col.r / 255, col.g / 255, col.b / 255 ) )
    end

    PANEL:Label( "-- Physgun Color --", clrScroll, TOP )
    local usePhysClr = PANEL:CheckBox( clrScroll, TOP, true, "Use Physgun Color" )
    local plyPhysClr = PANEL:ColorMixer( clrScroll, TOP )

    --

    local skinSlider
    local bgSliders = {}
    
    local sbgFrame = PANEL:BasicPanel( scrollPnl )
    sbgFrame:SetSize( 200, 200 )
    sbgFrame:Dock( LEFT )
    scrollPnl:AddPanel( sbgFrame )

    PANEL:Label( "-- BodyGroups/Skins --", sbgFrame, TOP )
    local sbgScroll = PANEL:ScrollPanel( sbgFrame, false, FILL )

    UpdateSBSliders = function()
        local ent = plyMdlPreview:GetEntity()

        for index, slider in pairs( bgSliders ) do 
            if IsValid( slider ) then slider:Remove() end
            bgSliders[ index ] = nil
        end
        if IsValid( skinSlider ) then skinSlider:Remove() end

        local skinCount = ( ent:SkinCount() - 1 )
        if skinCount != 0 then
            skinSlider = PANEL:NumSlider( sbgScroll, TOP, 0, "Skin", 0, skinCount, 0 )
            function skinSlider:OnValueChanged( val )
                ent:SetSkin( math_ceil( val ) )
            end
        end

        local groups = ( ent:GetBodyGroups() or {} )
        for _, v in ipairs( groups ) do
            local mdls = #v.submodels
            if mdls == 0 then continue end

            local index = v.id
            local bgSlider = PANEL:NumSlider( sbgScroll, TOP, 0, MakeNiceName( v.name ), 0, mdls, 0 )
            function bgSlider:OnValueChanged( val )
                ent:SetBodygroup( index, math_ceil( val ) )
            end
            bgSliders[ index ] = bgSlider
        end
    end

    --

    CompileSettings = function()
        local name = plyName:GetText()
        if #name == 0 then
            chat_AddText( "No name is set!" )
            return
        end

        --

        local infoTbl = {
            Name = name,
            VoicePitch = math_ceil( plyVcPitch:GetValue() ),
            PlayerColor = ( usePlyClr:GetChecked() and plyColor:GetVector() or nil ),
            WeaponColor = ( usePhysClr:GetChecked() and plyPhysClr:GetVector() or nil ),
            SkinGroup = ( IsValid( skinSlider ) and math_ceil( skinSlider:GetValue() ) or nil ),
            SpawnWeapon = ( #plySpawnWpn != 0 and plySpawnWpn or nil ),
            FavoriteWeapon = ( #plyFavWpn != 0 and plyFavWpn or nil )
        }

        --

        local mdl = plyMdl:GetText()
        infoTbl.PlayerModel = ( #mdl != 0 and mdl or nil )
        
        local pfp = plyPfp:GetText()
        infoTbl.ProfilePicture = ( #pfp != 0 and foundPfpPath .. pfp or nil )
        
        local _, vp = plyVP:GetSelected()
        infoTbl.VoiceProfile = ( #vp != 0 and vp or nil )

        local _, tp = plyTP:GetSelected()
        infoTbl.TextProfile = ( #tp != 0 and tp or nil )

        --

        if !table_IsEmpty( bgSliders ) then
            infoTbl.BodyGroups = {}
            for index, bgSlider in pairs( bgSliders ) do
                infoTbl.BodyGroups[ index ] = math_ceil( bgSlider:GetValue() )
            end
        end

        if usePersona:GetChecked() then
            infoTbl.Personality = {}
            for name, slider in pairs( persSliders ) do
                infoTbl.Personality[ name ] = math_ceil( slider:GetValue() )
            end
        end

        --

        return infoTbl
    end

    --

    ImportProfile = function( infoTbl )
        plyMdl:SetText( GLAMBDA:GetProfileInfo( infoTbl, "PlayerModel" ) or "" )
        plyName:SetText( GLAMBDA:GetProfileInfo( infoTbl, "Name" ) )
        plyVcPitch:SetValue( GLAMBDA:GetProfileInfo( infoTbl, "VoicePitch" ) )
        plyVP:SelectOptionByKey( GLAMBDA:GetProfileInfo( infoTbl, "VoiceProfile" ) or "" )
        plyTP:SelectOptionByKey( GLAMBDA:GetProfileInfo( infoTbl, "TextProfile" ) or "" )

        SetSpawnWeapon( infoTbl.SpawnWeapon or "" )
        SetFavoriteWeapon( infoTbl.FavoriteWeapon or "" )

        --
        
        if IsValid( skinSlider ) then
            skinSlider:SetValue( GLAMBDA:GetProfileInfo( infoTbl, "SkinGroup" ) or 0 )
        end

        local plyClr = GLAMBDA:GetProfileInfo( infoTbl, "PlayerColor" )
        usePlyClr:SetChecked( plyClr != nil )
        plyColor:SetVector( plyClr or vector_white )

        local wpnClr = GLAMBDA:GetProfileInfo( infoTbl, "WeaponColor" )
        usePhysClr:SetChecked( wpnClr != nil )
        plyPhysClr:SetVector( wpnClr or vector_white )

        local pfp = GLAMBDA:GetProfileInfo( infoTbl, "ProfilePicture" )
        if pfp then
            local foundPath = false
            for _, path in ipairs( profilePicPaths ) do
                if !string_match( pfp, path ) then continue end
                plyPfp:SetText( string_Replace( pfp, path, "" ) )
                foundPath = true; break
            end
            if !foundPath then plyPfp:SetText( "" ) end
        else
            plyPfp:SetText( "" )
        end

        local bodyGroups = GLAMBDA:GetProfileInfo( infoTbl, "BodyGroups" )
        if bodyGroups then
            local ent = plyMdlPreview:GetEntity()

            for index, val in pairs( bodyGroups ) do
                bgSliders[ index ]:SetValue( val )
                ent:SetBodygroup( index, val )
            end
        end

        local persona = GLAMBDA:GetProfileInfo( infoTbl, "Personality" )
        usePersona:SetChecked( persona != nil )
        for name, slider in pairs( persSliders ) do
            slider:SetValue( persona and GLAMBDA:GetProfileInfo( persona, name ) or 30 )
        end

        if persona then
            local voiceChan = infoTbl.voice
            if voiceChan then persSliders[ "Speech" ]:SetValue( voiceChan ) end

            local textChan = infoTbl.text
            if textChan then persSliders[ "Texting" ]:SetValue( textChan ) end
        end
        
        --

        plyMdl:OnChange()
        plyPfp:OnChange()
        plyMdlPreview:UpdateColors( plyClr or vector_white )
    end
end

GLAMBDA:CreateConCommand( "panel_profileeditor", OpenProfileEditor, true, "Allows you to create profiles of specific names/players.", {
    name = "Profile Editor", 
    category = "Panels" 
} )