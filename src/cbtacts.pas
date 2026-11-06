{ Combat actions: movement, attacks and target selection. This overlay runs a creature's turn after combatMain selects
  it. Its interface covers round setup, arena movement and opportunity attacks, flee attempts, weapon damage and attack
  resolution, spell and manual targeting, ally-attack confirmation, ranged animation, enemy movement, and the STING
  victory shortcut. buildAimTargets and advanceAimTarget are nested inside CombatAimMenu. }
{$O+,F+,A-,I-,V-}
unit CbtActs;

interface

uses Types, GDConsts, GDVars, C_Status, C_Keys, C_Dir, C_Spell, GameIo,
  SoundDrv, Crt, CharHlp, CbtMap, FxEngine, Pathing, MapTiles, Blit, Magic, ViewChar, MenuCore, Border, TextRend,
  ClassCal;

type
  { The manual-aim target: the creature, then x and y; the last byte is unused. It is not the internal targets[] element
    inside CombatAimMenu. }
  TAimTarget = record
    ptr: Types.PCharRecord;
    x: Byte;
    y: Byte;
    yTail: Byte;
  end;

{ Resets a creature for a new round: no spell being cast, casting allowed unless it stands in a stinking cloud, item use
  allowed, no attack made yet, the attack phase at 2, its current attacks (RecalcAttacksLeft, then the secondary attacks
  through AttacksFromRate after the condition-18 effects), its sweep budget (its attack level), its initiative and its
  movement. Initiative is 1d6 plus CharHlp.DexMissileAdjust's adjustment, at least 1, less 6 when the zone's surprise
  mask has the creature's side bit set (1 for the party, 2 for hostiles), and 0 for a creature out of play or a result
  outside 0..20.
  @param(creature The creature starting the round.) }
procedure BeginRound(creature: Types.PCharRecord);

{ Rolls one attack's damage into GDVars.pendingDamage: the current damage dice of the attack phase plus its modifier,
  adjusted by attacker's condition-4 and defender's condition-5 effects, then multiplied on a backstab by (thief level -
  1) div 4 + 2, where the thief level counts earlier thief levels while ClassCal.EarlierClassActive allows them. It then
  clears the damage element mask. Note: GDVars.pendingDamage is a Byte, so the test for a negative total never passes
  and a negative total wraps.
  @param(attacker The creature dealing the damage.)
  @param(defender The creature hit; it is tested for a backstab.)
  @param(phase Attack phase, 1 or 2, whose dice and modifier are used.) }
procedure CalcWeaponDamage(attacker, defender: Types.PCharRecord; phase: Byte);

{ Prints the attack message and, on a hit, inflicts the damage. Nonzero damage stops the defender casting this round and
  loses a spell it is casting, ending its actions. A defender that goes down is reported as going down, dying or killed,
  loses its hit-point-0 effects and, if still out of play, goes to CbtMap.CreatureDowned.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(manner 1 from behind, 2 a backstab, 3 slays a helpless target; anything else is a plain attack.)
  @param(damage Hit points inflicted on a hit.)
  @param(shownDamage The damage figure printed.)
  @param(isHit True for a hit, False for a miss.) }
procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; manner, damage, shownDamage: Byte;
                              isHit: Boolean);

{ Moves a creature one cell in a direction. The step costs the terrain cost times 2 half-steps, times 3 on a diagonal;
  with too few left, movement drops to 0 but the step is still taken. The view follows the mover (faster in quick
  fight). The step plays the step sound, resets the creature's flanking counts and lets guarding enemies attack, and a
  mover left out of play or helpless loses the rest of its movement.
  @param(creature The creature moving.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);

{ Gives each enemy adjacent to a creature before a step in direction, but not after it, one free attack on the mover,
  made as from behind, while the mover stays in play. Helpless and turned enemies are skipped, as are enemies an effect
  forbids to attack and those with a ranged weapon that cannot be thrown. An enemy with no initiative left that has
  already been attacked this round needs the mover in the five directions in front of it. The attack uses the enemy's
  highest phase with attacks left, granting one attack when that phase has no attacks left, and the enemy's own target
  is kept.
  @param(creature The creature about to move.)
  @param(direction Direction of the step, 0..7 clockwise from north.) }
procedure AttacksOfOpportunity(creature: Types.PCharRecord; direction: Byte);

{ Tries to flee. It succeeds automatically with no enemy in the target list, and otherwise when the creature's movement
  in whole steps beats the fastest enemy's, or on 1 in 2 when they tie. Success takes the creature out of play as
  running, with 'Got Away'; failure prints 'Escape is blocked'. The creature's actions end either way.
  @param(creature The creature fleeing.)
  @returns(The result of ending its actions.) }
function AttemptFlee(creature: Types.PCharRecord): Boolean;

{ Sets a creature's current attacks for the round. It starts from the weapon's rate of fire (at least 2) when it has a
  ranged weapon with ammunition, else from its base attacks, both in half-attacks; applies its condition-18 effects and
  AttacksFromRate, and caps a ranged weapon by its ammunition. Once an attack has been made this round, the result only
  replaces the current attacks when it is lower.
  @param(creature The creature whose attacks are recalculated.) }
procedure RecalcAttacksLeft(creature: Types.PCharRecord);

{ Converts half-attacks to attacks: adds 1 on odd rounds, then halves.
  @param(rate The rate in half-attacks.)
  @returns(The whole attacks for this round.) }
function AttacksFromRate(rate: Byte): Byte;

{ Sweeps level-0 enemies. When the defender is an adjacent level-0 enemy, the attacker's sweep budget exceeds its
  current attacks, and more adjacent level-0 enemies stand around it than it has current attacks, the attacker makes one
  attack on each of up to its sweep budget of them, the defender first.
  @param(att The creature attacking.)
  @param(def The enemy chosen to attack.)
  @returns(True if the attacker swept.) }
function SweepAttack(att, def: Types.PCharRecord): Boolean;

{ Checks whether effects let attacker attack target. True when target is attacker itself, False when target is nil.
  Otherwise target's condition-1 effects run, and an effect vetoes by setting GDVars.suppressTargeting. Note: attacker's
  target is set to target and put back with nothing run in between, so attacker's own effects are never consulted.
  @param(attacker The creature that would attack.)
  @param(target The creature it would attack, or nil.)
  @returns(True when the attack is allowed.) }
function CanTarget(attacker, target: Types.PCharRecord): Boolean;

{ Records an attack on a defender for flanking: the defender's count of attackers goes up, and the angle between its
  facing and the attack's direction (0..4) is added to its spread, mod 8.
  @param(attacker The attacker.)
  @param(defender The defender.) }
procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);

{ Makes an attack, pushing the round limit 15 rounds on. Unless it comes from behind or defender has already been
  attacked twice this round, defender turns to face attacker; otherwise, while defender's icon is visible, an attack not
  from behind turns it around. attacker turns toward defender and takes it as its target, and missiles fly for weapon
  and for a readied weapon of type 28 or 29. If attacks remain, RollAttacks runs with attacker as the current character;
  weapon then loses the primary attacks made from its quantity, and once it is used up it is removed, an expended
  throwable weapon (other than effect 23) dropping into the treasure pile. Note: the readied weapon's type is read
  without checking that there is one.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(fromBehind True for an attack from behind: defender keeps its facing.)
  @param(weapon The missile or thrown item, or nil for melee.)
  @param(done Set True when attacker's actions for the round are over.) }
procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec;
                     var done: Boolean);

{ Raises a defense value for range. With a ranged weapon the band is (range - 1) div 3 steps; a defender more than one
  band away adds 2 and more than two bands away 3 more. A weapon of range 3 or less has a band of 0, so any distance
  adds both. Melee adds nothing.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @param(armorClass The defense value, raised in place.) }
procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte);

{ Finds a Cure Light Wounds target in the creature's own cell or the eight around it. Candidates are the wounded ally
  with the fewest hit points (the creature itself, checked last, also wins whenever below half its maximum) and the last
  downed body, not dead, petrified or gone, found on a corpse cell. The body wins unless no body was found or the ally
  has 7 hit points or fewer.
  @param(cr The caster.)
  @param(tgt Receives the target, or nil.)
  @returns(True if a target was found.) }
function FindCureTarget(cr: Types.PCharRecord; var tgt: Pointer): Boolean;

{ Builds the spell's target list from the low nibble of its area type. 0: the caster. 5: weighted picks until a second
  or later pick brings the total weight past a budget (spell 79: caster level, weighted by icon size; others: 2d4,
  weighted by level). 15: the picked creature, or the area around a picked bare cell. 8..14: everything within (area and
  7) of the picked cell. Others: (area and 3) + 1 separate picks; spells 23, 49 and 94 refuse the caster. A repeated
  pick is refused; for the computer it uses up a pick, or one point of the weight budget. Note: the radius for a bare
  cell under type 15 is (area and $F) shr 4, which is always 0, and when the separate picks find nothing the target cell
  is read through the entry before the first target.
  @param(spell The spell being cast.)
  @param(ai False when the player aims; True for computer-controlled targeting.)
  @param(cast Set True; set False when the pick for types 8..15 fails or the separate picks find nothing.) }
procedure SelectCombatTargets(spell: Byte; ai: Boolean; var cast: Boolean);

{ Picks (from the spell menu, when no spell is given) and checks a spell, rejecting those not allowed in combat ('Camp
  Only Spell'). A casting delay (the casting time div 3) of 0 casts it at once and ends the caster's actions; otherwise
  the caster 'Begins Casting': the spell is recorded as being cast, initiative drops by the delay (to at least 1), and
  the caster moves back in the combat order to its new initiative, a tie going either way on a 1d2, so it resolves on a
  later action. Note: after an immediate cast, the result is that of ending the caster's actions, whatever the cast
  itself reported.
  @param(spell The spell to cast, or 0 to choose one from the menu.)
  @param(ai 0 redraws the combat screen first; passed on to the cast as its computer-controlled flag.)
  @param(cast Set True when a spell was cast or begun, False otherwise.) }
procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);

