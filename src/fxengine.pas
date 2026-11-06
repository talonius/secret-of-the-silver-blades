{ The effects, dice, saving-throw and damage engine. }
{$O+,F+,A-,I-,V-}
unit FxEngine;

interface

uses Types, CharHlp, Pathing, CbtMap, EclTrace, Blit, TextRend, GDConsts, GDVars,
  C_Status, C_Effect, C_Ifc, C_Dir, C_Stat, C_Class, C_Save;

{ Prints msg for cr. Unless cr is already petrified, dead or gone, it then gives cr status, takes it out of play at 0
  hit points, removes its effects that end at 0 hit points, marks it downed on the combat map when it is still out of
  play, pauses, clears the message window and, outside combat, redraws the party.
  @param(cr Creature being killed.)
  @param(status Status to give it.)
  @param(msg Message printed after its name.) }
procedure KillCreature(cr: Types.PCharRecord; status: Byte; msg: Types.TStr40);

{ Unlinks an effect node from cr's effect list and frees it, calling the handler of effId first when the node's onRemove
  flag is set. Removing effect 14 recalculates Charisma; removing effect 12, 38 or 113 recalculates Strength.
  @param(cr Creature whose effect is removed.)
  @param(effId Effect looked for when eff is nil; it also selects the handler and the ability recalculated.)
  @param(eff Node to remove, or nil for cr's first effect effId; nothing happens when there is none.) }
procedure RemoveEffect(cr: Types.PCharRecord; effId: Byte; eff: Pointer);

{ Applies the clouds on the cells of a creature in play. In a stinking cloud, when flag is nonzero and the creature has
  no first thief skill, is not helpless, is not protected by effect 99 and lacks target flag bit 3, it rolls a
  paralyzation save: on a save it starts to cough for 1 minute, otherwise nausea leaves it helpless for 1d4 + 1. The
  cloud's caster stands in as the current character while the effect is added and its handler runs. In a cloudkill a
  creature of level 0..4 is poisoned and killed, one of level 5 unless it saves at -4, and one of level 6 unless it
  saves. Note: the cough handler is passed the node left by the last failed effect search, which is nil, rather than the
  cough effect just added.
  @param(cr Creature to check.)
  @param(flag Nonzero to let a stinking cloud act.) }
procedure ConsiderTerrainEffects(cr: Types.PCharRecord; flag: Byte);

{ Rolls an attack that has no attacking creature: a d20, where 1 always misses and 20 counts as 100, adjusted by the
  defender's condition-16 effects.
  @param(defender Creature attacked.)
  @param(sixtyMinusThac0 The attack's to-hit value, 60 minus its THAC0.)
  @returns(True when the adjusted roll is not negative and the roll plus the to-hit value exceeds the defender's armor
    class.) }
function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;

{ Rolls attacker's attack on defender. Makes attacker visible, rolls a d20 into GDVars.attackRoll (1 always misses, 20
  counts as 100), runs attacker's condition-10 effects, and adds the side's to-hit modifier from zone 1: the party's for
  an attacker on the party's side, the monsters' otherwise. The values go to the debug trace. Note: the party's
  adjustment selects on the constant ATTACK_STYLE, which matches none of its cases, so it never applies.
  @param(attacker Creature attacking.)
  @param(defender Creature attacked.)
  @param(sixtyMinusAc Value the attack must reach, 60 minus defender's armor class.)
  @returns(True when the adjusted roll is not negative and the roll plus attacker's toHitCur and the modifier reaches
    sixtyMinusAc.) }
function AttackRoll(attacker, defender: Types.PCharRecord;
                    sixtyMinusAc: Byte): Boolean;

{ Rolls a creature's saving throw. A natural 1 fails and a natural 20 succeeds; otherwise the d20 plus the creature's
  saving throw bonus and the modifier, after the creature's condition-12 effects, must reach its save value for the
  category. The roll and the result are kept for later use, and so is the category when the roll is neither 1 nor 20.
  Note: the total is kept in a Byte, so a total below 0 wraps to a large value and succeeds.
  @param(cr Creature saving.)
  @param(saveType Saving throw category, an index into the creature's saves.)
  @param(modifier Added to the roll.)
  @returns(True when the save succeeds.) }
function RollSavingThrow(cr: Types.PCharRecord; saveType, modifier: Byte): Boolean;

{ Rolls a number of dice and adds them up.
  @param(n Number of dice; 0 rolls nothing.)
  @param(sides Faces per die.)
  @returns(The sum, kept in a Byte, so a total above 255 wraps.) }
function RollDice(n, sides: Byte): Byte;

{ Rolls damage dice, recording the number of dice for the resistances.
  @param(n Number of dice.)
  @param(sides Faces per die.)
  @returns(The sum, as RollDice returns it.) }
function RollDamageDice(n, sides: Byte): Byte;

{ Adds an effect node to the end of a creature's effect list. It neither checks for a node already there nor calls the
  effect's handler.
  @param(cr The creature.)
  @param(effId The effect.)
  @param(minutes Its duration in minutes; 0 for a permanent effect.)
  @param(strength Its strength.)
  @param(onRemove True to call the effect's handler when it is removed.) }
procedure AddEffect(cr: Types.PCharRecord; effId: Byte; minutes: Word; strength,
                    onRemove: Byte);

{ Takes an enabled creature out of play: centers the map on it, prints a message after its name, disables it and sets
  its status. Its hit points drop to 0 unless it fled (running). Its icon is erased from the combat map and taken off
  the arena, and when its actions end the effects that end at 0 hit points are removed.
  @param(cr The creature.)
  @param(status Its new status.)
  @param(msg The message.) }
procedure PutOutOfPlayWithStatus(cr: Types.PCharRecord; status: Byte; msg: Types.TStr40);

{ Removes each invisibility node from a creature.
  @param(cr The creature.) }
procedure RemoveInvisibility(cr: Types.PCharRecord);

{ Removes one copy of each of the fourteen effects listed in GDConsts.hpZeroEffects, the effects that end when a
  creature goes down. A creature that still has effect 77 afterwards and whose npc value is $B3 returns to the party's
  side.
  @param(cr Creature that went down.) }
procedure RemoveEffectsHp0(cr: Types.PCharRecord);

{ Empty: no effects end with combat AI control.
  @param(cr Unused.) }
procedure RemoveAiEffects(cr: Types.PCharRecord);

{ Removes cr's first effect effId.
  @param(cr Creature cured.)
  @param(effId Effect to remove.)
  @returns(True when cr had the effect.) }
function RemoveEffectWithMessage(cr: Types.PCharRecord; effId: Byte): Boolean;

{ Encodes a Strength as an effect strength: 18 with exceptional Strength becomes the exceptional value + 1 (1..101), any
  other base Strength becomes the base + 100.
  @param(baseStr Base Strength.)
  @param(excStr Exceptional Strength, read when the base Strength is 18.)
  @returns(The encoded Strength.) }
function StrengthModifier(baseStr, excStr: Byte): Byte;

{ Decodes an effect's strength byte, bit 7 aside, into Strength: up to 101 is Strength 18 with exceptional Strength of
  the value less 1, above it Strength of the value less 100 with no exceptional Strength.
  @param(eff The Strength effect.)
  @param(baseStr Receives Strength.)
  @param(excStr Receives exceptional Strength.) }
procedure StrengthEffectToStrength(eff: Types.PEffectRec; var baseStr, excStr: Byte);

{ Tells whether a Strength beats cr's permanent one: a higher base Strength, or 18 with exceptional Strength above cr's
  current exceptional Strength.
  @param(cr Creature compared against.)
  @param(baseStr Candidate base Strength.)
  @param(excStr Candidate exceptional Strength.)
  @param(out Receives the candidate's encoding (StrengthModifier) when it is better; unchanged otherwise.)
  @returns(True when the candidate is better.) }
function AdjustForNewStrength(cr: Types.PCharRecord; baseStr, excStr: Byte;
                              var out: Byte): Boolean;

{ Deals damage that is not a weapon hit. The creature's condition-6 effects adjust it first; then, when saved, a save
  reduction of 1 cancels it and 2 halves it, while without a save the condition-20 effects run. Damage left over on a
  creature in play is printed with its type and applied, and in combat it stops the creature's casting; a spell it was
  casting is lost and its actions for the round end. A creature this takes out of play is reported as going down, dying
  or killed: outside combat the game pauses; in combat its 0-hit-point effects are removed, its condition-13 effects run
  and it is marked downed if it is still out of play and has not exploded. The damage type comes from the current
  element mask: Fire, Cold, Electricity or Acid is named when it is the one type besides Magic, and "from Magic" is
  printed when Magic is the one type or no type is set.
  @param(cr Creature hurt.)
  @param(damage Damage before adjustment.)
  @param(saveReduction What a save does: 1 cancels the damage, 2 halves it, other values leave it.)
  @param(saved True when the creature made its saving throw.) }
procedure InflictNonWeaponDamage(cr: Types.PCharRecord; damage, saveReduction: Byte;
                                 saved: Boolean);

{ Applies effect effId to cr unless its condition-9 effects block it or a save negates it (saveNegates 1 and saved);
  then 'is Unaffected' is printed instead. When cr already has the effect with time left, a longer duration replaces its
  time; otherwise the effect is added. msg, when not empty, is announced with the effect animation.
  @param(cr Creature given the effect.)
  @param(effId Effect to add.)
  @param(minutes Duration.)
  @param(strength Effect strength, read by its handler.)
  @param(onRemove Nonzero to call the effect's handler when it is removed.)
  @param(saveNegates 1 when a successful save cancels the effect.)
  @param(saved True when cr made its saving throw.)
  @param(msg Message printed after its name, or empty.) }
procedure AddEffectWithMessage(cr: Types.PCharRecord; effId: Byte; minutes: Word; strength, onRemove, saveNegates: Byte;
                               saved: Boolean; msg: Types.TStr40);

{ Heals a creature that is okay, animated, unconscious or dying by the given hit points, capped at its maximum; when the
  flag is set, a creature already at its maximum is left alone. A healed creature out of play goes from dying to
  unconscious, and an unconscious one outside combat comes back into play okay. Note: the sum of the current and
  restored hit points is kept in a Byte, so a total above 255 wraps before the cap applies.
  @param(cr Creature healed.)
  @param(hp Hit points to restore.)
  @param(bypassRot Set to leave a creature at its maximum unhealed.)
  @returns(True when it healed.) }
function RestoreHitPoints(cr: Types.PCharRecord; hp, bypassRot: Byte): Boolean;

{ Empty routine with no callers. }
procedure NoopFxEngine;

{ Recomputes the current value of one ability of cr from its permanent value, its readied magic items and its effects.
  Items can raise or lower an ability or force it to 3 or 7. Strength keeps the best of the items, effect 38, which adds
  its decoded Strength to a creature at 18/99 or less and turns each point above 18 into 10 exceptional points for a
  fighter, paladin or ranger (others stop at 18), effect 113 (21) and effect 12. Constitution recomputes the maximum hit
  points from the rolled hit points and the Constitution bonus of the class levels, moves the current hit points by the
  change, and keeps effect 62 on while it is 20 or more. Intelligence and Wisdom take a forced value, 3 when
  feebleminded; Dexterity takes a forced value, and Charisma adds the strength of effect 14.
  @param(cr Creature recalculated.)
  @param(mode Ability, a C_Stat index from STRENGTH to CHARISMA.) }
procedure RecalcAbility(cr: Types.PCharRecord; mode: ShortInt);

{ Runs TriggerEffect for each effect on the list of condition cond, in list order; conditions 6 and 9 first let the
  creature's magic resistance cancel the pending damage or effect (CheckSpellResistance). The conditions this unit
  raises are 6 damage taken, 9 an effect being applied, 10 the attacker's attack roll, 12 a saving throw and 20 damage
  taken without a save. Conditions without a list (0, 13, 16 and others) do nothing.
  @param(cond Condition being checked.)
  @param(cr Creature whose effects are checked.) }
procedure TriggerEffectsWithCondition(cond: Byte; var cr: Types.PCharRecord);

{ Calls an effect's handler, or the override handler instead while an override is active.
  @param(effId Effect whose handler is called.)
  @param(cr Creature the effect acts on.)
  @param(p Node of the effect, passed on to the handler; may be nil.)
  @param(removed True when the call is for the effect's removal.) }
procedure CallEffectHandler(effId: Byte; var cr: Types.PCharRecord; p: Pointer;
                            removed: Boolean);

implementation

type
  { The footprint direction list FindCreatureAtCell scans, passed by reference. }
  TCellIds = array[0..3] of Byte;

var
  cloudDirs: TCellIds absolute GDConsts.cloudDirs;

procedure KillCreature(cr: Types.PCharRecord; status: Byte; msg: Types.TStr40);
begin
  CharHlp.PrintCreatureMessage(cr, msg, 10, False);
  case cr^.status of
    C_Status.PETRIFIED, C_Status.DEAD_STATUS, C_Status.GONE: ;
  else begin
      cr^.status := status;
      cr^.enabled := 0;
      cr^.hpCur := 0;
      FxEngine.RemoveEffectsHp0(cr);
      if cr^.enabled = 0 then
        CbtMap.CreatureDowned(cr);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow;
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayRoster(GDVars.curChar);
    end;
  end;
end;

procedure RemoveEffect(cr: Types.PCharRecord; effId: Byte; eff: Pointer);
var
  prev: Types.PEffectRec;
  e: Types.PEffectRec;
begin
  e := Types.PEffectRec(eff);
  if e = nil then begin
    e := cr^.effectsAddr;
    while (e <> nil) and (e^.id <> effId) do
      e := e^.next;
  end;
  if e = nil then
    exit;
  if e^.onRemove <> 0 then
    FxEngine.CallEffectHandler(effId, cr, e, True);
  if cr^.effectsAddr = e then
    cr^.effectsAddr := e^.next
  else begin
    prev := cr^.effectsAddr;
    while (prev <> nil) and (prev^.next <> e) do
      prev := prev^.next;
    prev^.next := e^.next;
  end;
  FreeMem(e, SizeOf(e^));
  if effId = 14 then
    FxEngine.RecalcAbility(cr, C_Stat.CHARISMA);
  if (effId = C_Effect.ENLARGE) or (effId = C_Effect.STRENGTH) or (effId = 113) then
    FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
end;

{ Lets a creature's magic resistance cancel the pending spell: with an effect pending (and, when damage is pending, a
  magical one), d100 against its resistance adjusted by 5 per caster level below 11 (above 11 lowers it) clears the
  pending damage and, except for effects 91 and 82, the pending effect.
  @param(cr The creature resisting.) }
procedure CheckSpellResistance(cr: Types.PCharRecord);
var
  gate: Byte;
  threshold: Byte;
  factor: Byte;
begin
  gate := cr^.magicResistance;
  if (gate <> 0) and (GDVars.currentEffectId <> 0) then begin
    if (GDVars.pendingDamage <> 0) and ((GDVars.elemMask and 8) = 0) then
      Exit;
    factor := CharHlp.GetCasterLevel(GDVars.spellId);
    threshold := gate + (11 - factor) * 5;
    if FxEngine.RollDice(1, 100) <= threshold then begin
      GDVars.pendingDamage := 0;
      if (GDVars.currentEffectId <> 91) and (GDVars.currentEffectId <> 82) then
        GDVars.currentEffectId := 0;
    end;
  end;
end;

{ Fires one effect on a creature: calls its handler when the creature has the effect, or, for the aura effects Silence
  15', Protection from Evil 10', Protection from Good 10' and Prayer, when a creature carrying it has this one in range
  (6 cells for Prayer, else 1; outside combat any carrier counts). The handler gets the node found: the creature's own,
  or the carrier's for an aura. The range test builds a target list, and the caller's target list is kept around it.
  @param(cr The creature.)
  @param(effId The effect.) }
procedure TriggerEffect(var cr: Types.PCharRecord; effId: Byte);
var
  saved: array[1..72] of Types.TTarget;
  p: Types.PCharRecord;
  eff: Types.PEffectRec;
  found: Boolean;
  i: Byte;
  radius: Byte;
begin
  found := False;
  p := GDVars.creatureList;
  if CharHlp.HasEffect(cr, effId, eff) then
    found := True
  { these four are the area effects that need a target-list sweep }
  else if effId in [21, 45, 46, 49] then begin
    Move(GDVars.targets, saved, SizeOf(saved));
    while (p <> nil) and (found = False) do begin
      if CharHlp.HasEffect(p, effId, eff) then begin
        if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
          if effId = 49 then
            radius := 6
          else
            radius := 1;
          Pathing.BuildTargetList(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), radius, 255, CbtMap.GetIconSize(p),
                                  GDVars.arenaPtr);

          for i := 1 to GDVars.targetCount do
            if GDVars.targets[i].who = CbtMap.CombatSlot(cr) then
              found := True;
        end else
          found := True;
      end;
      p := p^.nextCharAddr;
    end;
    Move(saved, GDVars.targets, SizeOf(saved));
  end;
  if found then
    FxEngine.CallEffectHandler(effId, cr, eff, False);
end;

procedure CallEffectHandler(effId: Byte; var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if GDVars.overrideFlag <> 0 then
    GDVars.overrideHandler(cr, p, removed)
  else
    GDVars.effectHandlers[effId](cr, p, removed);
end;

procedure TriggerEffectsWithCondition(cond: Byte; var cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
begin
  case cond of
    0: ;
    1:
      begin
        FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
        FxEngine.TriggerEffect(cr, 37);
        FxEngine.TriggerEffect(cr, 69);
      end;
    2:
      begin
        FxEngine.TriggerEffect(cr, 65);
        FxEngine.TriggerEffect(cr, 86);
        FxEngine.TriggerEffect(cr, 88);
      end;
    3:
      begin
        FxEngine.TriggerEffect(cr, 64);
        FxEngine.TriggerEffect(cr, 65);
        FxEngine.TriggerEffect(cr, 86);
        FxEngine.TriggerEffect(cr, 88);
      end;
    4:
      begin
        FxEngine.TriggerEffect(cr, 29);
        FxEngine.TriggerEffect(cr, 66);
        FxEngine.TriggerEffect(cr, 75);
        FxEngine.TriggerEffect(cr, C_Effect.RANGER_DAMAGE_BONUS);
        FxEngine.TriggerEffect(cr, 32);
      end;
    5:
      begin
        FxEngine.TriggerEffect(cr, 28);
        FxEngine.TriggerEffect(cr, 41);
        FxEngine.TriggerEffect(cr, 60);
        FxEngine.TriggerEffect(cr, 90);
        FxEngine.TriggerEffect(cr, 103);
        FxEngine.TriggerEffect(cr, 112);
      end;
    6:
      begin
        FxEngine.CheckSpellResistance(cr);
        FxEngine.TriggerEffect(cr, 6);
        FxEngine.TriggerEffect(cr, 10);
        FxEngine.TriggerEffect(cr, 17);
        FxEngine.TriggerEffect(cr, 20);
        FxEngine.TriggerEffect(cr, 28);
        FxEngine.TriggerEffect(cr, 61);
        FxEngine.TriggerEffect(cr, 63);
        FxEngine.TriggerEffect(cr, 57);
        FxEngine.TriggerEffect(cr, 73);
        FxEngine.TriggerEffect(cr, 79);
        FxEngine.TriggerEffect(cr, 93);
        FxEngine.TriggerEffect(cr, 98);
      end;
    7:
      begin
        FxEngine.TriggerEffect(cr, 3);
        FxEngine.TriggerEffect(cr, 27);
        FxEngine.TriggerEffect(cr, C_Effect.HELPLESS);
        FxEngine.TriggerEffect(cr, 51);
        FxEngine.TriggerEffect(cr, 52);
        FxEngine.TriggerEffect(cr, 53);
      end;
    8:
      begin
        FxEngine.TriggerEffect(cr, 56);
        FxEngine.TriggerEffect(cr, 82);
        FxEngine.TriggerEffect(cr, 89);
        FxEngine.TriggerEffect(cr, 108);
      end;
    9:
      begin
        FxEngine.CheckSpellResistance(cr);
        FxEngine.TriggerEffect(cr, 18);
        FxEngine.TriggerEffect(cr, 28);
        FxEngine.TriggerEffect(cr, 63);
        FxEngine.TriggerEffect(cr, 76);
        FxEngine.TriggerEffect(cr, 79);
        FxEngine.TriggerEffect(cr, 92);
        FxEngine.TriggerEffect(cr, 95);
        FxEngine.TriggerEffect(cr, 96);
        FxEngine.TriggerEffect(cr, 99);
      end;
    10:
      begin
        FxEngine.TriggerEffect(cr, 1);
        FxEngine.TriggerEffect(cr, 2);
        FxEngine.TriggerEffect(cr, 7);
        FxEngine.TriggerEffect(cr, 26);
        FxEngine.TriggerEffect(cr, C_Effect.BLIND);
        FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
        FxEngine.TriggerEffect(cr, 49);
        FxEngine.TriggerEffect(cr, 75);
      end;
    11:
      begin
        FxEngine.TriggerEffect(cr, 4);
        FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
        FxEngine.TriggerEffect(cr, 9);
        FxEngine.TriggerEffect(cr, 13);
        FxEngine.TriggerEffect(cr, 17);
        FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
        FxEngine.TriggerEffect(cr, C_Effect.BLIND);
        FxEngine.TriggerEffect(cr, 45);
        FxEngine.TriggerEffect(cr, 46);
        FxEngine.TriggerEffect(cr, 47);
        FxEngine.TriggerEffect(cr, 48);
        FxEngine.TriggerEffect(cr, 71);
        FxEngine.TriggerEffect(cr, 74);
      end;
    12:
      begin
        FxEngine.TriggerEffect(cr, C_Effect.PROTECTION_FROM_EVIL);
        FxEngine.TriggerEffect(cr, 9);
        FxEngine.TriggerEffect(cr, 10);
        FxEngine.TriggerEffect(cr, 13);
        FxEngine.TriggerEffect(cr, 17);
        FxEngine.TriggerEffect(cr, 20);
        FxEngine.TriggerEffect(cr, C_Effect.BLIND);
        FxEngine.TriggerEffect(cr, C_Effect.BESTOW_CURSE);
        FxEngine.TriggerEffect(cr, 45);
        FxEngine.TriggerEffect(cr, 46);
        FxEngine.TriggerEffect(cr, 49);
        FxEngine.TriggerEffect(cr, 50);
        FxEngine.TriggerEffect(cr, 54);
        FxEngine.TriggerEffect(cr, 61);
        FxEngine.TriggerEffect(cr, 78);
        FxEngine.TriggerEffect(cr, 94);
      end;
    14:
      begin
        FxEngine.TriggerEffect(cr, 58);
        FxEngine.TriggerEffect(cr, 67);
        FxEngine.TriggerEffect(cr, 70);
        FxEngine.TriggerEffect(cr, 80);
        FxEngine.TriggerEffect(cr, 81);
        FxEngine.TriggerEffect(cr, 83);
        FxEngine.TriggerEffect(cr, 104);
        FxEngine.TriggerEffect(cr, 107);
      end;
    15:
      begin
        FxEngine.TriggerEffect(cr, 3);
        FxEngine.TriggerEffect(cr, 5);
        FxEngine.TriggerEffect(cr, 11);
        FxEngine.TriggerEffect(cr, 21);
        FxEngine.TriggerEffect(cr, 27);
        FxEngine.TriggerEffect(cr, C_Effect.STINKING_CLOUD_COUGH);
        FxEngine.TriggerEffect(cr, 77);
        FxEngine.TriggerEffect(cr, 106);
        FxEngine.TriggerEffect(cr, C_Effect.INVISIBLE);
        FxEngine.TriggerEffect(cr, 37);
        FxEngine.TriggerEffect(cr, 47);
        FxEngine.TriggerEffect(cr, 48);
        FxEngine.TriggerEffect(cr, 69);
        FxEngine.TriggerEffect(cr, 89);
      end;
    17:
      begin
        FxEngine.TriggerEffect(cr, 1);
        FxEngine.TriggerEffect(cr, 2);
        FxEngine.TriggerEffect(cr, 11);
      end;
    18:
      begin
        FxEngine.TriggerEffect(cr, C_Effect.HASTED);
        FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
      end;
    19:
      begin
        FxEngine.TriggerEffect(cr, 11);
        FxEngine.TriggerEffect(cr, 23);
        FxEngine.TriggerEffect(cr, 56);
        FxEngine.TriggerEffect(cr, 100);
      end;
    20:
      begin
        FxEngine.TriggerEffect(cr, 50);
        FxEngine.TriggerEffect(cr, 54);
      end;
    21:
      begin
        FxEngine.TriggerEffect(cr, 35);
      end;
    22:
      begin
        FxEngine.TriggerEffect(cr, C_Effect.HASTED);
        FxEngine.TriggerEffect(cr, C_Effect.SLOWED);
        FxEngine.TriggerEffect(cr, 74);
      end;
  end;
end;

{ Finds the caster of the cloud covering a combat cell. Note: the direction table is read from index 1 against a table
  that starts at index 0, so with four cells per cloud the last cell checked comes from the byte after the table.
  @param(x Column of the cell.)
  @param(y Row of the cell.)
  @param(list First cloud node to check.)
  @param(count Number of cells checked per cloud.)
  @param(cells Directions from a cloud's corner to its cells, read from index 1.)
  @returns(The caster of the first cloud, from the given node on, that has one of its checked cells live at the cell;
    the head of the creature list when there is none.) }
function FindCreatureAtCell(x, y: ShortInt; list: Types.PCloudNode; count: Byte;
                            var cells: TCellIds): Types.PCharRecord;
var
  e: Types.PCloudNode;
  found: Boolean;
  i: Byte;
begin
  e := list;
  found := False;
  while (e <> nil) and not found do begin
    for i := 1 to count do
      if (e^.live[i] <> 0) and (e^.x + GDConsts.dirDx[cells[i]] = x) and (e^.y + GDConsts.dirDy[cells[i]] = y) then
        found := True;
    if not found then
      e := e^.next;
  end;
  if found then
    FindCreatureAtCell := e^.owner
  else
    FindCreatureAtCell := GDVars.creatureList;
end;

procedure ConsiderTerrainEffects(cr: Types.PCharRecord; flag: Byte);
var
  terrIdx: Byte;
  crIdx: Byte;
  eff: Types.PEffectRec;
  coughEff: Types.PEffectRec;
  saved: Boolean;
  adjStink: Byte;
  adjCloudkill: Byte;
  prevCur: Types.PCharRecord;
begin
  if cr^.enabled = 0 then
    Exit;
  CbtMap.ProbeDirection(cr, C_Dir.CENTER, crIdx, terrIdx, adjStink, adjCloudkill);
  if (adjStink <> 0) and (flag <> 0) and (cr^.firstThiefSkill = 0) and
      (not CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff)) and (not CharHlp.HasEffect(cr, 99, eff)) and
      ((cr^.targetFlags and 8) = 0) then begin
    saved := FxEngine.RollSavingThrow(cr, C_Save.PARALYZATION, 0);
    if saved then begin
      prevCur := GDVars.curChar;
      GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), GDVars.stinkHead, 4,
                                                    cloudDirs);
      FxEngine.AddEffectWithMessage(cr, C_Effect.STINKING_CLOUD_COUGH, 1, 255, 0, 0, saved, 'starts to cough');
      coughEff := nil;
      if CharHlp.HasEffect(cr, C_Effect.STINKING_CLOUD_COUGH, coughEff) then
        FxEngine.CallEffectHandler(C_Effect.STINKING_CLOUD_COUGH, cr, eff, False);
      GDVars.curChar := prevCur;
    end else begin
      prevCur := GDVars.curChar;
      GDVars.curChar := FxEngine.FindCreatureAtCell(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), GDVars.stinkHead, 4,
                                                    cloudDirs);
      FxEngine.AddEffectWithMessage(cr, C_Effect.HELPLESS, FxEngine.RollDice(1, 4) + 1, 255, 0, 0, saved,
                                    'chokes and gags from nausea');
      if CharHlp.HasEffect(cr, C_Effect.HELPLESS, eff) then
        FxEngine.CallEffectHandler(C_Effect.HELPLESS, cr, eff, False);
      GDVars.curChar := prevCur;
    end;
  end;
  if adjCloudkill = 0 then
    Exit;
  if cr^.enabled = 0 then
    Exit;
  case cr^.highestLevel of
    0..4:
      begin
        CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
        TextRend.PauseOnly;
        FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, 0);
        FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
      end;
    5:
      if not FxEngine.RollSavingThrow(cr, C_Save.PARALYZATION, 252) then begin
        CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
        TextRend.PauseOnly;
        FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, 0);
        FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
      end;
    6:
      if not FxEngine.RollSavingThrow(cr, C_Save.PARALYZATION, 0) then begin
        CharHlp.PrintCreatureMessage(cr, 'is Poisoned', 10, False);
        TextRend.PauseOnly;
        FxEngine.AddEffect(cr, C_Effect.POISONED, 0, 255, 0);
        FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'is killed');
      end;
  end;
end;

function AttackRollNoAttacker(defender: Types.PCharRecord; sixtyMinusThac0: Byte): Boolean;
begin
  AttackRollNoAttacker := False;
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then
      GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if GDVars.attackRoll >= 0 then
      if GDVars.attackRoll + sixtyMinusThac0 > defender^.acCurArr[0] then
        AttackRollNoAttacker := True;
  end;
end;

const
  ATTACK_STYLE = 500;

function AttackRoll(attacker, defender: Types.PCharRecord; sixtyMinusAc: Byte): Boolean;
var
  thac0Mod: ShortInt;
begin
  AttackRoll := False;
  FxEngine.RemoveInvisibility(attacker);
  GDVars.attackRoll := FxEngine.RollDice(1, 20);
  if GDVars.attackRoll > 1 then begin
    if GDVars.attackRoll = 20 then
      GDVars.attackRoll := 100;
    FxEngine.TriggerEffectsWithCondition(10, attacker);
    FxEngine.TriggerEffectsWithCondition(16, defender);
    if attacker^.hostileV1 = 0 then begin
      thac0Mod := GDVars.zone1^.modPartyThac0Lo;
      case FxEngine.ATTACK_STYLE of
        0: Inc(thac0Mod, 2);
        1: Inc(thac0Mod);
        3: Dec(thac0Mod);
        4: Dec(thac0Mod, 2);
      end;
    end else
      thac0Mod := GDVars.zone1^.modMonThac0Lo;
    EclTrace.ShowTrace('thac0', attacker^.toHitCur, sixtyMinusAc, thac0Mod);
    if GDVars.attackRoll >= 0 then
      if GDVars.attackRoll + attacker^.toHitCur + thac0Mod >= sixtyMinusAc then
        AttackRoll := True;
  end;
end;

function RollSavingThrow(cr: Types.PCharRecord; saveType, modifier: Byte): Boolean;
begin
  GDVars.saveResult := True;
  GDVars.saveRoll := FxEngine.RollDice(1, 20);
  case GDVars.saveRoll of
    1:
      GDVars.saveResult := False;
    20:
      GDVars.saveResult := True;
  else begin
      GDVars.saveRoll := GDVars.saveRoll + cr^.saveBonus + ShortInt(modifier);
      GDVars.saveType := saveType;
      FxEngine.TriggerEffectsWithCondition(12, cr);
      if cr^.saves[ShortInt(saveType)] <= GDVars.saveRoll then
        GDVars.saveResult := True
      else
        GDVars.saveResult := False;
    end;
  end;
  RollSavingThrow := GDVars.saveResult;
end;

function RollDice(n, sides: Byte): Byte;
var
  i: Byte;
  total: Byte;
begin
  total := 0;
  if n > 0 then
    for i := 1 to n do
      Inc(total, Random(sides) + 1);
  RollDice := total;
end;

function RollDamageDice(n, sides: Byte): Byte;
begin
  GDVars.damageDice := n;
  RollDamageDice := FxEngine.RollDice(n, sides);
end;

procedure AddEffect(cr: Types.PCharRecord; effId: Byte; minutes: Word; strength, onRemove: Byte);
var
  node: Types.PEffectRec;
  walk: Types.PEffectRec;
begin
  New(node);
  if cr^.effectsAddr = nil then
    cr^.effectsAddr := node
  else begin
    walk := cr^.effectsAddr;
    while walk^.next <> nil do
      walk := walk^.next;
    walk^.next := node;
  end;
  node^.next := nil;
  node^.id := effId;
  node^.minutes := minutes;
  node^.onRemove := onRemove;
  node^.strength := strength;
end;

procedure PutOutOfPlayWithStatus(cr: Types.PCharRecord; status: Byte; msg: Types.TStr40);
var
  id: Byte;
begin
  if cr^.enabled = 0 then
    Exit;
  id := CbtMap.CombatSlot(cr);
  CbtMap.DisplayMapViewCentered(cr, 3, False);
  CharHlp.PrintCreatureMessage(cr, msg, 10, True);
  cr^.enabled := 0;
  cr^.status := status;
  if cr^.status <> C_Status.RUNNING then
    cr^.hpCur := 0;
  CbtMap.UpdateCombatMapTile(0, 0, id);
  Blit.FlushView;
  GDVars.arenaLoc[id].size := 0;
  CbtMap.BuildArenaArrays;
  if CharHlp.EndActions(cr) then
    FxEngine.RemoveEffectsHp0(cr);
end;

procedure RemoveInvisibility(cr: Types.PCharRecord);
var
  eff: Types.PEffectRec;
begin
  while CharHlp.HasEffect(cr, C_Effect.INVISIBLE, eff) do
    FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, eff);
end;

procedure RemoveEffectsHp0(cr: Types.PCharRecord);
var
  i: Byte;
  eff: Types.PEffectRec;
begin
  for i := 1 to 14 do
    FxEngine.RemoveEffect(cr, GDConsts.hpZeroEffects[i], nil);
  if CharHlp.HasEffect(cr, 77, eff) then
    if cr^.npc = $B3 then
      cr^.hostileV1 := 0;
end;

procedure RemoveAiEffects(cr: Types.PCharRecord);
var
  { Unused in this version; see the other implementations of this routine. }
  effectIndex: Integer;
begin
end;

function RemoveEffectWithMessage(cr: Types.PCharRecord; effId: Byte): Boolean;
var
  eff: Types.PEffectRec;
begin
  RemoveEffectWithMessage := False;
  if CharHlp.HasEffect(cr, effId, eff) then begin
    FxEngine.RemoveEffect(cr, effId, eff);
    RemoveEffectWithMessage := True;
  end;
end;

function StrengthModifier(baseStr, excStr: Byte): Byte;
begin
  StrengthModifier := baseStr + 100;
  if baseStr = 18 then
    StrengthModifier := excStr + 1;
end;

procedure StrengthEffectToStrength(eff: Types.PEffectRec; var baseStr, excStr: Byte);
begin
  excStr := 0;
  baseStr := eff^.strength and $7F;
  if baseStr <= 101 then begin
    excStr := baseStr - 1;
    baseStr := 18;
  end else
    baseStr := baseStr - 100;
end;

function AdjustForNewStrength(cr: Types.PCharRecord; baseStr, excStr: Byte; var out: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  found: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  oldBase: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldExc: Byte;
begin
  if (baseStr > cr^.attrs[C_Stat.STRENGTH].base) or ((baseStr = 18) and (excStr > cr^.strExcCur)) then begin
    AdjustForNewStrength := True;
    out := FxEngine.StrengthModifier(baseStr, excStr);
  end else
    AdjustForNewStrength := False;
end;

procedure RecalcAbility(cr: Types.PCharRecord; mode: ShortInt);
var
  curBase: Byte;
  newBase: Byte;
  curExc: Byte;
  newExc: Byte;
  eff: Types.PEffectRec;
  savedHpMax: Byte;
  hpAcc: Byte;
  statVal: Byte;
  i: Byte;
  item: Types.PItemRec;
  override: Byte;
  itemVal: Byte;
  classes: Byte;

  { Raises the strength being built to the candidate when higher, comparing exceptional strength only at 18. }
  procedure StrClamp;
  begin
    if (newBase > curBase) or ((newBase = 18) and (newExc > curExc)) then begin
      curBase := newBase;
      curExc := newExc;
    end;
  end;

  { Adds to hpAcc class idx's Constitution hit-point bonus of curBase for its bonus levels, below the class cap. }
  procedure StatBonus(idx, bonus: Byte);
  begin
    if GDConsts.firstFixedHpLevel[ShortInt(idx)] <= bonus then
      bonus := GDConsts.firstFixedHpLevel[ShortInt(idx)] - 1;
    if idx = C_Class.RANGER then
      if (cr^.dualClassThresholdV1 = 0) or (Byte(cr^.oldClassLevelsV1[4]) = cr^.dualClassThresholdV1) then
        Inc(bonus);
    if (idx = C_Class.FIGHTER) or (idx = C_Class.PALADIN) or (idx = C_Class.RANGER) then begin
      case curBase of
        15..19: Inc(hpAcc, (curBase - 14) * bonus);
        20: Inc(hpAcc, bonus * 5);
        21..23: Inc(hpAcc, bonus * 6);
        24..25: Inc(hpAcc, bonus * 7);
      end;
    end else begin
      if curBase > 15 then
        Inc(hpAcc, bonus * 2)
      else if curBase = 15 then
        Inc(hpAcc, bonus);
    end;
  end;

begin
  hpAcc := 0;
  newBase := 0;
  newExc := 0;
  override := 255;
  item := cr^.itemsAddr;
  curBase := cr^.attrs[mode].base;
  curExc := cr^.strExcCur;
  while item <> nil do begin
    if (item^.attrVal > $80) and (item^.equipped <> 0) then begin
      itemVal := item^.attrVal and $7F;
      case mode of
        C_Stat.STRENGTH:
          begin
            case itemVal of
              3:
                begin
                  newBase := 18;
                  newExc := 100;
                end;
              5:
                case item^.attrSel of
                  0: begin newBase := 18; newExc := 100; end;
                  1: newBase := 19;
                  2: newBase := 20;
                  3: newBase := 21;
                  4: newBase := 22;
                  5: newBase := 23;
                  6: newBase := 24;
                end;
              8:
                if (cr^.attrs[C_Stat.STRENGTH].base < 18) and (item^.attrSel = 0) then begin
                  newBase := cr^.attrs[C_Stat.STRENGTH].base + 1;
                  newExc := 0;
                end;
              13:
                override := 3;
            end;
            StrClamp;
          end;
        C_Stat.CONSTITUTION:
          if itemVal = 6 then
            Inc(curBase)
          else if itemVal = 8 then
            if (cr^.attrs[C_Stat.CONSTITUTION].base < 18) and (item^.attrSel = 4) then
              Inc(curBase);
        C_Stat.INTELLIGENCE:
          case itemVal of
            8:
              if (cr^.attrs[C_Stat.INTELLIGENCE].base < 18) and (item^.attrSel = 1) then
                Inc(curBase);
            12: override := 7;
            13: override := 3;
          end;
        C_Stat.WISDOM:
          if itemVal = 8 then
            if (item^.attrSel = 2) and (cr^.attrs[C_Stat.WISDOM].base < 18) then
              Inc(curBase);
        C_Stat.DEXTERITY:
          case itemVal of
            2:
              case cr^.attrs[C_Stat.DEXTERITY].base of
                0..6: Inc(curBase, 4);
                7..13: Inc(curBase, 2);
              else
                Inc(curBase);
              end;
            8:
              if (cr^.attrs[C_Stat.DEXTERITY].base < 18) and (item^.attrSel = 3) then
                Inc(curBase);
            10:
              Dec(curBase, 2);
          end;
        C_Stat.CHARISMA:
          case itemVal of
            6: Dec(curBase);
            8: if (cr^.attrs[C_Stat.CHARISMA].base < 18) and (item^.attrSel = 5) then
                 Inc(curBase);
          end;
      end;
    end;
    item := item^.next;
  end;
  case mode of
    C_Stat.STRENGTH:
      begin
        if CharHlp.HasEffect(cr, C_Effect.STRENGTH, eff) then begin
          FxEngine.StrengthEffectToStrength(eff, newBase, newExc);
          if (curBase <= 18) and (curExc < 100) then begin
            newBase := curBase + newBase;
            if newBase > 18 then begin
              if (cr^.classLevelsV1[2] > 0) or (cr^.oldClassLevelsV1[2] > 0) or
                  (cr^.classLevelsV1[3] > 0) or (cr^.oldClassLevelsV1[3] > 0) or
                  (cr^.classLevelsV1[4] > 0) or (cr^.oldClassLevelsV1[4] > 0) then begin
                newExc := cr^.strExc + (newBase - 18) * 10;
                if newExc > 100 then
                  newExc := 100;
                newBase := 18;
              end else
                newBase := 18;
            end;
          end;
          StrClamp;
        end;
        if CharHlp.HasEffect(cr, 113, eff) then begin
          newBase := 21;
          StrClamp;
        end;
        if CharHlp.HasEffect(cr, C_Effect.ENLARGE, eff) then begin
          FxEngine.StrengthEffectToStrength(eff, newBase, newExc);
          StrClamp;
        end;
        if override <> 255 then begin
          cr^.attrs[C_Stat.STRENGTH].cur := override;
          cr^.strExc := 0;
        end else begin
          cr^.attrs[C_Stat.STRENGTH].cur := curBase;
          cr^.strExc := curExc;
        end;
      end;
    C_Stat.CONSTITUTION:
      begin
        classes := 0;
        savedHpMax := cr^.hpMax;
        cr^.hpMax := cr^.hpRolled;
        for i := C_Class.CLERIC to C_Class.THIEF do begin
          statVal := cr^.oldClassLevelsV1[ShortInt(i)];
          if statVal > 0 then
            StatBonus(i, statVal);
          statVal := cr^.classLevelsV1[ShortInt(i)];
          if statVal > 0 then
            Inc(classes);
          if GDConsts.firstFixedHpLevel[ShortInt(i)] < statVal then
            statVal := GDConsts.firstFixedHpLevel[ShortInt(i)];
          if statVal > cr^.dualClassThresholdV1 then begin
            Dec(statVal, cr^.dualClassThresholdV1);
            StatBonus(i, statVal);
          end;
        end;
        hpAcc := hpAcc div classes;
        Inc(cr^.hpMax, hpAcc);
        if cr^.hpMax > savedHpMax then
          Inc(cr^.hpCur, cr^.hpMax - savedHpMax);
        if cr^.hpMax < savedHpMax then begin
          if cr^.hpCur > savedHpMax - cr^.hpMax then
            Dec(cr^.hpCur, savedHpMax - cr^.hpMax)
          else
            cr^.hpCur := 0;
        end;
        cr^.attrs[C_Stat.CONSTITUTION].cur := curBase;
        if cr^.attrs[C_Stat.CONSTITUTION].cur >= 20 then
          FxEngine.AddEffect(cr, 62, 60, 255, 1)
        else
          FxEngine.RemoveEffect(cr, 62, nil);
      end;
    C_Stat.INTELLIGENCE:
      begin
        if CharHlp.HasEffect(cr, C_Effect.FEEBLEMINDED, eff) then
          if override > 7 then
            override := 3;
        if override <> 255 then
          cr^.attrs[C_Stat.INTELLIGENCE].cur := override
        else
          cr^.attrs[C_Stat.INTELLIGENCE].cur := curBase;
      end;
    C_Stat.WISDOM:
      begin
        if CharHlp.HasEffect(cr, C_Effect.FEEBLEMINDED, eff) then
          if override > 7 then
            override := 3;
        if override <> 255 then
          cr^.attrs[C_Stat.WISDOM].cur := override
        else
          cr^.attrs[C_Stat.WISDOM].cur := curBase;
      end;
    C_Stat.DEXTERITY:
      begin
        if override <> 255 then
          cr^.attrs[C_Stat.DEXTERITY].cur := override
        else
          cr^.attrs[C_Stat.DEXTERITY].cur := curBase;
      end;
    C_Stat.CHARISMA:
      begin
        if CharHlp.HasEffect(cr, 14, eff) then
          Inc(curBase, eff^.strength);
        cr^.attrs[C_Stat.CHARISMA].cur := curBase;
      end;
  end;
end;

procedure InflictNonWeaponDamage(cr: Types.PCharRecord; damage, saveReduction: Byte; saved: Boolean);
var
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  endRes: Boolean;
begin
  GDVars.pendingDamage := damage;
  FxEngine.TriggerEffectsWithCondition(6, cr);
  if saved then begin
    case saveReduction of
      1: GDVars.pendingDamage := 0;
      2: GDVars.pendingDamage := GDVars.pendingDamage div 2;
    end;
  end else
    FxEngine.TriggerEffectsWithCondition(20, cr);
  if GDVars.pendingDamage <= 0 then
    Exit;
  if cr^.enabled = 0 then
    Exit;
  if GDVars.pendingDamage <> 1 then
    msg := 'takes ' + CharHlp.Uint8Str(GDVars.pendingDamage) + ' points of damage '
  else
    msg := 'takes 1 point of damage ';
  case GDVars.elemMask and $F7 of
    1: msg := msg + 'from Fire';
    2: msg := msg + 'from Cold';
    4: msg := msg + 'from Electricity';
    $10: msg := msg + 'from Acid';
  end;
  if (GDVars.elemMask and 8) = GDVars.elemMask then
    msg := msg + 'from Magic';
  CharHlp.PrintNameStringAnim(cr, 0, msg);
  CharHlp.InflictDamage(cr, GDVars.pendingDamage);
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    cr^.combatAddr^.spellsAllowed := 0;
    if cr^.combatAddr^.slot > 0 then begin
      CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(cr, cr^.combatAddr^.slot);
      endRes := CharHlp.EndActions(cr);
    end;
  end;
  if cr^.enabled = 0 then begin
    msg := 'Goes Down';
    if cr^.status = C_Status.DYING then
      msg := msg + ', and is Dying';
    if cr^.status in [C_Status.DEAD_STATUS, C_Status.PETRIFIED, C_Status.GONE] then
      msg := 'is killed';
    CharHlp.PrintCreatureMessage(cr, msg, GDVars.curRow + 1, False);
    if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
      TextRend.PauseOnly
    else begin
      FxEngine.RemoveEffectsHp0(cr);
      FxEngine.TriggerEffectsWithCondition(13, cr);
      { status 10 is off statusNames' 0..8 axis and has no name }
      if (cr^.enabled = 0) and (cr^.status <> 10) then
        CbtMap.CreatureDowned(cr)
      else
        TextRend.PauseOnly;
    end;
  end;
  CharHlp.ClearMessageWindow;
end;

procedure AddEffectWithMessage(cr: Types.PCharRecord; effId: Byte; minutes: Word; strength, onRemove, saveNegates: Byte;
                               saved: Boolean; msg: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  existingEffect: Pointer;
  eff: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
begin
  GDVars.currentEffectId := effId;
  FxEngine.TriggerEffectsWithCondition(9, cr);
  if (GDVars.currentEffectId = 0) or (saved and (saveNegates = 1)) then
    CharHlp.PrintCreatureMessage(cr, 'is Unaffected', 10, True)
  else begin
    if CharHlp.HasEffect(cr, GDVars.currentEffectId, eff) then begin
      if eff^.minutes <> 0 then
        if minutes > eff^.minutes then
          eff^.minutes := minutes;
    end else
      FxEngine.AddEffect(cr, effId, minutes, strength, onRemove);
    if Length(msg) <> 0 then begin
      CharHlp.PrintNameStringAnim(cr, 1, msg);
      CharHlp.ClearMessageWindow;
    end;
  end;
end;

function RestoreHitPoints(cr: Types.PCharRecord; hp, bypassRot: Byte): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  RestoreHitPoints := False;
  if cr^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS,
                    C_Status.DYING] then begin
    if ((cr^.hpCur < cr^.hpMax) and (bypassRot <> 0)) or (bypassRot = 0) then begin
      cr^.hpCur := cr^.hpCur + hp;
      if cr^.hpCur > cr^.hpMax then
        cr^.hpCur := cr^.hpMax;
      if cr^.enabled = 0 then begin
        if cr^.status = C_Status.DYING then
          cr^.status := C_Status.UNCONSCIOUS;
        if (cr^.status = C_Status.UNCONSCIOUS) and (GDVars.interfaceState <> C_Ifc.IN_COMBAT) then begin
          cr^.status := C_Status.OKAY;
          cr^.enabled := 1;
        end;
      end;
      RestoreHitPoints := True;
    end;
  end;
end;

procedure NoopFxEngine;
begin
end;

begin
end.
