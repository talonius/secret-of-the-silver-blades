{ Money, treasure, and the random-item factory. }
{$O+,F+,I-}
unit Money;

interface

uses Types, Border, GameIo, FxEngine, CharHlp, MenuCore, TextRend, Crt, GDConsts, GDVars, C_Money, C_Keys, C_Ifc;

{ Gives the most weight a character can carry: its weight allowance plus 1500.
  @param(p The character.)
  @returns(The capacity.) }
function CarryingCapacity(p: Types.PCharRecord): Word;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight removed.) }
procedure RemoveWeight(p: Types.PCharRecord; w: LongInt);

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight added.) }
procedure AddWeight(p: Types.PCharRecord; w: LongInt);

{ Tells whether more weight would overload a character.
  @param(p Character to test.)
  @param(w Weight to add.)
  @param(takable Receives what it can still take when it would be overloaded (0 if already over), otherwise 0.)
  @returns(True when the weight would overload it.) }
function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: LongInt): Boolean;

{ Moves the money of each player character, and of each NPC with the value $B3, into the pool, taking its weight off,
  and marks the pool as holding money. }
procedure PoolMoney;

{ Counts the party members and animated creatures (NPC value 0 or $B3).
  @returns(The count.) }
function CountPoolers: Byte;

{ Divides the pool. Each money type's share is the pool divided by CountPoolers, the remainder held back. The first pass
  gives each member with an NPC value below $80, highest money type first, its share and one coin of the remainder while
  they fit, or as much of the share as it can carry, the rest going back to the remainder. The second pass hands what is
  left, type by type, to each member in list order as far as it can carry, and the rest stays in the pool, which is
  marked as holding money when anything stays. Note: the divisor counts animated members ($B3), whom the first pass
  skips, and not NPC values 1 to $7F, whom it pays. }
procedure ShareMoney;

{ Lists the money in the pool and lets the current character take an amount of the chosen type, until the pool is empty
  or the player leaves. Note: leaving the menu without choosing does not free the list it was built from. }
procedure TakeMoneyMenu;

{ Gives platinum to the current character; what does not fit goes to the pooled money, with a message on the bottom row.
  @param(pp The platinum pieces.) }
procedure GivePlatinum(pp: Word);