{ Confirms a weapon attack on an ally; enemies and quick-fighting attackers pass unasked. Yes sets the attacked-ally
  flags, and each NPC in okay status other than $B3 turns hostile and drops its target; the teams are recounted.
  @param(attacker The creature attacking.)
  @param(defender The creature it would attack.)
  @returns(True if the attack may go ahead.) }
function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;

{ Runs target selection with cycling, the free cursor and confirmation. Targets the creature may not attack are skipped.
  N and P cycle, M (Manual) starts the free cursor, T confirms (a weapon attack goes through ConfirmAttackTarget), C
  recenters, and E or Escape exits.
  @param(cr The creature aiming.)
  @param(range The reach in whole steps; 255 means the readied weapon's range minus 1 (1 unarmed).)
  @param(weaponMode 1 for weapon attacks, 0 for spell casting.)
  @param(groundOk Nonzero lets the free cursor pick a bare cell.)
  @param(creatureOk Nonzero lets the free cursor pick a creature.)
  @param(done True when a target was chosen.)
  @param(tgt Receives the choice, a creature pointer followed by its arena cell, passed untyped.) }
procedure CombatAimMenu(cr: Types.PCharRecord; range, weaponMode, groundOk, creatureOk: Byte; var done: Boolean;
                        var tgt);

{ Checks for a backstab: the attacker must be a thief (or have thief levels through ClassCal.EarlierClassActive), with
  no weapon or one of item types 3, 4 and 17..19; the defender must be small, have been attacked more than once this
  round, stand next to the attacker, and face away from it.
  @param(attacker The creature attacking.)
  @param(defender The creature attacked.)
  @returns(True for a backstab.) }
function IsBackstab(attacker, defender: Types.PCharRecord): Boolean;

{ Flies a missile from attacker to defender. It plays the launch sound, then builds the icon for weapon's item type with
  a sound for its kind: item types 66, 5, 7, 12 and 30 get an icon drawn for the direction of flight, types 2, 3 and 6
  spin in four frames at a slower pace, and the others take a fixed two-frame icon.
  @param(attacker The creature shooting.)
  @param(defender The creature shot at.)
  @param(weapon The missile or thrown item.) }
procedure AnimateMissile(attacker, defender: Types.PCharRecord; weapon: Types.PItemRec);

{ Sets the hostiles' hit-point percentage: the enabled hostiles' current hit points as a percentage of the hostiles'
  combined maximum hit points, disabled ones included, rounded down to a multiple of five; it is left unchanged when
  there are no hostiles. Note: the totals are Words multiplied by 20, so above 3276 hit points the percentage wraps. }
procedure UpdateHostileHpPercent;

{ Finds the fastest enabled enemy's movement in whole steps, with no range or line-of-sight check.
  @param(creature The creature whose enemies are checked.)
  @returns(The highest enemy movement, in whole steps.) }
function HighestEnemyMovement(creature: Types.PCharRecord): Byte;

{ Makes sure the creature's combat record holds a target. An existing lock is kept (without a range check) unless
  `forceNew` is set or it is now an ally, out of play or vetoed by CanTarget. Otherwise it makes up to 20 random picks
  among the enemies within range, dropping vetoed ones; a creature carrying effect 91 first tries the head of the target
  list when that is the marked creature. If that fails a second pass repeats it, ignoring terrain unless `forceNew` is
  set; there a nonzero `relaxed` accepts a pick without CanTarget.
  @param(cr The creature looking for a target.)
  @param(range The search range, in whole steps.)
  @param(relaxed Nonzero lets the second pass skip CanTarget.)
  @param(forceNew Nonzero drops any existing target and keeps terrain in the second pass.)
  @returns(True if a target is held.) }
function AcquireTarget(cr: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;

{ Debug victory: active when the second command-line parameter matches the debug password. Prints 'The Gods intervene!',
  kills each hostile, ends each creature's actions and rebuilds the view.
  @returns(True when the cheat ran.) }
function VictoryCheat: Boolean;

implementation

procedure BeginRound(creature: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { passed TWICE to ProbeDirection }
  cellIndex: Byte;
  inStinkingCloud: Byte;
  inCloudkill: Byte;
begin
  with creature^.combatAddr^ do begin
    spellsLost := 0;
    CbtMap.ProbeDirection(creature, C_Dir.CENTER, cellIndex, cellIndex, inStinkingCloud, inCloudkill);
    spellsAllowed := Ord(inStinkingCloud = 0);
    itemUseAllowedV1 := 1;
    madeAttack := 0;
    attackPhase := 2;
    CbtActs.RecalcAttacksLeft(creature);
    GDVars.movementAttacks := creature^.movementAttacks;
    FxEngine.TriggerEffectsWithCondition(18, creature);
    creature^.curAtt[2] := CbtActs.AttacksFromRate(GDVars.movementAttacks);
    attackLevel := creature^.attackLevel;
    if creature^.enabled <> 0 then begin
      initiative := FxEngine.RollDice(1, 6) + CharHlp.DexMissileAdjust(creature);
      if initiative < 1 then
        initiative := 1;
      if Byte((creature^.hostile + 1) and Integer(GDVars.zone1^.surprise)) <> 0 then
        Dec(initiative, 6);
      if (initiative < 0) or (initiative > 20) then
        initiative := 0;
    end else
      initiative := 0;
  end;
  creature^.combatAddr^.movement := CharHlp.RecalcMovement(creature);
end;

procedure CalcWeaponDamage(attacker, defender: Types.PCharRecord; phase: Byte);
begin
  GDVars.pendingDamage := attacker^.curModA[phase]
                + FxEngine.RollDamageDice(attacker^.curRollsA[phase], attacker^.curDiceA[phase]);
  { Note: pendingDamage is unsigned, so this comparison can never fire. }
  if GDVars.pendingDamage < 0 then
    GDVars.pendingDamage := 0;
  FxEngine.TriggerEffectsWithCondition(4, attacker);
  FxEngine.TriggerEffectsWithCondition(5, defender);
  if CbtActs.IsBackstab(attacker, defender) then
    GDVars.pendingDamage := GDVars.pendingDamage *
      ((attacker^.thiefLevel + attacker^.thiefOldLevel * ShortInt(ClassCal.EarlierClassActive(attacker)) - 1) div 4 +
       2);
  GDVars.elemMask := 0;
end;

procedure ProcessAttackResult(attacker, defender: Types.PCharRecord; manner, damage, shownDamage: Byte; isHit: Boolean);
var
  row: Byte;
  message: string[80];
  { Unused in this version; see the other implementations of this routine. }
  isDone: Boolean;
begin
  case manner of
    2: message := '-Backstabs-';
    3: message := 'slays helpless';
  else
    message := 'Attacks';
  end;
  CharHlp.PrintCreatureMessage(attacker, message, 10, False);
  row := 12;
  CharHlp.DisplayCreatureName(defender, 23, row, False);
  Inc(row);
  if manner = 1 then
    message := '(from behind) '
  else
    message := '';
  if isHit then begin
    if manner = 3 then
      message := 'with one cruel blow'
    else begin
      message := message + 'Hitting for ' + CharHlp.Uint8Str(shownDamage);
      if shownDamage = 1 then
        message := message + ' point '
      else
        message := message + ' points ';
      message := message + 'of damage';
    end;
    CharHlp.InflictDamage(defender, damage);
  end else
    message := message + 'and Misses';
  if defender^.status <> C_Status.GONE then
    TextRend.DisplayMessageWindow(23, row, 38, row + 3, LightGreen, 0, True, message);
  row := GDVars.curRow + 1;
  if damage > 0 then begin
    defender^.combatAddr^.spellsAllowed := 0;
    if defender^.combatAddr^.spellsLost > 0 then begin
      TextRend.PauseOnly;
      CharHlp.PrintCreatureMessage(defender, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(defender, defender^.combatAddr^.spellsLost);
      isDone := CharHlp.EndActions(defender);
    end else
      TextRend.PauseOnly;
  end else
    TextRend.PauseOnly;
  if defender^.enabled = 0 then begin
    CharHlp.PrintCreatureMessage(defender, 'goes down', row, False);
    Inc(row, 2);
    if defender^.status = C_Status.DYING then
      TextRend.DisplayString(23, row, LightGreen, 0, 'and is Dying');
    if defender^.status in [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE] then
      CharHlp.PrintCreatureMessage(defender, 'is killed', row, False);
    Inc(row, 2);
    FxEngine.RemoveEffectsHp0(defender);
    if defender^.enabled = 0 then
      CbtMap.CreatureDowned(defender)
    else
      TextRend.PauseOnly;
  end;
  CharHlp.ClearMessageWindow;
end;

{ Lets guarding enemies strike a creature that moved next to them: each adjacent enemy that is guarding and not helpless
  spends its guard on one free attack, while the mover stays up.
  @param(creature The creature that moved.) }
procedure GuardersAttack(creature: Types.PCharRecord);
var
  count: Byte;
  index: Byte;
  guarder: Types.PCharRecord;
  { MakeAttack's var-param sink }
  done: Boolean;
begin
  count := CharHlp.CountTargets(creature, 1);
  for index := 1 to count do
    if creature^.enabled <> 0 then begin
      guarder := GDVars.creatures[GDVars.targetIdx[index]];
      if guarder^.combatAddr^.guardFlag <> 0 then
        if not CharHlp.IsHelpless(guarder) then begin
          CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 2, C_Dir.CENTER);
          guarder^.combatAddr^.guardFlag := 0;
          CbtActs.NoteAttackDirection(guarder, creature);
          CbtActs.MakeAttack(guarder, creature, False, nil, done);
        end;
    end;
end;

procedure CombatMoveCreature(creature: Types.PCharRecord; direction: Byte);
var
  { reused as the scroll mode after the charge }
  moveCost: Byte;
  slot: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  destTerrain: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  nx := x + GDConsts.dirDx[direction];
  ny := y + GDConsts.dirDy[direction];
  if Odd(direction) then
    moveCost := GDConsts.terrainInfo[GDVars.arenaPtr^.cells[ny, nx]].cost * 3
  else
    moveCost := GDConsts.terrainInfo[GDVars.arenaPtr^.cells[ny, nx]].cost * 2;
  if moveCost > creature^.combatAddr^.movement then
    creature^.combatAddr^.movement := 0
  else
    Dec(creature^.combatAddr^.movement, moveCost);
  moveCost := 1;
  if creature^.quickfight <> 0 then begin
    moveCost := 3;
    if not CbtMap.ViewCoordsValid(nx - GDVars.arenaPtr^.ox, ny - GDVars.arenaPtr^.oy) then
      if GDVars.actorVisible then
        CbtMap.ScrollView(x, y, 2, C_Dir.CENTER);
  end;
  if GDVars.actorVisible then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaLoc[slot].x := nx;
  GDVars.arenaLoc[slot].y := ny;
  CbtMap.BuildArenaArrays;
  if GDVars.actorVisible then
    CbtMap.ScrollView(nx, ny, moveCost, C_Dir.CENTER);
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  SoundDrv.SoundCommand(GDConsts.stepSound);
  CbtActs.GuardersAttack(creature);
  if (creature^.enabled = 0) or CharHlp.IsHelpless(creature) then
    creature^.combatAddr^.movement := 0;
end;

procedure AttacksOfOpportunity(creature: Types.PCharRecord; direction: Byte);
var
  candidates: array[1..12] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  effect: Pointer;
  stillAdjacent: Boolean;
  attacked: Boolean;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  candidateCount: Byte;
  countAfter: Byte;
  scanPos: Byte;
  index: Byte;
  phasePos: Byte;
  phase: Byte;
  facingScan: Byte;
  attacker: Types.PCharRecord;
  savedTarget: Types.PCharRecord;
  { Unused in this version; see the other implementations of this routine. }
  leavingFoe: Boolean;
begin
  leavingFoe := False;
  GameIo.FillWord(candidates, SizeOf(candidates));
  slot := CbtMap.CombatSlot(creature);
  candidateCount := CharHlp.CountTargets(creature, 1);
  if candidateCount = 0 then
    Exit;
  index := 1;
  for scanPos := 1 to candidateCount do
    if not CharHlp.IsHelpless(GDVars.creatures[GDVars.targetIdx[scanPos]]) then
      if GDVars.creatures[GDVars.targetIdx[scanPos]]^.combatAddr^.forcedFleeV2 = 0 then begin
        candidates[index] := GDVars.targetIdx[scanPos];
        Inc(index);
      end;
  candidateCount := index - 1;
  Inc(GDVars.arenaLoc[slot].x, GDConsts.dirDx[direction]);
  Inc(GDVars.arenaLoc[slot].y, GDConsts.dirDy[direction]);
  countAfter := CharHlp.CountTargets(creature, 1);
  Dec(GDVars.arenaLoc[slot].x, GDConsts.dirDx[direction]);
  Dec(GDVars.arenaLoc[slot].y, GDConsts.dirDy[direction]);
  for index := 1 to candidateCount do begin
    stillAdjacent := False;
    for scanPos := 1 to countAfter do
      if GDVars.targetIdx[scanPos] = candidates[index] then
        stillAdjacent := True;
    if stillAdjacent then
      candidates[index] := 0;
  end;
  if creature^.hostile = 0 then
    for index := 1 to candidateCount do
      if candidates[index] > 0 then
        if creature^.enabled <> 0 then
          leavingFoe := True;
  for index := 1 to candidateCount do
    if candidates[index] > 0 then
      if creature^.enabled <> 0 then begin
        GDVars.panelDirty := 1;
        GDVars.actorVisible := True;
        attacked := False;
        attacker := GDVars.creatures[candidates[index]];
        if CbtActs.CanTarget(attacker, creature) then
          if (not CharHlp.HasRangedWeapon(attacker)) or CharHlp.HasThrowableWeapon(attacker) then
            for facingScan := attacker^.combatAddr^.direction + 6 to
                     attacker^.combatAddr^.direction + 10 do
              if not attacked then
                if (attacker^.combatAddr^.initiative > 0)
                   or (attacker^.combatAddr^.flankCount = 0)
                   or Pathing.IsDirToward(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                          CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature),
                                          facingScan mod 8) then begin
                  phase := 1;
                  if attacker^.attacks = 0 then
                    phase := 2;
                  for phasePos := 1 to 2 do
                    if attacker^.curAtt[phasePos] > 0 then
                      phase := phasePos;
                  if attacker^.curAtt[phase] = 0 then
                    attacker^.curAtt[phase] := 1;
                  attacker^.combatAddr^.attackPhase := phase;
                  savedTarget := attacker^.combatAddr^.other;
                  CbtActs.MakeAttack(attacker, creature, True, nil, GDVars.menuExt);
                  attacked := True;
                  attacker^.combatAddr^.other := savedTarget;
                  if creature^.enabled <> 0 then begin
                    GDVars.panelDirty := 1;
                    CharHlp.CombatPrintCreatureInfo(creature);
                  end;
                end;
      end;
end;

function AttemptFlee(creature: Types.PCharRecord): Boolean;
var
  hasEscaped: Boolean;
  enemyMove: Byte;
  creatureMove: Byte;
begin
  hasEscaped := False;
  if CharHlp.CountTargets(creature, 255) = 0 then
    hasEscaped := True
  else begin
    creatureMove := CharHlp.RecalcMovement(creature) div 2;
    enemyMove := CbtActs.HighestEnemyMovement(creature);
    if enemyMove < creatureMove then
      hasEscaped := True
    else if enemyMove = creatureMove then
      if FxEngine.RollDice(1, 2) = 1 then
        hasEscaped := True;
  end;
  if hasEscaped then
    FxEngine.PutOutOfPlayWithStatus(creature, C_Status.RUNNING, 'Got Away')
  else
    CharHlp.PrintBottomLine('Escape is blocked');
  AttemptFlee := CharHlp.EndActions(creature);
end;

procedure RecalcAttacksLeft(creature: Types.PCharRecord);
var
  attacks: Byte;
  previous: Byte;
  ammoLimit: Byte;
  rate: Byte;
  ranged: Boolean;
  { filled by FindDamagingRangedWeapon's var param }
  weapon: Types.PItemRec;
begin
  ranged := False;
  previous := creature^.curAtt[1];
  creature^.curAtt[1] := creature^.attacks;
  if CharHlp.HasRangedWeapon(creature) and CharHlp.FindDamagingRangedWeapon(creature, weapon) then begin
    ranged := True;
    rate := GDVars.baseItems[creature^.equipped[0]^.itemType].rateOfFire;
    if rate < 2 then rate := 2;
    GDVars.movementAttacks := rate;
  end else
    GDVars.movementAttacks := creature^.curAtt[1];
  FxEngine.TriggerEffectsWithCondition(18, creature);
  attacks := CbtActs.AttacksFromRate(GDVars.movementAttacks);
  if ranged and (weapon <> nil) then begin
    ammoLimit := 1;
    if (weapon <> nil) and (weapon^.quantity > ammoLimit) then
      ammoLimit := weapon^.quantity;
    if (ammoLimit < attacks) and (weapon^.quantity > 0) then
      attacks := ammoLimit;
  end;
  if (creature^.combatAddr^.madeAttack = 0) or (attacks < previous) then
    creature^.curAtt[1] := attacks
  else
    creature^.curAtt[1] := previous;
end;

function AttacksFromRate(rate: Byte): Byte;
var
  adjusted: Byte;
begin
  adjusted := rate;
  if Odd(GDVars.roundCounter) then
    Inc(adjusted);
  AttacksFromRate := adjusted div 2;
end;

function SweepAttack(att, def: Types.PCharRecord): Boolean;
var
  cnt: Byte;
  weak: Byte;
  i: Byte;
  defIdx: Byte;
  p: Types.PCharRecord;
begin
  SweepAttack := False;
  if att^.curAtt[1] >= att^.combatAddr^.attackLevel then
    Exit;
  if def^.highestLevel <> 0 then
    Exit;
  if CharHlp.CalcDistance(att, def) <> 1 then
    Exit;
  cnt := CharHlp.CountTargets(att, 1);
  weak := 0;
  for i := 1 to cnt do begin
    p := GDVars.creatures[GDVars.targetIdx[i]];
    if p = def then
      defIdx := i;
    if p^.highestLevel = 0 then
      Inc(weak);
  end;
  if weak <= att^.curAtt[1] then
    Exit;
  if weak > att^.combatAddr^.attackLevel then
    weak := att^.combatAddr^.attackLevel;
  CharHlp.PrintCreatureMessage(att, 'sweeps', 10, True);
  { def is promoted to slot 1 so it takes the first sweep swing. }
  p := GDVars.creatures[GDVars.targetIdx[1]];
  if p <> def then begin
    GDVars.targetIdx[defIdx] := GDVars.targetIdx[1];
    GDVars.targetIdx[1] := CbtMap.CombatSlot(def);
  end;
  for i := 1 to cnt do
    if weak > 0 then
      if GDVars.creatures[GDVars.targetIdx[i]]^.highestLevel = 0 then begin
        p := GDVars.creatures[GDVars.targetIdx[i]];
        CbtActs.NoteAttackDirection(att, p);
        att^.curAtt[1] := 1;
        CbtActs.MakeAttack(att, p, False, nil, GDVars.menuExt);
        Dec(weak);
      end;
  SweepAttack := True;
end;

function CanTarget(attacker, target: Types.PCharRecord): Boolean;
var
  savedTarget: Types.PCharRecord;
begin
  CanTarget := False;
  if target = nil then
    Exit;
  if attacker = target then begin
    CanTarget := True;
    Exit;
  end;
  GDVars.suppressTargeting := 0;
  FxEngine.TriggerEffectsWithCondition(1, target);
  if GDVars.suppressTargeting = 0 then begin
    savedTarget := attacker^.combatAddr^.other;
    attacker^.combatAddr^.other := target;
    attacker^.combatAddr^.other := savedTarget;
  end;
  CanTarget := GDVars.suppressTargeting = 0;
end;

{ Resolves att's remaining attacks on def. A helpless defender is slain with one blow (its hit points + 5) and the
  attacks are spent. Otherwise att uses its weapon's large-target dice against a large defender, and the defense is the
  rear AC less 4 on a backstab, the rear AC from behind (fromBehind, or def attacked more than once with att at its back
  and a flank spread above 4), else the front AC, plus range penalties. The attacks are rolled from the current attack
  phase down to 1 until def drops, a damaging hit on a defender still in play running att's condition-2 or condition-3
  effects; a miss is reported when no attack hits, and the sweep budget is spent. Note: an attacker that goes down
  during its attacks loses the rest of that phase's attacks but still makes the next phase's, and the readied weapon's
  type is read without checking that there is one.
  @param(att The creature attacking.)
  @param(def The creature attacked.)
  @param(fromBehind True to attack as from behind.)
  @param(done Set True when att has no attacks left or is out of play; its actions then end.)
  @param(other Unused.) }
procedure RollAttacks(att, def: Types.PCharRecord; fromBehind: Boolean; var done: Boolean; other: Types.PItemRec);
var
  weaponRec: Types.TBaseItem;
  attackMade: Boolean;
  defDown: Boolean;
  backstab: Byte;
  ac: Byte;
  k: Byte;
  phase: Byte;
  atkType: Byte;
  bsFlag: ShortInt;
begin
  backstab := Byte(fromBehind);
  done := False;
  GDVars.attacksHit[1] := 0;
  GDVars.attacksHit[2] := 0;
  GDVars.attacksTried[1] := 0;
  GDVars.attacksTried[2] := 0;
  attackMade := False;
  defDown := False;
  GDVars.pendingDamage := 0;
  att^.combatAddr^.madeAttack := 1;
  if CharHlp.IsHelpless(def) then begin
    SoundDrv.SoundCommand(GDConsts.strikeSound);
    while att^.curAtt[att^.combatAddr^.attackPhase] = 0 do
      Dec(att^.combatAddr^.attackPhase);
    Inc(GDVars.attacksTried[att^.combatAddr^.attackPhase]);
    CbtActs.ProcessAttackResult(att, def, 3, def^.hpCurrent + 5, 1, True);
    FxEngine.RemoveInvisibility(att);
    for k := 1 to 2 do
      att^.curAtt[k] := 0;
    attackMade := True;
    done := True;
  end else begin
    if att^.equipped[0] <> nil then
      if (def^.iconDimensions > $80) or ((def^.iconDimensions and 7) > 1) then begin
        weaponRec := GDVars.baseItems[att^.equipped[0]^.itemType];
        att^.curRollsA[1] := weaponRec.dmgLgRolls;
        att^.curDiceA[1] := weaponRec.dmgLgDice;
        att^.curModA[1] := att^.curModA[1] - weaponRec.dmgSmMod
                           + weaponRec.dmgLgMod;
      end;
    CharHlp.RecalcStats(def);
    FxEngine.TriggerEffectsWithCondition(11, def);
    bsFlag := 0;
    if CbtActs.IsBackstab(att, def) then
      ac := def^.acCurArr[1] - 4
    else begin
      if def^.combatAddr^.flankCount > 1 then
        if CharHlp.DirTowardTarget(att, def) = def^.combatAddr^.direction then
          if def^.combatAddr^.flankSpread > 4 then
            backstab := 1;
      if backstab <> 0 then
        bsFlag := 1;
      ac := def^.acCurArr[bsFlag];
    end;
    CbtActs.ApplyRangePenalty(att, def, ac);
    atkType := 0;
    if backstab <> 0 then
      atkType := 1;
    if CbtActs.IsBackstab(att, def) then
      atkType := 2;
    phase := att^.combatAddr^.attackPhase;
    for k := phase downto 1 do
      while (att^.curAtt[k] > 0) and not defDown do begin
        Dec(att^.curAtt[k]);
        att^.combatAddr^.attackPhase := k;
        Inc(GDVars.attacksTried[k]);
        if FxEngine.AttackRoll(att, def, ac) or CharHlp.IsHelpless(def) then begin
          Inc(GDVars.attacksHit[k]);
          SoundDrv.SoundCommand(GDConsts.strikeSound);
          attackMade := True;
          CbtActs.CalcWeaponDamage(att, def, k);
          if def^.enabled <> 0 then
            CbtActs.ProcessAttackResult(att, def, atkType, GDVars.pendingDamage, GDVars.pendingDamage, True);
          if (def^.enabled <> 0) and (GDVars.pendingDamage > 0) then
            FxEngine.TriggerEffectsWithCondition(k + 1, att);
          if def^.enabled = 0 then begin
            defDown := True;
            if att^.equipped[0]^.itemType = 66 then begin
              phase := 0;
              att^.curAtt[k] := 0;
            end;
          end;
          if att^.enabled = 0 then begin
            phase := 0;
            att^.curAtt[k] := 0;
          end;
        end;
      end;
    if not attackMade then begin
      SoundDrv.SoundCommand(GDConsts.swingSound);
      CbtActs.ProcessAttackResult(att, def, atkType, 0, 0, False);
    end;
    done := True;
    for k := 1 to 2 do
      if att^.curAtt[k] > 0 then
        done := False;
    att^.combatAddr^.attackLevel := 0;
  end;
  if att^.enabled = 0 then
    done := True;
  if done then
    done := CharHlp.EndActions(att);
end;

procedure NoteAttackDirection(attacker, defender: Types.PCharRecord);
var
  angle: Byte;
  attackDirection: Byte;
begin
  Inc(defender^.combatAddr^.flankCount);
  attackDirection := CharHlp.DirTowardTarget(defender, attacker);
  angle := (attackDirection - defender^.combatAddr^.direction + 8) mod 8;
  if angle > 4 then
    angle := 8 - angle;
  defender^.combatAddr^.flankSpread := (defender^.combatAddr^.flankSpread + angle) mod 8;
end;

procedure MakeAttack(attacker, defender: Types.PCharRecord; fromBehind: Boolean; weapon: Types.PItemRec;
                     var done: Boolean);
var
  thrownCopy: Types.PItemRec;
  walker: Types.PItemRec;
  savedCharacter: Types.PCharRecord;
  direction: Byte;
  slot: Byte;
begin
  GDVars.actorVisible := True;
  GDVars.panelDirty := 1;
  GDVars.roundLimit := GDVars.roundCounter + 15;
  if (defender^.combatAddr^.flankCount < 2) and (fromBehind = False) then begin
    direction := CharHlp.DirTowardTarget(defender, attacker);
    { stored raw here; the else-if arm below applies (direction + 4) mod 8 }
    defender^.combatAddr^.direction := direction;
  end else if CbtMap.CombatIconVisible(defender, 0) then begin
    direction := defender^.combatAddr^.direction;
    if fromBehind = False then
      defender^.combatAddr^.direction := (direction + 4) mod 8;
  end;
  if CbtMap.CombatIconVisible(defender, 0) then begin
    CbtMap.SetCreatureFacing(defender, direction, 0, 1);
    slot := CbtMap.CombatSlot(defender);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    MapTiles.DrawIconAnimSprite(GDVars.gridX[slot], GDVars.gridY[slot], direction, 0, defender^.orderNumber);
    Blit.FlushView;
  end;
  direction := CharHlp.DirTowardTarget(attacker, defender);
  CharHlp.CombatPrintCreatureInfo(attacker);
  CbtMap.SetCreatureFacing(attacker, direction, 1, 0);
  attacker^.combatAddr^.other := defender;
  Delay(100);
  if weapon <> nil then
    CbtActs.AnimateMissile(attacker, defender, weapon);
  if (attacker^.equipped[0]^.itemType = 28) or (attacker^.equipped[0]^.itemType = 29) then
    CbtActs.AnimateMissile(attacker, defender, attacker^.equipped[0]);
  done := True;
  if (attacker^.curAtt[1] > 0) or (attacker^.curAtt[2] > 0) then begin
    savedCharacter := GDVars.curChar;
    GDVars.curChar := attacker;
    CbtActs.RollAttacks(attacker, defender, fromBehind, done, weapon);
    if weapon <> nil then begin
      if weapon^.quantity > 0 then
        Dec(weapon^.quantity, GDVars.attacksTried[1]);
      if weapon^.quantity = 0 then
        if CharHlp.HasThrowableWeapon(attacker) and (weapon^.special <> 23) then begin
          New(thrownCopy);
          Move(weapon^, thrownCopy^, SizeOf(Types.TItemRec));
          walker := GDVars.treasureItems;
          if walker = nil then begin
            GDVars.treasureItems := thrownCopy;
            thrownCopy^.next := nil;
          end else begin
            while (walker^.next <> nil) and (walker <> GDVars.lastItem) do
              walker := walker^.next;
            thrownCopy^.next := walker^.next;
            walker^.next := thrownCopy;
          end;
          thrownCopy^.equipped := 0;
          CharHlp.RemoveItem(attacker, weapon);
          GDVars.lastItem := thrownCopy;
        end else
          CharHlp.RemoveItem(attacker, weapon);
    end;
    CharHlp.RecalcStats(attacker);
    GDVars.curChar := savedCharacter;
  end;
  if done then
    done := CharHlp.EndActions(attacker);
  if CbtMap.CombatIconVisible(attacker, 0) then begin
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 1, 1);
    CbtMap.SetCreatureFacing(attacker, attacker^.combatAddr^.direction, 0, 0);
  end;
end;

procedure ApplyRangePenalty(attacker, defender: Types.PCharRecord; var armorClass: Byte);
var
  band: ShortInt;
  distance: ShortInt;
begin
  distance := CharHlp.CalcDistance(attacker, defender);
  if CharHlp.HasRangedWeapon(attacker) then
    band := (GDVars.baseItems[attacker^.equipped[0]^.itemType].range - 1) div 3
  else
    band := distance;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 2;
  end;
  if distance - band > 0 then begin
    distance := distance - band;
    armorClass := armorClass + 3;
  end;
end;

function FindCureTarget(cr: Types.PCharRecord; var tgt: Pointer): Boolean;
var
  best: Pointer;
  nx: ShortInt;
  ny: ShortInt;
  downIdx: Byte;
  bestHp: Byte;
  d: Byte;
  j: Byte;
  crIdx: Byte;
  terrIdx: Byte;
begin
  best := nil;
  downIdx := 0;
  bestHp := 255;
  for d := 0 to 8 do begin
    nx := CbtMap.CombatCellX(cr) + GDConsts.dirDx[d];
    ny := CbtMap.CombatCellY(cr) + GDConsts.dirDy[d];
    CbtMap.GetArenaContents(nx, ny, crIdx, terrIdx);
    if crIdx > 0 then begin
      tgt := GDVars.creatures[crIdx];
      if Types.PCharRecord(tgt)^.hostile = cr^.hostile then
        if Types.PCharRecord(tgt)^.hpCurrent < Types.PCharRecord(tgt)^.hpMax then
          if (Types.PCharRecord(tgt)^.hpCurrent < bestHp)
             or ((tgt = cr) and (Types.PCharRecord(tgt)^.hpCurrent < Types.PCharRecord(tgt)^.hpMax div 2)) then begin
            best := tgt;
            bestHp := Types.PCharRecord(tgt)^.hpCurrent;
          end;
    end else if (terrIdx = 30) or (terrIdx = 28) then
      for j := 1 to GDVars.downedCount do
        if GDVars.downed[j].cr <> nil then
          if not (GDVars.downed[j].cr^.status in [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE]) then
            if GDVars.downed[j].x = nx then
              if GDVars.downed[j].y = ny then
                downIdx := j;
  end;
  if (bestHp < 8) or (downIdx = 0) then
    tgt := best
  else
    tgt := GDVars.downed[downIdx].cr;
  if tgt <> nil then
    FindCureTarget := True
  else
    FindCureTarget := False;
end;

{ Picks one spell target. For the player the aim goes through CombatAimMenu (one spell may aim at cells but not at
  creatures), which also locks the target. Otherwise a spell that does not target enemies goes to the caster, or for
  Cure Light Wounds to FindCureTarget's pick; an offensive spell takes one AcquireTarget pick, rejected when the target
  is helpless and the spell's effect is a helpless status. On success the target's cell becomes the spell's target cell;
  on failure the target is cleared.
  @param(spellId The spell being aimed.)
  @param(aiControlled 0 for the player's aim menu; nonzero for computer-controlled targeting.)
  @param(groundOk Passed to CombatAimMenu: nonzero lets the player pick a bare cell.)
  @param(target Receives the target: a creature pointer followed by its arena cell.)
  @returns(True if a target was found.) }
function SelectSpellTarget(spellId: Byte; aiControlled: Boolean; groundOk: Byte; var target: TAimTarget): Boolean;
var
  found: Boolean;
  acceptable: Boolean;
  candidate: Types.PCharRecord;
  i: Byte;
  tries: Byte;
  creatureOk: Byte;
begin
  found := False;
  if not aiControlled then begin
    creatureOk := Ord(spellId <> 83);
    CbtActs.CombatAimMenu(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, groundOk, creatureOk, found, target);
    GDVars.curChar^.combatAddr^.other := target.ptr;
  end else if GDConsts.spellDefs[spellId].offensive = 0 then begin
    target.ptr := GDVars.curChar;
    if (spellId <> 3) or CbtActs.FindCureTarget(GDVars.curChar, Pointer(target.ptr)) then begin
      target.x := CbtMap.CombatCellX(target.ptr);
      target.y := CbtMap.CombatCellY(target.ptr);
      found := True;
    end;
  end else begin
    tries := 1;
    while (tries > 0) and not found do begin
      acceptable := True;
      if CbtActs.AcquireTarget(GDVars.curChar, Magic.CalcSpellRange(spellId), 0, 1) then begin
        candidate := GDVars.curChar^.combatAddr^.other;
        if CharHlp.IsHelpless(candidate) then
          for i := 1 to 4 do
            if GDConsts.spellDefs[spellId].effectId = GDConsts.helplessFx[i] then
              acceptable := False;
        if acceptable then begin
          target.ptr := GDVars.curChar^.combatAddr^.other;
          target.x := CbtMap.CombatCellX(target.ptr);
          target.y := CbtMap.CombatCellY(target.ptr);
          found := True;
        end;
      end;
      Dec(tries);
    end;
  end;
  if found then begin
    SelectSpellTarget := True;
    GDVars.targetCellX := target.x;
    GDVars.targetCellY := target.y;
  end else begin
    SelectSpellTarget := False;
    GameIo.FillWord(target, SizeOf(target));
  end;
end;

procedure SelectCombatTargets(spell: Byte; ai: Boolean; var cast: Boolean);
var
  n: Byte;
  cnt: Byte;
  i: Byte;
  budget: Byte;
  weight: Byte;
  tgt: TAimTarget;
  dup: Boolean;
  finished: Boolean;
begin
  cast := True;
  GDVars.castTargetCount := 0;
  GDVars.areaTargets := 0;
  GDVars.targetCellX := CbtMap.CombatCellX(GDVars.curChar);
  GDVars.targetCellY := CbtMap.CombatCellY(GDVars.curChar);
  case GDConsts.spellDefs[spell].area and $F of
    0:
      begin
        GDVars.castTargets[1] := GDVars.curChar;
        GDVars.castTargetCount := 1;
      end;
    5:
      begin
        weight := 0;
        cnt := 0;
        if spell = 79 then budget := CharHlp.GetCasterLevel(79)
                       else budget := FxEngine.RollDice(2, 4);
        finished := False;
        repeat
          if CbtActs.SelectSpellTarget(spell, ai, 0, tgt) then begin
            dup := False;
            for i := 1 to cnt do
              if GDVars.castTargets[i] = tgt.ptr then
                dup := True;
            if not dup then begin
              Inc(cnt);
              GDVars.castTargets[cnt] := tgt.ptr;
              GDVars.targetCellX := CbtMap.CombatCellX(tgt.ptr);
              GDVars.targetCellY := CbtMap.CombatCellY(tgt.ptr);
              Inc(GDVars.castTargetCount);
              if spell <> 79 then
                case GDVars.castTargets[cnt]^.highestLevel of
                  0, 1: Inc(weight);
                  2: Inc(weight, 2);
                  3: Inc(weight, 4);
                else Inc(weight, 8);
                end else
                case GDVars.castTargets[cnt]^.iconDimensions of
                  1: Inc(weight);
                  2, 3: Inc(weight, 2);
                  4: Inc(weight, 4);
                end;
              if (cnt > 1) and (weight > budget) then
                finished := True;
            end else begin
              if ai then Dec(budget)
                    else CharHlp.PrintBottomLine('Already been targeted');
            end;
            CbtMap.RedrawArenaCell(CbtMap.CombatCellX(tgt.ptr), CbtMap.CombatCellY(tgt.ptr));
          end else
            finished := True;
        until finished or (budget = 0);
      end;
    8..14:
      begin
        if CbtActs.SelectSpellTarget(spell, ai, 1, tgt) then begin
          Pathing.BuildTargetList(GDVars.targetCellX, GDVars.targetCellY, GDConsts.spellDefs[spell].area and 7, 255, 1,
                                  GDVars.arenaPtr);
          for cnt := 1 to GDVars.targetCount do
            GDVars.castTargets[cnt] := GDVars.creatures[GDVars.targets[cnt].who];
          GDVars.castTargetCount := GDVars.targetCount;
          GDVars.areaTargets := 1;
        end else
          cast := False;
      end;
    15:
      begin
        if CbtActs.SelectSpellTarget(spell, ai, 0, tgt) then begin
          if GDVars.curChar^.combatAddr^.other <> nil then begin
            GDVars.castTargets[1] := GDVars.curChar^.combatAddr^.other;
            GDVars.castTargetCount := 1;
          end else begin
            { Note: the mask is applied before the shift, so this radius is always 0. }
            Pathing.BuildTargetList(GDVars.targetCellX, GDVars.targetCellY,
                                    (GDConsts.spellDefs[spell].area and $F) shr 4, 255, 1,
                                    GDVars.arenaPtr);
            for cnt := 1 to GDVars.targetCount do
              GDVars.castTargets[cnt] := GDVars.creatures[GDVars.targets[cnt].who];
            GDVars.castTargetCount := GDVars.targetCount;
            GDVars.areaTargets := 1;
          end;
        end else
          cast := False;
      end;
  else begin
      n := (GDConsts.spellDefs[spell].area and 3) + 1;
      cnt := 0;
      while n > 0 do begin
        if CbtActs.SelectSpellTarget(spell, ai, 0, tgt) then begin
          dup := False;
          for i := 1 to cnt do
            if GDVars.castTargets[i] = tgt.ptr then
              dup := True;
          if (spell = 23) or (spell = 49) or (spell = 94) then
            if tgt.ptr = GDVars.curChar then
              dup := True;
          if not dup then begin
            Inc(cnt);
            GDVars.castTargets[cnt] := tgt.ptr;
            Dec(n);
            GDVars.targetCellX := CbtMap.CombatCellX(tgt.ptr);
            GDVars.targetCellY := CbtMap.CombatCellY(tgt.ptr);
          end else if not ai then begin
            if tgt.ptr = GDVars.curChar then CharHlp.PrintBottomLine('Cannot target yourself')
                                else CharHlp.PrintBottomLine('Already been targeted');
          end else
            { the AI arm still burns a pick, so a duplicate cannot spin }
            Dec(n);
          CbtMap.RedrawArenaCell(CbtMap.CombatCellX(tgt.ptr), CbtMap.CombatCellY(tgt.ptr));
        end else
          n := 0;
      end;
      { Note: castTargets[cnt] is read with cnt possibly 0. }
      GDVars.castTargetCount := cnt;
      if cnt = 0 then
        cast := False;
      GDVars.targetCellX := CbtMap.CombatCellX(GDVars.castTargets[cnt]);
      GDVars.targetCellY := CbtMap.CombatCellY(GDVars.castTargets[cnt]);
    end;
  end;
end;

procedure CastSpellCombat(spell, ai: Byte; var cast: Boolean);
var
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
  castTime: Byte;
  k: Byte;
  idx: Integer;
  notEmpty: Boolean;
  caster: Types.PCharRecord;
  other: Types.PCharRecord;
begin
  caster := GDVars.curChar;
  notEmpty := True;
  idx := -1;
  cast := False;
  spellId := spell;
  if spellId = 0 then
    spellId := ViewChar.SpellMenu(0, 1, idx, notEmpty);
  if spellId > 0 then
    if GDConsts.spellDefs[spellId].castContext = C_Spell.CAMP_ONLY then begin
      CharHlp.PrintBottomLine('Camp Only Spell');
      spellId := 0;
    end;
  if ai = 0 then begin
    CharHlp.DisplayCombatInterface;
    GDVars.actorVisible := True;
    GDVars.panelDirty := 1;
    CbtMap.DisplayMapViewCentered(caster, 3, True);
    CharHlp.CombatPrintCreatureInfo(caster);
  end;
  if spellId > 0 then begin
    castTime := GDConsts.spellDefs[spellId].castTime div 3;
    if castTime = 0 then begin
      Magic.CastSpell(spellId, Boolean(ai), True, cast);
      cast := CharHlp.EndActions(caster);
    end else begin
      cast := True;
      CharHlp.PrintCreatureMessage(caster, 'Begins Casting', 10, True);
      caster^.combatAddr^.spellsLost := spellId;
      if caster^.combatAddr^.initiative > castTime then
        Dec(caster^.combatAddr^.initiative, castTime)
      else
        caster^.combatAddr^.initiative := 1;
      k := GDVars.combatantIdx;
      other := GDVars.initOrder[k + 1];
      while (other <> nil) and
          ((other^.combatAddr^.initiative > caster^.combatAddr^.initiative) or
           ((other^.combatAddr^.initiative = caster^.combatAddr^.initiative) and
            (FxEngine.RollDice(1, 2) = 1))) do begin
        GDVars.initOrder[k] := other;
        Inc(k);
        other := GDVars.initOrder[k + 1];
      end;
      GDVars.initOrder[k] := caster;
      Dec(GDVars.combatantIdx);
      cast := True;
    end;
  end;
end;

function IsBackstab(attacker, defender: Types.PCharRecord): Boolean;
var
  weapon: Types.PItemRec;
  { Unused in this version; see the other implementations of this routine. }
  armor: Types.PItemRec;
  weaponType: Byte;
  canBackstab: Boolean;
begin
  canBackstab := False;
  weapon := attacker^.equipped[0];
  if weapon <> nil then
    weaponType := weapon^.itemType;
  armor := attacker^.equipped[2];
  if (attacker^.thiefLevel > 0) or
      ((attacker^.thiefOldLevel > 0) and (ShortInt(ClassCal.EarlierClassActive(attacker)) <> 0)) then
    if (weapon = nil) or (weaponType = 3) or (weaponType = 4) or ((weaponType > 16) and (weaponType < 20)) then
      canBackstab := True;
  if canBackstab and (defender^.combatAddr^.flankCount > 1)
        and (CharHlp.CalcDistance(attacker, defender) < 2)
        and ((defender^.iconDimensions and $7F) <= 1)
        and (CharHlp.DirTowardTarget(attacker, defender) = defender^.combatAddr^.direction) then
    IsBackstab := True
  else
    IsBackstab := False;
end;

procedure AnimateMissile(attacker, defender: Types.PCharRecord; weapon: Types.PItemRec);
var
  missileCellBase: Byte;
  frames: Byte;
  direction: Byte;
  pace: Byte;
  { Unused in this version; see the other implementations of this routine. }
  imageSize: Word;
begin
  SoundDrv.SoundCommand(GDConsts.arrowSounds[0]);
  direction := CharHlp.DirTowardTarget(attacker, defender);
  frames := 1;
  pace := 10;
  missileCellBase := 13;
  imageSize := GDVars.iconBuf^.imgSize;
  case weapon^.itemType of
    66, 5, 7, 12, 30:
      begin
        if Odd(direction) then begin
          if (direction = C_Dir.SOUTHEAST) or (direction = C_Dir.SOUTHWEST) then
            CharHlp.CopyIconFacing(missileCellBase + 1, 1, 0, direction = C_Dir.SOUTHWEST)
          else
            CharHlp.CopyIconFacing(missileCellBase + 1, 0, 0, direction = C_Dir.NORTHWEST);
        end else
          CharHlp.CopyIconFacing(missileCellBase + direction mod 4, direction div 4, 0, False);
        SoundDrv.SoundCommand(GDConsts.arrowSounds[0]);
      end;
    2, 3, 6:
      begin
        CharHlp.BuildIconFacings(missileCellBase + 3);
        frames := 4;
        pace := 50;
        SoundDrv.SoundCommand(GDConsts.swingSound);
      end;
    28, 29:
      begin
        Inc(missileCellBase);
        CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, False);
        CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, False);
        frames := 2;
        pace := 10;
        SoundDrv.SoundCommand(GDConsts.slingSound);
      end;
  else begin
      CharHlp.CopyIconFacing(missileCellBase + 7, 0, 0, False);
      CharHlp.CopyIconFacing(missileCellBase + 7, 1, 1, False);
      frames := 2;
      pace := 20;
      SoundDrv.SoundCommand(GDConsts.swingSound);
    end;
  end;
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(attacker), CbtMap.CombatCellY(attacker),
                                  CbtMap.CombatCellX(defender), CbtMap.CombatCellY(defender), frames, pace);
end;

procedure UpdateHostileHpPercent;
var
  maximumTotal: Word;
  hitPointTotal: Word;
  combatant: Types.PCharRecord;
begin
  maximumTotal := 0;
  hitPointTotal := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if combatant^.hostile = 1 then begin
      if combatant^.enabled <> 0 then
        hitPointTotal := combatant^.hpCurrent + hitPointTotal;
      maximumTotal := combatant^.hpMax + maximumTotal;
    end;
    combatant := combatant^.nextCharAddr;
  end;
  if maximumTotal > 0 then
    GDVars.hostileHpPercent := hitPointTotal * 20 div maximumTotal * 5;
end;

function HighestEnemyMovement(creature: Types.PCharRecord): Byte;
var
  highest: Byte;
  movement: Byte;
  combatant: Types.PCharRecord;
begin
  highest := 0;
  combatant := GDVars.creatureList;
  while combatant <> nil do begin
    if CharHlp.EnemyTeam(creature) = combatant^.hostile then
      if combatant^.enabled <> 0 then begin
        movement := CharHlp.RecalcMovement(combatant) div 2;
        if movement > highest then
          highest := movement;
      end;
    combatant := combatant^.nextCharAddr;
  end;
  HighestEnemyMovement := highest;
end;

function CheckAttackAlly(attacker, defender: Types.PCharRecord): Boolean;
var
  combatant: Types.PCharRecord;
begin
  if (CharHlp.EnemyTeam(defender) = attacker^.hostile) or (attacker^.quickfight <> 0) then
    CheckAttackAlly := True
  else if MenuCore.YesNoMenu('Attack Ally: ', LightMagenta, LightGreen, White, 2) <> 'Y' then
    CheckAttackAlly := False
  else begin
    CheckAttackAlly := True;
    GDVars.allyAttacked := 1;
    GDVars.zone1^.allyAttacked := 1;
    combatant := GDVars.creatureList;
    while combatant <> nil do begin
      if combatant^.status = C_Status.OKAY then
        if combatant^.npc <> $B3 then
          if combatant^.npc > $7F then begin
            combatant^.hostile := 1;
            combatant^.combatAddr^.other := nil;
          end;
      combatant := combatant^.nextCharAddr;
    end;
    CharHlp.CountTeams;
  end;
end;

{ Shows one aim-menu round on the target: centers the view on it, shows the range in weapon mode, and offers Target when
  the target cell is in range and allowed (spell mode: always; weapon mode: when the target is another creature and the
  attacker either has no ranged weapon, or has ammunition for it and no adjacent enemy or a throwable weapon), then
  Next, Prev, Manual, Center and Exit.
  @param(cur The creature aiming.)
  @param(tgt The creature under the aim.)
  @param(effRange The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell.)
  @param(groundOk Unused.)
  @param(creatureOk Unused.)
  @param(valid Nonzero to allow Target at all.)
  @param(cellX Arena column of the target cell.)
  @param(cellY Arena row of the target cell.)
  @returns(The key chosen.) }
function AimTargetMenu(cur, tgt: Types.PCharRecord; effRange, weaponMode, groundOk, creatureOk, valid, cellX,
                       cellY: Byte): Char;
var
  menu: string[40];
  ext: Boolean;
  { FindDamagingRangedWeapon's var w }
  weapon: Types.PItemRec;
  dist: Word;
  { Unused in this version; see the other implementations of this routine. }
  losFound: Boolean;
  { arenaPtr^.distMode across the WalkLine call }
  savedSize: Byte;
begin
  menu := '';
  dist := 255;
  savedSize := GDVars.arenaPtr^.distMode;
  GDVars.arenaPtr^.distMode := 1;
  losFound := Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), ShortInt(cellX), ShortInt(cellY),
                               dist, GDVars.arenaPtr);
  GDVars.arenaPtr^.distMode := savedSize;
  dist := dist div 2;
  if weaponMode <> 0 then
    TextRend.DisplayString(0, 23, LightGreen, 0, 'Range = ' + CharHlp.Uint16Str(dist) + '  ');
  if effRange >= dist then
    if valid <> 0 then begin
      if weaponMode = 0 then
        menu := 'Target '
      else if cur <> tgt then begin
        if not CharHlp.HasRangedWeapon(cur) then
          menu := 'Target '
        else if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
          if (CharHlp.CountTargets(cur, 1) = 0) or CharHlp.HasThrowableWeapon(cur) then
            menu := 'Target ';
      end;
    end;
  menu := 'Next Prev Manual ' + menu + 'Center Exit';
  if tgt <> nil then begin
    CbtMap.DisplayMapViewCentered(tgt, 3, True);
    GDVars.panelDirty := 1;
    CharHlp.CombatPrintCreatureInfo(tgt);
  end;
  AimTargetMenu := MenuCore.MenuHorizontal('Aim:', menu, LightMagenta, LightGreen, White, 1, 0, ext);
