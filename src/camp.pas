{ Camp: rest, memorization, healing, alteration and copy protection. The overlay combines the camp menus and clock with
  the manual copy-protection quiz and the cure and heal workflow. }
{$O+,F+}
unit Camp;

interface

uses Types, CharGen, SaveLoad, ViewChar, GameTime, Magic, FxEngine, CharHlp, MenuCore, Portrait, Border, TextRend,
  GameIo, Crt, GDConsts, GDVars, C_Race, C_Status, C_Effect, C_Keys, C_Ifc, C_Spell, C_Stat,
  C_Class;

{ Runs the Camp menu (Save, which then offers to quit to DOS, View, Magic, Rest, Fix and Alter; extended keys change the
  current character) until Exit, Escape or an interrupted rest. Every 30th save first runs the rule-book check, and
  failing it quits the game. On entry, switches to the camping interface state, copies the portrait archive name and
  picture ID, clears the healing ticks, the rest clock and every pending memorize or scribe request, and announces 'The
  party makes camp...'. On exit, clears the pending requests and the cast target again, restores the interface state,
  and reloads the portrait animation from the copied archive name when it starts with PIC.
  @param(interrupted Set True when a rest is interrupted.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Runs the noncombat Cast menu for the current character until no spell is picked, saying 'has no spells memorized' when
  the list is empty. Clears the remembered cast target on entry, and redraws the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

implementation

const
  { an empty memorizedSpells slot }
  SPELL_NONE = 0;

var
  { effect-name table, indexed by effect id }
  effectNames: array[1..127] of String[37] absolute GDConsts.effectNames;

const
  ACT_CAST = 1;
  ACT_MEMORIZE = 2;
  ACT_SCRIBE = 3;

{ Returns the smaller of two counts.
  @param(a First count.)
  @param(b Second count.)
  @returns(The smaller count.) }
function Smaller(a, b: Word): Word;
begin
  Smaller := a;
  if b < a then Smaller := b;
end;

{ Works out a character's spell preparation time: 15 minutes per level of each pending spell (a level-0 spell being
  memorized counts as 1), plus four hours when any spell is pending, or six when any pending spell is level 3 or higher.
  Pending memorizing and pending scribing (readable items only, each sub-record of a bundle) both count. Stores the base
  hours (0, 4 or 6) in prepBase.
  @param(cr The character.)
  @returns(The preparation time in minutes.) }
function CampSpellPrepTime(cr: Types.PCharRecord): Word;
var
  maxMem: Byte;
  maxScr: Byte;
  cntMem: Byte;
  cntScr: Byte;
  inner: Types.PItemRec;
  outer: Types.PItemRec;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to 74 do
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      lvl := GDConsts.spellDefs[cr^.memorizedSpells[i] and C_Spell.ID_MASK].level;
      if lvl = 0 then lvl := 1;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  outer := cr^.itemsAddr;
  while outer <> nil do begin
    if Magic.ItemReadable(outer) then begin
      if outer^.itemType = Ord('I') then inner := outer^.bundleNext else inner := outer;
      repeat
        for i := 1 to 3 do
          if inner^.spells[i] > C_Spell.ID_MASK then begin
            lvl := GDConsts.spellDefs[inner^.spells[i] and C_Spell.ID_MASK].level;
            if lvl > maxScr then maxScr := lvl;
            Inc(cntScr, lvl);
          end;
        inner := inner^.bundleNext;
      until (outer^.itemType <> Ord('I')) or (inner = nil);
    end;
    outer := outer^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then base := 4;
  if (maxMem > 2) or (maxScr > 2) then base := 6;
  cr^.prepBase := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Runs the rule-book check: asks for word N after a heading on page P of the rule book, giving three tries to type it.
  The question is one of the first 20, and its heading and answer are decoded from GDConsts' letter tables.
  @returns(True when the last answer typed was right.) }
function RuleBookCheck: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  charIndex: Byte;
  wordIndex: Byte;
  attempts: Byte;
  { Unused in this version; see the other implementations of this routine. }
  passed: Byte;
  correctAnswer: String;
  headingText: String;
  wordNumber: Byte;
  headingIndex: Byte;
  pageNumber: Byte;
  reply: String;

  { Decodes a stored heading or answer word; each letter is a signed delta from 55 plus the word length. }
  function DecodeAnswer(tableIndex: Word; useHeading: Boolean): String;
  var
    count: Byte;
    letterIndex: Byte;
    firstLetter: Byte;
    decodedLetter: Byte;
    answer: String;
  begin
    answer := '';
    if useHeading then begin
      count := GDConsts.headTbl[tableIndex].textLen;
      firstLetter := GDConsts.headTbl[tableIndex].textOfs;
      for letterIndex := 1 to count do begin
        decodedLetter := ShortInt(GDConsts.wordChars1[firstLetter + letterIndex]) + 55 + count;
        answer := answer + Chr(decodedLetter);
      end;
    end else begin
      count := GDConsts.ruleBook[tableIndex].answerLen;
      firstLetter := GDConsts.ruleBook[tableIndex].answerOfs;
      for letterIndex := 1 to count do begin
        decodedLetter := ShortInt(GDConsts.wordChars2[firstLetter + letterIndex]) + 55 + count;
        answer := answer + Chr(decodedLetter);
      end;
    end;
    DecodeAnswer := answer;
  end;