{ Reads a money type from the start of a menu entry. Leading spaces are skipped, unchecked; the first letter gives the
  type, and for G the second letter, upper-cased, tells gems from gold. An unknown letter leaves the result and the name
  unset.
  @param(s The menu entry.)
  @param(typeName Receives the type's name, as the take prompt shows it.)
  @returns(The money type.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Shows a question on the bottom row and reads a number up to the largest accepted: digits are echoed in white, a larger
  number is cut to the largest, and backspace takes off the last digit. Enter or Escape ends the input.
  @param(max The largest number accepted.)
  @param(query The question shown.)
  @param(color The question's color.)
  @returns(The number, or 0 on Escape.) }
function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;

{ Moves coins of one type, with their weight, from one character to another when the receiver can carry them; otherwise
  shows "Overloaded", pauses and flushes the keyboard.
  @param(giver The character giving the coins.)
  @param(rcv The character receiving them.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: LongInt; mType: ShortInt);

{ Takes money from a character; in the loot screen, in shops and temples and in the vault it goes into the pool,
  elsewhere it is lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);

{ Tells what treasure is left.
  @param(hasMoney Set True when any pool slot is not 0, else False.)
  @param(items Set True when the treasure item list is not empty, else False.) }
procedure DetermineTreasure(var hasMoney, items: Boolean);

{ Sets the current character's coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The
  other coin types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetCreatureCoinsInGold(gp: Word);

{ Sets the pooled coins to a worth in gold: platinum for each five gold pieces and gold for the rest. The other coin
  types are cleared; gems and jewelry are kept.
  @param(gp The worth in gold pieces.) }
procedure SetTreasureCoinsInGold(gp: Word);

{ Values the coins of a money record in gold, rounded down; gems and jewelry are not counted.
  @param(m The money record.)
  @returns(The value in gold.) }
function CoinValueInGold(m: Types.TMoney): LongInt;

{ Fills an item record with a random item of a kind. Weapons and armor (1..37, 50, 59, 70, 71) get a RandomBonus plus
  (kind 50 always +4, kind 59 always +1 with a saving-throw bonus) with their name, weight and value, which rises with
  the plus; a long sword has a one-in-five chance of being a special sword from the random-item table instead. Kinds 39
  and 40 are scrolls of 1..3 random spells, kind 39 of levels 1..7 from the magic-user list and kind 40 of levels 1..6
  from the cleric list, worth 150 a spell level. Kinds 47, 52 and 53 copy a row of the random-item table, kind 47 one of
  four rows at random.
  @param(wantKind The item kind.)
  @param(it Receives the item.) }
procedure GenerateRandomItem(wantKind: Byte; var it: Types.TItemRec);

{ Appraises the current character's gems and jewelry one at a time: each gets a random value and is sold for a fifth of
  it in platinum (GivePlatinum), or, when the character has room and fewer than 16 items, kept as an item. Note: a kept
  gem or jewel is linked to the end of the item list without counting it or adding its weight, it is lost when the
  character carries no items, and leaving the Sell/Keep menu sells.
  @param(ok Set False when there is nothing to appraise, else True.) }
procedure AppraiseMenu(var ok: Boolean);

implementation

function CarryingCapacity(p: Types.PCharRecord): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(p) + 1500;
end;

procedure RemoveWeight(p: Types.PCharRecord; w: LongInt);
begin
  p^.encumbrance := p^.encumbrance - w;
end;

procedure AddWeight(p: Types.PCharRecord; w: LongInt);
begin
  p^.encumbrance := p^.encumbrance + w;
end;

function CheckOverload(p: Types.PCharRecord; w: LongInt; var takable: LongInt): Boolean;
var
  cap: Word;
begin
  cap := Money.CarryingCapacity(p);
  if p^.encumbrance + w > cap then begin
    CheckOverload := True;
    if p^.encumbrance > cap then
      takable := 0
    else
      takable := cap - p^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

function CoinValueInGold(m: Types.TMoney): LongInt;
var
  total: LongInt;
  i: ShortInt;
begin
  total := 0;
  for i := C_Money.COPPER to C_Money.PLATINUM do
    Inc(total, GDConsts.coinValue[i] * m[i]);
  CoinValueInGold := total div GDConsts.coinValue[C_Money.GOLD];
end;

procedure SetCreatureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := C_Money.COPPER to C_Money.PLATINUM do
    GDVars.curChar^.coinsA[i] := 0;
  GDVars.curChar^.coinsA[C_Money.PLATINUM] := gp div 5;
  GDVars.curChar^.coinsA[C_Money.GOLD] := gp mod 5;
end;

procedure SetTreasureCoinsInGold(gp: Word);
var
  i: ShortInt;
begin
  for i := C_Money.COPPER to C_Money.PLATINUM do
    GDVars.treasureMoney[i] := 0;
  GDVars.treasureMoney[C_Money.PLATINUM] := gp div 5;
  GDVars.treasureMoney[C_Money.GOLD] := gp mod 5;
end;

procedure GivePlatinum(pp: Word);
var
  takable: LongInt;
begin
  if Money.CheckOverload(GDVars.curChar, pp, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coinsA[C_Money.PLATINUM], takable);
    Money.AddWeight(GDVars.curChar, takable);
    GDVars.treasureMoney[C_Money.PLATINUM] := pp + GDVars.treasureMoney[C_Money.PLATINUM] - takable;
  end else begin
    Inc(GDVars.curChar^.coinsA[C_Money.PLATINUM], pp);
    Money.AddWeight(GDVars.curChar, pp);
  end;
end;

function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  maxLen: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: LongInt;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, Black, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9': begin
          s := Concat(s, ch);
          Val(s, v, code);
          if v <= max then
            Inc(col)
          else begin
            s := maxStr;
            col := qLen + Length(maxStr);
          end;
          TextRend.DisplayString(qLen, 24, White, Black, s);
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          Dec(col);
          TextRend.PrintSpaces(col, 24, Black, 1);
        end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCharRecord; qty: LongInt; mType: ShortInt);
begin
  if rcv^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    giver^.coinsA[mType] := giver^.coinsA[mType] - qty;
    Money.RemoveWeight(giver, qty);
    rcv^.coinsA[mType] := rcv^.coinsA[mType] + qty;
    Money.AddWeight(rcv, qty);
  end else begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.FlushKeys;
  end;
end;

procedure PoolMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  coinIndex: Byte;
  i: ShortInt;
begin
  p := GDVars.creatureList;
  GDVars.treasureMoneyFlag := True;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then begin
      for i := C_Money.COPPER to C_Money.JEWELRY do begin
        GDVars.treasureMoney[i] := p^.coinsA[i] + GDVars.treasureMoney[i];
        Money.RemoveWeight(p, p^.coinsA[i]);
      end;
      GameIo.FillWord(p^.coinsA, SizeOf(p^.coinsA));
    end;
    p := p^.nextCharAddr;
  end;
end;

function CountPoolers: Byte;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = $B3) then
      Inc(n);
    p := p^.nextCharAddr;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCharRecord;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: LongInt;
  share: array[0..6] of Word;
  rem: array[0..6] of Word;
  i: ShortInt;
begin
  p := GDVars.creatureList;
  done := False;
  cnt := Money.CountPoolers;
  GameIo.FillWord(share, SizeOf(share));
  GameIo.FillWord(rem, SizeOf(rem));
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.treasureMoney[i] > 0 then begin
      share[i] := GDVars.treasureMoney[i] div cnt;
      rem[i] := GDVars.treasureMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  while p <> nil do begin
    if p^.npc < $80 then
      for i := C_Money.JEWELRY downto C_Money.COPPER do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coinsA[i] := share[i] + p^.coinsA[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, 1, takable) then begin
              p^.coinsA[i] := p^.coinsA[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coinsA[i] := p^.coinsA[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.nextCharAddr;
  end;
  for i := C_Money.JEWELRY downto C_Money.COPPER do
    if rem[i] > 0 then begin
      p := GDVars.creatureList;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coinsA[i] := p^.coinsA[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coinsA[i] := p^.coinsA[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.nextCharAddr;
      end;
    end;
  GDVars.treasureMoneyFlag := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do begin
    GDVars.treasureMoney[i] := rem[i];
    if GDVars.treasureMoney[i] <> 0 then
      GDVars.treasureMoneyFlag := True;
  end;
end;

procedure DropMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);
begin
  p^.coinsA[mType] := p^.coinsA[mType] - qty;
  Money.RemoveWeight(p, qty);
  if (GDVars.interfaceState = C_Ifc.LOOT) or (GDVars.interfaceState = C_Ifc.SHOP_TEMPLE) or
      (GDVars.interfaceState = C_Ifc.IN_VAULT) then
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] + qty;
end;

{ Moves money from the pool to a character, at most what the pool holds; an amount that would overload the character is
  refused whole: "Overloaded" is shown, the game pauses and the keyboard is flushed. Note: the overload test uses the
  amount asked for, before it is cut down to what the pool holds.
  @param(p The character.)
  @param(qty The amount asked for.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PCharRecord; qty: LongInt; mType: ShortInt);
var
  takable: LongInt;
begin
  if Money.CheckOverload(p, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.FlushKeys;
  end else begin
    if qty > GDVars.treasureMoney[mType] then
      qty := GDVars.treasureMoney[mType];
    GDVars.treasureMoney[mType] := GDVars.treasureMoney[mType] - qty;
    p^.coinsA[mType] := p^.coinsA[mType] + qty;
    Money.AddWeight(p, qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var
  i: Byte;
begin
  i := 1;
  while s[i] = ' ' do
    Inc(i);
  case s[i] of
    'G': if UpCase(s[i + 1]) = 'E' then begin
           ParseMoneyType := C_Money.GEMS;
           typeName := 'Gems ';
         end else begin
           typeName := 'Gold ';
           ParseMoneyType := C_Money.GOLD;
         end;
    'P': begin
           typeName := 'Platinum ';
           ParseMoneyType := C_Money.PLATINUM;
         end;
    'E': begin
           typeName := 'electrum ';
           ParseMoneyType := C_Money.ELECTRUM;
         end;
    'S': begin
           typeName := 'silver ';
           ParseMoneyType := C_Money.SILVER;
         end;
    'C': begin
           typeName := 'Copper ';
           ParseMoneyType := C_Money.COPPER;
         end;
    'J': begin
           typeName := 'Jewelry ';
           ParseMoneyType := C_Money.JEWELRY;
         end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  save: Types.PItemRec;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: LongInt;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame(0);
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.treasureMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TItemNode));
          p^.next := sel;
        end;
        Str(GDVars.treasureMoney[i], numStr);
        p^.name := GDConsts.moneyNames[i] + ' ' + numStr;
        p^.isHeader := 0;
      end;
    sel := p;
    save := p;
    ch := MenuCore.MenuVertical('Select type of coin ', 'Select', LightMagenta, LightGreen, White, 2, 2, 15, 8, p, 1,
                                redraw, idx, sel);
    if (sel = nil) or (ch = C_Keys.NONE) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      if mType = C_Money.GEMS then
        numStr := 'How Many ' + numStr + ' will you take? '
      else
        numStr := 'How much ' + numStr + ' will you take? ';
      n := Money.InputNumberMax(GDVars.treasureMoney[mType], numStr, LightGreen);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(save);
      GDVars.treasureMoneyFlag := False;
      exitF := True;
      for i := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.treasureMoney[i] > 0 then begin
          GDVars.treasureMoneyFlag := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var hasMoney, items: Boolean);
var
  i: ShortInt;
begin
  hasMoney := False;
  items := False;
  for i := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.treasureMoney[i] <> 0 then
      hasMoney := True;
  if GDVars.treasureItems <> nil then
    items := True;
end;

{ Rolls a random weapon or armor bonus.
  @returns(1 on a d10 roll of 1..6, 2 on 7..9, 3 on 10.) }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 10);
  case r of
    1..6: RandomBonus := 1;
    7..9: RandomBonus := 2;
    10: RandomBonus := 3;
  end;
end;

procedure GenerateRandomItem(wantKind: Byte; var it: Types.TItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  flag: Byte;
  spell: Byte;
begin
  GameIo.FillWord(it, SizeOf(it));
  flag := 0;
  with it do begin
    GameIo.FillWord(spells, SizeOf(spells));
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := wantKind;
    GameIo.FillWord(nameIds, SizeOf(nameIds));
    saveBonus := 0;
    case itemType of
      1..37, 50, 70, 71, 59: begin
          plus := Money.RandomBonus;
          case itemType of
            29: begin
                   nameIds[3] := 29;
                   nameIds[2] := 28;
                   nameIds[1] := plus + 110;
                   unidMask := 4;
                 end;
            7: begin
                   r := FxEngine.RollDice(1, 5);
                   if r = 5 then
                     flag := 49;
                   nameIds[3] := 7;
                   nameIds[2] := plus + 110;
                 end;
            12: begin
                   nameIds[3] := 12;
                   nameIds[2] := plus + 110;
                 end;
            30: begin
                   nameIds[3] := 30;
                   nameIds[2] := plus + 110;
                 end;
            31: begin
                   nameIds[3] := 31;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 110;
                   unidMask := 4;
                 end;
            32..36: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 47;
                   nameIds[1] := plus + 110;
                   unidMask := 4;
                 end;
            50: begin
                   nameIds[3] := 50;
                   nameIds[2] := 90;
                   plus := 4;
                   nameIds[1] := 107;
                 end;
            59: begin
                   plus := 1;
                   saveBonus := 1;
                   nameIds[3] := 46;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 110;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 110;
                 end;
          end;
          quantity := 0;
          case itemType of
            1, 17:
              weight := 75;
            6, 14, 15, 23, 25, 37, 29:
              weight := 50;
            9: weight := 125;
            8, 16, 24:
              weight := 100;
            70, 31:
              weight := 150;
            71: weight := 175;
            4, 50:
              weight := 10;
            5: begin
                 weight := 5;
                 quantity := 20;
               end;
            10, 18:
              weight := 60;
            22: weight := 80;
            7: weight := 20;
            13: weight := 40;
            19: weight := 35;
            20, 32:
              weight := 250;
            33: weight := 400;
            34: weight := 300;
            35: weight := 350;
            36: weight := 450;
            28, 59:
              weight := 1;
            else begin
                   weight := 4;
                   quantity := 20;
                 end;
          end;
          case itemType of
            12, 5, 30: value := plus * 50;
            37: value := plus * 1250;
            32, 33: value := plus * 1500;
            34: value := plus * 1750;
            35: value := plus * 2000;
            36: value := plus * 2500;
            50: value := plus * 1500;
            else value := plus * 1000;
          end;
        end;
      39, 40: begin
          n := FxEngine.RollDice(1, 3);
          nameIds[1] := n + 99;
          nameIds[2] := 39;
          if itemType = 40 then
            nameIds[3] := 38
          else
            nameIds[3] := 40;
          plus := 1;
          weight := 25;
          quantity := 0;
          for j := 1 to n do begin
            if itemType = 39 then begin
              r := FxEngine.RollDice(1, 7);
              unidMask := 4;
              case r of
                1: spell := GDConsts.spellsByLevel[1, FxEngine.RollDice(1, 10)];
                2: spell := GDConsts.spellsByLevel[2, FxEngine.RollDice(1, 7)];
                3: spell := GDConsts.spellsByLevel[3, FxEngine.RollDice(1, 11)];
                4: spell := GDConsts.spellsByLevel[4, FxEngine.RollDice(1, 10)];
                5: spell := GDConsts.spellsByLevel[5, FxEngine.RollDice(1, 4)];
                6: spell := GDConsts.spellsByLevel[6, FxEngine.RollDice(1, 5)];
                7: spell := GDConsts.spellsByLevel[7, FxEngine.RollDice(1, 3)];
              end;
            end else begin
              r := FxEngine.RollDice(1, 6);
              unidMask := 0;
              case r of
                1: spell := GDConsts.clericSpellsByLevel[1, FxEngine.RollDice(1, 8)];
                2: spell := GDConsts.clericSpellsByLevel[2, FxEngine.RollDice(1, 7)];
                3: spell := GDConsts.clericSpellsByLevel[3, FxEngine.RollDice(1, 8)];
                4: spell := GDConsts.clericSpellsByLevel[4, FxEngine.RollDice(1, 6)];
                5: spell := GDConsts.clericSpellsByLevel[5, FxEngine.RollDice(1, 6)];
                6: spell := GDConsts.clericSpellsByLevel[6, FxEngine.RollDice(1, 2)];
              end;
            end;
            spells[j] := spell;
            value := r * 150 + value;
          end;
        end;
      52: flag := 33;
      53: flag := 9;
      47: begin
             r := FxEngine.RollDice(1, 8);
             case r of
               1..2: flag := 1;
               3..4: flag := 17;
               5..6: flag := 25;
               7..8: flag := 41;
             end;
           end;
    end;
    if flag <> 0 then begin
      for j := 0 to 2 do
        nameIds[j + 1] := Lo(GDConsts.randItemW[flag + j]);
      plus := 1;
      saveBonus := 0;
      weight := GDConsts.randItemW[flag + 3];
      quantity := 0;
      value := GDConsts.randItemW[flag + 4];
      for j := 1 to 3 do
        spells[j] := Lo(GDConsts.randItemW[flag + 4 + j]);
    end;
  end;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  menu: String[40];
  actionStr: String[40];
  r: Byte;
  value: LongInt;
  takable: LongInt;
  p: Types.PItemRec;
  gem: Types.PItemRec;
  exitF: Boolean;
  ext: Boolean;
  mustSell: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coinsA[C_Money.GEMS] = 0) and (GDVars.curChar^.coinsA[C_Money.JEWELRY] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coinsA[C_Money.GEMS] = 0) and (GDVars.curChar^.coinsA[C_Money.JEWELRY] = 0) then
        exitF := True
      else begin
        exitF := False;
        Str(GDVars.curChar^.coinsA[C_Money.GEMS], gemStr);
        Str(GDVars.curChar^.coinsA[C_Money.JEWELRY], jwlStr);
        case GDVars.curChar^.coinsA[C_Money.GEMS] of
          0: gemStr := '';
          1: gemStr := gemStr + ' Gem';
          else gemStr := gemStr + ' Gems';
        end;
        case GDVars.curChar^.coinsA[C_Money.JEWELRY] of
          0: jwlStr := '';
          1: jwlStr := jwlStr + ' piece of Jewelry';
          else jwlStr := jwlStr + ' pieces of Jewelry';
        end;
        TextRend.ClearRect(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, Black, 'You have a fine collection of:');
        TextRend.DisplayString(1, 9, White, Black, gemStr);
        TextRend.DisplayString(1, 10, White, Black, jwlStr);
        menu := '';
        if GDVars.curChar^.coinsA[C_Money.GEMS] <> 0 then
          menu := '  Gems';
        if GDVars.curChar^.coinsA[C_Money.JEWELRY] <> 0 then
          menu := menu + '  Jewelry';
        menu := menu + ' Exit';
        ch := MenuCore.MenuHorizontal('Appraise : ', menu, LightMagenta, LightGreen, White, 1, 0, ext);
        case ch of
          'G': if GDVars.curChar^.coinsA[C_Money.GEMS] <> 0 then begin
              Dec(GDVars.curChar^.coinsA[C_Money.GEMS]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 5;
                26..50: value := 25;
                51..70: value := 50;
                71..90: value := 250;
                91..99: value := 500;
                100: value := 2500;
              end;
              Str(value, gemStr);
              gemStr := 'The Gem is Valued at ' + gemStr + ' gp.';
              TextRend.DisplayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, 1, 0, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(gem^));
                GameIo.FillWord(gem^, SizeOf(gem^));
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 122;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GivePlatinum(value div 5);
            end;
          'J': if GDVars.curChar^.coinsA[C_Money.JEWELRY] <> 0 then begin
              Dec(GDVars.curChar^.coinsA[C_Money.JEWELRY]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(450)) + 50;
                11..20: value := Trunc(Random(500)) + 100;
                21..40: value := Trunc(Random(750)) + 150;
                41..50: value := Trunc(Random(1250)) + 250;
                51..70: value := Trunc(Random(2500)) + 500;
                71..90: value := Trunc(Random(3000)) + 1000;
                91..100: value := Trunc(Random(5000)) + 1000;
              end;
              Str(value, jwlStr);
              gemStr := 'The Jewel is Valued at ' + jwlStr + ' gp.';
              TextRend.DisplayString(1, 12, White, Black, gemStr);
              if Money.CheckOverload(GDVars.curChar, 1, takable)
                 or (GDVars.curChar^.numberOfItems >= 16) then begin
                actionStr := 'Sell';
                mustSell := True;
              end else begin
                actionStr := 'Sell Keep';
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal('You can : ', actionStr, LightMagenta, LightGreen, White, 1, 0, ext);
              if (ch = 'K') and (not mustSell) then begin
                GetMem(gem, SizeOf(gem^));
                GameIo.FillWord(gem^, SizeOf(gem^));
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 123;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.itemsAddr;
                if p = nil then
                  p := gem
                else begin
                  while p^.next <> nil do
                    p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GivePlatinum(value div 5);
            end;
          'E', C_Keys.NONE:
            exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
