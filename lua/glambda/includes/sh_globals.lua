local function MergeDirectory( dir, tbl )
    if dir[ #dir ] != "/" then dir = dir .. "/" end

    local files, dirs = file.Find( dir .. "*", "GAME", "nameasc" )    
    if files then  
        for _, fileName in ipairs( files ) do tbl[ #tbl + 1 ] = dir .. fileName end
    end
    if dirs then
        for _, addDir in ipairs( dirs ) do MergeDirectory( dir .. addDir, tbl ) end
    end
end

--

if ( SERVER ) then

    GLAMBDA.PlayerModels = {
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
    }

    function GLAMBDA:UpdatePlayerModels()
        table.Empty( self.PlayerModels.Addons )
        
        for _, mdl in pairs( player_manager.AllValidModels() ) do
            local isDefaultMdl = false
            for _, defMdl in ipairs( self.PlayerModels.Default ) do
                if mdl != defMdl then continue end
                isDefaultMdl = true; break
            end

            if isDefaultMdl then continue end
            self.PlayerModels.Addons[ #self.PlayerModels.Addons + 1 ] = mdl
        end
    end
    GLAMBDA:UpdatePlayerModels()

    --

    GLAMBDA.ProfilePictures = {}
    MergeDirectory( "materials/lambdaplayers/custom_profilepictures/", GLAMBDA.ProfilePictures )

    --

    GLAMBDA.VoiceTypes = {}

    function GLAMBDA:AddVoiceType( typeName, defPath, voiceDesc )
        local cvar = self:CreateConVar( "voice_path_" .. typeName, defPath, voiceDesc, true )

        self.VoiceTypes[ #self.VoiceTypes + 1 ] = { 
            name = typeName, 
            pathCvar = cvar
        }
    end

    GLAMBDA:AddVoiceType( "idle", "npcvoicechat/vo/idle/" )
    GLAMBDA:AddVoiceType( "taunt", "npcvoicechat/vo/taunt/" )
    GLAMBDA:AddVoiceType( "death", "npcvoicechat/vo/death/" )
    GLAMBDA:AddVoiceType( "panic", "npcvoicechat/vo/panic/" )
    GLAMBDA:AddVoiceType( "kill", "npcvoicechat/vo/kill/" )
    GLAMBDA:AddVoiceType( "witness", "npcvoicechat/vo/witness/" )
    GLAMBDA:AddVoiceType( "assist", "npcvoicechat/vo/assist/" )
    GLAMBDA:AddVoiceType( "fall", "npcvoicechat/vo/panic/" )

    --

    GLAMBDA.VoiceLines = {}

    for _, data in ipairs( GLAMBDA.VoiceTypes ) do
        local lineTbl = {}
        GLAMBDA.VoiceLines[ data.name ] = lineTbl
        MergeDirectory( "sound/" .. data.pathCvar:GetString(), lineTbl )
    end

    --
    
    GLAMBDA.UniversalActions = {
        [ "Killbind" ] = function( self )
            if math.random( 150 ) != 1 then return end
            self:Kill()
        end,
        [ "SelectRandomWeapon" ] = function( self )
            if math.random( 3 ) != 1 then return end
            
            if self:InCombat() then
                self:SelectLethalWeapon()
            else
                self:SelectRandomWeapon()
            end
        end,
        [ "Undo" ] = function( self )
            if !self:GetState( "Idle" ) then return end
            self:Timer( "Undo", math.Rand( 0.3, 0.6 ), math.random( 6 ), function()
                self:UndoCommand()
            end )
        end,
    }
    
    function GLAMBDA:AddUniversalAction( uaName, func )
        self.UniversalActions[ uaName ] = func
    end

end