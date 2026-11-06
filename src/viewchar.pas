{ The character sheet, the item and vault inventory menu, and the Heal and Cure handlers. }
{$O+,F+,A-,I-,V-}
unit ViewChar;

interface

uses Types, Magic, Money, FxEngine, CharHlp, ClassCal, MenuCore, CbtMap, Border, TextRend, Crt, GDConsts, GDVars,
  C_Race, C_Status, C_Money, C_Class, C_Keys, C_Ifc, C_Spell, C_Stat;

{ Draws the current character's sheet: name, status, gender and age, alignment, race, class (a human's earlier class
  after a slash while its level is below the current class's), levels (for a human with any earlier-class level, the
  first current class level, then a slash and the earlier class's level while it is below the current class's; otherwise
  each class's level joined by slashes), experience, the six abilities, the money, the combat values, and the readied
  weapon and armor. The character becomes the one the sheet shows. }
procedure DisplayChar;

{ Recalculates the current character's stats and shows its hit points, armor class, encumbrance, THAC0, movement and
  damage dice on the character sheet. }
procedure PrintCombatStats;

{ Draws one of the current character's abilities on its row of the character sheet, in light magenta while modifying and
  light green otherwise. Strength 18 with exceptional strength adds '(NN)', with 100 shown as '(00)'; a '*' marks a
  current value (or exceptional strength) that differs from its base.
  @param(statIdx The ability, 0 to 5.)
  @param(modifying True draws it in the modify color.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Lists the current character's money on the character sheet, one row for each type it has. }
procedure PrintMoney;

{ Shows the character sheet and runs its menu: Items, Spells, Trade (outside combat, for a player character or one out
  of play, with money), Deposit in the vault or Drop elsewhere (with money), Heal and Cure (when the character can), and
  Exit. The sheet is redrawn after items, spells or trade, and the noncombat interface afterwards.
  @param(done Set True when an item use ends the character's turn.) }
procedure ViewCharMenu(var done: Boolean);

{ Runs the current character's item menu: Ready, Use (in play, with no anti-magic, in camp or indoors, or in combat when
  item use is allowed this round), Trade (outside combat, for a player character or one out of play), Deposit in the
  vault or Drop elsewhere, Halve (below 16 items), Join, and in a shop Sell (for a player character or one out of play)
  and Id. A deposited item goes to the end of the vault's list; a dropped one is gone after a Yes. It repeats until
  Exit, Escape, an action that ends the turn, or no items are left; party picks with the mouse are off meanwhile.
  @param(done Set True when an item use ends the character's turn.) }
procedure UseItemMenu(var done: Boolean);

{ Readies or unreadies an item for the current character. A cursed item cannot be unreadied. Readying checks, the later
  checks winning, the free hands, an occupied slot or ammunition slot and the class mask; the hands-full message is
  skipped for a quick-fighting creature in combat. An item with a special above $7F calls its effect handler when
  readied and when unreadied.
  @param(it The item.) }
procedure ToggleReadyItem(it: Types.PItemRec);

{ Uses an item of the current character: a scroll or bundle casts a spell picked from it (reliably for a magic-user or
  cleric, 75 percent of the time for a thief above level 9, and otherwise "oops!"), any other item with a spell effect
  casts that spell. A use that completes spends the scroll's spell, or one of the item's quantity or charges, removing
  an item whose charges run out; in combat a combat spell ends the turn.
  @param(it The item.)
  @param(done Set True when the use completes.) }
procedure UseItem(it: Types.PItemRec; var done: Boolean);

{ Tells whether a character cannot take an item: it already holds 16 items, or the item's weight, times its quantity,
  would take it past its weight allowance plus 1500. The character's stats are recomputed first.
  @param(cr The character.)
  @param(it The item.)
  @returns(True when the character cannot take the item.) }
function CannotCarryItem(cr: Types.PCharRecord; it: Types.PItemRec): Boolean;

{ Makes the previous (up arrow) or next (down arrow) party member current, wrapping at either end; any other key selects
  the first member. Nothing changes after a mouse click.
  @param(c The key's scan code.) }
procedure SelectPrevNextChar(c: Char);

{ Values a creature's coins in gold, rounded down; gems and jewelry are not counted.
  @param(cr The creature.)
  @returns(The value in gold.) }
function CreatureCoinValueInGold(cr: Types.PCharRecord): LongInt;

{ Lists the current character's spells of a kind (memorized, grimoire, scroll, scrolls, choose, memorize, scribe,
  bundle) under its name and lets the player pick one.
  @param(menuType The list kind, 0..7.)
  @param(selType How the list is drawn and chosen from, passed to Magic.SpellSelection.)
  @param(idx The highlighted entry, kept between calls; negative redraws the frame.)
  @param(notEmpty Set True when the list has spells.)
  @returns(The spell picked, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer;
                   var notEmpty: Boolean): Byte;

{ Tells whether a character can lay on hands: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, and not within a day of its last healing.
  @param(cr The character.)
  @returns(True when it can heal.) }
function CanHeal(cr: Types.PCharRecord): Boolean;

{ Tells whether a character can cure disease: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, with a cure left.
  @param(cr The character.)
  @returns(True when it can cure.) }
function CanCure(cr: Types.PCharRecord): Boolean;

{ Lays on hands: the party member the player picks regains 2 hit points per paladin level of the healer (earlier paladin
  levels count while active), who cannot heal again for a day. Picking no one just redraws the sheet.
  @param(cr The paladin.) }
procedure PaladinLayOnHands(cr: Types.PCharRecord);

{ Cures disease: removes the disease effects from a party member the player picks (asking first when it is not
  diseased), uses up one of the character's cures and marks a week's cure effect on it.
  @param(cr The paladin.) }
procedure PaladinCureDisease(cr: Types.PCharRecord);

{ Returns the smaller of two numbers.
  @param(a The first number.)
  @param(b The second number.)
  @returns(The smaller one.) }
function MinOf(a, b: Word): Word;

{ Tells whether an item may be traded, dropped or sold: it must not be readied ("Must be unreadied"), and a scroll the
  character was going to scribe from asks whether losing it is all right. Note: for a bundle the walk tests the bundle
  itself instead of each scroll in it, so it never asks.
  @param(it The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(it: Types.PItemRec): Boolean;

{ Lets the player pick a party member with the arrow keys, allowing party picks with the mouse meanwhile.
  @returns(True when Select was chosen, False on Exit or Escape.) }
function PickCharacter: Boolean;

{ Gives an item to another party member chosen by the player, unless that member cannot carry it.
  @param(it The item.) }
procedure ItemTradeMenu(it: Types.PItemRec);

{ Splits an item's quantity, or a bundle's scrolls, into two stacks, the new half placed after it; a quantity below 2
  cannot be halved.
  @param(it The item.) }
procedure HalveItem(it: Types.PItemRec);

{ Joins items of the current character. A scroll or bundle gathers the character's other scrolls and bundles into one
  bundle of at most 10 scrolls, a scroll first becoming a bundle; it is refused when the bundle is full or nothing else
  can join. Any other item merges each other stack that matches it into it, up to 255 a stack; a stack that would
  overflow keeps the rest, and an item without a quantity cannot be joined. Note: the charges, effect and special tests
  compare each stack with itself, so they always pass.
  @param(it The item to join onto.) }
procedure JoinItem(it: Types.PItemRec);

{ Offers half the item's value for it in a shop (for a stack, that times its quantity, over 20 for arrows and quarrels)
  and, on a deal, removes the item and pays in platinum and gold, the overflow going into the pool. A worthless item can
  be given away instead.
  @param(it The item.) }
procedure SellItem(it: Types.PItemRec);

{ Identifies an item in a shop for 100 gold, paid from the current character's coins or else the pool; a bundle is
  refused.
  @param(it The item.)
  @param(newInfo Set True when the item reveals something new.) }
procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean);

{ Trades coins from the current character to another. The player picks the receiver, then a coin type and an amount up
  to the holding, repeating while coins are left. Note: escaping the coin menu leaves the outer loop's exit flag unset,
  so on the first pass whether the menu ends depends on an uninitialized local. }
procedure TradeTreasureMenu;

{ Lets the current character drop money, or deposit it in the vault, until it has none left or the player leaves. }
procedure DropMoneyMenu;

implementation

const
  { paladin Heal's 24-hour cooldown (1440 minutes), checked by CanHeal }
  EFF_RECENT_HEAL = 109;
  { paladin Cure's seven-day effect (10080 minutes) }
  EFF_RECENT_CURE = 110;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statCol: Byte;
  j: ShortInt;
  i: ShortInt;
  s: String;
  anyShown: Boolean;
  multiSeen: Boolean;
begin
  GDVars.cr := GDVars.curChar;
  Border.DrawCharViewFrame;
  CharHlp.DisplayCreatureName(GDVars.cr, 1, 1, False);
  TextRend.DisplayString(20, 1, White, 0, 'Status:');
  TextRend.DisplayString(27, 1, LightGreen, 0, GDConsts.statusNames[GDVars.cr^.status]);
  s := GDConsts.genderNames[GDVars.cr^.gender];
  TextRend.DisplayString(1, 3, White, 0, s);
  TextRend.DisplayString(8, 3, White, 0, CharHlp.Uint16Str(GDVars.cr^.age) + ' years');
  s := GDConsts.alignNames[GDVars.cr^.alignment];
  TextRend.DisplayString(1, 4, White, 0, s);
  s := GDConsts.raceNames[GDVars.cr^.race];
  TextRend.DisplayString(20, 4, White, 0, s);
  multiSeen := False;
  s := GDConsts.classNames[GDVars.cr^.charClass];
  if GDVars.cr^.race = C_Race.HUMAN then
    for i := C_Class.CLERIC to C_Class.THIEF do
      if GDVars.cr^.classLevelB[i] > 0 then begin
        multiSeen := True;
        if GDVars.cr^.classLevelB[i] < ClassCal.CurrentDualClassLevel(GDVars.cr) then begin
          s := s + '/' + GDConsts.classNames[i];
          i := C_Class.THIEF;
        end;
      end;
  TextRend.DisplayString(1, 5, White, 0, s);
  TextRend.DisplayString(1, 7, White, 0, 'Level');
  s := '';
  if multiSeen then begin
    for i := C_Class.CLERIC to C_Class.THIEF do
      if GDVars.cr^.classLevelA[i] > 0 then begin
        s := s + CharHlp.Uint8Str(GDVars.cr^.classLevelA[i]);
        i := C_Class.THIEF;
      end;
    for i := C_Class.CLERIC to C_Class.THIEF do
      if (GDVars.cr^.classLevelB[i] < ClassCal.CurrentDualClassLevel(GDVars.cr))
         and (GDVars.cr^.classLevelB[i] > 0) then begin
        s := s + '/' + CharHlp.Uint8Str(GDVars.cr^.classLevelB[i]);
        i := C_Class.THIEF;
      end;
  end else begin
    anyShown := False;
    for i := C_Class.CLERIC to C_Class.THIEF do
      if GDVars.cr^.classLevelA[i] > 0 then begin
        if anyShown then
          s := s + '/';
        s := s + CharHlp.Uint8Str(GDVars.cr^.classLevelA[i] + GDVars.cr^.classLevelB[i]);
        anyShown := True;
      end;
  end;
  TextRend.DisplayString(7, 7, White, 0, s);
  TextRend.DisplayString(24, 6, White, 0, 'Experience:');
  s := CharHlp.Int32Str(GDVars.cr^.experience);
  TextRend.DisplayString(20 + ((20 - Length(s)) div 2), 7, LightGreen, 0, s);
  for j := C_Stat.STRENGTH to C_Stat.CHARISMA do begin
    case j of
      C_Stat.STRENGTH: s := 'STR ';
      C_Stat.INTELLIGENCE: s := 'INT ';
      C_Stat.WISDOM: s := 'WIS ';
      C_Stat.DEXTERITY: s := 'DEX ';
      C_Stat.CONSTITUTION: s := 'CON ';
      C_Stat.CHARISMA: s := 'CHA ';
    end;
    TextRend.DisplayString(1, j + 9, LightGreen, 0, s);
    ViewChar.PrintStat(j, False);
  end;
  ViewChar.PrintMoney;
  ViewChar.PrintCombatStats;
  if GDVars.cr^.equippedV1[0] <> nil then
    CharHlp.PrintItemString(GDVars.cr, GDVars.cr^.equippedV1[0], 1, 21, 0, 1);
  if GDVars.cr^.equippedV1[2] <> nil then
    CharHlp.PrintItemString(GDVars.cr, GDVars.cr^.equippedV1[2], 1, 22, 0, 1);
end;

procedure PrintMoney;
var
  row: Byte;
  i: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(20, 9, 38, 15);
  row := 9;
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.curChar^.coinsA[i] > 0 then begin
      s := GDConsts.moneyNames[i];
      TextRend.DisplayString(20, row, LightGreen, 0, s);
      s := CharHlp.Uint16Str(GDVars.curChar^.coinsA[i]);
      TextRend.DisplayString(38 - Length(s), row, LightGreen, 0, s);
      Inc(row);
    end;
end;

procedure PrintCombatStats;
var
  c: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  moveMax: Byte;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  eff: LongInt;

  { Pads t with leading spaces to width. }
  procedure RightAlignField(var t: Types.TStr40; width: Byte);
  begin
    while Length(t) < width do
      t := ' ' + t;
  end;

begin
  c := GDVars.curChar;
  CharHlp.RecalcStats(c);
  TextRend.DisplayString(20, 3, White, 0, 'Hit Points ');
  Border.ClearBox(31, 3, 37, 3);
  CharHlp.PrintHitPoints(c, 31, 3, 0, 1);
  TextRend.DisplayString(1, 17, White, 0, 'Armor Class');
  case c^.acCurArr[0] of
    1..50: color := 16;
    51..60: color := 17;
    61..69: color := 16;
  else
    color := 15;
  end;
  Border.ClearBox(15, 17, 17, 17);
  CharHlp.PrintArmorClass(c, color, 17);
  TextRend.DisplayString(20, 17, White, 0, 'Encumbrance');
  s := CharHlp.Uint16Str(c^.encumbrance);
  RightAlignField(s, 5);
  TextRend.DisplayString(33, 17, LightGreen, 0, s);
  TextRend.DisplayString(1, 18, White, 0, 'THAC0   ');
  Str(60 - c^.toHitCur, s);
  RightAlignField(s, 2);
  TextRend.DisplayString(16, 18, LightGreen, 0, s);
  TextRend.DisplayString(20, 18, White, 0, 'Movement');
  moveMax := CharHlp.RecalcMovement(c);
  s := CharHlp.Uint8Str(c^.movementCur);
  RightAlignField(s, 3);
  TextRend.DisplayString(35, 18, LightGreen, 0, s);
  s := CharHlp.Uint8Str(c^.dmgDice) + 'd' + CharHlp.Uint8Str(c^.dmgSides);
  if c^.dmgBonus > 0 then
    s := s + '+' + CharHlp.Uint8Str(c^.dmgBonus);
  if c^.dmgBonus < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(c^.dmgBonus));
  TextRend.DisplayString(1, 19, White, 0, 'Damage');
  RightAlignField(s, 7);
  TextRend.DisplayString(11, 19, LightGreen, 0, s);
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  color: Byte;
begin
  if modifying then
    color := LightMagenta
  else
    color := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 9, 11, statIdx + 9);
  if GDVars.curChar^.stats[statIdx].cur < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 9, color, 0, CharHlp.Uint8Str(GDVars.curChar^.stats[statIdx].cur));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.stats[C_Stat.STRENGTH].cur = 18)
     and (GDVars.curChar^.strExc > 0) then begin
    s := CharHlp.Uint8Str(GDVars.curChar^.strExc);
    if GDVars.curChar^.strExc < 10 then
      s := '0' + s;
    if GDVars.curChar^.strExc = 100 then
      s := '00';
    TextRend.DisplayString(7, 9, color, 0, '(' + s + ')');
  end;
  if (GDVars.curChar^.stats[statIdx].cur <> GDVars.curChar^.stats[statIdx].base)
     or ((statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.strExcMax <> GDVars.curChar^.strExc)) then
    TextRend.DisplayString(12, statIdx + 9, color, 0, '*');
end;

procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  menuStr: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
  savedFlag: Byte;
begin
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  GDVars.viewedChar := GDVars.curChar;
  ViewChar.DisplayChar;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    menuStr := '';
    hasSpells := False;
    hasMoney := False;
    for i := 0 to 74 do
      if GDVars.cr^.spellsMem[i] > 0 then
        hasSpells := True;
    for j := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.cr^.coinsA[j] > 0 then
        hasMoney := True;
    if GDVars.cr^.itemsAddr <> nil then
      menuStr := menuStr + 'Items ';
    if hasSpells then
      menuStr := menuStr + 'Spells ';
    if ((GDVars.cr^.npc < $80) or (GDVars.cr^.enabled = 0))
       and hasMoney and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
      menuStr := menuStr + 'Trade ';
    if hasMoney then
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        menuStr := menuStr + 'Deposit '
      else
        menuStr := menuStr + 'Drop ';
    if ViewChar.CanHeal(GDVars.curChar) then
      menuStr := menuStr + 'Heal ';
    if ViewChar.CanCure(GDVars.curChar) then
      menuStr := menuStr + 'Cure ';
    menuStr := menuStr + 'Exit';
    ch := MenuCore.MenuHorizontal('', menuStr, LightMagenta, LightGreen, White, 0, 0, ext);
    idx := -1;
    savedFlag := GDVars.horizChoice;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             GDVars.horizChoice := 1;
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
           end;
      'H': if not ext then
             ViewChar.PaladinLayOnHands(GDVars.curChar);
      'C': ViewChar.PaladinCureDisease(GDVars.curChar);
    end;
    GDVars.horizChoice := savedFlag;
    if not done and (ch in ['I', 'S', 'T']) then
      ViewChar.DisplayChar;
  end;
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then
    CbtMap.SetCombatPalette;
  CharHlp.DisplayNoncombatInterface;
end;

function CheckItemAvail(it: Types.PItemRec): Boolean;
var
  p: Types.PItemRec;
begin
  CheckItemAvail := False;
  if it^.readied <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(it) then
    CheckItemAvail := True
  else if (it^.scribe0 > $7F) or (it^.scribe1 > $7F)
          or (it^.scribe2 > $7F) then begin
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White, 2) = 'Y' then
      CheckItemAvail := True;
  end else if it^.kind = 'I' then
  begin
    p := it;
    CheckItemAvail := False;
    while p^.bundleNext <> nil do begin
      if (it^.scribe0 > $7F) or (it^.scribe1 > $7F)
         or (it^.scribe2 > $7F) then begin
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
        GDVars.curCol := Length(GDVars.curChar^.name) + 2;
        GDVars.curRow := 21;
        TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, False, ' was going to scribe from that bundle');
        if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White, 2) = 'N' then
          CheckItemAvail := False;
        Border.ClearBox(1, 21, 38, 22);
        Exit;
      end;
      p := p^.bundleNext;
    end;
    CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  menuStr: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  needHeader: Boolean;
  redraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  prevItem: LongInt;
  who: Types.PCharRecord;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
  savedChoice: Byte;
  savedRosterPick: Byte;
begin
  savedRosterPick := GDVars.rosterPickMenu;
  GDVars.rosterPickMenu := 0;
  who := GDVars.curChar;
  ch := ' ';
  sel := who^.itemsAddr;
  idx := 0;
  redraw := True;
  needHeader := True;
  while not (ch in [C_Keys.NONE, 'E']) and not done and (who^.numItems > 0) do
  begin
    itemCount := who^.numItems;
    if who^.itemsAddr <> nil then begin
      menuStr := 'Ready';
      if (who^.enabled <> 0) and (GDVars.zone0^.antimagic = 0)
         and
           ((GDVars.interfaceState = C_Ifc.CAMPING) or (GDVars.interfaceState = C_Ifc.INDOORS) or
            ((GDVars.interfaceState = C_Ifc.IN_COMBAT) and (who^.combatAddrV1^.itemUseAllowed <> 0))) then
        menuStr := menuStr + ' Use';
      if ((who^.npc < $80) or (who^.enabled = 0)) and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then
        menuStr := menuStr + ' Trade';
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        menuStr := menuStr + ' Deposit'
      else
        menuStr := menuStr + ' Drop';
      if who^.numItems < 16 then
        menuStr := menuStr + ' Halve';
      menuStr := menuStr + ' Join';
      if ((who^.npc < $80) or (who^.enabled = 0)) and (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE) then
        menuStr := menuStr + ' Sell';
      if GDVars.interfaceState = C_Ifc.SHOP_TEMPLE then
        menuStr := menuStr + ' Id';
      p := who^.itemsAddr;
      while p <> nil do begin
        CharHlp.PrintItemString(who, p, 0, 0, 1, 0);
        p := p^.next;
      end;
      if needHeader or (GDVars.redrawInvMenu <> 0) then begin
        Border.DrawListFrame;
        CharHlp.DisplayCreatureName(who, 1, 1, True);
        TextRend.DisplayString(Length(who^.name) + 4, 1, LightGreen, 0, 'Items');
        TextRend.DisplayString(1, 3, White, 0, 'Ready Item');
        redraw := True;
        needHeader := False;
        GDVars.redrawInvMenu := 0;
      end;
      ch := MenuCore.MenuVertical('', menuStr, LightMagenta, LightGreen, White, 1, 5, 38, 22, who^.itemsAddr, 1,
                                  redraw, idx, sel);
      savedChoice := GDVars.horizChoice;
      if sel <> nil then
        case ch of
          'R': ViewChar.ToggleReadyItem(sel);
          'U': if sel^.readied = 0 then
               begin
                 CharHlp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if Magic.ItemReadable(sel)
                       or ((sel^.scribe1 > 0) and (sel^.scribe2 < $80)) then begin
                 ViewChar.UseItem(sel, done);
                 if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
                   done := False;
                 if not done then
                   needHeader := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needHeader := True;
               end;
          'D': if ViewChar.CheckItemAvail(sel) then
               begin
                 GDVars.vaultCur := GDVars.treasureItems;
                 while (GDVars.vaultCur <> nil) and (GDVars.vaultCur^.next <> nil) do
                   GDVars.vaultCur := GDVars.vaultCur^.next;
                 CharHlp.PrintItemString(who, sel, 0, 0, 0, 0);
                 if GDVars.interfaceState = C_Ifc.IN_VAULT then begin
                   TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                        'Your ' + sel^.nameV1 + 'will be left in the vault');
                   TextRend.PauseOnly;
                   if GDVars.treasureItems = nil then begin
                     New(GDVars.treasureItems);
                     GDVars.vaultCur := GDVars.treasureItems;
                   end else begin
                     New(GDVars.vaultCur^.next);
                     GDVars.vaultCur := GDVars.vaultCur^.next;
                   end;
                   GDVars.vaultCur^ := sel^;
                   GDVars.vaultCur^.next := nil;
                   if sel^.kind = 'I' then
                     sel^.bundleNext := nil;
                   CharHlp.RemoveItem(who, sel);
                   redraw := True;
                 end else begin
                   TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                                 'Your ' + sel^.nameV1 + 'will be gone forever');
                   if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White, 2) = 'Y' then
                   begin
                     CharHlp.RemoveItem(GDVars.curChar, sel);
                     redraw := True;
                   end;
                 end;
                 Border.ClearBox(1, 21, 38, 22);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': begin
                 ViewChar.JoinItem(sel);
                 redraw := True;
               end;
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, redraw);
        end;
      GDVars.horizChoice := savedChoice;
      CharHlp.RecalcStats(who);
    end;
    if who^.numItems <> itemCount then
      redraw := True;
  end;
  GDVars.rosterPickMenu := savedRosterPick;
