{ Save and load: the multi-file character save set (.who for the character, .stf for items, .sfx for effects), the save
  mode switch, import of SECRET and CURSE characters, and the interactive save-as dialog. }
{$O+,F+,I-}
{$A-}
unit SaveLoad;

interface

uses Types, CharHlp, ClassCal, MenuCore, Portrait, View3D, MapTiles, Blit, TextRend, DaxIo, GameIo, Dos, Crt, GDConsts,
  GDVars, C_Race, C_Class, C_Keys, C_Ifc, C_Stat;

{ Lists the characters that can be loaded: the *.guy files (save mode 0, CURSE imports) or *.who files (save mode 1) of
  the mode's record size in the save directory, leaving out characters already in the party and those with a byte above
  $7F at the mode's flag offset. Both lists stay empty when the save directory cannot be reached or for another save
  mode.
  @param(a Receives the stored names, padded, with "from saved game X" for a .sav file.)
  @param(b Receives the matching file names, in the same order.) }
procedure LoadCharlist(var a, b: Types.PItemRec);

{ Makes sure the save directory can be reached in save modes 0 and 1: while the game disk (volume SECRET, or CURSE in
  mode 0) sits in a floppy save drive it asks for the save disk; a missing directory is created, on a floppy after
  asking whether the save disk is in. An unexpected error on a hard disk is reported and fails. Note: in mode 1 that
  error message ends in a stray "hali".
  @returns(True when the directory is ready.) }
function CheckSaveDir: Boolean;

{ ORs one icon's pixels into another and ANDs its transparency mask into the other's.
  @param(a The icon to add.)
  @param(b The icon that receives it.) }
procedure MergeIcon(a, b: Types.PImgBuf);

