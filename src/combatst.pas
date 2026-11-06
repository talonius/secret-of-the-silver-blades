{ Combat arena construction and battle setup.

  The overlay builds dungeon and wilderness arenas, places combatants and terrain features, tests intervening walls, and
  hands the completed map to the combat renderer. }
{$O+,F+,I-}
unit CombatSt;

interface

uses Types, CbtActs, CharGen, FxEngine, CharHlp, MenuCore, Portrait, View3D, CbtMap, MapTiles, EclTrace, Blit, TextRend,
  GameIo, Crt, GDConsts, GDVars, C_Status, C_Dir, C_Ifc;

{ Sets up a battle: frees the big animation, the portraits and the big picture, shows 'A battle begins...', resets the
  combat state (magic off, a 15-round limit, empty cloud, blast and downed lists), loads the combat tiles and builds the
  arena, creates the creatures' combat records and places every creature, allocates the combat view picture, centers the
  view on the first creature and draws the combat interface. Each creature's condition-8 effects fire; the hostiles'
  hit-point percentage is figured, the interface state becomes combat, and each creature's name and status go to the
  trace display. }
procedure CombatStart;

{ Sets one arena cell in the current dungeon cell's skewed six-by-five block, ignoring cells off the 50x25 arena.
  @param(px Column within the block.)
  @param(py Row within the block.)
  @param(pv The terrain, stored plus 1.) }
procedure PlotCell(px, py, pv: Byte);

{ Decorates the current dungeon cell's floor. It records whether the cell is enclosed: at least one solid wall, no door,
  and no opposed pair of solid walls unless all four are solid. When the caller's map-event decoration flag is set and
  the cell is enclosed, each of its six middle spots that is open floor (terrain 22) has an even chance of becoming
  terrain 26, and each open-floor spot beside such a spot a nine in ten chance of becoming terrain 27. }
procedure DecorateCell;

{ Classifies the edge between a map cell and its neighbor in a direction, from both sides. Off the map it is open on the
  party's row going east or west, otherwise blocked.
  @param(x Map column.)
  @param(y Map row.)
  @param(dir Direction of the neighbor.)
  @returns(0 open, 1 blocked, 3 a wall that can be passed; the two sides' bits combined.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;

implementation

procedure PlotCell(px, py, pv: Byte);
var
  col: ShortInt;
  row: ShortInt;
begin
  col := GDVars.arenaOx * 6 + GDVars.arenaOy * 5 + 21 + px;
  row := (GDVars.arenaOy * 5 + 10) + py;
  if (col >= 0) and (col <= 49) and (row >= 0) and (row <= 24) then
    GDVars.arenaPtr^.cells[row][col] := pv + 1;
end;

procedure DecorateCell;
var
  oi: ShortInt;
  oj: ShortInt;
  mapC: ShortInt;
  mapR: ShortInt;
  featC: ShortInt;
  featR: ShortInt;
  k: Byte;
begin
  GDVars.featureLayout := Ord(((GDVars.qfA = 1) or (GDVars.qfC = 1) or (GDVars.qfD = 1) or (GDVars.qfB = 1)) and
                ((not ((GDVars.qfA = 1) and (GDVars.qfD = 1))) or ((GDVars.qfC = 1) and (GDVars.qfB = 1))) and
                ((not ((GDVars.qfC = 1) and (GDVars.qfB = 1))) or ((GDVars.qfA = 1) and (GDVars.qfD = 1))) and
                ((GDVars.qfA <> 3) and (GDVars.qfC <> 3) and (GDVars.qfD <> 3) and (GDVars.qfB <> 3)));
  for oi := 2 to 3 do
    for oj := 2 to 4 do begin
      mapC := GDVars.arenaOx * 6 + GDVars.arenaOy * 5 + 21 + oi + oj;
      mapR := (GDVars.arenaOy * 5 + 10) + oj;
      if (mapC >= 0) and (mapC <= 49) and (mapR >= 0) and (mapR <= 24) then
        if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[mapR][mapC]].id = 22 then
          if GDVars.featureEvent <> 0 then
            if GDVars.featureLayout <> 0 then
              if FxEngine.RollDice(1, 10) <= 5 then begin
                GDVars.arenaPtr^.cells[mapR][mapC] := 26;
                for k := 1 to 4 do begin
                  featC := GDConsts.featDx[k] + mapC;
                  featR := GDConsts.featDy[k] + mapR;
                  if (featC >= 0) and (featC <= 49) and (featR >= 0) and (featR <= 24) then
                    if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[featR][featC]].id = 22 then
                      if FxEngine.RollDice(1, 10) <= 9 then
                        GDVars.arenaPtr^.cells[featR][featC] := 27;
                end;
              end;
    end;
