{ Combat-map and battlefield tile rendering.

  This overlay owns the arena occupancy arrays, maps arena coordinates into the seven-by-seven viewport, draws terrain
  and creature sprites, scrolls the view, probes movement destinations, and animates downed creatures. Palette entry
  points are intentionally empty. Rendering is guarded by actorVisible. }
{$O+,F+}
unit CbtMap;

interface

uses Types, Blit, GameIo, Crt, MapTiles, SoundDrv, TextRend, GDConsts, GDVars, C_Status, C_Ifc,
  C_Dir;

{ Empty routine with no callers. }
procedure NoopCbtMap;

{ Finds where one tile of a creature icon lies relative to the icon's upper-left cell.
  @param(size The icon size; 0 for no icon.)
  @param(idx The tile, 0 to 3.)
  @param(dx Receives the tile's column offset; left as it was for size 0.)
  @param(dy Receives the tile's row offset; left as it was for size 0.)
  @returns(True when the icon uses the tile; False for size 0 or an unused tile, whose column offset is negative.) }
function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;

{ Empty: the palette is left as it is for combat. }
procedure SetCombatPalette;

{ Empty: the palette is left as it is after combat. }
procedure SetNoncombatPalette;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure DrawCursorCell(x, y: ShortInt);

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.) }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuilds the arena's creature-index grid: clears it, then for each creature with a nonzero icon size marks every cell
  its icon covers with the creature's combat slot and recomputes the creature's view coordinates. }
procedure BuildArenaArrays;

