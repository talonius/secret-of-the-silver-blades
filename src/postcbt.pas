{ Post-combat. Combat has just ended: this overlay totals the monsters' coins and items into the treasure pool, awards
  the XP share, resolves the combat-result flags, prints the summary screen, runs the Loot / Take / Pool / Share /
  Detect menus, lets NPCs take and hide their cut, frees the treasure list, and -- if the party was wiped -- paints the
  game-over screen. }
{$O+,F+,A-,I-,V-}
unit PostCbt;

interface

uses Types, Shop, EclMenu, CharGen, ViewChar, Magic, Money, FxEngine, CharHlp, MenuCore, Border, TextRend, GameIo, Crt,
  GDConsts, GDVars, C_Status, C_Money, C_Keys, C_Ifc, C_Class, C_Stat, C_Gender;

{ Settles the end of a battle. Outside the demo the results are worked out (DetermineCombatResults); the combat records
  and the defeated creatures are then removed and each party member's stats recalculated. Unless the party was
  destroyed, a fleeing party loses the treasure items, items of types 55 to 57 are purged, the NPCs take their share,
  the summary and the loot menu run, and the treasure list is freed; a destroyed party gets the game-over message and
  combat result $80. The zone's per-battle modifiers and flags are reset at the end. The demo skips everything after the
  cleanup. }
procedure PostCombat;

{ Offers the treasure's money and items to take: with both a Money/Items menu, where the up and down arrows change the
  current character, until one kind is gone; otherwise straight to the money or the items.
  @param(hasMoney Whether money is left; updated by the Money/Items menu.)
  @param(items Whether items are left; updated by the Money/Items menu.) }
procedure LootTakeMenu(var hasMoney, items: Boolean);

{ Works out the experience share of a won battle. In a duel it is 100 per level of the current character. Otherwise each
  defeated hostile adds its experience award plus its bonus per rolled hit point, its coins other than copper go to the
  treasure money when it was not a party member, and, unless the zone forbids combat items, copies of its items go to
  the treasure list. The treasure money then adds experience by coin type (1 per 200, 20 and 2 of the first three, 1, 5,
  250 and 2200 each of the rest), each new treasure item adds 400 per plus, and the total is divided among the party
  members who are not out of play or animated.
  @param(share Receives the experience each character earns.) }
procedure DetermineLootExp(var share: LongInt);

{ Gives each party member in play and not animated its share of the experience: a single-class character with high prime
  abilities gets a tenth more, a two-class character half, and a three-class character a third. Nothing is given when
  the zone withholds experience.
  @param(xp The share.) }
procedure AwardExperience(xp: LongInt);

{ Works out how a battle ended for the party, whose members head the creature list. It records whether a member fled;
  whether the party was defeated, unless a player character is still standing, the fight was a duel, or a zone flag is
  set with someone still alive; and whether the battle was won, when a member is okay or animated. It also counts the
  members out of play or animated. Each member loses the effects that end with combat, and a win awards experience. A
  surviving party gets running members back and the dying or unconscious ones okay or unconscious as that zone flag
  decides; a fleeing party records a fled result and leaves behind the members who did not run; a destroyed party is
  removed. A demo duel only awards the winner and settles the statuses. }
procedure DetermineCombatResults;

{ Shows the outcome of the battle (fled or won, when monsters were killed or in a duel), the experience each character
  receives unless the zone withholds it, and whether treasure was found, then waits for Enter. Fleeing also throws away
  the treasure items and money.
  @param(xp The share shown; 0 after a flight.) }
procedure PostCombatSummary(xp: LongInt);