end;

{ Turns an item's special effect on or off: effect 0 runs the effect's handler, effect 1 doubles the level 5 magic-user
  spell slots when readied and, when unreadied, works them out again from the magic-user level and forgets the memorized
  level 5 magic-user spells beyond them, effects 3 and 5 recalculate Strength, and unreadying effect 9 removes effect
  23. Note: the count of memorized spells starts uninitialized.
  @param(it The item.)
  @param(equipping True when the item is being readied.) }
procedure ToggleItemEffect(it: Types.PItemRec; equipping: Boolean);
var
  kind: Byte;
  lim2: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  damage: Byte;
  cr: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  lim: ShortInt;
  i: ShortInt;
  n: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lvl: Byte;
  cnt: Byte;
begin
  cr := GDVars.curChar;
  kind := it^.scribe2 and $7F;
  case kind of
    0: begin
         GDVars.overrideFlag := 1;
         FxEngine.CallEffectHandler(it^.scribe1, cr, it, not equipping);
       end;
    1: if equipping then begin
         n := cr^.spellSlots[C_Spell.MAGE_LIST, 5] * 2;
         cr^.spellSlots[C_Spell.MAGE_LIST, 5] := n;
       end else begin
         lim2 := Ord(ClassCal.EarlierClassActive(cr)) * cr^.classLevelB[C_Class.MAGE]
                 + cr^.classLevelA[C_Class.MAGE];
         lim := lim2;
         cr^.spellSlots[C_Spell.MAGE_LIST, 5] := 0;
         for i := 9 to lim do
           Inc(cr^.spellSlots[C_Spell.MAGE_LIST, 5], GDConsts.classProgression[C_Class.MAGE].spellSlots[i, 5]);
         for n := 0 to 74 do
           if (cr^.spellsMem[n] <> 0)
              and (GDConsts.spellDefs[cr^.spellsMem[n]].castClass = C_Spell.MAGE_LIST)
              and (GDConsts.spellDefs[cr^.spellsMem[n]].level = 5) then begin
             Inc(cnt);
             if cnt > cr^.spellSlots[C_Spell.MAGE_LIST, 5] then
               cr^.spellsMem[n] := 0;
           end;
       end;
    3: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    5: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    9: if not equipping then
         FxEngine.RemoveEffect(cr, 23, nil);
  end;
