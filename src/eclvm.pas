{ The ECL virtual machine: the opcode handlers, the dispatcher, and the per-frame game loop. }
{$O+,F+,A-,I-,V-}
unit EclVm;

interface

uses Types, GDConsts, GDVars, C_Ifc, C_Class, EclMenu, Combat, CharGen, SaveLoad,
  ViewChar, GameTime, Money, FxEngine, CharHlp, ClassCal, MenuCore, MapView, Portrait, View3D, MapTiles, EclTrace,
  Explore, Camp, PostCbt, Vault, Shop, Temple, Border, TextRend, DaxIo, GameIo, Mouse, SoundDrv, Crt, MapCurs;

{ Runs the game from the current ECL block until the party is destroyed: loads the block (the start block, the demo's,
  or the one last entered), runs its entry script, and in the demo removes the party at once. Otherwise it repeats the
  map menu: Encamp enters camp and Look searches through the block's search script, then the block's run script, the
  party's step (ResolveMovement) with the step sound when the party moved, and the search script again; a NEWECL from
  any script loads the next block through NewEclDone. The party is removed at the end. }
procedure GameLoop;

implementation

type
  { EclLoadMonster's 'CPIC' holder. }
  TStr12 = string[12];

procedure CallEclScript(vmAddr: Word); forward;

{ EXIT, opcode $00: ends the script. Redraws the view frame if the copy protection showed, restores the saved current
  character, clears the monster flags and the graphics flag, stops the interpreter, empties the gosub stack and puts the
  text cursor back at row 17, column 1. }
procedure EclExit;
begin
  if GDVars.eclProtection <> 0 then Border.DrawExploreFrame;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  GameIo.FillWord(GDVars.monFlags, SizeOf(GDVars.monFlags));
  GDVars.eclGraphics := False;
  GDVars.eclProtection := 0;
  GDVars.eclStop := 1;
  Inc(GDVars.eclIp);
  while GDVars.eclStack <> nil do begin
    GDVars.eclStackPrv := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(GDVars.eclStack^));
    GDVars.eclStack := GDVars.eclStackPrv;
  end;
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  GDVars.boxCleared := 0;
end;

{ GOTO, opcode $01: jumps to the address in its argument. }
procedure EclGoto;
begin
  EclMenu.LoadEclVars(1);
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
end;

{ GOSUB, opcode $02: pushes the return address and jumps to the address in its argument. }
procedure EclGosubCmd;
begin
  EclMenu.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE, opcode $03: compares its two arguments, as strings when either is a string type ($80 and up), else as
  integers, and sets the comparison flags. }
procedure EclCompare;
var
  lhs: Word;
  rhs: Word;
  lhsStr: String;
  rhsStr: String;
begin
  EclMenu.LoadEclVars(2);
  if (GDVars.varTypes[1] >= $80) or (GDVars.varTypes[2] >= $80) then begin
    lhsStr := GDVars.gbStrings[1];
    rhsStr := GDVars.gbStrings[2];
    EclMenu.EclCompareStr(lhsStr, rhsStr);
  end else begin
    lhs := EclMenu.GetEclVar(1);
    rhs := EclMenu.GetEclVar(2);
    EclMenu.EclCompareInt(lhs, rhs);
  end;
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: stores v[1] + v[2], v[2] - v[1], v[1] div v[2] (the remainder going to zone 1) or
  v[1] * v[2] at the third argument's address. }
procedure EclArithmetic;
var
  vmAddr: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclMenu.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclMenu.GetEclVar(i);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  case GDVars.curOp of
    4: r := v[1] + v[2];
    5: r := v[2] - v[1];
    6: begin
         r := v[1] div v[2];
         GDVars.zone1^.cell[$7F3F] := v[1] mod v[2];
       end;
    7: r := v[1] * v[2];
  end;
  EclMenu.WriteGbvm(vmAddr, r);
end;

{ RANDOM, opcode $08: stores a random number from 0 to its first argument (0 to 254 when that is 255) at the address in
  its second. }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  n := EclMenu.GetEclVar(1);
  if n < 255 then Inc(n);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  roll := Trunc(Random(n));
  EclMenu.WriteGbvm(vmAddr, roll);
end;

{ SAVE, opcode $09: stores its first argument, a number or a string (type bit 7 set), at the address in its second. }
procedure EclSave;
var
  v: Word;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  if GDVars.varTypes[1] < $80 then begin
    v := EclMenu.GetEclVar(1);
    EclMenu.WriteGbvm(vmAddr, v);
  end else
    EclMenu.WriteGbvmString(vmAddr, GDVars.gbStrings[1]);
end;

{ LOAD CHARACTER: makes the party member its argument names (low 7 bits, counting from 0) the current character, or sets
  the character-not-found flag when there is none; EXIT restores the previous one. With bit 7 set and both removal flags
  raised, it removes that character from the party and redraws the party. }
procedure EclLoadCharacter;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  savedIdx: Byte;
  idx: Byte;
  i: Byte;
  dropRequest: Byte;
begin
  GDVars.restoreChar := 1;
  EclMenu.LoadEclVars(1);
  i := 0;
  idx := EclMenu.GetEclVar(1);
  p := GDVars.creatureList;
  dropRequest := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.nextCharAddr;
      Inc(i);
    end;
  if p <> nil then begin
    GDVars.curChar := p;
    GDVars.charNotFound := 0;
  end else
    GDVars.charNotFound := 1;
  if (dropRequest <> 0) and GDVars.dumpMonsterRecords and GDVars.dumpPartyRecords then begin
    if GDVars.savedChar = GDVars.curChar then GDVars.restoreChar := 0;
    CharGen.RemoveCreature(False, True);
    CharHlp.DisplayRoster(GDVars.curChar);
    GDVars.dumpMonsterRecords := False;
    GDVars.dumpPartyRecords := False;
  end;
end;

{ SETUP MONSTER: records the encounter's monster and picture and its distance (the requested one, cut to the open cells
  ahead), and shows it. }
procedure EclSetupMonster;
var
  { Unused in this version; see the other implementations of this routine. }
  distance: Word;
begin
  EclMenu.LoadEclVars(3);
  GDVars.approachA := EclMenu.GetEclVar(1);
  GDVars.zone1^.cell[$7EC0] := EclMenu.GetEclVar(2);
  GDVars.approachB := EclMenu.GetEclVar(3);
  GDVars.zone1^.cell[$7EC1] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                      GDVars.partyPos.facing);
  if GDVars.zone1^.cell[$7EC0] < GDVars.zone1^.cell[$7EC1] then
    GDVars.zone1^.cell[$7EC1] := GDVars.zone1^.cell[$7EC0];
  EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]), GDVars.monFlags);
end;

{ Opcode $0B LOAD MONSTER. Initialize a template creature, append it to the party linked list, then clone count-1 more
  -- each a record copy plus a deep copy of the item list and the effect list, both prepended and so reversed. The whole
  list is capped at 63 nodes. }
procedure EclLoadMonster;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  cr: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  tmpl: Types.TCharRecord;
  nm: TStr12;
  it: Types.PItemRec;
  tmpIt: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  tmpEf: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := GDVars.curChar;
  i := 1;
  EclMenu.LoadEclVars(3);
  if GDVars.creatureCnt >= 63 then Exit;
  p := nil;
  q := nil;
  id := EclMenu.GetEclVar(1);
  EclMenu.InitCreature(id, cr, it, ef);
  { Difficulty scaling: hit points and movement are scaled by (level+2)/4. }
  if (cr^.hostileV1 = 1) and (GDVars.zone0^.cell[$4CF4] >= 0) and (GDVars.zone0^.cell[$4CF4] < 5) then begin
    cr^.hpCurrent := (cr^.hpCurrent * (GDVars.zone0^.cell[$4CF4] + 2)) div 4;
    cr^.hpMaxV1 := (cr^.hpMaxV1 * (GDVars.zone0^.cell[$4CF4] + 2)) div 4;
    if (cr^.hpCurrent = 0) or (cr^.hpMaxV1 = 0) then begin
      cr^.hpCurrent := 1;
      cr^.hpMaxV1 := 1;
    end;
  end;
  if cr^.thiefSkills[0] <> 0 then Inc(GDVars.thiefCount);
  tmpl := cr^;
  invHead := it;
  effHead := ef;
  count := EclMenu.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclMenu.GetEclVar(3);
  p := GDVars.creatureList;
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.iconAnimIdx);
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  p^.nextCharAddr := cr;
  p := p^.nextCharAddr;
  p^.orderNumber := GDVars.iconAnimIdx;
  p^.nextCharAddr := nil;
  Inc(GDVars.creatureCnt);
  Inc(i);
  while (i <= count) and (GDVars.creatureCnt < 63) do begin
    New(q);
    p^.nextCharAddr := q;
    p := p^.nextCharAddr;
    p^ := tmpl;
    p^.orderNumber := GDVars.iconAnimIdx;
    p^.nextCharAddr := nil;
    p^.effectsAddr := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(GDVars.creatureCnt);
    while it <> nil do begin
      if p^.itemsAddr = nil then begin
        New(p^.itemsAddr);
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := nil;
      end else begin
        tmpIt := p^.itemsAddr;
        New(p^.itemsAddr);
        p^.itemsAddr^ := it^;
        p^.itemsAddr^.next := tmpIt;
      end;
      it := it^.next;
    end;
    it := invHead;
    while ef <> nil do begin
      if p^.effectsAddr = nil then begin
        New(p^.effectsAddr);
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := nil;
      end else begin
        tmpEf := p^.effectsAddr;
        New(p^.effectsAddr);
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := tmpEf;
      end;
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(GDVars.iconAnimIdx);
  GDVars.monstersPresent := 1;
  GDVars.curChar := savedCur;