{ Lists the treasure items in a vertical Take menu.
  @param(c Receives the key pressed.)
  @param(itemToTake Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);

{ Runs the item-taking menu: each item taken goes to the current character as a copy, and the treasure item is freed. It
  ends on any key other than Take or Enter, or when no treasure items are left. }
procedure LootTakeItemMenu;

{ Runs the after-battle menu until the party leaves: View, Take while treasure is left, Pool, Share while money is left,
  and Detect when the current character is in play with a detect spell memorized and items are left. The arrow keys
  change the current character. Leaving with treasure left asks whether to go back for it. }
procedure LootMenu;

{ Removes the monsters and hostile creatures from the creature list, recording each removal as a monster killed and
  counting those out of play for the zone, and frees the combat records of the party. The first one removed raises a
  zone flag when it is out of play, and a running one sets combat result 1 when none is set. The current character
  becomes the party's first member. }
procedure PostCombatCreatureCleanup;

{ Removes the items of types 55, 56 and 57 from the treasure list. Note: the type is tested before the end of the list,
  so after the last item one more is read through nil. }
procedure PurgeTreasureItems;

{ Lets each okay NPC take its share of the treasure money: its weight is the low three bits of its modified field,
  everyone else counts 1, and the NPCs' shares come out of each coin type but copper. Each NPC that took a share says
  so, and the player presses Enter. }
procedure NpcTreasureShare;

implementation

procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  it: Types.PItemRec;
  cnt: Byte;
begin
  if GDVars.duelFlag <> 0 then
    share := GDVars.curChar^.highestLevel * 100
  else begin
    expTotal := 0;
    p := GDVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      it := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_Status.OKAY) and (p^.status <> C_Status.RUNNING) then begin
        GDVars.monstersKilled := 1;
        if p^.combatAddr^.inPlay = 1 then
          for i := C_Money.SILVER to C_Money.JEWELRY do
            Inc(GDVars.treasureMoney[i], p^.coinsA[i]);
        expTotal := expTotal + p^.xpAward + p^.pcHpRolled * p^.hpRolled;
        if GDVars.zone1^.noCombatItems <> 1 then
          while it <> nil do begin
            Inc(cnt);
            if GDVars.treasureItems = nil then begin
              New(GDVars.treasureItems);
              CharHlp.PrintItemString(p, it, 0, 0, 0, 0);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := nil;
            end else begin
              q := GDVars.treasureItems;
              New(GDVars.treasureItems);
              CharHlp.PrintItemString(p, it, 0, 0, 0, 0);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := q;
            end;
            it := it^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    { One XP per gold piece. The first five factors are coinValue (1/10/100/200/1000 copper) divided into gold's 200;
      gems and jewelry have no fixed rate and carry flat book values. }
    Inc(expTotal, GDVars.treasureMoney[C_Money.COPPER] div 200);
    Inc(expTotal, GDVars.treasureMoney[C_Money.SILVER] div 20);
    Inc(expTotal, GDVars.treasureMoney[C_Money.ELECTRUM] div 2);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GOLD]);
    Inc(expTotal, GDVars.treasureMoney[C_Money.PLATINUM] * 5);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GEMS] * 250);
    Inc(expTotal, GDVars.treasureMoney[C_Money.JEWELRY] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.lastItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    share := expTotal div (GDVars.zone1^.partySize - GDVars.nonAnimCount);
  end;
end;

procedure AwardExperience(xp: LongInt);
var
  p: Types.PCharRecord;
  share: LongInt;
begin
  if GDVars.zone0^.noXpAward = 0 then begin
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.enabled <> 0) and (p^.status <> C_Status.ANIMATED) then begin
        share := xp;
        case p^.charClass of
          C_Class.CLERIC: if p^.stats[C_Stat.WISDOM].cur > 14 then share := xp div 10 + xp;
          C_Class.FIGHTER: if p^.stats[C_Stat.STRENGTH].cur > 15 then share := xp div 10 + xp;
          C_Class.PALADIN: if (p^.stats[C_Stat.STRENGTH].cur > 15) and (p^.stats[C_Stat.WISDOM].cur > 15) then
               share := xp div 10 + xp;
          C_Class.RANGER: if (p^.stats[C_Stat.STRENGTH].cur > 15) and (p^.stats[C_Stat.INTELLIGENCE].cur > 15) and
            (p^.stats[C_Stat.WISDOM].cur > 15) then
               share := xp div 10 + xp;
          C_Class.MAGE: if p^.stats[C_Stat.INTELLIGENCE].cur > 15 then share := xp div 10 + xp;
          C_Class.THIEF: if p^.stats[C_Stat.DEXTERITY].cur > 15 then share := xp div 10 + xp;
          C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
            C_Class.MAGE_THIEF: share := xp div 2;
          C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF: share := xp div 3;
        end;
        Inc(p^.experience, share);
      end;
      p := p^.nextCharAddr;
    end;
  end;