{ Builds the current character's combat icon in its slot (on disk 1): loads the head (CHEAD) icon into scratch slot 11
  and the body (CBODY) icon into the slot, both for its icon size, ORs the head's two frames onto the body's and,
  outside CGA, recolors color 8 to 0 in each; then frees slot 11 and discards pending keys.
  @param(loading Also recolors the icon with the character's six saved icon colors.) }
procedure LoadCharIconAnim(loading: Boolean);

{ Deletes a character's .who, .stf and .sfx files from the save directory.
  @param(cr The character, whose name gives the file names.) }
procedure DeleteCharacterFiles(cr: Pointer);

{ Saves a character in the save directory in save mode 1: its record as <name>.who (or <fname>.sav), its items, with
  their bundled items, as .stf and its effects as .sfx. With no room it offers to try another disk; choosing Ok ('Lose
  character?') goes on writing anyway; instead of overwriting a .who file it can take a new name, which also renames the
  character.
  @param(cr The character.)
  @param(fname The file name for a saved game's copy, or empty to save under the character's name.) }
procedure SaveChar(cr: Types.PCharRecord; fname: Types.TStr8);

{ Loads a character from the save directory: its record (in save mode 0 converted from a CURSE record by
  ConvertPoolRecord, in save mode 1 marking a paladin's cure disease as available), then its .stf items in save mode 1
  and its .sfx effects when those files exist, and recalculates its stats and class values. Note: the buffer for a
  converted record is never freed.
  @param(name The file name, with its extension.)
  @param(cr Receives the character.)
  @param(savedGame Unused.)
  @param(askDisk Asks for the save disk rather than the data disk while the file is missing.) }
procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);

{ Loads a monster from MON1CHA.DAX, with its effects from MON1SPC and its items from MON1ITM; quits when the monster is
  missing.
  @param(id The monster number.)
  @param(cr Receives the monster.) }
procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);

{ Adds a monster to the party, unless it already has 8 members, with its combat icon from CPIC (in the demo, monsters 50
  to 52 take icons 77, 76 and 66).
  @param(id The monster number, also kept as its combat icon ID.) }
procedure AddCreatureToParty(id: Byte);

{ Offers the saved games A..J in the save directory and loads the chosen SAVGAM<x>.DAT: the disk number, three memory
  zones, the party position, the interface states, the three wall-set slots and the members' file names. The picture,
  animation and speed settings come back from zone 0, each member is loaded from its .sav file, the members' working
  files are deleted, the icons are rebuilt, the data disk is taken from zone 1, and the 3D map and wall sets or the
  overland picture are reloaded. The interface state becomes the main menu, remembering the saved one as the previous
  state. }
procedure LoadGame;

{ Asks which game (A..J) to save and writes SAVGAM<x>.DAT with the disk number, three memory zones, the party position,
  the interface states, the three wall-set slots and the members' file names CHRDAT<x><n>; then saves each member under
  that name, deletes its working files and marks the game as saved. It refuses when the disk lacks room. }
procedure SaveGame;

{ Appends a character to the party, makes it current, gives it the first free order slot, and counts it in the party
  size; an NPC also has its class values recalculated. Note: with all eight order slots taken, the order slot is left at
  8.
  @param(cr The character.) }
procedure AddCharToParty(cr: Types.PCharRecord);

{ Does nothing. }
procedure NoopSaveLoad;

implementation

type

  TStr80 = String[80];
  TString15 = String[15];
  PStr15 = ^TString15;
  PArr = ^TArr;
  TArr = array[0..511] of Byte;
  PNm = ^TNm;
  TNm = String[15];
  { The legacy import record ConvertPoolRecord reads. Its named fields are the ones copied into TCharRecord field by
    field; the icon color pairs (Types.TStatPack: low nibble base color, high nibble color+8, one per statInitTbl[1..6]
    slot) are copied as one whole-array assignment. }
  PSvRec = ^TSvRec;
  TSvRec = record
    ageLead: array[$000..$075] of Byte;
    { -> TCharRecord.age }
    age: Word;
    experienceLead: array[$078..$126] of Byte;
    { -> TCharRecord.experience }
    experience: LongInt;
    xpAwardLead: array[$12B..$13B] of Byte;
    { -> TCharRecord.xpAward }
    xpAward: Word;
    iconColorsLead: array[$13E..$144] of Byte;
    { -> TCharRecord.statPack }
    iconColors: Types.TStatPack;
    iconColorsTail: array[$14B..$1A5] of Byte;
  end;
  { loop-indexed array-field views }
  PCrSlot = ^TCrSlot; TCrSlot = record p: array[1..$70] of Byte; s: array[0..100] of Byte; end;
  PSvSlot = ^TSvSlot; TSvSlot = record p: array[1..$78] of Byte; s: array[0..100] of Byte; end;
  PCrClericSlots = ^TCrClericSlots; TCrClericSlots = record p: array[1..$131] of Byte; s: array[0..7] of Byte; end;
  PCrDruidSlots = ^TCrDruidSlots; TCrDruidSlots = record p: array[1..$138] of Byte; s: array[0..7] of Byte; end;
  PCrMageSlots = ^TCrMageSlots; TCrMageSlots = record p: array[1..$146] of Byte; s: array[0..7] of Byte; end;
  PSvClericSlots = ^TSvClericSlots; TSvClericSlots = record p: array[1..$12C] of Byte; s: array[0..7] of Byte; end;
  PSvDruidSlots = ^TSvDruidSlots; TSvDruidSlots = record p: array[1..$131] of Byte; s: array[0..7] of Byte; end;
  PSvMageSlots = ^TSvMageSlots; TSvMageSlots = record p: array[1..$136] of Byte; s: array[0..7] of Byte; end;

var
  driveNames: array[0..7] of String[29] absolute GDConsts.sfxOn;

procedure LoadCharlist(var a, b: Types.PItemRec);

  { Appends the files matching pattern whose size is expectSize to outA (stored names) and outB (file names). }
  procedure ScanSaveFiles(pattern: TStr80; name1Ofs, name2Ofs, expectSize: Word; var outA, outB: Types.PItemRec);
  var
    nameNode: Types.PItemRec;
    nameTail: Types.PItemRec;
    fileNode: Types.PItemRec;
    fileTail: Types.PItemRec;
    cr: Types.PCharRecord;
    sr: SearchRec;
    cnt: Word;
    f: File;
    buf2: String[80];
    n2len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    rawName: array[0..15] of Char;
    { Unused in this version; see the other implementations of this routine. }
    matchCount: Byte;
    { write-only Str(expectSize) result }
    deadStr: String[255];
  begin
    nameNode := nil;
    fileNode := nil;
    FindFirst(pattern, 0, sr);
    while DosError = 0 do begin
      Assign(f, GDVars.saveDir + sr.Name);
      Reset(f, 1);
      Str(expectSize, deadStr);
      if FileSize(f) = expectSize then begin
        GetMem(nameNode, SizeOf(Types.TItemNode));
        GetMem(fileNode, SizeOf(Types.TItemNode));
        GameIo.FillWord(nameNode^, SizeOf(Types.TItemNode));
        GameIo.FillWord(fileNode^, SizeOf(Types.TItemNode));
        Seek(f, name1Ofs);
        BlockRead(f, nameNode^, 16, cnt);
        Seek(f, name2Ofs);
        BlockRead(f, n2len, SizeOf(n2len));
        fileNode^.name := sr.Name;
        if Copy(sr.Name, 9, 4) = '.SAV' then
          buf2 := 'from saved game ' + sr.Name[7]
        else
          buf2 := '';
        nameNode^.name := nameNode^.name + Copy(GDConsts.blanks, 1, 15 - Length(nameNode^.name)) + buf2;
        cr := GDVars.creatureList;
        while (cr <> nil) and
            (Copy(nameNode^.name, 1, 15) <> Types.PStr(cr)^ + Copy(GDConsts.blanks, 1, 15 - Length(Types.PStr(cr)^))) do
          cr := cr^.nextCharAddr;
        if (n2len > $7F) or (cr <> nil) then begin
          FreeMem(nameNode, SizeOf(Types.TItemNode));
          FreeMem(fileNode, SizeOf(Types.TItemNode));
          nameNode := nil;
          fileNode := nil;
        end;
        if nameNode <> nil then begin
          if outA = nil then begin
            outA := nameNode;
            nameTail := outA;
            outB := fileNode;
            fileTail := outB;
          end else begin
            nameTail^.next := nameNode;
            nameTail := nameTail^.next;
            fileTail^.next := fileNode;
            fileTail := fileTail^.next;
          end;
        end;
      end;
      Close(f);
      FindNext(sr);
    end;
  end;

begin
  a := nil;
  b := nil;
  if SaveLoad.CheckSaveDir then
    case GDVars.saveMode of
      0: ScanSaveFiles(GDVars.saveDir + '*.guy', GDConsts.name1Tab[GDVars.saveMode], GDConsts.name2Tab[GDVars.saveMode],
                       GDConsts.sizeTab[GDVars.saveMode], a, b);
      1: ScanSaveFiles(GDVars.saveDir + '*.who', GDConsts.name1Tab[GDVars.saveMode], GDConsts.name2Tab[GDVars.saveMode],
                       GDConsts.sizeTab[GDVars.saveMode], a, b);
    end;
end;

function CheckSaveDir: Boolean;

var
  err: Integer;
  sr: SearchRec;
  key: Char;
begin
  CheckSaveDir := False;
  case GDVars.saveMode of
    1: begin
         repeat
           while (DaxIo.GetVolumeLabel(GDVars.saveDir[1]) = 'SECRET') and (GDVars.saveDir[1] < 'C') do
             TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':');
           repeat
             FindFirst(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1), Directory, sr);
             err := DosError;
             case err of
               0: ;
               2, 18:
                 begin
                   if UpCase(GDVars.saveDir[1]) < 'C' then begin
                     key := MenuCore.YesNoMenu('Is your save disk in drive ' + GDVars.saveDir[1] + ':? ',
                                               LightMagenta, LightGreen,
                                      White, 2);
                     if key <> 'Y' then
                       TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':');
                   end;
                   MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1));
                   err := DosError;
                 end;
             else
               if UpCase(GDVars.saveDir[1]) < 'C' then
                 TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':')
               else begin
                 TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err) + 'hali');
                 Exit;
               end;
             end;
           until err in [0, 5];
         until err in [0, 5];
       end;
    0: begin
         repeat
           while (DaxIo.GetVolumeLabel(GDVars.saveDir[1]) = 'CURSE') and (GDVars.saveDir[1] < 'C') do
             TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':');
           repeat
             FindFirst(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1), Directory, sr);
             err := DosError;
             case err of
               0: ;
               2, 18:
                 begin
                   if UpCase(GDVars.saveDir[1]) < 'C' then begin
                     key := MenuCore.YesNoMenu('Is your save disk in drive ' + GDVars.saveDir[1] + ':? ',
                                               LightMagenta, LightGreen,
                                      White, 2);
                     if key <> 'Y' then
                       TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':');
                   end;
                   MkDir(Copy(GDVars.saveDir, 1, Length(GDVars.saveDir) - 1));
                   err := DosError;
                 end;
             else
               if UpCase(GDVars.saveDir[1]) < 'C' then
                 TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':')
               else begin
                 TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
                 Exit;
               end;
             end;
           until err in [0, 5];
         until err in [0, 5];
       end;
  end;
  CheckSaveDir := True;