begin
  Border.DrawWindowFrame(1);
  attempts := 0;
  wordIndex := Random(20) + 1;
  repeat
    Inc(attempts);
    correctAnswer := '';
    TextRend.DisplayString(3, 2, LightGreen, 0, ' what is word # ');
    wordNumber := GDConsts.ruleBook[wordIndex].wordNum;
    pageNumber := GDConsts.ruleBook[wordIndex].page;
    headingIndex := GDConsts.ruleBook[wordIndex].headingIdx;
    headingText := DecodeAnswer(headingIndex, True);
    correctAnswer := DecodeAnswer(wordIndex, False);
    TextRend.DisplayString(19, 2, LightGreen, 0, CharHlp.Uint8Str(wordNumber) + '    ');
    TextRend.DisplayString(3, 4, LightGreen, 0, ' after the heading ');
    TextRend.DisplayString(3, 6, LightGreen, 0, '                                  ');
    TextRend.DisplayString(3, 6, LightGreen, 0, '"' + headingText + '"');
    TextRend.DisplayString(3, 8, LightGreen, 0, ' (rule book, page ' + CharHlp.Uint8Str(pageNumber) + ')?' + '     ');
    reply := TextRend.ReadString('Enter ', Yellow, 0, 20);
  until (attempts = 3) or (reply = correctAnswer);
  if reply = correctAnswer then
    RuleBookCheck := True
  else
    RuleBookCheck := False;
end;

{ Removes every pending memorize request of a character, zeroing the slot, and clears its preparation hours.
  @param(cr The character.) }
procedure ResetMemorize(cr: Types.PCharRecord);
var i: Byte;
begin
  for i := 0 to 74 do
    if cr^.memorizedSpells[i] > C_Spell.ID_MASK then cr^.memorizedSpells[i] := 0;
  cr^.prepBase := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items; for a bundle it clears the spells of
  each of its sub-records.
  @param(cr The character.) }
procedure ResetScribe(cr: Types.PCharRecord);
var
  j: Byte;
  k: Byte;
  outer: Types.PItemRec;
  inner: Types.PItemRec;
begin
  outer := cr^.itemsAddr;
  while outer <> nil do begin
    if Magic.ItemReadable(outer) then begin
      if outer^.itemType = Ord('I') then begin
        inner := outer^.bundleNext;
        for k := 1 to outer^.count do begin
          for j := 1 to 3 do
            inner^.spells[j] := inner^.spells[j] and C_Spell.ID_MASK;
          inner := inner^.bundleNext;
        end;
      end else
        for j := 1 to 3 do
          outer^.spells[j] := outer^.spells[j] and C_Spell.ID_MASK;
    end;
    outer := outer^.next;
  end;
end;

{ Clears the pending memorizing and scribing of each party member. }
procedure ResetPartySpellActivities;
var character: Types.PCharRecord;
begin
  character := GDVars.creatureList;
  while character <> nil do begin
    Camp.ResetMemorize(character);
    Camp.ResetScribe(character);
    character := character^.nextCharAddr;
  end;
end;

{ Counts the spells the current character can still memorize of a class and level: the allowance less the memorized and
  pending spells of that class and level, never below 0.
  @param(spellLevel The spell level.)
  @param(spellClass The spell list, CLERIC_LIST to MAGE_LIST.)
  @param(usedSlots Receives the memorized and pending count.)
  @returns(The spells left to memorize.) }
function SpellSlotsRemaining(spellLevel, spellClass: ShortInt; var usedSlots: Byte): Byte;
var
  count: Byte;
  i: Byte;
begin
  count := 0;
  for i := 0 to 74 do
    if GDVars.curChar^.memorizedSpells[i] > 0 then
      if GDConsts.spellDefs[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].level = spellLevel then
        if GDConsts.spellDefs[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].castClass = spellClass then
          Inc(count);
  usedSlots := count;
  if GDVars.curChar^.spellSlots[spellClass, spellLevel] < count then
    count := GDVars.curChar^.spellSlots[spellClass, spellLevel];
  SpellSlotsRemaining := GDVars.curChar^.spellSlots[spellClass, spellLevel] - count;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var message: Types.TStr40;
