{ The shop and its buy screen. }
{$O+,F+,I-,V-}
unit Shop;

interface

uses Types, EclMenu, ViewChar, Money, CharHlp, MenuCore, Border, TextRend, GameIo, Crt, GDVars, C_Keys, C_Ifc;

{ Runs a shop: the money pool starts empty and the shop's goods are the treasure item list. The menu offers Buy, View,
  Pool and Appraise, plus Take and Share while the pool holds money; the up and down arrow keys change the current
  character; leaving with money in the pool asks first. }
procedure ShopMainMenu;

{ Gives the current character a copy of an item at the end of its items and recalculates its stats, unless it cannot
  carry the item, which reports the character as overloaded.
  @param(a The item to copy.)
  @param(res Set True when the item was refused, else False.) }
procedure GiveItemCopyToCreature(a: Types.PItemRec; var res: Boolean);

{ Lists the shop's items with their prices in a vertical Buy menu, then rebuilds the item names. The price is the value
  scaled by the zone's price level, and a level outside the seven scaling values keeps the value; an item whose value is
  0 is given the value 1.
  @param(choice Receives the key pressed.)
  @param(node Receives the chosen item.)
  @param(head The highlighted item, kept between calls; receives the chosen item.)
  @param(itemCount The highlighted item's position, kept between calls.) }
procedure ShopBuyItemSelection(var choice: Char; var node: Types.PItemRec; var head: Types.PItemRec;
                               var itemCount: Integer);

{ Buys items until the player leaves the Buy menu: the scaled price is paid from the current character's coins when they
  suffice, else from the pool ('Not enough Money.' otherwise), the change coming back as gold, and the purchase is
  announced. Note: unlike the listing, a price level outside the eight named ones leaves the price unset. }
procedure ShopBuyMenu;

implementation

type
  TLong = record lo: Word; hi: Word; end;

procedure ShopBuyItemSelection(var choice: Char; var node: Types.PItemRec; var head: Types.PItemRec;
                               var itemCount: Integer);
var
  it2: Types.PItemRec;
  it: Types.PItemRec;
  valStr: String[16];
  line: String[38];
  len: Byte;
  i: Byte;
begin
  it := GDVars.treasureItems;
  while it <> nil do begin
    line := '                                      ';
    if it^.value = 0 then it^.value := 1;
    case GDVars.zone1^.priceMode of
      1: Str(it^.value div 16, valStr);
      2: Str(it^.value div 8, valStr);
      4: Str(it^.value div 4, valStr);
      8: Str(it^.value div 2, valStr);
      $20: Str(it^.value shl 1, valStr);
      $40: Str(it^.value shl 2, valStr);
      $80: Str(it^.value shl 3, valStr);
    else
      Str(it^.value, valStr);
    end;
    len := Length(valStr);
    for i := 1 to len do line[38 - len + i] := valStr[i];
    len := Length(it^.name);
    for i := 1 to len do line[i] := it^.name[i];
    it^.name := line;
    it^.name[0] := #38;
    it := it^.next;
  end;

  it2 := GDVars.treasureItems;
  GDVars.horizChoice := 0;
  choice := MenuCore.MenuVertical('Items: ', 'Buy', LightMagenta, LightGreen, White, 1, 1, 38, 22, it2, 1,
                                  GDVars.buyRedraw, itemCount, head);
  node := head;

  it := GDVars.treasureItems;
  while it <> nil do begin
    CharHlp.PrintItemString(nil, it, 0, 0, 0, 0);
    it := it^.next;
  end;
end;

procedure GiveItemCopyToCreature(a: Types.PItemRec; var res: Boolean);
var
  t: Types.PItemRec;
  node: Types.PItemRec;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, a) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    res := True;
  end else begin
    res := False;
    t := GDVars.curChar^.itemsAddr;
    if t = nil then begin
      New(t);
      t^ := a^;
      t^.next := nil;
      GDVars.curChar^.itemsAddr := t;
    end else begin
      while t^.next <> nil do t := t^.next;
      New(node);
      node^ := a^;
      node^.next := nil;
      t^.next := node;
    end;
    CharHlp.RecalcStats(GDVars.curChar);
  end;
end;

procedure ShopBuyMenu;
var
  node: Types.PItemRec;
  choice: Char;
  exitF: Byte;
  price: LongInt;
  priceA: LongInt;
  priceB: LongInt;
  res: Boolean;
  head: Types.PItemRec;
  itemCount: Integer;
begin
  node := nil;
  head := GDVars.treasureItems;
  itemCount := 0;
  Border.DrawWindowFrame(1);
  GDVars.buyRedraw := True;
  repeat
    Shop.ShopBuyItemSelection(choice, node, head, itemCount);
    if (choice <> 'B') and (choice <> C_Keys.ENTER) then
      exitF := 1
    else begin
      exitF := 0;
      case GDVars.zone1^.priceMode of
        1: price := node^.value div 16;
        2: price := node^.value div 8;
        4: price := node^.value div 4;
        8: price := node^.value div 2;
        $10: price := node^.value;
        $20: price := node^.value shl 1;
        $40: price := node^.value shl 2;
        $80: price := node^.value shl 3;
      end;
      priceA := ViewChar.CreatureCoinValueInGold(GDVars.curChar);
      if price <= priceA then begin
        Shop.GiveItemCopyToCreature(node, res);
        if not res then begin
          priceA := priceA - price;
          Money.SetCreatureCoinsInGold(TLong(priceA).lo);
          if node^.count > 0 then
            CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys ' + node^.name)
          else
            CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys a ' + node^.name);
        end;
      end else begin
        priceB := Money.CoinValueInGold(GDVars.treasureMoney);
        if price <= priceB then begin
          Shop.GiveItemCopyToCreature(node, res);
          if not res then begin
            priceB := priceB - price;
            Money.SetTreasureCoinsInGold(TLong(priceB).lo);
            if node^.count > 0 then
              CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys ' + node^.name)
            else
              CharHlp.PrintBottomLine(GDVars.curChar^.name + ' buys a ' + node^.name);
          end;
        end else
          CharHlp.PrintBottomLine('Not enough Money.');
      end;
    end;
  until exitF <> 0;
end;

procedure ShopMainMenu;
var
  items: Types.TStr40;
  prompt: String[1];
  menuFlag: Boolean;
  exitF: Byte;
  choice: Char;
  moneyF: Boolean;
  itemsF: Boolean;
  confirm: Byte;
  appraiseF: Boolean;
  node: Types.PItemRec;
begin
  GDVars.interfaceState := C_Ifc.SHOP_TEMPLE;
  GDVars.shopPanelOn := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.shopPanelOn := 1;
  CharHlp.DisplayRoster(GDVars.curChar);
  GameIo.FillWord(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
  prompt := '';
  GDVars.treasureMoneyFlag := False;
  exitF := 0;
  node := GDVars.treasureItems;
  while node <> nil do begin
    CharHlp.PrintItemString(nil, node, 0, 0, 0, 0);
    node := node^.next;
  end;

  repeat
    Money.DetermineTreasure(moneyF, itemsF);
    if moneyF then
      items := 'Buy View Take Pool Share Appraise Exit'
    else
      items := 'Buy View Pool Appraise Exit';
    choice := MenuCore.MenuHorizontal(prompt, items, LightMagenta, LightGreen, White, 1, 0, menuFlag);
    case choice of
      'B': begin
          Shop.ShopBuyMenu;
          CharHlp.DisplayNoncombatInterface;
          CharHlp.DisplayRoster(GDVars.curChar);
        end;
      'V': begin ViewChar.ViewCharMenu(menuFlag); CharHlp.DisplayRoster(GDVars.curChar); end;
      'T': begin
          Money.TakeMoneyMenu;
          CharHlp.DisplayNoncombatInterface;
          CharHlp.DisplayRoster(GDVars.curChar);
        end;
      'P': if not menuFlag then
             Money.PoolMoney
           else begin
             CharHlp.DisplayParty(GDVars.curChar, False);
             ViewChar.SelectPrevNextChar(choice);
             CharHlp.DisplayParty(GDVars.curChar, True);
           end;
      'S': Money.ShareMoney;
      'A': begin
             Money.AppraiseMenu(appraiseF);
             if appraiseF then begin
               CharHlp.DisplayNoncombatInterface;
               CharHlp.DisplayRoster(GDVars.curChar);
             end;
           end;
      'E': begin
             Money.DetermineTreasure(moneyF, itemsF);
             if moneyF then begin
               items := '~Yes ~No';
               TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                 'As you Leave the Shopkeeper says, "Excuse me but you have Left Some Money here."  ');
               TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, False,
                                             'Do you want to go back and get your Money?');
               confirm := EclMenu.MenuHorizontalCharacterSelect(prompt, items, LightMagenta, LightGreen, White, False,
                                                                False);
               if confirm = 1 then
                 exitF := 1
               else
                 TextRend.ClearRect(1, 17, 38, 22);
             end else
               exitF := 1;
           end;
      C_Keys.DOWN, C_Keys.UP:
        begin
          CharHlp.DisplayParty(GDVars.curChar, False);
          ViewChar.SelectPrevNextChar(choice);
          CharHlp.DisplayParty(GDVars.curChar, True);
        end;
    end;
  until exitF <> 0;
end;

begin
end.