end;

function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearEdge: Byte;
  farEdge: Byte;
  backDir: Byte;

  { Classifies one side of an edge: 1 solid, 0 open, 3 a door; off the map, east and west on the party's row are open. }
  function GetWallKind(x, y: ShortInt; facing: Byte): Byte;
  begin
    if (x >= 0) and (x <= 15) and (y >= 0) and (y <= 15) then begin
      if View3D.GetBarrierType(x, y, facing) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(x, y, facing) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (y = GDVars.partyPos.mapY) and
          ((facing = C_Dir.EAST) or (facing = C_Dir.WEST)) then GetWallKind := 0 else GetWallKind := 1;
    end;
  end;

begin
  backDir := (dir + 4) mod 8;
  nearEdge := GetWallKind(x, y, dir);
  farEdge := GetWallKind(x + GDConsts.dirDx[dir], y + GDConsts.dirDy[dir], backDir);
  WallBetween := nearEdge or farEdge;
end;

{ Builds the dungeon combat arena from the 13 by 5 dungeon cells around the party: each cell's walls are classified and
  drawn as a skewed six-by-five block of floor and wall terrain, and the cell is decorated (DecorateCell). }
procedure BuildDungeonArena;
var
  mapX: ShortInt;
  mapY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cornerIdx: Integer;

  { Draws the cell's three floor rows and its west wall or door. }
  procedure DrawFloorWestWall;
  var
    j: Byte;
    i: Byte;
  begin
    for i := 2 to 4 do
      for j := 0 to 5 do
        CombatSt.PlotCell(j, i, 22);
    if GDVars.qfB = 1 then begin
      for i := 2 to 4 do begin
        CombatSt.PlotCell(i - 1, i, 4);
        CombatSt.PlotCell(i, i, 3);
        CombatSt.PlotCell(i + 1, i, 13);
      end;
    end else if GDVars.qfB = 3 then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.qfA = 1 then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner by its walls and whether the corner between its neighbors is open. }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    tA: Byte;
    tC: Byte;
    tB: Byte;
    tD: Byte;
    side: Byte;
  begin
    if (CombatSt.WallBetween(mapX, mapY - 1, 6) = 0) and (CombatSt.WallBetween(mapX - 1, mapY,
        0) = 0) then side := 1 else side := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.qfA of
             0: case GDVars.qfB of
                  0: tA := 22;
                  3: tA := 13;
                  1: if side <> 0 then tA := 0 else tA := 13;
                end;
             3, 1: if GDVars.qfB = 0 then begin
                     if side <> 0 then tA := 15 else tA := 5;
                   end else begin
                     if side <> 0 then tA := 18 else tA := 2;
                   end;
           end;
        2: case GDVars.qfA of
             0: tB := 22;
             3: tB := 17;
             1: tB := 5;
           end;
        3: case GDVars.qfB of
             0: if GDVars.qfA = 0 then tC := 22
                else if side <> 0 then tC := 16 else tC := 10;
             3: if side <> 0 then tC := 20 else tC := 7;
             1: if side <> 0 then tC := 1 else tC := 3;
           end;
        4: case GDVars.qfB of
             0, 3: case GDVars.qfA of
                     0: tD := 22;
                     3: tD := 23;
                     1: tD := 10;
                   end;
             1: case GDVars.qfA of
                  0: tD := 13;
                  3: tD := 21;
                  1: tD := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, tA);
    CombatSt.PlotCell(2, 0, tB);
    CombatSt.PlotCell(1, 1, tC);
    CombatSt.PlotCell(2, 1, tD);
  end;

  { Fills the cell's northeast corner (spots 5..6 on rows 0..1) by its walls and its neighbors'. }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    tA: Byte;
    tC: Byte;
    tB: Byte;
    tD: Byte;
    bothOpen: Byte;
    edgeNtoNE: Byte;
    edgeEtoNE: Byte;
  begin
    edgeNtoNE := CombatSt.WallBetween(mapX, mapY - 1, 2);
    edgeEtoNE := CombatSt.WallBetween(mapX + 1, mapY, 0);
    if (edgeNtoNE = 0) and (edgeEtoNE = 0) then bothOpen := 1 else bothOpen := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.qfA of
             0: if edgeNtoNE = 1 then tA := 4 else tA := 22;
             3: tA := 15;
             1: tA := 5;
           end;
        2: if GDVars.qfA = 0 then
             case edgeNtoNE of
               0: tB := 22;
               3: if (GDVars.qfC = 0) and (edgeEtoNE <> 0) then tB := 24 else tB := 1;
               1: if GDVars.qfC = 0 then begin
                    if edgeEtoNE <> 0 then tB := 11 else tB := 7;
                  end else tB := 3;
             end else begin
             if GDVars.qfC <> 0 then tB := 9
             else if edgeEtoNE <> 0 then tB := 5
             else if bothOpen <> 0 then tB := 17 else tB := 19;
           end;
        3: case GDVars.qfA of
             0: tC := 22;
             3: tC := 16;
             1: tC := 10;
           end;
        4: if GDVars.qfA = 0 then begin
             if edgeNtoNE = 0 then tD := 22
             else if GDVars.qfC <> 0 then tD := 4
             else if edgeEtoNE = 0 then tD := 8 else tD := 12;
           end else begin
             if GDVars.qfC <> 0 then tD := 14
             else if edgeEtoNE = 0 then tD := 23 else tD := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, tA);
    CombatSt.PlotCell(6, 0, tB);
    CombatSt.PlotCell(5, 1, tC);
    CombatSt.PlotCell(6, 1, tD);
  end;