end;

procedure ToggleReadyItem(it: Types.PItemRec);
var
  hasEffect: Boolean;
  reason: Byte;
  slot: Byte;
  cr: Types.PCharRecord;
begin
  hasEffect := it^.scribe2 > $7F;
  cr := GDVars.curChar;
  if it^.readied <> 0 then begin
    if it^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed!')
    else begin
      it^.readied := 0;
      if hasEffect then
        ViewChar.ToggleItemEffect(it, False);
    end;
  end else begin
    reason := 0;
    if cr^.handsUsed + GDVars.baseItems[Ord(it^.kind)].hands > 2 then
      reason := 3;
    slot := GDVars.baseItems[Ord(it^.kind)].slot;
    case slot of
      0..8: if cr^.equippedV1[ShortInt(slot)] <> nil then
              reason := 2;
      9: if cr^.slot9Addr <> nil then
              reason := 2;
    end;
    if (it^.kind = #30) and (cr^.arrowsAddr <> nil) then begin
      reason := 2;
      slot := 11;
    end;
    if (it^.kind = #12) and (cr^.quarrelsAddr <> nil) then begin
      reason := 2;
      slot := 12;
    end;
    if GDVars.baseItems[Ord(it^.kind)].classMask and cr^.classBits = 0 then
      reason := 1;
    case reason of
      0: begin
           it^.readied := 1;
           if hasEffect then
             ViewChar.ToggleItemEffect(it, True);
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, cr^.equippedV1[ShortInt(slot)], 0, 0, 0, 0);
           CharHlp.PrintBottomLine('already using ' + cr^.equippedV1[ShortInt(slot)]^.nameV1);
         end;
      3: if (GDVars.interfaceState <> C_Ifc.IN_COMBAT) or (cr^.quickfight = 0) then
           CharHlp.PrintBottomLine('Your hands are full!');
    end;
  end;
end;

procedure ItemTradeMenu(it: Types.PItemRec);
var
  who: Types.PCharRecord;
begin
  who := GDVars.viewedChar;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', 1, 1, who);
  if who <> nil then begin
    GDVars.viewedChar := who;
    if ViewChar.CannotCarryItem(who, it) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(who, it);
      if it^.kind = 'I' then
        it^.bundleNext := nil;
      CharHlp.RemoveItem(GDVars.curChar, it);
      CharHlp.RecalcStats(who);
    end;
  end;
end;

procedure HalveItem(it: Types.PItemRec);
var
  newItem: Types.PItemRec;
  walker: Types.PItemRec;
  half: Byte;
  rest: Byte;
begin
  half := it^.count div 2;
  if half > 0 then begin
    if it^.kind = 'I' then
    begin
      rest := it^.count - half;
      New(newItem);
      newItem^ := it^;
      if half = 1 then
        newItem^ := newItem^.bundleNext^
      else begin
        newItem^.count := half;
        newItem^.bundleQuantity := half;
        newItem^.secondNameId := half;
        walker := newItem;
        newItem^.bundleWeight := 0;
        for GDVars.loopIdx := 1 to half do begin
          walker := walker^.bundleNext;
          Inc(newItem^.bundleWeight, walker^.bundleWeight);
        end;
      end;
      newItem^.readied := 0;
      newItem^.next := it^.next;
      if rest = 1 then begin
        if half = 1 then
          it^ := it^.bundleNext^.bundleNext^
        else
          it^ := it^.bundleNext^.bundleNext^.bundleNext^;
        it^.bundleNext := nil;
      end else begin
        it^.count := rest;
        it^.bundleQuantity := rest;
        it^.secondNameId := rest;
        for GDVars.loopIdx := 1 to half do begin
          Dec(it^.bundleWeight, it^.bundleNext^.bundleWeight);
          it^.bundleNext := it^.bundleNext^.bundleNext;
        end;
      end;
      if half = 1 then
        newItem^.bundleNext := nil
      else
        walker^.bundleNext := nil;
      it^.next := newItem;
    end else begin
      rest := it^.count - half;
      New(newItem);
      Move(it^, newItem^, SizeOf(it^));
      newItem^.count := half;
      newItem^.readied := 0;
      newItem^.next := it^.next;
      it^.count := rest;
      it^.next := newItem;
    end;
  end else
    CharHlp.PrintBottomLine('Can''t halve that');
end;

procedure JoinItem(it: Types.PItemRec);
var
  cur: Types.PItemRec;
  p: Types.PItemRec;
  nextP: Types.PItemRec;
  target: Types.PItemRec;
  total: Byte;
  i: Byte;
  countStr: string[4];
begin
  target := it;
  if (target^.kind = #39) or (target^.kind = #40)
     or (target^.kind = 'I') then
  begin
    if target^.count >= 10 then begin
      Str(10, countStr);
      CharHlp.PrintBottomLine('Bundles are limited to ' + countStr + ' scrolls.');
      Exit;
    end;
    total := 0;
      p := GDVars.curChar^.itemsAddr;
      while p <> nil do begin
        if ((p^.kind = 'I') and (p^.count < 10))
           or (p^.kind = #39) or (p^.kind = #40) then
          Inc(total);
        p := p^.next;
      end;
    if total < 2 then begin
      CharHlp.PrintBottomLine('There are no similar items to join with.');
      Exit;
    end;
    if target^.kind <> 'I' then
        begin
          New(target^.bundleNext);
          cur := target^.bundleNext;
          cur^ := target^;
          cur^.bundleNext := nil;
          target^.readied := 0;
          target^.thirdNameId := 77;
          target^.secondNameId := 1;
          target^.firstNameId := 39;
          target^.scribe0 := 0;
          target^.scribe1 := 0;
          target^.scribe2 := 0;
          target^.count := 1;
          target^.kind := 'I';
          target^.idFlags := 0;
        end else begin
          cur := target;
          for i := 1 to target^.count do
            cur := cur^.bundleNext;
          cur^.bundleNext := nil;
        end;
        p := GDVars.curChar^.itemsAddr;
        while (p <> nil) and (target^.count < 10) do begin
          nextP := p^.next;
          if p <> target then
            if ((p^.kind = 'I') and (p^.count < 10) and (p^.count + target^.count <= 10))
               or (p^.kind = #39) or (p^.kind = #40) then begin
              New(cur^.bundleNext);
              cur := cur^.bundleNext;
              if p^.kind = 'I' then
              begin
                cur^ := p^.bundleNext^;
                Inc(target^.bundleWeight, p^.bundleWeight);
                Inc(target^.count, p^.count);
                for i := 1 to p^.count - 1 do
                  cur := cur^.bundleNext;
              end else begin
                cur^ := p^;
                Inc(target^.count);
                Inc(target^.bundleWeight, cur^.bundleWeight);
                cur^.bundleNext := nil;
              end;
              target^.secondNameId := target^.count;
              target^.bundleQuantity := target^.count;
              p^.bundleNext := nil;
              CharHlp.RemoveItem(GDVars.curChar, p);
            end;
      p := nextP;
    end;
  end else begin
    if target^.count = 0 then
      CharHlp.PrintBottomLine('That cannot be joined with other items.')
    else begin
      total := target^.count;
      p := GDVars.curChar^.itemsAddr;
      while p <> nil do begin
        nextP := p^.next;
        if (p <> target) and (p^.firstNameId = target^.firstNameId)
           and (p^.secondNameId = target^.secondNameId) and (p^.thirdNameId = target^.thirdNameId)
           and (p^.kind = target^.kind) and (p^.plusV2 = target^.plusV2)
           and (p^.saveBonusV1 = target^.saveBonusV1) and (p^.cursed = target^.cursed)
           and (p^.scribe0 = p^.scribe0) and (p^.scribe0 < 2)
           and (p^.scribe1 = p^.scribe1) and (p^.scribe2 = p^.scribe2) then begin
          if total + p^.count <= 255 then begin
            Inc(total, p^.count);
            CharHlp.RemoveItem(GDVars.curChar, p);
          end else begin
            target^.count := 255;
            p^.count := p^.count - (255 - total);
            total := p^.count;
            target := p;
            CharHlp.PrintItemString(GDVars.curChar, target, 0, 0, 0, 0);
          end;
        end;
        p := nextP;
      end;
      target^.count := total;
    end;
  end;
end;

procedure UseItem(it: Types.PItemRec; var done: Boolean);
var
  eff: Byte;
  idx: Integer;
  ok: Boolean;
begin
  idx := -1;
  GDVars.usingItemFlag := 0;
  eff := 0;
  if Magic.ItemReadable(it) then begin
    GDVars.useItem := it;
    if GDVars.useItem^.kind = 'I' then
      eff := ViewChar.SpellMenu(7, 1, idx, ok)
    else
      eff := ViewChar.SpellMenu(2, 1, idx, ok);
  end else if (it^.scribe1 > 0) and (it^.scribe2 < $80) then begin
    GDVars.usingItemFlag := 1;
    eff := it^.scribe1 and $7F;
  end;
  if eff = 0 then
    done := False
  else begin
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItemFlag <> 0 then begin
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'uses an item', 10, False);
      if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, 0, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, it, 5, 23, 0, 1);
      end else
        CharHlp.PrintItemString(GDVars.curChar, it, 1, 22, 0, 1);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
    end;
    GDVars.usingItemFlag := 1;
    if Magic.ItemReadable(it) then begin
      if (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.MAGE) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.MAGE) or
          (ClassCal.FirstEarlierClass(GDVars.curChar) = C_Class.CLERIC) or
          (ClassCal.FirstCurrentClass(GDVars.curChar) = C_Class.CLERIC) or
          (GDVars.curChar^.classLevelA[C_Class.MAGE] > 0) or (GDVars.curChar^.classLevelA[C_Class.CLERIC] > 0) then
        Magic.CastSpell(eff, Boolean(GDVars.curChar^.quickfight), False, done)
      else if (GDVars.curChar^.classLevelA[C_Class.THIEF] > 9)
              and (FxEngine.RollDice(1, 100) <= 75) then
        Magic.CastSpell(eff, Boolean(GDVars.curChar^.quickfight), False, done)
      else
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'oops!', GDVars.curRow + 1, True);
    end else
      Magic.CastSpell(eff, Boolean(GDVars.curChar^.quickfight), False, done);
    GDVars.usingItemFlag := 0;
    if (GDVars.interfaceState = C_Ifc.IN_COMBAT) and
        (GDConsts.spellDefs[eff].castContext <> C_Spell.CAMP_ONLY) then
      done := CharHlp.EndActions(GDVars.curChar);
  end;
  if done then begin
    if Magic.ItemReadable(it) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, it, eff)
    else if it^.scribe0 > 0 then begin
      if it^.count > 1 then
        Dec(it^.count)
      else begin
        Dec(it^.scribe0);
        if it^.scribe0 = 0 then
          CharHlp.RemoveItem(GDVars.curChar, it);
      end;
    end;
  end;