end;

{ APPROACH, opcode $0D: brings the monster one step nearer and redraws it, unless it is already adjacent. }
procedure EclApproach;
begin
  if GDVars.zone1^.cell[$7EC1] > 0 then begin
    Dec(GDVars.zone1^.cell[$7EC1]);
    EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]), GDVars.monFlags);
  end;
  Inc(GDVars.eclIp);
end;

{ PICTURE, opcode $0E: picture 255 redraws the area view when an ECL picture or a sprite is up (unless the saved
  interface was the 3D view and the current one is not) and clears the monster flags. Any other picture sets the monster
  and ECL-graphics flags; when no portrait is staged in zone 1 (255) it shows pictures 112 and above as a big picture
  (121 also drawing the map cursor, the others setting the special-view flag) and lower ones as the first frame of a PIC
  animation in the picture box, and with a staged portrait it draws that portrait with this picture instead. }
procedure EclPicture;
var
  picId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  picBuf: array[0..3] of Byte;
begin
  EclMenu.LoadEclVars(1);
  picId := EclMenu.GetEclVar(1);
  if picId <> 255 then begin
    GDVars.monFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.zone1^.cell[$7EE1] = 255 then begin
      GDVars.picDrawn := 1;
      if picId >= 112 then begin
        Portrait.LoadBigPic(picId);
        Portrait.DisplayBigPic;
        if picId = 121 then MapCurs.DrawCursor
        else GDVars.rosterLock := 1;
        GDVars.viewDirty := 0;
      end else begin
        Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
        Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
      end;
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.zone1^.cell[$7EE1]), picId);
  end else begin
    if ((GDVars.savedInterface <> C_Ifc.INDOORS) or (GDVars.interfaceState = C_Ifc.INDOORS)) and
        (GDVars.eclGraphics or GDVars.sprShown) then begin
      GDVars.viewDirty := 1;
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.sprShown := False;
      GDVars.picDrawn := 1;
    end;
    GDVars.monFlags[0] := False;
    GDVars.monFlags[1] := False;
  end;
end;

{ INPUT NUMBER: reads a number from the player into the second argument's address. }
procedure EclInputNumber;
var
  q: String[1];
  v: Word;
  vmAddr: Word;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  v := TextRend.ReadNumber(q, LightGreen, 0);
  EclMenu.WriteGbvm(vmAddr, v);
end;

{ INPUT STRING: reads up to 40 characters into the second argument's address; an empty answer is stored as one space. }
procedure EclInputString;
var
  q: String[1];
  vmAddr: Word;
  s: String;
begin
  EclMenu.LoadEclVars(2);
  q := '';
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  s := TextRend.ReadString(q, LightGreen, 0, 40);
  if s = '' then s := ' ';
  EclMenu.WriteGbvmString(vmAddr, s);
end;

{ PRINT and PRINTCLEAR, opcodes $11 and $12: shows its argument, a number or a string, in the message window; PRINTCLEAR
  first clears the window and starts at its top. }
procedure EclPrint;
begin
  EclMenu.LoadEclVars(1);
  GDVars.bottomClear := 0;
  GDVars.msgDelayFlag := 1;
  if GDVars.varTypes[1] < $80 then
    GDVars.gbStrings[1] := CharHlp.Uint16Str(EclMenu.GetEclVar(1));
  if GDVars.curOp = $11 then
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, False, GDVars.gbStrings[1])
  else begin
    GDVars.curRow := 17;
    GDVars.curCol := 1;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, GDVars.gbStrings[1]);
  end;
  GDVars.msgDelayFlag := 0;
end;

{ RETURN, opcode $13: pops the gosub stack and returns to its address, or ends the script like EXIT when the stack is
  empty. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.eclStack <> nil then begin
    GDVars.eclIp := GDVars.eclStack^.addr;
    GDVars.eclStackPrv := GDVars.eclStack^.next;
    FreeMem(GDVars.eclStack, SizeOf(GDVars.eclStack^));
    GDVars.eclStack := GDVars.eclStackPrv;
  end else
    EclVm.EclExit;
end;

{ COMPARE AND: sets the equal flag when v[1] = v[2] and v[3] = v[4], else the not-equal flag. }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  EclMenu.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.compareFlags[0] := True
  else
    GDVars.compareFlags[1] := True;
end;

{ IF, opcodes $16..$1B (=, <>, <, >, <=, >=): skips the next command unless its comparison flag is set. }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.curOp of
    $16: if not GDVars.compareFlags[0] then EclMenu.SkipEclCmd;
    $17: if not GDVars.compareFlags[1] then EclMenu.SkipEclCmd;
    $18: if not GDVars.compareFlags[2] then EclMenu.SkipEclCmd;
    $19: if not GDVars.compareFlags[3] then EclMenu.SkipEclCmd;
    $1A: if not GDVars.compareFlags[4] then EclMenu.SkipEclCmd;
    $1B: if not GDVars.compareFlags[5] then EclMenu.SkipEclCmd;
  end;
end;

{ NEWECL, opcode $20: saves the current script id in zone 0 and loads the script its operand names. When the load
  succeeds it starts the new script from the beginning, stops the run with the new-script flag set and clears the
  monster flags; when it fails it stops the run with the flag clear and restores the saved script id. }
procedure EclNewEcl;
var
  newId: Byte;
begin
  EclMenu.LoadEclVars(1);
  GDVars.zone0^.cell[$4BF2] := GDVars.curEclId;
  newId := EclMenu.GetEclVar(1);
  GDVars.curEclId := newId;
  if EclMenu.LoadEclScript(newId) then begin
    EclMenu.EclInit;
    GDVars.eclStop := 1;
    GDVars.newEclFlag := 1;
    GameIo.FillWord(GDVars.monFlags, SizeOf(GDVars.monFlags));
  end else begin
    GDVars.eclStop := 1;
    GDVars.newEclFlag := 0;
    GDVars.curEclId := Byte(GDVars.zone0^.cell[$4BF2]);
  end;
end;

{ Opcode $21,$37 LOAD FILES/LOAD PIECES. $21 loads a 3-D geometry map; $37 loads up to three wall/piece sets. The $37
  arm is a three-way nest: after the 127 special case and the (zone0^.cell[$4BE7] and zone0^.cell[$4BE8]) guard, a third
  test on zone0^.cell[$4BE9] chooses between slots 1/2/3 and slots 1/3 only, with slot 3 cleared when absent. Every slot
  tests <> 127 alongside <> 255. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclMenu.LoadEclVars(3);
  GDVars.filesLoaded := 1;
  for i := 1 to 3 do
    f[i] := EclMenu.GetEclVar(i);
  if GDVars.curOp = $21 then begin
    GDVars.mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) and (GDVars.zone0^.cell[$4BE6] <> 0) then begin
      GDVars.zone0^.cell[$4BC5] := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.zone1^.cell[$7EC9] := 0;
    end;
  end else begin
    GDVars.piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^.cell[$4BE7] <> 0) and (GDVars.zone0^.cell[$4BE8] <> 0) then begin
      if GDVars.zone0^.cell[$4BE9] <> 0 then begin
        if f[1] <> 255 then
          View3D.LoadWallSet(f[1], 1)
        else begin
          GDVars.wallSetCache[1].defId := -1;
          GDVars.wallSetCache[1].symSet := -1;
        end;
        if (f[2] <> 255) and (f[2] <> 127) then View3D.LoadWallSet(f[2], 2);
        if (f[3] <> 255) and (f[3] <> 127) then View3D.LoadWallSet(f[3], 3);
      end else begin
        if f[1] <> 255 then
          View3D.LoadWallSet(f[1], 1)
        else begin
          GDVars.wallSetCache[1].defId := -1;
          GDVars.wallSetCache[1].symSet := -1;
        end;
        if (f[3] <> 255) and (f[3] <> 127) then
          View3D.LoadWallSet(f[3], 3)
        else begin
          GDVars.wallSetCache[3].defId := -1;
          GDVars.wallSetCache[3].symSet := -1;
        end;
      end;
    end else
      for i := 1 to 3 do
        if (f[i] <> 255) and (f[i] <> 127) then
          View3D.LoadWallSet(f[i], i)
        else begin
          GDVars.wallSetCache[i].defId := -1;
          GDVars.wallSetCache[i].symSet := -1;
        end;
  end;
  if (GDVars.piecesLoaded <> 0) and (GDVars.mapLoaded <> 0) and (GDVars.savedInterface = C_Ifc.OVERLAND) then begin
    if (GDVars.interfaceState <> C_Ifc.OVERLAND) and (GDVars.needPanelRedraw <> 0) then begin
      Border.DrawExploreFrame;
      CharHlp.DisplayRoster(GDVars.curChar);
      CharHlp.PrintPositionAndTime;
    end;
    GDVars.needPanelRedraw := 0;
  end;
