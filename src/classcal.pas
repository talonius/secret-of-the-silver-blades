{ Dual-class character updates: recalculate class levels, spell slots and lists, THAC0 base, saving throws, thief
  skills, and class-change state for a TCharRecord. }
{$O+,F+,I-,R-,S-}
unit ClassCal;

interface

uses Types, MenuCore, TextRend, GameIo, Crt, GDConsts, GDVars, C_Race, C_Keys, C_Class, C_Stat,
  C_Spell, C_Save;

{ Recomputes a character's level-derived values. The THAC0 base (baseToHit) becomes the best of its classes at their
  levels and highestLevel rises to its highest class level; a fighter or paladin above level 6 gets 3 half-attacks and
  above 12 gets 4, a ranger above 7 and above 14 likewise. It then rebuilds the spell slots (RecalcSpellLists), the
  saving throws (RecalcSaves) and, with thief levels, the thief skills (RecalcThiefSkills). The class mask (classMask)
  collects the item masks of the classes it has levels in, plus each earlier class whose level is below highestLevel; an
  equipped, uncursed item in an equipment slot that no class in the mask may use is unreadied. Once a dual-class
  character has passed its earlier class (EarlierClassActive), the earlier class levels also count for THAC0 and
  attacks, and earlier thief levels rebuild the thief skills.
  @param(cr The character to update.) }
procedure RecalcClassStats(cr: Types.PCharRecord);

{ Rebuilds a character's cleric slots when it has cleric levels (its earlier cleric levels counting once
  EarlierClassActive allows): one first-level slot plus the cleric progression for each level above 1, then the Wisdom
  bonus. Wisdom above 12 and above 13 each add a first-level slot, above 14 and above 15 each a second-level slot, above
  16 a third-level slot and above 17 a fourth-level slot, each only to a spell level that already has slots; Wisdom
  below 17 removes the sixth-level slots and below 18 the seventh-level ones.
  @param(cr The character to update.) }
procedure RecalcSpellSlots(cr: Types.PCharRecord);

{ Limits a character's magic-user slots by Intelligence: below 12 it has no sixth-level slots, below 14 no seventh-level
  ones.
  @param(cr The character to update.) }
procedure RecalcClericSlots(cr: Types.PCharRecord);

{ Recomputes a character's five saving throws (saves). Each starts at 20 and takes the lowest table value of its classes
  at their levels. The paralyzation save then adds 1 to 5, rising with Constitution from 4 to 18, for a character with
  an equipped item with special $86, and 1 to 4 for Constitution 19 to 25 for anyone. Note: the earlier-class check
  reuses j after its loop has ended, so it looks only at the thief class, and only when the current thief level is above
  the earlier one.
  @param(cr The character to update.) }
procedure RecalcSaves(cr: Types.PCharRecord);

{ Recomputes a character's eight thief skills (thiefSkills) from the thief skill table at its thief level, counting its
  earlier thief levels once it has passed them (EarlierClassActive). Each skill takes the race adjustment, falling to 0
  when a race penalty exceeds it, and skills 1 to 5 also take the Dexterity adjustment.
  @param(cr The character to update.) }
procedure RecalcThiefSkills(cr: Types.PCharRecord);

{ Lets a human who has not changed class before change class (dual-class). Lists the classes its race allows that it
  qualifies for, or reports that it does not qualify. On a pick it resets the experience and attacks, keeps the old
  class's level as the earlier level, records highestLevel as the level at the change (dualClassThreshold), starts the
  new class at level 1 with fresh spell slots (a magic-user also learns four spells), clears memorized spells,
  recomputes its class-derived values and unreadies uncursed items the new class mask does not allow. Note: Escape
  returns without freeing the class list.
  @param(cr The character changing class.)
  @returns(The new class, or 17 when the class was not changed.) }
function ChangeClass(cr: Types.PCharRecord): Byte;

{ Tells whether a character is human, the one race that may change class.
  @param(cr The character to check.)
  @returns(True for a human.) }
function IsHuman(cr: Types.PCharRecord): Boolean;