end;

procedure SellItem(it: Types.PItemRec);
var
  value: Word;
  gold: Word;
  takable: LongInt;
  t: LongInt;
  s: Types.TStr40;
  q: Word;
  r: Word;
begin
  value := 0;
  if it^.bundleWeight > 0 then
    value := it^.bundleWeight div 2;
  if (it^.count > 1) and (it^.kind <> 'I') then
  begin
    if (it^.kind = #30) or (it^.kind = #12) then
      value := it^.count * value div 20
    else
      value := it^.count * value;
  end;
  CharHlp.PrintItemString(GDVars.cr, it, 0, 0, 0, 0);
  if value > 0 then begin
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                         'I''ll give you ' + CharHlp.Uint16Str(value) + ' gold pieces for your ' + it^.nameV1);
    s := 'Will you sell ';
    if (it^.count < 2) or (it^.kind = 'I') then
      s := s + 'it? '
    else
      s := s + 'them? ';
  end else begin
    if it^.count < 2 then begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True, 'Your ' + it^.nameV1 + ' is worthless to me.');
      s := 'Shall I dispose of it for you? ';
    end else begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True, 'Your ' + it^.nameV1 + ' are worthless.');
      s := 'Would you like to discard them? ';
    end;
  end;
  if MenuCore.YesNoMenu(s, LightMagenta, LightGreen, White, 1) = 'Y' then
  begin
    if value > 0 then
      CharHlp.PrintBottomLine('Sold!')
    else if it^.count < 2 then
      CharHlp.PrintBottomLine('I will give it to one of my sons.')
    else
      CharHlp.PrintBottomLine('Very well.  I''ll take them.');
    CharHlp.RemoveItem(GDVars.curChar, it);
    gold := value;
    q := value div 5;
    r := value mod 5;
    if Money.CheckOverload(GDVars.curChar, gold, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      t := ViewChar.MinOf(takable, q);
      Inc(GDVars.curChar^.coinsA[C_Money.PLATINUM], t);
      Dec(q, t);
      Dec(takable, t);
      t := ViewChar.MinOf(takable, r);
      Inc(GDVars.curChar^.coinsA[C_Money.GOLD], t);
      Dec(r, t);
      Dec(takable, t);
      GDVars.treasureMoney[C_Money.PLATINUM] := GDVars.treasureMoney[C_Money.PLATINUM] + q;
      GDVars.treasureMoney[C_Money.GOLD] := GDVars.treasureMoney[C_Money.GOLD] + r;
    end else begin
      Inc(GDVars.curChar^.coinsA[C_Money.PLATINUM], q);
      Inc(GDVars.curChar^.coinsA[C_Money.GOLD], r);
    end;
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure IdentifyItem(it: Types.PItemRec; var newInfo: Boolean);
var
  charGold: LongInt;
  poolGold: LongInt;
  paid: Boolean;
begin
  { kind = 'I' is the bundle marker. }
  if it^.kind = 'I' then
  begin
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True, 'Fool! You must remove them from the bundle first!');
    Exit;
  end;
  paid := False;
  CharHlp.PrintItemString(GDVars.cr, it, 0, 0, 0, 0);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                'For 100 gold pieces I''ll identify your ' + it^.nameV1);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White, 1) = 'Y' then
  begin
    charGold := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
    if charGold >= 100 then begin
      paid := True;
      Dec(charGold, 100);
      Money.SetCreatureCoinsInGold(charGold);
    end else begin
      poolGold := Money.CoinValueInGold(GDVars.treasureMoney);
      if poolGold >= 100 then begin
        paid := True;
        Dec(poolGold, 100);
        Money.SetTreasureCoinsInGold(poolGold);
      end else
        CharHlp.PrintBottomLine('Not Enough Money');
    end;
  end;
  if paid then begin
    if (it^.idFlags and 7) = 0 then
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True,
                                    'I can''t tell anything new about your ' + it^.nameV1)
    else begin
      it^.idFlags := it^.idFlags and $F8;
      CharHlp.PrintItemString(GDVars.cr, it, 0, 0, 0, 0);
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, 0, True, 'It looks like some sort of ' + it^.nameV1);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.PauseOnly;
  Border.ClearBox(1, 21, 38, 22);
