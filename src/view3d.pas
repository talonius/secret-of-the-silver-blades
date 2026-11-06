{ Three-dimensional dungeon view and geometry loading.

  The overlay loads WALLDEF art and four-plane geometry maps, selects wall and barrier cells, draws distant-to-near wall
  slices, composes the outdoor or monster backdrop, and provides the automap view. }
{$O+,F+,I-}
unit View3D;

interface

{ Empty routine with no callers. }
procedure NoopThreeDViewA;

{ Stores the four 3D view band colors: sky, the two horizon bands and floor.
  @param(cSky The sky color.)
  @param(cHorz1 The first horizon band's color.)
  @param(cHorz2 The second horizon band's color.)
  @param(cFloor The floor color.) }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Paints the 3D view's background into the view buffer in the recorded colors; CGA uses its own bands. Outside CGA,
  under an open sky (a cell event below $80 and a light cyan sky) it draws the sun (skyPic2) by the clock's hour when
  the party faces east, south or west, and the north sky picture (skyPic1) when it faces north; then it draws the
  horizon picture (skyPic3). }
procedure DrawBackdrop;

{ Reads the wall type on one side of a cell: north and east share one map plane and south and west another, one nibble
  each. Off-map coordinates wrap around the 16x16 map, except in scripts 0 and 80, where they give 0.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The wall type, 0 for none. Note: a facing other than the four compass points leaves it undefined.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a cell. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The two-bit barrier type of the wall there, or 1 when there is no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads a cell's event from the 3D map. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @returns(The cell event.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ Draws the 3D view from a cell, or the automap while it is on. The view is the backdrop, then the walls row by row from
  two cells ahead to the party's own row: fronts, the corners between far fronts, and the side walls. It is flushed to
  the screen.
  @param(x Map column of the party's cell.)
  @param(y Map row of the party's cell.)
  @param(facing The direction the party faces.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Loads a wall-definition block of WALLDEF<disk>.DAX into a wall slot, and into the following slots when the block holds
  several entries. In each filled slot the cache entry is cleared, wall symbols from the first set's last symbol on are
  moved up to the slot's symbol set, and the matching 8x8 symbol set is loaded (for entry n of a multi-entry block, the
  picture numbered ten times the block plus n); the first slot's cache entry is then stamped with the block and the
  slot. A slot outside 1 to 3 does nothing; a missing block, or one that does not fit in slots 1 to 3, restores the
  video mode, reports it, waits for a key and quits. Note: the size check does not count a partial last entry, but the
  copy still copies it, into the slot after the last one counted, which can lie past slot 3.
  @param(fileId The block to load.)
  @param(wsSlot The first slot it fills, 1 to 3.) }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Loads a 3D map block of GEO<disk>.DAX (1026 bytes: a 2-byte header and the four 16x16 planes) and records its id for
  the script; a missing or wrong-sized block reports it, waits for a key and quits.
  @param(mapId The block to load.) }
procedure Load3DMap(mapId: Byte);

{ Empty routine with no callers. }
procedure NoopThreeDViewB;

{ Draws the automap into the view buffer and flushes it: the 11x11 cells around the viewer, kept on the 16x16 map, each
  as the symbol for its walls (symbol 260 plus one bit per side), and the viewer's arrow (symbol 256 plus facing div 2)
  on its cell.
  @param(x The viewer's map column.)
  @param(y The viewer's map row.)
  @param(facing The direction faced: 0, 2, 4 or 6.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);

{ Draws a wall in one perspective form, its width by its height in symbols, clipped to the 11x11 view; symbol 0 is left
  transparent.
  @param(x The view column of its top left symbol.)
  @param(y The view row of its top left symbol.)
  @param(wallType The wall type, an index into the loaded wall graphics.)
  @param(slot The perspective form.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);

{ Tells whether a cell is on the 16x16 map.
  @param(x The map column.)
  @param(y The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(x, y: ShortInt): Boolean;

implementation

uses Blit, Sym8x8, DaxIo, GameIo, GDConsts, GDVars, C_Dir, Types;

procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := 260;
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, 1, 0);
    end;
  end;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + 256, 1, 0);
  Blit.FlushView;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.viewColSky := cSky;
  GDVars.viewColHorz1 := cHorz1;
  GDVars.viewColHorz2 := cHorz2;
  GDVars.viewColFloor := cFloor;
end;

procedure DrawBackdrop;
var
  w: Word;
  baseX: Byte;
  baseY: Byte;
  colW: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowH: Byte;
begin
  if GDVars.displayMode = Types.Cga then begin
    Blit.FillPicRect(2, 16, 11, 43, GDVars.viewColSky, GDConsts.cmapStd, GDVars.viewBuf);
    Blit.FillPicRect(2, 59, 11, 1, GDVars.viewColHorz1, GDConsts.cmapStd, GDVars.viewBuf);
    Blit.FillPicRect(2, 60, 11, 2, 3, GDConsts.cmapStd, GDVars.viewBuf);
    Blit.FillPicRect(2, 62, 11, 42, 3, GDConsts.cmapStd, GDVars.viewBuf);
  end else begin
    Blit.FillPicRect(2, 16, 11, 44, GDVars.viewColSky, GDConsts.cmapStd, GDVars.viewBuf);
    Blit.FillPicRect(2, 60, 11, 2, GDVars.viewColHorz2, GDConsts.cmapStd, GDVars.viewBuf);
    Blit.FillPicRect(2, 62, 11, 42, GDVars.viewColFloor, GDConsts.cmapStd, GDVars.viewBuf);
    if (View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY) < $80) and (GDVars.viewColSky = 11) then begin
      baseX := 2;
      baseY := 2;
      colW := 12;
      rowH := 12;
      w := GDVars.zone0^.clock[$4BC9];
      case w of
        1..5:
          case GDVars.partyPos.facing of
            C_Dir.EAST: Blit.BlitTileClipped(colW - 3, baseY + 5 - w, 0, 1, GDVars.skyPic2, GDVars.viewBuf);
            C_Dir.SOUTH: if w > 2 then
                 Blit.BlitTileClipped(baseX + w - 3, baseY + 5 - w, 0, 1, GDVars.skyPic2, GDVars.viewBuf);
          end;
        13..18:
          case GDVars.partyPos.facing of
            C_Dir.WEST: Blit.BlitTileClipped(baseX, baseY + w - 13, 0, 1, GDVars.skyPic2, GDVars.viewBuf);
            C_Dir.SOUTH: if w < 16 then
                 Blit.BlitTileClipped(baseX + w - 8, baseY + w - 13, 0, 1, GDVars.skyPic2, GDVars.viewBuf);
          end;
      end;
      if GDVars.partyPos.facing = C_Dir.NORTH then
        Blit.BlitTileClipped(baseX, baseY, 0, 1, GDVars.skyPic1, GDVars.viewBuf);
    end;
    Blit.BlitTileClipped(2, 7, 0, 1, GDVars.skyPic3, GDVars.viewBuf);
  end;
end;

procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  cnt: Byte;
begin
  cnt := GDConsts.wallSliceTable.start[slot];
  colLim := GDConsts.wallSliceTable.cols[slot] + x - 1;
  rowLim := GDConsts.wallSliceTable.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (GDVars.wallDefs^.slices[wallType][cnt] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, GDVars.wallDefs^.slices[wallType][cnt], 1, 1);
      Inc(cnt);
    end;
end;

function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > 15) or (x < 0) or (y > 15) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.geo^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.geo^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.geo^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.geo^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.geo^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.geo^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.geo^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.geo^.wallsSW[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.curEclId = 0) or (GDVars.curEclId = 80)) then
    GetMapEvent := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.geo^.events[y][x];
  end;
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  fL: Byte;
  fR: Byte;
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  dxF: Integer;
  dyF: Integer;
  wx: Integer;
  wy: Integer;
  side: Byte;
  symOfs: Integer;
  dist: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slack: Byte;
  prevWall: Byte;
begin
  if GDVars.automapOn then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    fL := (facing + 6) mod 8;
    fB := (facing + 4) mod 8;
    fR := (facing + 2) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirDx[facing];
    dyF := GDConsts.dirDy[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0; prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fR) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[9] + symOfs + 1, GDConsts.wallSliceTable.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[0] + symOfs, GDConsts.wallSliceTable.yRow[0], wallFront,
                                   0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fL], wy - GDConsts.dirDy[fL], fL) <> 0) then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[9] + symOfs + 1, GDConsts.wallSliceTable.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side); Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL]; wy := wy + GDConsts.dirDy[fL];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0; prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, fL) = 0) then
              prevWall := 0;
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[9] + symOfs - 1, GDConsts.wallSliceTable.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[0] + symOfs, GDConsts.wallSliceTable.yRow[0], wallFront,
                                   0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fR], wy - GDConsts.dirDy[fR], fR) <> 0) then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[9] + symOfs - 1, GDConsts.wallSliceTable.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side); Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR]; wy := wy + GDConsts.dirDy[fR];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[1] + symOfs, GDConsts.wallSliceTable.yRow[1],
                                     wallSide, 1)
              else
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[1] + symOfs - 1, GDConsts.wallSliceTable.yRow[1],
                                     wallSide, 1);
            Inc(side); Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL]; wy := wy + GDConsts.dirDy[fL];
          end;
          wx := cxPos; wy := cyPos; side := 0; symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[2] + symOfs, GDConsts.wallSliceTable.yRow[2],
                                     wallSide, 2)
              else
                View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[2] + symOfs + 1, GDConsts.wallSliceTable.yRow[2],
                                     wallSide, 2);
            Inc(side); Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR]; wy := wy + GDConsts.dirDy[fR];
          end;
        end;
        1: begin
          wx := cxPos + GDConsts.dirDx[fL];
          wx := wx + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          wy := wy + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[3] + symOfs, GDConsts.wallSliceTable.yRow[3], wallFront,
                                   3);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[4] + symOfs, GDConsts.wallSliceTable.yRow[4], wallSide,
                                   4);
            Inc(side); Inc(symOfs, 3);
            wx := wx + GDConsts.dirDx[fR]; wy := wy + GDConsts.dirDy[fR];
          end;
          wx := cxPos + GDConsts.dirDx[fR];
          wx := wx + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          wy := wy + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[3] + symOfs, GDConsts.wallSliceTable.yRow[3], wallFront,
                                   3);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[5] + symOfs, GDConsts.wallSliceTable.yRow[5], wallSide,
                                   5);
            Inc(side); Dec(symOfs, 3);
            wx := wx + GDConsts.dirDx[fL]; wy := wy + GDConsts.dirDy[fL];
          end;
        end;
        0: begin
          wx := cxPos + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[6] + symOfs, GDConsts.wallSliceTable.yRow[6], wallFront,
                                   6);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[7] + symOfs, GDConsts.wallSliceTable.yRow[7], wallSide,
                                   7);
            Inc(side); Inc(symOfs, 7);
            wx := wx + GDConsts.dirDx[fR]; wy := wy + GDConsts.dirDy[fR];
          end;
          wx := cxPos + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[6] + symOfs, GDConsts.wallSliceTable.yRow[6], wallFront,
                                   6);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.wallSliceTable.xCol[8] + symOfs, GDConsts.wallSliceTable.yRow[8], wallSide,
                                   8);
            Inc(side); Dec(symOfs, 7);
            wx := wx + GDConsts.dirDx[fL]; wy := wy + GDConsts.dirDy[fL];
          end;
        end;
      end;
      cxPos := cxPos + GDConsts.dirDx[fB];
      cyPos := cyPos + GDConsts.dirDy[fB];
      Dec(dist);
    until dist = 255;
    Blit.FlushView;
  end;