{ Finds the first class in which a human has an earlier (pre-change) level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstEarlierClass(cr: Types.PCharRecord): ShortInt;

{ Finds the first class in which a human has a current level.
  @param(cr The character to check.)
  @returns(That class; 17 for a non-human or when there is none.) }
function FirstCurrentClass(cr: Types.PCharRecord): ShortInt;

{ Finds a human's current level in its first class with a level.
  @param(cr The character to check.)
  @returns(That level; 0 for a non-human or a human with no level.) }
function CurrentDualClassLevel(cr: Types.PCharRecord): ShortInt;

{ Tells whether a human's current class level exceeds the level it had when it changed class, which lets its earlier
  class's abilities count again.
  @param(cr The character to check.)
  @returns(True when the earlier class counts again.) }
function EarlierClassActive(cr: Types.PCharRecord): Boolean;

{ Rebuilds a character's spell slots and known spells from its class levels, using an earlier class's level once it
  counts again (EarlierClassActive). A cleric gets its slots from RecalcSpellSlots; a paladin above level 8 adds its
  cleric slots for levels 9 up; a ranger above level 7 adds druid slots (spell levels 1 to 3) and magic-user slots
  (spell levels 1 and 2) for levels 8 up; each of them then knows every spell of those lists with slots at its level. A
  magic-user gets one first-level slot plus the progression for each level above 1, limited by Intelligence
  (RecalcClericSlots). Each readied item with special $81 doubles the fifth-level magic-user slots.
  @param(cr The character to update.) }
procedure RecalcSpellLists(cr: Types.PCharRecord);

implementation

const
  { The eight skill columns of thiefBase and raceAdj; dexAdj carries the first five. thiefBase's level-1 row reads
    30/25/20/15/10/10/85/0, the AD&D thief table, and its level-4 row is the first with a non-zero last column -- the
    level at which Read Languages opens. }
  THIEF_PICK_POCKETS = 1;
  THIEF_HEAR_NOISE = 6;
  THIEF_READ_LANGUAGES = 8;

procedure RecalcSpellLists(cr: Types.PCharRecord);
var
  i: ShortInt;
  lvl: ShortInt;
  n: ShortInt;
  { spellSlots row 3 level for the ranger's magic-user columns 4..5 }
  row3Level: ShortInt;
  q: ShortInt;
  m: Byte;
  itemNode: Types.PItemRec;
begin
  with cr^ do begin
    GameIo.FillWord(spellSlots, SizeOf(spellSlots));
    for i := C_Class.CLERIC to C_Class.THIEF do begin
      if ClassCal.EarlierClassActive(cr) and (classLevelB[i] <> 0) then
        lvl := classLevelB[i]
      else
        lvl := classLevelA[i];
      if lvl > 0 then begin
        case i of
          C_Class.CLERIC: begin
               ClassCal.RecalcSpellSlots(cr);
               for m := 1 to 117 do
                 with GDConsts.spellDefs[m] do
                   if (castClass = C_Spell.CLERIC_LIST) and
                       (spellSlots[C_Spell.CLERIC_LIST, level] > 0) then known[m] := 1;
             end;
          C_Class.PALADIN: if lvl > 8 then begin
               for n := 9 to lvl do
                 for q := 1 to 7 do
                   Inc(spellSlots[C_Spell.CLERIC_LIST, q], GDConsts.classProgression[C_Class.PALADIN].spellSlots[n, q]);
               for m := 1 to 117 do
                 with GDConsts.spellDefs[m] do
                   if (castClass = C_Spell.CLERIC_LIST) and
                       (spellSlots[C_Spell.CLERIC_LIST, level] > 0) then known[m] := 1;
             end;
          C_Class.RANGER: if lvl > 7 then begin
               for n := 8 to lvl do begin
                 for q := 1 to 3 do
                   Inc(spellSlots[C_Spell.DRUID_LIST, q], GDConsts.classProgression[C_Class.RANGER].spellSlots[n, q]);
                 for q := 4 to 5 do begin
                   row3Level := q - 3;
                   Inc(spellSlots[C_Spell.MAGE_LIST, row3Level],
                       GDConsts.classProgression[C_Class.RANGER].spellSlots[n, q]);
                 end;
               end;
               for m := 1 to 117 do
                 with GDConsts.spellDefs[m] do
                   if ((castClass = C_Spell.DRUID_LIST) and
                       (spellSlots[C_Spell.DRUID_LIST, level] > 0)) or
                       ((castClass = C_Spell.MAGE_LIST) and
                        (spellSlots[C_Spell.MAGE_LIST, level] > 0)) then
                     known[m] := 1;
             end;
          C_Class.MAGE: begin
               Inc(spellSlots[C_Spell.MAGE_LIST, 1]);
               { no explicit guard here -- the for-loop's own entry test covers it }
               for n := 2 to lvl do
                   for q := 1 to 7 do
                     Inc(spellSlots[C_Spell.MAGE_LIST, q], GDConsts.classProgression[C_Class.MAGE].spellSlots[n, q]);
               ClassCal.RecalcClericSlots(cr);
             end;
        end;
      end;
    end;
    { tail pass: a readied item with type-code exactly $81 doubles the mage's level-5 slots }
    itemNode := itemsAddr;
    while itemNode <> nil do begin
      if (itemNode^.itemSpecial = $81) and (itemNode^.equippedV1 <> 0) then
        Inc(cr^.spellSlots[C_Spell.MAGE_LIST, 5], cr^.spellSlots[C_Spell.MAGE_LIST, 5]);
      itemNode := itemNode^.next;
    end;
  end;
end;

procedure RecalcClassStats(cr: Types.PCharRecord);
var
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  lvl: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  k: ShortInt;
begin
  cr^.baseToHit := 0;
  for i := C_Class.CLERIC to C_Class.THIEF do begin
    lvl := cr^.classLevelA[i];
    if GDConsts.baseToHitTbl[i, lvl] > cr^.baseToHit then cr^.baseToHit := GDConsts.baseToHitTbl[i, lvl];
    if cr^.highestLevel < lvl then cr^.highestLevel := lvl;
    case i of
      C_Class.PALADIN, C_Class.FIGHTER: begin
              if lvl > 6 then cr^.attacks := 3;
              if lvl > 12 then cr^.attacks := 4;
            end;
      C_Class.RANGER: begin
              if lvl > 7 then cr^.attacks := 3;
              if lvl > 14 then cr^.attacks := 4;
            end;
    end;
  end;
  ClassCal.RecalcSpellLists(cr);
  ClassCal.RecalcSaves(cr);
  if cr^.classLevelA[C_Class.THIEF] > 0 then ClassCal.RecalcThiefSkills(cr);
  cr^.classMask := 0;
  for i := C_Class.CLERIC to C_Class.THIEF do
    if (cr^.classLevelA[i] > 0) or ((cr^.classLevelB[i] > 0) and (cr^.classLevelB[i] < cr^.highestLevel)) then
      Inc(cr^.classMask, GDConsts.classMaskTbl[i]);
  for k := 0 to 12 do
    if cr^.equipped[k] <> nil then
      if (GDVars.baseItems[cr^.equipped[k]^.itemTypeV1].classMask and cr^.classMask) = 0 then
        if cr^.equipped[k]^.cursedV1 = 0 then
          cr^.equipped[k]^.equippedV1 := 0;
  if ClassCal.EarlierClassActive(cr) then
    for i := C_Class.CLERIC to C_Class.THIEF do begin
      lvl := cr^.classLevelB[i];
      case i of
        C_Class.FIGHTER, C_Class.PALADIN: if lvl >= 13 then cr^.attacks := 4
              else if lvl >= 7 then cr^.attacks := 3;
        C_Class.RANGER: if lvl >= 15 then cr^.attacks := 4
              else if lvl >= 8 then cr^.attacks := 3;
        C_Class.THIEF: if lvl > 0 then ClassCal.RecalcThiefSkills(cr);
      end;
      if GDConsts.baseToHitTbl[i, lvl] > cr^.baseToHit then cr^.baseToHit := GDConsts.baseToHitTbl[i, lvl];
    end;
end;

procedure RecalcSpellSlots(cr: Types.PCharRecord);
var
  k: ShortInt;
  i: ShortInt;
  total: ShortInt;
begin
  total := cr^.classLevelA[C_Class.CLERIC] +
    cr^.classLevelB[C_Class.CLERIC] * Ord(ClassCal.EarlierClassActive(cr));
  if total <= 0 then Exit;
  with cr^ do begin
  for i := 2 to 7 do spellSlots[C_Spell.CLERIC_LIST, i] := 0;
  spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
  for k := 2 to total do
    for i := 1 to 7 do
      Inc(spellSlots[C_Spell.CLERIC_LIST, i], GDConsts.classProgression[C_Class.CLERIC].spellSlots[k, i]);
  { Wisdom bonus spells: 13/14 -> +1 first, 15/16 -> +1 second, 17 -> +1 third, 18 -> +1 fourth; below 17/18 the top two
    levels are cleared outright. }
  if stats[C_Stat.WISDOM].cur > 12 then if spellSlots[C_Spell.CLERIC_LIST, 1] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
  if stats[C_Stat.WISDOM].cur > 13 then if spellSlots[C_Spell.CLERIC_LIST, 1] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 1]);
  if stats[C_Stat.WISDOM].cur > 14 then if spellSlots[C_Spell.CLERIC_LIST, 2] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
  if stats[C_Stat.WISDOM].cur > 15 then if spellSlots[C_Spell.CLERIC_LIST, 2] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 2]);
  if stats[C_Stat.WISDOM].cur > 16 then if spellSlots[C_Spell.CLERIC_LIST, 3] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 3]);
  if stats[C_Stat.WISDOM].cur > 17 then if spellSlots[C_Spell.CLERIC_LIST, 4] >
      0 then Inc(spellSlots[C_Spell.CLERIC_LIST, 4]);
  if stats[C_Stat.WISDOM].cur < 17 then spellSlots[C_Spell.CLERIC_LIST, 6] := 0;
  if stats[C_Stat.WISDOM].cur < 18 then spellSlots[C_Spell.CLERIC_LIST, 7] := 0;
  end;