end;

procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  b: Boolean;
  animIdx: Byte;
  anyDown: Boolean;
begin
  GDVars.nonAnimCount := 0;
  GDVars.partyDefeated := 1;
  GDVars.partyFled := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (p^.combatAddr^.inPlay <> 1) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := 1;
    p := p^.nextCharAddr;
  end;
  p := GDVars.creatureList;
  anyDown := False;
  while (p <> nil) and (not anyDown) do begin
    if (p^.enabled <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then
      anyDown := True;
    p := p^.nextCharAddr;
  end;
  if (GDVars.duelFlag <> 0) or ((GDVars.zone1^.mirrorDuel <> 0) and anyDown) then
    GDVars.partyDefeated := 0;
  GDVars.combatWon := 0;
  p := GDVars.creatureList;
  if (GDVars.duelFlag = 0) or (not GDVars.demoMode) then begin
    while (p <> nil) and (p^.combatAddr^.inPlay <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and
          (p^.hostile = 0) and (p^.npc < $80) then
        GDVars.partyDefeated := 0;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := 1;
        GDVars.partyFled := 0;
      end;
      if (p^.enabled = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.nonAnimCount);
      for animIdx := 1 to 11 do
        FxEngine.RemoveEffect(p, GDConsts.animTable[animIdx], nil);
      p := p^.nextCharAddr;
    end;
    if GDVars.combatWon <> 0 then begin
      PostCbt.DetermineLootExp(GDVars.expShare);
      PostCbt.AwardExperience(GDVars.expShare);
    end;
    p := GDVars.creatureList;
    if GDVars.partyDefeated = 0 then begin
      while (p <> nil) and (p^.combatAddr^.inPlay <> 1) do begin
        if GDVars.partyFled = 0 then begin
          case p^.status of
            C_Status.RUNNING: begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
            C_Status.DYING: if GDVars.zone1^.mirrorDuel <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
                 p^.hpCurrent := 1;
               end else
                 p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCurrent > 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end else if GDVars.zone1^.mirrorDuel <> 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
                 p^.hpCurrent := 1;
               end;
          end;
          p := p^.nextCharAddr;
        end else begin
          GDVars.zone1^.combatResult := $81;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.enabled := 1;
            p := p^.nextCharAddr;
          end else begin
            GDVars.curChar := p;
            p := p^.nextCharAddr;
            CharGen.RemoveCreature(False, True);
          end;
        end;
      end;
    end else begin
      p := GDVars.creatureList;
      b := False;
      while (p <> nil) and (not b) do begin
        if p^.combatAddr^.inPlay <> 1 then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          b := True;
        p := p^.nextCharAddr;
      end;
      GDVars.zone1^.partySize := 0;
    end;
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> 1) then begin
        GDVars.combatWon := 1;
        PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare);
      end;
      p := p^.nextCharAddr;
    end;
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
      p := p^.nextCharAddr;
    end;
  end;
end;

procedure PostCombatSummary(xp: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  { always empty }
  query: String[1];
  ext: Boolean;
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  query[0] := #0;
  Border.DrawWindowFrame(1);
  if (GDVars.monstersKilled <> 0) or (GDVars.duelFlag <> 0) then begin
    if GDVars.partyFled <> 0 then begin
      TextRend.DisplayString(1, 3, LightGreen, 0, 'The party has fled.');
      xp := 0;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p^.next;
        Dispose(p);
        p := q;
      end;
      GameIo.FillWord(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney));
    end else
      TextRend.DisplayString(1, 3, LightGreen, 0, 'The party has won.');
  end;
  Str(xp, numStr);
  msg := 'Each character receives ' + numStr;
  if GDVars.zone0^.noXpAward = 0 then begin
    TextRend.DisplayString(1, 5, LightGreen, 0, msg);
    TextRend.DisplayString(1, 7, LightGreen, 0, 'experience points.');
  end;
  GDVars.treasureHasMoney := False;
  GDVars.treasureHasItems := False;
  Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
  if GDVars.treasureHasMoney or GDVars.treasureHasItems then
    TextRend.DisplayString(1, 10, LightGreen, 0, GDConsts.treasureMsgA + GDConsts.treasureMsgB)
  else
    TextRend.DisplayString(1, 10, LightGreen, 0, GDConsts.treasureMsgA + 'no ' + GDConsts.treasureMsgB);
  c := MenuCore.MenuHorizontal(query, GDConsts.continuePrompt, White, White, White, 1, 0, ext);