end;

{ Does nothing. }
procedure NoopSaveLoadB;
begin
end;

procedure MergeIcon(a, b: Types.PImgBuf);
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
  i: Word;
begin
  for i := 0 to a^.imgSize - 1 do begin
    b^.data[i] := b^.data[i] or a^.data[i];
    b^.transp^[i] := b^.transp^[i] and a^.transp^[i];
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  animSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  iconIds: Byte;
  arr1: Types.TColorTab;
  arr2: Types.TColorTab;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  partIdx: Byte;
begin
  DaxIo.PushState(1);
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconClass[raceSize], portraitHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconClass[raceSize], portraitBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.iconAnims[11, 0], GDVars.iconAnims[orderNumber, 0]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmap8To0, 0, False, GDVars.iconAnims[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.iconAnims[11, 1], GDVars.iconAnims[orderNumber, 1]);
    if GDVars.displayMode <> Types.Cga then
      Blit.RemapPic(GDConsts.cmapIdent, GDConsts.cmap8To0, 0, False, GDVars.iconAnims[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        arr1[i] := i;
        arr2[i] := i;
      end;
      for i := 1 to 6 do begin
        arr2[GDConsts.statInitTbl[i]] := statPack[i] and $0F;
        arr2[GDConsts.statInitTbl[i] + 8] := (statPack[i] and $F0) shr 4;
      end;
      Blit.RemapPic(arr1, arr2, 0, False, GDVars.iconAnims[orderNumber, 0]);
      Blit.RemapPic(arr1, arr2, 0, False, GDVars.iconAnims[orderNumber, 1]);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
  GameIo.FlushKeys;
end;

procedure DeleteCharacterFiles(cr: Pointer);
var
  tmpName: String[80];
  { Unused in this version; see the other implementations of this routine. }
  fileBuf: array[0..127] of Byte;
begin
  tmpName := GDVars.saveDir + DaxIo.SanitizeFileName(Types.PStr(cr)^);
  DaxIo.DeleteIfPresent(tmpName + '.who');
  DaxIo.DeleteIfPresent(tmpName + '.stf');
  DaxIo.DeleteIfPresent(tmpName + '.sfx');
end;

procedure SaveChar(cr: Types.PCharRecord; fname: Types.TStr8);
var
  f: file;
  fn: Types.TStr40;
  ext: String[4];
  flag: Char;
  k: Byte;
  it2: Types.PItemRec;
  it: Types.PItemRec;
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  nameBuf: array[0..23] of Byte;
  err: Integer;
  total: Word;
  redraw: Boolean;
begin
  GDVars.saveMode := 1;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    total := 0;
    Inc(total, SizeOf(Types.TCharRecord));
    if cr^.itemsAddr <> nil then begin
      it := cr^.itemsAddr;
      while it <> nil do begin
        Inc(total, SizeOf(Types.TItemRec));
        it := it^.next;
      end;
    end;
    if cr^.effectsAddr <> nil then begin
      eff := cr^.effectsAddr;
      while eff <> nil do begin
        Inc(total, SizeOf(Types.TEffectRec));
        eff := eff^.next;
      end;
    end;
    flag := 'O';
    if total > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
      TextRend.DisplayAndPause(Yellow, 0, 'Can''t save.  No room on this disk.');
      flag := MenuCore.MenuHorizontal('Lose character? ', 'Ok  Try another disk', LightMagenta, LightGreen, White, 0, 0,
                                      redraw);
    end;
  until flag = 'O';
  if Length(fname) = 0 then begin
    ext := '.who';
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(cr^.name, '.'));
  end else begin
    ext := '.sav';
    fn := fname;
  end;
  repeat
    Assign(f, GDVars.saveDir + fn + ext);
    Reset(f, 1);
    err := DosError;
    if not (err in [0, 2]) then
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until (err = 0) or (err = 2);
  Close(f);
  flag := 'N';
  while (flag = 'N') and (Length(fname) = 0)
        and DaxIo.FileExists(GDVars.saveDir + fn + ext) do begin
    flag := MenuCore.YesNoMenu('Overwrite ' + fn + '? ', Yellow, LightGreen, White, 2);
    if flag = 'N' then begin
      fn := '';
      while Length(fn) = 0 do
        fn := TextRend.ReadString('New file name: ', LightGreen, 0, 8);
      PStr15(cr)^ := fn;
    end;
  end;
  Assign(f, GDVars.saveDir + fn + ext);
  Rewrite(f, 1);
  BlockWrite(f, cr^, SizeOf(Types.TCharRecord));
  Close(f);
  DaxIo.DeleteIfPresent(GDVars.saveDir + fn + '.stf');
  if cr^.itemsAddr <> nil then begin
    Assign(f, GDVars.saveDir + fn + '.stf');
    Rewrite(f, 1);
    it := cr^.itemsAddr;
    while it <> nil do begin
      BlockWrite(f, it^, SizeOf(Types.TItemRec));
      if it^.itemTypeV2 = 'I' then begin
        it2 := it;
        for k := 1 to it^.countV1 do begin
          it2 := it2^.bundleNextV1;
          BlockWrite(f, it2^, SizeOf(Types.TItemRec));
        end;
      end;
      it := it^.next;
    end;
    Close(f);
  end;
  DaxIo.DeleteIfPresent(GDVars.saveDir + fn + '.sfx');
  if cr^.effectsAddr <> nil then begin
    Assign(f, GDVars.saveDir + fn + '.sfx');
    Rewrite(f, 1);
    eff := cr^.effectsAddr;
    while eff <> nil do begin
      BlockWrite(f, eff^, SizeOf(Types.TEffectRec));
      eff := eff^.next;
    end;
    Close(f);
  end;
end;

procedure LoadChar(name: String; cr: Types.PCharRecord; savedGame, askDisk: Boolean);
var
  f: File;
  count: Word;
  subItemW: Types.PItemRec;
  itemW: Types.PItemRec;
  itemH: Types.PItemRec;
  effW: Types.PEffectRec;
  effH: Types.PEffectRec;
  fname: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  fileOpened: Boolean;
  savedBuf: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  importRecord: array[1..284] of Byte;
  bundleIdx: Byte;

  {$F+}
  { Converts the imported record in savedBuf into cr, trimming its name's spaces and capping its base Strength. }
  procedure ConvertPoolRecord;
  var
    i: Byte;
    k: Integer;
    j: ShortInt;
  begin
    GameIo.FillWord(cr^, SizeOf(Types.TCharRecord));

    while PNm(savedBuf)^[1] = ' ' do
      PNm(savedBuf)^ := Copy(PNm(savedBuf)^, 2, Length(PNm(savedBuf)^) - 1);
    i := Length(PNm(savedBuf)^);
    while PNm(savedBuf)^[i] = ' ' do
      Dec(i);
    PNm(savedBuf)^ := Copy(PNm(savedBuf)^, 1, i);

    PNm(cr)^ := PNm(savedBuf)^;

    Move(PArr(savedBuf)^[$10], cr^.stats, SizeOf(cr^.stats));
    cr^.strExc := PArr(savedBuf)^[$1C];
    cr^.strExcMax := PArr(savedBuf)^[$1D];
    cr^.baseToHit := PArr(savedBuf)^[$73];

    case PArr(savedBuf)^[$74] of
      1: cr^.race := C_Race.DWARF;
      2: cr^.race := C_Race.ELF;
      3: cr^.race := C_Race.GNOME;
      4: cr^.race := C_Race.HALF_ELF;
      5: cr^.race := C_Race.HALFLING;
      7: cr^.race := C_Race.HUMAN;
      6, 0: cr^.race := C_Race.MONSTER;
    end;

    cr^.charClass := PArr(savedBuf)^[$75];
    cr^.age := PSvRec(savedBuf)^.age;
    cr^.hpMax := PArr(savedBuf)^[$78];

    for k := 1 to 100 do
      case k of
        1..$23, $25..$37, $39..$3E, $40..$59, $5B..$5F, $61, $63, $2C:
          PCrSlot(cr)^.s[k] := PSvSlot(savedBuf)^.s[k];
      else
        PCrSlot(cr)^.s[k] := 0;
      end;

    cr^.attackLevel := PArr(savedBuf)^[$DD];
    cr^.iconDimensions := PArr(savedBuf)^[$DE];
    Move(PArr(savedBuf)^[$DF], cr^.saves, SizeOf(cr^.saves));
    cr^.movementBase := PArr(savedBuf)^[$E4];
    cr^.highestLevel := PArr(savedBuf)^[$E5];
    cr^.dualClassThreshold := PArr(savedBuf)^[$E6];
    cr^.drainedLevels := PArr(savedBuf)^[$E7];
    cr^.drainedHps := PArr(savedBuf)^[$E8];
    Move(PArr(savedBuf)^[$EA], cr^.thiefSkills[1], 8);

    cr^.npc := PArr(savedBuf)^[$F7];
    cr^.modified := PArr(savedBuf)^[$F8];
    cr^.formerClass := PArr(savedBuf)^[$F9];
    cr^.formerClassTail := PArr(savedBuf)^[$FA];

    Move(PArr(savedBuf)^[$109], cr^.classLevelA, SizeOf(cr^.classLevelA));
    Move(PArr(savedBuf)^[$111], cr^.classLevelB, SizeOf(cr^.classLevelB));

    cr^.gender := PArr(savedBuf)^[$119];
    cr^.alignment := PArr(savedBuf)^[$11B];
    Move(PArr(savedBuf)^[$11C], PArr(cr)^[$121], 2);
    Move(PArr(savedBuf)^[$11E], cr^.unarmedRollsA, SizeOf(cr^.unarmedRollsA));
    Move(PArr(savedBuf)^[$120], cr^.unarmedDiceA, SizeOf(cr^.unarmedDiceA));
    Move(PArr(savedBuf)^[$122], cr^.unarmedModA, SizeOf(cr^.unarmedModA));

    cr^.acBase := PArr(savedBuf)^[$124];
    cr^.useStrength := PArr(savedBuf)^[$125];
    cr^.combatIconId := PArr(savedBuf)^[$126];

    cr^.experience := PSvRec(savedBuf)^.experience;

    cr^.classMask := PArr(savedBuf)^[$12B];
    cr^.hpRolled := PArr(savedBuf)^[$12C];

    for j := 1 to 5 do begin
      PCrClericSlots(cr)^.s[j] := PSvClericSlots(savedBuf)^.s[j];
      PCrDruidSlots(cr)^.s[j] := PSvDruidSlots(savedBuf)^.s[j];
      PCrMageSlots(cr)^.s[j] := PSvMageSlots(savedBuf)^.s[j];
    end;

    cr^.xpAward := PSvRec(savedBuf)^.xpAward;
    cr^.pcHpRolled := PArr(savedBuf)^[$13E];
    cr^.pcHpRolledTail[$151] := PArr(savedBuf)^[$13F];
    cr^.pcHpRolledTail[$152] := PArr(savedBuf)^[$140];
    cr^.portraitHead := PArr(savedBuf)^[$141];
    cr^.portraitBody := PArr(savedBuf)^[$142];
    cr^.raceSize := PArr(savedBuf)^[$144];

    cr^.statPack := PSvRec(savedBuf)^.iconColors;
    Move(PArr(savedBuf)^[$151], cr^.equipped, SizeOf(cr^.equipped));

    cr^.handsEquipped := PArr(savedBuf)^[$185];
    cr^.saveBonus := PArr(savedBuf)^[$186];
    cr^.status := PArr(savedBuf)^[$195];
    cr^.enabled := PArr(savedBuf)^[$196];
    cr^.hostile := PArr(savedBuf)^[$197];
    cr^.toHitCur := PArr(savedBuf)^[$199];
    Move(PArr(savedBuf)^[$19A], cr^.acCurArr, SizeOf(cr^.acCurArr));
    Move(PArr(savedBuf)^[$19C], cr^.curAtt, SizeOf(cr^.curAtt));
    Move(PArr(savedBuf)^[$19E], cr^.curRollsA, SizeOf(cr^.curRollsA));
    Move(PArr(savedBuf)^[$1A0], cr^.curDiceA, SizeOf(cr^.curDiceA));
    Move(PArr(savedBuf)^[$1A2], cr^.curModA, SizeOf(cr^.curModA));
    cr^.hpCurrent := PArr(savedBuf)^[$1A4];
    { Cap the imported base strength at the race/gender limit. }
    with Types.PCharRecord(cr)^ do
      if GDConsts.raceLimits[race].strMax[gender] < stats[C_Stat.STRENGTH].base then
        stats[C_Stat.STRENGTH].base := GDConsts.raceLimits[race].strMax[gender];
    cr^.movementCur := PArr(savedBuf)^[$1A5];
  end;

begin
  if askDisk then
    fname := 'Put save disk in '
  else
    fname := driveNames[GDVars.diskNum];
  fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name, fname, #0, f);
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  GameIo.FillWord(cr^, SizeOf(Types.TCharRecord));
  case GDVars.saveMode of
    1: begin
         BlockRead(f, cr^, SizeOf(Types.TCharRecord), count);
         Close(f);
         if (cr^.classLevelA[C_Class.PALADIN] > 0)
            or ((cr^.formerClass = C_Class.PALADIN) and ClassCal.EarlierClassActive(cr)) then
           cr^.cureDiseaseLeft := 1;
         cr^.itemsAddr := nil;
         cr^.effectsAddr := nil;
         cr^.combatAddr := nil;
         cr^.nextCharAddr := nil;
       end;
    0: begin
         GetMem(savedBuf, SizeOf(TSvRec));
         BlockRead(f, savedBuf^, SizeOf(TSvRec), count);
         Close(f);
         cr^.itemsAddr := nil;
         cr^.effectsAddr := nil;
         cr^.combatAddr := nil;
         cr^.nextCharAddr := nil;
         ConvertPoolRecord;
       end;
  end;
  Delete(name, Pos('.', name), 4);
  if DaxIo.FileExists(GDVars.saveDir + name + '.stf') and (GDVars.saveMode = 1) then begin
    GetMem(itemH, SizeOf(itemH^));
    fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name + '.stf', fname, #0, f);
    repeat
      BlockRead(f, itemH^, SizeOf(Types.TItemRec), count);
      if count = SizeOf(Types.TItemRec) then begin
        if cr^.itemsAddr = nil then begin
          GetMem(cr^.itemsAddr, SizeOf(cr^.itemsAddr^));
          itemW := cr^.itemsAddr;
        end else begin
          GetMem(itemW^.next, SizeOf(itemW^.next^));
          itemW := itemW^.next;
        end;
        itemW^ := itemH^;
        itemW^.next := nil;
        if itemW^.itemTypeV2 = 'I' then begin
          subItemW := itemW;
          for bundleIdx := 1 to itemW^.countV1 do begin
            GetMem(subItemW^.bundleNextV1, SizeOf(subItemW^.bundleNextV1^));
            subItemW := subItemW^.bundleNextV1;
            BlockRead(f, subItemW^, SizeOf(Types.TItemRec), count);
          end;
          subItemW^.bundleNextV1 := nil;
        end;
      end;
    until count <> SizeOf(Types.TItemRec);
    Close(f);
    FreeMem(itemH, SizeOf(itemH^));
  end;
  if DaxIo.FileExists(GDVars.saveDir + name + '.sfx') then begin
    GetMem(effH, SizeOf(effH^));
    fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + name + '.sfx', fname, #0, f);
    repeat
      BlockRead(f, effH^, SizeOf(Types.TEffectRec), count);
      if count = SizeOf(Types.TEffectRec) then begin
        if cr^.effectsAddr = nil then begin
          GetMem(cr^.effectsAddr, SizeOf(cr^.effectsAddr^));
          effW := cr^.effectsAddr;
        end else begin
          GetMem(effW^.next, SizeOf(effW^.next^));
          effW := effW^.next;
        end;
        effW^ := effH^;
        effW^.next := nil;
      end;
    until count <> SizeOf(Types.TEffectRec);
    Close(f);
    FreeMem(effH, SizeOf(effH^));
  end;
  GameIo.FlushKeys;
  CharHlp.RecalcStats(Types.PCharRecord(cr));
  ClassCal.RecalcClassStats(cr);
end;

procedure LoadCreatureData(id: Byte; cr: Types.PCharRecord);
var
  size: Word;
  data: Types.PByteArr;
  readOfs: Word;
  it: Types.PItemRec;
  eff: Types.PEffectRec;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  itemIdx: Word;
begin
  numStr := '1';
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size = 0 then begin
    TextRend.DisplayAndPause(White, 0, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(data^, cr^, SizeOf(Types.TCharRecord));
  with cr^ do begin
    itemsAddr := nil;
    effectsAddr := nil;
    nextCharAddr := nil;
    combatAddr := nil;
  end;
  FreeMem(data, size);
  GDVars.suppressInsertPrompt := #1;

  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    readOfs := 0;
    GetMem(cr^.effectsAddr, SizeOf(cr^.effectsAddr^));
    eff := cr^.effectsAddr;
    repeat
      Move(data^[readOfs], eff^, SizeOf(Types.TEffectRec));
      eff^.next := nil;
      Inc(readOfs, SizeOf(Types.TEffectRec));
      if readOfs < size then begin
        GetMem(eff^.next, SizeOf(eff^.next^));
        eff := eff^.next;
      end;
    until readOfs >= size;
    FreeMem(data, size);
  end;

  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    readOfs := 0;
    GetMem(cr^.itemsAddr, SizeOf(cr^.itemsAddr^));
    it := cr^.itemsAddr;
    repeat
      Move(data^[readOfs], it^, 63);
      it^.bundleNextV1 := nil;
      it^.next := nil;
      Inc(readOfs, 63);
      if readOfs < size then begin
        GetMem(it^.next, SizeOf(it^.next^));
        it := it^.next;
      end;
    until readOfs >= size;
    FreeMem(data, size);
  end;

  GDVars.suppressInsertPrompt := #0;
  GameIo.FlushKeys;
end;

procedure AddCreatureToParty(id: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  slot: Byte;
begin
  if GDVars.zone1^.partySize > 7 then Exit;
  GetMem(cr, SizeOf(cr^));
  SaveLoad.LoadCreatureData(id, cr);
  cr^.combatIconId := id;
  if GDVars.demoMode then
    case id of
      50: id := 77;
      51: id := 76;
      52: id := 66;
    end;
  SaveLoad.AddCharToParty(cr);
  MapTiles.LoadIconAnim('CPIC', id, cr^.orderNumber);
end;

procedure AddCharToParty(cr: Types.PCharRecord);
var
  p: Types.PCharRecord;
  used: array[0..7] of Byte;
begin
  cr^.orderNumber := 255;
  if GDVars.creatureList = nil then
    GDVars.creatureList := cr
  else begin
    p := GDVars.creatureList;
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
    p^.nextCharAddr := cr;
  end;
  GDVars.curChar := cr;
  GameIo.FillWord(used, SizeOf(used));
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..7] then
      used[p^.orderNumber] := 1;
    p := p^.nextCharAddr;
  end;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^.partySize);
  if cr^.npc > $7F then
    ClassCal.RecalcClassStats(cr);
end;

procedure LoadGame;
var
  names: array[1..8] of String[40];
  f: File;
  i: Byte;
  cr: Types.PCharRecord;
  fn: String[40];
  nread: Word;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fileOpened: Boolean;
  letter: Char;
  ext: Boolean;
  menuStr: String[20];
begin
  GDVars.saveMode := 1;
  if not SaveLoad.CheckSaveDir then Exit;
  menuStr := '';
  for letter := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.saveDir + 'savgam' + letter + '.dat') then
      menuStr := menuStr + letter + ' ';
  if Length(menuStr) = 0 then Exit;
  Delete(menuStr, Length(menuStr), 1);
  repeat
    letter := MenuCore.MenuHorizontal('Load Which Game: ', menuStr, LightMagenta, LightGreen, White, 0, 0, ext);
  until ((letter in ['A'..'J']) and DaxIo.FileExists(GDVars.saveDir + 'savgam' + letter + '.dat')) or
      (letter = C_Keys.NONE);
  if letter = C_Keys.NONE then Exit;
  fileOpened := DaxIo.OpenWithRetry(GDVars.saveDir + 'savgam' + letter + '.dat', 'Put save disk in ' + GDVars.saveDir,
                                    #1, f);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
  GDVars.loadedSave := 1;
  BlockRead(f, GDVars.diskNum, SizeOf(GDVars.diskNum), nread);
  BlockRead(f, GDVars.zone0^, SizeOf(GDVars.zone0^), nread);
  BlockRead(f, GDVars.zone1^, SizeOf(GDVars.zone1^), nread);
  BlockRead(f, GDVars.zone2^, SizeOf(Types.TZone2), nread);
  BlockRead(f, GDVars.partyPos, SizeOf(GDVars.partyPos), nread);
  BlockRead(f, GDVars.savedInterface, SizeOf(GDVars.savedInterface), nread);
  BlockRead(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState), nread);
  for i := 1 to 3 do begin
    BlockRead(f, GDVars.wallSetCache[i].defId, SizeOf(GDVars.wallSetCache[i].defId), nread);
    BlockRead(f, GDVars.wallSetCache[i].symSet, SizeOf(GDVars.wallSetCache[i].symSet), nread);
  end;
  BlockRead(f, cnt, SizeOf(cnt), nread);
  BlockRead(f, names, SizeOf(names), nread);
  Close(f);
  GDVars.picsOn := GDVars.zone0^.savedPicsAnim div 2;
  GDVars.animOn := GDVars.zone0^.savedPicsAnim and 1;
  GDVars.gameDelay := GDVars.zone0^.savedGameDelay;
  GDVars.zone1^.partySize := 0;
  for i := 1 to cnt do begin
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(names[i], '.'));
    if DaxIo.FileExists(GDVars.saveDir + fn + '.sav') then begin
      GetMem(cr, SizeOf(cr^));
      SaveLoad.LoadChar(fn + '.sav', cr, True, True);
      SaveLoad.AddCharToParty(cr);
      if not SaveLoad.CheckSaveDir then Exit;
    end;
  end;
  cr := GDVars.creatureList;
  while cr <> nil do begin
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  while GDVars.curChar <> nil do begin
    if GDVars.curChar^.npc < $80 then
      SaveLoad.LoadCharIconAnim(True)
    else
      MapTiles.LoadIconAnim('CPIC', GDVars.curChar^.combatIconId, GDVars.curChar^.orderNumber);
    GDVars.curChar := GDVars.curChar^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  GDVars.diskNum := GDVars.zone1^.diskNum;
  if GDVars.zone0^.view3dFlag <> 0 then begin
    if GDVars.wallSetCache[1].defId > 0 then
      View3D.Load3DMap(GDVars.zone0^.mapId);
    for i := 1 to 3 do
      if GDVars.wallSetCache[i].defId > 0 then
        View3D.LoadWallSet(Lo(GDVars.wallSetCache[i].defId), Lo(GDVars.wallSetCache[i].symSet));
  end else
    Portrait.LoadBigPic(121);
  GameIo.FlushKeys;
  MenuCore.ClearBottomLine;
  GDVars.savedInterface := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.MAIN_MENU;
