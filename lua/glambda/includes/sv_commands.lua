concommand.Add( "glacebase_kickallbots", function()
    for k, v in ipairs( player.GetBots() ) do
        v:Kick()
    end
end )