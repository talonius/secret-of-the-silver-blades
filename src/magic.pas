{ Spell preparation and casting: the memorization and scribing menus, cast-target selection, and spell effect dispatch
  through the spell handler table. }
{$O+,F+,A-,I-,V-}
unit Magic;

interface

uses Types, Money, FxEngine, CharHlp, ClassCal, MenuCore, Pathing, CbtMap, Border, TextRend, GameIo, SoundDrv, Crt,
  GDConsts, GDVars, C_Race, C_Status, C_Class, C_Effect, C_Keys, C_Dir, C_Ifc, C_Spell,
  C_Stat, C_Save;

{ Runs the spell menu that GenerateSpellList built, then frees the list. Note: for Scribe the scroll is read from
  spellScratch after GenerateSpellList has freed it.
  @param(selType The menu: 1 Cast, 2 Memorize (rows 5 to 15, redrawn when fixByte is set), 3 Scribe, or 4 Learn, which
    has no Exit.)
  @param(idx The highlighted line, kept between calls; below 0 forces a redraw.)
  @returns(The chosen spell, or 0 for Exit or Escape. For Scribe, useItem is set to the chosen spell's scroll.) }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Builds the spell menu list for the current character, with a heading before each spell level except in the scroll
  lists.
  @param(menuType 0 its memorized spells it can cast, 5 those still being memorized, 1 the spells it knows and can cast,
    4 the magic-user spells it does not know at the levels it has magic-user slots for, 2 the current scroll's spells, 7
    the current bundle's, 3 all its scrolls' spells, 6 its scrolls' spells marked for scribing.)
  @returns(True when the list is not empty.) }
function GenerateSpellList(menuType: Byte): Boolean;

{ Computes a spell's range.
  @param(spell The spell.)
  @returns(Its base plus its per-level range times the caster level div 4 (for an item, the per-level range div 4 times
    6); a spell with an area gets at least 1, and 255 becomes 1.) }
function CalcSpellRange(spell: Byte): Byte;

{ Picks the targets of a spell cast outside combat (castTargetMenu there): the caster (targeting 1), a party member the
  player chooses (2; choosing none cancels), or the whole party (3); other targeting cannot be cast here.
  @param(spell The spell being cast.)
  @param(b Unused.)
  @param(cast Set False when the spell is not cast.) }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Casts spell for the current character. Outside combat a spell without noncombat targeting can only be lost ("Lose
  it?"), and an item of that kind can only be used up without effect ("Use it?", which sets sel); a feebleminded
  character casts nothing but from an item; with ai a cast that no item makes is announced. The target picker
  (castTargetMenu) chooses the targets; in combat the caster turns toward the target cell, the spell's sound plays and a
  bolt is drawn. Then invisibility is dropped, the spell is used up (unless an item casts it) and its handler in
  spellFns runs. A cancelled pick in combat asks whether to abort (b skips the question), which loses the spell.
  @param(spell The spell to cast.)
  @param(b True to abort a cancelled pick without asking; the target picker gets it too.)
  @param(ai True to announce the cast.)
  @param(sel Set by the target picker when targets were chosen, or by a Yes to "Use it?".) }
procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Tells whether an item is readable.
  @param(it The item, or nil.)
  @returns(True for a scroll (item type 39 or 40) or a bundle.) }
function ItemReadable(it: Types.PItemRec): Boolean;

{ Removes a spell from a scroll, or from the first scroll of a bundle that holds it: the scroll's spell-count name part
  drops by one, and the scroll goes when none are left (name id below 100), from the bundle, which becomes its last
  scroll when only one is left, or from the character's items.
  @param(cr The character carrying the scroll.)
  @param(it The scroll or bundle.)
  @param(spell The spell to remove; bit 7 of the scroll's entries is ignored.) }
procedure RemoveSpellFromScroll(cr: Types.PCharRecord; it: Types.PItemRec; spell: Byte);

{ Reports a cast: in combat "Casts a Spell" and the spell's name on row 23; outside combat the caster's name, the given
  text and the spell's name in the text window, then a pause.
  @param(cr The caster.)
  @param(msg Printed after the caster's name outside combat.)
  @param(spell The spell cast.) }
procedure PrintCastSpellMsg(cr: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Spells 43 and 89 (Remove Curse): lifts Bestow Curse from the target ("is un-cursed"), or else clears the curse of its
  first cursed item and, when that item's special effect is above $7F, removes that effect through the override handler
  and recalculates the target's abilities ("has an item un-cursed"). }
procedure SpellRemoveCurse;

{ Installs the spell handlers (spellFns, with castTargetMenu the outside-combat target picker) and EffDragonBreath as
  effect handlers 83 and 104, resets the effect lock, the item-use flag and the last target, and sets the
  inventory-redraw flag. }
procedure InitSpellFns;

{ Applies a spell to each target. The save is rolled only when the spell has a saving throw. A spell of fixed range 255
  needs an attack roll as well; a miss counts as saved and zeroes the damage for this and each later target. The damage
  is dealt with the save reducing it, and the spell's effect, if any, is added. With no targets it returns at once,
  leaving the element mask set.
  @param(spell The spell.)
  @param(casterLvl The effect's strength; 0 for the casting level.)
  @param(onRemove True to call the effect's handler when it is removed.)
  @param(damage The damage; 0 for none.)
  @param(elemKind The damage's element mask.)
  @param(msg Printed after each target's name when the effect takes hold.) }
procedure ResolveSpell(spell, casterLvl, onRemove, damage, elemKind: Byte; msg: Types.TStr40);

{ Shows a message on a character's line and asks whether to cast the cure anyway.
  @param(cr The character.)
  @param(msg The message.)
  @returns('Y' or 'N'.) }
function PromptCastAnyway(cr: Types.PCharRecord; msg: String): Char;

implementation

const
  NORMAL_STRENGTH_MAX = 18;

{ Tells whether a character's classes let it cast a spell; earlier-class levels count where EarlierClassActive allows.
  The cleric list needs Wisdom above 8 and either a cleric level or more than 8 paladin levels; the druid list Wisdom
  above 8 and more than 6 ranger levels; the magic-user list Intelligence above 8 and either magic-user levels with a
  race other than human, no armor (equipped[2]) or being outside combat, more than 8 ranger levels, or, from a scroll,
  more than 10 thief levels; the special list never.
  @param(cr The character.)
  @param(spell The spell; bit 7 is ignored.)
  @param(viaScroll True when the spell is read from a scroll.)
  @returns(True when the character can cast the spell.) }
function ClassCanCastSpell(cr: Types.PCharRecord; spell: Byte; viaScroll: Boolean): Boolean;
begin
  spell := spell and C_Spell.ID_MASK;
  ClassCanCastSpell := False;
  case GDConsts.spellDefs[spell].castClass of
    C_Spell.CLERIC_LIST: if Boolean(cr^.stats[C_Stat.WISDOM].cur > 8)
          and
            ((cr^.classLevelA[C_Class.CLERIC] > 0) or ((ClassCal.EarlierClassActive(cr)) and
                                                       (cr^.classLevelB[C_Class.CLERIC] > 0)) or
             (cr^.classLevelA[C_Class.PALADIN] > 8) or
             ((ClassCal.EarlierClassActive(cr)) and (cr^.classLevelB[C_Class.PALADIN] > 8))) then
         ClassCanCastSpell := True;
    C_Spell.DRUID_LIST: ClassCanCastSpell := Boolean(cr^.stats[C_Stat.WISDOM].cur > 8)
          and
            ((cr^.classLevelA[C_Class.RANGER] > 6) or ((ClassCal.EarlierClassActive(cr)) and
                                                       (cr^.classLevelB[C_Class.RANGER] > 6)));
    C_Spell.MAGE_LIST: if cr^.intCur > 8 then begin
         if (cr^.classLevelA[C_Class.MAGE] > 0)
            or ((ClassCal.EarlierClassActive(cr)) and (cr^.classLevelB[C_Class.MAGE] > 0)) then
           if (cr^.race <> C_Race.HUMAN) or (cr^.equipped[2] = nil)
              or (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
             ClassCanCastSpell := True;
         if (cr^.classLevelA[C_Class.RANGER] > 8)
            or ((ClassCal.EarlierClassActive(cr)) and (cr^.classLevelB[C_Class.RANGER] > 8)) then
           ClassCanCastSpell := True;
         if viaScroll
            and
              ((cr^.classLevelA[C_Class.THIEF] > 10) or
               ((ClassCal.EarlierClassActive(cr)) and (cr^.classLevelB[C_Class.THIEF] > 10))) then
           ClassCanCastSpell := True;
       end;
    C_Spell.SPECIAL_LIST: ClassCanCastSpell := False;
  end;
end;

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  { receives MenuVertical's highlighted member }
  sel: Types.PItemRec;
  { the counting cursor }
  p: Types.PItemRec;
  prompt: Types.TStr40;
  header: Types.TStr40;
  count: Word;
  { the menu window's bottom row }
  d: Byte;
  ch: Char;
  flag: Boolean;
  redraw: Boolean;
begin
  case selType of
    1: header := 'Cast';
    2: header := 'Memorize';
    3: header := 'Scribe';
    4: header := 'Learn';
  else
    header := '';
  end;
  redraw := False;
  if selType in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if selType = 2 then begin
    d := 15;
    redraw := Boolean(GDVars.fixByte);
  end else
    d := 22;
  if selType = 4 then
    flag := False
  else
    flag := True;
  if idx < 0 then begin
    redraw := True;
    idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    ch := MenuCore.MenuVertical(prompt, header, LightMagenta, LightGreen, White, 1, 5, 38, d, GDVars.spellList,
                                Ord(flag), redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := GDVars.spellList;
  count := 0;
  while p <> sel do begin
    if p^.isHeader = 0 then
      Inc(count);
    p := p^.next;
  end;
  if ch in [C_Keys.NONE, 'E'] then
    SpellSelection := 0
  else
    SpellSelection := GDVars.spellIdx[count];
  if selType = 3 then
    GDVars.useItem := GDVars.spellScratch^[count];
  MenuCore.FreeStringList(GDVars.spellList);
end;

{ Appends a spell to the scroll spell list (and its id list), with a level heading when its level differs from the last
  spell's.
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddScrollSpellLine(spell: Byte);
var
  cur: Types.PItemRec;
  idx: Word;
  lvl: ShortInt;
begin
  cur := GDVars.spellList;
  if GDVars.spellList = nil then begin
    GetMem(cur, SizeOf(Types.TItemNode));
    GDVars.spellList := cur;
    lvl := 0;
    idx := 0;
  end else begin
    idx := 1;
    while cur^.next <> nil do begin
      if cur^.isHeader = 0 then
        Inc(idx);
      cur := cur^.next;
    end;
    lvl := GDConsts.spellDefs[GDVars.spellIdx[idx - 1]].level;
    GetMem(cur^.next, SizeOf(Types.TItemNode));
    cur := cur^.next;
  end;
  cur^.next := nil;
  if GDConsts.spellDefs[spell and C_Spell.ID_MASK].level <> lvl then begin
    cur^.name := GDConsts.levelOrdinal[GDConsts.spellDefs[spell and C_Spell.ID_MASK].level] + GDConsts.lvlSuffix;
    cur^.isHeader := 1;
    GetMem(cur^.next, SizeOf(Types.TItemNode));
    cur := cur^.next;
    cur^.next := nil;
  end;
  if spell > C_Spell.ID_MASK then
    cur^.name := ' *'
  else
    cur^.name := '  ';
  cur^.name := cur^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  cur^.isHeader := 0;
  GDVars.spellIdx[idx] := spell and C_Spell.ID_MASK;
end;

{ Adds a spell to the menu list (and its id list), before the first spell of a higher level; a repeat of the same spell
  is merged into a count "(n)".
  @param(spell The spell; bit 7 marks it with " *".) }
procedure AddSpellToList(spell: Byte);
var
  carry: Byte;
  hold: Byte;
  cur: Types.PItemRec;
  scan: Types.PItemRec;
  node: Types.PItemRec;
  idx: Word;
  k: Word;
  found: Boolean;
  lvl: ShortInt;
begin
  cur := GDVars.spellList;
  found := False;
  lvl := GDConsts.spellDefs[spell and C_Spell.ID_MASK].level;
  if GDVars.spellList = nil then begin
    GameIo.FillWord(GDVars.spellQty, SizeOf(GDVars.spellQty));
    GetMem(cur, SizeOf(Types.TItemNode));
    cur^.next := nil;
    GDVars.spellList := cur;
    idx := 0;
    GDVars.spellQty[idx] := 1;
  end else begin
    idx := 0;
    while (cur <> nil) and (not found) do
      if cur^.isHeader = 0 then begin
        if (GDConsts.spellDefs[GDVars.spellIdx[idx]].level <= lvl) and
            ((spell and C_Spell.ID_MASK) <> GDVars.spellIdx[idx]) then begin
          Inc(idx);
          cur := cur^.next;
        end else
          found := True;
      end else begin
        cur := cur^.next;
        Inc(idx);
      end;
    if (spell and C_Spell.ID_MASK) <> GDVars.spellIdx[idx] then begin
      scan := GDVars.spellList;
      if scan <> cur then begin
        while scan^.next <> cur do
          scan := scan^.next;
        GetMem(node, SizeOf(Types.TItemNode));
        node^.next := scan^.next;
        scan^.next := node;
        cur := node;
      end else begin
        GetMem(node, SizeOf(Types.TItemNode));
        node^.next := cur;
        GDVars.spellList := node;
        cur := node;
      end;
      carry := 1;
      for k := idx to 125 do begin
        hold := GDVars.spellQty[k];
        GDVars.spellQty[k] := carry;
        carry := hold;
      end;
    end else
      Inc(GDVars.spellQty[idx]);
  end;
  if spell > C_Spell.ID_MASK then
    cur^.name := ' *'
  else
    cur^.name := '  ';
  cur^.name := cur^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  cur^.isHeader := 0;
  if GDVars.spellQty[idx] > 1 then
    cur^.name := cur^.name + ' (' + CharHlp.Uint8Str(GDVars.spellQty[idx]) + ')';
  if (spell and C_Spell.ID_MASK) <> GDVars.spellIdx[idx] then begin
    carry := GDVars.spellIdx[idx];
    GDVars.spellIdx[idx] := spell and C_Spell.ID_MASK;
    for k := idx + 1 to 125 do begin
      hold := GDVars.spellIdx[k];
      GDVars.spellIdx[k] := carry;
      carry := hold;
    end;
  end;
end;

{ Adds the current scroll's (useItem's) spells to the list (with alreadyCast only those marked for scribing), recording
  the scroll in spellScratch for each, and stops at the first spell the character's classes cannot cast. The scroll is
  identified first when the character has Read Magic (effect 16) or is a cleric reading a scroll of slot 12; an
  unidentified scroll adds nothing.
  @param(alreadyCast Selects the spells marked for scribing.) }
procedure AddScrollSpells(alreadyCast: Boolean);
var
  i: Byte;
  { the HasEffect var param }
  eff: Types.PEffectRec;
begin
  if CharHlp.HasEffect(GDVars.curChar, 16, eff) or
      (((GDVars.curChar^.classLevelA[C_Class.CLERIC] > 0) or
        (GDVars.curChar^.classLevelB[C_Class.CLERIC] > GDVars.curChar^.dualClassThreshold)) and
       (GDVars.baseItems[Ord(GDVars.useItem^.kind)].slot = 12)) then
    GDVars.useItem^.idFlags := GDVars.useItem^.idFlags and $F8;
  if (GDVars.useItem^.idFlags and 7) <> 0 then
    Exit;
  for i := 1 to 3 do
    if (alreadyCast and (GDVars.useItem^.scribe[i] > C_Spell.PENDING_FLAG)) or
        ((not alreadyCast) and (GDVars.useItem^.scribe[i] > 0)) then begin
      if not Magic.ClassCanCastSpell(GDVars.curChar, GDVars.useItem^.scribe[i], True) then
        Exit;
      Magic.AddScrollSpellLine(GDVars.useItem^.scribe[i]);
      GDVars.spellScratch^[GDVars.scratchCount] := GDVars.useItem;
      Inc(GDVars.scratchCount);
    end;
end;

{ Clears the scroll records and adds the spells of each scroll in the current bundle (useItem) through AddScrollSpells;
  useItem is left nil.
  @param(alreadyCast Passed on to AddScrollSpells.) }
procedure ScribeBundle(alreadyCast: Boolean);
var
  i: Word;
begin
  for i := 0 to 1000 do
    GDVars.spellScratch^[i] := nil;
  GDVars.scratchCount := 0;
  GDVars.useItem := GDVars.useItem^.bundleNext;
  while GDVars.useItem <> nil do begin
    Magic.AddScrollSpells(alreadyCast);
    GDVars.useItem := GDVars.useItem^.bundleNext;
  end;
end;

{ Clears the scroll records and adds the spells of each readable item of the current character, the scrolls in its
  bundles included, through AddScrollSpells.
  @param(alreadyCast Passed on to AddScrollSpells.) }
procedure AddAllScrollSpells(alreadyCast: Boolean);
var
  i: Word;
  saved: Types.PItemRec;
begin
  for i := 0 to 1000 do
    GDVars.spellScratch^[i] := nil;
  GDVars.scratchCount := 0;
  GDVars.useItem := GDVars.curChar^.itemsAddr;
  while GDVars.useItem <> nil do begin
    if Magic.ItemReadable(GDVars.useItem) then
      if GDVars.useItem^.kind = 'I' then
      begin
        saved := GDVars.useItem;
        GDVars.useItem := GDVars.useItem^.bundleNext;
        while GDVars.useItem <> nil do begin
          Magic.AddScrollSpells(alreadyCast);
          GDVars.useItem := GDVars.useItem^.bundleNext;
        end;
        GDVars.useItem := saved;
      end else
        Magic.AddScrollSpells(alreadyCast);
    GDVars.useItem := GDVars.useItem^.next;
  end;
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  spellId: Byte;
  i: Word;
  cur: Types.PItemRec;
  nw: Types.PItemRec;
  lvlPrev: ShortInt;
  lvl: ShortInt;
  addHdrs: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  classIdx: Byte;
begin
  New(GDVars.spellScratch);
  addHdrs := True;
  GenerateSpellList := False;
  GDVars.spellList := nil;
  GameIo.FillWord(GDVars.spellIdx, SizeOf(GDVars.spellIdx));
  case menuType of
    0: for i := 0 to 74 do
         if (GDVars.curChar^.memorizedSpells[i] > 0)
            and Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK, False)
            and (GDVars.curChar^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    5: for i := 0 to 74 do
         if (GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK) and
             Magic.ClassCanCastSpell(GDVars.curChar, GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK, False) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i]);
    1: for i := 1 to 117 do
         if (GDVars.curChar^.known[i] <> 0)
            and Magic.ClassCanCastSpell(GDVars.curChar, i, False) then
           Magic.AddSpellToList(i);
    2: begin
         Magic.AddScrollSpells(False);
         addHdrs := False;
       end;
    7: begin
         Magic.ScribeBundle(False);
         addHdrs := False;
       end;
    3: begin
         Magic.AddAllScrollSpells(False);
         addHdrs := False;
       end;
    6: begin
         Magic.AddAllScrollSpells(True);
         addHdrs := False;
       end;
    4: for lvl := 1 to 7 do
         if GDVars.curChar^.spellSlots[C_Spell.MAGE_LIST, lvl] > 0 then begin
           i := 1;
           spellId := 255;
           while (i <= 11) and (spellId <> 0) do begin
             spellId := GDConsts.spellsByLevel[lvl, i];
             if (spellId <> 0) and (GDVars.curChar^.known[spellId] = 0) then
               Magic.AddSpellToList(spellId);
             Inc(i);
           end;
         end;
  end;
  if GDVars.spellList <> nil then begin
    if addHdrs then begin
      i := 0;
      lvl := GDConsts.spellDefs[GDVars.spellIdx[i]].level;
      GetMem(nw, SizeOf(Types.TItemNode));
      nw^.next := GDVars.spellList;
      GDVars.spellList := nw;
      GDVars.spellList^.name := GDConsts.levelOrdinal[GDConsts.spellDefs[GDVars.spellIdx[i]].level] +
        GDConsts.lvlSuffix;
      GDVars.spellList^.isHeader := 1;
      cur := GDVars.spellList;
      repeat
        lvlPrev := lvl;
        if GDVars.spellIdx[i] <> 0 then
          lvl := GDConsts.spellDefs[GDVars.spellIdx[i]].level;
        if lvlPrev < lvl then begin
          GetMem(nw, SizeOf(Types.TItemNode));
          nw^.next := cur^.next;
          cur^.next := nw;
          cur := cur^.next;
          cur^.name := GDConsts.levelOrdinal[lvl] + GDConsts.lvlSuffix;
          cur^.isHeader := 1;
        end;
        Inc(i);
        cur := cur^.next;
      until cur = nil;
    end;
    GenerateSpellList := True;
  end;
  Dispose(GDVars.spellScratch);
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GDVars.usingItemFlag = 0 then
    r := GDConsts.spellDefs[spell].rangeBase
         + GDConsts.spellDefs[spell].rangePerLevel * CharHlp.GetCasterLevel(spell) div 4
  else
    r := (GDConsts.spellDefs[spell].rangePerLevel div 4) * 6
         + GDConsts.spellDefs[spell].rangeBase;
  if (r = 0) and (GDConsts.spellDefs[spell].area <> 0) then
    r := 1;
  if r = 255 then
    r := 1;
  CalcSpellRange := r;
end;

{ Computes a spell's duration.
  @param(spell The spell.)
  @returns(3780 for spell 26, 1d6 * 10 for 40, 5d4 for 57 and 61, 1d4 * 10 + 40 for 59, otherwise its base plus its
    per-level duration times the caster level.) }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    26: d := 3780;
    40: d := FxEngine.RollDice(1, 6) * 10;
    57, 61: d := FxEngine.RollDice(5, 4);
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
  else
    d := GDConsts.spellDefs[spell].durationBase
         + GDConsts.spellDefs[spell].durationPerLevel * CharHlp.GetCasterLevel(spell);
  end;
  CalcSpellDuration := d;
end;

procedure ResolveSpell(spell, casterLvl, onRemove, damage, elemKind: Byte; msg: Types.TStr40);
var
  lvl: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tgt: array[1..4] of Byte;
  saved: Boolean;
begin
  if damage = 0 then
    GDVars.elemMask := 0
  else
    GDVars.elemMask := elemKind;
  if GDVars.castTargetCount <> 0 then begin
    if casterLvl = 0 then
      lvl := CharHlp.GetCasterLevel(spell)
    else
      lvl := casterLvl;
    for i := 1 to GDVars.castTargetCount do
      if GDVars.castTargets[i] <> nil then begin
        if GDConsts.spellDefs[spell].saveEffect = 0 then
          saved := False
        else
          saved := FxEngine.RollSavingThrow(GDVars.castTargets[i], GDConsts.spellDefs[spell].saveType, 0);
        if GDConsts.spellDefs[GDVars.spellId].rangeBase = 255 then begin
          CharHlp.RecalcStats(GDVars.castTargets[i]);
          FxEngine.TriggerEffectsWithCondition(11, GDVars.castTargets[i]);
          if not FxEngine.AttackRoll(GDVars.curChar, GDVars.castTargets[i],
                                     GDVars.castTargets[i]^.acCurArr[0]) then begin
            damage := 0;
            saved := True;
          end;
        end;
        if damage > 0 then
          FxEngine.InflictNonWeaponDamage(GDVars.castTargets[i], damage, GDConsts.spellDefs[spell].saveEffect, saved);
        if GDConsts.spellDefs[spell].effectId > 0 then
          FxEngine.AddEffectWithMessage(GDVars.castTargets[i], GDConsts.spellDefs[spell].effectId,
                                        Magic.CalcSpellDuration(spell), lvl, onRemove,
                                        GDConsts.spellDefs[spell].saveEffect, saved, msg);
      end;
    GDVars.elemMask := 0;
  end;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  target: Pointer;
begin
  if GDVars.castTarget = nil then
    GDVars.castTarget := GDVars.curChar;
  GDVars.castTargets[1] := GDVars.curChar;
  GDVars.castTargetCount := 1;
  cast := True;
  case GDConsts.spellDefs[spell].noncombatTarget of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         GDVars.selOverride := 1;
         CharHlp.SelectChar('Cast Spell on whom', 1, 1, GDVars.castTarget);
         GDVars.selOverride := 0;
         if GDVars.castTarget = nil then begin
           GDVars.castTargets[1] := nil;
           GDVars.castTargetCount := 0;
           cast := False;
         end else
           GDVars.castTargets[1] := GDVars.castTarget;
       end;
    3: begin
         GDVars.castTargets[GDVars.castTargetCount] := GDVars.creatureList;
         while GDVars.castTargets[GDVars.castTargetCount]^.nextCharAddr <> nil do begin
           GDVars.castTargets[GDVars.castTargetCount + 1] := GDVars.castTargets[GDVars.castTargetCount]^.nextCharAddr;
           Inc(GDVars.castTargetCount);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpell(spell: Byte; b, ai: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  cx: ShortInt;
  cy: ShortInt;
  dir: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mr: Byte;
  cr: Types.PCharRecord;
  eff: Types.PEffectRec;
begin
  cr := GDVars.curChar;
  ok := True;
  if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (GDConsts.spellDefs[spell].noncombatTarget = 0) then begin
    if GDVars.usingItemFlag = 0 then begin
      TextRend.DisplayString(1, 19, LightGreen, 0, GDConsts.spellNames[spell]);
      TextRend.DisplayString(1, 20, LightGreen, 0, 'can''t be cast here...');
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, LightGreen, White, 2) = 'Y' then
        CharHlp.RemoveSpell(cr, spell);
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, 0, 'That Item');
      if spell = 31 then
        TextRend.DisplayString(1, 20, LightGreen, 0, 'is only useful on locked doors.')
      else
        TextRend.DisplayString(1, 20, LightGreen, 0, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, LightGreen, White, 2) = 'Y' then
        sel := True;
    end;
    ai := False;
    ok := False;
  end;
  if CharHlp.HasEffect(cr, C_Effect.FEEBLEMINDED, eff) and (GDVars.usingItemFlag = 0) then begin
    ai := False;
    ok := False;
  end;
  if ai and (GDVars.usingItemFlag = 0) then
    Magic.PrintCastSpellMsg(cr, 'casts', spell);
  while ok do begin
    GDVars.castTargetMenu(spell, b, sel);
    if sel then begin
      ok := False;
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        CharHlp.BuildIconFacings(18);
        cx := CbtMap.CombatCellX(cr);
        cy := CbtMap.CombatCellY(cr);
        dir := C_Dir.NORTH;
        while not Pathing.IsDirToward(cx, cy, GDVars.targetCellX, GDVars.targetCellY, dir) do
          Inc(dir);
        GDVars.actorVisible := True;
        CbtMap.SetCreatureFacing(cr, dir, 1, 0);
        case spell of
          47: SoundDrv.SoundCommand(GDConsts.explosionSound);
          51: SoundDrv.SoundCommand(GDConsts.lightningSound);
        else
          SoundDrv.SoundCommand(GDConsts.defaultSpellSound);
        end;
        CharHlp.CombatAnimateMovingIcon(cx, cy, GDVars.targetCellX, GDVars.targetCellY, 4, 30);
        if CbtMap.CombatIconVisible(cr, 0) then begin
          CbtMap.SetCreatureFacing(cr, cr^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(cr, cr^.combatAddr^.direction, 0, 0);
        end;
      end;
      FxEngine.RemoveInvisibility(cr);
      if GDVars.usingItemFlag = 0 then
        CharHlp.RemoveSpell(cr, spell);
      GDVars.spellId := spell;
      GDVars.spellFns[GDVars.spellId];
      GDVars.spellId := 0;
      GDVars.areaTargets := 0;
    end else begin
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        ok := False
      else begin
        if b or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White, 2) = 'Y') then
        begin
          CharHlp.PrintBottomLine('Spell Aborted');
          if GDVars.usingItemFlag = 0 then
            CharHlp.RemoveSpell(cr, spell);
          ok := False;
        end;
      end;
    end;
  end;
  CharHlp.ClearMessageWindow;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

{ Fills the spell targets with the creatures, other than the caster, on a line from the origin through the aimed cell,
  extended to the cone's length and cut short by walls, and with two or three rays on one or two more lines to cells
  beside its end; 255 rays take instead the creatures within 3 cells of the line's end. Note: once a creature has been
  met twice on the main line, no later creature on it is added; and the area list of 255 rays overwrites the line's list
  without ending it, so creatures past its length stay.
  @param(fromX The column of the cone's origin.)
  @param(fromY The row of the cone's origin.)
  @param(toX The column of the aimed cell.)
  @param(toY The row of the aimed cell.)
  @param(kind The number of lines (1, 2 or 3), or 255 for an area at the end.)
  @param(casterLvl The cone's length in cells.) }
procedure CollectConeTargets(fromX, fromY, toX, toY: ShortInt; kind, casterLvl: Byte);
  var
  cell1X: ShortInt;
  cell1Y: ShortInt;
  cell2X: ShortInt;
  cell2Y: ShortInt;
  req: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  walkOk: Boolean;
  walked: Byte;
  stepIdx: Byte;
  lastIdx: Byte;
  steps: array[0..49] of Byte;
  cells: array[0..30] of Byte;
  terr: Byte;
  cnt: Byte;
  j: Byte;
  lastStep: Byte;
  lineDist: Word;
  dup: Boolean;

  { Starts the line walk req from (x1, y1) to (x2, y2). }
  procedure SetLine(x1, y1, x2, y2: ShortInt);
  begin
    req.sx := x1;
    req.sy := y1;
    req.ex := x2;
    req.ey := y2;
    Pathing.PathFind(req);
  end;

  { Keeps (x, y) inside the 50x25 arena. }
  procedure ClampCell(var x, y: ShortInt);
  begin
    if x > 49 then
      x := 49
    else if x < 0 then
      x := 0;
    if y > 24 then
      y := 24
    else if y < 0 then
      y := 0;
  end;

  { Adds each creature on the rest of the walked line to the list, once. }
  procedure CollectAlong;
  var
    i: Byte;
    found: Boolean;
  begin
    repeat
      done := not Pathing.NextPathStep(req);
      if not done then begin
        CbtMap.GetArenaContents(req.cx, req.cy, cells[0], terr);
        i := 1;
        found := False;
        if cells[0] > 0 then
          repeat
            if cells[i] = cells[0] then
              found := True
            else if cells[i] = 0 then begin
              cells[i] := cells[0];
              found := True;
            end else
              Inc(i);
          until found;
      end;
    until done;
  end;

begin
  stepIdx := 0;
  SetLine(fromX, fromY, toX, toY);
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      steps[stepIdx] := req.step;
      Inc(stepIdx);
    end;
  until done;
  lastIdx := stepIdx - 1;
  stepIdx := 0;
  casterLvl := casterLvl * 2;
  walked := req.dist;
  done := False;
  while (walked < casterLvl) and not done do begin
    if (toX < 49) and (toX > 0) and (toY < 24) and (toY > 0) then begin
      case steps[stepIdx] of
        0, 2, 4, 6: Inc(walked, 2);
        1, 3, 5, 7: Inc(walked, 3);
      end;
      Inc(toX, GDConsts.dirDx[steps[stepIdx]]);
      Inc(toY, GDConsts.dirDy[steps[stepIdx]]);
      if stepIdx = lastIdx then
        stepIdx := 0
      else
        Inc(stepIdx);
    end else
      done := True;
  end;
  ClampCell(toX, toY);
  walkOk := Pathing.WalkLine(fromX, fromY, toX, toY, lineDist, GDVars.arenaPtr);
  SetLine(fromX, fromY, toX, toY);
  GameIo.FillWord(cells[1], SizeOf(cells) - SizeOf(cells[0]));
  cnt := 1;
  repeat
    done := not Pathing.NextPathStep(req);
    if not done then begin
      CbtMap.GetArenaContents(req.cx, req.cy, cells[0], terr);
      if cells[0] > 0 then begin
        if cnt > 1 then begin
          for GDVars.loopIdx := 1 to cnt - 1 do
            if cells[GDVars.loopIdx] = cells[0] then
              dup := True;
        end else
          dup := False;
        if not dup then begin
          cells[cnt] := cells[0];
          Inc(cnt);
        end;
        lastStep := req.step;
      end;
    end;
  until done;
  if (kind > 1) and (kind <> 255) then begin
    cell1X := toX + GDConsts.flank1Dx[lastStep];
    cell1Y := toY + GDConsts.flank1Dy[lastStep];
    ClampCell(cell1X, cell1Y);
    cell2X := toX + GDConsts.flank2Dx[lastStep];
    cell2Y := toY + GDConsts.flank2Dy[lastStep];
    ClampCell(cell2X, cell2Y);
    SetLine(fromX, fromY, cell2X, cell2Y);
    CollectAlong;
    if kind > 2 then begin
      SetLine(fromX, fromY, cell1X, cell1Y);
      CollectAlong;
    end;
  end;
  if kind = 255 then begin
    Pathing.BuildTargetList(toX, toY, 3, 255, 1, GDVars.arenaPtr);
    for GDVars.loopIdx := 1 to GDVars.targetCount do
      cells[GDVars.loopIdx] := GDVars.targets[GDVars.loopIdx].who;
  end;
  cnt := 1;
  j := 1;
  GDVars.castTargetCount := 0;
  if cells[1] <> 0 then
    repeat
      if GDVars.creatures[cells[cnt]] <> GDVars.curChar then begin
        Inc(GDVars.castTargetCount);
        GDVars.castTargets[j] := GDVars.creatures[cells[cnt]];
        Inc(j);
      end;
      Inc(cnt);
    until cells[cnt] = 0;
end;

{ Applies the current spell's effect, at caster-level strength, to each target from the last to the first, drawing a
  bolt to all but the last listed, with a save at saveMod. Tribbles and monsters always save against spells 23 and 49,
  and for spells 79 and 81 the last target always saves.
  @param(saveMod The saving-throw modifier.)
  @param(msg Reports the effect on each target.) }
procedure ApplyEffectToTargets(saveMod: Byte; msg: Types.TStr40);
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  redu: Byte;
begin
  for i := GDVars.castTargetCount downto 1 do
    if GDVars.castTargets[i] <> nil then begin
      tgt := GDVars.castTargets[i];
      if i < GDVars.castTargetCount then begin
        SoundDrv.SoundCommand(GDConsts.defaultSpellSound);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.curChar), CbtMap.CombatCellY(GDVars.curChar),
                                        CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt), 4, 30);
      end;
      if ((GDVars.spellId = 79) or (GDVars.spellId = 81)) and (i = GDVars.castTargetCount) then begin
        saved := True;
        redu := 1;
      end else begin
        saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellDefs[GDVars.spellId].saveType, saveMod);
        redu := GDConsts.spellDefs[GDVars.spellId].saveEffect;
      end;
      if ((tgt^.race = C_Race.TRIBBLE) or (tgt^.race = C_Race.MONSTER))
         and ((GDVars.spellId = 23) or (GDVars.spellId = 49)) then
        saved := True;
      if not saved then
        FxEngine.AddEffectWithMessage(tgt, GDConsts.spellDefs[GDVars.spellId].effectId,
                                      Magic.CalcSpellDuration(GDVars.spellId),
                                      CharHlp.GetCasterLevel(GDVars.spellId), 0, redu, saved, msg);
    end;
end;

{ Resolves the current spell on the targets of one side; Bless in combat also skips a target with an enemy next to it.
  @param(team The side affected.)
  @param(msg The effect's message.) }
procedure CastOneSide(team: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.areaTargets := 1;
  for i := 1 to GDVars.castTargetCount do
    if (GDVars.castTargets[i]^.hostile <> team)
       or ((GDVars.spellId = 1) and (GDVars.interfaceState = C_Ifc.IN_COMBAT) and
           (CharHlp.CountTargets(GDVars.castTargets[i], 1) > 0)) then
      GDVars.castTargets[i] := nil;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, msg);
end;

{ Does nothing: an unused spell slot. }
procedure SpellNoEffect;
begin
end;

{ Casts Bless on the caster's own side. }
procedure SpellBless;
begin
  Magic.CastOneSide(GDVars.curChar^.hostile, GDConsts.msgIs + GDConsts.effectNames[1]);
end;

{ Casts Curse on the caster's enemies. }
procedure SpellCurse;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GDVars.curChar), GDConsts.msgIs + GDConsts.effectNames[2]);
end;

{ Casts Cure Light Wounds: restores 1d8 hit points to the first target. }
procedure SpellCureLightWounds;
begin
  if GDVars.castTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(1, 8), 0) then
    CharHlp.AnnounceHealStatus(GDVars.castTargets[1]);
end;

{ Casts Cause Light Wounds: 1d8 magic damage. }
procedure SpellCauseLightWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(1, 8), 8, '');
end;

{ Applies a detection spell's effect to the targets. }
procedure SpellDetection;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgAffected);
end;

{ Applies a protection spell's effect to the targets. }
procedure SpellProtection;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgProtected);
end;

{ Applies Resist Cold's effect to the targets. }
procedure SpellResistCold;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[10]);
end;

{ Casts Burning Hands: fire damage of 1 point per caster level. }
procedure SpellBurningHands;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, CharHlp.GetCasterLevel(9), 9, '');
end;

{ Spell 10 (Charm Person): charms the target when it is a person (a race below monster) or has target flag 2, then runs
  the charm's handler; the charm's strength holds the caster's team in bit 7 and the caster level. Any other target "is
  unaffected". }
procedure SpellCharmPerson;
var
  { HasEffect var parameter }
  eff: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  if tgt = nil then
    Exit;
  if (tgt^.race < C_Race.MONSTER) or ((tgt^.targetFlags and 2) <> 0) then begin
    Magic.ResolveSpell(GDVars.spellId, GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.spellId),
                       1, 0, 0,
                        GDConsts.msgIs + GDConsts.effectNames[11]);
    if CharHlp.HasEffect(tgt, 11, eff) then
      FxEngine.CallEffectHandler(11, tgt, eff, False);
  end else
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + GDConsts.msgUnaffected, 10, True);
end;

{ Spell 12 (Enlarge): Strength by caster level (18 at level 1, 18/01, 18/51, 18/76, 18/91 and 18/100 at 2 to 6, 19 to 21
  at 7 to 9, 22 at 10 and 11, and 23 at any other level) as the Enlarge effect, when that beats the target's own;
  otherwise the target "is unaffected". }
procedure SpellEnlarge;
var
  newStr: Byte;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  GDVars.gScratchA := 18;
  GDVars.gScratchB := 0;
  case CharHlp.GetCasterLevel(GDVars.spellId) of
    1: GDVars.gScratchB := 0;
    2: GDVars.gScratchB := 1;
    3: GDVars.gScratchB := 51;
    4: GDVars.gScratchB := 76;
    5: GDVars.gScratchB := 91;
    6: GDVars.gScratchB := 100;
    7: GDVars.gScratchA := 19;
    8: GDVars.gScratchA := 20;
    9: GDVars.gScratchA := 21;
    10, 11: GDVars.gScratchA := 22;
  else
    GDVars.gScratchA := 23;
  end;
  if FxEngine.AdjustForNewStrength(tgt, GDVars.gScratchA, GDVars.gScratchB, newStr) then begin
    FxEngine.AddEffectWithMessage(tgt, C_Effect.ENLARGE, Magic.CalcSpellDuration(GDVars.spellId), newStr, 0, 0,
                                  False, GDConsts.msgIs + GDConsts.effectNames[C_Effect.ENLARGE]);
    FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH);
  end else
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + GDConsts.msgUnaffected, 10, True);
end;

{ Casts Reduce: removes Enlarge from the target unless it saves against spells ("has been reduced"). }
procedure SpellReduce;
var
  eff: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  if (tgt <> nil) and (GDVars.castTargetCount > 0) and not FxEngine.RollSavingThrow(tgt, C_Save.SPELL, 0) and
      CharHlp.HasEffect(tgt, C_Effect.ENLARGE, eff) then begin
    FxEngine.RemoveEffect(tgt, C_Effect.ENLARGE, nil);
    FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH);
    CharHlp.PrintCreatureMessage(tgt, 'has been reduced', 10, True);
  end;
end;

{ Casts Friends: the effect with strength 2d4, then the caster's Charisma is recalculated. }
procedure SpellFriends;
var
  { Unused in this version; see the other implementations of this routine. }
  oldCha: Byte;
begin
  Magic.ResolveSpell(GDVars.spellId, FxEngine.RollDice(2, 4), 1, 0, 0, GDConsts.msgIs + GDConsts.effectNames[14]);
  FxEngine.RecalcAbility(GDVars.curChar, C_Stat.CHARISMA);
end;

{ Casts Magic Missile: (caster level + 1) div 2 missiles of 1d4 + 1 magic damage. }
procedure SpellMagicMissile;
var
  lvl: Byte;
begin
  lvl := CharHlp.GetCasterLevel(GDVars.spellId) + 1;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, lvl div 2 + FxEngine.RollDamageDice(lvl div 2, 4), 8, '');
end;

{ Applies Shield's effect to the targets. }
procedure SpellShield;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[17]);
end;

{ Casts Shocking Grasp: 1d8 plus the caster level in electrical damage. }
procedure SpellShockingGrasp;
begin
  GDVars.elemMask := $0C;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(1,
      8) + CharHlp.GetCasterLevel(GDVars.spellId), $0C, '');
end;

{ Casts Sleep with a 4d4 hit-dice pool. Each target costs by its level: 0..1 costs 1, 2 costs 2, 3 costs 4, 4 costs 6, 5
  costs 10 for a creature of the monster race and 20 otherwise, and higher levels cost 20. Animated dead, targets
  already asleep and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target
  order. }
procedure SpellSleep;
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  GDVars.areaTargets := 1;
  GDVars.gScratchA := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.castTargetCount do begin
    case GDVars.castTargets[i]^.highestLevel of
      0..1: GDVars.gScratchB := 1;
      2: GDVars.gScratchB := 2;
      3: GDVars.gScratchB := 4;
      4: GDVars.gScratchB := 6;
      5: if GDVars.castTargets[i]^.race = C_Race.TRIBBLE then
              GDVars.gScratchB := 10
            else
              GDVars.gScratchB := 20;
    else
      GDVars.gScratchB := 20;
    end;
    if (GDVars.castTargets[i]^.status <> C_Status.ANIMATED)
       and not CharHlp.HasEffect(GDVars.castTargets[i], 53, eff)
       and (GDVars.gScratchA >= GDVars.gScratchB) then
      Dec(GDVars.gScratchA, GDVars.gScratchB)
    else
      GDVars.castTargets[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, 'falls ' + GDConsts.effectNames[53]);
end;

{ Hold Person and Hold Monsters: puts the hold effect on up to four targets, with a save modifier by their number: -2 or
  -3 for one, depending on the spell, -1 for two and 0 for three or four. Note: more targets leave the modifier
  undefined. }
procedure SpellHold;
var
  saveMod: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tgt: Pointer;
begin
  case GDVars.castTargetCount of
    1: if GDVars.spellId = 23 then
         saveMod := 254
       else
         saveMod := 253;
    2: saveMod := 255;
    3, 4: saveMod := 0;
  end;
  Magic.ApplyEffectToTargets(saveMod, GDConsts.msgIs + GDConsts.effectNames[52]);
end;

{ Applies Resist Fire's effect to the targets. }
procedure SpellResistFire;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[20]);
end;

{ Applies Silence's effect to the targets. }
procedure SpellSilence;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[21]);
end;

{ Spell 26 (Slow Poison): on a poisoned target, raises 0 hit points to 1, sets it okay and in play, applies the spell
  and re-arms the poison damage for 10. }
procedure SpellSlowPoison;
var
  eff: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  if CharHlp.HasEffect(tgt, C_Effect.POISONED, eff) then begin
    if tgt^.hpCurrent = 0 then
      tgt^.hpCurrent := 1;
    tgt^.status := C_Status.OKAY;
    tgt^.enabled := 1;
    Magic.ResolveSpell(GDVars.spellId, 255, 1, 0, 0, GDConsts.msgIs + GDConsts.msgAffected);
    FxEngine.AddEffect(tgt, C_Effect.SLOW_POISON_HIT, 10, 255, 1);
  end;
end;

{ Casts Snake Charm: charms snakes in play and not yet charmed whose hit points, in total, fit in the caster's current
  hit points. }
procedure SpellSnakeCharm;
var
  cur: Types.PCharRecord;
  eff: Types.PEffectRec;
begin
  GDVars.gScratchA := GDVars.curChar^.hpCurrent;
  GDVars.castTargetCount := 0;
  cur := GDVars.creatureList;
  while cur <> nil do begin
    if ((cur^.creatureTypeFlags and $10) <> 0) and (cur^.enabled <> 0)
       and not CharHlp.HasEffect(cur, 51, eff)
       and (GDVars.gScratchA >= cur^.hpCurrent) then begin
      GDVars.gScratchA := GDVars.gScratchA - cur^.hpCurrent;
      Inc(GDVars.castTargetCount);
      GDVars.castTargets[GDVars.castTargetCount] := cur;
    end;
    cur := cur^.nextCharAddr;
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[11]);
end;

{ Casts Spiritual Hammer: applies the spell's effect, then runs the Spiritual Hammer effect handler for the first
  target. }
procedure SpellSpiritualHammer;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 1, 0, 0, '');
  FxEngine.CallEffectHandler(23, GDVars.castTargets[1], nil, False);
end;

{ Applies the Invisibility spells' effect to the targets. }
procedure SpellInvisibility;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + 'invisible');
end;

{ Applies Knock's effect to the targets. }
procedure SpellKnock;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, 'Knock-Knock');
end;

{ Casts Mirror Image: 1d4 images in the effect strength's high nibble, the caster level in the low one. }
procedure SpellMirrorImage;
var
  lvl: Byte;
begin
  lvl := FxEngine.RollDice(1, 4) * 16;
  lvl := lvl or CharHlp.GetCasterLevel(GDVars.spellId);
  Magic.ResolveSpell(GDVars.spellId, lvl, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[28]);
end;

{ Applies Ray of Enfeeblement's effect to the targets. }
procedure SpellRayOfEnfeeblement;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[29]);
end;

{ Casts Stinking Cloud: a cloud on the four cells around the target cell. A node joins the stinking-cloud list, numbered
  among the caster's clouds and tracked by an effect on the caster; each cell's terrain is saved (for a cell under
  another cloud or a body, the terrain beneath it) and passable cells get the cloud tile. Creatures inside take the
  cloud once each. Note: the count of the caster's clouds skips the list's last node. }
procedure SpellStinkingCloud;
var
  scan: Types.PCloudNode;
  node: Types.PCloudNode;
  dirs: array[1..4] of Byte;
  j: Byte;
  ownCnt: Byte;
  crIdx: Byte;
  lvl: Byte;
  i: Byte;
  k: Byte;
begin
  GDVars.areaTargets := 1;
  lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  ownCnt := 0;
  node := GDVars.stinkHead;
  if GDVars.stinkHead = nil then begin
    New(GDVars.stinkHead);
    node := GDVars.stinkHead;
  end else begin
    while node^.next <> nil do begin
      if node^.owner = GDVars.curChar then
        Inc(ownCnt);
      node := node^.next;
    end;
    New(node^.next);
    node := node^.next;
  end;
  GameIo.FillWord(node^, SizeOf(node^));
  FxEngine.AddEffect(GDVars.curChar, 40, lvl, lvl + ownCnt * 16, 1);
  node^.owner := GDVars.curChar;
  node^.cnt := ownCnt;
  node^.x := GDVars.targetCellX;
  node^.y := GDVars.targetCellY;
  for i := 1 to 4 do begin
    k := GDConsts.cloudDirs[i];
    CbtMap.GetArenaContents(GDVars.targetCellX + GDConsts.dirDx[k], GDVars.targetCellY + GDConsts.dirDy[k], dirs[i],
                            crIdx);
    if (crIdx > 0) and (GDConsts.terrainInfo[crIdx].cost < 255) then
      node^.live[i] := 1
    else
      node^.live[i] := 0;
    if crIdx = 29 then begin
      scan := GDVars.stinkHead;
      while scan <> nil do begin
        if scan <> node then
          for j := 1 to 4 do
            if scan^.live[j] <> 0 then
              if (scan^.x + GDConsts.dirDx[GDConsts.cloudDirs[j]] = GDVars.targetCellX + GDConsts.dirDx[k])
                 and (scan^.y + GDConsts.dirDy[GDConsts.cloudDirs[j]] = GDVars.targetCellY + GDConsts.dirDy[k])
                 and (scan^.saved[j] <> 29) then
                crIdx := scan^.saved[j];
        scan := scan^.next;
      end;
    end else if (crIdx = 30) or (crIdx = 28) then begin
      for j := 1 to GDVars.downedCount do
        if (GDVars.downed[j].x = GDVars.targetCellX + GDConsts.dirDx[k])
           and (GDVars.downed[j].y = GDVars.targetCellY + GDConsts.dirDy[k]) then
          crIdx := GDVars.downed[j].terrain;
    end;
    node^.saved[i] := crIdx;
    if node^.live[i] <> 0 then
      GDVars.arenaPtr^.cells[GDVars.targetCellY + GDConsts.dirDy[k], GDVars.targetCellX + GDConsts.dirDx[k]] := 29;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  for i := 2 to 4 do
    for j := 1 to 4 do
      if (dirs[i] = dirs[j]) and (i <> j) then
        dirs[i] := 0;
  for i := 1 to 4 do
    if dirs[i] > 0 then
      FxEngine.ConsiderTerrainEffects(GDVars.creatures[dirs[i]], 1);
end;

{ Spell 35 (Strength): 1d4 Strength for a magic-user, 1d6 for a cleric or thief, 1d8 for a fighter (the last match
  wins); above 18 a fighter or ranger gets exceptional Strength instead. Applied as the Strength effect when it beats
  the target's own. Note: a target with none of those classes never sets the roll, so it adds whatever the local held. }
procedure SpellStrength;
var
  tgt: Types.PCharRecord;
  pct: Byte;
  hd: Byte;
  base: Byte;
  strEff: Byte;
begin
  pct := 0;
  tgt := GDVars.castTargets[1];
  if (tgt^.classLevelA[C_Class.MAGE] > 0)
     or (tgt^.classLevelB[C_Class.MAGE] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 4);
  if (tgt^.classLevelA[C_Class.CLERIC] > 0)
     or (tgt^.classLevelB[C_Class.CLERIC] > tgt^.dualClassThreshold)
     or (tgt^.classLevelA[C_Class.THIEF] > 0)
     or (tgt^.classLevelB[C_Class.THIEF] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 6);
  if (tgt^.classLevelA[C_Class.FIGHTER] > 0)
     or (tgt^.classLevelB[C_Class.FIGHTER] > tgt^.dualClassThreshold) then
    hd := FxEngine.RollDice(1, 8);
  base := tgt^.stats[C_Stat.STRENGTH].cur + hd;
  if base > Magic.NORMAL_STRENGTH_MAX then
    if (tgt^.classLevelA[C_Class.FIGHTER] > 0)
       or (tgt^.classLevelB[C_Class.FIGHTER] > tgt^.dualClassThreshold)
       or (tgt^.classLevelA[C_Class.RANGER] > 0)
       or (tgt^.classLevelB[C_Class.RANGER] > tgt^.dualClassThreshold) then begin
      pct := tgt^.strExc + (base - Magic.NORMAL_STRENGTH_MAX) * 10;
      if pct > 100 then
        pct := 100;
      base := Magic.NORMAL_STRENGTH_MAX;
    end else
      base := Magic.NORMAL_STRENGTH_MAX;
  if FxEngine.AdjustForNewStrength(tgt, base, pct, strEff) then begin
    strEff := hd + 100;
    FxEngine.AddEffect(tgt, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.spellId), strEff, 1);
    FxEngine.RecalcAbility(tgt, C_Stat.STRENGTH);
  end;
end;

{ Removes the four disease effects from the first spell target, with the effect lock set, recalculating its Strength
  when one was removed.
  @returns(True when one was removed.) }
function RemoveDiseaseEffects: Boolean;
var
  i: Byte;
  found: Boolean;
begin
  GDVars.effectLock := 1;
  RemoveDiseaseEffects := False;
  found := False;
  for i := 1 to 4 do
    if FxEngine.RemoveEffectWithMessage(GDVars.castTargets[1], GDConsts.diseaseFx[i]) then begin
      RemoveDiseaseEffects := True;
      found := True;
    end;
  if found then
    FxEngine.RecalcAbility(GDVars.castTargets[1], C_Stat.STRENGTH);
  GDVars.effectLock := 0;
end;

{ Casts Heal: removes the target's diseases, blindness and feeblemindedness (recalculating Intelligence and Wisdom),
  then heals it to 1d4 below its maximum. Note: a target already within 1d4 of its maximum heals nothing. }
procedure SpellHeal;
var
  tgt: Types.PCharRecord;
  hp: Byte;
begin
  tgt := GDVars.castTargets[1];
  if Magic.RemoveDiseaseEffects then
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + 'cured', 10, False);
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.BLIND) then
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + 'no longer blind', 10, False);
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.FEEBLEMINDED) then begin
    CharHlp.PrintCreatureMessage(tgt, 'regains intellect', 10, False);
    FxEngine.RecalcAbility(tgt, C_Stat.INTELLIGENCE);
    FxEngine.RecalcAbility(tgt, C_Stat.WISDOM);
  end;
  hp := FxEngine.RollDice(1, 4);
  if tgt^.hpCurrent + hp > tgt^.hpMax then
    hp := 0
  else
    hp := tgt^.hpMax - tgt^.hpCurrent - hp;
  if FxEngine.RestoreHitPoints(tgt, hp, 0) then
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + GDConsts.msgHealed, 10, False);
end;