end;

procedure RecalcClericSlots(cr: Types.PCharRecord);
begin
  with cr^ do begin
    if stats[C_Stat.INTELLIGENCE].cur < 12 then spellSlots[C_Spell.MAGE_LIST, 6] := 0;
    if stats[C_Stat.INTELLIGENCE].cur < 14 then spellSlots[C_Spell.MAGE_LIST, 7] := 0;
  end;
end;

procedure RecalcSaves(cr: Types.PCharRecord);
var
  i: ShortInt;
  j: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  level: Byte;
  k: Byte;
  node: Types.PItemRec;
  found: Byte;
begin
  found := 0;
  node := cr^.itemsAddr;
  while (node <> nil) and (found = 0) do begin
    if (node^.itemSpecial > $80) and (node^.equippedV1 <> 0) then begin
      k := node^.itemSpecial and $7F;
      found := Ord(k = 6);
    end;
    node := node^.next;
  end;
  for i := 0 to 4 do begin
    cr^.saves[i] := 20;
    for j := C_Class.CLERIC to C_Class.THIEF do
      if cr^.classLevelA[j] > 0 then
        if cr^.saves[i] > GDConsts.saveTbl[j, cr^.classLevelA[j], i] then
          cr^.saves[i] := GDConsts.saveTbl[j, cr^.classLevelA[j], i];
    { outside the j loop: this reuses j's final value }
    if cr^.classLevelA[j] > cr^.classLevelB[j] then
      if cr^.saves[i] > GDConsts.saveTbl[j, cr^.classLevelB[j], i] then
        cr^.saves[i] := GDConsts.saveTbl[j, cr^.classLevelB[j], i];
    if (i = C_Save.PARALYZATION) and (found <> 0) then
      case cr^.stats[C_Stat.CONSTITUTION].cur of
        4..6: Inc(cr^.saves[i]);
        7..10: Inc(cr^.saves[i], 2);
        11..13: Inc(cr^.saves[i], 3);
        14..17: Inc(cr^.saves[i], 4);
        18: Inc(cr^.saves[i], 5);
      end;
    if i = C_Save.PARALYZATION then
      case cr^.stats[C_Stat.CONSTITUTION].cur of
        19, 20: Inc(cr^.saves[i]);
        21, 22: Inc(cr^.saves[i], 2);
        23, 24: Inc(cr^.saves[i], 3);
        25: Inc(cr^.saves[i], 4);
      end;
  end;
end;

procedure RecalcThiefSkills(cr: Types.PCharRecord);
var
  i: Byte;
  x: Byte;
  { Unused in this version; see the other implementations of this routine. }
  effectCode: Byte;
  lvl2: ShortInt;
  saved: Byte;
  { Unused in this version; see the other implementations of this routine. }
  item: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  skillFloorItem: Byte;
  { Unused in this version; see the other implementations of this routine. }
  skillBonusItem: Byte;
begin
  with cr^ do begin
    x := 0;
    item := itemsAddr;
    lvl2 := cr^.classLevelA[C_Class.THIEF] +
      cr^.classLevelB[C_Class.THIEF] * Ord(ClassCal.EarlierClassActive(cr));
    saved := lvl2;
    for i := ClassCal.THIEF_PICK_POCKETS to ClassCal.THIEF_READ_LANGUAGES do begin
      if (GDConsts.raceAdj[race, i] < 0) and (GDConsts.thiefBase[lvl2, i] < Abs(GDConsts.raceAdj[race, i]) + x) then
        thiefSkills[i] := 0
      else begin
        thiefSkills[i] := x + (GDConsts.thiefBase[lvl2, i] + GDConsts.raceAdj[race, i]);
        if i < ClassCal.THIEF_HEAR_NOISE then
          thiefSkills[i] := thiefSkills[i] + GDConsts.dexAdj[stats[C_Stat.DEXTERITY].cur, i];
      end;
      lvl2 := saved;
    end;
  end;
end;

function FirstEarlierClass(cr: Types.PCharRecord): ShortInt;
var
  i: ShortInt;
begin
  FirstEarlierClass := 17;
  if cr^.race <> C_Race.HUMAN then Exit;
  i := 0;
  while (i < C_Class.THIEF) and (cr^.classLevelB[i] = 0) do Inc(i);
  if cr^.classLevelB[i] > 0 then FirstEarlierClass := i;
end;

function FirstCurrentClass(cr: Types.PCharRecord): ShortInt;
var
  i: ShortInt;
begin
  FirstCurrentClass := 17;
  if cr^.race <> C_Race.HUMAN then Exit;
  i := 0;
  while (i < C_Class.THIEF) and (cr^.classLevelA[i] = 0) do Inc(i);
  if cr^.classLevelA[i] > 0 then FirstCurrentClass := i;
end;

function CurrentDualClassLevel(cr: Types.PCharRecord): ShortInt;
var
  i: ShortInt;
begin
  if cr^.race <> C_Race.HUMAN then
    CurrentDualClassLevel := 0
  else begin
    i := 0;
    while (i < C_Class.THIEF) and (cr^.classLevelA[i] = 0) do Inc(i);
    CurrentDualClassLevel := cr^.classLevelA[i];
  end;
end;

function IsHuman(cr: Types.PCharRecord): Boolean;
begin
  IsHuman := cr^.race = C_Race.HUMAN;
end;

function EarlierClassActive(cr: Types.PCharRecord): Boolean;
begin
  EarlierClassActive := ClassCal.CurrentDualClassLevel(cr) > cr^.dualClassThreshold;
end;

function ChangeClass(cr: Types.PCharRecord): Byte;
var
  key: Char;
  cls: ShortInt;
  nRules: Byte;
  head: Types.PItemRec;
  cur: Types.PItemRec;
  { MenuCore.MenuVertical's var parameter }
  cnt: Integer;
  one: Byte;
  two: Boolean;
  node: Types.PItemRec;

  { True when the character may change to classId: another class, prime requisites high enough, alignment allowed. }
  function QualifiesForClass(classId: ShortInt): Boolean;
  var
    ok: Boolean;
    i: ShortInt;
    j: Byte;
  begin
    ok := GDConsts.raceClassTbl[cr^.race, GDVars.loopIdx] <> ClassCal.FirstCurrentClass(cr);
    i := 0;
    while (i <= C_Stat.CHARISMA) and
        ((GDConsts.classMinTbl[ClassCal.FirstCurrentClass(cr), i] < 9) or (cr^.stats[i].base > 14)) do Inc(i);
    ok := ok and (i > C_Stat.CHARISMA);
    i := 0;
    while (i <= C_Stat.CHARISMA) and ((GDConsts.classMinTbl[classId, i] < 9) or (cr^.stats[i].base > 16)) do Inc(i);
    ok := ok and (i > C_Stat.CHARISMA);
    j := 1;
    while (GDConsts.classAlignTbl[classId, 0] >= j) and
        (GDConsts.classAlignTbl[classId, j] <> Byte(cr^.alignment)) do Inc(j);
    ok := ok and (GDConsts.classAlignTbl[classId, 0] >= j);
    QualifiesForClass := ok;
  end;

begin
  ChangeClass := 17;
  if not (ClassCal.IsHuman(GDVars.curChar) and (ClassCal.FirstEarlierClass(GDVars.curChar) = 17)) then
    TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', Red, White)
  else begin
    nRules := GDConsts.raceClassTbl[cr^.race, 0];
    GetMem(head, SizeOf(Types.TItemNode));
    cur := head;
    cur^.next := nil;
    cur^.isHeader := 1;
    cur^.name := 'Pick New Class';
    cnt := 1;
    for GDVars.loopIdx := 1 to nRules do begin
      cls := GDConsts.raceClassTbl[cr^.race, GDVars.loopIdx];
      if QualifiesForClass(cls) then begin
        GetMem(cur^.next, SizeOf(Types.TItemNode));
        cur := cur^.next;
        cur^.next := nil;
        cur^.isHeader := 0;
        cur^.name := GDConsts.classNames[cls];
        Inc(cnt);
      end;
    end;
    if cnt = 1 then begin
      TextRend.PrintAndPause(cr^.name + ' doesn''t qualify.', Red, White);
      MenuCore.FreeStringList(head);
    end else begin
      cur := head;
      cnt := 1;
      one := 1;
      two := True;
      repeat
        key := MenuCore.MenuVertical('', 'Select', LightMagenta, LightGreen, White, 1, 2, 38, 22, head, one, two, cnt,
                                     cur);
        if key = C_Keys.NONE then Exit;
      until key = 'S';
      cr^.experience := 0;
      cr^.attacks := 2;
      cls := 0;
      while (cls <= C_Class.THIEF) and (GDConsts.classNames[cls] <> cur^.name) do Inc(cls);
      MenuCore.FreeStringList(head);
      cr^.classLevelB[ClassCal.FirstCurrentClass(cr)] := ClassCal.CurrentDualClassLevel(cr);
      cr^.dualClassThreshold := cr^.highestLevel;
      cr^.highestLevel := 1;
      cr^.classLevelA[ClassCal.FirstCurrentClass(cr)] := 0;
      cr^.classLevelA[cls] := 1;
      GameIo.FillWord(cr^.spellSlots, SizeOf(cr^.spellSlots));
      case cls of
        C_Class.CLERIC: cr^.spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
        C_Class.MAGE: begin
             cr^.spellSlots[C_Spell.MAGE_LIST, 1] := 1;
             cr^.known[11] := 1;
             cr^.known[18] := 1;
             cr^.known[12] := 1;
             cr^.known[21] := 1;
           end;
      end;
      cr^.charClass := cls;
      ChangeClass := cls;
      TextRend.PrintAndPause(cr^.name + ' is now a 1st level ' + GDConsts.classNames[cls] + '.', LightGreen, 0);
      GameIo.FillWord(cr^.memorizedSpells, SizeOf(cr^.memorizedSpells));
      ClassCal.RecalcClassStats(cr);
      ClassCal.RecalcSpellSlots(cr);
      ClassCal.RecalcClericSlots(cr);
      ClassCal.RecalcSaves(cr);
      ClassCal.RecalcThiefSkills(cr);
      node := cr^.itemsAddr;
      while node <> nil do begin
        if (GDVars.baseItems[node^.itemTypeV1].classMask and cr^.classMask) = 0 then
          if node^.cursedV1 = 0 then node^.equippedV1 := 0;
        node := node^.next;
      end;
    end;
  end;
end;

begin
end.