{ Looks up what lies on an arena cell.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(crIdx Receives the combat slot of the creature standing there; 0 for none or outside the arena.)
  @param(terrIdx Receives the cell's terrain; 0 outside the arena.) }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(crIdx The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(cr The creature.)
  @param(whole Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(cr: Types.PCharRecord; whole: Byte): Boolean;

{ Targets the arena cell one step in the given direction from a cell and redraws the whole view if needed
  (BuildViewBuffer), redrawing each visible icon of a creature in play after a full redraw. Then redraws the cell, draws
  the cursor at the target (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(delta How far the target may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(dir Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; delta, dir: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or `frame` or
  `eraseOnly` is nonzero. It stores the new facing and, unless `eraseOnly` is set, draws its sprite and flushes when it
  is visible and the map shows.
  @param(cr The creature.)
  @param(dir The new facing, 0 to 7.)
  @param(frame The animation frame to draw.)
  @param(eraseOnly Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(cr: Types.PCharRecord; dir, frame, eraseOnly: Byte);

{ Finds a creature's arena column.
  @param(cr The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(cr: Types.PCharRecord): ShortInt;

{ Finds a creature's arena row.
  @param(cr The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(cr: Types.PCharRecord): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(cr The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(cr: Types.PCharRecord): Byte;

{ Finds a combatant's combat slot. Note: with no combatants, or more than 72, the search runs past the end of the table.
  @param(cr The combatant.)
  @returns(The slot, or 0 if it is not in the fight.) }
function CombatSlot(cr: Types.PCharRecord): Byte;

{ Probes the cells one step in the given direction from each of the creature's icon tiles.
  @param(cr The creature.)
  @param(dir The direction, 0 to 7; 8 probes the creature's own cells.)
  @param(crIdx Receives an adjacent creature's combat slot (0 for none); the creature itself is ignored and the last one
    found wins.)
  @param(terrIdx Receives the dominant terrain: 0 (off the arena) beats everything, otherwise the highest cost wins (the
    later tile on a tie), starting from terrain 23 at cost 1. Stinking clouds and cloudkill do not compete, and once it
    is 0 later cells set no cloud flags.)
  @param(adjStink Receives 1 when a probed cell holds a stinking cloud, else 0.)
  @param(adjCloudkill Receives 1 when a probed cell holds cloudkill, else 0.) }
procedure ProbeDirection(cr: Types.PCharRecord; dir: Byte; var crIdx, terrIdx, adjStink, adjCloudkill: Byte);

{ Handles a creature going down. Outside combat it plays the downed sound and pauses. In combat it scrolls the creature
  wholly into view, flashes the skull sprite over it, records a body for the party side and marks its cell as a corpse
  (28 for a petrified creature, else 30) unless the cell holds a stinking cloud, removes the icon, refreshes the view's
  center cell (ScrollView), and clears the creature's initiative, movement, casting and guarding. Note: the check for an
  already recorded body tests downed[frame] with frame not yet set, so it finds one only when that entry happens to hold
  the creature.
  @param(cr The creature that went down.) }
procedure CreatureDowned(cr: Types.PCharRecord);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell (icon size from the low 7 bits of iconDimensions), probes its own cells and rejects the place, zeroing the icon
  size, on any creature, terrain 0 or impassable terrain. On success with moving set for a party-side creature, it
  clears the creature's body entries and, unless another body lies on the cell, writes into it the terrain its last body
  covered, or the probed terrain when it has no body entry or the body covered a corpse cell (28 or 30). The creature
  grid is then refilled.
  @param(cr The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(moving True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(cr: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView toward its own cell) when the combat map shows, drawing the cursor over
  its icon footprint when `cursor` is set; afterwards the cursor is off with size 1.
  @param(cr The creature.)
  @param(delta How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(cursor True to draw the cursor.) }
procedure DisplayMapViewCentered(cr: Types.PCharRecord; delta: Byte; cursor: Boolean);

implementation

function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  if size = 0 then Exit;
  dx := GDConsts.iconDelta[size, idx].dx;
  dy := GDConsts.iconDelta[size, idx].dy;
  if dx >= 0 then
    GetIconTileDelta := True;
end;

procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaCount do begin
    GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arenaPtr^.ox;
    GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arenaPtr^.oy;
  end;
end;

procedure SetCombatPalette;
begin
end;

procedure SetNoncombatPalette;
begin
end;

procedure DrawCursorCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
  for i := 0 to 3 do
    if CbtMap.GetIconTileDelta(GDVars.arenaPtr^.cursorSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        MapTiles.Copy2DTile((relX + tdx) * 3, (relY + tdy) * 3,
                            GDConsts.terrainInfo[GDVars.arenaPtr^.cells[y + tdy, x + tdx]].id, 0);
        if GDVars.arenaPtr^.cursorOn then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, 25);
      end;
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatures[c]^.combatAddr^.direction, 0,
                                  GDVars.creatures[c]^.orderNumber);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  c: Byte;
  t: Byte;
begin
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatures[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatures[c]^.combatAddr^.direction, 0,
                                  GDVars.creatures[c]^.orderNumber);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  GameIo.FillWord(GDVars.creatureIndexGrid, SizeOf(GDVars.creatureIndexGrid));
  for i := 1 to GDVars.arenaCount do
    if GDVars.arenaLoc[i].size > 0 then begin
      for j := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[i].size, j, tdx, tdy) then
          GDVars.creatureIndexGrid[GDVars.arenaLoc[i].y + tdy, GDVars.arenaLoc[i].x + tdx] := i;
      GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arenaPtr^.ox;
      GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arenaPtr^.oy;
    end;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrIdx := GDVars.arenaPtr^.cells[y, x];
    crIdx := GDVars.creatureIndexGrid[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);
var
  absX: ShortInt;
  absY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  t: Byte;
  size: Byte;
begin
  if crIdx = 0 then begin
    absX := x + GDVars.arenaPtr^.ox;
    absY := y + GDVars.arenaPtr^.oy;
    CbtMap.GetArenaContents(absX, absY, crIdx, t);
  end;
  if crIdx > 0 then begin
    x := GDVars.gridX[crIdx];
    y := GDVars.gridY[crIdx];
    absX := x + GDVars.arenaPtr^.ox;
    absY := y + GDVars.arenaPtr^.oy;
    size := GDVars.arenaLoc[crIdx].size;
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          MapTiles.Copy2DTile((x + tdx) * 3, (y + tdy) * 3,
                              GDConsts.terrainInfo[GDVars.arenaPtr^.cells[absY + tdy, absX + tdx]].id, 0);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GDConsts.terrainInfo[GDVars.arenaPtr^.cells[absY, absX]].id, 0);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(cr: Types.PCharRecord; whole: Byte): Boolean;
var
  i: Byte;
  slot: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: Integer;
begin
  CombatIconVisible := True;
  slot := CbtMap.CombatSlot(cr);
  if GDVars.arenaLoc[slot].size = 0 then
    CombatIconVisible := False
  else
    for i := 0 to 3 do
      if CbtMap.GetIconTileDelta(GDVars.arenaLoc[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then begin
          CombatIconVisible := False;
          if whole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if whole = 0 then Exit;
        end;
end;

{ Recenters the 7x7 view on a target cell when it lies farther from the view center than allowed, keeping the view
  inside the arena, then draws the view's terrain and recomputes the creatures' view coordinates.
  @param(x Arena column of the target.)
  @param(y Arena row of the target.)
  @param(delta How far the target may lie from the view center; 255 forces a redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  d: Byte;
  pixX: ShortInt;
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  viewOffset: Integer;
begin
  BuildViewBuffer := False;
  cX := GDVars.arenaPtr^.ox + 3;
  cY := GDVars.arenaPtr^.oy + 3;
  d := delta;
  if delta = 255 then
    d := 0;
  minX := cX - d;
  maxX := cX + d;
  minY := cY - d;
  maxY := cY + d;
  if (delta <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < 46) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < 21) do Inc(cY);
  GDVars.arenaPtr^.ox := cX - 3;
  GDVars.arenaPtr^.oy := cY - 3;
  pixY := 0;
  cY := GDVars.arenaPtr^.oy;
  for j := 0 to 6 do begin
    pixX := 0;
    cX := GDVars.arenaPtr^.ox;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixX, pixY, GDConsts.terrainInfo[GDVars.arenaPtr^.cells[cY, cX]].id, 0);
      Inc(pixX, 3);
      Inc(cX);
    end;
    Inc(pixY, 3);
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, dir: Byte);
var
  p: Types.PCharRecord;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GDConsts.dirDx[dir];
  ty := y + GDConsts.dirDy[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then
    for i := 1 to GDVars.arenaCount do begin
      p := GDVars.creatures[i];
      if (p^.enabled <> 0) and (GDVars.arenaLoc[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.gridX[i], GDVars.gridY[i], p^.combatAddr^.direction, 0, p^.orderNumber);
    end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.arenaPtr^.ox, ty - GDVars.arenaPtr^.oy) then begin
    if tx > 49 then tx := 49;
    if tx < 0 then tx := 0;
    if ty > 24 then ty := 24;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Blit.FlushView;
end;

procedure SetCreatureFacing(cr: Types.PCharRecord; dir, frame, eraseOnly: Byte);
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(cr);
  if not CbtMap.CombatIconVisible(cr, 1) then
    if GDVars.actorVisible then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
  if (cr^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    if GDVars.actorVisible then
      CbtMap.UpdateCombatMapTile(0, 0, slot);
  cr^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(cr, 0) then
      if GDVars.actorVisible then begin
        MapTiles.DrawIconAnimSprite(GDVars.gridX[slot], GDVars.gridY[slot], dir, frame, cr^.orderNumber);
        Blit.FlushView;
      end;
end;

function CombatCellX(cr: Types.PCharRecord): ShortInt;
begin
  CombatCellX := GDVars.arenaLoc[CbtMap.CombatSlot(cr)].x;
end;

function CombatCellY(cr: Types.PCharRecord): ShortInt;
begin
  CombatCellY := GDVars.arenaLoc[CbtMap.CombatSlot(cr)].y;
end;

function GetIconSize(cr: Types.PCharRecord): Byte;
begin
  GetIconSize := GDVars.arenaLoc[CbtMap.CombatSlot(cr)].size;
end;

function CombatSlot(cr: Types.PCharRecord): Byte;
var
  found: Boolean;
  i: Byte;
begin
  found := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.creatures[i] = cr then
      found := True;
  until found or (i = GDVars.arenaCount);
  if found then
    CombatSlot := i;
end;

procedure ProbeDirection(cr: Types.PCharRecord; dir: Byte; var crIdx, terrIdx, adjStink, adjCloudkill: Byte);
var
  i: Byte;
  slot: Byte;
  c: Byte;
  t: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  crIdx := 0;
  terrIdx := 23;
  best := 1;
  adjStink := 0;
  adjCloudkill := 0;
  slot := CbtMap.CombatSlot(cr);
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  for i := 0 to 3 do
    if CbtMap.GetIconTileDelta(GDVars.arenaLoc[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GDConsts.dirDx[dir];
      ny := y + tdy + GDConsts.dirDy[dir];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = slot then
        c := 0;
      if c > 0 then
        crIdx := c;
      if (t = 0) or (terrIdx = 0) then
        terrIdx := 0
      else
        case t of
          29: adjStink := 1;
          27: adjCloudkill := 1;
        else
          if GDConsts.terrainInfo[t].cost >= best then begin
            best := GDConsts.terrainInfo[t].cost;
            terrIdx := t;
          end;
        end;
    end;
end;

procedure CreatureDowned(cr: Types.PCharRecord);
var
  slot: Byte;
  k: Byte;
  frame: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: Integer;
begin
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then begin
    SoundDrv.SoundCommand(GDConsts.downedSound);
    TextRend.PauseOnly;
  end else begin
    k := 1;
    { Note: this indexes downed[frame], not the loop counter k, and frame is unassigned here. }
    while (k < 9) and (GDVars.downed[frame].cr <> cr) do
      Inc(k);
    if k < 9 then Exit;
    slot := CbtMap.CombatSlot(cr);
    cellX := CbtMap.CombatCellX(cr);
    cellY := CbtMap.CombatCellY(cr);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, C_Dir.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    SoundDrv.SoundCommand(GDConsts.downedSound);
    for frame := 0 to 8 do begin
      for k := 0 to 3 do
        if CbtMap.GetIconTileDelta(GDVars.arenaLoc[slot].size, k, tdx, tdy) then
          if CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then
            Blit.BlitTileClipped((GDVars.gridX[slot] + tdx) * 3, (GDVars.gridY[slot] + tdy) * 3, 0, 5,
                                 GDVars.iconAnims[24, frame mod 2], GDVars.viewBuf);
      Blit.FlushView;
      Delay(10);
    end;
    if cr^.combatAddr^.notPcNpc = 0 then begin
      Inc(GDVars.downedCount);
      GDVars.downed[GDVars.downedCount].terrain := GDVars.arenaPtr^.cells[cellY, cellX];
      if GDVars.arenaPtr^.cells[cellY, cellX] <> 29 then
        if cr^.status = C_Status.PETRIFIED then
          GDVars.arenaPtr^.cells[cellY, cellX] := 28
        else
          GDVars.arenaPtr^.cells[cellY, cellX] := 30;
      GDVars.downed[GDVars.downedCount].cr := cr;
      GDVars.downed[GDVars.downedCount].x := cellX;
      GDVars.downed[GDVars.downedCount].y := cellY;
    end;
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GDVars.arenaLoc[CbtMap.CombatSlot(cr)].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
    cr^.combatAddr^.initiativeV2 := 0;
    cr^.combatAddr^.movementV1 := 0;
    cr^.combatAddr^.spellCastV1 := 0;
    cr^.combatAddr^.guardingV1 := 0;
  end;
end;

function IsValidCreatureLoc(cr: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  found: Boolean;
  adjStink: Byte;
  adjCloudkill: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(cr);
    GDVars.arenaLoc[slot].size := cr^.iconDimensions and $7F;
    GDVars.arenaLoc[slot].x := x;
    GDVars.arenaLoc[slot].y := y;
    CbtMap.ProbeDirection(cr, C_Dir.CENTER, c, t, adjStink, adjCloudkill);
    if (c <> 0) or (t = 0) or (GDConsts.terrainInfo[t].cost = 255) then
      GDVars.arenaLoc[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if cr^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.downed[i].cr = cr then begin
              if (GDVars.downed[i].terrain <> 30) and (GDVars.downed[i].terrain <> 28) then
                t := GDVars.downed[i].terrain;
              GameIo.FillWord(GDVars.downed[i], SizeOf(GDVars.downed[i]));
            end;
          found := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.downed[i].cr <> nil) and (GDVars.downed[i].x = x)
               and (GDVars.downed[i].y = y) then
              found := True;
          if not found then
            GDVars.arenaPtr^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(cr: Types.PCharRecord; delta: Byte; cursor: Boolean);
begin
  GDVars.arenaPtr^.cursorOn := cursor;
  GDVars.arenaPtr^.cursorSize := GDVars.arenaLoc[CbtMap.CombatSlot(cr)].size;
  if GDVars.actorVisible then
    CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), delta, C_Dir.CENTER);
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
end;

procedure NoopCbtMap;
begin
end;

begin
end.