end;

{ AND and OR, opcodes $2F and $30: combines its first two arguments bitwise, truncates the result to a byte, sets the
  comparison flags as for COMPARE of 0 with the result, and stores it at the address in its third. }
procedure EclAndOr;
var
  vmAddr: Word;
  rhs: Word;
  lhs: Word;
  r: Byte;
begin
  EclMenu.LoadEclVars(3);
  lhs := EclMenu.GetEclVar(1);
  rhs := EclMenu.GetEclVar(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  if GDVars.curOp = $2F then
    r := lhs and rhs
  else
    r := lhs or rhs;
  EclMenu.EclCompareInt(0, r);
  EclMenu.WriteGbvm(vmAddr, r);
end;

{ GETTABLE, opcode $2A: reads the GBVM entry at its first argument's address plus its second and stores it at the
  address in its third. }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclMenu.LoadEclVars(3);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  idx := EclMenu.GetEclVar(2);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  sum := idx + addr1;
  v := EclMenu.ReadGbvm(sum);
  EclMenu.WriteGbvm(addr2, v);
end;

{ SAVETABLE, opcode $35: stores its first argument at the GBVM entry at its second argument's address plus its third. }
procedure EclSaveTable;
var
  idx: Word;
  vmAddr: Word;
  v: Word;
  sum: Word;
begin
  EclMenu.LoadEclVars(3);
  v := EclMenu.GetEclVar(1);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  idx := EclMenu.GetEclVar(3);
  sum := vmAddr + idx;
  EclMenu.WriteGbvm(sum, v);
end;

{ VERTICAL MENU, opcode $15: shows its message, then a vertical menu of as many strings as its third argument says, and
  stores the choice at the GBVM address in its first. }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  vmAddr: Word;
begin
  GDVars.horizChoice := 1;
  GDVars.bottomClear := 0;
  redraw := True;
  q := '';
  i := 1;
  EclMenu.LoadEclVars(3);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  msg := GDVars.gbStrings[1];
  count := EclMenu.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := 1;
  GDVars.curRow := 17;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, msg);
  while list <> nil do begin
    list^.name := GDVars.gbStrings[i];
    list^.isHeader := 0;
    list := list^.next;
    Inc(i);
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, LightMagenta, LightGreen, White, 1, GDVars.curRow + 1, 38, 22, list, False, redraw,
                          idx, list);
  EclMenu.WriteGbvm(vmAddr, idx);
  MenuCore.FreeStringList(list);
  TextRend.ClearRect(1, 17, 38, 22);
end;

{ HORIZONTAL MENU, opcode $2B: builds a '~A ~B ~C' horizontal menu from the strings that follow, as many as its second
  argument says, and stores the chosen index at the address in its first. A single choice also accepts Enter, and the
  joystick wording of the continue prompt becomes the keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  vmAddr: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  GDVars.horizChoice := 1;
  q := '';
  menu := '';
  EclMenu.LoadEclVars(2);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := White;
    mCol := White;
    if GDVars.gbStrings[1] = 'PRESS BUTTON OR RETURN TO CONTINUE.' then
      GDVars.gbStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := White;
    mCol := LightGreen;
  end;
  anim := GDVars.eclGraphics and (GDVars.picDrawn <> 0);
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.gbStrings[i] + ' ';
  menu := menu + '~' + GDVars.gbStrings[count];
  ch := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclMenu.WriteGbvm(vmAddr, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEAR MONSTERS, opcode $1C: forgets the loaded monsters and undead, resets the icon slots to 8, and empties the pool
  and the treasure. }
procedure EclClearMonsters;
var
  nxt: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
begin
  Inc(GDVars.eclIp);
  GDVars.thiefCount := 0;
  GDVars.creatureCnt := 0;
  GDVars.monstersPresent := 0;
  GDVars.iconAnimIdx := 8;
  GameIo.FillWord(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
  while GDVars.treasureItems <> nil do begin
    nxt := GDVars.treasureItems^.next;
    FreeMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
    GDVars.treasureItems := nxt;
  end;
end;

{ PARTYSTRENGTH: stores the party's strength: for each member (hit points + 5 per point of stored armor class above 60 +
  5 per point of stored THAC0 above 39 + 8 per magic-user level + 4 per cleric level) div 10, summed into a byte. }
procedure EclPartyStrength;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Byte;
  vmAddr: Word;
  p: Types.PCharRecord;
begin
  EclMenu.LoadEclVars(1);
  strength := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    hp := p^.hpCurrent;
    ac := p^.acCurArr[0];
    th := p^.toHitCur;
    mage := p^.classLevelA[C_Class.MAGE] +
      p^.classLevelB[C_Class.MAGE] * Ord(ClassCal.EarlierClassActive(p));
    cleric := p^.classLevelA[C_Class.CLERIC] +
      p^.classLevelB[C_Class.CLERIC] * Ord(ClassCal.EarlierClassActive(p));
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    Inc(strength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.nextCharAddr;
  end;
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.WriteGbvm(vmAddr, strength);
end;

{ Opcode $1E CHECKPARTY. An attribute-keyed party scan: the operand key selects which per-member value to reduce to
  (min, max, mean) and where to write the three results plus a found flag. The key bias is - $7C00. The $72 arm is an
  equality search rather than a reduction, and $C9..$D0 reads both class-level bands. The $19 arm tests max first, every
  other arm min first. }
procedure EclCheckParty;
var
  attr: Integer;
  sum: Integer;
  effId: Byte;
  p: Types.PCharRecord;
  found: Byte;
  eff: Types.PEffectRec;
  { min / max / mean }
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;
  idx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  deadStr: String;
  classIdx: ShortInt;
  lvl: ShortInt;

  { Stores the three results and the found flag at the four result addresses. }
  procedure Write4Gbvm;
  begin
    EclMenu.WriteGbvm(addr1, outv[1]);
    EclMenu.WriteGbvm(addr2, outv[2]);
    EclMenu.WriteGbvm(addr3, outv[3]);
    EclMenu.WriteGbvm(addr4, ShortInt(found));
  end;

begin
  EclMenu.LoadEclVars(6);
  p := GDVars.creatureList;
  found := 0;
  if GDVars.varTypes[1] = 1 then
    attr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1])
  else
    attr := EclMenu.GetEclVar(1);
  effId := EclMenu.GetEclVar(2);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  addr3 := EclMenu.CombineBytesToWord(GDVars.varLo[5], GDVars.varHi[5]);
  addr4 := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  Dec(attr, $7C00);
  case attr of
    { key $8400: active-effect search }
    -31744:
      begin
        while (p <> nil) and (found = 0) do begin
          found := Byte(CharHlp.HasEffect(p, effId, eff));
          p := p^.nextCharAddr;
        end;
        GameIo.FillWord(outv, SizeOf(outv));
        Write4Gbvm;
      end;
    { charisma; max tested first }
    $19:
      begin
        while p <> nil do begin
          Inc(count);
          if p^.chaCur > outv[2] then outv[2] := p^.chaCur;
          if p^.chaCur < outv[1] then outv[1] := p^.chaCur;
          Inc(sum, p^.chaCur);
          p := p^.nextCharAddr;
        end;
        outv[3] := sum div count;
        Write4Gbvm;
      end;
    { equality search; outv is not touched }
    $72:
      begin
        while (p <> nil) and (found = 0) do begin
          if Byte(p^.race) = effId then found := 1;
          p := p^.nextCharAddr;
        end;
        Write4Gbvm;
      end;
    { thiefSkills[attr - $A4] }
    $A5..$AC:
      begin
        idx := attr - $A4;
        while p <> nil do begin
          Inc(count);
          if p^.thiefSkills[idx] < outv[1] then outv[1] := p^.thiefSkills[idx];
          if p^.thiefSkills[idx] > outv[2] then outv[2] := p^.thiefSkills[idx];
          Inc(sum, p^.thiefSkills[idx]);
          p := p^.nextCharAddr;
        end;
        outv[3] := sum div count;
        Write4Gbvm;
      end;
    { movementCur }
    $9F:
      begin
        while p <> nil do begin
          Inc(count);
          if p^.movementCur < outv[1] then outv[1] := p^.movementCur;
          if p^.movementCur > outv[2] then outv[2] := p^.movementCur;
          Inc(sum, p^.movementCur);
          p := p^.nextCharAddr;
        end;
        outv[3] := sum div count;
        Write4Gbvm;
      end;
    { class level; effId is a FLOOR, not an id }
    $C9..$D0:
      begin
        case attr of
          $C9: classIdx := C_Class.MAGE;
          $CA: classIdx := C_Class.CLERIC;
          $CB: classIdx := C_Class.THIEF;
          $CC: classIdx := C_Class.FIGHTER;
          $CF: classIdx := C_Class.PALADIN;
          $D0: classIdx := C_Class.RANGER;
        end;
        while p <> nil do begin
          Inc(count);
          lvl := p^.classLevelA[classIdx];
          if p^.classLevelB[classIdx] > lvl then
            if Ord(ClassCal.EarlierClassActive(p)) <> 0 then
              lvl := p^.classLevelB[classIdx];
          if lvl >= ShortInt(effId) then begin
            if lvl < ShortInt(outv[1]) then outv[1] := lvl;
            if lvl > ShortInt(outv[2]) then outv[2] := lvl;
          end;
          Inc(sum, lvl);
          p := p^.nextCharAddr;
        end;
        outv[3] := sum div count;
        Write4Gbvm;
      end;
  end;