{ Casts Cure Blindness: ends the first target's blindness ('can see'). }
procedure SpellCureBlindness;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.castTargets[1], C_Effect.BLIND) then
    CharHlp.PrintNameStringAnim(GDVars.castTargets[1], 1, 'can see');
end;

{ Spell 38 (Cause Blindness). }
procedure SpellCauseBlindness;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[C_Effect.BLIND]);
end;

{ Casts Cure Disease: removes the first target's disease effects. }
procedure SpellCureDisease;
var
  { Unused in this version; see the other implementations of this routine. }
  removed: Boolean;
begin
  removed := Magic.RemoveDiseaseEffects;
end;

{ Casts Cause Disease, resolving the spell (run on removal) with the Diseased effect's name. }
procedure SpellCauseDisease;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 1, 0, 0, GDConsts.msgIs + GDConsts.effectNames[C_Effect.DISEASED]);
end;

{ Spells 41 and 46 (Dispel Magic): tries each timed effect (strength below 255) of the target, removing it with chance
  50% + 5 per caster level above the effect's level (strength low nibble), - 2 per level below. Then each cloud
  (stinking cloud, cloudkill or delayed blast) on the target cell and the eight around it is dispelled the same way
  against its caster, which loses the matching cloud effect; a cloud that resists is not tried again. Note: each pass of
  the target loop dispels the first target again, so the other targets keep their effects; and a dispelled cloud whose
  caster has no matching effect is removed through nil. }
procedure SpellDispelMagic;
var
  i: Byte;
  lvl: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  matched: Boolean;
  eff: Types.PEffectRec;
  nxt: Types.PEffectRec;
  cx: ShortInt;
  cy: ShortInt;
  terrIdx: Byte;
  crIdx: Byte;
  node: Types.PCloudNode;

  { Rolls whether caster cr's cloud is dispelled, by the caster level against cr's magic-user level. }
  function CloudDispelled(cr: Types.PCharRecord): Boolean;
  begin
    GDVars.gScratchB := cr^.classLevelA[C_Class.MAGE]
                 + cr^.classLevelB[C_Class.MAGE]
                   * Ord(ClassCal.EarlierClassActive(GDVars.curChar));
    if lvl > GDVars.gScratchB then
      GDVars.gScratchA := (lvl - GDVars.gScratchB) * 5 + 50
    else if lvl < GDVars.gScratchB then
      GDVars.gScratchA := 50 - (GDVars.gScratchB - lvl) * 2
    else
      GDVars.gScratchA := 50;
    CloudDispelled := FxEngine.RollDice(1, 100) <= GDVars.gScratchA;
  end;

begin
  GDVars.areaTargets := 1;
  lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  for i := 1 to GDVars.castTargetCount do begin
    removed := False;
    tgt := GDVars.castTargets[1];
    eff := tgt^.effectsAddr;
    while eff <> nil do begin
      nxt := eff^.next;
      if eff^.strength <> 255 then begin
        GDVars.gScratchB := eff^.strength and $F;
        if lvl > GDVars.gScratchB then
          GDVars.gScratchA := (lvl - GDVars.gScratchB) * 5 + 50
        else if lvl < GDVars.gScratchB then
          GDVars.gScratchA := 50 - (GDVars.gScratchB - lvl) * 2
        else
          GDVars.gScratchA := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.gScratchA then begin
          FxEngine.RemoveEffect(tgt, eff^.id, eff);
          removed := True;
        end;
      end;
      eff := nxt;
    end;
    if removed then
      CharHlp.PrintNameStringAnim(tgt, 1, GDConsts.msgIs + GDConsts.msgAffected);
  end;
  for GDVars.loopIdx := 0 to 8 do begin
    case GDVars.loopIdx of
      0: begin
           cx := GDVars.targetCellX;
           cy := GDVars.targetCellY;
         end;
      1: cy := GDVars.targetCellY - 1;
      2: cx := GDVars.targetCellX + 1;
      3: cy := GDVars.targetCellY;
      4: cy := GDVars.targetCellY + 1;
      5: cx := GDVars.targetCellX;
      6: cx := GDVars.targetCellX - 1;
      7: cy := GDVars.targetCellY;
      8: cy := GDVars.targetCellY - 1;
    end;
    CbtMap.GetArenaContents(cx, cy, crIdx, terrIdx);
    crIdx := 0;
    case terrIdx of
      27: begin
             node := GDVars.cloudkillHead;
             crIdx := 9;
           end;
      26: begin
             node := GDVars.blastHead;
             crIdx := 1;
           end;
      29: begin
             node := GDVars.stinkHead;
             crIdx := 4;
           end;
    end;
    if crIdx <> 0 then begin
      while node <> nil do begin
        for i := 1 to crIdx do begin
          if (cx = node^.x + GDConsts.dirDx[GDConsts.cloudDirs[i]])
             and (cy = node^.y + GDConsts.dirDy[GDConsts.cloudDirs[i]])
             and (node^.spent = 0) then
            if CloudDispelled(node^.owner) then begin
              eff := node^.owner^.effectsAddr;
              matched := False;
              while (eff <> nil) and not matched do
                if (((eff^.id = 91) and (terrIdx = 27)) or ((eff^.id = 100) and (terrIdx = 26)) or
                    ((eff^.id = 40) and (terrIdx = 29)))
                   and (eff^.strength div $10 = node^.cnt) then
                  matched := True
                else
                  eff := eff^.next;
              FxEngine.RemoveEffect(node^.owner, eff^.id, eff);
            end else
              node^.spent := 1;
        end;
        node := node^.next;
      end;
      CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 3, C_Dir.CENTER);
    end;
  end;