begin
  message := '';
  if (activity = Camp.ACT_CAST) and (GDVars.zone0^.antimagic > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.enabled = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACT_CAST: message := message + 'cast any spells';
      Camp.ACT_MEMORIZE: message := message + 'memorize spells';
      Camp.ACT_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.curChar, message, 10, True);
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer; notEmpty: Boolean; needsRedraw: Boolean; castSelected: Boolean; spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.castTarget := nil;
  GDVars.horizChoice := 1;
  if Camp.CanDoSpellActivity(Camp.ACT_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> Camp.SPELL_NONE then begin
        needsRedraw := True;
        Border.ClearBox(1, 17, 38, 22);
        Magic.CastSpell(spellId, False, True, castSelected);
      end else begin
        if notEmpty then
          needsRedraw := True
        else
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = Camp.SPELL_NONE;
  end;
  if needsRedraw then
    CharHlp.DisplayNoncombatInterface;
end;

{ Shows the current character's remaining spell slots for levels 1..7 of the cleric, druid and magic-user lists, one
  line for each list with any allowance. A level with no allowance is blank; a full level shows zero. The special list
  counts toward the result but is not shown.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  slotStr: array[1..7, 0..3] of String[2];
  canDo: array[0..3] of Byte;
  typ: ShortInt;
  lvl: ShortInt;
  col: Byte;
  row: Byte;
  any: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  baseSlotCount: Word;
  usedSlots: Byte;
begin
  any := False;
  for typ := C_Spell.CLERIC_LIST to C_Spell.MAGE_LIST do begin
    canDo[typ] := 0;
    for lvl := 1 to 7 do begin
      slotStr[lvl, typ] := CharHlp.Uint8Str(Camp.SpellSlotsRemaining(lvl, typ, usedSlots));
      if GDVars.curChar^.spellSlots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharHlp.PrintCreatureMessage(GDVars.curChar, '', 10, False);
    row := 1;
    for typ := C_Spell.CLERIC_LIST to C_Spell.MAGE_LIST do
      if typ <> 2 then
        if canDo[typ] <> 0 then begin
          case typ of
            C_Spell.CLERIC_LIST: s := '    Cleric Spells:';
            C_Spell.DRUID_LIST: s := '     Druid Spells:';
            C_Spell.MAGE_LIST: s := 'Magic-User Spells:';
          end;
          TextRend.DisplayString(1, row + 17, LightGreen, 0, s);
          col := 19;
          for lvl := 1 to 7 do begin
            TextRend.DisplayString(col + 1, row + 17, LightGreen, 0, slotStr[lvl, typ]);
            Inc(col, 3);
          end;
          Inc(row);
        end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest time and redraws the
  position and time.
  @param(interrupted Receives True when the rest was interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCharRecord;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.creatureList;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.nextCharAddr;
  end;
  GDVars.restClock[3] := maxPrepMinutes div 60;
  GDVars.restClock[2] := (maxPrepMinutes - 60 * GDVars.restClock[3]) div 10;
  GDVars.restClock[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(1);
  GameIo.FillWord(GDVars.restClock, SizeOf(GDVars.restClock));
  CharHlp.PrintPositionAndTime;
end;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to 73 do
    for j := i to 74 do
      if (GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) > (GDVars.curChar^.memorizedSpells[j] and
                                                              C_Spell.ID_MASK) then begin
        tmp := GDVars.curChar^.memorizedSpells[i];
        GDVars.curChar^.memorizedSpells[i] := GDVars.curChar^.memorizedSpells[j];
        GDVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Shows the pending memorize list first: Yes keeps it and skips selection, No clears it. Then lets the player pick
  spells from the spellbook, marking each as pending while slots of its class and level remain, until the player stops
  or no slot is left, and confirms the pending list again if the spellbook menu was used. The noncombat interface is
  redrawn afterwards when a list was shown. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
  usedSlots: Byte;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_MEMORIZE) then begin
    done := False;
    idx := -1;
    GDVars.horizChoice := 1;
    spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu(GDConsts.gMemorize + GDConsts.gTheseSpells, Yellow, LightGreen, White, 1) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot ' + GDConsts.gMemorize + ' any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = Camp.SPELL_NONE then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellDefs[spellId].level, GDConsts.spellDefs[spellId].castClass,
                                    usedSlots) > 0 then begin
          GDVars.fixByte := 0;
          i := 0;
          while GDVars.curChar^.memorizedSpells[i] <> 0 do
            Inc(i);
          GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu(GDConsts.gMemorize + GDConsts.gTheseSpells, Yellow, LightGreen, White, 1) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Shows the pending scribe list first: Yes keeps it and skips selection, No clears it. Then lets the player pick scroll
  spells to copy, rejecting spells already known, already pending, or of a class and level the character has no slots
  for. Confirms the pending list again if the scroll menu was used. Note: the marking walk does not check ItemReadable:
  it marks the first item spell equal to the picked ID. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  j: Byte;
  k: Byte;
  idx: Integer;
  outer: Types.PItemRec;
  inner: Types.PItemRec;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACT_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu(GDConsts.gScribe + GDConsts.gTheseSpells, Yellow, LightGreen, White, 1) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = Camp.SPELL_NONE then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no copyable scrolls', 10, True)
        else
          redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.known[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          outer := GDVars.curChar^.itemsAddr;
          found := False;
          while (outer <> nil) and (found = False) do begin
            if Magic.ItemReadable(outer) then begin
              if outer^.itemType = Ord('I') then begin
                inner := outer^.bundleNext;
                for k := 1 to outer^.count do begin
                  for j := 1 to 3 do
                    if (found = False) and (inner^.spells[j] > C_Spell.ID_MASK) and
                        (inner^.spells[j] and C_Spell.ID_MASK = spellId) then begin
                      CharHlp.PrintBottomLine('You are already scribing that spell');
                      found := True;
                    end;
                  inner := inner^.bundleNext;
                end;
              end else
                for j := 1 to 3 do
                  if (outer^.spells[j] > C_Spell.ID_MASK) and (outer^.spells[j] and
                                                               C_Spell.ID_MASK = spellId) then begin
                    CharHlp.PrintBottomLine('You are already scribing that spell');
                    found := True;
                  end;
            end;
            outer := outer^.next;
          end;
          if found = False then begin
            if GDVars.curChar^.spellSlots[GDConsts.spellDefs[spellId].castClass, GDConsts.spellDefs[spellId].level] >
                0 then begin
              outer := GDVars.curChar^.itemsAddr;
              while (outer <> nil) and (found = False) do begin
                if outer^.itemType = Ord('I') then begin
                  inner := outer^.bundleNext;
                  for k := 1 to outer^.count do begin
                    j := 1;
                    repeat
                      if inner^.spells[j] = spellId then begin
                        inner^.spells[j] := inner^.spells[j] or C_Spell.PENDING_FLAG;
                        found := True;
                      end;
                      Inc(j);
                    until (j > 3) or found;
                    inner := inner^.bundleNext;
                    if found then k := outer^.count;
                  end;
                end else begin
                  j := 1;
                  repeat
                    if outer^.spells[j] = spellId then begin
                      outer^.spells[j] := outer^.spells[j] or C_Spell.PENDING_FLAG;
                      found := True;
                    end;
                    Inc(j);
                  until (j > 3) or found;
                end;
                outer := outer^.next;
              end;
            end else
              CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu(GDConsts.gScribe + GDConsts.gTheseSpells, Yellow, LightGreen, White, 1) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists the magical effects on each party member under the member's name, by the effect-name table; effects with an
  empty name are hidden, and a member with none shows '<No Magical Effects>'. The noncombat interface is redrawn
  afterwards. }
procedure CampDisplayMenu;
var
  effect: Types.PEffectRec;
  listHead: Types.PItemRec;
  listTail: Types.PItemRec;
  character: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  effectId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  { Unused in this version; see the other implementations of this routine. }
  effectNameFound: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: Types.TStr40;
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends a list node with the given text; isTitle marks a character-name heading. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TItemNode));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.isHeader := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TItemNode));
  listTail := listHead;
  listTail^.isHeader := 0;
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.creatureList;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := character^.effectsAddr;
    while effect <> nil do begin
      displayEffect := True;
      effectName := effectNames[effect^.id];
      if effectName <> '' then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then
      AddToList(False, ' <No Magical Effects>');
    AddToList(False, ' ');
    character := character^.nextCharAddr;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame(1);
  choice := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, listHead, 1, viewNeedsRedraw,
                                  menuIndex, listTail);
  MenuCore.FreeStringList(listHead);
  CharHlp.DisplayNoncombatInterface;