end;

{ PARTY SURPRISE, opcode $22: stores 1 at its first argument's address when the party holds a ranger or a cleric/ranger,
  else 0, and 0 at its second's. }
procedure EclPartySurprise;
var
  p: Types.PCharRecord;
  mod1: Byte;
  mod2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rangerDead: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclMenu.LoadEclVars(2);
  p := GDVars.creatureList;
  mod1 := 0;
  mod2 := 0;
  rangerDead := 0;
  while p <> nil do begin
    if (p^.charClassV1 = C_Class.RANGER) or (p^.charClassV1 = C_Class.CLERIC_RANGER) then begin
      mod1 := 1;
      rangerDead := 1;
    end;
    p := p^.nextCharAddr;
  end;
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  EclMenu.WriteGbvm(addr1, mod1);
  EclMenu.WriteGbvm(addr2, mod2);
end;

{ SURPRISE, opcode $23: rolls a six-sided die for each side against v[4] + 2 - v[1] and v[2] + 2 - v[3] and writes which
  side is surprised (1 or 2, 0 when neither is) to a fixed script address. Note: the final test overrides the both-sides
  result 3, and the address lies outside the GBVM banks, where writes store nothing, so the result is lost. }
procedure EclSurprise;
var
  firstRoll: Byte;
  secondRoll: Byte;
  i: Byte;
  res: Byte;
  v: array[1..4] of Byte;
  firstTarget: ShortInt;
  secondTarget: ShortInt;
begin
  EclMenu.LoadEclVars(4);
  res := 0;
  for i := 1 to 4 do
    v[i] := EclMenu.GetEclVar(i);
  firstTarget := v[4] + 2 - v[1];
  secondTarget := v[2] + 2 - v[3];
  firstRoll := FxEngine.RollDice(1, 6);
  secondRoll := FxEngine.RollDice(1, 6);
  if firstRoll <= firstTarget then
    if secondRoll <= secondTarget then
      res := 3
    else
      res := 1;
  if secondRoll <= secondTarget then
    res := 2;
  EclMenu.WriteGbvm($2CB, res);
end;

{ Opcode $24 COMBAT. Four mutually exclusive leave-the-map arms, then the shared teardown; each arm is bracketed by the
  same two-test sound pair. The arms test zone0^.cell[$4CFC], zone1^.cell[$7F6C] and zone1^.cell[$7EE2] in that order,
  then fall through, entering PoolVault, ShopMainMenu, TempleMainMenu and PostCombat. Note: redraw is cleared in the
  indoor arm of the temple and TempleMainMenu branches but not in the fallthrough branch's indoor arm. }
procedure EclCombat;
var
  dist: Word;
  redraw: Byte;
  sav: Byte;
begin
  GDVars.rosterLock := 0;
  sav := GDVars.moveMode;
  GDVars.moveMode := 0;
  Inc(GDVars.eclIp);
  redraw := 1;
  if (GDVars.monstersPresent = 0) and (GDVars.duelFlag = 0) then begin
    if GDVars.zone0^.cell[$4CFC] = 1 then begin
      GDVars.zone0^.cell[$4CFC] := 0;
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Vault.PoolVault;
    end else if GDVars.zone1^.cell[$7F6C] = 1 then begin
      GDVars.zone1^.cell[$7F6C] := 0;
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Shop.ShopMainMenu;
      if GDVars.zone0^.cell[$4BE6] = 0 then begin
        redraw := 0;
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end;
    end else if GDVars.zone1^.cell[$7EE2] = 1 then begin
      GDVars.zone1^.cell[$7EE2] := 0;
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Temple.TempleMainMenu;
      if GDVars.zone0^.cell[$4BE6] = 0 then begin
        redraw := 0;
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end;
    end else begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      PostCbt.PostCombat;
      if GDVars.zone0^.cell[$4BE6] = 0 then begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end else begin
        if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
        if GDVars.soundActive = 0 then SoundDrv.StartSound;
      end;
    end;
  end else begin
    if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
    if GDVars.soundActive = 0 then SoundDrv.StartSound;
    dist := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    if dist < GDVars.zone1^.cell[$7EC1] then
      GDVars.zone1^.cell[$7EC1] := dist;
    Combat.CombatMain;
    if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
    PostCbt.PostCombat;
    if GDVars.soundActive = 0 then SoundDrv.StartSound;
    if GDVars.zone0^.cell[$4BE6] = 0 then begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
      Portrait.LoadBigPic(121);
    end else begin
      if GDVars.soundActive <> 0 then SoundDrv.SoundCommand(GDConsts.sfxReset);
      if GDVars.soundActive = 0 then SoundDrv.StartSound;
    end;
    if GDVars.duelFlag <> 0 then GDVars.duelFlag := 0;
  end;
  if GDVars.zone0^.cell[$4BE6] = 0 then
    GDVars.interfaceState := C_Ifc.OVERLAND
  else
    GDVars.interfaceState := C_Ifc.INDOORS;
  GDVars.zone1^.cell[$7ECA] := GDVars.zone1^.cell[$7ECA] and 1;
  GameIo.FillWord(GDVars.monFlags, SizeOf(GDVars.monFlags));
  GDVars.eclGraphics := False;
  if redraw <> 0 then begin
    CharHlp.DisplayNoncombatInterface;
    if (GDVars.zone0^.cell[$4BE6] = 0) and (GDVars.partyDefeated = 0) and (GDVars.zone0^.cell[$4C38] = 0) then
      MapCurs.DrawCursor;
  end;
  GDVars.moveMode := sav;
end;

{ ON GOTO and ON GOSUB, opcodes $25 and $26: jumps to, or calls, the address its first argument picks from the list
  whose length its second gives; an index past the list does nothing. }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  target: Byte;
  i: Byte;
  found: Byte;
begin
  found := 0;
  EclMenu.LoadEclVars(2);
  sel := EclMenu.GetEclVar(1);
  count := EclMenu.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclMenu.LoadEclVars(count);
  i := 0;
  while (i < count) and (found = 0) do begin
    if sel = i then begin
      if GDVars.curOp = $25 then
        GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[i + 1], GDVars.varHi[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      found := 1;
    end else
      Inc(i);
  end;
end;

{ Opcode $27 TREASURE. Stages the seven LongInt money slots, then builds the next-combat item list: a treasure id below
  $80 is a fixed list read out of ITEM<disk>.dax, $80+n rolls n random items off the roll tables, $FF is none. Every
  insert prepends. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  { Unused in this version; see the other implementations of this routine. }
  treasureMsg: String[22];
  it: Types.TItemRec;
  tmp: Types.PItemRec;
  walk: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  { Unused in this version; see the other implementations of this routine. }
  roll4: Byte;
  itemId: Byte;
  readOfs: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PByteArr;
begin
  EclMenu.LoadEclVars(8);
  for i := 0 to 6 do
    GDVars.treasureMoney[i] := EclMenu.GetEclVar(Byte(i) + 1);
  tId := EclMenu.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.diskNum, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, 0, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    readOfs := 0;
    repeat
      Move(data^[readOfs], it, 63);
      it.next := nil;
      it.bundleNextV2 := nil;
      Inc(readOfs, 63);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
        GDVars.treasureItems^ := it;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    until readOfs >= sizeRead;
    FreeMem(data, sizeRead);
  end else begin
    if tId = $FF then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..31:
          begin
            roll2 := FxEngine.RollDice(1, 100);
            case roll2 of
              1..20:
                begin
                  roll2 := FxEngine.RollDice(1, 10);
                  case roll2 of
                    1, 2: itemId := 6;
                    3..6: itemId := 8;
                    7, 8: itemId := 70;
                    9: itemId := 15;
                    10: itemId := 29;
                  end;
                end;
              21..44:
                begin
                  roll2 := FxEngine.RollDice(1, 3);
                  case roll2 of
                    1: itemId := 5;
                    2: itemId := 12;
                    3: itemId := 30;
                  end;
                end;
              45..60:
                begin
                  roll2 := FxEngine.RollDice(1, 20);
                  case roll2 of
                    1..3: itemId := 7;
                    4..6: itemId := 24;
                    7..9: itemId := 22;
                    10..12: itemId := 25;
                    13, 14: itemId := 23;
                    15..17: itemId := 28;
                    18..20: itemId := 15;
                  end;
                end;
              61..100:
                begin
                  roll2 := FxEngine.RollDice(1, 4);
                  if roll2 < 4 then begin
                    roll2 := FxEngine.RollDice(1, 20);
                    case roll2 of
                      1..8: itemId := 18;
                      9..13: itemId := 17;
                      14: itemId := 13;
                      15: itemId := 16;
                      16..18: itemId := 19;
                      19, 20: itemId := 20;
                    end;
                  end else begin
                    roll2 := FxEngine.RollDice(1, 8);
                    case roll2 of
                      1: itemId := 1;
                      2, 3: itemId := 4;
                      4, 5: itemId := 9;
                      6: itemId := 10;
                      7: itemId := 14;
                      8: itemId := 71;
                    end;
                  end;
                end;
            end;
          end;
        32..62: itemId := 39;
        63..70: itemId := 40;
        71..80: itemId := 37;
        81..85: itemId := 59;
        86..95:
          begin
            roll2 := FxEngine.RollDice(1, 20);
            case roll2 of
              1..3: itemId := 31;
              4..11: itemId := 35;
              12..16: itemId := 36;
              17: itemId := 32;
              18: itemId := 33;
              19, 20: itemId := 34;
            end;
          end;
        96..100:
          begin
            roll2 := FxEngine.RollDice(1, 6);
            case roll2 of
              1, 2: itemId := 50;
              3, 4: itemId := 47;
              5: itemId := 52;
              6: itemId := 53;
            end;
          end;
      end;
      Money.GenerateRandomItem(itemId, it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(GDVars.treasureItems^));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(GDVars.curChar, walk, 0, 0, 0, 0);
      walk := walk^.next;
    end;
  end;
end;

{ ROB, opcode $28: takes the percentage of money in its second argument and, with the chance in its third, items from
  the current character, or from every member when its first is non-zero. }
procedure EclRob;
var
  whole: Byte;
  pctLoss: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  inv: Types.PItemRec;
  fraction: Real;
begin
  EclMenu.LoadEclVars(3);
  whole := EclMenu.GetEclVar(1);
  pctLoss := EclMenu.GetEclVar(2);
  fraction := (100 - pctLoss) / 100;
  chance := EclMenu.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      inv := p^.itemsAddr;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      p := p^.nextCharAddr;
    end;
  end;
end;

{ ENCOUNTER MENU, opcode $29: runs the encounter menu until combat, flight, parley or the monsters' retreat ends it;
  WAIT and ADVANCE update the encounter and repeat. Stores the outcome at the address in its fourth argument: 0 when the
  monsters flee, 1 for combat, 2 when the party flees, 3 for parley. }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  vmAddr: Word;
begin
  GDVars.inEncMenu := 1;
  GDVars.bottomClear := 0;
  GDVars.msgDelayFlag := 1;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclMenu.LoadEclVars(14);
  GDVars.approachA := EclMenu.GetEclVar(1);
  GDVars.zone1^.cell[$7EC0] := EclMenu.GetEclVar(2);
  GDVars.approachB := EclMenu.GetEclVar(3);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[4], GDVars.varHi[4]);
  for i := 0 to 4 do
    resp[i] := EclMenu.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GDVars.gbStrings[i];
  fleePar := EclMenu.GetEclVar(13);
  fleeMon := EclMenu.GetEclVar(14);
  GDVars.zone1^.cell[$7EC1] := EclMenu.MaxMonsterDist(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                      GDVars.partyPos.facing);
  if GDVars.zone1^.cell[$7EC0] < GDVars.zone1^.cell[$7EC1] then
    GDVars.zone1^.cell[$7EC1] := GDVars.zone1^.cell[$7EC0];
  EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]), GDVars.monFlags);
  repeat
    anim := GDVars.eclGraphics and (GDVars.picDrawn <> 0) and (GDVars.zone0^.cell[$4BE6] <> 0)
            and (GDVars.picArcId <> 9);
    clearW := GDVars.zone0^.cell[$4BE6] <> 0;
    waited := False;
    GDVars.curCol := 1;
    GDVars.curRow := 17;
    case GDVars.zone1^.cell[$7EC1] of
      0:
        begin
          k := 1;
          repeat
            msg := msgs[k];
            Inc(k);
          until (msg <> '') or (k > 3);
        end;
      1:
        begin
          k := 2;
          repeat
            msg := msgs[k];
            Inc(k);
            if k > 3 then k := 1;
          until (msg <> '') or (k = 2);
        end;
      2:
        begin
          k := 3;
          repeat
            msg := msgs[k];
            Inc(k);
            if k > 3 then k := 1;
          until (msg <> '') or (k = 3);
        end;
    end;
    if msg = '' then
      clearW := False;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, clearW, msg);
    if (GDVars.zone1^.cell[$7EC1] = 0) or (GDVars.zone0^.cell[$4BE6] = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCharacterSelect(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.zone1^.cell[$7EC1] = 0) or (GDVars.zone0^.cell[$4BE6] = 0)) and (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclMenu.WriteGbvm(vmAddr, 1)
        else begin
          if loMove >= fleePar then
            EclMenu.WriteGbvm(vmAddr, 2)
          else
            EclMenu.WriteGbvm(vmAddr, 1);
        end;
      1:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1:
            begin
              waited := True;
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
            end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
          3:
            begin
              if GDVars.zone1^.cell[$7EC1] <> 0 then begin
                Dec(GDVars.zone1^.cell[$7EC1]);
                EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]),
                                       GDVars.monFlags);
              end else
                TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
              waited := True;
            end;
          4:
            if GDVars.zone1^.cell[$7EC1] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.zone1^.cell[$7EC1]);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]),
                                     GDVars.monFlags);
              waited := True;
            end;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclMenu.WriteGbvm(vmAddr, 0);
              GDVars.curCol := 1;
              GDVars.curRow := 17;
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'The monsters flee.');
            end else
              EclMenu.WriteGbvm(vmAddr, 1);
          1..4:
            begin
              EclMenu.WriteGbvm(vmAddr, 0);
              GDVars.curCol := 1;
              GDVars.curRow := 17;
              TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'The monsters flee.');
            end;
        end;
      3:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1, 3:
            begin
              if GDVars.zone1^.cell[$7EC1] <> 0 then begin
                Dec(GDVars.zone1^.cell[$7EC1]);
                EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]),
                                       GDVars.monFlags);
              end else
                TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Both sides wait.');
              waited := True;
            end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
          4:
            if GDVars.zone1^.cell[$7EC1] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.zone1^.cell[$7EC1]);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]),
                                     GDVars.monFlags);
              waited := True;
            end;
        end;
      4:
        case sel of
          0: EclMenu.WriteGbvm(vmAddr, 1);
          1, 3, 4:
            if GDVars.zone1^.cell[$7EC1] <= 0 then
              EclMenu.WriteGbvm(vmAddr, 3)
            else begin
              Dec(GDVars.zone1^.cell[$7EC1]);
              EclMenu.DisplayMonster(GDVars.approachA, GDVars.approachB, Byte(GDVars.zone1^.cell[$7EC1]),
                                     GDVars.monFlags);
              waited := True;
            end;
          2: EclMenu.WriteGbvm(vmAddr, 2);
        end;
    end;
  until not waited;
  MenuCore.ClearBottomLine;
  GDVars.msgDelayFlag := 0;
  GDVars.inEncMenu := 0;
