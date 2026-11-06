{ Combat tile, icon, and 24-by-24 sprite-set loading.

  The loader allocates image sets, expands DAX data, applies optional color remapping, and serves animated combat
  sprites. }
{$O+,F+,I-}
unit MapTiles;

interface

uses Blit, GameIo, GDConsts, GDVars, Types;

{ Empty routine with no callers. }
procedure NoopMapTiles;

{ Loads a picture of 24x24 map tiles and copies the given number of its tiles into tile-set buffer 1 from the given slot
  on, then drains pending keystrokes. A slot above 48 is a fatal error, reported in text mode.
  @param(name Base name of the DAX file.)
  @param(fileId Picture number within the file.)
  @param(slot First tile slot written.)
  @param(count Number of tiles copied.) }
procedure Load24x24Set(name: string; fileId, slot, count: Byte);

{ Draws a 24x24 map tile into the view buffer at a character cell. Tiles 0..127 come from tile-set buffer 1, tiles 128
  and up from tile-set buffer 2.
  @param(col Character column.)
  @param(row Character row.)
  @param(tile Tile number.)
  @param(flag Drawing flags passed to the tile blitter; bit 0 draws through the mask.) }
procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);

{ Frees both frames of an icon animation slot.
  @param(animIdx The slot.) }
procedure FreeIconAnim(animIdx: Byte);

{ Loads the two frames of an icon animation, picture fileId and fileId + 128, with black transparent. For CHEAD and
  CBODY files the last letter of the name is a size letter: it is dropped, and T adds 64 to fileId. COMSPR and ICON are
  loaded as named. Any other name gets the current disk number appended (1 for CPIC), and outside CGA both frames are
  recolored from color 8 to color 0. Pending keystrokes are flushed afterwards.
  @param(name Base name of the DAX file.)
  @param(fileId Picture number of the first frame.)
  @param(animIdx Slot receiving the frames.) }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

{ Draws one frame of an icon animation into the view buffer, clipped, at three character cells per map cell, mirrored
  for facings past southeast. Nothing is drawn if the frame is not loaded.
  @param(col Map column.)
  @param(row Map row.)
  @param(facing Direction the icon faces.)
  @param(frame Frame to draw, 0 or 1.)
  @param(animIdx Animation slot.) }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

const
  TILE_ID_MASK = $7F;

procedure Load24x24Set(name: string; fileId, slot, count: Byte);
var
  pic: Types.PImgBuf;
  total: Word;
  destOfs: Word;
begin
  if slot > 48 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame;
  end;
  pic := nil;
  Blit.LoadPic(name, fileId, False, 0, pic);
  total := count * pic^.imgSize;
  destOfs := slot * pic^.imgSize;
  if GDVars.tileSet1 <> nil then
    Move(pic^.data, GDVars.tileSet1^.data[destOfs], total);
  Blit.FreePic(pic);
  GameIo.FlushKeys;
end;

procedure Copy2DTile(col, row: ShortInt; tile, flag: Byte);
begin
  if tile > MapTiles.TILE_ID_MASK then
    Blit.BlitTileCell(col, row, tile and MapTiles.TILE_ID_MASK, flag, GDVars.tileSet2, GDVars.viewBuf)
  else
    Blit.BlitTileCell(col, row, tile, flag, GDVars.tileSet1, GDVars.viewBuf);
end;

procedure FreeIconAnim(animIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Integer;
begin
  if GDVars.iconAnims[animIdx, 0] <> nil then
    Blit.FreePic(GDVars.iconAnims[animIdx, 0]);
  if GDVars.iconAnims[animIdx, 1] <> nil then
    Blit.FreePic(GDVars.iconAnims[animIdx, 1]);
end;

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
var
  suffix: string[1];
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnims[animIdx, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') then begin
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnims[animIdx, 1]);
  end else begin
    Str(GDVars.diskNum, suffix);
    if name = 'CPIC' then
      suffix := '1';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.iconAnims[animIdx, 0]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmap8To0, 0, False, GDVars.iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.iconAnims[animIdx, 1]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmap8To0, 0, False, GDVars.iconAnims[animIdx, 1]);
  end;
  GameIo.FlushKeys;
end;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if GDVars.iconAnims[animIdx, frame] = nil then
    Exit;
  with GDVars.iconAnims[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > 3 then
      Blit.MirrorPic(GDVars.iconAnims[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      Move(transp^, work^.transp^, imgSize);
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.viewBuf);
  Blit.FreePic(work);
end;

procedure NoopMapTiles;
begin
end;

begin
end.
