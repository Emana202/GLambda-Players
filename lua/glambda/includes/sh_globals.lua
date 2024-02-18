function GLAMBDA:MergeDirectory( dir, tbl )
    if dir[ #dir ] != "/" then dir = dir .. "/" end
    tbl = ( tbl or {} )

    local files, dirs = file.Find( dir .. "*", "GAME", "nameasc" )    
    if files then  
        for _, fileName in ipairs( files ) do tbl[ #tbl + 1 ] = dir .. fileName end
    end
    if dirs then
        for _, addDir in ipairs( dirs ) do self:MergeDirectory( dir .. addDir, tbl ) end
    end

    return tbl
end

--

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

    function GLAMBDA:GetRandomPlayerModel()
        local mdlTbl = self.PlayerModels
        local mdlList = mdlTbl.Default
    
        local defCount = #mdlList
        local mdlCount = defCount
        if self:GetConVar( "player_addonplymdls" ) then
            if self:GetConVar( "player_onlyaddonpms" ) then
                mdlList = mdlTbl.Addons
                return mdlList[ math.random( #mdlList ) ]
            end
            
            mdlCount = ( mdlCount + #mdlTbl.Addons )
        end
    
        local mdlIndex = math.random( mdlCount )
        if mdlIndex > defCount then
            mdlIndex = ( mdlIndex - defCount )
            mdlList = mdlTbl.Addons
        end
        
        return mdlList[ mdlIndex ]
    end

    --

    GLAMBDA.ProfilePictures = GLAMBDA:MergeDirectory( "materials/lambdaplayers/custom_profilepictures/" )

    function GLAMBDA:GetProfilePictures( rnd )
        local pfps = self.ProfilePictures
        if rnd then return ( pfps[ math.random( #pfps ) ] ) end
        return pfps
    end

end