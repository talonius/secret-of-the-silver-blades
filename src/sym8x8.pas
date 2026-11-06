{ 8x8 symbol and tile display. }
{$O+,F+,I-}
unit Sym8x8;

interface

uses Blit, GameIo, GDConsts, GDVars, C_Pic, Types;

{ Empty routine with no callers. }
procedure NoopSym8x8;

{ Loads an 8x8 symbol set from picture fileId of 8X8D<disk>.DAX (8X8D1 on disk 5) into gfxSet[slotnum], with the
  standard transparent color, then flushes pending keystrokes; the slot goes to the debug log while it is open. A slot
  outside 0..4 does nothing. If the picture cannot be loaded, the error is shown in text mode and the game exits after a
  key. Note: RestoreVideoMode runs twice on that path.
  @param(fileId Picture number within the file.)
  @param(slotnum Symbol set slot, 0..4.) }
procedure Load8x8Set(fileId, slotnum: Byte);

{ Draws 8x8 symbol 1..333, found in its symbol set by number, at a character cell: composited into the view buffer, or
  copied to the 8x8 work buffer and shown on screen at once. Nothing is drawn if its set is not loaded. Symbol 0 and
  334..32767 show an error in text mode and exit after a key. Note: a symbol above 32767 passes every band and the error
  test, so the set index is read uninitialized.
  @param(scrX Character column.)
  @param(scrY Character row.)
  @param(symNum Symbol number.)
  @param(drawFlag Nonzero to draw into the view buffer, 0 to draw straight to the screen.)
  @param(slotIdx Drawing flags for the view buffer; bit 0 draws through the symbol's mask.) }
procedure Put8x8Sym(scrX, scrY: ShortInt; symNum: Word; drawFlag, slotIdx: Byte);

implementation
var
  { debug trace file }
  debugFile: Text absolute GDVars.debugFile;

procedure Load8x8Set(fileId, slotnum: Byte);
var
  numStr: String[1];
  deadStr: String[3];
  { Unused in this version; see the other implementations of this routine. }
  ignoredKey: Integer;
  { Unused in this version; see the other implementations of this routine. }
  pressedKey: Char;
begin
  if GDVars.debugOn then
    WriteLn(debugFile, 'slotnum = ', slotnum);
  if slotnum in [0..4] then begin
    if GDVars.diskNum = 5 then
      numStr := '1'
    else
      Str(GDVars.diskNum, numStr);
    Str(fileId, deadStr);
    Blit.LoadPic('8x8d' + numStr, fileId, True, C_Pic.TRANSPARENT_COLOR, GDVars.gfxSet[slotnum]);
    if GDVars.gfxSet[slotnum] = nil then begin
      Blit.RestoreVideoMode;
      WriteLn('Unable to load ', fileId, ' from 8x8D' + numStr);
      pressedKey := GameIo.ReadGameKey;
      Blit.RestoreVideoMode;
      GameIo.ExitGame;
    end;
    GameIo.FlushKeys;
  end;
end;

procedure Put8x8Sym(scrX, scrY: ShortInt; symNum: Word; drawFlag, slotIdx: Byte);
var
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pressedKey: Char;
begin
  case symNum of
    1..45: slot := 0;
    46..115: slot := 1;
    116..185: slot := 2;
    186..255: slot := 3;
    256..333: slot := 4;
    0, 334..32767:
      begin
        Blit.RestoreVideoMode;
        WriteLn('Bad symbol number in Put8x8Symbol.');
        pressedKey := GameIo.ReadGameKey;
        GameIo.ExitGame;
      end;
  end;
  if GDVars.gfxSet[slot] = nil then
    Exit;
  Dec(symNum, GDConsts.symSetFirst[slot]);
  if drawFlag <> 0 then
    Blit.BlitTileCell(scrX, scrY, Lo(symNum), slotIdx, GDVars.gfxSet[slot], GDVars.viewBuf)
  else begin
    with GDVars.gfxSet[slot]^ do
      Move(data[symNum * imgSize], GDVars.workPic^.data[0], imgSize);
    Blit.ShowPic(scrX, scrY, GDVars.workPic);
  end;
end;

procedure NoopSym8x8;
begin
end;

begin
end.
