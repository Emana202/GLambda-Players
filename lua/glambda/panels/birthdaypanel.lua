local months = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
}

local function OpenBirthdayPanel( ply )
    local frame = GLAMBDA.PANEL:Frame( "Birthday Date Setup", 350, 100 )
    GLAMBDA.PANEL:Label( "Changes are saved when you close the panel!", frame, TOP )

    local box = GLAMBDA.PANEL:ComboBox( frame, LEFT, months, true )
    box:SetSize( 120, 5 )
    box:Dock( LEFT )
    box:SetSortItems( false )
    box:SetValue( "Select a Month" )

    local day = GLAMBDA.PANEL:NumSlider( frame, LEFT, 0, "Week Day", 1, 31, 0 )
    day:SetSize( 200, 5 )
    day:Dock( RIGHT )

    local birthdayData = GLAMBDA.FILE:ReadFile( "glambda/plybirthday.json", "json" )
    if birthdayData then    
        box:SelectOptionByKey( birthdayData.month )
        day:SetValue( birthdayData.day )
    end

    function frame:OnClose() 
        local _, month = box:GetSelected()
        if !month or #month == 0 then return end

        local weekDay = math.floor( day:GetValue() )
        LAMBDAFS:UpdateKeyValueFile( "glambda/plybirthday.json", { month = month, day = weekDay }, "json" ) 
        GLAMBDA:SendNotification( nil, "Changed the birthday date!", NOTIFY_HINT, nil, "buttons/button15.wav" )

        net.Start( "glambda_setupbirthday" )
            net.WriteString( month )
            net.WriteUInt( weekDay, 5 ) 
        net.SendToServer()
    end
end

GLAMBDA:CreateConCommand( "panel_plybirthday", OpenBirthdayPanel, true, "Allows you to set your birthday date, making player bots to mention it in their messages once the date has come.", {
    name = "Birthday Date", 
    category = "Panels" 
} )