end;

{ PARLAY: offers Haughty, Sly, Nice, Meek and Abusive and stores the script's value for the chosen attitude at the sixth
  argument's address. }
procedure EclParlay;
var
  sel: Byte;
  chosenValue: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  vmAddr: Word;
  space: Char;
begin
  EclMenu.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclMenu.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCharacterSelect(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen,
                                               White, False, False);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[6], GDVars.varHi[6]);
  chosenValue := v[sel];
  EclMenu.WriteGbvm(vmAddr, chosenValue);
end;

{ FIND ITEM, opcode $32: sets the equal flag when a party member carries an item of the type in its argument, the
  not-equal flag otherwise. }
procedure EclFindItem;
var
  target: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Byte;
  p: Types.PCharRecord;
  item: Types.PItemRec;
  found: Byte;
begin
  EclMenu.LoadEclVars(1);
  found := 0;
  target := EclMenu.GetEclVar(1);
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  GDVars.compareFlags[1] := True;
  p := GDVars.creatureList;
  while (p <> nil) and (found = 0) do begin
    item := p^.itemsAddr;
    while (item <> nil) and (found = 0) do begin
      if target = item^.itemId then begin
        GDVars.compareFlags[0] := True;
        GDVars.compareFlags[1] := False;
        found := 1;
      end;
      item := item^.next;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ DELAY, opcode $3A: waits the message delay; no key is read. }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.PauseOnly;