end;

procedure TradeTreasureMenu;
var
  target: Types.PCharRecord;
  i: ShortInt;
  mType: ShortInt;
  j: Byte;
  fillCount: Byte;
  head: Types.PItemRec;
  sel: Types.PItemRec;
  listHead: Types.PItemRec;
  count: Word;
  idx: Integer;
  qty: string[15];
  spaces: string[15];
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: LongInt;
  doneOuter: Boolean;
  doneInner: Boolean;
  redraw: Boolean;
begin
  repeat
    target := GDVars.viewedChar;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar('Trade to?', 1, 1, target);
    if target = nil then
      doneOuter := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.viewedChar := target;
        head := nil;
        sel := nil;
        listHead := nil;
        count := 0;
        { The loop counts down, so the list is built tail-first and comes out in ascending coin order. }
        for i := C_Money.JEWELRY downto C_Money.COPPER do
          if GDVars.curChar^.coinsA[i] <> 0 then begin
            Inc(count);
            if head = nil then begin
              GetMem(head, SizeOf(Types.TItemNode));
              head^.next := nil;
            end else begin
              sel := head;
              GetMem(head, SizeOf(Types.TItemNode));
              head^.next := sel;
            end;
            qty := CharHlp.Uint16Str(GDVars.curChar^.coinsA[i]);
            fillCount := 14 - Length(GDConsts.moneyNames[i]);
            spaces := '';
            for j := 1 to fillCount do
              spaces := spaces + ' ';
            head^.name := GDConsts.moneyNames[i] + spaces + qty;
            head^.isHeader := 0;
          end;
        listHead := head;
        idx := 0;
        redraw := True;
        ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 38, 15,
                                    head, 1, redraw, idx, sel);
        if sel = nil then
          doneInner := True
        else begin
          s := '';
          mType := Money.ParseMoneyType(sel^.name, s);
          s := 'How much ' + s + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], s, LightGreen);
          Money.TradeMoney(GDVars.curChar, target, amount, mType);
          doneInner := True;
          doneOuter := True;
          for i := C_Money.COPPER to C_Money.JEWELRY do
            if GDVars.curChar^.coinsA[i] > 0 then begin
              doneOuter := False;
              doneInner := False;
            end;
        end;
        if listHead <> nil then
          MenuCore.FreeStringList(listHead);
      until doneInner;
    end;
  until doneOuter;