end;

procedure SaveGame;
var
  names: array[1..8] of String[40];
  f: File;
  i: Byte;
  cr: Types.PCharRecord;
  numStr: String[1];
  { Unused in this version; see the other implementations of this routine. }
  fileName: String[40];
  ext: Boolean;
  letter: Char;
  err: Integer;
  total: Word;

  { Returns the bytes the members' files need: a record each plus its items and effects. }
  function ComputePartySaveSize: Word;
  var
    cr: Types.PCharRecord;
    it: Types.PItemRec;
    eff: Types.PEffectRec;
    total: Word;
  begin
    total := 0;
    cr := GDVars.creatureList;
    while cr <> nil do begin
      Inc(total, SizeOf(Types.TCharRecord));
      if cr^.itemsAddr <> nil then begin
        it := cr^.itemsAddr;
        while it <> nil do begin
          Inc(total, SizeOf(Types.TItemRec));
          it := it^.next;
        end;
      end;
      if cr^.effectsAddr <> nil then begin
        eff := cr^.effectsAddr;
        while eff <> nil do begin
          Inc(total, SizeOf(Types.TEffectRec));
          eff := eff^.next;
        end;
      end;
      cr := cr^.nextCharAddr;
    end;
    ComputePartySaveSize := total;
  end;

begin
  repeat
    letter := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta, LightGreen, White, 0,
                        Byte(GDVars.interfaceState = C_Ifc.CAMPING), ext);
  until letter in [C_Keys.NONE, 'A'..'J'];
  if letter = C_Keys.NONE then Exit;
  GDVars.saveMode := 1;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(GDVars.saveDir + 'savgam' + letter + '.dat') then
    total := 0
  else
    total := 5128;
  Inc(total, ComputePartySaveSize);
  if total > DiskFree(Ord(UpCase(GDVars.saveDir[1])) - 64) then begin
    TextRend.DisplayAndPause(Yellow, 0, 'Can''t save.  No room on this disk.');
    Exit;
  end;
  repeat
    Assign(f, GDVars.saveDir + 'savgam' + letter + '.dat');
    Rewrite(f, 1);
    err := DosError;
    if not (err in [0, 2, 18]) then
      if UpCase(GDVars.saveDir[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, 0, 'Put save disk in ' + GDVars.saveDir[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, 0, 'Unexpected error during save: ' + CharHlp.Uint8Str(err));
        Close(f);
        Exit;
      end;
  until err in [0, 2, 18];
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 0, 'Saving...Please Wait');
  GDVars.zone0^.savedGameDelay := GDVars.gameDelay;
  GDVars.zone0^.savedPicsAnim := GDVars.picsOn * 2 + GDVars.animOn;
  GDVars.zone1^.diskNum := GDVars.diskNum;
  BlockWrite(f, GDVars.diskNum, SizeOf(GDVars.diskNum));
  BlockWrite(f, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(f, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(f, GDVars.zone2^, SizeOf(Types.TZone2));
  BlockWrite(f, GDVars.partyPos, SizeOf(GDVars.partyPos));
  BlockWrite(f, GDVars.savedInterface, SizeOf(GDVars.savedInterface));
  BlockWrite(f, GDVars.interfaceState, SizeOf(GDVars.interfaceState));
  for i := 1 to 3 do begin
    BlockWrite(f, GDVars.wallSetCache[i].defId, SizeOf(GDVars.wallSetCache[i].defId));
    BlockWrite(f, GDVars.wallSetCache[i].symSet, SizeOf(GDVars.wallSetCache[i].symSet));
  end;
  i := 0;
  cr := GDVars.creatureList;
  if cr = nil then
    TextRend.DisplayAndPause(Yellow, 0, 'WARNING: Problem Saving Characters');
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    names[i] := 'CHRDAT' + letter + numStr;
    cr := cr^.nextCharAddr;
  end;
  BlockWrite(f, i, SizeOf(i));
  BlockWrite(f, names, SizeOf(names));
  Close(f);
  cr := GDVars.creatureList;
  i := 0;
  while cr <> nil do begin
    Inc(i);
    Str(i, numStr);
    SaveLoad.SaveChar(cr, 'CHRDAT' + letter + numStr);
    SaveLoad.DeleteCharacterFiles(cr);
    cr := cr^.nextCharAddr;
  end;
  GDVars.gameSaved := 1;
  MenuCore.ClearBottomLine;
end;

procedure NoopSaveLoad;
begin
end;

begin
end.