end;

{ Confirms an aim selection: weapon mode 1 makes a weapon attack, anything else selects a spell target. A weapon attack
  on an ally needs CheckAttackAlly's consent, otherwise the selection is cleared and the done flag is False. The attack
  tries a sweep first; a throwable ranged weapon used at distance 1 strikes as melee.
  @param(cur The creature aiming.)
  @param(tgt The creature chosen.)
  @param(mode 1 for a weapon attack.)
  @param(done False when the attack was declined; otherwise True or the attack's result.)
  @param(sel Receives the target and its cell; cleared when declined.) }
procedure ConfirmAttackTarget(cur, tgt: Types.PCharRecord; mode: Byte; var done: Boolean; var sel: TAimTarget);
var
  { Unused in this version; see the other implementations of this routine. }
  targetDir: Byte;
  weapon: Types.PItemRec;
begin
  weapon := nil;
  done := True;
  if mode = 1 then
    if not CbtActs.CheckAttackAlly(cur, tgt) then
      done := False;
  if done then begin
    sel.ptr := tgt;
    sel.x := CbtMap.CombatCellX(tgt);
    sel.y := CbtMap.CombatCellY(tgt);
    GDVars.arenaPtr^.cursorOn := False;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
    if mode = 1 then begin
      if CbtActs.SweepAttack(cur, tgt) then
        done := CharHlp.EndActions(cur)
      else begin
        CbtActs.NoteAttackDirection(cur, tgt);
        if CharHlp.HasRangedWeapon(cur) then
          if CharHlp.FindDamagingRangedWeapon(cur, weapon) then
            if CharHlp.HasThrowableWeapon(cur) then
              if CharHlp.CalcDistance(cur, tgt) = 1 then
                weapon := nil;
        CbtActs.MakeAttack(cur, tgt, False, weapon, done);
      end;
    end;
  end else
    GameIo.FillWord(sel, SizeOf(sel));
end;

{ Runs the free cursor: the arrow keys move a cell cursor (kept inside the arena) from a starting cell, Target or Enter
  takes the cell under it and Space recenters; Exit and Escape leave with nothing chosen. A cell is valid when a line
  reaches it within range and its terrain is passable; a bare cell also needs the ground flag, and a creature needs the
  creature flag and CanTarget's consent. In weapon mode a creature is also invalid when it is the attacker itself or a
  downed body, or when the attacker's ranged weapon has no ammunition or, unless throwable, an enemy stands adjacent.
  @param(cur The creature aiming.)
  @param(underCursor Overwritten: holds the creature under the cursor while it moves.)
  @param(range The reach, in whole steps.)
  @param(weaponMode Nonzero for a weapon attack, 0 for a spell target.)
  @param(groundOk Nonzero lets a bare cell be chosen.)
  @param(creatureOk Nonzero lets a creature be chosen.)
  @param(valid Set True when the cell under the cursor may be chosen.)
  @param(done Set True when a cell was taken, False on Exit or Escape.)
  @param(sel Receives the creature (nil for a bare cell) and cell taken; on Exit the starting cell.)
  @param(cellX Arena column the cursor starts on.)
  @param(cellY Arena row the cursor starts on.) }
procedure ManualAimCursor(cur, underCursor: Types.PCharRecord; range, weaponMode, groundOk, creatureOk: Byte;
                          var valid: Boolean; var done: Boolean; var sel: TAimTarget; cellX, cellY: Byte);
var
  menu: string[40];
  ch: Char;
  weapon: Types.PItemRec;
  dir: Byte;
  j: Byte;
  wx: ShortInt;
  wy: ShortInt;
  crIdx: Byte;
  terrIdx: Byte;
  saveX: Byte;
  saveY: Byte;
  dist: Word;
begin
  GDVars.aimActive := 1;
  saveX := cellX;
  saveY := cellY;
  GDVars.aimCursorX := cellX;
  GDVars.aimCursorY := cellY;
  GameIo.FillWord(sel, SizeOf(sel));
  GDVars.arenaPtr^.cursorOn := True;
  GDVars.arenaPtr^.cursorSize := 1;
  ch := ' ';
  dir := C_Dir.CENTER;
  GDVars.castConfirmed := False;
  { the set holds the exit keys, so the loop runs until one is pressed }
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    CbtMap.ScrollView(GDVars.aimCursorX, GDVars.aimCursorY, 2, dir);
    Inc(GDVars.aimCursorX, GDConsts.dirDx[dir]);
    Inc(GDVars.aimCursorY, GDConsts.dirDy[dir]);
    if GDVars.aimCursorX < 0 then GDVars.aimCursorX := 0;
    if GDVars.aimCursorY < 0 then GDVars.aimCursorY := 0;
    if GDVars.aimCursorX > 49 then GDVars.aimCursorX := 49;
    if GDVars.aimCursorY > 24 then GDVars.aimCursorY := 24;
    CbtMap.GetArenaContents(GDVars.aimCursorX, GDVars.aimCursorY, crIdx, terrIdx);
    GameIo.FlushKeys;
    valid := False;
    dist := 255;
    wx := GDVars.aimCursorX;
    wy := GDVars.aimCursorY;
    if Pathing.WalkLine(CbtMap.CombatCellX(cur), CbtMap.CombatCellY(cur), wx, wy, dist, GDVars.arenaPtr) then begin
      valid := True;
      if weaponMode <> 0 then
        TextRend.DisplayString(0, 23, LightGreen, 0, 'Range = ' + CharHlp.Uint16Str(dist div 2) + '  ');
    end else if weaponMode <> 0 then
      Border.ClearBox(0, 23, 39, 23);
    dist := dist div 2;
    underCursor := nil;
    if valid then begin
      if crIdx > 0 then
        underCursor := GDVars.creatures[crIdx]
      else if (terrIdx = 30) or (terrIdx = 28) then
        for j := 1 to GDVars.downedCount do
          if (GDVars.downed[j].x = GDVars.aimCursorX) and (GDVars.downed[j].y = GDVars.aimCursorY) then
            underCursor := GDVars.downed[j].cr;
    end;
    if underCursor <> nil then begin
      GDVars.panelDirty := 1;
      CharHlp.CombatPrintCreatureInfo(underCursor);
    end else
      Border.ClearBox(23, 1, 38, 21);
    if (range < dist) or (GDConsts.terrainInfo[terrIdx].cost = 255) then
      valid := False;
    if underCursor <> nil then begin
      if not CbtActs.CanTarget(cur, underCursor) or (creatureOk = 0) then
        valid := False;
      if weaponMode = 1 then begin
        if (cur = underCursor)
           or ((crIdx = 0) and ((terrIdx = 30) or (terrIdx = 28))) then
          valid := False
        else if CharHlp.HasRangedWeapon(cur)
                and
                  (not CharHlp.FindDamagingRangedWeapon(cur, weapon) or
                   ((CharHlp.CountTargets(cur, 1) > 0) and not CharHlp.HasThrowableWeapon(cur))) then
          valid := False;
      end;
    end else if groundOk = 0 then
      valid := False;
    if valid then menu := 'Target' else menu := 'Exit';
    ch := MenuCore.MenuHorizontal('(Use Cursor keys) ', menu, LightMagenta, LightGreen, White, 1, 0,
                                  GDVars.menuExt);
    case ch of
      C_Keys.ENTER, 'T':
        begin
          done := True;
          sel.x := GDVars.aimCursorX;
          sel.y := GDVars.aimCursorY;
          if underCursor <> nil then sel.ptr := underCursor else sel.ptr := nil;
          GDVars.arenaPtr^.cursorOn := False;
          CbtMap.RedrawArenaCell(GDVars.aimCursorX, GDVars.aimCursorY);
          GDVars.castConfirmed := False;
        end;
      { the numeric keypad's scan codes, laid out as the compass they draw }
      C_Keys.UP: dir := C_Dir.NORTH;
      C_Keys.PAGE_UP: dir := C_Dir.NORTHEAST;
      C_Keys.RIGHT: dir := C_Dir.EAST;
      C_Keys.PAGE_DOWN: dir := C_Dir.SOUTHEAST;
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      C_Keys.LEFT: dir := C_Dir.WEST;
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
      ' ':
        begin
          CbtMap.ScrollView(GDVars.aimCursorX, GDVars.aimCursorY, 0, C_Dir.CENTER);
          dir := C_Dir.CENTER;
        end;
      'E', C_Keys.NONE:
        begin
          done := False;
          CbtMap.RedrawArenaCell(GDVars.aimCursorX, GDVars.aimCursorY);
          GameIo.FillWord(sel, SizeOf(sel));
          sel.x := saveX;
          sel.y := saveY;
          CbtMap.ScrollView(saveX, saveY, 0, C_Dir.CENTER);
          GDVars.arenaPtr^.cursorOn := False;
          CbtMap.RedrawArenaCell(saveX, saveY);
          GDVars.castConfirmed := False;
        end;
    else
      dir := C_Dir.CENTER;
    end;
  end;
  GDVars.aimActive := 0;
end;

procedure CombatAimMenu(cr: Types.PCharRecord; range, weaponMode, groundOk, creatureOk: Byte; var done: Boolean;
                        var tgt);
var
  targets: array[1..72] of Types.TTarget;
  effRange: Byte;
  tgtCount: Byte;
  curIdx: Byte;
  step: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  menuStep: Byte;
  curX: ShortInt;
  curY: ShortInt;
  newX: ShortInt;
  newY: ShortInt;
  cur: Types.PCharRecord;
  ch: Char;
  valid: Boolean;
  accepted: Boolean;
  cellX: Byte;
  cellY: Byte;
  saveX: Byte;
  saveY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  aimDelay: Word;

  { Copies the creatures within radius 127 of c that it may attack into the local target list. }
  procedure BuildAimTargets(c: Types.PCharRecord);
  var
    i: Byte;
  begin
    Pathing.BuildTargetList(CbtMap.CombatCellX(c), CbtMap.CombatCellY(c), 127, 255, CbtMap.GetIconSize(c),
                            GDVars.arenaPtr);
    { filter the target list and compact it }
    tgtCount := 0;
    for i := 1 to GDVars.targetCount do
      if CbtActs.CanTarget(c, GDVars.creatures[GDVars.targets[i].who]) then begin
        Inc(tgtCount);
        targets[tgtCount] := GDVars.targets[i];
      end;
  end;

  { Moves the aim through the target list, wrapping, flying the cursor there when animate is set. }
  function AdvanceAimTarget(step: ShortInt; animate: Boolean): Types.PCharRecord;
  var
    { Unused in this version; see the other implementations of this routine. }
    previousTarget: Pointer;
  begin
    if animate then begin
      curX := GDVars.arenaLoc[targets[curIdx].who].x;
      curY := GDVars.arenaLoc[targets[curIdx].who].y;
    end else
      CbtMap.RedrawArenaCell(curX, curY);
    Inc(curIdx, step);
    if curIdx = 0 then curIdx := tgtCount;
    if curIdx > tgtCount then curIdx := 1;
    AdvanceAimTarget := GDVars.creatures[targets[curIdx].who];
    newX := GDVars.arenaLoc[targets[curIdx].who].x;
    newY := GDVars.arenaLoc[targets[curIdx].who].y;
    if animate then begin
      CharHlp.CombatAnimateMovingIcon(curX, curY, newX, newY, 1, 0);
      curX := newX;
      curY := newY;
    end;
  end;

begin
  CharHlp.CopyIconFacing(25, 0, 0, False);
  GameIo.FillWord(tgt, SizeOf(TAimTarget));
  done := False;
  effRange := range;
  if effRange = 255 then begin
    if cr^.equipped[0] <> nil then
      effRange := GDVars.baseItems[cr^.equipped[0]^.itemType].range - 1
    else
      effRange := 1;
  end;
  if (effRange = 0) or (effRange = 255) then
    effRange := 1;
  BuildAimTargets(cr);
  curIdx := 1;
  step := 0;
  cur := AdvanceAimTarget(step, True);
  ch := ' ';
  cellX := CbtMap.CombatCellX(cur);
  cellY := CbtMap.CombatCellY(cur);
  saveX := cellX;
  saveY := cellY;
  valid := True;
  { the set holds the exit keys; ch starts as a space so the loop runs }
  while not (ch in [C_Keys.NONE, C_Keys.ENTER, 'E', 'T']) do
  begin
    ch := CbtActs.AimTargetMenu(cr, cur, effRange, weaponMode, groundOk, creatureOk, Byte(valid), cellX, cellY);
    if not GDVars.extKeyFlag then
      case ch of
        'N':
          begin
            step := 1;
            valid := True;
            cur := AdvanceAimTarget(1, True);
          end;
        'P':
          begin
            step := -1;
            valid := True;
            cur := AdvanceAimTarget(-1, True);
          end;
        'M':
          begin
            CbtActs.ManualAimCursor(cr, cur, effRange, weaponMode, groundOk, creatureOk, valid, accepted,
                                    TAimTarget(tgt), cellX, cellY);
            cur := TAimTarget(tgt).ptr;
            cellX := TAimTarget(tgt).x;
            cellY := TAimTarget(tgt).y;
            if valid and accepted then begin
              ch := 'T';
              GDVars.horizChoice := 4;
              if cur <> nil then TAimTarget(tgt).ptr := cur
                            else TAimTarget(tgt).ptr := nil;
              done := True;
              if weaponMode = 1 then
                CbtActs.ConfirmAttackTarget(cr, cur, weaponMode, done, TAimTarget(tgt));
              if not done then begin
                GDVars.arenaPtr^.cursorOn := False;
                CbtMap.ScrollView(cellX, cellY, 0, C_Dir.CENTER);
              end;
            end else
              GDVars.horizChoice := 3;
          end;
        'T':
          begin
            TAimTarget(tgt).x := cellX;
            TAimTarget(tgt).y := cellY;
            if cur <> nil then TAimTarget(tgt).ptr := cur
                          else TAimTarget(tgt).ptr := nil;
            done := True;
            if weaponMode = 1 then
              CbtActs.ConfirmAttackTarget(cr, cur, weaponMode, done, TAimTarget(tgt));
            if not done then begin
              GDVars.arenaPtr^.cursorOn := False;
              CbtMap.ScrollView(cellX, cellY, 0, C_Dir.CENTER);
            end;
          end;
        'C':
          begin
            GDVars.arenaPtr^.cursorOn := True;
            GDVars.arenaPtr^.cursorSize := 1;
            CbtMap.ScrollView(cellX, cellY, 0, C_Dir.CENTER);
            GDVars.arenaPtr^.cursorOn := False;
          end;
        'E':
          begin
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.ScrollView(cellX, cellY, 0, C_Dir.CENTER);
          end;
        C_Keys.NONE:
          begin
            GDVars.arenaPtr^.cursorOn := False;
            CbtMap.RedrawArenaCell(cellX, cellY);
            CbtMap.ScrollView(saveX, saveY, 0, C_Dir.CENTER);
          end;
      end;
    if (ch = 'N') or (ch = 'P') or (ch = 'T') then
    begin
      cellX := CbtMap.CombatCellX(cur);
      cellY := CbtMap.CombatCellY(cur);
    end;
  end;
  if weaponMode <> 0 then
    Border.ClearBox(0, 23, 39, 23);
end;

function AcquireTarget(cr: Types.PCharRecord; range, relaxed, forceNew: Byte): Boolean;
var
  cnt: Byte;
  tries: Byte;
  pick: Byte;
  second: Boolean;
  found: Boolean;
  pass: Boolean;
  p: Types.PCharRecord;
  eff: Types.PEffectRec;
begin
  eff := nil;
  pass := False;
  found := False;
  second := False;
  p := cr^.combatAddr^.other;
  if (forceNew <> 0)
     or ((p <> nil) and ((p^.hostile = cr^.hostile) or (p^.enabled = 0) or (not CbtActs.CanTarget(cr, p)))) then
    cr^.combatAddr^.other := nil;
  if cr^.combatAddr^.other <> nil then
    found := True;
  while (not found) and (not second) do begin
    second := pass;
    if pass and (forceNew = 0) then
      GDVars.arenaPtr^.distMode := 1;
    tries := 20;
    cnt := CharHlp.CountTargets(cr, range);
    while (tries > 0) and (not found) and (cnt > 0) do begin
      Dec(tries);
      if CharHlp.HasEffect(cr, 91, eff)
         and (GDVars.creatures[GDVars.targetIdx[1]] = GDVars.curCreature)
         and (tries = 19) then
        pick := 1
      else
        pick := FxEngine.RollDice(1, cnt);
      if GDVars.targetIdx[pick] > 0 then begin
        p := GDVars.creatures[GDVars.targetIdx[pick]];
        if ((relaxed <> 0) and (GDVars.arenaPtr^.distMode <> 0))
           or CbtActs.CanTarget(cr, p) then begin
          found := True;
          cr^.combatAddr^.other := p;
        end else begin
          GDVars.targetIdx[pick] := 0;
          for pick := 1 to cnt do
            if GDVars.targetIdx[pick] > 0 then
              found := True;
          if found then
            found := False
          else
            cnt := 0;
        end;
      end;
    end;
    if not pass then
      pass := True;
  end;
  GDVars.arenaPtr^.distMode := 0;
  AcquireTarget := found;
end;

function VictoryCheat: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  c: Types.PCharRecord;
begin
  VictoryCheat := False;
  if ParamStr(2) <> GDVars.stingKey then
    Exit;
  VictoryCheat := True;
  CharHlp.PrintBottomLine('The Gods intervene!');
  c := GDVars.creatureList;
  while c <> nil do begin
    if c^.hostile = 1 then begin
      c^.enabled := 0;
      c^.status := C_Status.DEAD_STATUS;
      GDVars.arenaLoc[CbtMap.CombatSlot(c)].size := 0;
    end;
    done := CharHlp.EndActions(c);
    c := c^.nextCharAddr;
  end;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
end;

begin
end.