end;

procedure DropMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  fillCount: Byte;
  j: Byte;
  count: Word;
  idx: Integer;
  head: Types.PItemRec;
  sel: Types.PItemRec;
  listHead: Types.PItemRec;
  done: Boolean;
  redraw: Boolean;
  qty: string[15];
  spaces: string[15];
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
  amount: LongInt;
begin
  repeat
    ViewChar.PrintMoney;
    head := nil;
    sel := nil;
    listHead := nil;
    count := 0;
    for i := C_Money.JEWELRY downto C_Money.COPPER do
      if GDVars.curChar^.coinsA[i] <> 0 then begin
        Inc(count);
        if head = nil then begin
          GetMem(head, SizeOf(Types.TItemNode));
          head^.next := nil;
        end else begin
          sel := head;
          GetMem(head, SizeOf(Types.TItemNode));
          head^.next := sel;
        end;
        qty := CharHlp.Uint16Str(GDVars.curChar^.coinsA[i]);
        fillCount := 18 - Length(GDConsts.moneyNames[i]) - Length(qty);
        spaces := '';
        for j := 1 to fillCount do
          spaces := spaces + ' ';
        head^.name := GDConsts.moneyNames[i] + spaces + qty;
        head^.isHeader := 0;
      end;
    listHead := head;
    idx := 0;
    redraw := True;
    ch := MenuCore.MenuVertical('Select type of coin ', ' Select', LightMagenta, LightGreen, White, 20, 9, 38, 15, head,
                                1, redraw, idx, sel);
    if sel = nil then
      done := True
    else begin
      s := '';
      mType := Money.ParseMoneyType(sel^.name, s);
      { interfaceState 8 is the vault, where money is deposited rather than dropped on the floor. }
      if GDVars.interfaceState = C_Ifc.IN_VAULT then
        s := 'How much ' + s + 'will you deposit? '
      else
        s := 'How much ' + s + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coinsA[mType], s, LightGreen);
      Money.DropMoney(GDVars.curChar, amount, mType);
      done := True;
      for i := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.curChar^.coinsA[i] > 0 then
          done := False;
    end;
    if listHead <> nil then
      MenuCore.FreeStringList(listHead);
  until done;
