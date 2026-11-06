{ Monster and NPC combat AI. }
{$O+,F+,I-,R-,S-}
unit CombatAi;

interface

uses Types, CbtActs, ViewChar, Magic, FxEngine, CharHlp, ClassCal, MenuCore, Pathing, CbtMap, TextRend, GameIo, Crt,
  GDConsts, GDVars, C_Status, C_Effect, C_Keys, C_Save;

{ Runs one AI-controlled turn: checks the keyboard (Space can return the party to manual control), rerolls the approach
  pattern (kept on three turns out of four for patterns 1..4), checks morale, then tries in order an item's spell
  effect, a spell begun earlier and a new spell, and otherwise re-equips and runs the move/attack loop until the
  creature is done.
  @param(cr The creature taking its turn.) }
procedure CombatAiControl(cr: Types.PCharRecord);

{ Uses an equipped item's spell when the creature may use items, an enemy team remains and there is no antimagic. Over
  1d7 passes the lowest AI priority accepted falls from 7, and the first equipped item that is not readable, has a
  special below $80 and a spell DecideCastSpell accepts is used. Item effects above 56 map to the spell entries 23
  lower.
  @param(cr The creature.)
  @returns(True when an item was used.) }
function SelectItemToUse(cr: Types.PCharRecord): Boolean;