end;

{ Casts Prayer: the effect with the caster's side in bit 4 and the caster level. }
procedure SpellPrayer;
begin
  Magic.ResolveSpell(GDVars.spellId, GDVars.curChar^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.spellId), 0,
                     0, 0, GDConsts.msgIs + GDConsts.effectNames[49]);
end;

procedure SpellRemoveCurse;
var
  it: Types.PItemRec;
  found: Boolean;
  i: Byte;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.castTargets[1], C_Effect.BESTOW_CURSE) then
    CharHlp.PrintNameStringAnim(GDVars.castTargets[1], 1, GDConsts.msgIs + 'un-cursed')
  else begin
    found := False;
    it := GDVars.castTargets[1]^.itemsAddr;
    while (it <> nil) and not found do begin
      if it^.cursed <> 0 then begin
        found := True;
        it^.curseFlag := 0;
        if it^.scribe[3] > $7F then begin
          GDVars.overrideFlag := 1;
          FxEngine.CallEffectHandler(it^.scribe[3], GDVars.castTargets[1], it, True);
          for i := C_Stat.STRENGTH to C_Stat.CHARISMA do
            FxEngine.RecalcAbility(GDVars.castTargets[1], i);
        end;
      end;
      it := it^.next;
    end;
    if found then
      CharHlp.PrintNameStringAnim(GDVars.castTargets[1], 1, 'has an item un-cursed');
  end;