end;

{ Runs the Magic menu (cast, memorize, scribe, display, rest); extended keys change the current character. Ends on Exit,
  Escape or an interrupted rest.
  @param(interrupted Set True when a rest is interrupted; the menu ends at once when it is already True.) }
procedure CampMagicMenu(var interrupted: Boolean);
var c: Char; ext: Boolean; savedFlag: Byte;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('', GDConsts.magicMenu, LightMagenta, LightGreen, White, 1, 1, ext);
    savedFlag := GDVars.horizChoice;
    if ext then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end else
      case c of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.RestForSpellPrep(interrupted);
      end;
    GDVars.horizChoice := savedFlag;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  tmp: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
  end else
    while p^.nextCharAddr <> GDVars.curChar do begin
      prev := p;
      p := p^.nextCharAddr;
    end;
  tmp := GDVars.curChar^.nextCharAddr;
  if GDVars.creatureList = GDVars.curChar then begin
    if tmp <> nil then
      GDVars.creatureList := tmp;
    p^.nextCharAddr := GDVars.curChar;
    GDVars.curChar^.nextCharAddr := nil;
  end else begin
    p^.nextCharAddr := tmp;
    GDVars.curChar^.nextCharAddr := p;
    if (p = GDVars.creatureList) or (prev = nil) then
      GDVars.creatureList := GDVars.curChar
    else
      prev^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCharRecord;
  successor: Types.PCharRecord;
begin
  predecessor := GDVars.creatureList;
  if predecessor <> GDVars.curChar then
    while predecessor^.nextCharAddr <> GDVars.curChar do
      predecessor := predecessor^.nextCharAddr;
  successor := GDVars.curChar^.nextCharAddr;
  if successor = nil then begin
    GDVars.curChar^.nextCharAddr := GDVars.creatureList;
    GDVars.creatureList := GDVars.curChar;
    predecessor^.nextCharAddr := successor;
  end else begin
    GDVars.curChar^.nextCharAddr := successor^.nextCharAddr;
    if GDVars.creatureList = GDVars.curChar then
      GDVars.creatureList := successor;
    if predecessor <> GDVars.curChar then
      predecessor^.nextCharAddr := successor;
    successor^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Reorders the party in two modes. In Select mode extended keys change the current character; in Place mode the up arrow
  moves it up and the down arrow moves it down. Enter, P and S switch modes. }
procedure PartyOrderMenu;
var selected: ShortInt; isExtendedKey: Boolean; choice: Char;
begin
  selected := 0;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('Party Order: ', GDConsts.orderMenus[selected], LightMagenta, LightGreen, White,
                                      1, 1, isExtendedKey);
    if isExtendedKey then begin
      if selected = 0 then begin
        CharHlp.DisplayParty(GDVars.curChar, False);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.DisplayParty(GDVars.curChar, True);
      end else begin
        case choice of
          C_Keys.UP: Camp.OrderMoveUp;
          C_Keys.DOWN: Camp.OrderMoveDown;
        end;
        CharHlp.DisplayRoster(GDVars.curChar);
      end;
    end else
      if choice in [C_Keys.ENTER, 'P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then CharHlp.PrintCreatureMessage(GDVars.curChar, 'has been selected', 10, False)
        else CharHlp.ClearMessageWindow;
      end;
  end;
end;

{ Drops the current character from the party after confirmation, with a farewell that depends on whether it is enabled,
  and redraws the party. For the last party member it offers to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.nextCharAddr = nil) and (GDVars.curChar = GDVars.creatureList) then begin
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White, 2) = 'Y' then begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharHlp.PrintCreatureMessage(GDVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White, 2) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'bids you farewell', 10, True)
    else
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'is dumped in a ditch', 10, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayRoster(GDVars.curChar);
  end else
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'Breathes A sigh of relief', 10, True);
end;