end;

{ Opcode $2E DAMAGE. The damage roll appears separately inside each of the four arms. <attack> bit-field: $80 =
  save-based magical damage (else physical multi-attack), $40 = area / whole party, $20 = no save, $10 = damage even on
  a successful save, low $1F = save-vs-level modifier. <varOp> $80 = single named target, low $7 = save type. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  atkLo: Byte;
  varOp: Byte;
  bonus: Byte;
  target: Byte;
  saveTy: Byte;
  j: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  areaAtk: Byte;
  saveBit: Byte;
begin
  savedCur := GDVars.curChar;
  damageType := 0;
  areaAtk := 0;
  p := GDVars.creatureList;
  EclMenu.LoadEclVars(5);
  attack := EclMenu.GetEclVar(1);
  dice := EclMenu.GetEclVar(2);
  sides := EclMenu.GetEclVar(3);
  bonus := EclMenu.GetEclVar(4);
  varOp := EclMenu.GetEclVar(5);
  saveBit := attack and $10;
  if (attack and $40) <> 0 then
    areaAtk := 1
  else
    target := FxEngine.RollDice(1, Byte(GDVars.zone1^.cell[$7F3E]));
  if (attack and $80) <> 0 then begin
    atkLo := attack and $1F;
    saveTy := varOp and 7;
    if areaAtk <> 0 then begin
      while p <> nil do begin
        dmg := FxEngine.RollDice(dice, sides) + bonus;
        if (attack and $20) <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
          EclMenu.EclInflictDamage(dmg, p)
        else if saveBit <> 0 then
          EclMenu.EclInflictDamage(dmg, p);
        p := p^.nextCharAddr;
      end;
    end else if (varOp and $80) <> 0 then begin
      dmg := FxEngine.RollDice(dice, sides) + bonus;
      if (saveTy = 0) or not FxEngine.RollSavingThrow(GDVars.curChar, saveTy - 1, atkLo) then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar);
    end else begin
      dmg := FxEngine.RollDice(dice, sides) + bonus;
      for i := 2 to target do
        p := p^.nextCharAddr;
      if not FxEngine.RollSavingThrow(p, saveTy, atkLo) then
        EclMenu.EclInflictDamage(dmg, p)
      else if saveBit <> 0 then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end else begin
    for i := 1 to attack do begin
      dmg := FxEngine.RollDice(dice, sides) + bonus;
      p := GDVars.creatureList;
      target := FxEngine.RollDice(1, Byte(GDVars.zone1^.cell[$7F3E]));
      j := 1;
      while j < target do begin
        p := p^.nextCharAddr;
        Inc(j);
      end;
      if FxEngine.AttackRollNoAttacker(p, varOp) then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end;
  q := GDVars.creatureList;
  GDVars.partyDefeated := 1;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GDVars.partyDefeated := 0;
    q := q^.nextCharAddr;
  end;
  if GDVars.partyDefeated <> 0 then begin
    Border.DrawWindowFrame(1);
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, 0, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, 0, GDConsts.continuePrompt);
end;

{ SPRITE OFF, opcode $31: when a sprite is showing, redraws the map view over it. }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclIp);
  if GDVars.sprShown then begin
    GDVars.viewDirty := 1;
    MapView.DisplayMapView;
    GDVars.sprShown := False;
    GDVars.eclGraphics := False;
  end;
end;

{ CLOCK, opcode $34: advances the clock by its first argument in the unit its second names. }
procedure EclClock;
var
  amount: Byte;
  timeUnit: Byte;
begin
  EclMenu.LoadEclVars(2);
  amount := EclMenu.GetEclVar(1);
  timeUnit := EclMenu.GetEclVar(2);
  GameTime.AdvanceTime(amount, timeUnit);
end;

{ PRINT RETURN, opcode $33: moves the message cursor to the start of the next line and clears the print-return flag. }
procedure EclPrintReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.printRetFlag <> 0 then begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
    GDVars.printRetFlag := 0;
  end else begin
    GDVars.curCol := 1;
    Inc(GDVars.curRow);
  end;
end;

{ CLEAR BOX, opcode $3D: redraws the view frame, the party and the picture box (not in a demo). }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  GDVars.rosterLock := 0;
  Border.DrawExploreFrame;
  CharHlp.DisplayRoster(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  if not GDVars.demoMode then
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  CharHlp.PrintPositionAndTime;
  GDVars.needPanelRedraw := 0;
  GDVars.boxCleared := 1;
end;

{ WHO, opcode $39: asks the player to pick a party member, with its argument as the prompt, and makes that member
  current. }
procedure EclWho;
var
  msg: String;
  sav: Byte;
begin
  sav := GDVars.moveMode;
  GDVars.moveMode := 0;
  GDVars.charNotFound := 0;
  EclMenu.LoadEclVars(1);
  TextRend.ClearRect(1, 17, 38, 22);
  msg := GDVars.gbStrings[1];
  CharHlp.SelectChar(msg, 0, 0, GDVars.curChar);
  GDVars.moveMode := sav;
end;

{ ADD NPC, opcode $36: adds the monster its first argument names to the party as a non-player character whose morale is
  half its second argument. }
procedure EclAddNpc;
var
  { Unused in this version; see the other implementations of this routine. }
  npc: Pointer;
  id: Byte;
  morale: Byte;
begin
  EclMenu.LoadEclVars(2);
  id := EclMenu.GetEclVar(1);
  SaveLoad.AddCreatureToParty(id);
  morale := EclMenu.GetEclVar(2);
  morale := morale div 2;
  morale := morale or $80;
  GDVars.curChar^.npc := morale;
  CharHlp.RecalcStats(GDVars.curChar);
  CharHlp.DisplayRoster(GDVars.curChar);
end;

{ Opcode $3B SPELL. memorizedSpells is indexed from 0; the band threshold is < 74 and the not-found sentinel is chosen
  on found = 0. The trailing ShowTrace is the only handler that traces itself. }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  p: Types.PCharRecord;
  found: Byte;
  innerDone: Byte;
  addr1: Word;
  addr2: Word;
begin
  innerDone := 0;
  found := 0;
  EclMenu.LoadEclVars(3);
  spellId := EclMenu.GetEclVar(1);
  addr1 := EclMenu.CombineBytesToWord(GDVars.varLo[2], GDVars.varHi[2]);
  addr2 := EclMenu.CombineBytesToWord(GDVars.varLo[3], GDVars.varHi[3]);
  slot := 1;
  idx := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (found = 0) do begin
    slot := 0;
    repeat
      if p^.memorizedSpells[slot] = spellId then
        found := 1
      else if slot < 74 then
        Inc(slot)
      else
        innerDone := 1;
    until (innerDone <> 0) or (found <> 0);
    innerDone := 0;
    p := p^.nextCharAddr;
    if (p <> nil) and (found = 0) then
      Inc(idx);
  end;
  if found = 0 then
    slot := 255;
  EclMenu.WriteGbvm(addr1, slot);
  EclMenu.WriteGbvm(addr2, idx);
  EclTrace.ShowTrace('spell', slot, idx, spellId);
end;

{ Opcode $2D CALL. Re-reads operand 1's GBVM address as a magic key (vmAddr - $7FFF) and dispatches engine effects that
  are not reachable as ordinary GBVM writes. Five keys, no default arm: $ADCC resamples the cell event, then, if any of
  five dirty flags is set, clears the monster-flag pair, repaints, and resamples the wall ahead; $3204 plays the
  move-step sound selected by sndEffect; $401F, $4019 and $E804. }
procedure EclCall;
var
  vmAddr: Word;
  magicKey: Word;
begin
  EclMenu.LoadEclVars(1);
  vmAddr := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  magicKey := vmAddr - $7FFF;
  case magicKey of
    $ADCC:
      begin
        GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
        if GDVars.eclGraphics or GDVars.sprShown or GDVars.picRegionW or GDVars.movedParty
           or GDVars.redrawSky then begin
          GameIo.FillWord(GDVars.monFlags, SizeOf(GDVars.monFlags));
          GDVars.viewDirty := 1;
          MapView.DisplayMapView;
          CharHlp.PrintPositionAndTime;
          GDVars.redrawSky := False;
          GDVars.picRegionW := False;
          GDVars.movedParty := False;
          GDVars.eclGraphics := False;
          GDVars.sprShown := False;
          GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                          GDVars.partyPos.facing);
        end;
      end;
    $3204:
      case GDVars.sndEffect of
        8: SoundDrv.SoundCommand(GDConsts.stepSound);
        10: SoundDrv.SoundCommand(GDConsts.explosionSound);
      else
        SoundDrv.SoundCommand(GDConsts.stepSound);
      end;
    $401F: EclMenu.EclMoveForward;
    $4019:
      if GDVars.zone0^.cell[$4BE6] = 0 then
        GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY,
                                                        GDVars.partyPos.facing);
    $E804:
      begin
        Mouse.hideMouse;
        Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[GDVars.animData.curFrame].pic);
        Mouse.showMouse;
        Inc(GDVars.animData.curFrame);
        if GDVars.animData.curFrame > GDVars.animData.count then
          GDVars.animData.curFrame := 1;
        TextRend.PauseOnly;
      end;
  end;