end;

{ Spell 44 (Bestow Curse): applies its effect ("has been cursed!"). }
procedure SpellBestowCurse;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, 'has been cursed!');
end;

{ Applies Blink's effect to the targets. }
procedure SpellBlink;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[37]);
end;

{ Casts Fireball: caster-level d6 fire damage (the item fireball rolls 3, 5 or 7 d6); outside 3D maps the targets are
  every creature within 2 cells of the target cell. }
procedure SpellFireball;
var
  lvl: Byte;
  i: Byte;
begin
  GDVars.areaTargets := 1;
  if GDVars.spellId = 64 then
    lvl := FxEngine.RollDice(1, 3) * 2 + 1
  else
    lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  if GDVars.zone0^.view3dFlag = 0 then begin
    Pathing.BuildTargetList(GDVars.targetCellX, GDVars.targetCellY, 2, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      GDVars.castTargets[i] := GDVars.creatures[GDVars.targets[i].who];
    GDVars.castTargetCount := GDVars.targetCount;
  end;
  CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 0, C_Dir.CENTER);
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(lvl, 6), 9, '');
end;

{ Resolves Haste or Slow for up to the casting level of targets on one team, dropping the rest. A kept target with the
  opposing effect only loses it; the others take the spell's effect and have their movement and attack-rate effects run
  again.
  @param(effId The opposing effect, Slowed or Hasted.)
  @param(hostileFlag The team to keep: 0 the party's side, 1 the hostiles.)
  @param(msg The effect message.) }
procedure HasteSlowLogic(effId: Byte; hostileFlag: ShortInt; msg: Types.TStr40);
var
  budget: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  affected: Byte;
begin
  GDVars.areaTargets := 1;
  budget := CharHlp.GetCasterLevel(GDVars.spellId);
  for i := 1 to GDVars.castTargetCount do
    if (GDVars.castTargets[i]^.hostile = hostileFlag) and (budget > 0) then begin
      Dec(budget);
      if FxEngine.RemoveEffectWithMessage(GDVars.castTargets[i], effId) then
        GDVars.castTargets[i] := nil;
    end else
      GDVars.castTargets[i] := nil;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, msg);
  for i := 1 to GDVars.castTargetCount do
    if GDVars.castTargets[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(18, GDVars.castTargets[i]);
end;

{ Spell 48 (Haste) on the caster's side; it removes Slow instead where there is one. }
procedure SpellHaste;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile,
                       GDConsts.msgIs + GDConsts.effectNames[C_Effect.HASTED]);
end;

{ Hits the creature on cell (x, y), unless it is in combat slot skipIdx, with electrical damage halved on a save of
  saveType; `blocked` becomes True at an impassable cell of a 3D map unless it already was, and False otherwise.
  @param(x The cell's column.)
  @param(y The cell's row.)
  @param(dmg The electrical damage.)
  @param(saveType The saving-throw type that halves it.)
  @param(skipIdx The combat slot of a creature to skip, or 0.)
  @param(blocked In, whether the bolt was blocked before this cell; out, as described above.) }
procedure LightningAttackAt(x, y: ShortInt; dmg, saveType, skipIdx: Byte; var blocked: Boolean);
var
  cr: Types.PCharRecord;
  crIdx: Byte;
  terrIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hitDamage: Integer;
begin
  CbtMap.GetArenaContents(x, y, crIdx, terrIdx);
  if (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost = 255)
     and (GDVars.zone0^.view3dFlag = 1) and (not blocked) then
    blocked := True
  else
    blocked := False;
  if (crIdx > 0) and (crIdx <> skipIdx) then begin
    cr := GDVars.creatures[crIdx];
    FxEngine.InflictNonWeaponDamage(cr, dmg, 2, FxEngine.RollSavingThrow(cr, saveType, 0));
    CharHlp.BuildIconFacings(19);
  end;
end;

{ Carries a bolt on from the target cell, away from the caster, for the bolt's length in cells, hitting each creature it
  reaches (not the one just hit); at a wall it turns back toward the caster, the first bounce costing 4 more cells when
  the caster is within 4 cells and the bounce flag is set.
  @param(reach The bolt's length in cells.)
  @param(dmg The electrical damage to each creature hit.)
  @param(saveType The saving-throw type that halves it.)
  @param(extendOnBounce True to let the first bounce cost 4 more cells.) }
procedure LightningPath(reach, dmg, saveType: Byte; extendOnBounce: Boolean);
var
  { the outbound walk }
  req: Types.TPathReq;
  { the leg back to the caster }
  back: Types.TPathReq;
  { caster cell }
  srcX: ShortInt;
  srcY: ShortInt;
  { last animated cell }
  prevX: ShortInt;
  prevY: ShortInt;
  { +1 outbound, -1 rebounding }
  dir: ShortInt;
  { LightningAttackAt's var parameter }
  bounced: Boolean;
  { NextPathStep's result }
  more: Boolean;
  { one-shot copy of the arg }
  extend: Boolean;
  { creature already hit }
  lastCr: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  { half-cells of travel left }
  budget: Byte;
  { distance at the last check }
  walked: Byte;
begin
  bounced := False;
  CharHlp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.targetCellX, GDVars.targetCellY, lastCr, terrIdx);
  walked := 0;
  dir := 1;
  srcX := CbtMap.CombatCellX(GDVars.curChar);
  srcY := CbtMap.CombatCellY(GDVars.curChar);
  extend := extendOnBounce;
  if (srcX = GDVars.targetCellX) and (srcY = GDVars.targetCellY) then
    Exit;
  budget := reach * 2;
  GDVars.areaTargets := 1;
  while budget > 0 do begin
    GameIo.FillWord(req, SizeOf(req));
    req.sx := GDVars.targetCellX;
    req.sy := GDVars.targetCellY;
    req.ex := GDVars.targetCellX + (GDVars.targetCellX - srcX) * dir * budget;
    req.ey := GDVars.targetCellY + (GDVars.targetCellY - srcY) * dir * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then
        repeat
          more := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terrIdx);
            { terrIdx is 0 once the walk leaves the arena, and this read is not guarded; it reads before the start of
              terrainInfo, and LightningAttackAt's own terrIdx > 0 test makes the result moot. }
          if GDConsts.terrainInfo[terrIdx].cost = 1 then
            bounced := False;
        until (not more) or ((crIdx > 0) and (crIdx <> lastCr))
              or (terrIdx = 0) or (GDConsts.terrainInfo[terrIdx].cost > 1)
              or (req.dist >= budget);
      if terrIdx = 0 then
        budget := 0;
      CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
      Magic.LightningAttackAt(req.cx, req.cy, dmg, saveType, lastCr, bounced);
      lastCr := crIdx;
      if bounced then begin
        GDVars.targetCellX := req.cx;
        GDVars.targetCellY := req.cy;
        GameIo.FillWord(back, SizeOf(back));
        back.sx := GDVars.targetCellX;
        back.sy := GDVars.targetCellY;
        back.ex := srcX;
        back.ey := srcY;
        Pathing.PathFind(back);
        while Pathing.NextPathStep(back) do
          ;
        if extend and (back.dist <= 8) then
          Inc(req.dist, 8);
        dir := 0 - dir;
        extend := False;
        lastCr := 0;
      end;
      walked := req.dist - walked;
      if walked < budget then
        Dec(budget, walked)
      else
        budget := 0;
      walked := req.dist;
    until bounced or (budget = 0);
  end;
  GDVars.areaTargets := 0;
end;

{ Casts Lightning Bolt: caster-level d6 electrical damage at the target cell, carried on as a 7-cell bolt that can
  bounce. }
procedure SpellLightningBolt;
var
  dmg: Byte;
  { LightningAttackAt's var argument }
  ok: Boolean;
begin
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.spellId), 6);
  GDVars.elemMask := $0C;
  Magic.LightningAttackAt(GDVars.targetCellX, GDVars.targetCellY, dmg, C_Save.SPELL, 0, ok);
  Magic.LightningPath(7, dmg, C_Save.SPELL, True);
end;

{ Spell 55 (Slow) on the other side; it removes Haste instead where there is one. }
procedure SpellSlow;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, CharHlp.EnemyTeam(GDVars.curChar),
                       GDConsts.msgIs + GDConsts.effectNames[C_Effect.SLOWED]);
end;

{ Casts Harm: diseases the target and leaves it 1d4 hit points. }
procedure SpellHarm;
var
  cr: Types.PCharRecord;
begin
  cr := GDVars.castTargets[1];
  GDVars.elemMask := 8;
  FxEngine.AddEffectWithMessage(cr, C_Effect.DISEASED, 0, 0, 0, 0, False, '');
  CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + GDConsts.effectNames[C_Effect.DISEASED], 10, True);
  FxEngine.InflictNonWeaponDamage(cr, cr^.hpCurrent - FxEngine.RollDice(1, 4), 0, False);
end;

{ Removes Slow from the target, or else applies the Potion of Speed's effect. }
procedure SpellPotionOfSpeed;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.castTargets[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[C_Effect.HASTED]);
end;

{ Casts Cure Serious Wounds: heals the target 2d8 + 1. }
procedure SpellCureSeriousWounds;
begin
  if GDVars.castTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(2, 8) + 1, 0) then
    CharHlp.AnnounceHealStatus(GDVars.castTargets[1]);
end;

{ Gives the target frost giant strength: Strength 21 for 1d4 * 10 + 40, announced when that beats the target's own; the
  effect is added either way. }
procedure SpellGiantStrength;
var
  newStr: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldStrength: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.castTargets[1], 21, 0, newStr) then
    CharHlp.PrintCreatureMessage(GDVars.castTargets[1], GDConsts.msgGains + GDConsts.effectNames[113], 10, True);
  FxEngine.AddEffect(GDVars.castTargets[1], 113, FxEngine.RollDice(1, 4) * 10 + 40, newStr, 1);
  FxEngine.RecalcAbility(GDVars.castTargets[1], C_Stat.STRENGTH);
end;

{ Spell 60 (javelin of lightning): 1d6 + 20 electrical damage at the target cell, then a 3-cell bolt of 20 that does not
  bounce. }
procedure SpellJavelinOfLightning;
var
  ok: Boolean;
begin
  GDVars.elemMask := 4;
  Magic.LightningAttackAt(GDVars.targetCellX, GDVars.targetCellY, FxEngine.RollDice(1, 6) + 20, C_Save.SPELL, 0, ok);
  Magic.LightningPath(3, 20, C_Save.SPELL, False);
end;

{ Applies the Wand of Paralyzation's effect to the targets ("is paralyzed"). }
procedure SpellWandOfParalyzation;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + 'paralyzed');
end;

{ Heals the first target 2d4 + 2 hit points for the Potion of Healing. }
procedure SpellPotionOfHealing;
begin
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(2, 4) + 2, 0) then
    CharHlp.PrintNameStringAnim(GDVars.castTargets[1], 1, GDConsts.msgIs + GDConsts.msgHealed);
