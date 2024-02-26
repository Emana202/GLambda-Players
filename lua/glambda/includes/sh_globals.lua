if ( SERVER ) then

    GLAMBDA.PlayerModels = ( GLAMBDA.PlayerModels or {
        Default = {
            "models/player/alyx.mdl",
            "models/player/arctic.mdl",
            "models/player/barney.mdl",
            "models/player/breen.mdl",
            "models/player/charple.mdl",
            "models/player/combine_soldier.mdl",
            "models/player/combine_soldier_prisonguard.mdl",
            "models/player/combine_super_soldier.mdl",
            "models/player/corpse1.mdl",
            "models/player/dod_american.mdl",
            "models/player/dod_german.mdl",
            "models/player/eli.mdl",
            "models/player/gasmask.mdl",
            "models/player/gman_high.mdl",
            "models/player/guerilla.mdl",
            "models/player/kleiner.mdl",
            "models/player/leet.mdl",
            "models/player/odessa.mdl",
            "models/player/phoenix.mdl",
            "models/player/police.mdl",
            "models/player/police_fem.mdl",
            "models/player/riot.mdl",
            "models/player/skeleton.mdl",
            "models/player/soldier_stripped.mdl",
            "models/player/swat.mdl",
            "models/player/urban.mdl",
            "models/player/hostage/hostage_01.mdl",
            "models/player/hostage/hostage_02.mdl",
            "models/player/hostage/hostage_03.mdl",
            "models/player/hostage/hostage_04.mdl",
            "models/player/Group01/female_01.mdl",
            "models/player/Group01/female_02.mdl",
            "models/player/Group01/female_03.mdl",
            "models/player/Group01/female_04.mdl",
            "models/player/Group01/female_05.mdl",
            "models/player/Group01/female_06.mdl",
            "models/player/Group01/male_01.mdl",
            "models/player/Group01/male_02.mdl",
            "models/player/Group01/male_03.mdl",
            "models/player/Group01/male_04.mdl",
            "models/player/Group01/male_05.mdl",
            "models/player/Group01/male_06.mdl",
            "models/player/Group01/male_07.mdl",
            "models/player/Group01/male_08.mdl",
            "models/player/Group01/male_09.mdl",
            "models/player/Group02/male_02.mdl",
            "models/player/Group02/male_04.mdl",
            "models/player/Group02/male_06.mdl",
            "models/player/Group02/male_08.mdl",
            "models/player/Group03/female_01.mdl",
            "models/player/Group03/female_02.mdl",
            "models/player/Group03/female_03.mdl",
            "models/player/Group03/female_04.mdl",
            "models/player/Group03/female_05.mdl",
            "models/player/Group03/female_06.mdl",
            "models/player/Group03/male_01.mdl",
            "models/player/Group03/male_02.mdl",
            "models/player/Group03/male_03.mdl",
            "models/player/Group03/male_04.mdl",
            "models/player/Group03/male_05.mdl",
            "models/player/Group03/male_06.mdl",
            "models/player/Group03/male_07.mdl",
            "models/player/Group03/male_08.mdl",
            "models/player/Group03/male_09.mdl",
            "models/player/Group03m/female_01.mdl",
            "models/player/Group03m/female_02.mdl",
            "models/player/Group03m/female_03.mdl",
            "models/player/Group03m/female_04.mdl",
            "models/player/Group03m/female_05.mdl",
            "models/player/Group03m/female_06.mdl",
            "models/player/Group03m/male_01.mdl",
            "models/player/Group03m/male_02.mdl",
            "models/player/Group03m/male_03.mdl",
            "models/player/Group03m/male_04.mdl",
            "models/player/Group03m/male_05.mdl",
            "models/player/Group03m/male_06.mdl",
            "models/player/Group03m/male_07.mdl",
            "models/player/Group03m/male_08.mdl",
            "models/player/Group03m/male_09.mdl",
            "models/player/zombie_soldier.mdl",
            "models/player/p2_chell.mdl",
            "models/player/mossman.mdl",
            "models/player/mossman_arctic.mdl",
            "models/player/magnusson.mdl",
            "models/player/monk.mdl",
            "models/player/zombie_classic.mdl",
            "models/player/zombie_fast.mdl"
        },
        Addons = {}
    } )

    function GLAMBDA:UpdatePlayerModels()
        table.Empty( self.PlayerModels.Addons )
        local blockList = GLAMBDA.FILE:ReadFile( "glambda/pmblocklist.json", "json" )

        for _, mdl in pairs( player_manager.AllValidModels() ) do
            local isDefaultMdl = false
            for _, defMdl in ipairs( self.PlayerModels.Default ) do
                if mdl != defMdl then continue end
                isDefaultMdl = true; break
            end
            if isDefaultMdl then continue end

            if blockList then
                local isBlocked = false
                for k, blockedMdl in ipairs( blockList ) do
                    if mdl != blockedMdl then continue end
                    table.remove( blockList, k )
                    isBlocked = true; break
                end
                if isBlocked then continue end
            end

            self.PlayerModels.Addons[ #self.PlayerModels.Addons + 1 ] = mdl
        end
    end

    function GLAMBDA:GetRandomPlayerModel()
        local mdlTbl = self.PlayerModels
        local mdlList = mdlTbl.Default
    
        local defCount = #mdlList
        local mdlCount = defCount
        if self:GetConVar( "player_addonplymdls" ) then
            if self:GetConVar( "player_onlyaddonpms" ) then
                mdlList = mdlTbl.Addons
                return mdlList[ GLAMBDA:Random( #mdlList ) ]
            end
            
            mdlCount = ( mdlCount + #mdlTbl.Addons )
        end
    
        local mdlIndex = GLAMBDA:Random( mdlCount )
        if mdlIndex > defCount then
            mdlIndex = ( mdlIndex - defCount )
            mdlList = mdlTbl.Addons
        end
        
        return mdlList[ mdlIndex ]
    end

end

--

if ( CLIENT ) then

    function GLAMBDA:InitializeLambda( ply, pfp )
        ply.gb_IsLambdaPlayer = true
        ply.gb_IsVoiceMuted = false

        if !string.EndsWith( pfp, ".vtf" ) then
            pfp = Material( pfp )
        else
            pfp = CreateMaterial( "GLambda_PfpMaterial_" .. pfp, "UnlitGeneric", {
                [ "$baseTexture" ] = pfp,
                [ "$translucent" ] = 1,

                [ "Proxies" ] = {
                    [ "AnimatedTexture" ] = {
                        [ "animatedTextureVar" ] = "$baseTexture",
                        [ "animatedTextureFrameNumVar" ] = "$frame",
                        [ "animatedTextureFrameRate" ] = 10
                    }
                }
            } )

            if !pfp or pfp:IsError() then
                local plyMdl = ply:GetModel()
                pfp = Material( "spawnicons/" .. string.sub( plyMdl, 1, #plyMdl - 4 ) .. ".png" )
            end
        end
        ply.gb_ProfilePicture = pfp
    end

end

--

function GLAMBDA:SendNotification( ply, text, notifyType, length, snd )
    if ( CLIENT ) then
        notification.AddLegacy( text, ( notifyType or 0 ), ( length or 3 ) )
        if snd and #snd != 0 then surface.PlaySound( snd ) end   
    end
    if ( SERVER ) then
        net.Start( "glambda_sendnotify" )
            net.WriteString( text )
            net.WriteUInt( ( notifyType or 0 ), 3 )
            net.WriteFloat( length or 3 )
            net.WriteString( snd or "" )
        net.Send( ply )
    end
end

local rngCalled = 0
function GLAMBDA:Random( min, max, float )
    rngCalled = ( rngCalled + 1 )
    if rngCalled > 32768 then rngCalled = 0 end
    math.randomseed( os.time() + SysTime() + rngCalled )

    if !min and !max then return math.random() end
    return ( float and math.Rand( min, max ) or ( max and math.random( min, max ) or math.random( min ) ) )
end

--

GLAMBDA.VoiceTypes = {}

function GLAMBDA:AddVoiceType( typeName, defPath, voiceDesc )
    local cvar = self:CreateConVar( "voice_path_" .. typeName, defPath, "The filepath for the " .. typeName .. " voice type voicelines.\n" .. voiceDesc, {
        name = string.upper( typeName[ 1 ] ) .. string.sub( typeName, 2, #typeName ) .. " Voice Type",
        category = "Voice Type Paths"
    } )

    self.VoiceTypes[ #self.VoiceTypes + 1 ] = { 
        name = typeName, 
        pathCvar = cvar
    }
end

GLAMBDA:AddVoiceType( "idle",       "lambdaplayers/vo/idle/",       "Played when the player is idle and not panicking and in combat." )
GLAMBDA:AddVoiceType( "taunt",      "lambdaplayers/vo/taunt/",      "Played when the player starts attacking someone and is in combat." )
GLAMBDA:AddVoiceType( "death",      "lambdaplayers/vo/death/",      "Played when the player is killed." )
GLAMBDA:AddVoiceType( "panic",      "lambdaplayers/vo/panic/",      "Played when the player is panicking and running away." )
GLAMBDA:AddVoiceType( "kill",       "lambdaplayers/vo/kill/",       "Played when the player killed someone." )
GLAMBDA:AddVoiceType( "witness",    "lambdaplayers/vo/witness/",    "Played when the player saw someone get killed." )
GLAMBDA:AddVoiceType( "assist",     "lambdaplayers/vo/assist/",     "Played when the player's enemy is killed by someone else." )
GLAMBDA:AddVoiceType( "laugh",      "lambdaplayers/vo/laugh/",      "Played when the player saw someone get killed and plays a laugh taunt." )
GLAMBDA:AddVoiceType( "fall",       "lambdaplayers/vo/fall/",       "Played when the player is falling." )