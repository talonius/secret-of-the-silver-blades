{ The combat round driver and the manual-control menus. }
{$O+,F+,I-,R-,S-}
unit Combat;

interface

uses Types, GDConsts, GDVars, C_Race, C_Status, C_Keys, C_Dir, C_Ifc, C_Gender, TextRend, Border,
  Blit, GameIo, MenuCore, CombatAi, CombatSt, CbtActs, ViewChar, GameTime, Magic, FxEngine, CharHlp, CbtMap, Crt;

{ Runs a battle. Switches to the combat interface state and the combat cast-target menu and sets up the battle
  (CombatSt.CombatStart), then, unless a side starts empty, plays rounds until EndOfRound reports the battle over: count
  the sides, run each creature's round-start setup, clear the zone's surprise mask, sort the creatures by initiative
  (OrderCreatures) and let them act in that order, and end the round. Afterwards it runs AgingDeaths when aging is
  pending, cleans up and sets the message-delay flag. }
procedure CombatMain;

{ Runs one creature's turn: resets its flanking counts and guard and fires its condition-7 effects. If it still has
  initiative (a finished turn's marker becomes 19), it becomes the current character, the map shows when it is friendly
  or a visible hostile, the view centers on it, its statistics are recalculated and shown, and its condition-15 effects
  fire (and its condition-21 effects when it is not casting). If initiative is still left, the AI (quick fight) or the
  player acts. Last, its cell is redrawn to erase the cursor.
  @param(cr The creature whose turn it is.) }
procedure CreatureAction(cr: Types.PCharRecord);

{ Runs a player-controlled creature's turn. A creature out of play just ends its actions, and a spell begun earlier is
  cast now and ends them. Otherwise the combat menu repeats until an action ends the turn: Quick hands the creature to
  the AI at once; Move, View, Aim (attack), Use, Cast and Done do what they say; Y ends its actions; and Space takes
  each party member that is not an NPC off quick fight. Alt-M toggles magic, Alt-Q or Alt-A ends this creature's turn
  and puts each creature on quick fight, and Alt-X tries the victory cheat.
  @param(cr The creature whose turn it is.) }
procedure ManualControl(cr: Types.PCharRecord);

{ Builds the combat menu (Move while movement remains, View, Aim, Use with items, Cast with memorized spells when the
  creature may cast and the zone allows it, Quick, Done, and * in debug mode) and returns the first accepted key. Alt-R
  is accepted but ManualControl ignores it.
  @param(cr The creature whose turn it is.)
  @param(ch Receives the key; GDVars.extKeyFlag tells whether it is a scan code.) }
procedure CombatMenu(cr: Types.PCharRecord; var ch: Char);

{ Ends a round: advances the clock a minute, counts the round, refigures the hostiles' hit-point percentage, fires each
  creature's condition-19 effects and terrain effects, bleeds dying creatures (dead past overkill 9), warns when a party
  member is dying, counts the sides and rebuilds the view. The battle is done when a side is empty or the round limit is
  reached; when the party is left alone outside the demo, the player is asked whether to continue the battle.
  @param(done Set when the battle is over, and cleared when the player continues it; otherwise left as it was.) }
procedure EndOfRound(var done: Boolean);

{ Moves the creature with the arrow and diagonal keys, prompting with the movement left. Bumping a creature attacks it;
  stepping off the arena offers to flee; a step costing more than the movement left is refused. Each step allows
  opportunity attacks and terrain effects, and a creature left out of play or helpless ends its actions. Escape undoes
  the whole move; Enter or Done ends it, and movement below 2 half-steps is dropped.
  @param(cr The moving creature.)
  @param(startCh The first key: a direction key, or a space to prompt for one.)
  @param(done Set when the creature's actions are over.) }
procedure MoveMenu(cr: Types.PCharRecord; startCh: Char; var done: Boolean);

{ Makes MoveMenu's attack on a creature in the way, refused with a ranged weapon that cannot be thrown. Once an attack
  on an ally is confirmed, the target is locked, and a sweep is tried before a normal attack.
  @param(att The attacker.)
  @param(def The creature attacked.)
  @param(done Receives True when the attacker's actions are over; left as it was when the attack is refused.) }
procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean);

{ Offers Guard (with a melee or throwable weapon), Delay (initiative 1, moving the creature to the end of the order so
  it acts again later), Quit (end its actions), Bandage (while a party member is dying), Speed and Exit, until a choice
  ends the creature's actions or it leaves with Exit or Escape.
  @param(cr The creature whose turn it is.)
  @param(done Set when the choice ends the creature's actions.) }
procedure DoneMenu(cr: Types.PCharRecord; var done: Boolean);

{ Adjusts the game delay: Slower (offered below 9) raises it, Faster (offered above 0) lowers it, and Exit or Escape
  leaves. }
procedure SpeedMenu;

{ Puts a creature on quick fight and drops a locked target on its own side.
  @param(cr The creature to hand to the AI.) }
procedure TurnOnAuto(cr: Types.PCharRecord);

{ Fills the combat order with the creatures in descending initiative, inserting each and shifting the later ones down; a
  tie goes either way at random. Note: the insertion point is sought only among the first 64 slots. }
procedure OrderCreatures;

{ After a battle, warns each living creature within ten years of its race's maximum age ('is looking very old') and
  kills one past it: it dies from age (GONE) with a farewell, and the closing message depends on how many okay party
  members are left to witness it. Clears the aging flag. Note: the witness count is never set to 0 first. }
procedure AgingDeaths;

{ Ends a battle: frees both cloud lists, turns each okay creature with effect 11 to running while more than one enemy
  remains, drops each creature's effects that end at 0 hit points, frees the arena and the combat view picture, restores
  the noncombat palette, and points the cast-target menu back at the noncombat one. }
procedure CombatDoneCleanup;

implementation

const
  { extended scan codes, after a #0 prefix }
  KEY_ALT_Q = #16;
  KEY_ALT_R = #19;
  KEY_ALT_A = #30;

procedure CombatDoneCleanup;
var
  { reused by both free loops }
  nx: Types.PCloudNode;
  p: Types.PCharRecord;
  { HasEffect's out-param }
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  effectScan: Integer;
begin
  while GDVars.stinkHead <> nil do begin
    nx := GDVars.stinkHead^.next;
    FreeMem(GDVars.stinkHead, SizeOf(GDVars.stinkHead^));
    GDVars.stinkHead := nx;
  end;
  while GDVars.blastHead <> nil do begin
    nx := GDVars.blastHead^.next;
    FreeMem(GDVars.blastHead, SizeOf(GDVars.blastHead^));
    GDVars.blastHead := nx;
  end;
  p := GDVars.creatureList;
  while p <> nil do begin
    if CharHlp.HasEffect(p, 11, eff) and (p^.status = C_Status.OKAY) then
      if GDVars.teamCount[1] > 1 then
        p^.status := C_Status.RUNNING
      else
        p^.status := C_Status.OKAY;
    FxEngine.RemoveEffectsHp0(p);
    p := p^.nextCharAddr;
  end;
  FreeMem(GDVars.arenaPtr, SizeOf(GDVars.arenaPtr^));
  GDVars.arenaPtr := nil;
  Blit.FreePic(GDVars.iconBuf);
  CbtMap.SetNoncombatPalette;
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
end;

procedure CombatMain;
var
  done: Boolean;
  cr: Types.PCharRecord;
begin
  GDVars.interfaceState := C_Ifc.IN_COMBAT;
  GDVars.castTargetMenu := CbtActs.SelectCombatTargets;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  cr := GDVars.creatureList;
  while not done do begin
    CharHlp.CountTeams;
    cr := GDVars.creatureList;
    while cr <> nil do begin
      CbtActs.BeginRound(cr);
      cr := cr^.nextCharAddr;
    end;
    GDVars.zone1^.surprise := 0;
    Combat.OrderCreatures;
    cr := GDVars.initOrder[1];
    GDVars.combatantIdx := 1;
    while cr <> nil do begin
      Combat.CreatureAction(cr);
      Inc(GDVars.combatantIdx);
      if GDVars.combatantIdx > 72 then
        cr := nil
      else
        cr := GDVars.initOrder[GDVars.combatantIdx];
    end;
    Combat.EndOfRound(done);
  end;
  if GDVars.agingFlag <> 0 then
    Combat.AgingDeaths;
  Combat.CombatDoneCleanup;
  GDVars.msgDelayFlag := 1;
end;

procedure AgingDeaths;
var
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  witness: Types.PCharRecord;
  diesOfAge: Boolean;
  warn: Boolean;
  row: ShortInt;
  count: Byte;
  he: String[4];
  msg: String[255];
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.status < C_Status.DEAD_STATUS then
      with p^ do begin
        diesOfAge := False;
        warn := False;
        { AD&D maximum ages, one arm per playable race: 1600, 325, 525, 750, 199 and 120 years, each warned about ten
          years earlier. }
        case race of
          C_Race.ELF: if age > 1600 then diesOfAge := True
             else if age > 1590 then warn := True;
          C_Race.HALF_ELF: if age > 325 then diesOfAge := True
             else if age > 315 then warn := True;
          C_Race.DWARF: if age > 525 then diesOfAge := True
             else if age > 515 then warn := True;
          C_Race.GNOME: if age > 750 then diesOfAge := True
             else if age > 740 then warn := True;
          C_Race.HALFLING: if age > 199 then diesOfAge := True
             else if age > 189 then warn := True;
          C_Race.HUMAN: if age > 120 then diesOfAge := True
             else if age > 110 then warn := True;
        end;
        if warn then
          CharHlp.PrintCreatureMessage(p, 'is looking very old', 10, True);
        if diesOfAge then begin
          row := 14;
          Border.ClearBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, White, 0, True,
                               'The strain of this last battle has worn heavily on ' + name + '.  ');
          TextRend.DisplayAndPause(LightMagenta, 0, GDConsts.continuePrompt);
          Border.ClearBox(23, row, 38, 21);
          if gender = C_Gender.MALE then
            he := 'He'
          else
            he := 'She';
          TextRend.DisplayMessageWindow(23, row, 38, 21, White, 0, True,
                               he + ' breathes deeply one last time and crumples to the ground.');
          TextRend.DisplayAndPause(LightMagenta, 0, GDConsts.continuePrompt);
          Border.ClearBox(23, row, 38, 21);
          FxEngine.KillCreature(p, C_Status.GONE, 'dies from age');
          q := GDVars.creatureList;
          while q <> nil do begin
            if (q^.enabled = 1) and (q^.status = C_Status.OKAY) and (q^.hostile <> 1) then begin
              Inc(count);
              witness := q;
            end;
            q := q^.nextCharAddr;
          end;
          case count of
            0: msg := 'Sadly, no party member witnesses the passing of the champion.';
            1: msg := witness^.name
                 + ' weeps at the loss of such a venerable companion.';
          else
            msg := ' The remaining party members are overcome with grief as they search '
              + name + '''s body for valuables.';
          end;
          Border.ClearBox(23, row, 38, 21);
          TextRend.DisplayMessageWindow(23, row, 38, 21, Yellow, 0, True, msg);
          TextRend.DisplayAndPause(LightMagenta, 0, GDConsts.continuePrompt);
        end;
      end;
    p := p^.nextCharAddr;
  end;
  GDVars.agingFlag := 0;
end;

procedure OrderCreatures;
var
  ok: Boolean;
  p: Types.PCharRecord;
  cur: Types.PCharRecord;
  nxt: Types.PCharRecord;
  ins: ShortInt;
  other: ShortInt;
  slot: Byte;
  j: Byte;
begin
  p := GDVars.creatureList;
  GameIo.FillWord(GDVars.initOrder, SizeOf(GDVars.initOrder));
  while p <> nil do begin
    slot := 1;
    ok := True;
    ins := p^.combatAddr^.initiative;
    while (slot < 65) and ok do begin
      if GDVars.initOrder[slot] <> nil then
        other := GDVars.initOrder[slot]^.combatAddr^.initiative
      else
        other := -1;
      if (ins > other) or ((ins = other) and (FxEngine.RollDice(1, 2) = 1)) then
        ok := False
      else
        Inc(slot);
    end;
    cur := GDVars.initOrder[slot];
    GDVars.initOrder[slot] := p;
    if cur <> nil then begin
      j := slot;
      ok := True;
      while (j < 72) and ok do begin
        Inc(j);
        nxt := GDVars.initOrder[j];
        GDVars.initOrder[j] := cur;
        cur := nxt;
        if nxt = nil then
          ok := False;
      end;
    end;
    p := p^.nextCharAddr;
  end;
end;

procedure CreatureAction(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  initiative: Integer;
begin
  cr^.combatAddr^.flankCountV1 := 0;
  cr^.combatAddr^.flankSpreadV1 := 0;
  cr^.combatAddr^.guarding := 0;
  FxEngine.TriggerEffectsWithCondition(7, cr);
  if cr^.combatAddr^.initiative <= 0 then
    Exit;
  if cr^.combatAddr^.initiative = 20 then
    cr^.combatAddr^.initiative := 19;
  GDVars.curChar := cr;
  GDVars.actorVisible := (cr^.hostile = 0) or CbtMap.CombatIconVisible(cr, 0);
  CbtMap.DisplayMapViewCentered(cr, 2, True);
  CharHlp.RecalcStats(cr);
  GDVars.panelDirty := 1;
  CharHlp.CombatPrintCreatureInfo(cr);
  FxEngine.TriggerEffectsWithCondition(15, cr);
  if cr^.combatAddr^.spellCast = 0 then
    FxEngine.TriggerEffectsWithCondition(21, cr);
  if cr^.combatAddr^.initiative > 0 then
    if cr^.quickfight <> 0 then
      CombatAi.CombatAiControl(cr)
    else
      Combat.ManualControl(cr);
  CbtMap.RedrawArenaCell(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr));
end;

procedure ManualControl(cr: Types.PCharRecord);
var
  ch: Char;
  done: Boolean;
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  aimInfo: array[1..3] of Byte;
  { aim menu out-param }
  aimTgt: Pointer;
  spell: Byte;
begin
  if cr^.enabled <> 0 then begin
    if cr^.combatAddr^.spellCast > 0 then begin
      spell := cr^.combatAddr^.spellCast;
      cr^.combatAddr^.spellCast := 0;
      Magic.CastSpell(spell, False, True, done);
      done := CharHlp.EndActions(cr);
    end else begin
      done := False;
      while not done do begin
        GDVars.horizChoice := 1;
        Combat.CombatMenu(cr, ch);
        if not GDVars.extKeyFlag then
          case ch of
            'Q': begin
                   Combat.TurnOnAuto(cr);
                   MenuCore.ClearBottomLine;
                   GameIo.FlushKeys;
                   Delay(200);
                   done := True;
                   CombatAi.CombatAiControl(cr);
                 end;
            'M': Combat.MoveMenu(cr, ' ', done);
            'V': begin
                   ViewChar.ViewCharMenu(done);
                   CbtActs.RecalcAttacksLeft(cr);
                   if not done then
                     CharHlp.DisplayCombatInterface;
                 end;
            'A': CbtActs.CombatAimMenu(cr, 255, 1, 0, 1, done, aimTgt);
            'U': begin
                   GDVars.horizChoice := 2;
                   ViewChar.UseItemMenu(done);
                   CbtActs.RecalcAttacksLeft(cr);
                   if not done then
                     CharHlp.DisplayCombatInterface;
                 end;
            'C': CbtActs.CastSpellCombat(0, 0, done);
            'Y': done := CharHlp.EndActions(cr);
            'D': Combat.DoneMenu(cr, done);
            ' ': begin
                   p := GDVars.creatureList;
                   while p <> nil do begin
                     if p^.npc < $80 then
                       p^.quickfight := 0;
                     p := p^.nextCharAddr;
                   end;
                 end;
          end else
          case ch of
            C_Keys.ALT_M: begin
                    GDVars.quickMagic := GDVars.quickMagic = False;
                    if GDVars.quickMagic then
                      CharHlp.PrintBottomLine('Magic On')
                    else
                      CharHlp.PrintBottomLine('Magic Off');
                  end;
            Combat.KEY_ALT_Q, Combat.KEY_ALT_A: begin
                    Dec(GDVars.combatantIdx);
                    cr^.combatAddr^.initiative := 20;
                    p := GDVars.creatureList;
                    while p <> nil do begin
                      Combat.TurnOnAuto(p);
                      p := p^.nextCharAddr;
                    end;
                    MenuCore.ClearBottomLine;
                    Delay(200);
                    done := True;
                  end;
            C_Keys.ALT_X: if CbtActs.VictoryCheat then begin
                    CbtMap.DisplayMapViewCentered(cr, 3, False);
                    done := True;
                  end else
                    CharHlp.PrintBottomLine('That doesn''t work');
          end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(cr, 2, True);
          GDVars.panelDirty := 1;
          CharHlp.CombatPrintCreatureInfo(cr);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(cr);
end;

procedure CombatMenu(cr: Types.PCharRecord; var ch: Char);
var
  menu: String[40];
  i: Byte;
  hasSpell: Boolean;
begin
  menu := '';
  if cr^.combatAddr^.movement > 0 then
    menu := menu + 'Move ';
  menu := menu + 'View Aim ';
  if cr^.numberOfItems > 0 then
    menu := menu + 'Use ';
  hasSpell := False;
  for i := 0 to 74 do
    if cr^.memorizedSpells[i] > 0 then
      hasSpell := True;
  if hasSpell and (cr^.combatAddr^.castAllowed <> 0)
     and (GDVars.zone0^.antimagic = 0) then
    menu := menu + 'Cast ';
  menu := menu + 'Quick Done';
  if GDVars.debugOn then
    menu := menu + '*';
  repeat
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, 1, 0, hasSpell);
    if hasSpell then
      if not (ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, C_Keys.ALT_X, C_Keys.ALT_M]) then
        ch := C_Keys.NONE;
  until ch in [Combat.KEY_ALT_Q, Combat.KEY_ALT_R, Combat.KEY_ALT_A, ' ', C_Keys.ALT_X, C_Keys.ALT_M, 'A', 'C',
               'D', 'M', 'Q', 'T', 'U', 'V', 'Y'];
  MenuCore.ClearBottomLine;
end;

procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  status: Byte;
  { incremented, never read }
  cnt: Byte;
begin
  GameTime.AdvanceTime(1, 1);
  Inc(GDVars.roundCounter);
  CbtActs.UpdateHostileHpPercent;
  p := GDVars.creatureList;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(19, p);
    FxEngine.ConsiderTerrainEffects(p, Byte(False));
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.damageTaken);
      if p^.combatAddr^.damageTaken > 9 then
        p^.status := C_Status.DEAD_STATUS;
    end;
    Inc(cnt);
    p := p^.nextCharAddr;
  end;
  if CharHlp.BandageDying(Byte(False)) then
    CharHlp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0)
     or (GDVars.roundCounter >= GDVars.roundLimit) then
    done := True;
  if (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0) and (not GDVars.demoMode) then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White, 2) = 'Y' then
      done := False;
end;

procedure MoveMenu(cr: Types.PCharRecord; startCh: Char; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: Byte;
  startY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slot: Integer;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Char;
  outA: Byte;
  outB: Byte;
  cost: Byte;

  { Puts the creature back where the move began, with its movement and facing restored. }
  procedure UndoMove;
  begin
    cr^.combatAddr^.movement := savedMove;
    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(cr));
    done := CbtMap.IsValidCreatureLoc(cr, startX, startY, False) = False;
    CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, C_Dir.CENTER);
    cr^.combatAddr^.direction := savedDir;
    dir := C_Dir.CENTER;
  end;

begin
  GDVars.inMoveMenu := 1;
  savedMove := cr^.combatAddr^.movement;
  savedDir := cr^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(cr);
  startY := CbtMap.CombatCellY(cr);
  ch := startCh;
  done := False;
  dir := C_Dir.CENTER;
  repeat
    while (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) and (ch <> 'D') and (done = False) do
    begin
      Border.ClearBox(24, 24, 39, 24);
      if ch = ' ' then
        ch := MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2),
                                      ' Done', LightMagenta,
                        LightGreen, White, 1, 0, GDVars.menuExt);
      case ch of
        C_Keys.NONE: UndoMove;
        C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
        C_Keys.UP: dir := C_Dir.NORTH;
        C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
        C_Keys.RIGHT: dir := C_Dir.EAST;
        C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
        C_Keys.DOWN: dir := C_Dir.SOUTH;
        C_Keys.HOME: dir := C_Dir.NORTHWEST;
        C_Keys.LEFT: dir := C_Dir.WEST;
      else
        dir := C_Dir.CENTER;
      end;
      if dir < C_Dir.CENTER then begin
        CbtMap.SetCreatureFacing(cr, dir, 0, 0);
        CbtMap.ProbeDirection(cr, dir, crIdx, terrIdx, outA, outB);
        if crIdx > 0 then
          Combat.MeleeAttack(cr, GDVars.creatures[crIdx], done)
        else if terrIdx = 0 then begin
          case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White, 2) of
            'Y': done := CbtActs.AttemptFlee(cr);
            'N': done := False;
          end;
        end else begin
          if Odd(dir) then
            cost := GDConsts.terrainInfo[terrIdx].cost * 3
          else
            cost := GDConsts.terrainInfo[terrIdx].cost * 2;
          if GDConsts.terrainInfo[terrIdx].cost = 255 then
            cost := 255;
          if cost > cr^.combatAddr^.movement then
            CharHlp.PrintBottomLine('can''t go there')
          else begin
            CbtActs.AttacksOfOpportunity(cr, dir);
            if cr^.enabled = 0 then
              done := CharHlp.EndActions(cr)
            else begin
              if cr^.combatAddr^.movement > 0 then
                CbtActs.CombatMoveCreature(cr, dir);
              if cr^.enabled = 0 then
                done := CharHlp.EndActions(cr);
              FxEngine.ConsiderTerrainEffects(cr, Byte(True));
              if CharHlp.IsHelpless(cr) then
                done := CharHlp.EndActions(cr);
            end;
          end;
        end;
      end;
      if (ch <> C_Keys.NONE) and (ch <> C_Keys.ENTER) and (ch <> 'D') then
        ch := ' ';
    end;
  until (ch <> ' ') or done;
  if cr^.combatAddr^.movement < 2 then
    cr^.combatAddr^.movement := 0;
  GDVars.inMoveMenu := 0;
end;

procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharHlp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    if CbtActs.SweepAttack(att, def) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(att, def);
      CbtActs.MakeAttack(att, def, False, nil, done);
    end;
  end;
end;

procedure DoneMenu(cr: Types.PCharRecord; var done: Boolean);
var
  menu: String[40];
  ch: Char;
  nxt: Types.PCharRecord;
  idx: Byte;
begin
  done := False;
  menu := '';
  if not CharHlp.HasRangedWeapon(cr) or CharHlp.HasThrowableWeapon(cr) then
    menu := menu + 'Guard ';
  menu := menu + 'Delay Quit ';
  if CharHlp.BandageDying(Byte(False)) then
    menu := menu + 'Bandage ';
  menu := menu + 'Speed Exit';
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) and (done = False) do
  begin
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, 0, 0, GDVars.menuExt);
    case ch of
      'G': done := CharHlp.Guard(cr);
      'D': begin
             cr^.combatAddr^.initiative := 1;
             idx := GDVars.combatantIdx;
             nxt := GDVars.initOrder[idx + 1];
             while (nxt <> nil) and (idx < 72) do begin
               GDVars.initOrder[idx] := nxt;
               Inc(idx);
               nxt := GDVars.initOrder[idx + 1];
             end;
             GDVars.initOrder[idx] := cr;
             Dec(GDVars.combatantIdx);
             done := True;
           end;
      'Q': done := CharHlp.EndActions(cr);
      'B': begin
             done := CharHlp.BandageDying(Byte(True));
             { immediately overwritten }
             done := CharHlp.EndActions(cr);
           end;
      'S': Combat.SpeedMenu;
    end;
  end;
end;

procedure SpeedMenu;
var
  menu: String[40];
  query: String[40];
  ch: Char;
begin
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + CharHlp.Uint8Str(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, 0, 0, GDVars.menuExt);
    case ch of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
end;

procedure TurnOnAuto(cr: Types.PCharRecord);
begin
  cr^.quickfight := 1;
  if (cr^.combatAddr^.other <> nil)
     and (cr^.combatAddr^.other^.hostile = cr^.hostile) then
    cr^.combatAddr^.other := nil;
end;

begin
end.