end;

{ Spell 63 (potion of youth): the target becomes 1d4 + 1 years younger, but no younger than 18. }
procedure SpellYouth;
var
  cr: Types.PCharRecord;
begin
  cr := GDVars.castTargets[1];
  cr^.age := cr^.age - (FxEngine.RollDice(1, 4) + 1);
  if cr^.age < 18 then begin
    cr^.age := 18;
    CharHlp.PrintCreatureMessage(cr, 'is now 18 years old', 10, True);
  end else
    CharHlp.PrintCreatureMessage(cr, 'becomes younger', 10, True);
end;

{ Deals the Wand of Magic Missiles' 2d4 + 2 magic damage. }
procedure SpellWandOfMagicMissiles;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(2, 4) + 2, 8, '');
end;

{ Casts Cause Serious Wounds: deals 2d8 + 1 magic damage. }
procedure SpellCauseSeriousWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(2, 8) + 1, 8, '');
end;

{ Spell 67 (Neutralize Poison): cures the poison of a target that is not animated (Poisoned and Slow Poison removed),
  raising 0 hit points to 1 and setting it okay; an unpoisoned target "is unaffected". }
procedure SpellNeutralizePoison;
var
  cr: Types.PCharRecord;
  { HasEffect var parameter }
  e: Types.PEffectRec;