end;

{ Helper called by GameLoop and by EclProgram's prog=9 arm. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.vmRun[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharHlp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.vmRun[4]);
  end;
  GDVars.viewDirty := 1;
  if GDVars.zone0^.cell[$4C38] = 0 then
    MapView.DisplayMapView;
  GDVars.gameSaved := 0;
  if (GDVars.zone0^.cell[$4BE6] = 0) and (GDVars.zone0^.cell[$4C38] = 0) then
    MapCurs.DrawCursor;
end;

{ Opcode $38 PROGRAM. Two arms: prog 0 runs the finale entry with returnedFromCharGen lowered around it, then repaints
  the interface when no 3D map is loaded and neither special mode is on; prog 9 camps, with eclIp saved and restored
  around EnterCamp and EclExit called when not in the $4C38 state. Any other value is a no-op. p and key are unused. }
procedure EclProgram;
var
  prog: Byte;
  savedIp: Word;
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  sav: Byte;
begin
  sav := GDVars.moveMode;
  GDVars.moveMode := 0;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  EclMenu.LoadEclVars(1);
  prog := EclMenu.GetEclVar(1);
  case prog of
    0:
      begin
        GDVars.returnedFromCharGen := 0;
        CharGen.MainMenu;
        GDVars.returnedFromCharGen := 1;
        if (GDVars.picArcId <> 9) and (GDVars.zone0^.cell[$4BE6] = 0)
           and (GDVars.zone0^.cell[$4C38] = 0) then
          CharHlp.DisplayNoncombatInterface;
      end;
    9:
      begin
        savedIp := GDVars.eclIp;
        EclVm.EnterCamp;
        GDVars.eclIp := savedIp;
        if GDVars.zone0^.cell[$4C38] = 0 then
          EclVm.EclExit;
      end;
  end;
  GDVars.moveMode := sav;
end;

{ EclProtection -- opcode $3C. Empty. }
procedure EclProtection;
begin
end;

{ DUMP, opcode $3E: removes the current character from the party, keeps the character that becomes current as the saved
  character to restore, and redraws the party. }
procedure EclDump;
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
begin
  Inc(GDVars.eclIp);
  CharGen.RemoveCreature(False, True);
  GDVars.savedChar := GDVars.curChar;
  CharHlp.DisplayRoster(GDVars.curChar);
end;

{ FIND SPECIAL, opcode $3F: clears the compare flags, then sets the equal flag when the current character has the effect
  in its argument, the not-equal flag otherwise. }
procedure EclFindSpecial;
var
  node: Types.PEffectRec;
  v: Byte;
begin
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  EclMenu.LoadEclVars(1);
  v := EclMenu.GetEclVar(1);
  if CharHlp.HasEffect(GDVars.curChar, v, node) then
    GDVars.compareFlags[0] := True
  else
    GDVars.compareFlags[1] := True;
end;

{ DESTROY ITEMS, opcode $40: removes each item matching its argument from every party member, unreadying it first when
  it is readied, and recalculates each member; the current character is restored afterwards. }
procedure EclDestroyItems;
var
  id: Byte;
  p: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  item: Types.PItemRec;
  nextItem: Types.PItemRec;
begin
  EclMenu.LoadEclVars(1);
  id := EclMenu.GetEclVar(1);
  savedCur := GDVars.curChar;
  p := GDVars.creatureList;
  while p <> nil do begin
    item := p^.itemsAddr;
    while item <> nil do begin
      nextItem := item^.next;
      if id = item^.itemId then begin
        GDVars.curChar := p;
        if item^.equipped <> 0 then
          ViewChar.ToggleReadyItem(item);
        CharHlp.RemoveItem(p, item);
      end;
      item := nextItem;
    end;
    CharHlp.RecalcStats(p);
    p := p^.nextCharAddr;
  end;
  GDVars.curChar := savedCur;
end;

{ Opcode $41 AWARD EXPERIENCE. Operand 2 is a total XP pot, operand 1 selects the whole party (non-zero) or just the
  current character (0). Either way the pot is divided by that member's number of non-zero class levels -- a multi-class
  share -- and credited only if the member is enabled. }
procedure EclAwardExperience;
var
  xpTotal: Word;
  mode: Byte;
  p: Types.PCharRecord;
  i: ShortInt;
  cnt: Byte;
  share: Word;
begin
  EclMenu.LoadEclVars(2);
  xpTotal := EclMenu.GetEclVar(2);
  mode := EclMenu.GetEclVar(1);
  GDVars.curRow := 17;
  GDVars.curCol := 1;
  if mode <> 0 then begin
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True, 'Congratulations the party gains experience!');
    TextRend.PauseOnly;
    p := GDVars.creatureList;
    while p <> nil do begin
      cnt := 0;
      for i := C_Class.CLERIC to C_Class.THIEF do
        if p^.classLevelA[i] > 0 then
          Inc(cnt);
      share := xpTotal div cnt;
      if p^.enabled <> 0 then
        Inc(p^.xp, share);
      p := p^.nextCharAddr;
    end;
  end else begin
    p := GDVars.curChar;
    TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                  'Congratulations ' + p^.name + ' gains experience!');
    TextRend.PauseOnly;
    cnt := 0;
    for i := C_Class.CLERIC to C_Class.THIEF do
      if p^.classLevelA[i] > 0 then
        Inc(cnt);
    share := xpTotal div cnt;
    if p^.enabled <> 0 then
      Inc(p^.xp, share);
  end;
end;

{ The opcode dispatcher. Unknown opcodes are a no-op. }
procedure DispatchEclCommand;
begin
  case GDVars.curOp of
    $00: EclVm.EclExit;
    $01: EclVm.EclGoto;
    $02: EclVm.EclGosubCmd;
    $03: EclVm.EclCompare;
    $04, $05, $06, $07: EclVm.EclArithmetic;
    $08: EclVm.EclRandom;
    $09: EclVm.EclSave;
    $0A: EclVm.EclLoadCharacter;
    $0B: EclVm.EclLoadMonster;
    $0C: EclVm.EclSetupMonster;
    $0D: EclVm.EclApproach;
    $0E: EclVm.EclPicture;
    $0F: EclVm.EclInputNumber;
    $10: EclVm.EclInputString;
    $11, $12: EclVm.EclPrint;
    $13: EclVm.EclReturn;
    $14: EclVm.EclCompareAnd;
    $15: EclVm.EclVMenu;
    $16, $17, $18, $19, $1A, $1B: EclVm.EclIf;
    $1C: EclVm.EclClearMonsters;
    $1D: EclVm.EclPartyStrength;
    $1E: EclVm.EclCheckParty;
    $20: EclVm.EclNewEcl;
    $21, $37: EclVm.EclLoadFiles;
    $22: EclVm.EclPartySurprise;
    $23: EclVm.EclSurprise;
    $24: EclVm.EclCombat;
    $25, $26: EclVm.EclOnGoto;
    $27: EclVm.EclTreasure;
    $28: EclVm.EclRob;
    $29: EclVm.EclEncounter;
    $2A: EclVm.EclGetTable;
    $2B: EclVm.EclHMenu;
    $2C: EclVm.EclParlay;
    $2D: EclVm.EclCall;
    $2E: EclVm.EclDamage;
    $2F, $30: EclVm.EclAndOr;
    $31: EclVm.EclSpriteOff;
    $32: EclVm.EclFindItem;
    $33: EclVm.EclPrintReturn;
    $34: EclVm.EclClock;
    $35: EclVm.EclSaveTable;
    $36: EclVm.EclAddNpc;
    $38: EclVm.EclProgram;
    $39: EclVm.EclWho;
    $3A: EclVm.EclDelay;
    $3B: EclVm.EclSpell;
    $3C: EclVm.EclProtection;
    $3D: EclVm.EclClearBox;
    $3E: EclVm.EclDump;
    $3F: EclVm.EclFindSpecial;
    $40: EclVm.EclDestroyItems;
    $41: EclVm.EclAwardExperience;
  end;
