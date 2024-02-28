local IsValid                                        = IsValid
local CurTime                                        = CurTime
local isvector                                       = isvector
local RandomPairs                                    = RandomPairs
local VectorRand                                     = VectorRand
local GetNavArea                                     = navmesh.GetNavArea
local IsNavmeshLoaded                                = navmesh.IsLoaded
local FindNavAreas                                   = navmesh.Find
local band                                           = bit.band

-- Truly, one of the function locals of all time

-- CNavArea --
local CNavAreaMeta                                   = FindMetaTable( "CNavArea" )
local CNavArea_GetCenter                             = CNavAreaMeta.GetCenter
local CNavArea_GetRandomPoint                        = CNavAreaMeta.GetRandomPoint
local CNavArea_GetAdjacentAreas                      = CNavAreaMeta.GetAdjacentAreas
local CNavArea_GetLaddersAtSide                      = CNavAreaMeta.GetLaddersAtSide
local CNavArea_ClearSearchLists                      = CNavAreaMeta.ClearSearchLists
local CNavArea_AddToOpenList                         = CNavAreaMeta.AddToOpenList
local CNavArea_SetCostSoFar                          = CNavAreaMeta.SetCostSoFar
local CNavArea_SetTotalCost                          = CNavAreaMeta.SetTotalCost
local CNavArea_UpdateOnOpenList                      = CNavAreaMeta.UpdateOnOpenList
local CNavArea_IsOpenListEmpty                       = CNavAreaMeta.IsOpenListEmpty
local CNavArea_PopOpenList                           = CNavAreaMeta.PopOpenList
local CNavArea_AddToClosedList                       = CNavAreaMeta.AddToClosedList
local CNavArea_GetCostSoFar                          = CNavAreaMeta.GetCostSoFar
local CNavArea_IsOpen                                = CNavAreaMeta.IsOpen
local CNavArea_IsClosed                              = CNavAreaMeta.IsClosed
local CNavArea_RemoveFromClosedList                  = CNavAreaMeta.RemoveFromClosedList
local CNavArea_ComputeAdjacentConnectionHeightChange = CNavAreaMeta.ComputeAdjacentConnectionHeightChange
local CNavArea_GetAttributes                         = CNavAreaMeta.GetAttributes
local CNavArea_HasAttributes                         = CNavAreaMeta.HasAttributes

-- CNavLadder --
local CNavLadderMeta                                 = FindMetaTable( "CNavLadder" )
local CNavLadder_GetLength                           = CNavLadderMeta.GetLength
local CNavLadder_GetTopForwardArea                   = CNavLadderMeta.GetTopForwardArea
local CNavLadder_GetTopLeftArea                      = CNavLadderMeta.GetTopLeftArea
local CNavLadder_GetTopRightArea                     = CNavLadderMeta.GetTopRightArea
local CNavLadder_GetTopBehindArea                    = CNavLadderMeta.GetTopBehindArea
local CNavLadder_GetBottomArea                       = CNavLadderMeta.GetBottomArea

-- Vector --
local VectorMeta                                     = FindMetaTable( "Vector" )
local GetDistTo                                      = VectorMeta.Distance
local GetDistToSqr                                   = VectorMeta.DistToSqr

-- Entity --
local EntityMeta                                     = FindMetaTable( "Entity" )
local ENT_GetPos                                     = EntityMeta.GetPos
local ENT_Health                                     = EntityMeta.Health
local ENT_GetGravity                                 = EntityMeta.GetGravity

-- Player --
local PlayerMeta                                     = FindMetaTable( "Player" )
local PLY_GetStepSize                                = PlayerMeta.GetStepSize
local PLY_GetJumpPower                               = PlayerMeta.GetJumpPower

--

-- Gets a random position within the distance.
function GLAMBDA.Player:GetRandomPos( dist, pos )
    pos = ( pos or ENT_GetPos( self:GetPlayer() ) )
    dist = ( dist or 1500 )

    if IsNavmeshLoaded() then
        local areas = FindNavAreas( pos, dist, dist, dist )
        for _, area in RandomPairs( areas ) do
            if !self:IsAreaTraversable( area ) then continue end
            return CNavArea_GetRandomPoint( area )
        end
    end
    return ( pos + VectorRand( -dist, dist ) )
end

--

local crouchWalkPenalty = 5
local jumpPenalty = 15
local ladderPenalty = 20
local avoidPenalty = 100