begin
  cr := GDVars.castTargets[1];
  if cr^.status = C_Status.ANIMATED then
    GDVars.castTargets[1] := nil
  else if CharHlp.HasEffect(cr, C_Effect.POISONED, e) then begin
    if cr^.hpCurrent = 0 then
      cr^.hpCurrent := 1;
    FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
    FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_END, nil);
    FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + 'unpoisoned', 10, True);
    cr^.enabled := 1;
    cr^.status := C_Status.OKAY;
  end else
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + 'unaffected', 10, True);
end;

{ Casts Poison: applies the spell, then, unless the effects of the caster's target cancel the poison attack, runs the
  poison attack's handler (a poison bite) for the caster. }
procedure SpellPoison;
var
  { never written; read once }
  handlerArg: Pointer;
  who: Types.PCharRecord;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 8, '');
  who := GDVars.curChar^.combatAddr^.otherV2;
  GDVars.currentEffectId := 64;
  FxEngine.TriggerEffectsWithCondition(9, who);
  if GDVars.currentEffectId = 64 then
    FxEngine.CallEffectHandler(64, GDVars.curChar, handlerArg, False);
end;

{ Spell 70 (Sticks to Snakes): a target below level 6 fights snakes (effect 3, strength the caster level); a stronger
  one "smashes them flat". }
procedure SpellSticksToSnakes;
var
  { HasEffect var parameter }
  e: Types.PEffectRec;
begin
  if GDVars.castTargets[1]^.highestLevel < 6 then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'turns sticks into snakes', 10, True);
    Magic.ResolveSpell(GDVars.spellId, CharHlp.GetCasterLevel(GDVars.spellId), 0, 0, 8, '');
    if CharHlp.HasEffect(GDVars.castTargets[1], 3, e) then
      FxEngine.CallEffectHandler(3, GDVars.castTargets[1], e, False);
  end else
    CharHlp.PrintCreatureMessage(GDVars.castTargets[1], 'smashes them flat', 10, True);
end;

{ Casts Cure Critical Wounds: heals the target 3d8 + 3. }
procedure SpellCureCriticalWounds;
begin
  if GDVars.castTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(3, 8) + 3, 0) then
    CharHlp.AnnounceHealStatus(GDVars.castTargets[1]);
end;

{ Casts Cause Critical Wounds: deals 3d8 + 3 magic damage. }
procedure SpellCauseCriticalWounds;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(3, 8) + 3, 8, '');
end;

{ Spell 73 (Dispel Evil): gives the caster effect 4 for the spell's duration, then applies the spell ("is affected"). }
procedure SpellDispelEvil;
var
  { Unused in this version; see the other implementations of this routine. }
  durText: array[1..5] of Byte;
begin
  GDVars.areaTargets := 0;
  GDVars.elemMask := $40;
  FxEngine.AddEffectWithMessage(GDVars.curChar, 4, Magic.CalcSpellDuration(73), 0, 0, 0, False, '');
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgAffected);
end;

{ Casts Flame Strike: deals 6d8 fire damage. }
procedure SpellFlameStrike;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(6, 8), 9, '');
end;

{ Spell 75 (Raise Dead): raises a dead or animated target that is not an elf and has Constitution left: its poison is
  removed, it becomes okay with 1 hit point and loses a point of base Constitution ("is raised"). }
procedure SpellRaiseDead;
var
  cr: Types.PCharRecord;
begin
  cr := GDVars.castTargets[1];
  if ((cr^.status = C_Status.DEAD_STATUS) or (cr^.status = C_Status.ANIMATED)) and
      (cr^.stats[C_Stat.CONSTITUTION].base > 0) and (cr^.race <> C_Race.ELF) then begin
    FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
    cr^.status := C_Status.OKAY;
    cr^.enabled := 1;
    Dec(cr^.stats[C_Stat.CONSTITUTION].base);
    FxEngine.RecalcAbility(cr, C_Stat.CONSTITUTION);
    cr^.hpCurrent := 1;
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + 'raised', 10, True);
  end;
end;

{ Spell 76 (Slay Living): unless the target's effects cancel it or the target has target flag 8 ("is unaffected"), slays
  the target on a failed save and deals 2d8 + 1 magic damage otherwise. }
procedure SpellSlayLiving;
var
  cr: Types.PCharRecord;
begin
  cr := GDVars.castTargets[1];
  GDVars.elemMask := $40;
  GDVars.pendingDamage := 255;
  FxEngine.TriggerEffectsWithCondition(9, cr);
  if (cr^.targetFlags and 8) <> 0 then
    GDVars.pendingDamage := 0;
  if GDVars.pendingDamage <> 0 then begin
    if not FxEngine.RollSavingThrow(cr, C_Save.SPELL, 0) then
      FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, GDConsts.msgIs + 'slain')
    else begin
      GDVars.elemMask := 8;
      FxEngine.InflictNonWeaponDamage(cr, FxEngine.RollDamageDice(2, 8) + 1, 0, False);
    end;
  end else
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + GDConsts.msgUnaffected, 10, True);
end;

{ Spell 78 (Entangle): does nothing in this game. }
procedure SpellEntangle;
var
  { Unused in this version; see the other implementations of this routine. }
  tgt: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  saved: Boolean;
begin
end;

{ Spell 79 (Faerie Fire): ApplyEffectToTargets with no modifier. }
procedure SpellFaerieFire;
begin
  Magic.ApplyEffectToTargets(0, GDConsts.msgIs + GDConsts.effectNames[71]);
end;

{ Spell 80 (Invisibility to Animals). }
procedure SpellInvisibilityToAnimals;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[C_Effect.INVISIBLE]);
end;

{ Casts Charm Monsters: ApplyEffectToTargets ("is charmed"), then the charm handler for each charmed target. }
procedure SpellCharmMonsters;
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  charmCount: array[1..2] of Byte;
  { HasEffect var parameter }
  e: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  charmInfo: array[1..3] of Byte;
begin
  Magic.ApplyEffectToTargets(0, GDConsts.msgIs + GDConsts.effectNames[11]);
  for i := 1 to GDVars.castTargetCount do
    if CharHlp.HasEffect(GDVars.castTargets[i], 11, e) then
      FxEngine.CallEffectHandler(11, GDVars.castTargets[i], e, False);
end;

{ Casts Confusion: up to 2d8 targets save (type 4) or are confused. }
procedure SpellConfusion;
var
  i: Byte;
  saved: Boolean;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  eff: array[1..4] of Byte;
  n: Byte;
begin
  n := FxEngine.RollDice(2, 8);
  if GDVars.castTargetCount > n then
    GDVars.castTargetCount := n;
  for i := 1 to GDVars.castTargetCount do
    if GDVars.castTargets[i] <> nil then begin
      cr := GDVars.castTargets[i];
      saved := FxEngine.RollSavingThrow(cr, C_Save.SPELL, 0);
      FxEngine.AddEffectWithMessage(cr, 35, Magic.CalcSpellDuration(82), 0, 0, 1, saved,
                                    GDConsts.msgIs + GDConsts.effectNames[35]);
    end;
end;

{ Casts Dimension Door: erases the caster's icon, places it on the target cell, scrolls the view to it and reports
  "teleports". Note: the placement's result is ignored. }
procedure SpellDimensionDoor;
var
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  target: array[1..4] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  landed: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
begin
  cr := GDVars.curChar;
  CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(cr));
  landed := CbtMap.IsValidCreatureLoc(cr, GDVars.targetCellX, GDVars.targetCellY, False);
  CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, C_Dir.CENTER);
  CharHlp.PrintCreatureMessage(cr, 'teleports', 10, True);
end;

{ Spell 84 (Fear): a 3-ray cone of 6 cells; each target saves against spells or runs in terror (effect 111), fleeing as
  a quick fighter with no target (a player character becomes NPC $B3). }
procedure SpellFear;
var
  cr: Types.PCharRecord;
  tgt: Types.PCharRecord;
  i: Byte;
  saved: Boolean;
begin
  cr := GDVars.curChar;
  Magic.CollectConeTargets(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), GDVars.targetCellX, GDVars.targetCellY, 3,
                           6);
  for i := 1 to GDVars.castTargetCount do begin
    tgt := GDVars.castTargets[i];
    saved := FxEngine.RollSavingThrow(tgt, C_Save.SPELL, 0);
    if not saved then begin
      FxEngine.AddEffectWithMessage(tgt, 111, Magic.CalcSpellDuration(84), 0, 1, 1, saved, 'flees in terror');
      tgt^.combatAddr^.forcedFleeV1 := 1;
      tgt^.quickfight := 1;
      if tgt^.npc <= $7F then
        tgt^.npc := $B3;
      tgt^.combatAddr^.otherV2 := nil;
    end else
      CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + GDConsts.msgUnaffected, 10, True);
  end;
end;

{ Spell 85 (Fire Shield): asks for hot or cold flames (random for a quick fighter): hot gives the caster effects 50 and
  112, cold 54 and 112; any other answer offers to abort. }
procedure SpellFireShield;
var
  ch: Char;
  sel: Boolean;
  done: Boolean;
begin
  done := False;
  repeat
    if GDVars.curChar^.quickfight <> 0 then begin
      if FxEngine.RollDice(1, 10) > 5 then
        ch := 'H'
      else
        ch := 'C';
    end else
      ch := MenuCore.MenuHorizontal('flame type: ', 'Hot Cold', LightMagenta, LightGreen, White, 0, 0, sel);
    case ch of
      'H':
        begin
          FxEngine.AddEffectWithMessage(GDVars.curChar, 50, Magic.CalcSpellDuration(85), 0, 0, 0, False,
                                        GDConsts.msgIs + 'protected');
          FxEngine.AddEffectWithMessage(GDVars.curChar, 112, Magic.CalcSpellDuration(85), 0, 0, 0, False, '');
          done := True;
        end;
      'C':
        begin
          FxEngine.AddEffectWithMessage(GDVars.curChar, 54, Magic.CalcSpellDuration(85), 0, 0, 0, False, '');
          FxEngine.AddEffectWithMessage(GDVars.curChar, 112, Magic.CalcSpellDuration(85), 0, 0, 0, False, '');
          done := True;
        end;
    else begin
        ch := MenuCore.MenuHorizontal('Abort spell? ', 'Yes No', LightMagenta, LightGreen, White, 0, 0, sel);
        if ch = 'Y' then
          done := True;
      end;
    end;
  until done;
end;

{ Casts Fumble: a first target that fails a save (type 4) becomes clumsy ('is clumsy'), one that saves is slowed ('is
  slowed'), each effect with its handler run; then the spell's table effect is resolved on the targets as well ('is
  clumsy'). }
procedure SpellFumble;
var
  cr: Types.PCharRecord;
  eff: Types.PEffectRec;
begin
  cr := GDVars.castTargets[1];
  GDVars.elemMask := $40;
  if not FxEngine.RollSavingThrow(cr, C_Save.SPELL, 0) then begin
    FxEngine.AddEffectWithMessage(cr, 27, Magic.CalcSpellDuration(86), 0, 0, 0, False,
                                  GDConsts.msgIs + GDConsts.effectNames[27]);
    if CharHlp.HasEffect(cr, 27, eff) then
      FxEngine.CallEffectHandler(27, cr, nil, False);
  end else begin
    FxEngine.AddEffectWithMessage(cr, C_Effect.SLOWED, Magic.CalcSpellDuration(86), 0, 0, 0, False,
                                  GDConsts.msgIs + GDConsts.effectNames[C_Effect.SLOWED]);
    if CharHlp.HasEffect(cr, C_Effect.SLOWED, eff) then
      FxEngine.CallEffectHandler(C_Effect.SLOWED, cr, nil, False);
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, 1, 0, 0, GDConsts.msgIs + 'clumsy');
end;

{ Casts Ice Storm: deals 3d10 cold damage. }
procedure SpellIceStorm;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, FxEngine.RollDamageDice(3, 10), $0A, '');
end;

{ Casts Minor Globe of Invulnerability: applies its effect to the targets. }
procedure SpellMinorGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgProtected);
end;

{ Does nothing. }
procedure NoopMagic;
begin
end;

{ Spell 91 (Cloud Kill): a poisonous cloud on the target cell and the eight around it given by cloudDirs9, tracked like
  a stinking cloud (the cloudkill list and effect 91 on the caster); creatures inside take the cloud. Note: the count of
  the caster's clouds skips the list's last node. }
procedure SpellCloudkill;
var
  scan: Types.PCloudNode;
  node: Types.PCloudNode;
  dirs: array[1..9] of Byte;
  j: Byte;
  ownCnt: Byte;
  crIdx: Byte;
  lvl: Byte;
  i: Byte;
  k: Byte;
  matched: Boolean;