end;

function CannotCarryItem(cr: Types.PCharRecord; it: Types.PItemRec): Boolean;
var
  cannot: Boolean;
  w: Word;
begin
  CharHlp.RecalcStats(cr);
  cannot := False;
  if cr^.numItems > 15 then
    cannot := True;
  w := it^.bundleQuantity;
  if it^.count > 0 then
    w := it^.count * w;
  if cr^.encumbrance + w > CharHlp.WeightAllowance(cr) + 1500 then
    cannot := True;
  CannotCarryItem := cannot;
end;

procedure SelectPrevNextChar(c: Char);
var
  p: Types.PCharRecord;
begin
  if GDVars.mouseOn and GDVars.mouseClk then
    Exit;
  p := GDVars.creatureList;
  if p <> nil then
    case c of
      C_Keys.UP: if p = GDVars.curChar then begin
             while p^.nextCharAddr <> nil do
               p := p^.nextCharAddr;
           end else
             while (p <> nil) and (p^.nextCharAddr <> GDVars.curChar) do
               p := p^.nextCharAddr;
      C_Keys.DOWN: if GDVars.curChar^.nextCharAddr <> nil then
             p := GDVars.curChar^.nextCharAddr;
    else
      p := GDVars.creatureList;
    end;
  GDVars.curChar := p;