-- The cost functor function the path finding will use to, well, pathfind
function GLAMBDA.Player:PathGenerator( sqrDist )
    local navi = self:GetNavigator()
    local ply = self:GetPlayer()

    --

    local gravity = ENT_GetGravity( ply )
    if gravity == 0 then gravity = 1 end

    local svGrav = ( GLAMBDA:GetConVar( "sv_gravity" ) / 600 )
    gravity = ( ( gravity + svGrav ) / 2 )

    local maxSafeFallHeight = ( 240 * gravity )
    local fatalFallHeight = ( 720 * gravity )
    local damageForFall = ( 100 / ( fatalFallHeight - maxSafeFallHeight ) )

    --

    local stepH = PLY_GetStepSize( ply )
    local jumpH = ( ( PLY_GetJumpPower( ply ) * 0.225 ) / gravity )
    local thirdHealth = ( ENT_Health( ply ) * 0.4 )

    --

    return function( area, fromArea, ladder, elevator, length )
        if !IsValid( fromArea ) then return 0 end

        local dist = 0
        if IsValid( ladder ) then
            return -1 -- For now...
            -- dist = CNavLadder_GetLength( ladder )
            -- if sqrDist then dist = ( dist * dist ) end
            -- dist = ( dist * ladderPenalty )
        else
            if length > 0 then
                dist = length
            elseif sqrDist then
                dist = GetDistToSqr( CNavArea_GetCenter( fromArea ), CNavArea_GetCenter( area ) )
            else
                dist = GetDistTo( CNavArea_GetCenter( fromArea ), CNavArea_GetCenter( area ) )
            end

            local deltaZ = CNavArea_ComputeAdjacentConnectionHeightChange( fromArea, area )
            if deltaZ > stepH then
                if deltaZ > jumpH then return -1 end
                dist = ( dist * jumpPenalty )
            else
                local fallDmg = ( ( -deltaZ - maxSafeFallHeight ) * damageForFall )
                if fallDmg > 0 then
                    if fallDmg >= thirdHealth then return -1 end
                    dist = ( dist * ( fallDmg * 2 ) )
                end
            end
        end
        
        local attributes = CNavArea_GetAttributes( area )
        if band( attributes, NAV_MESH_AVOID ) != 0 then
            dist = ( dist * avoidPenalty )
        end
        if band( attributes, NAV_MESH_WALK ) != 0 or band( attributes, NAV_MESH_CROUCH ) != 0 then
            dist = ( dist * crouchWalkPenalty )
        end
        
        local cost = ( CNavArea_GetCostSoFar( fromArea ) + dist )
        return cost
    end
end

--

-- Using the A* algorithm and navmesh, finds out if we can reach the given area
-- Was created because base CLuaLocomotion's 'IsAreaTraversable' seems to be broken
-- Not recommended to use in loops with large tables
-- The 'area' and 'startArea' variables can be either a vector or a navmesh area
function GLAMBDA.Player:IsAreaTraversable( area, startArea, pathGenerator )
    if isvector( area ) then area = GetNavArea( area, 120 ) end
    if !IsValid( area ) then return false end

    if !startArea then
        startArea = GetNavArea( ENT_GetPos( self:GetPlayer() ), 120 )
    elseif isvector( startArea ) then 
        startArea = GetNavArea( startArea, 120 )
    end
    if !IsValid( startArea ) then return false end

    if area == startArea then return true end
    pathGenerator = ( pathGenerator or self:PathGenerator( true ) )

    CNavArea_ClearSearchLists( startArea )
    CNavArea_AddToOpenList( startArea )
    CNavArea_SetCostSoFar( startArea, 0 )

    local areaPos = CNavArea_GetCenter( area )
    CNavArea_SetTotalCost( startArea, GetDistToSqr( CNavArea_GetCenter( startArea ), areaPos ) )
    CNavArea_UpdateOnOpenList( startArea )

    while ( !CNavArea_IsOpenListEmpty( startArea ) ) do
        local curArea = CNavArea_PopOpenList( startArea )
        if curArea == area then return true end

        local ladderList
        local searchIndex = 1
        local searchLadders = false
        local ladderUp = true
        local ladderTopDir = 0
        local floorList = CNavArea_GetAdjacentAreas( curArea )

        while ( true ) do
            local newArea, ladder

            if !searchLadders then
                if searchIndex > #floorList then
                    searchLadders = true
                    ladderList = CNavArea_GetLaddersAtSide( curArea, 0 )

                    searchIndex = 1
                    continue
                end

                newArea = floorList[ searchIndex ]
                searchIndex = ( searchIndex + 1 )
            else
                if searchIndex > #ladderList then
                    if !ladderUp then break end
                    ladderUp = false
                    ladderList = CNavArea_GetLaddersAtSide( curArea, 1 )
                    searchIndex = 1
                    continue
                end

                ladder = ladderList[ searchIndex ]
                if ladderUp then
                    if ladderTopDir == 0 then
                        newArea = CNavLadder_GetTopForwardArea( ladder )
                    elseif ladderTopDir == 1 then
                        newArea = CNavLadder_GetTopLeftArea( ladder )
                    elseif ladderTopDir == 2 then
                        newArea = CNavLadder_GetTopRightArea( ladder )
                    elseif ladderTopDir == 3 then
                        newArea = CNavLadder_GetTopBehindArea( ladder )
                    else
                        searchIndex = ( searchIndex + 1 )
                        ladderTopDir = 0
                        continue
                    end

                    ladderTopDir = ( ladderTopDir + 1 )
                else
                    newArea = CNavLadder_GetBottomArea( ladder )
                    searchIndex = ( searchIndex + 1 )
                end
            end
            if !IsValid( newArea ) or newArea == curArea then continue end

            local newCostSoFar = pathGenerator( newArea, curArea, ladder, nil, -1 )
            if !isnumber( newCostSoFar ) then
                newCostSoFar = math.huge
            elseif newCostSoFar < 0 then
                continue
            end

            if ( CNavArea_IsOpen( newArea ) or CNavArea_IsClosed( newArea ) ) and CNavArea_GetCostSoFar( newArea ) <= newCostSoFar then continue end
            CNavArea_SetCostSoFar( newArea, newCostSoFar )
            CNavArea_SetTotalCost( newArea, newCostSoFar + GetDistToSqr( CNavArea_GetCenter( newArea ), areaPos ) )

            if CNavArea_IsClosed( newArea ) then
                CNavArea_RemoveFromClosedList( newArea )
            end

            if CNavArea_IsOpen( newArea ) then
                CNavArea_UpdateOnOpenList( newArea )
            else
                CNavArea_AddToOpenList( newArea )
            end
        end

        CNavArea_AddToClosedList( curArea )
    end

    return false
end