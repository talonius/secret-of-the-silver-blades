{ ECL-VM support: the ECL (Event Control Language) support library, not the opcode dispatcher (that is EclVm). It owns
  the GBVM address space, the ECL operand decoder, the ECL-facing menus, the six COMPARE flags, GOSUB's return stack,
  party-forward movement, and the ROB and DAMAGE action opcodes. }
{$O+,F+,A-,I-,V-}
unit EclMenu;

interface

uses Types, SaveLoad, ViewChar, FxEngine, CharHlp, ClassCal, MenuCore, MapView, Portrait, View3D, TextRend, DaxIo,
  GameIo, Crt, GDConsts, GDVars, C_Status, C_Money, C_Keys, C_Dir, C_Ifc;

{ Reads the value of a loaded script argument: type 0 is an immediate byte, types 1, 3 and $80 read the GBVM word at the
  argument's address, and types 2 and $81 are an immediate word. Other types leave the result undefined.
  @param(idx The argument, from 1.)
  @returns(The argument's value.) }
function GetEclVar(idx: ShortInt): Word;

{ Decodes the arguments of the current script command: each has a type byte and a low byte, and types 1..3 add a high
  byte. Type $80 is an inline packed string of that length and $81 the address of a string; both go to the next script
  string. Leaves the instruction pointer on the next command.
  @param(count The number of arguments.) }
procedure LoadEclVars(count: Byte);

{ Resets the script interpreter for a new script: its graphics and protection flags, two status flags, the view color
  selectors, monster flags, icon animation slot (8), instruction pointer, return stack and comparison flags, and a few
  zone words (no picture, rest timers off, anti-magic off), then reads the script's five entry addresses. For a new game
  (not a loaded one) it also clears zone-0 words $4C00..$4C1F and zone-1 words $7F79..$7F82. }
procedure EclInit;

{ Loads a script block from ECL<disk>.DAX into the cleared script zone, skipping its 2-byte header, and keeps retrying
  until the block loads.
  @param(scriptId The script's block in the file.)
  @returns(Always True.) }
function LoadEclScript(scriptId: Byte): Boolean;

{ Allocates a creature record and loads a monster into it.
  @param(id The monster's record number.)
  @param(cr Receives the new record.)
  @param(inv Receives its item list.)
  @param(eff Receives its effect list.) }
procedure InitCreature(id: Byte; var cr: Types.PCharRecord; var inv: Types.PItemRec; var eff: Types.PEffectRec);

{ Works out how far ahead a monster can appear. Outside the 3D view it is 2, also stored as the zone's monster distance;
  in it, the number of open cells (at most 2) walking from the position in the facing before a wall.
  @param(x The starting column.)
  @param(y The starting row.)
  @param(facing The direction, 0, 2, 4 or 6.)
  @returns(The distance in cells, 0..2.) }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Records a portrait's head and body, loads them and shows them at cell (3, 3).
  @param(headId The head picture.)
  @param(bodyId The body picture.) }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Shows an encounter's monster. Until its close-up is shown, it turns off the automap and loads the sprite animation in
  the 3D view the first time (redrawing the map view on later calls), and draws the sprite at distance dist + 1 in the
  3D interface. At distance 0 in the 3D interface (unless the encounter menu is open with monster pictures off) it shows
  the close-up: picture picId when the zone's picture word is 255, else a portrait with that word as the head and picId
  as the body, skipping one already shown.
  @param(sprId The sprite animation.)
  @param(picId The close-up picture, or the portrait's body.)
  @param(dist The monster's distance, 0 when it is next to the party.)
  @param(flags The encounter's monster flags: [0] marks the sprite loaded and [1] the close-up shown.) }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Joins two bytes into a word.
  @param(lower The low byte.)
  @param(upper The high byte.)
  @returns(The high byte times 256 plus the low byte.) }
function CombineBytesToWord(lower, upper: Byte): Word;

{ Turns a 6-bit game character into ASCII: codes below 32 gain 64, and higher codes stay as they are.
  @param(c The game character.)
  @returns(The ASCII character.) }
function DecodeGameCharacter(c: Byte): Char;

{ Finds the GBVM bank holding an address.
  @param(vmAddr The GBVM address.)
  @returns(0 for $4B00..$4EFF, 1 for $7C00..$7FFF, 2 for $7A00..$7BFF, 3 (the script) for $8000..$9DFF, and 4 for
    anything else.) }
function GbvmZone(vmAddr: Word): Byte;

{ Finds a creature's place in the creature list.
  @param(cr The creature.)
  @returns(Its place from 0; the list's length when it is not there.) }
function FindCurCharIdx(cr: Types.PCharRecord): Byte;

{ Reads the zone-1 addresses that map onto the current character: Intelligence, Constitution, Charisma, race, class,
  maximum hit points, the petrification save, highest level, thief skills, NPC byte, coins, the magic-user, cleric,
  thief, fighter, paladin and ranger levels (each counting an earlier class once passed), gender, alignment, experience
  award, rolled hit points, status ($100: 1 okay up to 7 petrified, or 0 after a character-not-found), side and quick
  fight ($10C), hit points, movement, party position, a Charisma value (0..60), the current disk and zone-1 word $7F3E.
  Note: $10D, and a Charisma outside 3..25, leave the result undefined.
  @param(vmAddr The zone-1 address.)
  @param(found Set False for an ordinary zone-1 word, else True.)
  @returns(The value; undefined for an ordinary word.) }
function SpecialReadZ1(vmAddr: Word; var found: Boolean): Word;

{ Applies the side effects of a zone-1 write to the current character: a party record dump (0 written at the zone's
  base), memorized spells, NPC byte (values above $B2 lowered by 50), coins, experience award, rolled hit points, status
  (1 makes it okay and in play), side and quick fight, hit points, the current disk (PushState), and the three wall sets
  (values above $80, less bit 7).
  @param(vmAddr The zone-1 address.)
  @param(value The value written.) }
procedure SpecialWriteZ1(vmAddr, value: Word);

{ Writes a GBVM word. A zone-0 write to a sky color asks for a sky redraw, and one that changes the 3D flag switches to
  the 3D interface state, remembering the previous one; zone-1 writes go on to SpecialWriteZ1. Outside the zones, the
  addresses that do anything are the sound effect, two script registers, and from $BF68 up the party's map position and
  facing (marking the party moved) and the wall and ceiling-floor color selectors.
  @param(vmAddr The GBVM address.)
  @param(value The value written.) }
procedure WriteGbvm(vmAddr, value: Word);

{ Reads a GBVM word: zone 1 through SpecialReadZ1 first, and the zone-0 facing word gives the party's facing. Outside
  the zones it serves three script registers, the facing, and from $C04B the party's map position, facing (0..3 in 3D),
  wall ahead and cell event.
  @param(vmAddr The GBVM address.)
  @returns(The word; undefined for any other address outside the zones.) }
function ReadGbvm(vmAddr: Word): Word;

{ Writes a string, zero-terminated, at a GBVM address in any zone; the zone-1 base address sets the current character's
  name instead. Addresses outside the zones are ignored.
  @param(vmAddr The GBVM address.)
  @param(s The string.) }
procedure WriteGbvmString(vmAddr: Word; s: String);

{ Decodes packed 6-bit game characters at the script's instruction pointer into a script string, four characters to
  three bytes; zero characters are dropped. The instruction pointer ends on the last byte read.
  @param(len The number of packed bytes.)
  @param(strIdx The script string to fill.) }
procedure ConvGbString(len, strIdx: Byte);

{ Copies the zero-terminated string at a GBVM address into a script string. The zone-1 base address gives the current
  character's name; addresses outside the zones give an empty string.
  @param(strIdx The script string filled.)
  @param(vmAddr The GBVM address.) }
procedure DerefGbString(strIdx: Byte; vmAddr: Word);

{ Runs a horizontal menu with ~ hotkeys; extended keys select the previous or next character.
  @param(query The prompt.)
  @param(menu The menu, with ~ before each hotkey.)
  @param(qCol The prompt's color.)
  @param(mCol The menu's color.)
  @param(hlCol The hotkeys' color.)
  @param(enterOk True to accept Enter.)
  @param(animate True to animate the menu picture while waiting.)
  @returns(The hotkey's place from 0; 0 for Enter; 255 for a letter or digit that is not a hotkey.) }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk,
                                       animate: Boolean): Byte;

{ Runs MenuCore.MenuVertical over a list with the command menu Select; the key it returns is discarded. The menu string
  is prepared for hotkeys but not shown.
  @param(query The prompt.)
  @param(menu The script's menu string, with '~' before each hotkey.)
  @param(qCol The labels' and prompt's color.)
  @param(mCol The choices' color.)
  @param(hlCol The highlight color.)
  @param(ulCol The window's left column.)
  @param(ulRow The window's top row.)
  @param(lrCol The window's right column.)
  @param(lrRow The window's bottom row.)
  @param(list The members listed.)
  @param(addExit True to offer Exit.)
  @param(redraw True to redraw the window first; cleared on return unless the list is nil.)
  @param(idx The highlighted member, kept between calls.)
  @param(sel Receives the chosen member, or nil.) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: Byte;
                          list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                          var sel: Types.PItemRec);

{ Sets the six comparison flags from two strings: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareStr(leftOperand, rightOperand: String);

{ Sets the six comparison flags from two numbers: equal, not equal, less, greater, less or equal, greater or equal.
  @param(leftOperand The left side.)
  @param(rightOperand The right side.) }
procedure EclCompareInt(leftOperand, rightOperand: Word);

{ Pushes the instruction pointer on the script return stack and jumps to the address in a loaded argument.
  @param(varIdx The argument holding the address.) }
procedure EclGosub(varIdx: Byte);

{ Moves the party one cell the way it faces, wrapping on the 16x16 map, refreshes the cell event and the wall ahead, and
  marks the party moved. }
procedure EclMoveForward;

{ Scales each of a creature's seven money types by a fraction, truncating.
  @param(fraction The fraction kept.)
  @param(cr The creature.) }
procedure RobMoney(fraction: Real; cr: Types.PCharRecord);

{ Takes each of a character's items with a chance in percent, unreadying it first. An item heavier than 255 lowers the
  chance by 90 and one heavier than 24 by 50, to no less than 0. Note: the lowered chance carries over to the items
  after it.
  @param(chance The chance in percent.)
  @param(cr The character robbed.) }
procedure RobItems(chance: Byte; cr: Types.PCharRecord);

{ Skips the current script command, decoding as many arguments as its opcode takes. Note: VERTICAL MENU, HORIZONTAL
  MENU, ON GOTO and ON GOSUB are skipped as if they had no arguments, so the bytes of their arguments are read as the
  next commands. }
procedure SkipEclCmd;

{ Finds the party's highest and lowest movement, doubled for haste or halved for slow. Note: both start from the first
  member's unadjusted movement.
  @param(maxMove Receives the highest movement.)
  @param(minMove Receives the lowest movement.) }
procedure MoveExtremes(var maxMove, minMove: Byte);

{ Damages a character (not a dead or petrified one) for a script: reports that it dies when the damage exceeds its hit
  points by more than 10, or how much it was hit for, pausing when the text window is full, then applies the damage and
  redraws the party.
  @param(dmg The damage.)
  @param(cr The character.) }
procedure EclInflictDamage(dmg: Word; cr: Types.PCharRecord);

{ Prepares a script menu string: lowercases it, removes each '~' and uppercases the letter after it as a hotkey. Note:
  the lowercasing adds $20 to digits too, turning them into letters P..Y.
  @param(menu The menu string, prepared in place.)
  @param(opts Receives the hotkeys in order.) }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40);

implementation

procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
begin
  strIdx := 0;
  for i := 1 to count do begin
    GDVars.varTypes[i] := GDVars.zone3^[GDVars.eclIp + 1];
    GDVars.varLo[i] := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case GDVars.varTypes[i] of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        GDVars.varHi[i] := GDVars.zone3^[GDVars.eclIp];
      end;
      $80: begin
        Inc(strIdx);
        len := GDVars.varLo[i];
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings[strIdx] := '';
      end;
      $81: begin
        Inc(strIdx);
        Inc(GDVars.eclIp);
        GDVars.varHi[i] := GDVars.zone3^[GDVars.eclIp];
        v := EclMenu.CombineBytesToWord(GDVars.varLo[i], GDVars.varHi[i]);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  address: Word;
  { Unused in this version; see the other implementations of this routine. }
  value: Word;
  { Unused in this version; see the other implementations of this routine. }
  kind: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.varLo[idx];
  vLo := GDVars.varHi[idx];
  case GDVars.varTypes[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

procedure EclInit;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptId: Byte;
  i: Word;
begin
  GDVars.eclGraphics := False;
  GDVars.eclProtection := 0;
  GDVars.dumpMonsterRecords := False;
  GDVars.dumpPartyRecords := False;
  GDVars.wallColorSel := $41;
  GDVars.ceilFloorColorSel := 9;
  GDVars.picRegionW := True;
  GameIo.FillWord(GDVars.monFlags, SizeOf(GDVars.monFlags));
  GDVars.iconAnimIdx := 8;
  GDVars.eclIp := $8000;
  GDVars.castConfirmed := False;
  GDVars.eclStack := nil;
  GDVars.eclStackPrv := nil;
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  GDVars.zone1^.cell[$7EE1] := 255;
  GDVars.zone1^.cell[$7ED2] := 0;
  GDVars.zone1^.cell[$7ED3] := 0;
  GDVars.zone0^.cell[$4BE5] := 0;
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[1] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[2] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[3] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[4] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  EclMenu.LoadEclVars(1);
  GDVars.vmRun[5] := EclMenu.CombineBytesToWord(GDVars.varLo[1], GDVars.varHi[1]);
  if GDVars.loadedSave = 0 then begin
    for i := 1 to 32 do
      { GBVM $4C00..$4C1F }
      GDVars.zone0^.cell[i + $4BFF] := 0;
    for i := 0 to 9 do
      { GBVM $7F79..$7F82 }
      GDVars.zone1^.cell[i + $7F79] := 0;
  end;
end;

function LoadEclScript(scriptId: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  scriptSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  scriptOffset: Word;
  s: String[1];
  sizeRead: Word;
  data: Types.PByteArr;
  failed: Boolean;
begin
  failed := False;
  repeat
    MenuCore.ClearBottomLine;
    TextRend.DisplayString(0, 24, LightGreen, 0, 'Loading...Please Wait');
    Str(GDVars.diskNum, s);
    DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  until (sizeRead >= 2) or failed;
  GameIo.FillWord(GDVars.zone3^, SizeOf(GDVars.zone3^));
  Move(data^[2], GDVars.zone3^, sizeRead - 2);
  FreeMem(data, sizeRead);
  MenuCore.ClearBottomLine;
  LoadEclScript := True;
end;

procedure InitCreature(id: Byte; var cr: Types.PCharRecord; var inv: Types.PItemRec; var eff: Types.PEffectRec);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Pointer;
begin
  cr := nil;
  New(cr);
  SaveLoad.LoadCreatureData(id, cr);
  inv := cr^.itemsAddr;
  eff := cr^.effectsAddr;
end;

function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  { flag above the counter }
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GDVars.zone0^.cell[$4BE6] = 0 then begin
    MaxMonsterDist := 2;
    GDVars.zone1^.cell[$7EC1] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.picDrawn := 0;
  GDVars.portraitHeadId := headId;
  GDVars.portraitBodyId := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  { Unused in this version; see the other implementations of this routine. }
  headPic: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  bodyPic: Pointer;
  { = dist + 1, Show3DSprite's range }
  spriteDist: Byte;
begin
  spriteDist := dist + 1;
  if picId = 255 then
    flags[1] := False;
  if not flags[1] then begin
    if not flags[0] then begin
      if GDVars.automapOn then begin
        GDVars.automapOn := False;
        GDVars.viewDirty := 1;
        MapView.DisplayMapView;
      end;
      if GDVars.zone0^.cell[$4BE6] <> 0 then begin
        Portrait.LoadAnimation('SPRIT', sprId, 1, GDVars.animData);
        flags[0] := True;
        GDVars.sprShown := True;
      end;
    end else begin
      GDVars.viewDirty := 1;
      MapView.DisplayMapView;
    end;
    if GDVars.interfaceState = C_Ifc.INDOORS then
      Portrait.Show3DSprite(spriteDist, GDVars.animData);
  end;
  if flags[1] then
    if GDVars.picIdShown = GDVars.zone1^.cell[$7EE1] then
      Exit;
  if dist <> 0 then Exit;
  if GDVars.interfaceState <> C_Ifc.INDOORS then Exit;
  if picId = 255 then Exit;
  if (GDVars.inEncMenu <> 0) and (GDVars.monsterPics = 0) then Exit;
  GDVars.picIdShown := Byte(GDVars.zone1^.cell[$7EE1]);
  GDVars.eclGraphics := True;
  if GDVars.zone1^.cell[$7EE1] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^.cell[$7EE1]), picId);
    flags[1] := True;
    GDVars.picDrawn := 0;
  end;
end;

function CombineBytesToWord(lower, upper: Byte): Word;
begin
  CombineBytesToWord := upper * 256 + lower;
end;

function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

function GbvmZone(vmAddr: Word): Byte;
begin
  GbvmZone := 4;
  if (vmAddr >= $4B00) and (vmAddr <= $4EFF) then GbvmZone := 0;
  if (vmAddr >= $7C00) and (vmAddr <= $7FFF) then GbvmZone := 1;
  if (vmAddr >= $7A00) and (vmAddr <= $7BFF) then GbvmZone := 2;
  if (vmAddr >= $8000) and (vmAddr <= $9DFF) then GbvmZone := 3;
end;

function FindCurCharIdx(cr: Types.PCharRecord): Byte;
var
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
begin
  p := GDVars.creatureList;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = cr then
      found := True
    else begin
      Inc(idx);
      p := p^.nextCharAddr;
    end;
  end;
  FindCurCharIdx := idx;
end;

function SpecialReadZ1(vmAddr: Word; var found: Boolean): Word;
var
  { Unused in this version; see the other implementations of this routine. }
  fieldIndex: Byte;
  t: Byte;
begin
  found := True;
  vmAddr := vmAddr - $7C00;
  case vmAddr of
    $15: SpecialReadZ1 := GDVars.curChar^.intCurV1;
    $18: SpecialReadZ1 := GDVars.curChar^.conCur;
    $19: SpecialReadZ1 := GDVars.curChar^.chaCur;
    $72: SpecialReadZ1 := GDVars.curChar^.race;
    $73: SpecialReadZ1 := GDVars.curChar^.charClassV1;
    $76: SpecialReadZ1 := GDVars.curChar^.hpMaxV1;
    $9B: SpecialReadZ1 := GDVars.curChar^.petrificationSave;
    $A0: SpecialReadZ1 := GDVars.curChar^.highestLevel;
    $A5..$AC: begin
      t := vmAddr - $A4;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[t];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.COPPER];
    $BD: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.SILVER];
    $BF: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.ELECTRUM];
    $C1: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.GOLD];
    $C3: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.PLATINUM];
    $C5: SpecialReadZ1 := GDVars.curChar^.coinsA[C_Money.GEMS];
    $C9: SpecialReadZ1 := GDVars.curChar^.mageLevel +
      GDVars.curChar^.mageOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $CA: SpecialReadZ1 := GDVars.curChar^.clericLevel +
      GDVars.curChar^.clericOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $CB: SpecialReadZ1 := GDVars.curChar^.thiefLevel +
      GDVars.curChar^.thiefOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $CC: SpecialReadZ1 := GDVars.curChar^.fighterLevel +
      GDVars.curChar^.fighterOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $CF: SpecialReadZ1 := GDVars.curChar^.paladinLevel +
      GDVars.curChar^.paladinOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $D0: SpecialReadZ1 := GDVars.curChar^.rangerLevel +
      GDVars.curChar^.rangerOldLevel * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    $D6: SpecialReadZ1 := GDVars.curChar^.genderV1;
    $D8: SpecialReadZ1 := GDVars.curChar^.alignment;
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.pcHpRolled;
    $100:
      if GDVars.charNotFound <> 0 then
        SpecialReadZ1 := 0
      else
        case GDVars.curChar^.status of
          C_Status.OKAY: SpecialReadZ1 := 1;
          C_Status.RUNNING: SpecialReadZ1 := 6;
          C_Status.UNCONSCIOUS: SpecialReadZ1 := 5;
          C_Status.DYING: SpecialReadZ1 := 4;
          C_Status.DEAD_STATUS: SpecialReadZ1 := 3;
          C_Status.PETRIFIED: SpecialReadZ1 := 7;
          C_Status.GONE: SpecialReadZ1 := 2;
        else
          SpecialReadZ1 := 0;
        end;
    $10C:
      if (GDVars.curChar^.hostileV1 = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostileV1 = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { empty: result undefined }
    $10D: ;
    $119: SpecialReadZ1 := GDVars.curChar^.hpCurrent;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2CF:
      case GDVars.curChar^.chaCur of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.diskNum;
    $33E: SpecialReadZ1 := GDVars.zone1^.cell[$7F3E];
  else
    found := False;
  end;
end;

procedure SpecialWriteZ1(vmAddr, value: Word);
var
  t: Byte;
begin
  vmAddr := vmAddr - $7C00;
  case vmAddr of
    0:
      if value = 0 then GDVars.dumpPartyRecords := True;
    $1B..$65: begin
      t := vmAddr - $1B;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    $B8: begin
      if value > $B2 then Dec(value, $32);
      GDVars.curChar^.npc := value;
    end;
    $BB: GDVars.curChar^.coinsA[C_Money.COPPER] := value;
    $BD: GDVars.curChar^.coinsA[C_Money.SILVER] := value;
    $BF: GDVars.curChar^.coinsA[C_Money.ELECTRUM] := value;
    $C1: GDVars.curChar^.coinsA[C_Money.GOLD] := value;
    $C3: GDVars.curChar^.coinsA[C_Money.PLATINUM] := value;
    $C5: GDVars.curChar^.coinsA[C_Money.GEMS] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.pcHpRolled := value;
    $100:
      case value of
        1: begin
          GDVars.curChar^.status := C_Status.OKAY;
          GDVars.curChar^.enabled := 1;
        end;
      end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostileV1 := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostileV1 := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostileV1 := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    $119: GDVars.curChar^.hpCurrent := value;
    $312: DaxIo.PushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
end;

procedure WriteGbvm(vmAddr, value: Word);
var
  zone: Byte;
  ok: Boolean;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  case zone of
    0: begin
      case vmAddr - $4B00 of
        $FD, $FE: GDVars.redrawSky := True;
        $E6:
          if GDVars.zone0^.cell[$4BE6] <> value then begin
            GDVars.savedInterface := GDVars.interfaceState;
            GDVars.interfaceState := C_Ifc.INDOORS;
          end;
      end;
      GDVars.zone0^.cell[vmAddr] := value;
    end;
    1: begin
      GDVars.zone1^.cell[vmAddr] := value;
      EclMenu.SpecialWriteZ1(vmAddr, value);
    end;
    2:
      GDVars.zone2^[vmAddr] := value;
    3:
      GDVars.zone3^[vmAddr] := value;
    4:
      if vmAddr < $BF68 then
        case vmAddr of
          $FB: ;
          $FC: ;
          $B1: ;
          $3DE: GDVars.sndEffect := value;
          $B8: GDVars.writeReg1 := value;
          $B9: GDVars.writeReg2 := value;
        end else begin
        vmAddr := vmAddr - $BF68;
        case vmAddr of
          $E3: begin
            GDVars.movedParty := True;
            GDVars.partyPos.mapX := value;
          end;
          $E4: begin
            GDVars.partyPos.mapY := value;
            GDVars.movedParty := True;
          end;
          $E5: begin
            repeat
              ok := True;
              { the ECL carries a quarter code 0..3; facing is the compass axis, so the two encodings differ by a factor
                of two }
              case value of
                0: GDVars.partyPos.facing := C_Dir.NORTH;
                1: GDVars.partyPos.facing := C_Dir.EAST;
                2: GDVars.partyPos.facing := C_Dir.SOUTH;
                3: GDVars.partyPos.facing := C_Dir.WEST;
              else begin
                ok := False;
                Dec(value, 4);
              end;
              end;
            until ok = True;
            GDVars.movedParty := True;
          end;
          $F1: begin
            GDVars.wallColorSel := value;
            GDVars.picRegionW := True;
          end;
          $F7: begin
            GDVars.ceilFloorColorSel := value;
            GDVars.picRegionW := True;
          end;
          $10BA: ;
        end;
      end;
  end;
end;

function ReadGbvm(vmAddr: Word): Word;
var
  zone: Byte;
  found: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  offset: Word;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  found := False;
  case zone of
    0:
      if vmAddr = $4BEA then
        ReadGbvm := GDVars.partyPos.facing
      else
        ReadGbvm := GDVars.zone0^.cell[vmAddr];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(vmAddr, found);
      if not found then
        ReadGbvm := GDVars.zone1^.cell[vmAddr];
    end;
    2:
      ReadGbvm := GDVars.zone2^[vmAddr];
    3:
      ReadGbvm := GDVars.zone3^[vmAddr];
    4:
      if vmAddr < $C04B then
        case vmAddr of
          $B1: ReadGbvm := GDVars.readReg3;
          $FB: ReadGbvm := GDVars.readReg1;
          $FC: ReadGbvm := GDVars.readReg2;
          $33D: ReadGbvm := GDVars.partyPos.facing;
          $35F: ;
        end else begin
        vmAddr := vmAddr - $C04B;
        case vmAddr of
          0: ReadGbvm := GDVars.partyPos.mapX;
          1: ReadGbvm := GDVars.partyPos.mapY;
          2:
            if GDVars.zone0^.cell[$4BE6] = 0 then
              ReadGbvm := GDVars.partyPos.facing
            else
              ReadGbvm := Word(GDVars.partyPos.facing) div 2;
          3: ReadGbvm := GDVars.partyPos.wallAhead;
          4: ReadGbvm := GDVars.partyPos.eventAtCell;
          $E: ;
        end;
      end;
  end;
end;

procedure WriteGbvmString(vmAddr: Word; s: String);
var
  zone: Byte;
  len: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  len := Length(s);
  case zone of
    0: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone0^.cell[i + vmAddr] := Ord(s[i + 1]);
      GDVars.zone0^.cell[len + vmAddr] := 0;
    end;
    1:
      if vmAddr = $7C00 then
        GDVars.curChar^.name := s
      else begin
        if len > 0 then
          for i := 0 to len - 1 do
            GDVars.zone1^.cell[i + vmAddr] := Ord(s[i + 1]);
        GDVars.zone1^.cell[len + vmAddr] := 0;
      end;
    2: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone2^[i + vmAddr] := Ord(s[i + 1]);
      GDVars.zone2^[len + vmAddr] := 0;
    end;
    3: begin
      if len > 0 then
        for i := 0 to len - 1 do
          GDVars.zone3^[i + vmAddr] := Ord(s[i + 1]);
      GDVars.zone3^[len + vmAddr] := 0;
    end;
  end;
end;

procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  outPos: Byte;
  cur: Byte;
  prev: Byte;
  charCode: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.zone3^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        charCode := cur shr 2;
      2: begin
        charCode := prev shl 6 + cur shr 2;
        charCode := charCode shr 2;
      end;
      3: begin
        charCode := prev shl 4 + cur shr 4;
        charCode := charCode shr 2;
      end;
      4:
        charCode := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if charCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(charCode);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    charCode := cur and $3F;
    if charCode <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(charCode);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
end;

procedure DerefGbString(strIdx: Byte; vmAddr: Word);
var
  zone: Byte;
  i: Byte;
begin
  zone := EclMenu.GbvmZone(vmAddr);
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  case zone of
    0:
      while GDVars.zone0^.cell[i + vmAddr] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone0^.cell[i + vmAddr]));
        Inc(i);
      end;
    1:
      if vmAddr = $7C00 then
        GDVars.gbStrings[strIdx] := GDVars.curChar^.name
      else
        while GDVars.zone1^.cell[i + vmAddr] <> 0 do begin
          GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone1^.cell[i + vmAddr]));
          Inc(i);
        end;
    2:
      while GDVars.zone2^[i + vmAddr] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone2^[i + vmAddr]));
        Inc(i);
      end;
    3:
      while GDVars.zone3^[i + vmAddr] <> 0 do begin
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(GDVars.zone3^[i + vmAddr]));
        Inc(i);
      end;
  end;
end;

procedure MenuToOptions(var menu: String; var opts: Types.TStr40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk,
                                       animate: Boolean): Byte;
var
  opts: Types.TStr40;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  EclMenu.MenuToOptions(menu, opts);
  repeat
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, 1, Ord(animate), ext);
    if ext then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar, True);
      ch := C_Keys.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_Keys.ENTER) and enterOk);
  case ch of
    C_Keys.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: Byte;
                          list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer; var sel:
                              Types.PItemRec);
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  opts: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, 'Select', qCol, mCol, hlCol, ulCol, ulRow, lrCol, lrRow, list, Ord(addExit),
                              redraw, idx, sel);
end;

procedure EclCompareStr(leftOperand, rightOperand: String);
begin
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  if leftOperand = rightOperand then GDVars.compareFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.compareFlags[1] := True;
  if leftOperand < rightOperand then GDVars.compareFlags[2] := True;
  if leftOperand > rightOperand then GDVars.compareFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.compareFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.compareFlags[5] := True;
end;

procedure EclCompareInt(leftOperand, rightOperand: Word);
begin
  GameIo.FillWord(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  if leftOperand = rightOperand then GDVars.compareFlags[0] := True;
  if leftOperand <> rightOperand then GDVars.compareFlags[1] := True;
  if leftOperand < rightOperand then GDVars.compareFlags[2] := True;
  if leftOperand > rightOperand then GDVars.compareFlags[3] := True;
  if leftOperand <= rightOperand then GDVars.compareFlags[4] := True;
  if leftOperand >= rightOperand then GDVars.compareFlags[5] := True;
end;

procedure EclGosub(varIdx: Byte);
begin
  if GDVars.eclStack = nil then begin
    New(GDVars.eclStack);
    GDVars.eclStack^.next := nil;
  end else begin
    GDVars.eclStackPrv := GDVars.eclStack;
    New(GDVars.eclStack);
    GDVars.eclStack^.next := GDVars.eclStackPrv;
  end;
  GDVars.eclStack^.addr := GDVars.eclIp;
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.varLo[varIdx], GDVars.varHi[varIdx]);
end;

procedure EclMoveForward;
begin
  case GDVars.partyPos.facing of
    C_Dir.NORTH: if GDVars.partyPos.mapY > 0 then Dec(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 15;
    C_Dir.EAST: if GDVars.partyPos.mapX < 15 then Inc(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 0;
    C_Dir.SOUTH: if GDVars.partyPos.mapY < 15 then Inc(GDVars.partyPos.mapY) else GDVars.partyPos.mapY := 0;
    C_Dir.WEST: if GDVars.partyPos.mapX > 0 then Dec(GDVars.partyPos.mapX) else GDVars.partyPos.mapX := 15;
  end;
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.mapX, GDVars.partyPos.mapY);
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.mapX, GDVars.partyPos.mapY, GDVars.partyPos.facing);
  GDVars.movedParty := True;
end;

procedure RobMoney(fraction: Real; cr: Types.PCharRecord);
begin
  cr^.coinsA[C_Money.COPPER] := Trunc(cr^.coinsA[C_Money.COPPER] * fraction);
  cr^.coinsA[C_Money.SILVER] := Trunc(cr^.coinsA[C_Money.SILVER] * fraction);
  cr^.coinsA[C_Money.ELECTRUM] := Trunc(cr^.coinsA[C_Money.ELECTRUM] * fraction);
  cr^.coinsA[C_Money.PLATINUM] := Trunc(cr^.coinsA[C_Money.PLATINUM] * fraction);
  cr^.coinsA[C_Money.GOLD] := Trunc(cr^.coinsA[C_Money.GOLD] * fraction);
  cr^.coinsA[C_Money.GEMS] := Trunc(cr^.coinsA[C_Money.GEMS] * fraction);
  cr^.coinsA[C_Money.JEWELRY] := Trunc(cr^.coinsA[C_Money.JEWELRY] * fraction);
end;

procedure RobItems(chance: Byte; cr: Types.PCharRecord);
var
  roll: Byte;
  it: Types.PItemRec;
  nxt: Types.PItemRec;
begin
  it := cr^.itemsAddr;
  while it <> nil do begin
    if it^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if it^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    nxt := it^.next;
    if roll <= chance then begin
      if it^.equipped <> 0 then
        ViewChar.ToggleReadyItem(it);
      CharHlp.RemoveItem(cr, it);
    end;
    it := nxt;
  end;
end;

procedure SkipEclCmd;
begin
  GDVars.curOp := GDVars.zone3^[GDVars.eclIp];
  case GDVars.curOp of
    1, 2, $A, $E, $11, $12, $1D, $20, $2D, $32, $34, $36, $38, $39,
    $3C, $3F, $40:
      EclMenu.LoadEclVars(1);
    3, 8, 9, $F, $10, $1F, $22, $41:
      EclMenu.LoadEclVars(2);
    4..7, $B, $C, $21, $28, $2A, $2F, $30, $35, $37, $3B:
      EclMenu.LoadEclVars(3);
    $14, $23:
      EclMenu.LoadEclVars(4);
    $2E:
      EclMenu.LoadEclVars(5);
    $1E, $2C:
      EclMenu.LoadEclVars(6);
    $27:
      EclMenu.LoadEclVars(8);
    $29:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

procedure MoveExtremes(var maxMove, minMove: Byte);
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  m: Byte;
begin
  p := GDVars.creatureList;
  maxMove := p^.movementCur;
  minMove := p^.movementCur;
  while p <> nil do begin
    m := CharHlp.RecalcMovement(p) div 2;
    if m > maxMove then maxMove := m;
    if m < minMove then minMove := m;
    p := p^.nextCharAddr;
  end;
end;

procedure EclInflictDamage(dmg: Word; cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  damageType: Byte;
  msg: String;
  dmgStr: String[3];
  pause: Boolean;
begin
  if cr^.status = C_Status.DEAD_STATUS then Exit;
  if cr^.status = C_Status.PETRIFIED then Exit;
  pause := False;
  Str(dmg, dmgStr);
  if cr^.hpCurrent + 10 < dmg then
    msg := '  ' + cr^.name + ' dies. '
  else
    msg := '  ' + cr^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
  if GDVars.curRow > 22 then begin
    GDVars.curRow := 17;
    pause := True;
    TextRend.DisplayAndPause(White, 0, GDConsts.continuePrompt);
  end else
    pause := False;
  GDVars.curCol := 38;
  TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, pause, msg);
  CharHlp.InflictDamage(cr, dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharHlp.DisplayRoster(GDVars.curChar);
end;

begin
end.