end;

function CreatureCoinValueInGold(cr: Types.PCharRecord): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_Money.COPPER to C_Money.PLATINUM do
    Inc(total, GDConsts.coinValue[i] * cr^.coinsA[i]);
  CreatureCoinValueInGold := total div GDConsts.coinValue[C_Money.GOLD];
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Grimoire';
    2: s := 'on Scroll';
    7: s := 'in Bundle';
    3: s := 'on Scrolls';
    4: s := 'to Choose';
    5: s := 'to Memorize';
    6: s := 'to Scribe';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then begin
      if selType = 2 then
        Border.DrawMemorizeFrame
      else
        Border.DrawListFrame;
    end;
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
    TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, 0, 'Spells ' + s);
    SpellMenu := Magic.SpellSelection(selType, idx);
  end else
    SpellMenu := 0;
end;

function CanHeal(cr: Types.PCharRecord): Boolean;
var
  eff: Types.PEffectRec;
begin
  CanHeal := ((cr^.charClass = C_Class.PALADIN) or ((cr^.classLevelB[C_Class.PALADIN] > 0) and
                                                    ClassCal.EarlierClassActive(cr))) and
    (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and (not CharHlp.HasEffect(cr,
        ViewChar.EFF_RECENT_HEAL, eff));
end;

function CanCure(cr: Types.PCharRecord): Boolean;
begin
  CanCure := ((cr^.charClass = C_Class.PALADIN) or ((cr^.classLevelB[C_Class.PALADIN] > 0) and
                                                    ClassCal.EarlierClassActive(cr))) and
    (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and (cr^.cureDiseaseLeft > 0);
end;

procedure PaladinLayOnHands(cr: Types.PCharRecord);
var
  target: Types.PCharRecord;
begin
  CharHlp.DisplayNoncombatInterface;
  target := GDVars.creatureList;
  CharHlp.SelectChar('Heal whom? ', 1, 0, target);
  if target = nil then begin
    ViewChar.DisplayChar;
    Exit;
  end;
  if FxEngine.RestoreHitPoints(target,
                               (cr^.classLevelA[C_Class.PALADIN] +
                                cr^.classLevelB[C_Class.PALADIN] * Ord(ClassCal.EarlierClassActive(cr))) *
      2, 0) then
    CharHlp.PrintBottomLine(target^.name + ' feels better')
  else
    CharHlp.PrintBottomLine(target^.name + ' is unaffected');
  FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_HEAL, 1440, 0, 0);
  ViewChar.DisplayChar;
end;

procedure PaladinCureDisease(cr: Types.PCharRecord);
var
  target: Types.PCharRecord;
  found: Boolean;
  ch: Char;
  eff: Types.PEffectRec;
begin
  CharHlp.DisplayNoncombatInterface;
  target := GDVars.creatureList;
  CharHlp.SelectChar('Cure whom? ', 1, 0, target);
  if target = nil then begin
    ViewChar.DisplayChar;
    Exit;
  end;
  found := False;
  for GDVars.loopIdx := 1 to 4 do
    if CharHlp.HasEffect(target, GDConsts.diseaseFx[GDVars.loopIdx], eff) then
      found := True;
  ch := 'Y';
  if not found then begin
    CharHlp.PrintCreatureMessage(target, 'is not diseased', 0, False);
    ch := MenuCore.YesNoMenu('cure anyway: ', LightMagenta, LightGreen, White, 2);
    CharHlp.ClearMessageWindow;
  end;
  if ch = 'Y' then
  begin
    GDVars.effectLock := 1;
    for GDVars.loopIdx := 1 to 4 do
      FxEngine.RemoveEffect(target, GDConsts.diseaseFx[GDVars.loopIdx], nil);
    GDVars.effectLock := 0;
    if cr^.cureDiseaseLeft > 0 then
      Dec(cr^.cureDiseaseLeft);
    if not CharHlp.HasEffect(cr, ViewChar.EFF_RECENT_CURE, eff) then
      FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_CURE, 10080, 0, 1);
    if found then
      CharHlp.PrintBottomLine(target^.name + ' is cured')
    else
      CharHlp.PrintBottomLine(cr^.name + ' cures the healthy');
  end;
  ViewChar.DisplayChar;
end;

function PickCharacter: Boolean;
var
  ch: Char;
  redraw: Boolean;
  saved: Byte;
  savedRosterPick: Byte;
begin
  savedRosterPick := GDVars.rosterPickMenu;
  GDVars.rosterPickMenu := 1;
  saved := GDVars.rosterMouseOn;
  GDVars.rosterMouseOn := 1;
  repeat
    GDVars.pickingCharacter := 1;
    ch := MenuCore.MenuHorizontal('Pick Character ', 'Select Exit', LightMagenta, LightGreen, White, 1, 0, redraw);
    GDVars.pickingCharacter := 0;
    if redraw then begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end;
  until not redraw and (ch in [C_Keys.NONE, 'E', 'S']);
  CharHlp.DisplayParty(GDVars.curChar, True);
  PickCharacter := ch = 'S';
  GDVars.rosterMouseOn := saved;
  GDVars.rosterPickMenu := savedRosterPick;
end;

function MinOf(a, b: Word): Word;
begin
  MinOf := a;
  if b < a then
    MinOf := b;
end;

begin
end.