begin
  GDVars.areaTargets := 1;
  lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  ownCnt := 0;
  node := GDVars.cloudkillHead;
  if GDVars.cloudkillHead = nil then begin
    New(GDVars.cloudkillHead);
    node := GDVars.cloudkillHead;
  end else begin
    while node^.next <> nil do begin
      if node^.owner = GDVars.curChar then
        Inc(ownCnt);
      node := node^.next;
    end;
    New(node^.next);
    node := node^.next;
  end;
  GameIo.FillWord(node^, SizeOf(node^));
  FxEngine.AddEffect(GDVars.curChar, 91, lvl, lvl + ownCnt * 16, 1);
  node^.owner := GDVars.curChar;
  node^.cnt := ownCnt;
  node^.x := GDVars.targetCellX;
  node^.y := GDVars.targetCellY;
  for i := 1 to 9 do begin
    k := GDConsts.cloudDirs9[i];
    CbtMap.GetArenaContents(GDVars.targetCellX + GDConsts.dirDx[k], GDVars.targetCellY + GDConsts.dirDy[k], dirs[i],
                            crIdx);
    if (crIdx > 0) and (GDConsts.terrainInfo[crIdx].cost < 255) then
      node^.live[i] := 1
    else
      node^.live[i] := 0;
    case crIdx of
      29:
        begin
          scan := GDVars.stinkHead;
          matched := False;
          while (scan <> nil) and not matched do begin
            for j := 1 to 4 do
              if (scan^.live[j] <> 0)
                 and (scan^.x + GDConsts.dirDx[GDConsts.cloudDirs[j]] = GDVars.targetCellX + GDConsts.dirDx[k])
                 and (scan^.y + GDConsts.dirDy[GDConsts.cloudDirs[j]] = GDVars.targetCellY + GDConsts.dirDy[k])
                 and (scan^.saved[j] <> 29) and (scan^.saved[j] <> 27) then begin
                crIdx := scan^.saved[j];
                matched := True;
              end;
            scan := scan^.next;
          end;
        end;
      27:
        begin
          scan := GDVars.cloudkillHead;
          matched := False;
          while (scan <> nil) and not matched do begin
            if scan <> node then
              for j := 1 to 9 do
                if (scan^.live[j] <> 0)
                   and (scan^.x + GDConsts.dirDx[GDConsts.cloudDirs9[j]] = GDVars.targetCellX + GDConsts.dirDx[k])
                   and (scan^.y + GDConsts.dirDy[GDConsts.cloudDirs9[j]] = GDVars.targetCellY + GDConsts.dirDy[k])
                   and (scan^.saved[j] <> 29) and (scan^.saved[j] <> 27) then begin
                  crIdx := scan^.saved[j];
                  matched := True;
                end;
            scan := scan^.next;
          end;
        end;
      28, 30:
        begin
          for j := 1 to GDVars.downedCount do
            if (GDVars.downed[j].x = GDVars.targetCellX + GDConsts.dirDx[k])
               and (GDVars.downed[j].y = GDVars.targetCellY + GDConsts.dirDy[k]) then
              crIdx := GDVars.downed[j].terrain;
        end;
    end;
    node^.saved[i] := crIdx;
    if node^.live[i] <> 0 then
      GDVars.arenaPtr^.cells[GDVars.targetCellY + GDConsts.dirDy[k], GDVars.targetCellX + GDConsts.dirDx[k]] := 27;
  end;
  node^.saved[i] := crIdx;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'Creates a poisonous cloud', 10, False);
  CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
  for i := 1 to 9 do
    if dirs[i] > 0 then
      FxEngine.ConsiderTerrainEffects(GDVars.creatures[dirs[i]], 1);
end;

{ Casts Cone of Cold: a cone of 2 rays toward the target cell, reaching (caster level + 1) div 2 cells, at least 1,
  deals caster level + caster-level d4 cold damage. }
procedure SpellConeOfCold;
var
  cr: Types.PCharRecord;
  half: Byte;
  lvl: Byte;
begin
  cr := GDVars.curChar;
  lvl := CharHlp.GetCasterLevel(GDVars.spellId);
  half := (CharHlp.GetCasterLevel(GDVars.spellId) + 1) div 2;
  if half < 1 then
    half := 1;
  Magic.CollectConeTargets(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), GDVars.targetCellX, GDVars.targetCellY, 2,
                           half);
  Magic.ResolveSpell(GDVars.spellId, 0, 0, lvl + FxEngine.RollDamageDice(lvl, 4), $0A, '');
end;

{ Spell 93 (Feeblemind): applies the spell with the target's saving throw against spells changed by class while it rolls
  (clerics -1, rangers +1 at level 8 and +2 above, paladins +4 from level 9, magic-users +4 for a human and +2
  otherwise, other multi-class magic-users +2; other classes are not affected), then runs the feeblemind handler when
  the target has the effect, or reports "is unaffected". Note: the cleric arm never sets whether the spell applies, so
  that is undefined. }
procedure SpellFeeblemind;
var
  saved: Byte;
  cr: Types.PCharRecord;
  hit: Boolean;
  eff: Types.PEffectRec;
begin
  cr := GDVars.castTargets[1];
  saved := cr^.saves[C_Save.SPELL];
  case cr^.charClass of
    C_Class.CLERIC, C_Class.CLERIC_FIGHTER, C_Class.CLERIC_THIEF:
      Dec(cr^.saves[C_Save.SPELL]);
    C_Class.RANGER:
      begin
        if cr^.highestLevel = 8 then
          Inc(cr^.saves[C_Save.SPELL]);
        if cr^.highestLevel >= 9 then
          Inc(cr^.saves[C_Save.SPELL], 2);
        hit := True;
      end;
    C_Class.PALADIN:
      begin
        if cr^.highestLevel >= 9 then
          Inc(cr^.saves[C_Save.SPELL], 4);
        hit := True;
      end;
    C_Class.MAGE, C_Class.FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF:
      begin
        if cr^.race = C_Race.HUMAN then
          Inc(cr^.saves[C_Save.SPELL], 4)
        else
          Inc(cr^.saves[C_Save.SPELL], 2);
        hit := True;
      end;
    C_Class.CLERIC_FIGHTER_MAGE, C_Class.CLERIC_RANGER, C_Class.CLERIC_MAGE,
      C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF:
      begin
        Inc(cr^.saves[C_Save.SPELL], 2);
        hit := True;
      end;
  else
    hit := False;
  end;
  if hit then
    Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, '');
  if CharHlp.HasEffect(cr, C_Effect.FEEBLEMINDED, eff) then
    FxEngine.CallEffectHandler(C_Effect.FEEBLEMINDED, cr, nil, False)
  else
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + 'unaffected', 10, True);
  cr^.saves[C_Save.SPELL] := saved;
end;

{ Spell 95: applies its effect ("is protected"). }
procedure SpellImmuneBreath;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgProtected);
end;

{ Casts Charm Person or Mammal: charms the target when it is a person (a race below monster) or a creature of type bit
  2, then runs the charm's handler; the charm's strength holds the caster's team in bit 7 and the caster level. Any
  other target is not charmed. }
procedure SpellCharmPersonOrMammal;
var
  { HasEffect var parameter }
  eff: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  if tgt = nil then
    Exit;
  if (tgt^.race < C_Race.MONSTER) or ((tgt^.creatureTypeFlags and 2) <> 0) then begin
    Magic.ResolveSpell(GDVars.spellId, GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.spellId),
                       1, 0, 0,
                        GDConsts.msgIs + GDConsts.effectNames[11]);
    if CharHlp.HasEffect(tgt, 11, eff) then
      FxEngine.CallEffectHandler(11, tgt, eff, False);
  end else
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + 'not ' + GDConsts.effectNames[11], 10, True);
end;

{ Casts the invisibility spell by applying its effect. }
procedure SpellTurnInvisible;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, '');
end;

{ Casts Cure Light Wounds: heals the target 1d8. }
procedure SpellDruidCureLightWounds;
begin
  if GDVars.castTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(1, 8), 0) then
    CharHlp.AnnounceHealStatus(GDVars.castTargets[1]);
end;

{ Spell 99: heals the target 2d4 + 2. }
procedure SpellHealSelf;
begin
  if FxEngine.RestoreHitPoints(GDVars.castTargets[1], FxEngine.RollDice(2, 4) + 2, 0) then
    CharHlp.PrintNameStringAnim(GDVars.castTargets[1], 1, GDConsts.msgIs + GDConsts.msgHealed);
end;

{ Casts Bestow Curse: applies its effect. }
procedure SpellMageBestowCurse;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, '');
end;

{ Casts Death Spell: spends a budget of 4d20 * 2 on the targets in list order, each costing 1, 2, 8, 16 or 20 by its
  highest level (at level 6, 20 above 51 maximum hit points; above level 8, 162). A target the budget covers drops dead;
  an immune target, or one the budget cannot cover, leaves the list. }
procedure SpellDeathSpell;
var
  tgt: Types.PCharRecord;
  i: Byte;
begin
  GDVars.areaTargets := 1;
  GDVars.elemMask := $40;
  GDVars.gScratchA := FxEngine.RollDice(4, 20) * 2;
  for i := 1 to GDVars.castTargetCount do begin
    tgt := GDVars.castTargets[i];
    case tgt^.highestLevel of
      0: GDVars.gScratchB := 1;
      1: GDVars.gScratchB := 2;
      2..3: GDVars.gScratchB := 8;
      4..5: GDVars.gScratchB := 16;
      6: if tgt^.hpMax <= 51 then
              GDVars.gScratchB := 16
            else
              GDVars.gScratchB := 20;
      7..8: GDVars.gScratchB := 20;
    else
      GDVars.gScratchB := 162;
    end;
    if ((tgt^.targetFlags and 8) = 0) and (GDVars.gScratchA >= GDVars.gScratchB) then begin
      Dec(GDVars.gScratchA, GDVars.gScratchB);
      FxEngine.KillCreature(tgt, C_Status.DEAD_STATUS, 'drops dead');
    end else
      GDVars.castTargets[i] := nil;
  end;
end;

{ Casts Disintegrate: unless the target's effects cancel it, the target disintegrates on a failed save against spells. }
procedure SpellDisintegrate;
var
  saved: Boolean;
  tgt: Types.PCharRecord;
begin
  GDVars.elemMask := $40;
  tgt := GDVars.castTargets[1];
  GDVars.pendingDamage := 255;
  FxEngine.TriggerEffectsWithCondition(9, tgt);
  if GDVars.pendingDamage <> 0 then begin
    saved := FxEngine.RollSavingThrow(tgt, C_Save.SPELL, 0);
    if not saved then
      FxEngine.KillCreature(tgt, C_Status.DEAD_STATUS, 'disintegrates');
  end;
end;

{ Casts Globe of Invulnerability: applies its effect, protecting the targets. }
procedure SpellGlobeOfInvulnerability;
begin
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.msgProtected);
end;

{ Spell 113 (Stone to Flesh): a petrified target becomes okay with 1 hit point ("is no longer a statue"); in camp any
  other target asks whether to cast anyway; then the spell's effect applies. Note: the answer is tested against 'y',
  which PromptCastAnyway never returns. }
procedure SpellStoneToFlesh;
var
  tgt: Types.PCharRecord;
  ch: Char;
begin
  tgt := GDVars.castTargets[1];
  if tgt^.status = C_Status.PETRIFIED then begin
    tgt^.status := C_Status.OKAY;
    tgt^.enabled := 1;
    tgt^.hpCurrent := 1;
    CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + 'no longer a statue', 10, False);
  end else if GDVars.interfaceState = C_Ifc.CAMPING then begin
    ch := Magic.PromptCastAnyway(tgt, GDConsts.msgIs + 'not stoned.');
    if ch = 'y' then
      CharHlp.PrintCreatureMessage(tgt, GDConsts.msgIs + GDConsts.msgUnaffected, 10, False);
  end;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, '');
end;

{ Casts Flesh to Stone: unless the target's effects cancel it, the target turns to stone on a failed save against
  spells. }
procedure SpellFleshToStone;
var
  saved: Boolean;
  tgt: Types.PCharRecord;
begin
  GDVars.elemMask := $40;
  tgt := GDVars.castTargets[1];
  GDVars.pendingDamage := 255;
  FxEngine.TriggerEffectsWithCondition(9, tgt);
  if GDVars.pendingDamage <> 0 then begin
    saved := FxEngine.RollSavingThrow(tgt, C_Save.SPELL, 0);
    if not saved then
      FxEngine.KillCreature(tgt, C_Status.PETRIFIED, GDConsts.msgIs + 'turned to stone');
  end;
end;

{ Spell 115 (Delayed Blast Fireball): asks for a delay of 1 to 50 segments, rounded to tens; with none, caster level +
  caster-level d6 fire damage at once; otherwise a delayed blast is set on the target cell (the blast list and effect
  100 on the caster for the delay), which gets the blast tile when passable. }
procedure SpellDelayedBlastFireball;
var
  scan: Types.PCloudNode;
  node: Types.PCloudNode;
  dirs: Byte;
  { Unused in this version; see the other implementations of this routine. }
  terrIdx: Byte;
  ownCnt: Byte;
  crIdx: Byte;
  lvl: Byte;
  matched: Boolean;
  blastDelay: Word;
begin
  GDVars.areaTargets := 1;
  lvl := CharHlp.GetCasterLevel(115);
  blastDelay := Money.InputNumberMax(50, 'Blast Delay in segments (1-50)? ', LightGreen);
  blastDelay := (blastDelay + 5) div 10;
  if blastDelay = 0 then
    Magic.ResolveSpell(115, 0, 0, lvl + FxEngine.RollDamageDice(lvl, 6), 9, '')
  else begin
    ownCnt := 0;
    node := GDVars.blastHead;
    if GDVars.blastHead = nil then begin
      New(GDVars.blastHead);
      node := GDVars.blastHead;
    end else begin
      while node^.next <> nil do begin
        if node^.owner = GDVars.curChar then
          Inc(ownCnt);
        node := node^.next;
      end;
      New(node^.next);
      node := node^.next;
    end;
    GameIo.FillWord(node^, SizeOf(node^));
    node^.owner := GDVars.curChar;
    node^.cnt := ownCnt;
    node^.x := GDVars.targetCellX;
    node^.y := GDVars.targetCellY;
    FxEngine.AddEffect(GDVars.curChar, 100, blastDelay, lvl + ownCnt * 16, 1);
    CbtMap.GetArenaContents(GDVars.targetCellX, GDVars.targetCellY, dirs, crIdx);
    if (crIdx > 0) and (GDConsts.terrainInfo[crIdx].cost < 255) then
      node^.live[1] := 1
    else
      node^.live[1] := 0;
    scan := GDVars.blastHead;
    matched := False;
    while (scan <> nil) and not matched do begin
      if scan <> node then begin
        crIdx := scan^.saved[1];
        if (scan^.live[1] <> 0)
           and (scan^.x = GDVars.targetCellX) and (scan^.y = GDVars.targetCellY)
           and (crIdx <> 29) and (crIdx <> 27) and (crIdx <> 26) then
          matched := True;
      end;
      scan := scan^.next;
    end;
    node^.saved[1] := crIdx;
    if node^.live[1] <> 0 then
      GDVars.arenaPtr^.cells[GDVars.targetCellY, GDVars.targetCellX] := 26;
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'Sets a delayed blast fireball.', 10, False);
    CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 255, C_Dir.CENTER);
  end;
end;

{ Casts Mass Invisibility on the caster's side, in combat passing over those with an enemy next to them. }
procedure SpellMassInvisibility;
var
  i: Byte;
begin
  GDVars.areaTargets := 1;
  for i := 1 to GDVars.castTargetCount do
    if (GDVars.castTargets[i]^.hostile <> GDVars.curChar^.hostile)
       or ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and (CharHlp.CountTargets(GDVars.castTargets[i], 1) > 0)) then
      GDVars.castTargets[i] := nil;
  Magic.ResolveSpell(GDVars.spellId, 0, 0, 0, 0, GDConsts.msgIs + GDConsts.effectNames[C_Effect.INVISIBLE]);
