{ Game initialization 2: item and sprite graphics loading.

  InitializeGame sets the display mode, waits, turns on Num Lock, optionally re-homes the mouse cursor and region,
  allocates the seven work buffers, builds the three per-mode screen segment tables, primes the sprite-descriptor
  arrays, runs the field-init block, shows the 'Loading...Please Wait' banner, then opens the ITEMS dax and reads it.

  ResetGameState is the re-entry path: it clears the video buffers again and re-runs the field-init block (a
  near-duplicate of InitializeGame' tail with a handful of different seed values). }
{$O+,F+}
{$I-}
unit GameInit;

interface

uses Types, Blit, GameIo, Crt, DaxIo, MapTiles, Mouse, EffHndlr, Magic, MenuCore, Sym8x8, TextRend, GDConsts, GDVars,
  C_Dir, C_Ifc, C_Video, C_Pic;

{ One-time startup: sets the display mode's video mode, forces Num Lock on, seeds Random, starts the mouse (checking
  whether its driver reports 640-wide coordinates) or centers the joystick cursor, allocates the memory zones, font,
  wall graphics, map and the persistent picture buffers, builds the per-scanline CGA, EGA and Tandy address tables, and
  sets the game variables to their starting values. It then loads the font, the 8x8 symbol sets, the combat sprites and
  the sky pictures (not on CGA), reads the base item table from ITEMS, and installs the spell and effect handlers. }
procedure InitializeGame;

{ Returns the game state to its starting values for a new game, keeping the buffers and artwork InitializeGame loaded:
  enables the save on a heap failure, clears the dirty spans and the memory zones, places the party at its starting cell
  facing east, and resets the flags, counters and pointers that a game changes. }
procedure ResetGameState;

implementation

var
  { the four bytes after the debug log's file record, cleared at start-up }
  debugFileTail: LongInt absolute GDVars.debugFileTail;

procedure InitializeGame;
var
  { Unused in this version; see the other implementations of this routine. }
  inputLine: String;
  { BIOS keyboard shift flags }
  kbFlag: Byte absolute $0000:$0417;
begin
  case GDVars.displayMode of
    Types.Cga: Blit.SetVideoMode(4);
    Types.Ega: Blit.SetVideoMode(13);
    Types.Tandy: Blit.SetVideoMode(9);
  end;
  Delay(2000);
  kbFlag := kbFlag or $20;
  Randomize;
  if GDVars.mouseOn then begin
    GDVars.rosterMouseOn := 1;
    GDVars.buttonCount := 0;
    Mouse.InitMouse;
    if GDVars.mouseOn then begin
      GDVars.mouseScaled := True;
      if GDVars.displayMode = Types.Cga then
        GDVars.cursorMask := @GDConsts.cursorMaskCga
      else
        GDVars.cursorMask := @GDConsts.cursorMaskHi;
      { pass the stored far-pointer value }
      Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.mouseBtn, GDVars.mouseRawX, GDVars.mouseRawY);
      GDVars.mouseScaled := (GDVars.mouseRawX >= 321) = False;
      Mouse.ShowMouse;
    end;
    GDVars.mouseX := 160;
    GDVars.mouseY := 100;
    Mouse.SetMouse(GDVars.mouseX, GDVars.mouseY);
    GDVars.mouseOldX := 0;
    GDVars.mouseOldY := 0;
  end;
  if GDVars.joyOn then begin
    GDVars.joyCursorX := 160;
    GDVars.joyCursorY := 100;
  end;
  GetMem(GDVars.zone0, SizeOf(GDVars.zone0^));
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  GetMem(GDVars.zone2, SizeOf(Types.TZone2));
  GetMem(GDVars.zone3, SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, 1416);
  GetMem(GDVars.wallDefs, SizeOf(GDVars.wallDefs^));
  GetMem(GDVars.geo, SizeOf(GDVars.geo^));
  Blit.AllocPic(8, 1, 1, 0, GDVars.workPic);
  Blit.AllocPic(8, 1, 1, 0, GDVars.cursorBackground);
  Blit.AllocPic(8, 1, 1, 0, GDVars.cursorComposite);
  debugFileTail := 0;
  Blit.AllocPic(168, 21, 1, 0, GDVars.viewBuf);
  Blit.AllocPic(24, 3, 1, 0, GDVars.saveUnder);
  GameIo.FillWord(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.FillWord(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.FillWord(GDVars.spanY, SizeOf(GDVars.spanY));
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), $FF);
  GameIo.FillWord(GDVars.spanX1, SizeOf(GDVars.spanX1));
  case GDVars.displayMode of
    Types.Cga:
      for GDVars.gI := 0 to 199 do
        if Odd(GDVars.gI) then
          GDVars.cgaRowSeg[GDVars.gI] := C_Video.GFX_BANK1_SEG + (GDVars.gI div 2) * 5
        else
          GDVars.cgaRowSeg[GDVars.gI] := C_Video.GFX_BANK0_SEG + (GDVars.gI div 2) * 5;
    Types.Ega:
      begin
        GDVars.rowOfs := 0;
        for GDVars.gI := 0 to 199 do begin
          GDVars.fbRowOfs[GDVars.gI] := GDVars.rowOfs;
          Inc(GDVars.rowOfs, 40);
        end;
      end;
    Types.Tandy:
      begin
        GDVars.gI := 0;
        GDVars.rowOfs := 0;
        while GDVars.gI <= 199 do begin
          GDVars.tandyRowSeg[GDVars.gI] := GDVars.rowOfs + C_Video.GFX_BANK0_SEG; Inc(GDVars.gI);
          GDVars.tandyRowSeg[GDVars.gI] := GDVars.rowOfs + C_Video.GFX_BANK1_SEG; Inc(GDVars.gI);
          GDVars.tandyRowSeg[GDVars.gI] := GDVars.rowOfs + C_Video.GFX_BANK2_SEG; Inc(GDVars.gI);
          GDVars.tandyRowSeg[GDVars.gI] := GDVars.rowOfs + C_Video.GFX_BANK3_SEG; Inc(GDVars.gI);
          GDVars.rowOfs := GDVars.rowOfs + 10;
        end;
      end;
  end;
  GameIo.FillWord(GDVars.gfxSet, SizeOf(GDVars.gfxSet));
  GameIo.FillWord(GDVars.tileSet1, SizeOf(GDVars.tileSet1) + SizeOf(GDVars.tileSet2));
  Blit.AllocPic(24, 3, 48, 0, GDVars.tileSet1);
  GameIo.FillWord(GDVars.zone0^, SizeOf(GDVars.zone0^));
  GDVars.zone0^.difficulty := 2;
  GDVars.zone0^.view3dFlag := 1;
  GDVars.zone0^.prevEcl := 0;
  GameIo.FillWord(GDVars.zone1^, SizeOf(GDVars.zone1^));
  GameIo.FillWord(GDVars.zone2^, SizeOf(Types.TZone2));
  GameIo.FillWord(GDVars.zone3^, SizeOf(Types.TZone3));
  GameIo.FillWord(GDVars.iconAnims, SizeOf(GDVars.iconAnims));
  for GDVars.gI := 1 to 2 do begin
    GDVars.portraits[GDVars.gI].fileId := 255;
    GDVars.portraits[GDVars.gI].pic := nil;
  end;
  GameIo.FillWord(GDVars.animData, SizeOf(GDVars.animData));
  GDVars.bigPicBuf := nil;
  GDVars.treasureItems := nil;
  GameIo.FillWord(GDVars.partyPos, SizeOf(GDVars.partyPos));
  GDVars.partyPos.mapX := 7;
  GDVars.partyPos.mapY := 13;
  GDVars.partyPos.facing := C_Dir.NORTH;
  FillChar(GDVars.bashOffered, SizeOf(GDVars.bashOffered) + SizeOf(GDVars.pickOffered) + SizeOf(GDVars.knockOffered),
           1);
  GDVars.wallSetCache[1].defId := 0;
  GDVars.wallSetCache[1].symSet := 1;
  for GDVars.gI := 2 to 3 do begin
    GDVars.wallSetCache[GDVars.gI].defId := -1;
    GDVars.wallSetCache[GDVars.gI].symSet := -1;
  end;
  GDVars.heapFailureSaveEnabled := 0;
  GDVars.soundGuard := 0;
  GDVars.animOn := 1;
  GDVars.picsOn := 1;
  GDVars.debugOn := False;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.redrawChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.demoMode := False;
  GDVars.diskNum := 5;
  GDVars.savedDiskNum := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^.partySize := 0;
  GDVars.menuTop := 1;
  GDVars.duelFlag := 0;
  GDVars.restActive := 0;
  GDVars.searchBak := 0;
  GDVars.boxCleared := 0;
  GDVars.printRetFlag := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := 0;
  GDVars.initFlag := 1;
  GDVars.sprShown := False;
  GDVars.suppressInsertPrompt := #0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPicArcName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.savedPicArcId := 255;
  GDVars.gameSaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := 0;
  GDVars.selOverride := 0;
  GDVars.actorVisible := True;
  GDVars.bigPicId := 255;
  GDVars.newCharTraining := 0;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.INDOORS;
  GDVars.savedInterface := 0;
  GDVars.soundActive := 1;
  GDVars.overrideFlag := 0;
  GDVars.rosterLock := 0;
  GDVars.skyPic1 := nil;
  GDVars.skyPic2 := nil;
  GDVars.skyPic3 := nil;
  GDVars.needPanelRedrawTail := 0;
  GDVars.inMoveMenu := 0;
  GDVars.aimActive := 0;
  GDVars.moveMode := 0;
  GDVars.mouseClk := False;
  GDVars.modifyMenuActive := 0;
  GDVars.agingFlag := 0;
  TextRend.LoadGameFont;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  for GDVars.gI := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.gI, GDVars.gI + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  if GDVars.displayMode <> Types.Cga then begin
    Blit.LoadPic('sky', 250, True, C_Pic.TRANSPARENT_COLOR, GDVars.skyPic1);
    Blit.LoadPic('sky', 251, True, C_Pic.TRANSPARENT_COLOR, GDVars.skyPic2);
    Blit.LoadPic('sky', 252, True, C_Pic.TRANSPARENT_COLOR, GDVars.skyPic3);
  end;
  GDVars.itemsOpened := DaxIo.OpenWithRetry('ITEMS', GDConsts.diskPath[GDVars.diskNum], #0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  { Note: this asks for 129 records into the 128-record table; ITEMS holds 128 after its header, so the read stops one
    record short and itemsRead is never inspected. }
  BlockRead(GDVars.itemsFile, GDVars.baseItems, 129 * SizeOf(Types.TBaseItem), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;
end;

procedure ResetGameState;
begin
  GDVars.heapFailureSaveEnabled := 1;
  GDVars.soundGuard := 0;
  GameIo.FillWord(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.FillWord(GDVars.spanY, SizeOf(GDVars.spanY));
  FillChar(GDVars.spanX0, SizeOf(GDVars.spanX0), $FF);
  GameIo.FillWord(GDVars.spanX1, SizeOf(GDVars.spanX1));
  GameIo.FillWord(GDVars.zone0^, SizeOf(GDVars.zone0^));
  GDVars.zone0^.difficulty := 2;
  GDVars.zone0^.view3dFlag := 1;
  GDVars.zone0^.prevEcl := 0;
  GameIo.FillWord(GDVars.zone1^, SizeOf(GDVars.zone1^));
  GameIo.FillWord(GDVars.zone2^, SizeOf(Types.TZone2));
  GameIo.FillWord(GDVars.zone3^, SizeOf(Types.TZone3));
  GameIo.FillWord(GDVars.partyPos, SizeOf(GDVars.partyPos));
  GDVars.partyPos.mapX := 7;
  GDVars.partyPos.mapY := 13;
  GDVars.partyPos.facing := C_Dir.EAST;
  FillChar(GDVars.bashOffered, SizeOf(GDVars.bashOffered) + SizeOf(GDVars.pickOffered) + SizeOf(GDVars.knockOffered),
           1);
  GDVars.rosterMouseOn := 1;
  GDVars.wallSetCache[1].defId := 0;
  GDVars.wallSetCache[1].symSet := 1;
  for GDVars.gI := 2 to 3 do begin
    GDVars.wallSetCache[GDVars.gI].defId := -1;
    GDVars.wallSetCache[GDVars.gI].symSet := -1;
  end;
  GDVars.debugOn := False;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.redrawChar := nil;
  GDVars.eclIp := $8000;
  GDVars.gameDelay := 4;
  GDVars.diskNum := 1;
  GDVars.savedDiskNum := 1;
  GDVars.automapOn := False;
  LastMode := 1;
  GDVars.zone1^.partySize := 0;
  GDVars.menuTop := 1;
  GDVars.duelFlag := 0;
  GDVars.restActive := 0;
  GDVars.searchBak := 0;
  GDVars.boxCleared := 0;
  GDVars.printRetFlag := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := 0;
  GDVars.initFlag := 1;
  GDVars.sprShown := False;
  GDVars.suppressInsertPrompt := #0;
  GDVars.picArcName[0] := #0;
  GDVars.savedPicArcName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.savedPicArcId := 255;
  GDVars.gameSaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncMenu := 0;
  GDVars.actorVisible := True;
  GDVars.bigPicId := 255;
  GDVars.newCharTraining := 0;
  MenuCore.ClearBottomLine;
  GDVars.horizChoice := 1;
  GDVars.interfaceState := C_Ifc.INDOORS;
  GDVars.savedInterface := 0;
  GDVars.soundActive := 1;
  GDVars.overrideFlag := 0;
  GDVars.needPanelRedrawTail := 0;
  GDVars.inMoveMenu := 0;
  GDVars.aimActive := 0;
  GDVars.moveMode := 0;
  GDVars.mouseClk := False;
  GDVars.selOverride := 0;
  GDVars.modifyMenuActive := 0;
  GDVars.rosterLock := 0;
  GDVars.agingFlag := 0;
  GDVars.returnedFromCharGen := 0;
end;

begin
end.