{ Picks a spell for an NPC, or for a party member while magic is on (Alt-M), when enemies remain; a creature that may
  not cast, has nothing in its spellbook (which also clears its casting flag) or is feebleminded casts nothing. Over 1d7
  passes the minimum AI priority drops from 7, with three random picks per pass from the spellbook entries; the first
  spell DecideCastSpell accepts goes to CastSpellCombat.
  @param(cr The caster.)
  @returns(CastSpellCombat's done flag, or False when no spell was cast.) }
function SelectSpellToCast(cr: Types.PCharRecord): Boolean;

{ Runs the AI's move/attack loop (the 21st pass finishes the round): fires condition-14 effects, lets a party member
  bandage a dying teammate (ending its turn), moves a fleeing creature away, then attacks the locked target if it is a
  hostile in weapon range and in sight (a locked party-side target is dropped, so hostile creatures never use theirs
  here), or a random enemy in range, or moves toward a target. A ranged weapon that cannot fire with an enemy adjacent
  makes it re-equip and stop. Attacks try a sweep first. Note: the locked target is read before it is checked for nil,
  and the pass that finishes the round for the pass limit still goes on to seek and attack a target.
  @param(cr The acting creature.)
  @returns(True when the creature can no longer act.) }
function AiMoveAttack(cr: Types.PCharRecord): Boolean;

{ Ends the creature's round: a helpless, ranged-armed or out-of-initiative creature just ends its actions; others guard.
  @param(cr The creature.)
  @returns(What ending the actions or guarding returns.) }
function FinishRound(cr: Types.PCharRecord): Boolean;

{ Handles a key pressed during an AI turn: Alt-M toggles quick magic, space returns each creature that is neither a
  non-player character nor animated to manual control, and Alt-X tries the victory cheat. Pending keys are discarded
  afterwards. Note: the key is tested whether or not the extended-key prefix came first, so an unprefixed 2 also toggles
  quick magic and an unprefixed hyphen also tries the cheat.
  @param(cr The creature.)
  @returns(True when space put the creature itself back under manual control, which marks it to act again at once.) }
function CheckKeystroke(cr: Types.PCharRecord): Boolean;

{ Clears the creature's fleeing flag and AI effects, then checks a non-player character's morale (party characters never
  check; a turned creature is forced to flee). Morale is twice the low 7 bits of its non-player-character byte (0 above
  102), adjusted by condition-17 effects, and it holds when it is nonzero and covers the creature's own hit-point loss
  in percent. Failing that, a hostile still holds when the hostiles' remaining hit-point percentage, adjusted the same
  way, is nonzero and at least 100 less the zone's morale threshold. On a failure the creature flees if it is at least
  twice as fast as the fastest enemy; otherwise one with Intelligence above 5 surrenders.
  @param(cr The creature.)
  @returns(True on surrender.) }
function CheckMorale(cr: Types.PCharRecord): Boolean;

{ Re-equips a creature with its best usable weapon (CalcWeaponPriority; its unarmed damage sets the bar for melee) and
  its best shield (plus + 1). The ranged pick wins when it scores above half the melee score, has ammunition, and is a
  true ranged weapon or no enemy is beside the creature. Cursed items are never swapped out; with too many hands in use
  the shield, or else the weapon, is unreadied. The creature's information is redrawn when anything changed.
  @param(cr The creature.) }
procedure EquipWeaponAndArmor(cr: Types.PCharRecord);

implementation

procedure CombatAiControl(cr: Types.PCharRecord);
var
  { the AI approach-pattern index, 1..6 }
  pat: Byte;
  done: Boolean;
begin
  done := CombatAi.CheckKeystroke(cr);
  MenuCore.ClearBottomLine;
  CharHlp.ClearMessageWindow;
  if cr^.enabled = 0 then done := CharHlp.EndActions(cr);
  pat := cr^.combatAddr^.approach;
  if (pat = 0) or (pat > 4) or (FxEngine.RollDice(1, 4) = 1) then begin
    pat := FxEngine.RollDice(1, 8);
    if pat = 8 then pat := FxEngine.RollDice(1, 2) + 4
               else pat := FxEngine.RollDice(1, 4);
  end;
  cr^.combatAddr^.approach := pat;
  if not done then done := CombatAi.CheckMorale(cr);
  if (cr^.combatAddr^.fleeing <> 0) and (cr^.combatAddr^.forcedFlee = 0) then
    CharHlp.PrintCreatureMessage(cr, 'flees in panic', 10, True);
  if not done then begin
    if CombatAi.SelectItemToUse(cr) then
      done := CharHlp.EndActions(cr)
    else if cr^.combatAddr^.spellCast > 0 then begin
      Magic.CastSpell(cr^.combatAddr^.spellCast, True, True, done);
      done := CharHlp.EndActions(cr);
    end else if CombatAi.SelectSpellToCast(cr) then
      done := True
    else begin
      CombatAi.EquipWeaponAndArmor(cr);
      done := CombatAi.CheckKeystroke(cr);
      while not done do
        if CbtActs.AcquireTarget(cr, 255, 1, 0) and (cr^.combatAddr^.initiative > 0)
           and (cr^.enabled <> 0)
          then done := CombatAi.AiMoveAttack(cr)
          else done := CombatAi.FinishRound(cr);
    end;
  end;
end;

{ Decides whether the AI should use a spell (from its spellbook, or an item's spell effect). Its AI priority must be at
  least `minPri`. Non-offensive spells other than Cure Light Wounds always qualify, as does Cure Light Wounds with a
  cure target. Everything else needs an enemy within the spell's range and, for an area spell, no candidate target whose
  area would catch a creature off the caster's enemy team that fails a saving throw, rolled at once (-2 for a party
  caster, +8 for a hostile one); a spell whose save result is 1 never counts as catching one.
  @param(cr The caster.)
  @param(spell The spell.)
  @param(minPri The lowest AI priority accepted.)
  @returns(True when the AI should cast the spell.) }
function DecideCastSpell(cr: Types.PCharRecord; spell, minPri: Byte): Boolean;
var
  { out-parameter buffer for FindCureTarget; never read back }
  tgt: Pointer;
  { candidate count }
  n: Byte;
  i: Byte;

  { Tells whether the spell's area around (x, y) catches a non-enemy of the current character that fails its save. }
  function AreaHitsNonEnemy(x, y: ShortInt; spell: Byte): Boolean;
  var
    i: Byte;
    { save modifier: 254 (-2 as a byte) for the party, 8 for monsters }
    k: Byte;
  begin
    AreaHitsNonEnemy := False;
    if GDVars.curChar^.hostile = 0 then k := 254 else k := 8;
    Pathing.BuildTargetList(x, y, GDConsts.spellDefs[spell].aiRadius, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      if GDVars.creatures[GDVars.targets[i].who]^.hostile <> CharHlp.EnemyTeam(GDVars.curChar) then
        if GDConsts.spellDefs[spell].saveEffect <> 1 then
          if not FxEngine.RollSavingThrow(GDVars.creatures[GDVars.targets[i].who], GDConsts.spellDefs[spell].saveType,
                                          k) then
            AreaHitsNonEnemy := True;
  end;

begin
  DecideCastSpell := False;
  if GDConsts.spellDefs[spell].aiPriority >= minPri then begin
    if ((spell <> 3) and (GDConsts.spellDefs[spell].offensive = 0))
       or ((spell = 3) and CbtActs.FindCureTarget(cr, tgt)) then
      DecideCastSpell := True
    else begin
      n := CharHlp.CountTargets(cr, Magic.CalcSpellRange(spell));
      if n > 0 then begin
        if GDConsts.spellDefs[spell].aiRadius = 0 then
          DecideCastSpell := True
        else begin
          for i := 1 to n do
            if AreaHitsNonEnemy(GDVars.arenaLoc[GDVars.targetIdx[i]].x, GDVars.arenaLoc[GDVars.targetIdx[i]].y,
                                spell) then
              Exit;
          DecideCastSpell := True;
        end;
      end;
    end;
  end;
end;

function SelectItemToUse(cr: Types.PCharRecord): Boolean;
var
  { priority floor, decremented per attempt }
  minPri: Byte;
  tries: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Word;
  { Unused in this version; see the other implementations of this routine. }
  itemSlot: Byte;
  spell: Byte;
  { Unused in this version; see the other implementations of this routine. }
  baseItem: Pointer;
  it: Types.PItemRec;
  best: Types.PItemRec;
  used: Boolean;
begin
  SelectItemToUse := False;
  best := nil;
  minPri := 7;
  tries := FxEngine.RollDice(1, 7);
  if cr^.combatAddr^.itemUseAllowed <> 0 then
    if GDVars.teamCount[CharHlp.EnemyTeam(cr)] > 0 then
      if GDVars.zone0^.antimagic = 0 then
        for i := 1 to tries do begin
          it := cr^.itemsAddr;
          while (it <> nil) and (best = nil) do begin
            spell := it^.spells[2];
            itemSlot := GDVars.baseItems[it^.itemType].slot;
            if (not Magic.ItemReadable(it)) and (it^.spells[3] < $80)
               and (it^.equipped <> 0) and (spell > 0) then begin
              if spell > 56 then spell := spell - 23;
              if CombatAi.DecideCastSpell(cr, spell, minPri) then best := it;
            end;
            it := it^.next;
          end;
          Dec(minPri);
        end;
  if best <> nil then begin
    ViewChar.UseItem(best, used);
    SelectItemToUse := True;
  end;
end;

function SelectSpellToCast(cr: Types.PCharRecord): Boolean;
var
  { the dense candidate list }
  list: array[0..74] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellTarget: Pointer;
  minPri: Byte;
  tries: Byte;
  pick: Boolean;
  attempt: Byte;
  inner: Byte;
  count: Byte;
  i: Byte;
  spell: Byte;
  best: Byte;
  eff: Types.PEffectRec;
begin
  if (cr^.combatAddr^.hasSpells = 0) or (cr^.combatAddr^.castAllowed = 0)
     or CharHlp.HasEffect(cr, C_Effect.FEEBLEMINDED, eff) then begin
    SelectSpellToCast := False;
    Exit;
  end;
  count := 0;
  for i := 1 to 74 do
    if cr^.spellBook[i] > 0 then begin
      list[count] := cr^.spellBook[i];
      Inc(count);
    end;
  if count = 0 then begin
    cr^.combatAddr^.hasSpells := 0;
    SelectSpellToCast := False;
    Exit;
  end;
  best := 0;
  minPri := 7;
  tries := FxEngine.RollDice(1, 7);
  attempt := 1;
  if count > 0 then
    if (cr^.npc > $7F) or GDVars.quickMagic then
      if GDVars.teamCount[CharHlp.EnemyTeam(cr)] > 0 then
        while (attempt <= tries) and (best = 0) do begin
          inner := 1;
          while (inner < 4) and (best = 0) do begin
            i := FxEngine.RollDice(1, count) - 1;
            spell := list[i];
            if CombatAi.DecideCastSpell(cr, spell, minPri) then best := spell;
            Inc(inner);
          end;
          Dec(minPri);
          Inc(attempt);
        end;
  if best > 0 then CbtActs.CastSpellCombat(best, 1, pick)
               else pick := False;
  SelectSpellToCast := pick;
end;

{ Checks a step in direction baseDir plus the approach pattern's offset for attempt. Off the arena sets edge and fails;
  an occupied or impassable cell fails. The step costs 2 (orthogonal) or 3 (diagonal) times the terrain cost and must be
  less than the movement left. Next to a stinking cloud the creature balks unless it has effect 30, 63, 57 or 99, is
  turned, or makes a paralyzation save; next to cloudkill a creature with a movement rate below 7 balks unless it has
  effect 99 or is turned.
  @param(cr The moving creature.)
  @param(attempt The attempt, 1..5, which picks the pattern's turn.)
  @param(baseDir The wanted direction, 0..7.)
  @param(edge Set True when the step would leave the arena, else False.)
  @returns(True when the creature can take the step.) }
function AiCanStep(cr: Types.PCharRecord; attempt, baseDir: Byte; var edge: Boolean): Boolean;
var
  eff: Types.PEffectRec;
  pat: Byte;
  dir: Byte;
  { ProbeDirection out-params, in its declared order }
  crIdx: Byte;
  terrIdx: Byte;
  cost: Byte;
  adjStink: Byte;
  adjCloudkill: Byte;
  ok: Boolean;
begin
  edge := False;
  ok := False;
  pat := GDConsts.approachPatterns[cr^.combatAddr^.approach, attempt];
  dir := (baseDir + pat) mod 8;
  CbtMap.ProbeDirection(cr, dir, crIdx, terrIdx, adjStink, adjCloudkill);
  if terrIdx = 0 then
    edge := True
  else begin
    if GDConsts.terrainInfo[terrIdx].cost = 255 then begin
      AiCanStep := False;
      Exit;
    end;
    { diagonal steps cost 3x, orthogonal 2x }
    if Odd(dir) then cost := GDConsts.terrainInfo[terrIdx].cost * 3
                else cost := GDConsts.terrainInfo[terrIdx].cost shl 1;
    if (crIdx = 0) and (cost < cr^.combatAddr^.movement) then begin
      if (adjStink <> 0) and (not CharHlp.HasEffect(cr, C_Effect.STINKING_CLOUD_COUGH, eff))
         and (not CharHlp.HasEffect(cr, 63, eff))
         and (not CharHlp.HasEffect(cr, 57, eff))
         and (not CharHlp.HasEffect(cr, 99, eff))
         and (cr^.combatAddr^.forcedFlee = 0)
         and (not FxEngine.RollSavingThrow(cr, C_Save.PARALYZATION, 0)) then
        cost := cr^.combatAddr^.movement + 1;
      if (adjCloudkill <> 0) and (cr^.movementRate < 7)
         and (not CharHlp.HasEffect(cr, 99, eff))
         and (cr^.combatAddr^.forcedFlee = 0) then
        cost := cr^.combatAddr^.movement + 1;
      if cr^.combatAddr^.movement >= cost then ok := True;
    end;
  end;
  AiCanStep := ok;
end;

{ Takes one AI movement step: toward the locked target, or for a fleeing creature away from the party's facing (the
  party flees the other way), trying up to five directions from the approach pattern; a fleeing creature at the arena
  edge tries to flee. A magic-user without armor does not advance, and an NPC advances when it passes a morale roll
  against the hostiles' remaining hit points, while party characters and hostile creatures always may. A step back the
  way it came, or no usable direction, counts as stuck and rotates the pattern; stuck twice drops the target, three
  times stops moving. The step allows opportunity attacks and terrain effects.
  @param(cr The moving creature.) }
procedure AiMoveStep(cr: Types.PCharRecord);
var
  dir: Byte;
  newDir: Byte;
  attempt: Byte;
  { AiCanStep's out-parameter }
  edge: Boolean;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  combat: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  steps: Byte;
begin
  TextRend.DisplayString(0, 24, LightGreen, 0,
                         'Move/Attack, Move Left = ' + CharHlp.Uint8Str(cr^.combatAddr^.movement div 2) + ' ');
  if CombatAi.CheckKeystroke(cr) then Exit;
  { Note: the second npc test is unreachable given the first. }
  if (cr^.combatAddr^.movement div 2 > 0)
     and (cr^.combatAddr^.initiative > 0)
     and ((cr^.npc < $80) or ((cr^.npc > $7F) and (GDVars.hostileHpPercent <= GDVars.morale + FxEngine.RollDice(1,
         100))) or (cr^.hostile = 1))
     and
       ((cr^.combatAddr^.fleeing <> 0) or (cr^.equipped[2] <> nil) or (cr^.charClassV2 <> 5) or
        (Ord(ClassCal.EarlierClassActive(cr)) > 0)) then begin
    if cr^.combatAddr^.fleeing = 0 then
      dir := CharHlp.DirTowardTarget(cr, cr^.combatAddr^.otherV1)
    else begin
      cr^.combatAddr^.approach := FxEngine.RollDice(1, 2);
      dir := GDVars.partyPos.facing - (GDVars.partyPos.facing + 2) mod 4 div 2;
      if cr^.hostile = 0 then dir := dir + 4;
      dir := dir mod 8;
    end;
    edge := False;
    done := False;
    attempt := 1;
    { the then-arm skips the increment: a creature that is fleeing and has reached the arena edge retries the same
      attempt index. }
    while (attempt < 6) and (not done)
          and (not CombatAi.AiCanStep(cr, attempt, dir, edge)) do
      if (cr^.combatAddr^.fleeing <> 0) and edge then
        done := CbtActs.AttemptFlee(cr)
      else
        Inc(attempt);
    if done then begin
      cr^.combatAddr^.movement := 0;
      cr^.combatAddr^.fleeing := 0;
      done := CharHlp.EndActions(cr);
    end else begin
      { Note: attempt is 6 when the loop ran out: this reads one cell past the row }
      newDir := (dir + GDConsts.approachPatterns[cr^.combatAddr^.approach, attempt]) mod 8;
      { gOccA holds the previous step's direction; walking back the way we came is what rotates the approach pattern. }
      if (attempt = 6) or (GDVars.gOccA = (newDir + 4) mod 8) then begin
        Inc(GDVars.gOccB);
        cr^.combatAddr^.approach := cr^.combatAddr^.approach mod 6 + 1;
        if GDVars.gOccB > 1 then begin
          cr^.combatAddr^.otherV1 := nil;
          if GDVars.gOccB > 2 then begin
            cr^.combatAddr^.movement := 0;
            done := True;
          end else if not CbtActs.AcquireTarget(cr, 255, 1, 0) then
            done := CombatAi.FinishRound(cr);
        end;
      end;
      if attempt < 6 then GDVars.gOccA := newDir else done := True;
    end;
    if not done then begin
      GDVars.actorVisible := (GDVars.moveBlocked <> 0) or CbtMap.CombatIconVisible(cr, 0) or (cr^.hostile = 0);
      CbtMap.SetCreatureFacing(cr, newDir, 0, 0);
      CbtActs.AttacksOfOpportunity(cr, cr^.combatAddr^.direction);
      if cr^.enabled = 0 then
        done := CharHlp.EndActions(cr)
      else begin
        if cr^.combatAddr^.movement > 0 then
          CbtActs.CombatMoveCreature(cr, cr^.combatAddr^.direction);
        if (cr^.enabled = 0) or CharHlp.IsHelpless(cr) then done := CharHlp.EndActions(cr);
        FxEngine.ConsiderTerrainEffects(cr, 1);
      end;
    end;
  end else
    done := CombatAi.FinishRound(cr);
end;

function AiMoveAttack(cr: Types.PCharRecord): Boolean;
var
  { also MakeAttack's out-parameter }
  stop: Boolean;
  acting: Boolean;
  { weapon range minus one, floored at 1 }
  reach: Byte;
  { WalkLine's out-parameter, the doubled distance }
  dist: Word;
  nTargets: Byte;
  pick: Byte;
  victim: Types.PItemRec;
  tgt: Types.PCharRecord;
  tx: ShortInt;
  ty: ShortInt;
  rounds: Byte;
begin
  GDVars.gOccA := 8;
  GDVars.gOccB := 0;
  GDVars.gOccC := 0;
  rounds := 0;
  acting := True;
  stop := False;
  FxEngine.TriggerEffectsWithCondition(14, cr);
  if (cr^.hostile = 0) and CharHlp.BandageDying(1) then
    cr^.combatAddr^.initiative := 0;
  if cr^.combatAddr^.initiative = 0 then acting := False;
  while (not stop) and acting do begin
    if cr^.combatAddr^.fleeing <> 0 then
      while (cr^.combatAddr^.movement > 0)
            and (cr^.combatAddr^.initiative > 0)
            and (cr^.combatAddr^.initiative < 20) do
        CombatAi.AiMoveStep(cr);
    if (cr^.combatAddr^.initiative = 0)
       or (cr^.combatAddr^.initiative = 20)
      then acting := False
      else stop := False;
    if (not stop) and acting then begin
      Inc(rounds);
      if rounds > 20 then begin
        stop := True;
        acting := not CombatAi.FinishRound(cr);
      end;
      GDVars.moveBlocked := 0;
      reach := 1;
      if cr^.equipped[0] <> nil then
        reach := GDVars.baseItems[cr^.equipped[0]^.itemType].range - 1;
      if (reach = 0) or (reach = 255) then reach := 1;
      tgt := cr^.combatAddr^.otherV1;
      if (tgt^.enabled = 0) or (tgt^.hostile = 0) then tgt := nil;
      if tgt <> nil then
        if CbtActs.CanTarget(cr, tgt) then begin
          tx := CbtMap.CombatCellX(tgt);
          ty := CbtMap.CombatCellY(tgt);
          dist := reach;
          GDVars.arenaPtr^.distMode := 0;
          if Pathing.WalkLine(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), tx, ty, dist, GDVars.arenaPtr) then
            { dist is a Word, and it comes back doubled }
            if dist div 2 <= reach then GDVars.moveBlocked := 1;
        end;
      if GDVars.moveBlocked = 0 then begin
        nTargets := CharHlp.CountTargets(cr, reach);
        if nTargets = 0 then begin
          if CbtActs.AcquireTarget(cr, 255, 0, 0) then CombatAi.AiMoveStep(cr)
                                    else stop := CombatAi.FinishRound(cr);
        end else begin
          pick := FxEngine.RollDice(1, nTargets);
          tgt := GDVars.creatures[GDVars.targetIdx[pick]];
          if CharHlp.HasRangedWeapon(cr) and (not CharHlp.HasThrowableWeapon(cr)) and (CharHlp.CountTargets(cr,
              1) > 0) then begin
            CombatAi.EquipWeaponAndArmor(cr);
            stop := True;
          end else if (CharHlp.CalcDistance(cr, tgt) = 1) or CbtActs.CanTarget(cr, tgt) then
            GDVars.moveBlocked := 1;
        end;
      end;
      if GDVars.moveBlocked <> 0 then
        CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 2, CharHlp.DirTowardTarget(cr, tgt));
      if GDVars.moveBlocked <> 0 then begin
        if CbtActs.SweepAttack(cr, tgt) then
          stop := CharHlp.EndActions(cr)
        else begin
          CbtActs.NoteAttackDirection(cr, tgt);
          victim := nil;
          if CharHlp.HasRangedWeapon(cr) then begin
            GDVars.moveBlocked := Ord(CharHlp.FindDamagingRangedWeapon(cr, victim));
            if CharHlp.HasThrowableWeapon(cr) and (CharHlp.CalcDistance(cr, tgt) = 1) then victim := nil;
          end;
          CbtActs.MakeAttack(cr, tgt, False, victim, stop);
          if stop then acting := False
                  else if tgt^.enabled = 0 then stop := True;
        end;
      end;
    end;
  end;
  AiMoveAttack := not acting;
end;

function FinishRound(cr: Types.PCharRecord): Boolean;
begin
  CharHlp.ClearMessageWindow;
  if CharHlp.IsHelpless(cr) or CharHlp.HasRangedWeapon(cr) or (cr^.combatAddr^.initiative = 0)
    then FinishRound := CharHlp.EndActions(cr)
    else FinishRound := CharHlp.Guard(cr);
end;

function CheckKeystroke(cr: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
  key: Char;
begin
  CheckKeystroke := False;
  if GameIo.InputPending then begin
    key := GameIo.ReadGameKey;
    if key = #0 then key := GameIo.ReadGameKey;
    case key of
      { Alt-M -- toggle spellcasting }
      C_Keys.ALT_M:
        begin
          GDVars.quickMagic := GDVars.quickMagic = False;
          if GDVars.quickMagic then CharHlp.PrintBottomLine('Magic On')
                          else CharHlp.PrintBottomLine('Magic Off');
        end;
      { quickfight the whole party }
      ' ':
        begin
          p := GDVars.creatureList;
          while p <> nil do begin
            if (p^.npc < $80) and (p^.status <> C_Status.ANIMATED) then p^.quickfightV1 := 0;
            p := p^.nextCharAddr;
          end;
          if cr^.quickfightV1 = 0 then begin
            cr^.combatAddr^.initiative := 20;
            CheckKeystroke := True;
          end;
        end;
      C_Keys.ALT_X: if CbtActs.VictoryCheat then ;
    end;
  end;
  GameIo.FlushKeys;
end;

function CheckMorale(cr: Types.PCharRecord): Boolean;
var
  moraleRoll: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedMorale: Byte;
begin
  CheckMorale := False;
  cr^.combatAddr^.fleeing := 0;
  FxEngine.RemoveAiEffects(cr);
  if cr^.combatAddr^.forcedFlee <> 0 then begin
    cr^.combatAddr^.fleeing := 1;
    CharHlp.PrintCreatureMessage(cr, 'is forced to flee', 10, True);
  end else if cr^.npc > $7F then begin
    GDVars.morale := (cr^.npc and $7F) shl 1;
    if GDVars.morale > 102 then GDVars.morale := 0;
    FxEngine.TriggerEffectsWithCondition(17, cr);
    if (GDVars.morale < 100 - cr^.hpCur * 100 div cr^.hpMax) or (GDVars.morale = 0) then begin
      savedMorale := GDVars.morale;
      GDVars.morale := GDVars.hostileHpPercent;
      FxEngine.TriggerEffectsWithCondition(17, cr);
      if (GDVars.morale < 100 - GDVars.zone1^.moraleThreshold) or (GDVars.morale = 0)
         or (cr^.hostile = 0) then begin
        moraleRoll := CbtActs.HighestEnemyMovement(cr);
        if moraleRoll <= CharHlp.RecalcMovement(cr) div 2 then
          cr^.combatAddr^.fleeing := 1
        else if cr^.intCur > 5 then begin
          FxEngine.PutOutOfPlayWithStatus(cr, C_Status.UNCONSCIOUS, 'Surrenders');
          CheckMorale := CharHlp.EndActions(cr);
        end;
      end;
    end;
  end;
end;

{ Scores a weapon for EquipWeaponAndArmor: damage dice product, +8 per plus, +2 per damage bonus, +2 per extra shot for
  a launcher, +3 one-handed. The score is zero when it would bring the hands in use to 3 or more, for an aligned weapon
  (special $84) of another alignment, for an item with spell effect 83, and when cursed.
  @param(cr The creature that would wield the weapon.)
  @param(it The weapon.)
  @returns(The score.) }
function CalcWeaponPriority(cr: Types.PCharRecord; it: Types.PItemRec): Byte;
var
  pri: Byte;
  base: Types.TBaseItem;
begin
  base := GDVars.baseItems[it^.itemType];
  pri := base.dmgSmDice * base.dmgSmRolls;
  if it^.plus > 0 then pri := pri + (it^.plus shl 3);
  if base.dmgSmMod > 0 then pri := pri + (base.dmgSmMod shl 1);
  if (base.props and 8) > 0 then
    pri := pri + ((base.rateOfFire - 1) shl 1);
  if base.hands <= 1 then pri := pri + 3;
  if base.hands + cr^.handsEquipped >= 3 then pri := 0;
  if (it^.spells[3] = $84) and ((it^.spells[2] and $F) <> Byte(cr^.alignment)) then
    pri := 0;
  if it^.spells[2] = 83 then pri := 0;
  if it^.cursed <> 0 then pri := 0;
  CalcWeaponPriority := pri;
end;

procedure EquipWeaponAndArmor(cr: Types.PCharRecord);
var
  { props bit 3 or 4 -- the missile candidate }
  bestRanged: Types.PItemRec;
  { everything without props bit 3 }
  bestMelee: Types.PItemRec;
  bestShield: Types.PItemRec;
  { the list walker, then the chosen weapon }
  it: Types.PItemRec;
  ammo: Types.PItemRec;
  rangedPri: Byte;
  { seeded from the unarmed attack }
  meleePri: Byte;
  shieldPri: Byte;
  pri: Byte;
  baseIdx: Byte;
  props: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hands: Byte;
  mayEquip: Boolean;
  changed: Boolean;
  trueRanged: Boolean;
  haveAmmo: Boolean;
begin
  if cr^.equipped[0] <> nil then
    cr^.handsEquipped := cr^.handsEquipped
                         - GDVars.baseItems[cr^.equipped[0]^.itemType].hands;
  bestRanged := nil;
  bestMelee := nil;
  bestShield := nil;
  rangedPri := 1;
  meleePri := cr^.unarmedDiceA[1] * cr^.unarmedRollsA[1];
  if cr^.unarmedModA[1] > 0 then
    meleePri := meleePri + (cr^.unarmedModA[1] shl 1);
  shieldPri := 0;
  it := cr^.itemsAddr;
  while it <> nil do begin
    baseIdx := it^.itemType;
    if GDVars.baseItems[baseIdx].slot = 0 then
      if (GDVars.baseItems[baseIdx].classMask and cr^.classMaskV1) <> 0 then begin
        pri := CombatAi.CalcWeaponPriority(cr, it);
        if ((GDVars.baseItems[baseIdx].props and 8) <> 0)
           or ((GDVars.baseItems[baseIdx].props and $10) <> 0) then
          if pri > rangedPri then begin
            bestRanged := it;
            rangedPri := pri;
          end;
        if ((GDVars.baseItems[baseIdx].props and 8) = 0) and (pri > meleePri) then begin
          bestMelee := it;
          meleePri := pri;
        end;
      end;
    if GDVars.baseItems[baseIdx].slot = 1 then
      if (GDVars.baseItems[baseIdx].classMask and cr^.classMaskV1) > 0 then begin
        if it^.plus >= 0 then pri := it^.plus + 1 else pri := 0;
        if pri > shieldPri then begin
          bestShield := it;
          shieldPri := pri;
        end;
      end;
    it := it^.next;
  end;
  if (bestRanged <> nil) and (GDVars.baseItems[bestRanged^.itemType].range > 1)
     and ((GDVars.baseItems[bestRanged^.itemType].props and $14) = $14)
    then trueRanged := True
    else trueRanged := False;
  haveAmmo := False;
  ammo := nil;
  props := 0;
  if bestRanged <> nil then begin
    props := GDVars.baseItems[bestRanged^.itemType].props;
    if (props and $10) <> 0 then ammo := bestRanged;
    if (props and 8) <> 0 then begin
      if (props and 1) <> 0 then ammo := cr^.equipped[11];
      if (props and $80) <> 0 then ammo := cr^.equipped[12];
    end;
  end;
  if (ammo <> nil) or (props = $A) then haveAmmo := True;
  if (bestRanged <> nil) and (rangedPri > meleePri div 2) and haveAmmo
     and (trueRanged or (not Boolean(CharHlp.CountTargets(cr, 1))))
    then it := bestRanged
    else it := bestMelee;
  changed := False;
  mayEquip := True;
  if cr^.equipped[0] <> nil then
    if (cr^.equipped[0] = it) or (cr^.equipped[0]^.cursed <> 0) then
      mayEquip := False;
  if mayEquip then begin
    if cr^.equipped[0] <> nil then ViewChar.ToggleReadyItem(cr^.equipped[0]);
    CharHlp.RecalcStats(cr);
    if (cr^.equipped[1] <> nil) and (cr^.equipped[1]^.cursed = 0) then
      cr^.handsEquipped := cr^.handsEquipped
                           - GDVars.baseItems[cr^.equipped[1]^.itemType].hands;
    if it <> nil then ViewChar.ToggleReadyItem(it);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  CbtActs.RecalcAttacksLeft(cr);
  mayEquip := True;
  if cr^.equipped[1] <> nil then
    if (cr^.equipped[1] = bestShield) or (cr^.equipped[1]^.cursed <> 0) then
      mayEquip := False;
  if cr^.handsEquipped > 2 then begin
    if (cr^.equipped[1] = nil) or (cr^.equipped[1]^.cursed <> 0) then begin
      ViewChar.ToggleReadyItem(it);
      changed := True;
    end else begin
      ViewChar.ToggleReadyItem(cr^.equipped[1]);
      changed := True;
    end;
  end else if (cr^.handsEquipped < 2) and mayEquip then begin
    if cr^.equipped[1] <> nil then ViewChar.ToggleReadyItem(cr^.equipped[1]);
    CharHlp.RecalcStats(cr);
    if bestShield <> nil then ViewChar.ToggleReadyItem(bestShield);
    changed := True;
  end;
  CharHlp.RecalcStats(cr);
  if changed then CharHlp.CombatPrintCreatureInfo(cr);
end;

begin
end.
