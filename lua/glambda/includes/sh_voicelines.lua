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

--

GLAMBDA.VoiceLines = {}

for _, data in ipairs( GLAMBDA.VoiceTypes ) do
    local lineTbl = GLAMBDA:MergeDirectory( "sound/" .. data.pathCvar:GetString() )
    GLAMBDA.VoiceLines[ data.name ] = lineTbl
end

--

function GLAMBDA:UpdateVoiceData()
    GLAMBDA.VoiceLines = {}
    
    for _, data in ipairs( GLAMBDA.VoiceTypes ) do
        local lineTbl = GLAMBDA:MergeDirectory( "sound/" .. data.pathCvar:GetString() )
        GLAMBDA.VoiceLines[ data.name ] = lineTbl
    end

    --

    GLAMBDA.VoiceProfiles = {}

    local profilePath = "sound/lambdaplayers/voiceprofiles/"
    local _, profileFiles = file.Find( profilePath .. "*", "GAME", "nameasc" )
    for _, profile in ipairs( profileFiles ) do
        local profileTbl = {}
    
        for _, data in ipairs( GLAMBDA.VoiceTypes ) do
            local typeName = data.name
            local typePath = profilePath .. profile .. "/" .. typeName .. "/"
    
            local voicelines = file.Find( typePath .. "*", "GAME", "nameasc" )
            if !voicelines or #voicelines == 0 then continue end
    
            local lineTbl = GLAMBDA:MergeDirectory( typePath )
            profileTbl[ typeName ] = lineTbl
        end
    
        GLAMBDA.VoiceProfiles[ profile ] = profileTbl
    end
end
GLAMBDA:UpdateVoiceData()