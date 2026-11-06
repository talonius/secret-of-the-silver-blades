{ Image-buffer display, animation loading, portraits, and Show3DSprite. }
{$O+,F+,I-}
unit Portrait;

interface

uses Types, Blit, Border, GameIo, DaxIo, Mouse, TextRend, Crt, GDConsts, GDVars;

{ Shows a picture at a character cell with the mouse cursor hidden: an animation frame is drawn clipped into the view
  buffer one cell up and left and the view flushed to the screen, any other picture is drawn straight to the screen.
  Nothing happens for nil.
  @param(col Character column.)
  @param(row Character row.)
  @param(anim True to draw through the view buffer.)
  @param(pic The picture.) }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

{ Draws a portrait head straight to the screen.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(pic The head picture; nil draws nothing.) }
procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);

{ Draws a portrait body straight to the screen, five character rows below the head drawn at the same cell.
  @param(col Column of the head's upper-left character cell.)
  @param(row Row of the head's upper-left character cell.)
  @param(pic The body picture; nil draws nothing.) }
procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);

{ Loads picture picId of <name><disk>.DAX into an animation, one image buffer per frame, freeing what the animation
  held; nothing happens when that picture is the one last loaded, or for picId 255. SPRIT always comes from disk 1, and
  a few PIC pictures from disk 4 or 5. PIC and FINAL pictures store each frame after the first as an XOR difference from
  it, and load only their first frame while animations are off. A frame is skipped when less than 3900 bytes of heap are
  free. Outside CGA, frames with a mask are recolored through remapFrom and remapTo. 'Loading...Please Wait' shows
  meanwhile when animations are on, and 'PIC not found' when the picture is missing.
  @param(name Base name of the DAX file.)
  @param(picId Picture number within the file.)
  @param(transp Bit 0 gives the frames a transparency mask.)
  @param(a Receives the frames.) }
procedure LoadAnimation(name: Types.TStr8; picId, transp: Byte; var a: Types.TAnimRec);

{ Frees each frame of an animation record, clears the record and forgets the last loaded picture.
  @param(a The animation record.) }
procedure FreeAnimation(var a: Types.TAnimRec);

{ Draws the loaded portrait head straight to the screen at a character cell and, when asked, the body five character
  rows below it.
  @param(col Character column of the head.)
  @param(row Character row of the head.)
  @param(both True to draw the body as well, False for the head alone.) }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

{ Loads a portrait head from HEAD<disk>.DAX and a body from BODY<disk>.DAX into the portrait slots, skipping an id of
  255 or one already loaded, then drains pending keystrokes. Note: a missing body also reports "head not found".
  @param(headId Head picture number.)
  @param(bodyId Body picture number.) }
procedure LoadPortraitBufs(headId, bodyId: Byte);

{ Draws a 3D sprite frame transparently into the view buffer at its origin and flushes the view. A distance outside 1 to
  3 restores the video mode, prints an error and exits to DOS.
  @param(dist The view distance, 1 to 3, which is also the frame drawn.)
  @param(a The sprite's animation record; a missing frame draws nothing.) }
procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);

{ Frees the big animation, then loads a picture from BIGPIC<disk>.DAX into the big picture buffer unless it is the one
  already loaded.
  @param(picId Picture number.) }
procedure LoadBigPic(picId: Byte);

{ Draws the base frame (Border.ScreenText) and shows the big picture at cell (1, 1), with the mouse cursor hidden. }
procedure DisplayBigPic;

implementation

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
  if pic <> nil then
    if anim then begin
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, pic, GDVars.viewBuf);
      Mouse.HideMouse;
      Blit.FlushView;
      Mouse.ShowMouse;
    end else begin
      Mouse.HideMouse;
      Blit.ShowPic(col, row, pic);
      Mouse.ShowMouse;
    end;
end;

procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row, False, pic);
end;

procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row + 5, False, pic);
end;

procedure LoadAnimation(name: Types.TStr8; picId, transp: Byte; var a: Types.TAnimRec);
var
  sz: Word;
  buf: Types.PByteArr;
  readOfs: Word;
  f: Byte;
  h: Word;
  w: Word;
  diskCh: String[1];
  xorBuf: Types.PByteArr;
  j: Word;
  planeSz: Word;
  isPic: Boolean;
  gotXor: Boolean;
  loaded: Byte;