begin
  for GDVars.arenaOy := -2 to 2 do
    for GDVars.arenaOx := -6 to 6 do begin
      mapX := GDVars.partyPos.mapX + GDVars.arenaOx;
      mapY := GDVars.partyPos.mapY + GDVars.arenaOy;
      GDVars.qfB := CombatSt.WallBetween(mapX, mapY, 6);
      GDVars.qfA := CombatSt.WallBetween(mapX, mapY, 0);
      GDVars.qfC := CombatSt.WallBetween(mapX, mapY, 2);
      GDVars.qfD := CombatSt.WallBetween(mapX, mapY, 4);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
      GDVars.featureEvent := View3D.GetMapEvent(mapX, mapY) and $40;
      CombatSt.DecorateCell;
    end;
end;

{ Empty routine with no callers. }
procedure NoopCombatStA;
begin
end;

{ Empty routine with no callers. }
procedure NoopCombatStB;
begin
end;

{ Empty routine with no callers. }
procedure NoopCombatStC;
begin
end;

{ Empty routine with no callers. }
procedure NoopCombatStD;
begin
end;

{ Empty routine with no callers. }
procedure NoopCombatStE;
begin
end;

{ Empty: an arena outside the 3D view is left as allocated. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapX: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mapY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: Integer;
begin
end;

{ Loads the dungeon combat tiles (DungCom) in the 3D view, allocates the arena with its cursor off, and builds the
  dungeon or wilderness arena. }
procedure LoadCombatTileSet;
begin
  if GDVars.zone0^.view3dFlag <> 0 then
    MapTiles.Load24x24Set('DungCom', 1, 0, 32);
  New(GDVars.arenaPtr);
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
  GDVars.arenaPtr^.distMode := 0;
  if GDVars.zone0^.view3dFlag <> 0 then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Gives each creature a zeroed combat record after recalculating its stats: creatures past the party's size are marked
  as non-party members, allies face the party's way and hostiles the other way, a friendly non-party creature with no
  morale, or one above 102, takes the zone's morale threshold as a non-player, and each may cast. }
procedure InitCreatureCombatData;
var
  p: Types.PCharRecord;
  cnt: Byte;
  t: Byte;
begin
  p := GDVars.creatureList;
  cnt := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(cnt);
    New(p^.combatAddr);
    GameIo.FillWord(p^.combatAddr^, SizeOf(Types.TCombatRec));
    if cnt > GDVars.zone1^.partySize then p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadrantDirs[GDVars.partyPos.facing div 2];
    if p^.hostile = 1 then p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    t := p^.npc and $7F;
    if (p^.hostile = 0) and (p^.combatAddr^.notPcNpc = 1) and ((t = 0) or (t > 102)) then
      p^.npc := GDVars.zone1^.moraleThreshold + $80;
    p^.combatAddr^.hasSpells := 1;
    p := p^.nextCharAddr;
  end;
end;

{ Tells whether a placement quadrant lies off the 11x6 grid in both coordinates.
  @param(qx Quadrant column.)
  @param(qy Quadrant row.)
  @returns(1 when both are off the grid, else 0.) }
function QuadFullyOff(qx, qy: ShortInt): Byte;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := 0
  else
    QuadFullyOff := 1;
end;

{ Tries to put a creature on a placement square of its team's grid for one ring. The square must be on the grid and
  free; its arena cell, from the same skewed mapping as the dungeon builder, is stored before the probe, and the cell
  must hold no creature and passable terrain.
  @param(slot The creature's combat slot.)
  @param(ex The square's column.)
  @param(ey The square's row.)
  @param(gx The grid's base column.)
  @param(gy The grid's base row.)
  @param(quad The placement ring, 0 to 3.)
  @returns(1 when the creature was placed, which takes the square; 0 otherwise.) }
function TryPlaceAt(slot: Byte; ex, ey, gx, gy: ShortInt; quad: Byte): Byte;
var
  crIdx: Byte;
  terrIdx: Byte;
  adjStink: Byte;
  adjCloudkill: Byte;
begin
  if (ex < 0) or (ey < 0) or (ex > 10) or (ey > 5) or (GDVars.occ[GDVars.sideIx][quad][ey][ex] = 0) then
    TryPlaceAt := 0
  else begin
    GDVars.arenaLoc[slot].x := ex + gx * 6 + gy * 5 + 22;
    GDVars.arenaLoc[slot].y := ey + gy * 5 + 10;
    CbtMap.ProbeDirection(GDVars.creatures[slot], C_Dir.CENTER, crIdx, terrIdx, adjStink, adjCloudkill);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < 255) then begin
      TryPlaceAt := 1;
      GDVars.occ[GDVars.sideIx][quad][ey][ex] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Places a creature by walking its team's quadrant grid outward leg by leg from the team's origin; when the walk leaves
  the grid, it moves on to the next ring through the first open direction of quadrantGlyphs, up to ring 3.
  @param(slot The creature's combat slot.)
  @returns(1 when the creature was placed, else 0.) }
function FindPlacement(slot: Byte): Byte;
var
  placed: Byte;
  firstPass: Byte;
  success: Byte;
  outRange: Byte;
  blocked: Byte;
  state: Byte;
  glyph: Byte;
  dir0: Byte;
  kk: Byte;
  dcx: ShortInt;
  dcy: ShortInt;
  mapX2: ShortInt;
  mapY2: ShortInt;
  mulCounter: Byte;
  mul2: Byte;
  bx0: Byte;
  by0: Byte;
  step: Byte;
  ring: Byte;
  ex1: ShortInt;
  ey1: ShortInt;
  ex: ShortInt;
  ey: ShortInt;
begin
  firstPass := 1;
  success := 0;
  state := 1;
  mulCounter := 0;
  ring := 0;
  bx0 := GDVars.quadrantOx[GDVars.sideIx];
  by0 := GDVars.quadrantOy[GDVars.sideIx];
  repeat
    dir0 := GDConsts.quadrantFacings[GDVars.qId[GDVars.sideIx]][ring] div 2;
    case state of
      1: begin
           dcx := GDConsts.dirDx[GDConsts.quadrantDirs[(dir0 + 2) mod 4]];
           dcy := GDConsts.dirDy[GDConsts.quadrantDirs[(dir0 + 2) mod 4]];
           ex1 := GDConsts.ringStartX[Ord(ring > 0)][dir0] + dcx * mulCounter;
           ey1 := GDConsts.ringStartY[Ord(ring > 0)][dir0] + dcy * mulCounter;
           ex := ex1;
           ey := ey1;
           mul2 := 1;
           state := 2;
           step := 1;
         end;
      2: begin
           dcx := GDConsts.dirDx[GDConsts.quadrantDirs[(dir0 + 1) mod 4]];
           dcy := GDConsts.dirDy[GDConsts.quadrantDirs[(dir0 + 1) mod 4]];
           ex := ex1 + dcx * mul2;
           ey := ey1 + dcy * mul2;
           state := 3;
           Inc(step);
         end;
      3: begin
           dcx := GDConsts.dirDx[GDConsts.quadrantDirs[(dir0 + 3) mod 4]];
           dcy := GDConsts.dirDy[GDConsts.quadrantDirs[(dir0 + 3) mod 4]];
           ex := ex1 + dcx * mul2;
           ey := ey1 + dcy * mul2;
           state := 2;
           Inc(mul2);
           Inc(step);
         end;
    end;
    if (ex < 0) or (ey < 0) or (ex > 10) or (ey > 5) then outRange := 1 else outRange := 0;
    if state > 1 then begin
      if ((outRange <> 0) and (CombatSt.QuadFullyOff(ex, ey) = 0)) or
          (firstPass <> 0) and (step >= GDVars.qCnt[GDVars.sideIx]) or (firstPass = 0) and (step > 11) then begin
        Inc(mulCounter);
        if (GDVars.sideIx = 0) and Odd(GDVars.qId[0]) and (ring = 0) and (mulCounter = 1) then begin
          mapX2 := GDVars.quadrantOx[GDVars.sideIx] + GDVars.partyPos.mapX;
          mapY2 := GDVars.quadrantOy[GDVars.sideIx] + GDVars.partyPos.mapY;
          blocked := 0;
          for kk := 1 to 3 do begin
            glyph := GDConsts.quadrantGlyphs[GDVars.qId[GDVars.sideIx]][kk];
            if CombatSt.WallBetween(mapX2, mapY2, glyph) <> 1 then blocked := 1;
          end;
          if blocked <> 0 then Inc(mulCounter);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    if outRange <> 0 then
      if CombatSt.QuadFullyOff(ex, ey) <> 0 then begin
        placed := 0;
        state := 0;
        while (ring < 3) and (state <> 1) do begin
          Inc(ring);
          mapX2 := GDVars.quadrantOx[GDVars.sideIx] + GDVars.partyPos.mapX;
          mapY2 := GDVars.quadrantOy[GDVars.sideIx] + GDVars.partyPos.mapY;
          glyph := GDConsts.quadrantGlyphs[GDVars.qId[GDVars.sideIx]][ring];
          if CombatSt.WallBetween(mapX2, mapY2, glyph) <> 1 then begin
            bx0 := GDVars.quadrantOx[GDVars.sideIx] + GDConsts.dirDx[glyph];
            by0 := GDVars.quadrantOy[GDVars.sideIx] + GDConsts.dirDy[glyph];
            mulCounter := 0;
            state := 1;
          end;
        end;
        if state <> 1 then success := 1;
      end;
    if outRange = 0 then
      placed := CombatSt.TryPlaceAt(slot, ex, ey, bx0, by0, ring);
  until (placed <> 0) or (success <> 0);
  if success <> 0 then FindPlacement := 0 else FindPlacement := 1;
end;

{ Places every creature in the arena. The party's team starts at the party's cell facing its way, the hostiles the
  zone's monster distance ahead facing back; each team's placement grid is limited to its band. Out-of-play party-side
  creatures become corpses on their cells (28 when petrified, else 30), and a non-party creature that cannot be placed
  is removed from the game. }
procedure PlaceAllCreatures;
var
  px: ShortInt;
  py: ShortInt;
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  slot: Byte;
  qq: Byte;
  qd: Byte;
  cnt2: Byte;
  cnt1: Byte;
begin
  CharHlp.CountTeams;
  cnt1 := 0;
  cnt2 := 0;
  for slot := 1 to 72 do
    GDVars.arenaLoc[slot].size := 0;
  GDVars.arenaCount := 72;
  CbtMap.BuildArenaArrays;
  GDVars.quadrantOx[0] := 0;
  GDVars.quadrantOy[0] := 0;
  GDVars.qId[0] := GDVars.partyPos.facing div 2;
  GDVars.quadrantOx[1] := GDVars.quadrantOx[0] +
    GDConsts.dirDx[GDVars.partyPos.facing] * LongInt(GDVars.zone1^.monsterDist);
  GDVars.quadrantOy[1] := GDVars.quadrantOy[0] +
    GDConsts.dirDy[GDVars.partyPos.facing] * LongInt(GDVars.zone1^.monsterDist);
  GDVars.qId[1] := (GDVars.partyPos.facing + 4) mod 8 div 2;
  p := GDVars.creatureList;
  GDVars.qCnt[0] := 0;
  while p <> nil do begin
    if p^.hostile = 0 then Inc(GDVars.qCnt[0]);
    p := p^.nextCharAddr;
  end;
  GDVars.qCnt[0] := (GDVars.qCnt[0] + 1) div 2;
  GDVars.qCnt[1] := (GDVars.teamCount[1] + 1) div 2;
  for GDVars.sideIx := 0 to 1 do
    for qq := 0 to 3 do begin
      if qq = 1 then qd := 4 else qd := GDVars.qId[GDVars.sideIx];
      for py := 0 to 5 do
        for px := 0 to 10 do
          if (px < GDConsts.zrng[qd][py].lo) or (px > GDConsts.zrng[qd][py].hi) then
            GDVars.occ[GDVars.sideIx][qq][py][px] := 0
          else
            GDVars.occ[GDVars.sideIx][qq][py][px] := 1;
    end;
  slot := 1;
  GDVars.arenaCount := 1;
  prev := GDVars.creatureList;
  p := GDVars.creatureList;
  while p <> nil do begin
    GameIo.DiscardPendingKeys;
    GDVars.creatures[slot] := p;
    GDVars.sideIx := p^.hostile;
    GDVars.arenaLoc[slot].aux := slot;
    GDVars.arenaLoc[slot].size := p^.iconDimensions and 7;
    if CombatSt.FindPlacement(slot) <> 0 then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.arenaLoc[slot].size := 0;
        if p^.combatAddr^.notPcNpc = 0 then begin
          px := GDVars.arenaLoc[slot].x;
          py := GDVars.arenaLoc[slot].y;
          Inc(GDVars.downedCount);
          GDVars.downed[GDVars.downedCount].terrain := GDVars.arenaPtr^.cells[py][px];
          if p^.status = C_Status.PETRIFIED then
            GDVars.arenaPtr^.cells[py][px] := 28
          else
            GDVars.arenaPtr^.cells[py][px] := 30;
          GDVars.downed[GDVars.downedCount].cr := p;
          GDVars.downed[GDVars.downedCount].x := px;
          GDVars.downed[GDVars.downedCount].y := py;
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaCount);
      Inc(cnt2);
    end else begin
      GDVars.arenaLoc[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(cnt1);
        GDVars.creatures[slot] := nil;
        GDVars.curChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaCount);
      end;
    end;
    p := p^.nextCharAddr;
  end;
  prev^.nextCharAddr := nil;
end;

procedure CombatStart;
var
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..10] of Byte;
  p: Types.PCharRecord;
begin
  GDVars.msgDelayFlag := 0;
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.portraits[1].pic);
  Blit.FreePic(GDVars.portraits[2].pic);
  Blit.FreePic(GDVars.bigPicBuf);
  GDVars.bigPicId := 255;
  GDVars.portraits[1].fileId := 255;
  GDVars.portraits[2].fileId := 255;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'A battle begins...');
  GDVars.quickMagic := False;
  GDVars.roundCounter := 0;
  GDVars.roundLimit := 15;
  GDVars.attackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.stinkHead := nil;
  GDVars.blastHead := nil;
  GDVars.cloudkillHead := nil;
  GDVars.lastItem := nil;
  GameIo.FillWord(GDVars.downed, SizeOf(GDVars.downed));
  GDVars.zone1^.allyAttacked := 0;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.iconBuf);
  GDVars.arenaPtr^.ox := CbtMap.CombatCellX(GDVars.creatureList) - 3;
  GDVars.arenaPtr^.oy := CbtMap.CombatCellY(GDVars.creatureList) - 3;
  CharHlp.DisplayCombatInterface;
  p := GDVars.creatureList;
  while p <> nil do begin
    p^.combatAddr^.usedTurnUndead := 0;
    FxEngine.TriggerEffectsWithCondition(8, p);
    p := p^.nextCharAddr;
  end;
  CbtActs.UpdateHostileHpPercent;
  GDVars.inMoveMenu := 0;
  GDVars.aimActive := 0;
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  GDVars.moveMode := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    EclTrace.ShowTrace(Types.PStr(p)^, p^.status, p^.enabled, 0);
    p := p^.nextCharAddr;
  end;
end;

begin
end.
