GLAMBDA.VoiceTypes = {}

function GLAMBDA:AddVoiceType( typeName, defPath, voiceDesc )
    local cvar = self:CreateConVar( "voice_path_" .. typeName, defPath, voiceDesc, true )

    self.VoiceTypes[ #self.VoiceTypes + 1 ] = { 
        name = typeName, 
        pathCvar = cvar
    }
end

GLAMBDA:AddVoiceType( "idle",       "lambdaplayers/vo/idle/" )
GLAMBDA:AddVoiceType( "taunt",      "lambdaplayers/vo/taunt/" )
GLAMBDA:AddVoiceType( "death",      "lambdaplayers/vo/death/" )
GLAMBDA:AddVoiceType( "panic",      "lambdaplayers/vo/panic/" )
GLAMBDA:AddVoiceType( "kill",       "lambdaplayers/vo/kill/" )
GLAMBDA:AddVoiceType( "witness",    "lambdaplayers/vo/witness/" )
GLAMBDA:AddVoiceType( "assist",     "lambdaplayers/vo/assist/" )
GLAMBDA:AddVoiceType( "fall",       "lambdaplayers/vo/fall/" )
GLAMBDA:AddVoiceType( "laugh",      "lambdaplayers/vo/laugh/" )

--

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