end;

{ Runs ECL commands from an address until EXIT or the party is destroyed, logging each opcode to the debug trace.
  @param(vmAddr The script address to start at.) }
procedure CallEclScript;
var
  { Unused in this version; see the other implementations of this routine. }
  commandCount: Byte;
begin
  GDVars.loopIdx := 1;
  GDVars.eclIp := vmAddr;
  GDVars.eclStop := 0;
  while (GDVars.eclStop = 0) and (GDVars.partyDefeated = 0) do begin
    GDVars.prevOp := GDVars.curOp;
    GDVars.curOp := GDVars.zone3^[GDVars.eclIp];
    EclVm.DispatchEclCommand;
    EclTrace.ShowTrace(EclTrace.OpName(GDVars.curOp), 0, 0, 0);
  end;
  GDVars.eclStop := 0;
end;

{ Finishes a NEWECL: for each newly loaded block it frees the animation, refreshes the cell event and the wall ahead,
  runs the block's entry script, redraws the map view when the view's files are loaded, and runs the block's run and
  search scripts, restoring the selected character; a NEWECL in any of them repeats it for the next block. The interface
  state is remembered at the end. }
procedure NewEclDone;
begin
  repeat
    Portrait.FreeAnimation(GDVars.animData);
    GDVars.savedPicArcName := '';
    GDVars.savedPicArcId := 255;
    GDVars.newEclFlag := 0;
    GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
    GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
    GDVars.movedParty := True;
    GDVars.zone1^.cell[$7ED5] := 0;
    GDVars.savedChar := GDVars.curChar;
    EclVm.CallEclScript(GDVars.vmRun[5]);
    if GDVars.newEclFlag = 0 then
      GDVars.zone0^.cell[$4BF2] := GDVars.curEclId;
    if GDVars.newEclFlag = 0 then begin
      if (((GDVars.savedInterface <> C_Ifc.INDOORS) or (GDVars.interfaceState = C_Ifc.INDOORS)) and
          (GDVars.filesLoaded <> 0)) or
          ((GDVars.savedInterface = C_Ifc.INDOORS) and (GDVars.interfaceState = C_Ifc.INDOORS)) then
        MapView.DisplayMapView;
      GDVars.newEclFlag := 0;
      EclVm.CallEclScript(GDVars.vmRun[1]);
      if GDVars.newEclFlag = 0 then begin
        EclVm.CallEclScript(GDVars.vmRun[2]);
        if GDVars.newEclFlag = 0 then begin
          GDVars.curChar := GDVars.savedChar;
          CharHlp.DisplayRoster(GDVars.curChar);
        end;
      end;
    end;
  until GDVars.newEclFlag = 0;
  GDVars.savedInterface := GDVars.interfaceState;
end;

procedure GameLoop;
var
  cmd: Char;
  cr: Types.PCharRecord;
  sav: Byte;
begin
  GDVars.savedChar := GDVars.curChar;
  GDVars.viewDirty := 1;
  GDVars.eclProtection := 0;
  GDVars.piecesLoaded := 0;
  GDVars.mapLoaded := 0;
  GDVars.restoreChar := 0;
  GDVars.filesLoaded := 0;
  GDVars.needPanelRedraw := 1;
  GDVars.interfaceState := C_Ifc.INDOORS;
  GDVars.newEclFlag := 0;
  if GDVars.zone0^.cell[$4BF2] = 0 then begin
    GDVars.needPanelRedraw := 0;
    if GDVars.demoMode then begin
      Border.DrawWindowFrame(1);
      GDVars.curEclId := 3;
      GDVars.diskNum := 1;
    end else begin
      GDVars.diskNum := 2;
      GDVars.curEclId := 17;
      CharHlp.DisplayRoster(GDVars.curChar);
    end;
  end else
    GDVars.curEclId := Byte(GDVars.zone0^.cell[$4BF2]);
  if GDVars.zone0^.cell[$4BE6] = 0 then
    GDVars.interfaceState := C_Ifc.OVERLAND;
  if EclMenu.LoadEclScript(GDVars.curEclId) then
    EclMenu.EclInit;
  if GDVars.demoMode then begin
    Border.DrawExploreFrame;
    CharHlp.DisplayRoster(GDVars.curChar);
  end;
  EclVm.CallEclScript(GDVars.vmRun[5]);
  if GDVars.demoMode then begin
    cr := GDVars.creatureList;
    while cr <> nil do begin
      GDVars.curChar := cr;
      cr := cr^.nextCharAddr;
      CharGen.RemoveCreature(True, True);
    end;
  end else begin
    if GDVars.newEclFlag = 0 then
      GDVars.zone0^.cell[$4BF2] := GDVars.curEclId
    else
      EclVm.NewEclDone;
    if (GDVars.interfaceState <> C_Ifc.OVERLAND) and (GDVars.loadedSave <> 0) then begin
      if GDVars.needPanelRedraw = 1 then
        CharHlp.DisplayNoncombatInterface;
      GDVars.viewDirty := 1;
      MapView.DisplayMapView;
    end;
    GDVars.loadedSave := 0;
    GDVars.moveMode := 0;
    repeat
      cmd := Explore.MapMainMenu;
      GDVars.savedChar := GDVars.curChar;
      if GDVars.newEclFlag = 0 then
        GDVars.zone0^.cell[$4BF2] := GDVars.curEclId;
      while ((GDVars.zone1^.cell[$7ECA] > 1) or (UpCase(cmd) = 'E')) and (GDVars.partyDefeated = 0) do
      begin
        if UpCase(cmd) = 'E' then
        begin
          sav := GDVars.horizChoice;
          GDVars.horizChoice := 1;
          EclVm.EnterCamp;
          GDVars.horizChoice := sav;
        end else begin
          GDVars.searchBak := GDVars.zone1^.cell[$7ECA] and 1;
          GDVars.zone1^.cell[$7ECA] := 1;
          GDVars.viewDirty := 1;
          MapView.DisplayMapView;
          EclVm.CallEclScript(GDVars.vmRun[2]);
          if GDVars.newEclFlag <> 0 then
            EclVm.NewEclDone;
          GDVars.zone1^.cell[$7ECA] := GDVars.searchBak;
        end;
        if GDVars.partyDefeated = 0 then begin
          cmd := Explore.MapMainMenu;
          GDVars.savedChar := GDVars.curChar;
        end;
      end;
      if GDVars.partyDefeated = 0 then
        EclVm.CallEclScript(GDVars.vmRun[1]);
      if GDVars.newEclFlag <> 0 then
        EclVm.NewEclDone
      else if GDVars.partyDefeated = 0 then begin
        GDVars.zone0^.cell[$4BF0] := GDVars.partyPos.mapX;
        GDVars.zone0^.cell[$4BF1] := GDVars.partyPos.mapY;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        if (GDVars.partyPos.mapX <> GDVars.zone0^.cell[$4BF0]) or
            (GDVars.partyPos.mapY <> GDVars.zone0^.cell[$4BF1]) then
          SoundDrv.SoundCommand(GDConsts.stepSound);
        GDVars.eclGraphics := False;
        GDVars.picDrawn := 1;
        EclVm.CallEclScript(GDVars.vmRun[2]);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone;
      end;
    until GDVars.partyDefeated <> 0;
    GDVars.partyDefeated := 0;
    cr := GDVars.creatureList;
    while cr <> nil do begin
      GDVars.curChar := cr;
      cr := cr^.nextCharAddr;
      CharGen.RemoveCreature(False, True);
    end;
  end;
end;

begin
end.