{ Shows the difficulty menu with the current level highlighted and stores the level picked (Novice 0 to Champion 4) in
  the zone's difficulty variable; extended keys change the current character instead. }
procedure CampDifficultyMenu;
var choice: Char; isExtendedKey: Boolean; difficulty: Byte;
begin
  difficulty := GDVars.zone0^.difficulty;
  GDVars.horizChoice := difficulty + 1;
  choice := MenuCore.MenuHorizontal('', GDConsts.difficultyMenu, LightMagenta, LightGreen, White, 1, 1,
                                    isExtendedKey);
  if isExtendedKey then begin
    CharHlp.DisplayParty(GDVars.curChar, False);
    ViewChar.SelectPrevNextChar(choice);
    CharHlp.DisplayParty(GDVars.curChar, True);
  end else
    case choice of
      'N': difficulty := 0;
      'S': difficulty := 1;
      'V': difficulty := 2;
      'A': difficulty := 3;
      'C': difficulty := 4;
    end;
  GDVars.zone0^.difficulty := difficulty;
end;

{ Adjusts the game delay, 0 (fastest) to 9 (slowest). Faster and Slower are offered only while the delay can move that
  way; the up arrow slows the game and the down arrow speeds it up. }
procedure CampSpeedMenu;
var choice: Char; isExtendedKey: Boolean; menuText: Types.TStr40;
begin
  repeat
    TextRend.DisplayString(1, 18, LightGreen, 0,
                           'Game Speed = ' + CharHlp.Uint8Str(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuText := '';
    if GDVars.gameDelay > 0 then menuText := menuText + ' Faster';
    if GDVars.gameDelay < 9 then menuText := menuText + ' Slower';
    menuText := menuText + ' Exit';
    choice := MenuCore.MenuHorizontal('Game Speed:', menuText, LightMagenta, LightGreen, White, 1, 1,
                                      isExtendedKey);
    if isExtendedKey then
      case choice of
        C_Keys.DOWN: if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        C_Keys.UP: if GDVars.gameDelay < 9 then Inc(GDVars.gameDelay);
      end else
      case choice of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until choice in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Runs the Alter menu: difficulty level, party order, drop, game speed and portrait icon (read from disk 2). Extended
  keys change the current character. Pictures and animation are turned on at entry. }
procedure CampAlterMenu;
var choice: Char;
    { Unused in this version; see the other implementations of this routine. }
    toggleChoice: Byte;
    isExtendedKey: Boolean;
    { Unused in this version; see the other implementations of this routine. }
    menuText: Types.TStr40;
    savedDisk: Byte;
    savedChoice: Byte;
begin
  GDVars.picsOn := 1;
  GDVars.animOn := 1;
  choice := ' ';
  while not (choice in [C_Keys.NONE, 'E']) do begin
    choice := MenuCore.MenuHorizontal('', GDConsts.alterMenu, LightMagenta, LightGreen, White, 1, 1, isExtendedKey);
    savedChoice := GDVars.horizChoice;
    if isExtendedKey then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(choice);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end else
      case choice of
        'L': Camp.CampDifficultyMenu;
        'O': Camp.PartyOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'I': begin
               savedDisk := GDVars.diskNum;
               GDVars.diskNum := 2;
               CharGen.CustomizeIcon;
               GDVars.diskNum := savedDisk;
               CharHlp.DisplayNoncombatInterface;
             end;
      end;
    GDVars.horizChoice := savedChoice;
  end;
end;

{ Heals the party with its cure spells when any member is missing hit points. Rolls each cure spell the conscious
  members have memorized into a healing pool and counts their memorized status cures, then rests for a time set by their
  cure slots (shortened in proportion when the party misses fewer hit points than the slots' combined heal time). Unless
  the rest is interrupted, it rolls one cure for each counted slot into the pool, applies the status cures, spends the
  pool on the party in order and puts the rest clock back. It then counts the members needing each status cure, adds the
  status-cure slots to the cures available, rests again for the cures needed and, unless interrupted, applies the status
  cures once more. Note: the heal time is never set to 0 before it is added up, a member who is not conscious repeats
  the previous member's slot times, and cure blindness acts on the current character instead of the member being
  examined.
  @param(interrupted Set True when a rest is interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);
var
  healPool: Word;
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  healSlots: Word;
  raiseDeadCount: Word;
  deadCount: Word;
  removeCurseCount: Word;
  cursedCount: Word;
  cureBlindnessCount: Word;
  blindCount: Word;
  cureDiseaseCount: Word;
  diseasedCount: Word;
  healCount: Word;
  feeblemindedCount: Word;
  neutralizePoisonCount: Word;
  poisonedCount: Word;
  stoneToFleshCount: Word;
  petrifiedCount: Word;
  savedRestTime: Types.TRestClock;

  { A member counts as conscious only when its status is OKAY. }
  function CanCast(character: Types.PCharRecord): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Rolls each cure spell memorized by a conscious member into healPool and counts the memorized status cures. }
  procedure RollMemorizedCures;
  var rolledHealing: Word; spellIndex: Byte; character: Types.PCharRecord;
  begin
    rolledHealing := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      if CanCast(character) then
        for spellIndex := 0 to 74 do
          case character^.memorizedSpells[spellIndex] of
            { Cure Light Wounds }
            3, 98: Inc(rolledHealing, FxEngine.RollDice(1, 8));
            { Cure Serious Wounds }
            58: Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
            { Cure Critical Wounds }
            71: Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
            { Heal }
            36: begin Inc(rolledHealing, FxEngine.RollDice(4, 8) + 5); Inc(healCount); end;
            { Neutralize Poison }
            67: Inc(neutralizePoisonCount);
            { Raise Dead }
            75: Inc(raiseDeadCount);
            { Remove Curse }
            43, 89: Inc(removeCurseCount);
            { Stone to Flesh }
            113: Inc(stoneToFleshCount);
            { Cure Blindness }
            37: Inc(cureBlindnessCount);
            { Cure Disease }
            39: Inc(cureDiseaseCount);
          end;
      character := character^.nextCharAddr;
    end;
    Inc(healPool, rolledHealing);
  end;

  { Adds a cure roll for each counted cure slot to the healing pool. }
  procedure RollCureSlots;
  var rolledHealing: Word; rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    for rollIndex := 1 to healSlots do Inc(rolledHealing, FxEngine.RollDice(4, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { Returns the party's total missing hit points. }
  function PartyHitPointsMissing: Word;
  var totalDamage: Word; character: Types.PCharRecord;
  begin
    totalDamage := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      Inc(totalDamage, character^.hpMax - character^.hpCur);
      character := character^.nextCharAddr;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Counts the conscious members' cure slots and sets the rest clock from their healing time. }
  procedure ComputeFixTime;
  var timeMin: Word; ch: Types.PCharRecord;
      maxTime: Word;
      partA: Word;
      partB: Word;
      partC: Word;
      partD: Word;
      partE: Word;
      base: Word;
      t: Word;
      ratio: Byte;
  begin
    ch := GDVars.creatureList;
    partA := 0; partB := 0; partC := 0; partD := 0; partE := 0;
    cureLightSlots := 0; cureSeriousSlots := 0; cureCriticalSlots := 0; healSlots := 0;
    maxTime := 0;
    while ch <> nil do begin
      base := 0;
      if CanCast(ch) then
        if ch^.stats[C_Stat.WISDOM].cur > 3 then begin
          t := ch^.spellSlots[C_Spell.CLERIC_LIST, 1]; Inc(cureLightSlots, t); partA := t * 15;
          t := ch^.spellSlots[C_Spell.DRUID_LIST, 2]; Inc(cureLightSlots, t); partB := t * 30;
          Inc(cureSeriousSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 4]);
          partC := ch^.spellSlots[C_Spell.CLERIC_LIST, 4] * 60;
          Inc(cureCriticalSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 5]);
          partD := ch^.spellSlots[C_Spell.CLERIC_LIST, 5] * 75;
          Inc(healSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 6]);
          partE := ch^.spellSlots[C_Spell.CLERIC_LIST, 6] * 90;
        end;
      if partA > 0 then begin base := 240; Inc(timeMin, 27); end;
      if partB > 0 then begin base := 240; Inc(timeMin, 27); end;
      if partC + partD > 0 then begin
        base := 360;
        if partD > 0 then Inc(timeMin, 78) else Inc(timeMin, 34);
      end;
      if partE > 0 then begin base := 480; Inc(timeMin, 90); end;
      Inc(base, partA + partB + partC + partD + partE);
      if maxTime < base then maxTime := base;
      ch := ch^.nextCharAddr;
    end;
    if PartyHitPointsMissing < timeMin then begin
      ratio := timeMin div PartyHitPointsMissing;
      maxTime := maxTime div ratio;
    end;
    GDVars.restClock[3] := maxTime div 60;
    GDVars.restClock[2] := (maxTime - 60 * GDVars.restClock[3]) div 10;
    GDVars.restClock[1] := maxTime mod 10;
  end;

  { Adds the conscious members' status-cure slots to the cure counts and sets the rest clock from the cures needed. }
  procedure ComputeCureTime;
  var character: Types.PCharRecord; cureMinutes: Word;
      { Unused in this version; see the other implementations of this routine. }
      hours: Word;
  begin
    character := GDVars.creatureList;
    while character <> nil do begin
      if CanCast(character) then begin
        Inc(healCount, character^.spellSlots[C_Spell.CLERIC_LIST, 6]);
        Inc(stoneToFleshCount, character^.spellSlots[C_Spell.MAGE_LIST, 6]);
        Inc(raiseDeadCount, character^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        Inc(neutralizePoisonCount, character^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.MAGE_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
        Inc(cureBlindnessCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
        Inc(cureDiseaseCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
      end;
      character := character^.nextCharAddr;
    end;
    cureMinutes := 0;
    cureMinutes := cureMinutes + Camp.Smaller(healCount, feeblemindedCount) * 90;
    cureMinutes := cureMinutes + Camp.Smaller(stoneToFleshCount, petrifiedCount) * 90;
    cureMinutes := cureMinutes + Camp.Smaller(raiseDeadCount, deadCount) * 75;
    cureMinutes := cureMinutes + Camp.Smaller(neutralizePoisonCount, poisonedCount) * 60;
    cureMinutes := cureMinutes + Camp.Smaller(cureDiseaseCount, diseasedCount) * 45;
    cureMinutes := cureMinutes + Camp.Smaller(cureBlindnessCount, blindCount) * 45;
    cureMinutes := cureMinutes + Camp.Smaller(removeCurseCount, cursedCount) * 45;
    GDVars.restClock[3] := cureMinutes div 60;
    GDVars.restClock[2] := (cureMinutes - 60 * GDVars.restClock[3]) div 10;
    GDVars.restClock[1] := cureMinutes mod 10;
  end;

  { Spends the healing pool on each member in party order, up to that member's missing hit points. }
  procedure HealParty;
  var character: Types.PCharRecord; healingNeeded: Word;
  begin
    character := GDVars.creatureList;
    while character <> nil do begin
      if character^.hpMax > character^.hpCur then begin
        healingNeeded := character^.hpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, healingNeeded, 0) then
            if healingNeeded <= healPool then Dec(healPool, healingNeeded);
      end;
      character := character^.nextCharAddr;
    end;
  end;

  { Applies the counted heal, stone-to-flesh, poison, raise-dead, curse, disease and blindness cures. }
  procedure CureStatusEffects;
  var character: Types.PCharRecord; effect: Types.PEffectRec; diseaseIndex: Byte; wasHealed: Byte; bonusHitPoints: Byte;
      bonusDivisor: Byte; classIndex: ShortInt;
  begin
    character := GDVars.creatureList;
    while character <> nil do begin
      wasHealed := 0;
      if healCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.FEEBLEMINDED, effect) then begin
          FxEngine.RemoveEffect(character, C_Effect.FEEBLEMINDED, nil);
          if CharHlp.HasEffect(character, C_Effect.BLIND, effect) then
            FxEngine.RemoveEffect(character, C_Effect.BLIND, nil);
          for diseaseIndex := 1 to 4 do
            if CharHlp.HasEffect(character, GDConsts.diseaseFx[diseaseIndex], effect) then
              FxEngine.RemoveEffect(character, GDConsts.diseaseFx[diseaseIndex], nil);
          wasHealed := 1;
          CharHlp.PrintCreatureMessage(character, 'is healed', 10, True);
          Dec(healCount);
        end;
      if (stoneToFleshCount > 0) and (character^.status = C_Status.PETRIFIED) then begin
        character^.status := C_Status.OKAY;
        character^.enabled := 1;
        character^.hpCur := 1;
        CharHlp.PrintCreatureMessage(character, 'is changed back to flesh', 10, True);
        Dec(stoneToFleshCount);
      end;
      if neutralizePoisonCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.POISONED, effect) then begin
          if character^.hpCur = 0 then character^.hpCur := 1;
          GDVars.effectLock := 1;
          FxEngine.RemoveEffect(character, C_Effect.POISONED, nil);
          FxEngine.RemoveEffect(character, C_Effect.SLOW_POISON_END, nil);
          FxEngine.RemoveEffect(character, C_Effect.SLOW_POISON_HIT, nil);
          GDVars.effectLock := 0;
          character^.enabled := 1;
          character^.status := C_Status.OKAY;
          CharHlp.PrintCreatureMessage(character, 'is detoxified', 10, True);
          Dec(neutralizePoisonCount);
        end;
      if raiseDeadCount > 0 then
        if (character^.status = C_Status.DEAD_STATUS) and (character^.race <> C_Race.HALF_ELF)
           and (character^.race <> C_Race.ELF) then begin
          GDVars.effectLock := 1;
          FxEngine.RemoveEffect(character, C_Effect.POISONED, nil);
          GDVars.effectLock := 0;
          character^.hpCur := 1;
          character^.status := C_Status.OKAY;
          character^.enabled := 1;
          if character^.stats[C_Stat.CONSTITUTION].cur > 0 then Dec(character^.stats[C_Stat.CONSTITUTION].cur);
          if character^.hpMax > character^.hpRolled then
            bonusHitPoints := character^.hpMax - character^.hpRolled
          else
            bonusHitPoints := 0;
          bonusDivisor := 0;
          if character^.stats[C_Stat.CONSTITUTION].cur >= 14 then begin
            for classIndex := C_Class.CLERIC to C_Class.THIEF do begin
              if character^.classLevelA[classIndex] > 0 then
                if (classIndex = C_Class.FIGHTER) or (classIndex = C_Class.PALADIN) or
                    (classIndex = C_Class.RANGER) then
                  Inc(bonusDivisor,
                      (character^.stats[C_Stat.CONSTITUTION].cur - 14) * character^.classLevelA[classIndex])
                else if character^.stats[C_Stat.CONSTITUTION].cur > 15 then
                  Inc(bonusDivisor, character^.classLevelA[classIndex] * 2)
                else
                  Inc(bonusDivisor, character^.classLevelA[classIndex]);
            end;
            if bonusDivisor > 0 then bonusHitPoints := bonusHitPoints div bonusDivisor;
            if (character^.stats[C_Stat.CONSTITUTION].cur < 17) or (character^.classLevelA[C_Class.FIGHTER] > 0) or
                (character^.classLevelA[C_Class.FIGHTER] > character^.dualClassThreshold) then
              Dec(character^.hpMax, bonusHitPoints);
          end;
          CharHlp.PrintCreatureMessage(character, 'has been raised from the dead', 10, True);
          Dec(raiseDeadCount);
        end;
      if removeCurseCount > 0 then
        if CharHlp.HasEffect(character, C_Effect.BESTOW_CURSE, effect) then begin
          GDVars.castTargets[1] := character;
          Magic.SpellRemoveCurse;
          CharHlp.PrintCreatureMessage(character, 'is relieved of a curse', 10, True);
          Dec(removeCurseCount);
        end;
      if wasHealed = 0 then
        if cureDiseaseCount > 0 then begin
          wasHealed := 0;
          for diseaseIndex := 1 to 4 do
            if CharHlp.HasEffect(character, GDConsts.diseaseFx[diseaseIndex], effect) then begin
              GDVars.effectLock := 1;
              FxEngine.RemoveEffect(character, GDConsts.diseaseFx[diseaseIndex], nil);
              GDVars.effectLock := 0;
              wasHealed := 1;
              FxEngine.RecalcAbility(character, C_Stat.STRENGTH);
            end;
          if wasHealed <> 0 then
            CharHlp.PrintCreatureMessage(character, 'is cured of disease', 10, True);
        end;
      if wasHealed = 0 then
        if cureBlindnessCount > 0 then
          if CharHlp.HasEffect(character, C_Effect.BLIND, effect) then begin
            FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
            CharHlp.PrintCreatureMessage(GDVars.curChar, 'regains sight', 10, True);
          end;
      character := character^.nextCharAddr;
    end;
  end;

  { Counts the members needing each status cure; a feebleminded member is not counted as blind or diseased. }
  procedure CountCureNeeds;
  var character: Types.PCharRecord; effect: Types.PEffectRec;
  begin
    deadCount := 0;
    cursedCount := 0;
    blindCount := 0;
    diseasedCount := 0;
    feeblemindedCount := 0;
    poisonedCount := 0;
    petrifiedCount := 0;
    character := GDVars.creatureList;
    while character <> nil do begin
      if (character^.status = C_Status.DEAD_STATUS) and (character^.race <> C_Race.HALF_ELF)
         and (character^.race <> C_Race.ELF) then Inc(deadCount);
      if character^.status = C_Status.PETRIFIED then Inc(petrifiedCount);
      if CharHlp.HasEffect(character, C_Effect.BESTOW_CURSE, effect) then Inc(cursedCount);
      if CharHlp.HasEffect(character, C_Effect.POISONED, effect) then Inc(poisonedCount);
      if CharHlp.HasEffect(character, C_Effect.FEEBLEMINDED, effect) then Inc(feeblemindedCount)
      else begin
        if CharHlp.HasEffect(character, C_Effect.BLIND, effect) then Inc(blindCount);
        if CharHlp.HasEffect(character, C_Effect.DISEASED, effect) then Inc(diseasedCount);
      end;
      character := character^.nextCharAddr;
    end;
  end;

begin
  raiseDeadCount := 0;
  removeCurseCount := 0;
  cureBlindnessCount := 0;
  cureDiseaseCount := 0;
  healCount := 0;
  neutralizePoisonCount := 0;
  stoneToFleshCount := 0;
  interrupted := False;
  healPool := 0;
  if PartyHitPointsMissing <> 0 then begin
    RollMemorizedCures;
    savedRestTime := GDVars.restClock;
    ComputeFixTime;
    interrupted := GameTime.CampRest(0);
    if not interrupted then begin
      RollCureSlots;
      CureStatusEffects;
      HealParty;
      CharHlp.DisplayRoster(GDVars.curChar);
      CharHlp.PrintPositionAndTime;
      GDVars.restClock := savedRestTime;
      savedRestTime := GDVars.restClock;
      CountCureNeeds;
      ComputeCureTime;
      interrupted := GameTime.CampRest(0);
      if not interrupted then begin
        CureStatusEffects;
        CharHlp.DisplayRoster(GDVars.curChar);
        CharHlp.PrintPositionAndTime;
        GDVars.restClock := savedRestTime;
      end;
    end;
  end;
end;

procedure CampMainMenu(var interrupted: Boolean);
var savedIfc: Byte; c: Char; vflag: Boolean; ext: Boolean; savedFlag: Byte;
begin
  savedIfc := GDVars.interfaceState;
  GDVars.interfaceState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  GameIo.FillWord(GDVars.restClock, SizeOf(GDVars.restClock));
  GDVars.savedPicArcName := GDVars.picArcName;
  GDVars.savedPicArcId := GDVars.picArcId;
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(1, 17, 38, 22);
  TextRend.DisplayString(1, 18, LightGreen, 0, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    GDVars.rosterPickMenu := 1;
    c := MenuCore.MenuHorizontal('', GDConsts.campMenu, LightMagenta, LightGreen, White, 1, 1, ext);
    savedFlag := GDVars.horizChoice;
    if ext then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end else
      case c of
        'S': begin
               Inc(GDVars.zone0^.saveCount);
               if GDVars.zone0^.saveCount >= 30 then begin
                 if not Camp.RuleBookCheck then GameIo.ExitGame;
                 CharHlp.DisplayNoncombatInterface;
                 GDVars.zone0^.saveCount := 0;
               end;
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White, 2) = 'Y' then GameIo.ExitGame;
             end;
        'V': begin GDVars.rosterPickMenu := 0; ViewChar.ViewCharMenu(vflag); end;
        'M': begin GDVars.horizChoice := 1; Camp.CampMagicMenu(interrupted); end;
        'R': begin GDVars.horizChoice := 1; Camp.RestForSpellPrep(interrupted); end;
        'F': Camp.CampFixMenu(interrupted);
        'A': begin GDVars.horizChoice := 1; Camp.CampAlterMenu; end;
      end;
    GDVars.horizChoice := savedFlag;
  end;
  if Copy(GDVars.savedPicArcName, 1, 3) = 'PIC' then
    Portrait.LoadAnimation(GDVars.savedPicArcName, GDVars.savedPicArcId, 0, GDVars.animData);
  Camp.ResetPartySpellActivities;
  GDVars.castTarget := nil;
  GDVars.interfaceState := savedIfc;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
end.