end;

procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  itemText: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  redraw: Boolean;
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindowFrame(1);
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, p, 0, 0, 0, 0);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  GDVars.horizChoice := 0;
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, 1, redraw, idx,
                             cursor);
  itemToTake := cursor;
end;

procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then
          Dispose(itemToTake);
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var hasMoney, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if hasMoney then begin
    if items then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White, 1, 1, ext);
        case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharHlp.DisplayNoncombatInterface;
                 Money.DetermineTreasure(hasMoney, items);
                 if not hasMoney then
                   done := True;
                 CharHlp.DisplayRoster(GDVars.curChar);
               end;
          'I': begin
                 PostCbt.LootTakeItemMenu;
                 Money.DetermineTreasure(hasMoney, items);
                 if not items then
                   done := True;
                 CharHlp.DisplayRoster(GDVars.curChar);
               end;
          'E', C_Keys.NONE: done := True;
        else begin
            CharHlp.DisplayParty(GDVars.curChar, False);
            ViewChar.SelectPrevNextChar(c);
            CharHlp.DisplayParty(GDVars.curChar, True);
          end;
        end;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

procedure LootMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  hasMoney: Boolean;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  { always empty }
  query: String[1];
  ynIdx: Byte;
  i: Byte;
  detectSpell: Byte;
  hasDetect: Byte;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharHlp.DisplayNoncombatInterface;
  repeat
    Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := 0;
    if GDVars.treasureHasItems then
      while (i <= 74) and (hasDetect = 0) do begin
        if ((GDVars.curChar^.memorizedSpells[i] = 5) or (GDVars.curChar^.memorizedSpells[i] = 11) or
            (GDVars.curChar^.memorizedSpells[i] = 77)) and (GDVars.curChar^.enabled <> 0) then begin
          hasDetect := 1;
          detectSpell := GDVars.curChar^.memorizedSpells[i];
        end;
        Inc(i);
      end;
    if hasDetect <> 0 then
      tail := ' Detect Exit';
    if GDVars.treasureHasMoney then
      menu := 'View Take Pool Share' + tail
    else if GDVars.treasureHasItems then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, 1, 1, ext);
    if not ext then begin
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': PostCbt.LootTakeMenu(GDVars.treasureHasMoney, GDVars.treasureHasItems);
        'P': if not ext then
               Money.PoolMoney;
        'S': Money.ShareMoney;
        'D': Magic.CastSpell(detectSpell, False, False, ext);
        'E', C_Keys.NONE: begin
                   Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
                   if GDVars.treasureHasMoney or GDVars.treasureHasItems then begin
                     menu := '~Yes ~No';
                     TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, 0, True,
                                                   'There is still treasure left.  ');
                     TextRend.DisplayMessageWindow(1, 17, 38, 22, White, 0, False,
                                          'Do you want to go back and claim your treasure?');
                     ynIdx := EclMenu.MenuHorizontalCharacterSelect(query, menu, LightMagenta, LightGreen,
                                                                    White, False, False);
                     if ynIdx = 1 then
                       done := True
                     else
                       TextRend.ClearRect(1, 17, 38, 22);
                   end else
                     done := True;
                 end;
      end;
    end else begin
      CharHlp.DisplayParty(GDVars.curChar, False);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar, True);
    end;
  until done;
end;

procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
  first: Boolean;
begin
  first := True;
  GDVars.zone1^.monstersDefeated := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.inPlay = 1) or (p^.hostile = 1) then begin
      GDVars.monstersKilled := 1;
      if p^.enabled <> 1 then begin
        Inc(GDVars.zone1^.monstersDefeated);
        if first then
          GDVars.zone0^.combatCleanedUp := 1;
      end;
      if (p^.status = C_Status.RUNNING) and (GDVars.zone1^.combatResult = 0) then
        GDVars.zone1^.combatResult := 1;
      first := False;
      next := p^.nextCharAddr;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.inPlay = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        Dispose(p^.combatAddr);
        p^.combatAddr := nil;
      end;
      p := p^.nextCharAddr;
    end;
  end;
  GDVars.curChar := GDVars.creatureList;