end;

procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  readOfs: Word;
  symOfs: Word;
  row: Byte;
  i: Word;
  col: Integer;
  count: Byte;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (wsSlot < 1) or (wsSlot > 3) then Exit;
  Str(GDVars.diskNum, numStr);
  DaxIo.LoadDax('WALLDEF' + numStr, '.dax', fileId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead div SizeOf(Types.TWallDef) + wsSlot > 4) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load ', fileId, ' from WALLDEF' + numStr + '.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  symOfs := GDConsts.symSetFirst[wsSlot] - GDConsts.symSetFirst[1];
  readOfs := 0;
  i := 1;
  repeat
    Move(data^[readOfs], GDVars.wallDefs^.banks[wsSlot + i - 1], SizeOf(Types.TWallDef));
    Inc(readOfs, SizeOf(Types.TWallDef));
    Inc(i);
  until readOfs >= sizeRead;
  FreeMem(data, sizeRead);
  count := i - 1;
  for i := 1 to count do
    if (wsSlot + i - 1) in [1..3] then begin
      GDVars.wallSetCache[wsSlot + i - 1].defId := -1;
      GDVars.wallSetCache[wsSlot + i - 1].symSet := -1;
      for row := 1 to 5 do
        for col := 0 to 155 do
          if GDVars.wallDefs^.banks[wsSlot + i - 1][row][col] >= GDConsts.symSetLast[0] then
            Inc(GDVars.wallDefs^.banks[wsSlot + i - 1][row][col], symOfs);
      if count > 1 then
        Sym8x8.Load8x8Set(fileId * 10 + i, wsSlot + i - 1)
      else
        Sym8x8.Load8x8Set(fileId, wsSlot + i - 1);
    end;
  GDVars.wallSetCache[wsSlot].defId := fileId;
  GDVars.wallSetCache[wsSlot].symSet := wsSlot;
end;

procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  readOfs: Word;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  Str(GDVars.diskNum, numStr);
  DaxIo.LoadDax('GEO' + numStr, '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> SizeOf(Types.TGeoMap) + 2) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to load geo in Load3DMap.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  readOfs := 2;
  Move(data^[readOfs], GDVars.geo^.wallsNE, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.geo^.wallsSW, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.geo^.events, SizeOf(Types.TGeoPlane));
  Inc(readOfs, SizeOf(Types.TGeoPlane));
  Move(data^[readOfs], GDVars.geo^.barriers, SizeOf(Types.TGeoPlane));
  FreeMem(data, sizeRead);
  GDVars.zone0^.mapId := mapId;
end;

procedure NoopThreeDViewA;
begin
end;

procedure NoopThreeDViewB;
begin
end;

begin
end.