begin
  if ((name = GDVars.picArcName) and (picId = GDVars.picArcId)) or (picId = 255) then Exit;
  if GDVars.animOn <> 0 then begin
    TextRend.PrintSpaces(0, 24, 0, 40);
    TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  end;
  Portrait.FreeAnimation(a);
  GDVars.picArcName := name;
  GDVars.picArcId := picId;
  isPic := (name = 'PIC') or (name = 'FINAL');
  Str(LongInt(GDVars.diskNum), diskCh);
  if name = 'SPRIT' then diskCh := '1';
  if name = 'PIC' then
    if (picId = 6) or (picId = 59) or (picId = 60) or (picId = 66) or (picId = 69) or (picId = 71) or
        (picId = 89) then
      diskCh := '4';
  if name = 'PIC' then
    if (picId = 1) or (picId = 17) or (picId = 77) or (picId = 27) then
      diskCh := '5';
  DaxIo.LoadDax(name + diskCh, '.dax', picId, sz, buf);
  if sz = 0 then begin
    TextRend.DisplayAndPause(Yellow, 0, 'PIC not found');
    Exit;
  end;
  readOfs := 0;
  gotXor := False;
  with a do begin
    count := buf^[readOfs];
    Inc(readOfs);
    curFrame := 1;
    loaded := 0;
    if (GDVars.animOn = 0) and isPic then count := 1;
    for f := 1 to count do begin
      Move(buf^[readOfs], frames[f].delay, SizeOf(frames[f].delay));
      Inc(readOfs, 4);
      Move(buf^[readOfs], h, SizeOf(h));
      Inc(readOfs, 2);
      Move(buf^[readOfs], w, SizeOf(w));
      Inc(readOfs, 2);
      if MaxAvail >= 3900 then begin
        Inc(loaded);
        Blit.AllocPic(h, w, 1, transp, frames[f].pic);
        with frames[f].pic^ do begin
          Move(buf^[readOfs], originX, SizeOf(originX));
          Inc(readOfs, 2);
          Move(buf^[readOfs], originY, SizeOf(originY));
          Inc(readOfs, 3);
          Move(buf^[readOfs], map, SizeOf(map));
          Inc(readOfs, 8);
        end;
        if GDVars.displayMode = Types.Cga then
          planeSz := frames[f].pic^.imgSize * 2 - 1
        else
          planeSz := frames[f].pic^.imgSize - 1;
        if isPic then
          if f = 1 then begin
            GetMem(xorBuf, planeSz + 1);
            Move(buf^[readOfs], xorBuf^, planeSz + 1);
            gotXor := True;
          end else
            for j := readOfs to readOfs + planeSz do
              buf^[j] := buf^[j] xor xorBuf^[j - readOfs];
        Blit.ExpandPicFrames(buf, readOfs, Boolean(transp), 0, frames[f].pic);
        if (transp and 1 > 0) and (GDVars.displayMode <> Types.Cga) then
          Blit.RemapPic(GDConsts.remapFrom, GDConsts.remapTo, 0, False, frames[f].pic);
        Inc(readOfs, planeSz + 1);
      end else
        count := 1;
    end;
    count := loaded;
  end;
  if isPic and gotXor then FreeMem(xorBuf, planeSz + 1);
  FreeMem(buf, sz);
  GameIo.FlushKeys;
  if GDVars.animOn <> 0 then TextRend.PrintSpaces(0, 24, 0, 40);
end;

procedure FreeAnimation(var a: Types.TAnimRec);
begin
  with a do
    for GDVars.loopIdx := 1 to count do
      Blit.FreePic(frames[GDVars.loopIdx].pic);
  GameIo.FillWord(a, SizeOf(a));
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
end;

procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.diskNum), diskCh);
  if headId <> 255 then
    if (GDVars.portraits[1].fileId = 255) or (GDVars.portraits[1].fileId <> headId) then begin
      Blit.LoadPic('HEAD' + diskCh, headId, False, 0, GDVars.portraits[1].pic);
      if GDVars.portraits[1].pic = nil then TextRend.DisplayAndPause(Yellow, 0, 'head not found');
      GDVars.portraits[1].fileId := headId;
    end;
  if bodyId <> 255 then
    if (GDVars.portraits[2].fileId = 255) or (GDVars.portraits[2].fileId <> bodyId) then begin
      Blit.LoadPic('BODY' + diskCh, bodyId, False, 0, GDVars.portraits[2].pic);
      if GDVars.portraits[2].pic = nil then TextRend.DisplayAndPause(Yellow, 0, 'head not found');
      GDVars.portraits[2].fileId := bodyId;
    end;
  GameIo.FlushKeys;
end;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
  if both then begin
    Portrait.DisplayPortraitHead(col, row, GDVars.portraits[1].pic);
    Portrait.DisplayPortraitBody(col, row, GDVars.portraits[2].pic);
  end else
    Portrait.DisplayImageBuf(col, row, False, GDVars.portraits[1].pic);
end;

procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);
begin
  if (dist < 1) or (dist > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame;
  end;
  if a.frames[dist].pic <> nil then
    with a.frames[dist].pic^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, a.frames[dist].pic, GDVars.viewBuf)
  else
    Exit;
  Blit.FlushView;
end;

procedure LoadBigPic(picId: Byte);
var
  diskCh: String[1];
begin
  Portrait.FreeAnimation(GDVars.animData);
  if GDVars.bigPicId = picId then Exit;
  Str(LongInt(GDVars.diskNum), diskCh);
  Blit.LoadPic('bigpic' + diskCh, picId, False, 0, GDVars.bigPicBuf);
  GDVars.bigPicId := picId;
end;

procedure DisplayBigPic;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  Blit.ShowPic(1, 1, GDVars.bigPicBuf);
  Mouse.ShowMouse;
end;

begin
end.