end;

procedure PurgeTreasureItems;
var
  head: Types.PItemRec;
  q: Types.PItemRec;
begin
  head := GDVars.treasureItems;
  while (head <> nil) and ((head^.itemType = 56) or (head^.itemType = 57) or (head^.itemType = 55)) do begin
    GDVars.treasureItems := head^.next;
    Dispose(head);
    head := GDVars.treasureItems;
  end;
  while (head <> nil) and (head^.next <> nil) do begin
    q := head^.next;
    while ((q^.itemType = 56) or (q^.itemType = 57) or (q^.itemType = 55)) and (q <> nil) do begin
      head^.next := q^.next;
      Dispose(q);
      q := head^.next;
    end;
    head := head^.next;
  end;
end;

procedure NpcTreasureShare;
var
  p: Types.PCharRecord;
  npcShares: Byte;
  total: Byte;
  cut: Byte;
  row: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  msg: String[8];
  took: Boolean;
  ext: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
begin
  took := False;
  p := GDVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    if (p^.npc > $7F) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.modified and 7);
      Inc(total, p^.modified and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := C_Money.SILVER to C_Money.JEWELRY do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindowFrame(1);
    p := GDVars.creatureList;
    row := 0;
    while p <> nil do begin
      if (p^.npc > $7F) and (p^.status = C_Status.OKAY) and (p^.modified > 0) then begin
        if p^.gender = C_Gender.MALE then
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, 0, True,
                               p^.name + ' takes and hides ' + 'his' + ' share.')
        else
          TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, 0, True,
                               p^.name + ' takes and hides ' + 'her' + ' share.');
        Inc(row, 2);
      end;
      p := p^.nextCharAddr;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White, 1, 0, ext);
  end;
end;

procedure PostCombat;
var
  p: Types.PItemRec;
  q: Types.PItemRec;
  cp: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  lootCount: Integer;
begin
  GDVars.zone1^.combatResult := 0;
  GDVars.monstersKilled := 0;
  if not GDVars.demoMode then
    PostCbt.DetermineCombatResults;
  GDVars.interfaceState := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.demoMode then begin
    cp := GDVars.creatureList;
    while cp <> nil do begin
      CharHlp.RecalcStats(cp);
      cp := cp^.nextCharAddr;
    end;
    if GDVars.partyDefeated = 0 then begin
      if GDVars.partyFled <> 0 then begin
        p := GDVars.treasureItems;
        while p <> nil do begin
          q := p;
          p := p^.next;
          Dispose(q);
        end;
        GDVars.treasureItems := nil;
      end;
      if not GDVars.demoMode then begin
        PostCbt.PurgeTreasureItems;
        PostCbt.NpcTreasureShare;
        PostCbt.PostCombatSummary(GDVars.expShare);
        if GDVars.treasureHasMoney or GDVars.treasureHasItems then
          PostCbt.LootMenu;
      end;
      p := GDVars.treasureItems;
      while p <> nil do begin
        q := p;
        p := p^.next;
        Dispose(q);
      end;
      GDVars.treasureItems := nil;
    end else begin
      GDVars.zone1^.combatResult := $80;
      Border.DrawWindowFrame(1);
      GDVars.curCol := 2;
      GDVars.curRow := 6;
      TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, 0, True,
                                    'The monsters rejoice for the party has been destroyed');
      TextRend.DisplayAndPause(LightMagenta, 0, 'Press any key to continue');
    end;
    GDVars.msgDelayFlag := 1;
    GDVars.zone1^.modMonThac0 := 0;
    GDVars.zone1^.modPartyThac0 := 0;
    GDVars.zone1^.partyMoveBonus := 0;
    GDVars.zone1^.noCombatItems := 0;
    GDVars.zone1^.mirrorDuel := 0;
    GDVars.zone0^.noXpAward := 0;
  end;
end;

begin
end.