end;

{ Casts Power Word Stun: stuns the target for 4d4 rounds at up to 30 hit points, 2d4 up to 60, 1d4 up to 90, and not at
  all above. }
procedure SpellPowerWordStun;
var
  n: Byte;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.castTargets[1];
  case tgt^.hpCurrent of
    1..30: n := FxEngine.RollDice(4, 4);
    31..60: n := FxEngine.RollDice(2, 4);
    61..90: n := FxEngine.RollDice(1, 4);
  else
    n := 0;
  end;
  FxEngine.AddEffectWithMessage(tgt, GDConsts.spellDefs[117].effectId, n, CharHlp.GetCasterLevel(117), 0,
                       GDConsts.spellDefs[117].saveEffect, False,
                       GDConsts.msgIs + GDConsts.effectNames[106]);
end;

{ Effects 83 and 104: a 3-ray breath cone, cold of 7 cells (83) or fire of 9 cells (104), aimed with spell 61's target
  picker, for the creature's maximum hit points, halved on a save against breath, only when every target is on the other
  side. The effect allows three breaths per battle, and a breath ends the creature's turn.
  @param(cr The creature carrying the effect.)
  @param(eff The effect's node.)
  @param(removed Unused.) }
procedure EffDragonBreath(var cr: Types.PCharRecord; eff: Types.PEffectRec; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  drain: Boolean;
  cellX: ShortInt;
  cellY: ShortInt;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  kind: Byte;
  lvl: Byte;
  elem: String[5];
  dir: Byte;
begin
  if (GDVars.roundCounter = 0) or (eff^.strength > 3) then
    eff^.strength := 3;
  if eff^.strength <= 0 then
    Exit;
  case eff^.id of
    83:
      begin
        GDVars.elemMask := $22;
        kind := 3;
        lvl := 7;
        elem := 'cold';
      end;
    104:
      begin
        GDVars.elemMask := $21;
        kind := 3;
        lvl := 9;
        elem := 'Fire';
      end;
  end;
  cellX := CbtMap.CombatCellX(cr);
  cellY := CbtMap.CombatCellY(cr);
  GDVars.castTargetMenu(61, True, GDVars.castConfirmed);
  if not GDVars.castConfirmed then
    Exit;
  Magic.CollectConeTargets(cellX, cellY, GDVars.targetCellX, GDVars.targetCellY, kind, lvl);
  for i := 1 to GDVars.castTargetCount do
    if GDVars.castTargets[i]^.hostile <> CharHlp.EnemyTeam(cr) then
      GDVars.castConfirmed := False;
  if GDVars.castTargetCount <= 0 then
    Exit;
  if not GDVars.castConfirmed then
    Exit;
  CharHlp.PrintCreatureMessage(cr, 'breathes ' + elem, 10, True);
  dir := CharHlp.DirTowardTarget(cr, GDVars.castTargets[1]);
  CharHlp.CombatPrintCreatureInfo(cr);
  CbtMap.SetCreatureFacing(cr, dir, 1, 0);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.castTargets[1]), CbtMap.CombatCellY(GDVars.castTargets[1]),
                                  1, 30);
  for i := 1 to GDVars.castTargetCount do
    if GDVars.castTargets[i] <> nil then begin
      tgt := GDVars.castTargets[i];
      saved := FxEngine.RollSavingThrow(tgt, C_Save.BREATH_WEAPON, 0);
      FxEngine.InflictNonWeaponDamage(tgt, cr^.hpMax, 2, saved);
    end;
  Dec(eff^.strength);
  drain := CharHlp.EndActions(cr);
end;

function ItemReadable(it: Types.PItemRec): Boolean;
begin
  if (it <> nil) and ((it^.kind = #39) or (it^.kind = #40) or (it^.kind = 'I')) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

procedure RemoveSpellFromScroll(cr: Types.PCharRecord; it: Types.PItemRec; spell: Byte);
var
  want: Byte;
  i: Byte;
  found: Byte;
  prev: Types.PItemRec;
  head: Types.PItemRec;
  hit: Boolean;
begin
  want := spell;
  found := 0;
  if it^.kind = 'I' then
  begin
    head := it;
    hit := False;
    while (it^.bundleNext <> nil) and not hit do begin
      prev := it;
      it := it^.bundleNext;
      for i := 1 to 3 do
        if (it^.scribe[i] and C_Spell.ID_MASK) = want then begin
          found := i;
          hit := True;
        end;
    end;
    if not hit then Exit;
    it^.scribe[found] := 0;
    Dec(it^.firstNameId);
    if it^.firstNameId < 100 then begin
      prev^.bundleNext := it^.bundleNext;
      Dec(head^.count);
      if head^.count = 1 then begin
        prev := head^.next;
        head^ := head^.bundleNext^;
        head^.bundleNext := nil;
        head^.next := prev;
      end;
      Dispose(it);
    end;
  end else begin
    for i := 1 to 3 do
      if (it^.scribe[i] and C_Spell.ID_MASK) = want then
        found := i;
    if found = 0 then Exit;
    it^.scribe[found] := 0;
    Dec(it^.firstNameId);
    if it^.firstNameId < 100 then
      CharHlp.RemoveItem(cr, it);
  end;
end;

procedure PrintCastSpellMsg(cr: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    CharHlp.PrintCreatureMessage(cr, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 0, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(cr, 1, 19, False);
    TextRend.DisplayString(Length(cr^.name) + 1 + 1, 19, LightGreen, 0, msg);
    TextRend.DisplayString(1, 20, LightGreen, 0, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

function PromptCastAnyway(cr: Types.PCharRecord; msg: String): Char;
begin
  CharHlp.PrintCreatureMessage(cr, msg, 0, False);
  PromptCastAnyway := MenuCore.YesNoMenu('cast cure anyway: ', LightMagenta, LightGreen, White, 2);
  CharHlp.ClearMessageWindow;
end;

procedure InitSpellFns;
begin
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
  GDVars.usingItemFlag := 0;
  GDVars.castTarget := nil;
  GDVars.redrawInvMenu := 1;
  GDVars.effectLock := 0;
  GDVars.spellFns[1] := Magic.SpellBless;
  GDVars.spellFns[2] := Magic.SpellCurse;
  GDVars.spellFns[3] := Magic.SpellCureLightWounds;
  GDVars.spellFns[4] := Magic.SpellCauseLightWounds;
  GDVars.spellFns[5] := Magic.SpellDetection;
  GDVars.spellFns[6] := Magic.SpellProtection;
  GDVars.spellFns[7] := Magic.SpellProtection;
  GDVars.spellFns[8] := Magic.SpellResistCold;
  GDVars.spellFns[9] := Magic.SpellBurningHands;
  GDVars.spellFns[10] := Magic.SpellCharmPerson;
  GDVars.spellFns[11] := Magic.SpellDetection;
  GDVars.spellFns[12] := Magic.SpellEnlarge;
  GDVars.spellFns[13] := Magic.SpellReduce;
  GDVars.spellFns[14] := Magic.SpellFriends;
  GDVars.spellFns[15] := Magic.SpellMagicMissile;
  GDVars.spellFns[16] := Magic.SpellProtection;
  GDVars.spellFns[17] := Magic.SpellProtection;
  GDVars.spellFns[18] := Magic.SpellDetection;
  GDVars.spellFns[19] := Magic.SpellShield;
  GDVars.spellFns[20] := Magic.SpellShockingGrasp;
  GDVars.spellFns[21] := Magic.SpellSleep;
  GDVars.spellFns[22] := Magic.SpellDetection;
  GDVars.spellFns[23] := Magic.SpellHold;
  GDVars.spellFns[24] := Magic.SpellResistFire;
  GDVars.spellFns[25] := Magic.SpellSilence;
  GDVars.spellFns[26] := Magic.SpellSlowPoison;
  GDVars.spellFns[27] := Magic.SpellSnakeCharm;
  GDVars.spellFns[28] := Magic.SpellSpiritualHammer;
  GDVars.spellFns[29] := Magic.SpellDetection;
  GDVars.spellFns[30] := Magic.SpellInvisibility;
  GDVars.spellFns[31] := Magic.SpellKnock;
  GDVars.spellFns[32] := Magic.SpellMirrorImage;
  GDVars.spellFns[33] := Magic.SpellRayOfEnfeeblement;
  GDVars.spellFns[34] := Magic.SpellStinkingCloud;
  GDVars.spellFns[35] := Magic.SpellStrength;
  GDVars.spellFns[36] := Magic.SpellHeal;
  GDVars.spellFns[37] := Magic.SpellCureBlindness;
  GDVars.spellFns[38] := Magic.SpellCauseBlindness;
  GDVars.spellFns[39] := Magic.SpellCureDisease;
  GDVars.spellFns[40] := Magic.SpellCauseDisease;
  GDVars.spellFns[41] := Magic.SpellDispelMagic;
  GDVars.spellFns[42] := Magic.SpellPrayer;
  GDVars.spellFns[43] := Magic.SpellRemoveCurse;
  GDVars.spellFns[44] := Magic.SpellBestowCurse;
  GDVars.spellFns[45] := Magic.SpellBlink;
  GDVars.spellFns[46] := Magic.SpellDispelMagic;
  GDVars.spellFns[47] := Magic.SpellFireball;
  GDVars.spellFns[48] := Magic.SpellHaste;
  GDVars.spellFns[49] := Magic.SpellHold;
  GDVars.spellFns[50] := Magic.SpellInvisibility;
  GDVars.spellFns[51] := Magic.SpellLightningBolt;
  GDVars.spellFns[52] := Magic.SpellProtection;
  GDVars.spellFns[53] := Magic.SpellProtection;
  GDVars.spellFns[54] := Magic.SpellProtection;
  GDVars.spellFns[55] := Magic.SpellSlow;
  GDVars.spellFns[56] := Magic.SpellHarm;
  GDVars.spellFns[57] := Magic.SpellPotionOfSpeed;
  GDVars.spellFns[58] := Magic.SpellCureSeriousWounds;
  GDVars.spellFns[59] := Magic.SpellGiantStrength;
  GDVars.spellFns[60] := Magic.SpellJavelinOfLightning;
  GDVars.spellFns[61] := Magic.SpellWandOfParalyzation;
  GDVars.spellFns[62] := Magic.SpellPotionOfHealing;
  GDVars.spellFns[63] := Magic.SpellYouth;
  GDVars.spellFns[64] := Magic.SpellFireball;
  GDVars.spellFns[65] := Magic.SpellWandOfMagicMissiles;
  GDVars.spellFns[66] := Magic.SpellCauseSeriousWounds;
  GDVars.spellFns[67] := Magic.SpellNeutralizePoison;
  GDVars.spellFns[68] := Magic.SpellPoison;
  GDVars.spellFns[69] := Magic.SpellProtection;
  GDVars.spellFns[70] := Magic.SpellSticksToSnakes;
  GDVars.spellFns[71] := Magic.SpellCureCriticalWounds;
  GDVars.spellFns[72] := Magic.SpellCauseCriticalWounds;
  GDVars.spellFns[73] := Magic.SpellDispelEvil;
  GDVars.spellFns[74] := Magic.SpellFlameStrike;
  GDVars.spellFns[75] := Magic.SpellRaiseDead;
  GDVars.spellFns[76] := Magic.SpellSlayLiving;
  GDVars.spellFns[77] := Magic.SpellDetection;
  GDVars.spellFns[78] := Magic.SpellEntangle;
  GDVars.spellFns[79] := Magic.SpellFaerieFire;
  GDVars.spellFns[80] := Magic.SpellInvisibilityToAnimals;
  GDVars.spellFns[81] := Magic.SpellCharmMonsters;
  GDVars.spellFns[82] := Magic.SpellConfusion;
  GDVars.spellFns[83] := Magic.SpellDimensionDoor;
  GDVars.spellFns[84] := Magic.SpellFear;
  GDVars.spellFns[85] := Magic.SpellFireShield;
  GDVars.spellFns[86] := Magic.SpellFumble;
  GDVars.spellFns[87] := Magic.SpellIceStorm;
  GDVars.spellFns[88] := Magic.SpellMinorGlobeOfInvulnerability;
  GDVars.spellFns[89] := Magic.SpellRemoveCurse;
  GDVars.spellFns[90] := Magic.SpellHeal;
  GDVars.spellFns[91] := Magic.SpellCloudkill;
  GDVars.spellFns[92] := Magic.SpellConeOfCold;
  GDVars.spellFns[93] := Magic.SpellFeeblemind;
  GDVars.spellFns[94] := Magic.SpellHold;
  GDVars.spellFns[95] := Magic.SpellImmuneBreath;
  GDVars.spellFns[96] := Magic.SpellCharmPersonOrMammal;
  GDVars.spellFns[97] := Magic.SpellTurnInvisible;
  GDVars.spellFns[98] := Magic.SpellDruidCureLightWounds;
  GDVars.spellFns[99] := Magic.SpellHealSelf;
  GDVars.spellFns[100] := Magic.SpellMageBestowCurse;
  GDVars.spellFns[101] := Magic.SpellNoEffect;
  GDVars.spellFns[102] := Magic.SpellNoEffect;
  GDVars.spellFns[103] := Magic.SpellNoEffect;
  GDVars.spellFns[104] := Magic.SpellNoEffect;
  GDVars.spellFns[105] := Magic.SpellNoEffect;
  GDVars.spellFns[106] := Magic.SpellNoEffect;
  GDVars.spellFns[107] := Magic.SpellNoEffect;
  GDVars.spellFns[108] := Magic.SpellNoEffect;
  GDVars.spellFns[109] := Magic.SpellNoEffect;
  GDVars.spellFns[110] := Magic.SpellDeathSpell;
  GDVars.spellFns[111] := Magic.SpellDisintegrate;
  GDVars.spellFns[112] := Magic.SpellGlobeOfInvulnerability;
  GDVars.spellFns[113] := Magic.SpellStoneToFlesh;
  GDVars.spellFns[114] := Magic.SpellFleshToStone;
  GDVars.spellFns[115] := Magic.SpellDelayedBlastFireball;
  GDVars.spellFns[116] := Magic.SpellMassInvisibility;
  GDVars.spellFns[117] := Magic.SpellPowerWordStun;
  @GDVars.effectHandlers[83] := @Magic.EffDragonBreath;
  @GDVars.effectHandlers[104] := @Magic.EffDragonBreath;
end;

begin
end.
