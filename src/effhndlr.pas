{ Persistent and combat effect dispatch: the effect handlers and their helpers. InitEffectHandlers installs the handlers
  into the dispatch table the effects engine uses. Handlers take (var cr: PCharRecord; p: Pointer; removed: Boolean). }
{$O+,F+}
unit EffHndlr;

interface

uses Types, ViewChar, FxEngine, CharHlp, ClassCal, Pathing, CbtMap, Blit, TextRend, GameIo, SoundDrv, Crt, GDConsts,
  GDVars, C_Race, C_Align, C_Status, C_Effect, C_Ifc, C_Dir, C_Stat, C_Save;

{ Fills the effect handler table with the handler of each effect, and sets the override handler used for items
  (EffGrantItemEffect). }
procedure InitEffectHandlers;

{ Paralyzes the creature's combat target (effect 52) unless it makes a paralyzation save modified by saveMod, with a
  'paralyzed by poison' message. Note: duration is never used, so the paralysis always lasts the same time.
  @param(cr The attacking creature.)
  @param(duration Unused.)
  @param(saveMod Modifier to the target's save.) }
procedure ParalyzeTarget(var cr: Types.PCharRecord; duration: Word; saveMod: Byte);

{ Cancels the pending effect and the damage when the given effect is 0 or is the effect being applied.
  @param(effectId The effect to cancel, or 0 for whichever effect is pending.) }
procedure NullifyAttack(effectId: Byte);

{ Adds an effect, removed through its handler, unless the effect lock is set.
  @param(cr The creature given the effect.)
  @param(effectId The effect.)
  @param(strength Its strength.)
  @param(duration Its duration.)
  @returns(True when the effect was added.) }
function AddEffectIfNoLock(var cr: Types.PCharRecord; effectId, strength: Byte; duration: Word): Boolean;

{ Marks the arena cells each cloudkill (terrain 27), stinking cloud (29) and delayed blast fireball (26) in the cloud
  lists still covers. }
procedure MarkCloudCells;

{ Ends the creature's actions for the round.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffEndActions(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Adds 1 to the saving throw and to the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure AddRollBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the bless effect: adds 5 to morale and 1 to the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBless(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the curse effect: takes 5 from morale (not below 0) and 1 from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies sticks to snakes: the snakes use up the creature's attacks this round, taking them off the effect's strength
  (the effect ends when it runs out); the creature is shown fighting with snakes and its actions end.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffSticksToSnakes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Dispel Evil: takes 7 from the attack roll when the current creature has creature-type flag bit 0, except on
  removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDispelEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 6: cancels the effect and the damage of electrical attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneElectricity(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 7: adds 1 to the attack roll against a combat target with target flag bit 2, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffTypeHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies protection from evil: against an evil attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies protection from good: against a good attacker (the current character) adds 2 to the saving throw and takes 2
  from the attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtGood(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies resist cold: halves cold damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies charm: the first time (strength bit 5 marks it), saves the creature's side in strength bit 6, moves it to the
  side in bit 7, makes it a quick fighter (NPC value $B3 unless the value is above $7F), drops its target and recounts
  the sides; each call except a removal sets morale to 100. On removal the saved side returns and the NPC value $B3 is
  cleared.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffCharm(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing for the enlarge and strength effects.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffStrengthBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Barkskin: adds 1 to the saving throw unless the attack carries element bit 3, and takes 1 from the attack
  roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBarkskin(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing for the friends effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffFriends(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the poison that slow poison holds back: except on removal, every ten minutes, unless the effect lock is set,
  renews itself and costs the creature 1 hit point while it has more than 1, redrawing its roster line outside combat.
  Note: the effect it renews is the dwarf's attack bonus, not itself.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonHit(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing for the read magic effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffReadMagic(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies shield: raises the creature's armor class value to at least 57 (armor class 3), adds 1 to the saving throw,
  and stops Magic Missile, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffShield(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 18: a half-elf's 30 percent chance to resist charm (effect 11) and sleep (effect 53), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHalfElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies resist fire: halves fire damage and adds 3 to the saving throw against it, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffResistFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 21 (Silence): the creature can neither cast nor use items this round, with a message the first time, except on
  removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSilence(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 22 (the end of Slow Poison): a poisoned creature dies from the poison, and the held-back poison (effect 15) is
  removed under the effect lock, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowPoisonEnd(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 23 (Spiritual Hammer): gives the creature the hammer item (type 6, name 121, +1, effect 23) when it is missing
  and there is room (under 16 items), readying it when no weapon is readied, with a message; on removal the hammer is
  taken away. The creature's stats are recalculated either way. Note: the search after adding the hammer steps past the
  item it finds, so it readies the item after the hammer, if any.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpiritualHammer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies invisibility: unless the current character can see invisible, it may not target the creature and takes 4 from
  its attack roll, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisible(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the dwarf's attack bonus: adds 1 to the attack roll against a combat target with creature-type flag bit 7,
  except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrA;

{ Applies mirror image: unless the dice pick the creature itself (1 in images + 1), an attack or single-target offensive
  spell is cancelled and an image is lost; losing the last ends the effect. The image count is the high nibble of the
  effect's strength. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffMirrorImage(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies ray of enfeeblement: takes a quarter off the pending damage, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffEnfeeble(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 30 (coughing in a stinking cloud): the creature can neither cast nor use items this round, with an 'is
  coughing' message the first time, and its armor class becomes its rear armor class less 2, at least 50; the panel is
  redrawn for the current character. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffCoughing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 32: an evil-type combat target (creature-type flag bit 0) that fails a spell save is dispelled (GONE) and the
  creature's Dispel Evil effects (4 and 32) end; otherwise the target resists. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDispelEvilTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies blindness: takes 4 from the attack roll, the saving throw and both armor classes, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies disease: runs the strength-loss and hit-point-loss disease handlers, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseased(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies confusion: rolls d100: on 1..10 the creature runs away (forced to flee under AI control with the fear effect,
  the confusion ending), on 11..60 it is confused and its actions end, on 61..80 it goes berserk, and on 81..100 it is
  enraged. A spell save at -2 then ends the confusion. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusion(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies bestow curse: takes 4 from the attack roll and the saving throw, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBestowCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Blink effect: when the creature has no initiative left, it cannot be targeted and the attack misses, except on
  removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBlinking(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Haste effect: ages the creature a year the first time (strength bit 4 marks it, and aging is noted for after the
  battle) and doubles its movement and attacks, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffHasted(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 40: clears the creature's stinking cloud whose number is the high nibble of the effect's strength: restores the
  covered cells (a corpse cell where a body lies), frees the cloud and redraws the cloud cells, with 'The air clears a
  little...'. Note: a body's cell becomes stone or corpse by the cloud owner's status, not the body's.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffClearStinkingCloud(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Lets a creature avoid a missile: when the current character has a readied weapon and stands more than one cell away, a
  d100 roll within the chance cancels the damage, makes the attack miss and takes the hit back, with 'Avoids it'.
  @param(cr The creature attacked.)
  @param(a The chance in percent.) }
procedure AvoidMissile(var cr: Types.PCharRecord; a: Byte);

{ Finds the item a creature attacks with: the missile its readied weapon fires or throws, else the readied weapon.
  @param(cr The creature.)
  @returns(The item, or nil with no weapon readied.) }
function FindDamagingWeapon(cr: Types.PCharRecord): Types.PItemRec;

{ Effect 41 (Protection from Normal Missiles): avoids every missile from a nonmagical weapon (AvoidMissile at 100),
  except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffProtNormalMissiles(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies Slow: halves the movement and attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSlowed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 43 (disease): every hour, unless the effect lock is set, renews itself and weakens the creature by 1 Strength
  down to 3, then leaves it helpless. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseaseStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 44 (disease): every ten minutes, unless the effect lock is set, renews itself and costs the creature 1 hit
  point while it has more than 1, redrawing its roster line outside combat, then leaves it helpless. Nothing happens on
  removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDiseaseHitPoints(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Dwarf's defense against giants: takes 4 from the attack roll of an attacker (the current character) with creature-type
  flag bit 2, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDwarfGiantDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the gnome's defensive bonus: takes 4 from the attack roll of an attacker (the current character) with
  creature-type flag bit 5, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGnomeBugDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 49 (Prayer): adds 1 to the attack roll and saving throw of a creature on the side in strength bit 4, and takes
  1 from them for the other side, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffPrayer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 50: against a cold attack adds 2 to the saving throw; a fire attack whose save failed does double damage.
  Nothing happens on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFireVulnerable(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 54: against a fire attack adds 2 to the saving throw; a cold attack does double damage. Nothing happens on
  removal. Note: the doubling tests GDVars.gameSaved instead of the save result.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffColdVulnerable(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing for the poisoned effect.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffPoisoned(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 56: renews the creature's invisibility (effect 25); on removal in combat the invisibility ends.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRenewInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 57 (Globe of Invulnerability): cancels spells of level 4 or lower, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGlobeOfInvulnerability(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 58 (petrifying gaze): picks a target for spell 61; an enemy target the gaze reaches ('gazes...') is turned to
  stone unless it makes a petrification save. A creature with effect 59 has its gaze reflected by a target with effect
  72, and then makes the save itself. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPetrifyingGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoneB(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 60: cancels the damage of an attack without a weapon of +3 or better, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffNeedMagicWeapon(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the ring of fire resistance: against fire takes 2 off the damage per die (to no less than one per die) and
  adds 4 to the saving throw, cancelling the attack unless it carries element bit 3, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRingFireRes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 62 (Regeneration): every hour, unless the effect lock is set, renews itself and restores 1 hit point,
  announcing it. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffRegeneration(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 63 (Minor Globe of Invulnerability): cancels spells of level 3 or lower, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffMinorGlobe(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target (effect 55) unless it makes a paralyzation save modified by dmg, which the
  strength of the target's effect 64 raises (a negative dmg drops to 0 instead); a target left poisoned is killed.
  @param(cr The attacking creature.)
  @param(dmg The save modifier.) }
procedure PoisonTarget(var cr: Types.PCharRecord; dmg: ShortInt);

{ Poisons the creature's combat target on a hit, with no save modifier; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 65: turns the creature's combat target to stone unless it makes a petrification save, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFleshToStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 66 (swallow whole): on an attack roll of 75 or more the creature's combat target is swallowed: it dies and
  loses its hit-point-0 effects, its icon flashes away, a party-side victim leaves a body at the swallower's cell, the
  swallower belches or the victim is digested, and the victim's actions end. Nothing happens on removal. Note: the check
  for an already recorded body tests downed[frame] with frame not yet set.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSwallowWhole(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 67 (fire breath): after the first round, while the creature has at least as many attacks as rounds have passed,
  breathes fire at an adjacent combat target through FxEngine.InflictNonWeaponDamage, with a breath-weapon save. Nothing
  happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBreatheFireAdjacent(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 68 (Feeblemind): sets the creature's Intelligence and Wisdom to 3 ('is made stupid'); in combat it can no
  longer cast this round and loses a spell it is casting. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFeeblemind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 69 (Invisibility to Animals): a creature with any of creature-type flag bits 0, 2 and 6 and without effect 24
  cannot be targeted, and the attack roll loses 4, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffInvisibleToAnimals(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 70: picks a target for spell 68 and, when it is adjacent, gazes at it ('gazes...'); a target failing a spell
  save is confused (effect 35) for 1d10 + 2 rounds ('stares blankly'). Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffReflectSpell(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 71 (Faerie Fire): worsens both armor classes by 2, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFaerieFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoneC(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies breath immunity: cancels attacks carrying element bit 5 (breath), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneBreath(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 74 (boots of speed): improves both armor classes by 2, except on removal; CharHlp.RecalcMovement doubles the
  movement for it. Note: it also doubles a local that was never set.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBootsOfSpeed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 75 (holy water): against a combat target with target flag bit 0 the damage becomes 6d6 plus the Strength damage
  bonus and the attack roll gains 1, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHolyWater(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 76: empty.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNoneD(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies berserk: the creature fights under AI control (NPC value $B3, or $B2 for an NPC above $7F other than $B3); in
  combat it drops its target, takes the second creature of a full target list instead, may not cast, and joins the side
  opposed to that target, with a 'goes berserk' message. On removal a $B3 creature leaves AI control and the creature
  returns to the party's side.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 78: adds 1 to the saving throw, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSaveBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the iron golem's immunity: a fire attack with element bit 3 heals the creature by the damage (to its maximum),
  an electrical attack slows it, and each attack is cancelled, on removal too.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffIronGolem(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 80 (fire breath): picks a target for spell 68, turns toward it and breathes fire at it through
  FxEngine.InflictNonWeaponDamage, with a breath-weapon save. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffBreatheFireAtTarget(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 81 (spit): picks a target for spell 61 and spits at it with a chance of 10 percent per cell inside 11 (10
  percent in the first round): a hit does 4d8 through FxEngine.InflictNonWeaponDamage, with a breath-weapon save;
  otherwise it 'Spits and misses'. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffSpitAtTarget(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 82 (dragon fear): each creature of the other side below level 5 without effect 92 or 111 is terrified (effect
  111): it flees under AI control and drops its target. Nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffDragonFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Poisons the creature's combat target on a hit, with a save modifier of -2; nothing happens on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffStrongPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 88 (ghoul touch): paralyzes the creature's combat target (ParalyzeTarget) unless it makes a paralyzation save,
  except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGhoulPara(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies displacement: except on removal, the first attack on the creature misses (the attack roll becomes -1) and
  strength bit 4 marks it used; the mark is cleared only in round 0 on a zero attack roll.
  @param(cr Unused.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDisplaced(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 90: cancels the damage of a weapon of weapon class bit 7 (a bashing weapon), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffHalfBash(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 91: clears the creature's cloudkill whose number is the high nibble of the effect's strength: restores the nine
  covered cells (a corpse cell where a body lies), frees the cloud and redraws the cloud cells, with 'The air clears a
  little...'. Note: a body's cell becomes stone or corpse by the cloud owner's status, not the body's.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed Unused.) }
procedure EffClearCloudkill(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies fear immunity: cancels fear, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 93: cancels fire attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies the Constitution saving-throw bonus: adds 1 to 5 to a spell, paralyzation or type-2 saving throw, rising with
  Constitution from 4 to 20, except on removal. Note: other Constitution values add whatever the local held.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConPsnSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 95: an elf's 90 percent chance to resist charm (effect 11) and sleep (effect 53), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 96: cancels charm (effect 11) and sleep (effect 53), except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneSleepCharm(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Constitution save bonus: adds 1 to 5, rising with Constitution from 4 to 20, to a saving throw against spells or
  wands, except on removal. Note: other Constitution values add an unset value.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffConSpellSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 98: cancels cold attacks, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 99: cancels poison (effect 55) and paralysis (effect 52), and makes a paralyzation saving throw certain, except
  on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffImmuneParalysisPoison(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 100 (Delayed Blast Fireball): when the effect is removed in combat, the creature's matching blast goes off:
  everything within 3 cells of its cell takes the caster's magic-user level plus that many d6 of fire, with a spell
  save, after the explosion animation; the blast's cell is restored and the blast freed.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffDelayedBlastFireball(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 103: cancels the damage of an attacker (the current character) without a magic weapon when it is a playable
  race or below level 4, except on removal.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffWeaponResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 105 (the ranger's bonus): adds the creature's ranger level to the damage against an adjacent combat target with
  creature-type flag bit 3, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRangerDamageBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Helpless effect: ends the creature's actions for the round.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffHelpless(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies berserk from confusion: the creature fights under AI control (NPC value $B3, or $B2 for an NPC above $7F other
  than $B3), takes the second creature of a full target list as its target and joins the side opposed to it. On removal
  a $B3 creature's NPC value is cleared and its side comes from the effect's strength.
  @param(cr The creature carrying the effect.)
  @param(p The effect's node.)
  @param(removed True when the effect is being removed.) }
procedure EffConfusedBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Effect 108: gives the creature lasting invisibility (effect 25), except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffLastingInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Empty routine with no callers. }
procedure NoopEffHndlrB;

{ Effect 110: when it is removed, the paladin's cure disease uses come back: one plus one per five levels above the
  first.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffRecentCure(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies fear: on removal a $B3 creature leaves AI control and the creature is no longer forced to flee.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Zaps an adjacent attacker (the current character), except on removal: it 'gets zapped' for twice the pending damage,
  when that is above 0, as magic damage (element bit 3).
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffZapAttacker(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Applies giant strength: announces that the creature gains it, except on removal.
  @param(cr The creature carrying the effect.)
  @param(p Unused.)
  @param(removed True when the effect is being removed.) }
procedure EffGiantStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Does nothing.
  @param(cr Unused.)
  @param(p Unused.)
  @param(removed Unused.) }
procedure EffNone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

{ The override handler for item effects: adds the item's effect to the creature, or on removal removes it, and clears
  the override flag.
  @param(cr The creature.)
  @param(p The item whose effect is granted.)
  @param(removed True when the item's effect is being removed.) }
procedure EffGrantItemEffect(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);

implementation

const
  { TCharRecord.alignment }
  ALIGN_LAWFUL_EVIL = 2;
  ALIGN_NEUTRAL_EVIL = 5;
  ALIGN_CHAOTIC_EVIL = 8;
  { TCharRecord.saves: petrification / polymorph }
  SAVE_PETRIFY = 1;
  { without it an attacker takes -4 against an invisible target }
  SEE_INVISIBLE = 24;
  { removed when the last image is lost ('lost an image') }
  MIRROR_IMAGE = 28;
  { disease: lowers strength ('weakened') }
  DISEASE_STRENGTH = 43;
  { disease: dispatched together with DISEASE_STRENGTH }
  DISEASE_HIT_POINTS = 44;

type
  { The effect node p, every handler's second formal, points at. }
  PEffData = ^TEffData;
  TEffData = record
    id: Byte;
    val: Word;
    strength: Byte;
    onRemove: Byte;
    next: PEffData;
  end;

procedure ParalyzeTarget(var cr: Types.PCharRecord; duration: Word; saveMod: Byte);
var
  r: Boolean;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  r := FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.PARALYZATION, saveMod);
  FxEngine.AddEffectWithMessage(GDVars.combatTarget, 52, 10, 12, 0, 1, r, 'paralyzed by poison');
end;

procedure NullifyAttack(effectId: Byte);
begin
  if (effectId = 0) or (GDVars.currentEffectId = effectId) then begin
    GDVars.pendingDamage := 0;
    GDVars.currentEffectId := 0;
  end;
end;

function AddEffectIfNoLock(var cr: Types.PCharRecord; effectId, strength: Byte; duration: Word): Boolean;
begin
  if GDVars.effectLock <> 0 then
    AddEffectIfNoLock := False
  else begin
    AddEffectIfNoLock := True;
    FxEngine.AddEffect(cr, effectId, duration, strength, 1);
  end;
end;

procedure MarkCloudCells;
var
  a: Types.PCloudNode;
  b: Types.PCloudNode;
  c: Types.PCloudNode;
  i: Byte;
begin
  a := GDVars.cloudkillHead;
  while a <> nil do begin
    for i := 1 to 9 do
      if a^.live[i] <> 0 then
        GDVars.arenaPtr^.cells[a^.y + GDConsts.dirDy[GDConsts.cloudDirs9[i]], a^.x +
                                                                      GDConsts.dirDx[GDConsts.cloudDirs9[i]]] := 27;
    a := a^.next;
  end;
  b := GDVars.stinkHead;
  while b <> nil do begin
    for i := 1 to 4 do
      if b^.live[i] <> 0 then
        GDVars.arenaPtr^.cells[b^.y + GDConsts.dirDy[GDConsts.cloudDirs[i]], b^.x +
                                                                     GDConsts.dirDx[GDConsts.cloudDirs[i]]] := 29;
    b := b^.next;
  end;
  c := GDVars.blastHead;
  while c <> nil do begin
    if c^.live[1] <> 0 then
      GDVars.arenaPtr^.cells[c^.y, c^.x] := 26;
    c := c^.next;
  end;
end;

procedure EffEndActions(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  done := CharHlp.EndActions(cr);
end;

procedure AddRollBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.saveRoll);
    Inc(GDVars.attackRoll);
  end;
end;

procedure EffBless(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Inc(GDVars.morale, 5);
    Inc(GDVars.attackRoll);
  end;
end;

procedure EffCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if GDVars.morale < 5 then
      GDVars.morale := 0
    else
      Dec(GDVars.morale, 5);
    Dec(GDVars.attackRoll);
  end;
end;

procedure EffSticksToSnakes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  total: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  total := cr^.curAtt[1] + cr^.curAtt[2];
  if PEffData(p)^.strength > total then
    Dec(PEffData(p)^.strength, total)
  else
    FxEngine.RemoveEffect(cr, 3, nil);
  CharHlp.PrintNameStringAnim(cr, 1, 'is fighting with snakes');
  CharHlp.ClearMessageWindow;
  done := CharHlp.EndActions(cr);
end;

procedure EffDispelEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.creatureTypeFlags and 1) <> 0 then
      Dec(GDVars.attackRoll, 7);
end;

procedure EffImmuneElectricity(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.elemMask and 4) <> 0 then
      EffHndlr.NullifyAttack(0);
end;

procedure EffTypeHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  bonus: Integer;
begin
  if not removed then begin
    GDVars.combatTarget := cr^.combatAddr^.other;
    if (GDVars.combatTarget^.targetFlags and 4) <> 0 then
      Inc(GDVars.attackRoll);
  end;
end;

procedure EffProtEvil(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.alignment = EffHndlr.ALIGN_LAWFUL_EVIL) or
        (GDVars.curChar^.alignment = EffHndlr.ALIGN_NEUTRAL_EVIL) or
        (GDVars.curChar^.alignment = EffHndlr.ALIGN_CHAOTIC_EVIL) then begin
      Inc(GDVars.saveRoll, 2);
      Dec(GDVars.attackRoll, 2);
    end;
end;

procedure EffProtGood(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.curChar^.alignment = C_Align.LAWFUL_GOOD) or (GDVars.curChar^.alignment = C_Align.NEUTRAL_GOOD)
       or (GDVars.curChar^.alignment = C_Align.CHAOTIC_GOOD) then begin
      Inc(GDVars.saveRoll, 2);
      Dec(GDVars.attackRoll, 2);
    end;
end;

procedure EffResistCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.elemMask and 2) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.saveRoll, 3);
    end;
end;

procedure EffCharm(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    cr^.hostile := (PEffData(p)^.strength and $40) div $40;
    if cr^.npc = $B3 then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
  end else begin
    if (PEffData(p)^.strength and $20) = 0 then begin
      PEffData(p)^.strength := PEffData(p)^.strength + $20 + (cr^.hostile shl 6);
      cr^.hostile := PEffData(p)^.strength div $80;
      cr^.quickfight := 1;
      if cr^.npc <= $7F then
        cr^.npc := $B3;
      cr^.combatAddr^.other := nil;
      CharHlp.CountTeams;
    end;
    GDVars.morale := 100;
  end;
end;

procedure EffStrengthBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffBarkskin(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if (GDVars.elemMask and 8) = 0 then
      Inc(GDVars.saveRoll);
    Dec(GDVars.attackRoll);
  end;
end;

procedure EffFriends(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffSlowPoisonHit(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if EffHndlr.AddEffectIfNoLock(cr, 26, PEffData(p)^.strength, 10) then
      if cr^.hpCurrent > 1 then begin
        GDVars.elemMask := 0;
        FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
        if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
          CharHlp.DisplayParty(cr, cr = GDVars.curChar);
      end;
end;

procedure EffReadMagic(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffShield(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if cr^.acCurArr[0] < 57 then
      cr^.acCurArr[0] := 57;
    Inc(GDVars.saveRoll);
    if GDVars.spellId = 15 then
      GDVars.pendingDamage := 0;
  end;
end;

procedure EffHalfElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if FxEngine.RollDice(1, 100) <= 30 then begin
      EffHndlr.NullifyAttack(11);
      EffHndlr.NullifyAttack(53);
    end;
end;

procedure EffResistFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if (GDVars.elemMask and 1) <> 0 then begin
      GDVars.pendingDamage := GDVars.pendingDamage div 2;
      Inc(GDVars.saveRoll, 3);
    end;
end;

procedure EffSilence(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if cr^.combatAddr^.itemUseAllowed <> 0 then
      CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + GDConsts.effectNames[21], 10, True);
    cr^.combatAddr^.itemUseAllowed := 0;
    cr^.combatAddr^.spellsAllowed := 0;
  end;
end;

procedure EffSlowPoisonEnd(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Types.PEffectRec;
begin
  if not removed then begin
    if CharHlp.HasEffect(cr, C_Effect.POISONED, eff) then begin
      FxEngine.KillCreature(cr, C_Status.DEAD_STATUS, 'dies from poison');
      FxEngine.RemoveEffect(cr, C_Effect.POISONED, nil);
    end;
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(cr, C_Effect.SLOW_POISON_HIT, nil);
    GDVars.effectLock := 0;
  end;
end;

procedure EffSpiritualHammer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
  found: Boolean;
  savedCur: Types.PCharRecord;
begin
  it := cr^.itemsAddr;
  found := False;
  while (it <> nil) and not found do
    if (it^.itemTypeV1 = 6) and (it^.thirdNameId = 121) then
      found := True
    else
      it := it^.next;
  if removed then
    if it <> nil then
      CharHlp.RemoveItem(cr, it);
  if not removed then
    if not found then
      if cr^.numberOfItems < 16 then begin
        New(it);
        GameIo.FillWord(it^, SizeOf(Types.TItemRec));
        it^.itemTypeV1 := 6;
        it^.secondNameIdV1 := 6;
        it^.thirdNameId := 121;
        it^.plusV1 := 1;
        it^.itemEffect := 23;
        it^.itemSpecial := $80;
        CharHlp.AddItemCopy(cr, it);
        Dispose(it);
        it := cr^.itemsAddr;
        found := False;
        while (it <> nil) and not found do begin
          found := (it^.thirdNameId = 121) and (it^.itemTypeV1 = 6);
          it := it^.next;
        end;
        savedCur := GDVars.curChar;
        GDVars.curChar := cr;
        if it <> nil then
          if cr^.equipped[0] = nil then begin
            ViewChar.ToggleReadyItem(it);
            it^.equipped := 1;
          end;
        GDVars.curChar := savedCur;
        CharHlp.PrintCreatureMessage(cr, GDConsts.msgGains + 'an item', 10, True);
      end;
  CharHlp.RecalcStats(cr);
end;

procedure EffInvisible(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Types.PEffectRec;
begin
  if not removed then
    if not CharHlp.HasEffect(GDVars.curChar, EffHndlr.SEE_INVISIBLE, eff) then begin
      GDVars.suppressTargeting := 1;
      Dec(GDVars.attackRoll, 4);
    end;
end;

procedure EffDwarfHitBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foeIndex: Integer;
begin
  if not removed then begin
    GDVars.combatTarget := cr^.combatAddr^.other;
    if (GDVars.combatTarget^.creatureTypeFlags and $80) <> 0 then
      Inc(GDVars.attackRoll);
  end;
end;

procedure EffMirrorImage(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Byte;
begin
  if not removed then
    if FxEngine.RollDice(1, PEffData(p)^.strength div $10 + 1) > 1 then
      if (GDVars.spellId <= 0)
         or ((GDVars.areaTargets = 0) and (GDConsts.spellDefs[GDVars.spellId].offensive <> 0)) then begin
        EffHndlr.NullifyAttack(0);
        CharHlp.PrintCreatureMessage(cr, 'lost an image', 10, True);
        n := PEffData(p)^.strength shr 4;
        Dec(n);
        if n = 0 then
          FxEngine.RemoveEffect(cr, EffHndlr.MIRROR_IMAGE, nil)
        else begin
          n := n shl 4;
          PEffData(p)^.strength := (PEffData(p)^.strength and $F) or n;
        end;
      end;
end;

procedure EffEnfeeble(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    GDVars.pendingDamage := GDVars.pendingDamage - GDVars.pendingDamage div 4;
end;

procedure EffCoughing(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if cr^.combatAddr^.itemUseAllowed <> 0 then
      CharHlp.PrintCreatureMessage(cr, 'is coughing', 10, True);
    cr^.combatAddr^.itemUseAllowed := 0;
    cr^.combatAddr^.spellsAllowed := 0;
    CharHlp.RecalcStats(cr);
    if cr^.acCurArr[1] > 52 then
      Dec(cr^.acCurArr[1], 2)
    else
      cr^.acCurArr[1] := 50;
    cr^.acCurArr[0] := cr^.acCurArr[1];
    if cr = GDVars.curChar then
      CharHlp.CombatPrintCreatureInfo(cr);
  end;
end;

procedure EffDispelEvilTouch(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    GDVars.combatTarget := cr^.combatAddr^.other;
    if ((GDVars.combatTarget^.creatureTypeFlags and 1) <> 0) and
        (not FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.SPELL, 0)) then begin
      FxEngine.KillCreature(GDVars.combatTarget, C_Status.GONE, 'is dispelled');
      FxEngine.RemoveEffect(cr, 4, nil);
      FxEngine.RemoveEffect(cr, 32, nil);
    end else
      CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'resists dispel evil', 10, True);
  end;
end;

procedure EffBlind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Dec(GDVars.attackRoll, 4);
    Dec(cr^.acCurArr[0], 4);
    Dec(cr^.acCurArr[1], 4);
    Dec(GDVars.saveRoll, 4);
  end;
end;

procedure EffDiseased(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    FxEngine.CallEffectHandler(EffHndlr.DISEASE_STRENGTH, cr, p, removed);
    FxEngine.CallEffectHandler(EffHndlr.DISEASE_HIT_POINTS, cr, p, removed);
  end;
end;

procedure EffConfusion(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  roll: Byte;
  saved: Boolean;
begin
  if not removed then begin
    roll := FxEngine.RollDice(1, 100);
    case roll of
      1..10:
        begin
          FxEngine.RemoveEffect(cr, 35, nil);
          cr^.combatAddr^.forcedFlee := 1;
          cr^.quickfight := 1;
          if cr^.npc <= $7F then
            cr^.npc := $B3;
          cr^.combatAddr^.other := nil;
          FxEngine.AddEffectWithMessage(cr, 111, 10, 0, 1, 1, False, 'runs away');
        end;
      11..60:
        begin
          CharHlp.PrintNameStringAnim(cr, 1, 'is confused');
          CharHlp.ClearMessageWindow;
          EffHndlr.EffEndActions(cr, p, False);
        end;
      61..80:
        begin
          FxEngine.AddEffectWithMessage(cr, 77, 1, cr^.hostile, 1, 1, False, 'goes berserk');
          FxEngine.CallEffectHandler(77, cr, nil, False);
        end;
      81..100:
        begin
          CharHlp.PrintNameStringAnim(cr, 1, 'is enraged');
          CharHlp.ClearMessageWindow;
        end;
    end;
    saved := FxEngine.RollSavingThrow(cr, C_Save.SPELL, 254);
    if saved then
      FxEngine.RemoveEffect(cr, 35, nil);
  end;
end;

procedure EffBestowCurse(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    Dec(GDVars.attackRoll, 4);
    Dec(GDVars.saveRoll, 4);
  end;
end;

procedure EffBlinking(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    if cr^.combatAddr^.initiative = 0 then begin
      GDVars.suppressTargeting := 1;
      GDVars.attackRoll := -1;
    end;
end;

procedure EffHasted(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    if (PEffData(p)^.strength and $10) = 0 then begin
      PEffData(p)^.strength := PEffData(p)^.strength + $10;
      CharHlp.PrintCreatureMessage(cr, 'ages', 10, True);
      Inc(cr^.age);
      GDVars.agingFlag := 1;
    end;
    GDVars.movement := GDVars.movement shl 1;
    GDVars.movementAttacks := GDVars.movementAttacks shl 1;
  end;
end;

procedure EffClearStinkingCloud(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  prev: Types.PCloudNode;
  node: Types.PCloudNode;
  found: Boolean;
  k: Byte;
  j: Byte;
  x: Byte;
  y: Byte;
begin
  k := PEffData(p)^.strength div $10;
  found := False;
  node := GDVars.stinkHead;
  while (node <> nil) and not found do
    if (node^.owner = cr) and (node^.cnt = k) then
      found := True
    else
      node := node^.next;
  if found then begin
    CharHlp.PrintBottomLine('The air clears a little...');
    for j := 1 to 4 do
      if node^.live[j] <> 0 then begin
        x := node^.x + GDConsts.dirDx[GDConsts.cloudDirs[j]];
        y := node^.y + GDConsts.dirDy[GDConsts.cloudDirs[j]];
        found := False;
        for k := 1 to GDVars.downedCount do
          if (GDVars.downed[k].cr <> nil) and (GDVars.downed[k].x = x)
             and (GDVars.downed[k].y = y) then
            found := True;
        if found then begin
          if cr^.status = C_Status.PETRIFIED then
            GDVars.arenaPtr^.cells[y, x] := 28
          else
            GDVars.arenaPtr^.cells[y, x] := 30;
        end else
          GDVars.arenaPtr^.cells[y, x] := node^.saved[j];
      end;
    prev := GDVars.stinkHead;
    if prev = node then
      GDVars.stinkHead := prev^.next
    else
      while prev^.next <> node do
        prev := prev^.next;
    prev^.next := node^.next;
    Dispose(node);
    EffHndlr.MarkCloudCells;
  end;
end;

procedure AvoidMissile(var cr: Types.PCharRecord; a: Byte);
begin
  if GDVars.curChar^.equipped[0] <> nil then
    if CharHlp.CalcDistance(GDVars.curChar, cr) > 1 then
      if FxEngine.RollDice(1, 100) <= a then begin
        CharHlp.PrintCreatureMessage(cr, 'Avoids it', 10, True);
        GDVars.pendingDamage := 0;
        GDVars.attackRoll := -1;
        Dec(GDVars.attacksHit[1]);
      end;
end;

function FindDamagingWeapon(cr: Types.PCharRecord): Types.PItemRec;
var
  it: Types.PItemRec;
  ok: Boolean;
begin
  it := nil;
  if cr^.equipped[0] <> nil then begin
    ok := CharHlp.FindDamagingRangedWeapon(cr, it);
    if (not ok) or (it = nil) then
      it := cr^.equipped[0];
  end;
  FindDamagingWeapon := it;
end;

procedure EffProtNormalMissiles(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if EffHndlr.FindDamagingWeapon(GDVars.curChar) <> nil then
    if EffHndlr.FindDamagingWeapon(GDVars.curChar)^.plusV1 = 0 then
      EffHndlr.AvoidMissile(cr, 100);
end;

procedure EffSlowed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.movement := GDVars.movement div 2;
  GDVars.movementAttacks := GDVars.movementAttacks div 2;
end;

procedure EffDiseaseStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, EffHndlr.DISEASE_STRENGTH, PEffData(p)^.strength, 60) then
    if cr^.stats[C_Stat.STRENGTH].cur > 3 then begin
      CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + 'weakened', 10, True);
      Dec(cr^.stats[C_Stat.STRENGTH].cur);
    end else
      FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, 0);
end;

procedure EffDiseaseHitPoints(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, EffHndlr.DISEASE_HIT_POINTS, PEffData(p)^.strength, 10) then
    if cr^.hpCurrent > 1 then begin
      GDVars.elemMask := 0;
      FxEngine.InflictNonWeaponDamage(cr, 1, 0, False);
      if GDVars.interfaceState <> C_Ifc.IN_COMBAT then
        CharHlp.DisplayParty(cr, cr = GDVars.curChar);
    end else
      FxEngine.AddEffect(cr, C_Effect.HELPLESS, 0, 255, 0);
end;

procedure EffDwarfGiantDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.curChar^.creatureTypeFlags and 4) <> 0 then
    Dec(GDVars.attackRoll, 4);
end;

procedure EffGnomeBugDefense(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.curChar^.creatureTypeFlags and $20) <> 0 then
    Dec(GDVars.attackRoll, 4);
end;

procedure EffPrayer(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  want: ShortInt;
begin
  if removed then Exit;
  want := (PEffData(p)^.strength and $10) div $10;
  if cr^.hostile = want then
    EffHndlr.AddRollBonus(cr, p, removed)
  else begin
    Dec(GDVars.attackRoll);
    Dec(GDVars.saveRoll);
  end;
end;

procedure EffFireVulnerable(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elemMask and 2) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if (GDVars.elemMask and 1) <> 0 then
    if not GDVars.saveResult then
      GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffColdVulnerable(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elemMask and 1) <> 0 then
    Inc(GDVars.saveRoll, 2)
  else if (GDVars.elemMask and 2) <> 0 then
    if GDVars.gameSaved = 0 then
      GDVars.pendingDamage := GDVars.pendingDamage shl 1;
end;

procedure EffPoisoned(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffRenewInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then
      FxEngine.RemoveEffect(cr, C_Effect.INVISIBLE, nil);
  end else
    FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 1, 12, 0);
end;

procedure EffGlobeOfInvulnerability(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if GDVars.spellId > 0 then
    if GDConsts.spellDefs[GDVars.spellId].level <= 4 then
      EffHndlr.NullifyAttack(0);
end;

procedure EffPetrifyingGaze(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  item: Types.PEffectRec;
  { Unused in this version; see the other implementations of this routine. }
  reflected: Boolean;
  eff: Types.PEffectRec;
begin
  if removed then Exit;
  GDVars.castTargetMenu(61, True, GDVars.castConfirmed);
  if CharHlp.EnemyTeam(cr) <> GDVars.castTargets[1]^.hostile then
    GDVars.castConfirmed := False;
  if not GDVars.castConfirmed then Exit;
  GDVars.combatTarget := GDVars.castTargets[1];
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 4,
                                  45);
  if CharHlp.HasEffect(cr, 59, eff) then begin
    reflected := False;
    if CharHlp.HasEffect(GDVars.combatTarget, 72, eff) then begin
      CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'reflects it!', 12, False);
      CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget),
                                      CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 4,
                              45);
      reflected := True;
      GDVars.combatTarget := cr;
    end;
  end;
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, EffHndlr.SAVE_PETRIFY, 0) then
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.PETRIFIED, 'is turned to stone');
end;

procedure EffNoneB(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffNeedMagicWeapon(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
begin
  if removed then Exit;
  it := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if it <> nil then begin
    if it^.plusV1 < 3 then
      GDVars.pendingDamage := 0;
  end else
    GDVars.pendingDamage := 0;
end;

procedure EffRingFireRes(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  i: Byte;
begin
  if removed then Exit;
  if (GDVars.elemMask and 1) <> 0 then begin
    for i := 1 to GDVars.damageDice do begin
      Dec(GDVars.pendingDamage, 2);
      if GDVars.pendingDamage < GDVars.damageDice then
        GDVars.pendingDamage := GDVars.damageDice;
    end;
    Inc(GDVars.saveRoll, 4);
    if (GDVars.elemMask and 8) = 0 then
      EffHndlr.NullifyAttack(0);
  end;
end;

procedure EffRegeneration(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if EffHndlr.AddEffectIfNoLock(cr, 62, PEffData(p)^.strength, 60) then
    if FxEngine.RestoreHitPoints(cr, 1, 1) then
      CharHlp.AnnounceHealStatus(cr);
end;

procedure EffMinorGlobe(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if GDVars.spellId > 0 then
    if GDConsts.spellDefs[GDVars.spellId].level <= 3 then
      EffHndlr.NullifyAttack(0);
end;

procedure PoisonTarget(var cr: Types.PCharRecord; dmg: ShortInt);
var
  eff: Types.PEffectRec;
  r: Boolean;
begin
  GDVars.combatTarget := cr^.combatAddr^.other;
  if CharHlp.HasEffect(GDVars.combatTarget, 64, eff) then
    if dmg < 0 then
      dmg := 0
    else
      Inc(dmg, PEffData(eff)^.strength);
  r := FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.PARALYZATION, dmg);
  FxEngine.AddEffectWithMessage(GDVars.combatTarget, C_Effect.POISONED, 0, 255, 0, 1, r,
                                GDConsts.msgIs + GDConsts.effectNames[C_Effect.POISONED]);
  TextRend.PauseOnly;
  if CharHlp.HasEffect(GDVars.combatTarget, C_Effect.POISONED, eff) then
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.DEAD_STATUS, 'is killed');
end;

procedure EffPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.PoisonTarget(cr, 0);
end;

procedure EffFleshToStone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  saved: Byte;
begin
  if removed then Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, EffHndlr.SAVE_PETRIFY, 0) then
    FxEngine.KillCreature(GDVars.combatTarget, C_Status.PETRIFIED, 'is turned to stone');
end;

procedure EffSwallowWhole(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { CombatSlot(combatTarget) }
  slot: Byte;
  { the search counter, then the inner animation index }
  step: Byte;
  { the outer animation counter }
  frame: Byte;
  { GetIconTileDelta out-parameters }
  ox: ShortInt;
  oy: ShortInt;
  cx0: ShortInt;
  cy0: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  downedIdx: Byte;
begin
  if removed then Exit;
  if GDVars.attackRoll < 75 then Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is swallowed whole', 10, True);
  TextRend.PauseOnly;
  GDVars.combatTarget^.status := C_Status.DEAD_STATUS;
  GDVars.combatTarget^.enabled := 0;
  GDVars.combatTarget^.hpCurrent := 0;
  FxEngine.RemoveEffectsHp0(GDVars.combatTarget);
  step := 1;
  while (step < 9) and (GDVars.downed[frame].cr <> GDVars.combatTarget) do
    Inc(step);
  if step <> 9 then Exit;
  slot := CbtMap.CombatSlot(GDVars.combatTarget);
  cx0 := CbtMap.CombatCellX(GDVars.combatTarget);
  cy0 := CbtMap.CombatCellY(GDVars.combatTarget);
  if not CbtMap.CombatIconVisible(GDVars.combatTarget, 1) then
    CbtMap.ScrollView(cx0, cy0, 3, C_Dir.CENTER);
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  SoundDrv.SoundCommand(GDConsts.downedSound);
  for frame := 0 to 8 do begin
    for step := 0 to 3 do
      if CbtMap.GetIconTileDelta(GDVars.arenaLoc[slot].size, step, ox, oy) then
        if CbtMap.ViewCoordsValid(GDVars.gridX[slot] + ox, GDVars.gridY[slot] + oy) then
          Blit.BlitTileClipped((GDVars.gridX[slot] + ox) * 3, (GDVars.gridY[slot] + oy) * 3, 0, 5,
                               GDVars.iconAnims[24, frame mod 2], GDVars.viewBuf);
    Blit.FlushView;
    Delay(10);
  end;
  CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is killed', 10, False);
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  if GDVars.combatTarget^.combatAddr^.notPcNpc = 0 then begin
    cx0 := CbtMap.CombatCellX(cr);
    cy0 := CbtMap.CombatCellY(cr);
    Inc(GDVars.downedCount);
    GDVars.downed[GDVars.downedCount].terrain := GDVars.arenaPtr^.cells[cy0, cx0];
    if GDVars.arenaPtr^.cells[cy0, cx0] <> 29 then
      if cr^.status = C_Status.PETRIFIED then
        GDVars.arenaPtr^.cells[cy0, cx0] := 28
      else
        GDVars.arenaPtr^.cells[cy0, cx0] := 30;
    GDVars.downed[GDVars.downedCount].cr := GDVars.combatTarget;
    GDVars.downed[GDVars.downedCount].x := cx0;
    GDVars.downed[GDVars.downedCount].y := cy0;
  end;
  if FxEngine.RollDice(1, 100) <= 50 then
    CharHlp.PrintCreatureMessage(cr, 'belches in satisfaction', 10, True)
  else
    CharHlp.PrintCreatureMessage(GDVars.combatTarget, 'is digested instantly', 10, True);
  CbtMap.UpdateCombatMapTile(0, 0, slot);
  GDVars.arenaLoc[slot].size := 0;
  GDVars.arenaLoc[slot].x := cx0;
  GDVars.arenaLoc[slot].y := cy0;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
  GDVars.combatTarget^.combatAddr^.initiative := 0;
  GDVars.combatTarget^.combatAddr^.movement := 0;
  GDVars.combatTarget^.combatAddr^.spellCast := 0;
  GDVars.combatTarget^.combatAddr^.guarding := 0;
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
end;

procedure EffBreatheFireAdjacent(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if GDVars.roundCounter = 0 then Exit;
  if cr^.attacks < GDVars.roundCounter then Exit;
  GDVars.elemMask := $21;
  GDVars.combatTarget := cr^.combatAddr^.other;
  if CharHlp.CalcDistance(cr, GDVars.combatTarget) >= 2 then Exit;
  CharHlp.PrintCreatureMessage(cr, 'Breathes Fire', 10, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 1,
                                  30);
  FxEngine.InflictNonWeaponDamage(GDVars.combatTarget, 8, 2,
                                  FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.BREATH_WEAPON, 0));
end;

procedure EffFeeblemind(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  cr^.intCurV1 := 3;
  cr^.stats[C_Stat.WISDOM].cur := 3;
  CharHlp.PrintCreatureMessage(cr, 'is made stupid', 10, True);
  if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
    cr^.combatAddr^.spellsAllowed := 0;
    if cr^.combatAddr^.spellCast > 0 then begin
      CharHlp.PrintCreatureMessage(cr, 'lost a spell', 12, True);
      CharHlp.RemoveSpell(cr, cr^.combatAddr^.spellCast);
      cr^.combatAddr^.spellCast := 0;
    end;
  end;
end;

procedure EffInvisibleToAnimals(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  eff: Types.PEffectRec;
begin
  if not removed then
    if (cr^.creatureTypeFlags and $45) <> 0 then
      if not CharHlp.HasEffect(cr, EffHndlr.SEE_INVISIBLE, eff) then begin
        GDVars.suppressTargeting := 1;
        Dec(GDVars.attackRoll, 4);
      end;
end;

procedure EffReflectSpell(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  proceed: Boolean;
begin
  if removed then Exit;
  GDVars.castTargetMenu(68, True, proceed);
  GDVars.combatTarget := GDVars.castTargets[1];
  if not proceed then Exit;
  if CharHlp.CalcDistance(cr, GDVars.combatTarget) >= 2 then Exit;
  CharHlp.PrintCreatureMessage(cr, 'gazes...', 10, False);
  CharHlp.BuildIconFacings(18);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 4,
                                  45);
  if not FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.SPELL, 0) then
    FxEngine.AddEffectWithMessage(GDVars.combatTarget, 35, FxEngine.RollDice(1, 10) + 2, cr^.hostile, 1, 1, False,
                                  'stares blankly');
end;

procedure EffFaerieFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  acPenalty: Integer;
begin
  if removed then Exit;
  Dec(cr^.acCurArr[0], 2);
  Dec(cr^.acCurArr[1], 2);
end;

procedure EffNoneC(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffImmuneBreath(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elemMask and $20) > 0 then
    EffHndlr.NullifyAttack(0);
end;

procedure EffBootsOfSpeed(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  scale: Word;
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  if not removed then begin
    scale := scale * 2;
    Inc(cr^.acCurArr[0], 2);
    Inc(cr^.acCurArr[1], 2);
  end;
end;

procedure EffHolyWater(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  if (GDVars.combatTarget^.targetFlags and 1) <> 0 then begin
    GDVars.pendingDamage := FxEngine.RollDamageDice(6, 6) + CharHlp.StrDamageAdjust(cr);
    Inc(GDVars.attackRoll);
  end;
end;

procedure EffNoneD(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = $B3) then
      cr^.npc := $B3
    else
      cr^.npc := $B2;
    if GDVars.interfaceState = C_Ifc.IN_COMBAT then begin
      cr^.combatAddr^.other := nil;
      Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr),
                              GDVars.arenaPtr);
      cr^.combatAddr^.other := GDVars.creatures[GDVars.targets[2].who];
      cr^.combatAddr^.spellsAllowed := 0;
      cr^.hostile := cr^.combatAddr^.other^.hostile xor 1;
      CharHlp.PrintCreatureMessage(cr, 'goes berserk', 10, True);
    end;
  end else begin
    if cr^.npc = $B3 then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
    cr^.hostile := 0;
  end;
end;

procedure EffSaveBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  Inc(GDVars.saveRoll);
end;

procedure EffIronGolem(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Types.PEffectRec;
begin
  if ((GDVars.elemMask and 1) <> 0) and ((GDVars.elemMask and 8) <> 0) then begin
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + GDConsts.msgHealed, 10, True);
    Inc(cr^.hpCurrent, GDVars.pendingDamage);
    if cr^.hpCurrent > cr^.hpMaxV1 then
      cr^.hpCurrent := cr^.hpMaxV1;
    EffHndlr.NullifyAttack(0);
  end else if (GDVars.elemMask and 4) <> 0 then begin
    FxEngine.AddEffect(cr, C_Effect.SLOWED, 3, 255, 0);
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgIs + GDConsts.effectNames[C_Effect.SLOWED], 10, True);
    EffHndlr.NullifyAttack(0);
  end else
    EffHndlr.NullifyAttack(0);
end;

procedure EffBreatheFireAtTarget(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  proceed: Boolean;
  fxRes: Boolean;
  dir: Byte;
begin
  if removed then Exit;
  GDVars.elemMask := $21;
  GDVars.castTargetMenu(68, True, proceed);
  GDVars.combatTarget := GDVars.castTargets[1];
  if not proceed then Exit;
  dir := CharHlp.DirTowardTarget(cr, GDVars.combatTarget);
  CbtMap.SetCreatureFacing(cr, dir, 1, 0);
  CharHlp.PrintCreatureMessage(cr, 'Breathes Fire', 10, True);
  CharHlp.BuildIconFacings(23);
  CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                  CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 1,
                                  30);
  fxRes := FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.BREATH_WEAPON, 0);
  FxEngine.InflictNonWeaponDamage(GDVars.combatTarget, 7, 2, fxRes);
end;

procedure EffSpitAtTarget(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  proceed: Boolean;
  chance: Byte;
  dist: Byte;
begin
  if removed then Exit;
  GDVars.elemMask := $10;
  chance := 0;
  GDVars.castTargetMenu(61, True, proceed);
  GDVars.combatTarget := GDVars.castTargets[1];
  dist := CharHlp.CalcDistance(cr, GDVars.combatTarget);
  if dist <= 11 then
    if GDVars.roundCounter = 0 then
      chance := 10
    else
      chance := (11 - dist) * 10;
  if chance <= 0 then Exit;
  if proceed and (FxEngine.RollDice(1, 100) <= chance) then begin
    CharHlp.PrintCreatureMessage(cr, 'Spits...', 10, True);
    CharHlp.BuildIconFacings(23);
    CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr),
                                    CbtMap.CombatCellX(GDVars.combatTarget), CbtMap.CombatCellY(GDVars.combatTarget), 1,
                                    30);
    FxEngine.InflictNonWeaponDamage(GDVars.combatTarget, FxEngine.RollDamageDice(4, 8), 2,
                                    FxEngine.RollSavingThrow(GDVars.combatTarget, C_Save.BREATH_WEAPON, 0));
  end else
    CharHlp.PrintCreatureMessage(cr, 'Spits and misses', 10, True);
end;

procedure EffDragonFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  who: Types.PCharRecord;
  eff: Types.PEffectRec;
begin
  if removed then Exit;
  eff := nil;
  who := GDVars.creatureList;
  while who <> nil do begin
    if (who^.hostile <> cr^.hostile) and (not CharHlp.HasEffect(who, 92, eff)) and
        (not CharHlp.HasEffect(who, 111, eff)) and (who^.highestLevel < 5) then begin
      FxEngine.AddEffectWithMessage(who, 111, 0, 255, 1, 1, False, 'is terrified');
      if CharHlp.HasEffect(who, 111, eff) then begin
        who^.quickfight := 1;
        if who^.npc <= $7F then
          who^.npc := $B3;
        who^.combatAddr^.other := nil;
        who^.combatAddr^.forcedFlee := 1;
      end;
    end;
    who := who^.nextCharAddr;
  end;
end;

procedure EffStrongPoisonAttack(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.PoisonTarget(cr, -2);
end;

procedure EffGhoulPara(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.ParalyzeTarget(cr, 100, 0);
end;

procedure EffDisplaced(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.roundCounter = 0) and (GDVars.attackRoll = 0) then
    PEffData(p)^.strength := PEffData(p)^.strength and $F
  else if (PEffData(p)^.strength and $10) = 0 then begin
    GDVars.attackRoll := -1;
    PEffData(p)^.strength := PEffData(p)^.strength or $10;
  end;
end;

procedure EffHalfBash(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
begin
  if removed then Exit;
  it := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if it <> nil then
    if (GDVars.baseItems[it^.itemTypeV1].wpnClass and $80) <> 0 then
      GDVars.pendingDamage := 0;
end;

procedure EffClearCloudkill(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  prev: Types.PCloudNode;
  node: Types.PCloudNode;
  found: Boolean;
  k: Byte;
  j: Byte;
  x: Byte;
  y: Byte;
begin
  k := PEffData(p)^.strength div $10;
  found := False;
  node := GDVars.cloudkillHead;
  while (node <> nil) and not found do
    if (node^.owner = cr) and (node^.cnt = k) then
      found := True
    else
      node := node^.next;
  if found then begin
    CharHlp.PrintBottomLine('The air clears a little...');
    for j := 1 to 9 do
      if node^.live[j] <> 0 then begin
        x := node^.x + GDConsts.dirDx[GDConsts.cloudDirs9[j]];
        y := node^.y + GDConsts.dirDy[GDConsts.cloudDirs9[j]];
        found := False;
        for k := 1 to GDVars.downedCount do
          if (GDVars.downed[k].cr <> nil) and (GDVars.downed[k].x = x)
             and (GDVars.downed[k].y = y) then
            found := True;
        if found then begin
          if cr^.status = C_Status.PETRIFIED then
            GDVars.arenaPtr^.cells[y, x] := 28
          else
            GDVars.arenaPtr^.cells[y, x] := 30;
        end else
          GDVars.arenaPtr^.cells[y, x] := node^.saved[j];
      end;
    prev := GDVars.cloudkillHead;
    if prev = node then
      GDVars.cloudkillHead := prev^.next
    else
      while prev^.next <> node do
        prev := prev^.next;
    prev^.next := node^.next;
    Dispose(node);
    EffHndlr.MarkCloudCells;
  end;
end;

procedure EffImmuneFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.NullifyAttack(111);
end;

procedure EffImmuneFire(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elemMask and 1) <> 0 then
    EffHndlr.NullifyAttack(0);
end;

procedure EffConPsnSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Byte;
begin
  if removed then Exit;
  if (GDVars.saveType = C_Save.SPELL) or (GDVars.saveType = 2) or
      (GDVars.saveType = C_Save.PARALYZATION) then begin
    case cr^.conCur of
      4..6: n := 1;
      7..10: n := 2;
      11..13: n := 3;
      14..17: n := 4;
      18..20: n := 5;
    end;
    GDVars.saveRoll := GDVars.saveRoll + n;
  end;
end;

procedure EffElfResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if FxEngine.RollDice(1, 100) <= 90 then begin
    EffHndlr.NullifyAttack(11);
    EffHndlr.NullifyAttack(53);
  end;
end;

procedure EffImmuneSleepCharm(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.NullifyAttack(11);
  EffHndlr.NullifyAttack(53);
end;

procedure EffConSpellSave(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  n: Byte;
begin
  if removed then Exit;
  if (GDVars.saveType = C_Save.SPELL) or (GDVars.saveType = 2) then begin
    case cr^.conCur of
      4..6: n := 1;
      7..10: n := 2;
      11..13: n := 3;
      14..17: n := 4;
      18..20: n := 5;
    end;
    GDVars.saveRoll := GDVars.saveRoll + n;
  end;
end;

procedure EffImmuneCold(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  if (GDVars.elemMask and 2) <> 0 then
    EffHndlr.NullifyAttack(0);
end;

procedure EffImmuneParalysisPoison(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  EffHndlr.NullifyAttack(C_Effect.POISONED);
  EffHndlr.NullifyAttack(52);
  if GDVars.saveType = C_Save.PARALYZATION then
    GDVars.saveRoll := 100;
end;

procedure EffDelayedBlastFireball(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;
  prev: Types.PCloudNode;
  node: Types.PCloudNode;
  found: Boolean;
  k: Byte;
  x: Byte;
  y: Byte;
  dmg: Byte;
  i: Byte;
  px: ShortInt;
  py: ShortInt;
  snd: Byte;
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hits: Byte;
  total: Byte;
  j: Byte;
  tgt: Types.PCharRecord;
  s: String;
begin
  if not removed then Exit;
  if GDVars.interfaceState <> C_Ifc.IN_COMBAT then Exit;
  k := PEffData(p)^.strength div $10;
  found := False;
  node := GDVars.blastHead;
  while (node <> nil) and not found do
    if (node^.owner = cr) and (node^.cnt = k) then
      found := True
    else
      node := node^.next;
  if not found then Exit;
  GDVars.areaTargets := 1;
  dmg := cr^.mageLevel + cr^.mageOldLevel * Ord(ClassCal.EarlierClassActive(cr));
  GDVars.targetCellX := node^.x;
  GDVars.targetCellY := node^.y;
  Pathing.BuildTargetList(GDVars.targetCellX, GDVars.targetCellY, 3, 255, 1, GDVars.arenaPtr);
  for i := 1 to GDVars.targetCount do
    GDVars.castTargets[i] := GDVars.creatures[GDVars.targets[i].who];
  GDVars.castTargetCount := GDVars.targetCount;
  CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 255, C_Dir.CENTER);
  px := (GDVars.targetCellX - GDVars.arenaPtr^.ox) * 3;
  py := (GDVars.targetCellY - GDVars.arenaPtr^.oy) * 3;
  TextRend.PauseOnly;
  snd := 23;
  CharHlp.BuildIconFacings(snd);
  SoundDrv.SoundCommand(GDConsts.missSound);
  for frame := 0 to 3 do begin
    if frame = 1 then
      TextRend.DisplayString(0, 24, LightGreen, 0, 'Delayed Blast Fireball goes off');
    Blit.BlitTileClipped(px, py, frame, 5, GDVars.iconBuf, GDVars.viewBuf);
    Blit.FlushView;
    Delay(frame * 30 + 70);
    Blit.BlitTileClipped(px, py, 0, 0, GDVars.saveUnder, GDVars.viewBuf);
  end;
  Blit.FlushView;
  TextRend.ClearRect(0, 24, 39, 24);
  if node^.live[1] <> 0 then begin
    x := node^.x;
    y := node^.y;
    found := False;
    for k := 1 to GDVars.downedCount do
      if (GDVars.downed[k].cr <> nil) and (GDVars.downed[k].x = x)
         and (GDVars.downed[k].y = y) then
        found := True;
    if found then begin
      if cr^.status = C_Status.PETRIFIED then
        GDVars.arenaPtr^.cells[y, x] := 28
      else
        GDVars.arenaPtr^.cells[y, x] := 30;
    end else
      GDVars.arenaPtr^.cells[y, x] := node^.saved[1];
  end;
  prev := GDVars.blastHead;
  if prev = node then
    GDVars.blastHead := prev^.next
  else
    while prev^.next <> node do
      prev := prev^.next;
  prev^.next := node^.next;
  Dispose(node);
  EffHndlr.MarkCloudCells;
  CbtMap.ScrollView(GDVars.targetCellX, GDVars.targetCellY, 0, C_Dir.CENTER);
  GDVars.elemMask := 9;
  Str(dmg, s);
  total := dmg + FxEngine.RollDamageDice(dmg, 6);
  for j := 1 to GDVars.castTargetCount do begin
    tgt := GDVars.castTargets[j];
    if tgt <> nil then
      FxEngine.InflictNonWeaponDamage(tgt, total, 2, FxEngine.RollSavingThrow(tgt, C_Save.SPELL, 0));
  end;
  GDVars.elemMask := 0;
end;

procedure EffWeaponResistance(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
begin
  if removed then Exit;
  it := EffHndlr.FindDamagingWeapon(GDVars.curChar);
  if (it = nil) or (it^.plusV1 = 0) then
    if ((GDVars.curChar^.race < C_Race.MONSTER) and (GDVars.curChar^.race > C_Race.TRIBBLE))
       or (GDVars.curChar^.highestLevel < 4) then
      GDVars.pendingDamage := 0;
end;

procedure EffRangerDamageBonus(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  foe: Pointer;
begin
  if removed then Exit;
  GDVars.combatTarget := cr^.combatAddr^.other;
  if CharHlp.CalcDistance(cr, GDVars.combatTarget) > 1 then Exit;
  if (GDVars.combatTarget^.creatureTypeFlags and 8) <> 0 then
    Inc(GDVars.pendingDamage, cr^.rangerLevel);
end;

procedure EffHelpless(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
begin
  done := CharHlp.EndActions(cr);
end;

procedure EffConfusedBerserk(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then begin
    cr^.quickfight := 1;
    if (cr^.npc <= $7F) or (cr^.npc = $B3) then
      cr^.npc := $B3
    else
      cr^.npc := $B2;
    cr^.combatAddr^.other := nil;
    Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr),
                            GDVars.arenaPtr);
    cr^.combatAddr^.other := GDVars.creatures[GDVars.targets[2].who];
    cr^.hostile := cr^.combatAddr^.other^.hostile xor 1;
  end else begin
    if cr^.npc = $B3 then
      cr^.npc := 0;
    cr^.hostile := PEffData(p)^.strength;
  end;
end;

procedure EffLastingInvisibility(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then Exit;
  FxEngine.AddEffect(cr, C_Effect.INVISIBLE, 255, 255, 0);
end;

procedure EffRecentCure(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then
    cr^.cureDiseaseLeft := (cr^.paladinLevel + cr^.paladinOldLevel * Ord(ClassCal.EarlierClassActive(cr)) - 1) div 5 +
      1;
end;

procedure EffFear(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if removed then begin
    if cr^.npc = $B3 then begin
      cr^.npc := 0;
      cr^.quickfight := 0;
    end;
    cr^.combatAddr^.forcedFlee := 0;
  end;
end;

procedure EffZapAttacker(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  savedDamage: Byte;
  savedElemMask: Byte;
begin
  if removed then Exit;
  if CharHlp.CalcDistance(GDVars.curChar, cr) < 2 then begin
    savedDamage := GDVars.pendingDamage;
    GDVars.pendingDamage := GDVars.pendingDamage * 2;
    if GDVars.pendingDamage > 0 then begin
      savedElemMask := GDVars.elemMask;
      GDVars.elemMask := 8;
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'gets zapped', 10, True);
      FxEngine.InflictNonWeaponDamage(GDVars.curChar, GDVars.pendingDamage, 0, False);
      GDVars.pendingDamage := savedDamage;
      GDVars.elemMask := savedElemMask;
    end;
  end;
end;

procedure EffGiantStrength(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
  if not removed then
    CharHlp.PrintCreatureMessage(cr, GDConsts.msgGains + GDConsts.effectNames[113], 10, True);
end;

procedure EffNone(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
begin
end;

procedure EffGrantItemEffect(var cr: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  it: Types.PItemRec;
begin
  GDVars.overrideFlag := 0;
  it := p;
  if removed then
    FxEngine.RemoveEffect(cr, it^.itemEffect, nil)
  else
    FxEngine.AddEffect(cr, it^.itemEffect, 0, 255, 1);
end;

procedure InitEffectHandlers;
begin
  GDVars.effectHandlers[1] := EffHndlr.EffBless;
  GDVars.effectHandlers[2] := EffHndlr.EffCurse;
  GDVars.effectHandlers[3] := EffHndlr.EffSticksToSnakes;
  GDVars.effectHandlers[4] := EffHndlr.EffDispelEvil;
  GDVars.effectHandlers[5] := EffHndlr.EffNone;
  GDVars.effectHandlers[6] := EffHndlr.EffImmuneElectricity;
  GDVars.effectHandlers[7] := EffHndlr.EffTypeHitBonus;
  GDVars.effectHandlers[C_Effect.PROTECTION_FROM_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[9] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[10] := EffHndlr.EffResistCold;
  GDVars.effectHandlers[11] := EffHndlr.EffCharm;
  GDVars.effectHandlers[C_Effect.ENLARGE] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[13] := EffHndlr.EffBarkskin;
  GDVars.effectHandlers[14] := EffHndlr.EffFriends;
  GDVars.effectHandlers[C_Effect.SLOW_POISON_HIT] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectHandlers[16] := EffHndlr.EffReadMagic;
  GDVars.effectHandlers[17] := EffHndlr.EffShield;
  GDVars.effectHandlers[18] := EffHndlr.EffHalfElfResistance;
  GDVars.effectHandlers[19] := EffHndlr.EffNone;
  GDVars.effectHandlers[20] := EffHndlr.EffResistFire;
  GDVars.effectHandlers[21] := EffHndlr.EffSilence;
  GDVars.effectHandlers[C_Effect.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectHandlers[23] := EffHndlr.EffSpiritualHammer;
  GDVars.effectHandlers[24] := EffHndlr.EffNone;
  GDVars.effectHandlers[C_Effect.INVISIBLE] := EffHndlr.EffInvisible;
  GDVars.effectHandlers[26] := EffHndlr.EffDwarfHitBonus;
  GDVars.effectHandlers[27] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[28] := EffHndlr.EffMirrorImage;
  GDVars.effectHandlers[29] := EffHndlr.EffEnfeeble;
  GDVars.effectHandlers[C_Effect.STINKING_CLOUD_COUGH] := EffHndlr.EffCoughing;
  GDVars.effectHandlers[C_Effect.HELPLESS] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[32] := EffHndlr.EffDispelEvilTouch;
  GDVars.effectHandlers[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectHandlers[C_Effect.DISEASED] := EffHndlr.EffDiseased;
  GDVars.effectHandlers[35] := EffHndlr.EffConfusion;
  GDVars.effectHandlers[C_Effect.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GDVars.effectHandlers[37] := EffHndlr.EffBlinking;
  GDVars.effectHandlers[C_Effect.STRENGTH] := EffHndlr.EffStrengthBonus;
  GDVars.effectHandlers[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectHandlers[40] := EffHndlr.EffClearStinkingCloud;
  GDVars.effectHandlers[41] := EffHndlr.EffProtNormalMissiles;
  GDVars.effectHandlers[C_Effect.SLOWED] := EffHndlr.EffSlowed;
  GDVars.effectHandlers[43] := EffHndlr.EffDiseaseStrength;
  GDVars.effectHandlers[44] := EffHndlr.EffDiseaseHitPoints;
  GDVars.effectHandlers[45] := EffHndlr.EffProtEvil;
  GDVars.effectHandlers[46] := EffHndlr.EffProtGood;
  GDVars.effectHandlers[47] := EffHndlr.EffDwarfGiantDefense;
  GDVars.effectHandlers[48] := EffHndlr.EffGnomeBugDefense;
  GDVars.effectHandlers[49] := EffHndlr.EffPrayer;
  GDVars.effectHandlers[50] := EffHndlr.EffFireVulnerable;
  GDVars.effectHandlers[51] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[52] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[53] := EffHndlr.EffEndActions;
  GDVars.effectHandlers[54] := EffHndlr.EffColdVulnerable;
  GDVars.effectHandlers[C_Effect.POISONED] := EffHndlr.EffPoisoned;
  GDVars.effectHandlers[56] := EffHndlr.EffRenewInvisibility;
  GDVars.effectHandlers[57] := EffHndlr.EffGlobeOfInvulnerability;
  GDVars.effectHandlers[58] := EffHndlr.EffPetrifyingGaze;
  GDVars.effectHandlers[59] := EffHndlr.EffNoneB;
  GDVars.effectHandlers[60] := EffHndlr.EffNeedMagicWeapon;
  GDVars.effectHandlers[61] := EffHndlr.EffRingFireRes;
  GDVars.effectHandlers[62] := EffHndlr.EffRegeneration;
  GDVars.effectHandlers[63] := EffHndlr.EffMinorGlobe;
  GDVars.effectHandlers[64] := EffHndlr.EffPoisonAttack;
  GDVars.effectHandlers[65] := EffHndlr.EffFleshToStone;
  GDVars.effectHandlers[66] := EffHndlr.EffSwallowWhole;
  GDVars.effectHandlers[67] := EffHndlr.EffBreatheFireAdjacent;
  GDVars.effectHandlers[C_Effect.FEEBLEMINDED] := EffHndlr.EffFeeblemind;
  GDVars.effectHandlers[69] := EffHndlr.EffInvisibleToAnimals;
  GDVars.effectHandlers[70] := EffHndlr.EffReflectSpell;
  GDVars.effectHandlers[71] := EffHndlr.EffFaerieFire;
  GDVars.effectHandlers[72] := EffHndlr.EffNoneC;
  GDVars.effectHandlers[73] := EffHndlr.EffImmuneBreath;
  GDVars.effectHandlers[74] := EffHndlr.EffBootsOfSpeed;
  GDVars.effectHandlers[75] := EffHndlr.EffHolyWater;
  GDVars.effectHandlers[76] := EffHndlr.EffNoneD;
  GDVars.effectHandlers[77] := EffHndlr.EffBerserk;
  GDVars.effectHandlers[78] := EffHndlr.EffSaveBonus;
  GDVars.effectHandlers[79] := EffHndlr.EffIronGolem;
  GDVars.effectHandlers[80] := EffHndlr.EffBreatheFireAtTarget;
  GDVars.effectHandlers[81] := EffHndlr.EffSpitAtTarget;
  GDVars.effectHandlers[82] := EffHndlr.EffDragonFear;
  GDVars.effectHandlers[84] := EffHndlr.EffNone;
  GDVars.effectHandlers[85] := EffHndlr.EffNone;
  GDVars.effectHandlers[86] := EffHndlr.EffStrongPoisonAttack;
  GDVars.effectHandlers[87] := EffHndlr.EffNone;
  GDVars.effectHandlers[88] := EffHndlr.EffGhoulPara;
  GDVars.effectHandlers[89] := EffHndlr.EffDisplaced;
  GDVars.effectHandlers[90] := EffHndlr.EffHalfBash;
  GDVars.effectHandlers[91] := EffHndlr.EffClearCloudkill;
  GDVars.effectHandlers[92] := EffHndlr.EffImmuneFear;
  GDVars.effectHandlers[93] := EffHndlr.EffImmuneFire;
  GDVars.effectHandlers[94] := EffHndlr.EffConPsnSave;
  GDVars.effectHandlers[95] := EffHndlr.EffElfResistance;
  GDVars.effectHandlers[96] := EffHndlr.EffImmuneSleepCharm;
  GDVars.effectHandlers[97] := EffHndlr.EffConSpellSave;
  GDVars.effectHandlers[98] := EffHndlr.EffImmuneCold;
  GDVars.effectHandlers[99] := EffHndlr.EffImmuneParalysisPoison;
  GDVars.effectHandlers[100] := EffHndlr.EffDelayedBlastFireball;
  GDVars.effectHandlers[101] := EffHndlr.EffNone;
  GDVars.effectHandlers[102] := EffHndlr.EffNone;
  GDVars.effectHandlers[103] := EffHndlr.EffWeaponResistance;
  GDVars.effectHandlers[C_Effect.RANGER_DAMAGE_BONUS] := EffHndlr.EffRangerDamageBonus;
  GDVars.effectHandlers[106] := EffHndlr.EffHelpless;
  GDVars.effectHandlers[107] := EffHndlr.EffConfusedBerserk;
  GDVars.effectHandlers[108] := EffHndlr.EffLastingInvisibility;
  GDVars.effectHandlers[109] := EffHndlr.EffNone;
  GDVars.effectHandlers[110] := EffHndlr.EffRecentCure;
  GDVars.effectHandlers[111] := EffHndlr.EffFear;
  GDVars.effectHandlers[112] := EffHndlr.EffZapAttacker;
  GDVars.effectHandlers[113] := EffHndlr.EffGiantStrength;
  GDVars.overrideHandler := EffHndlr.EffGrantItemEffect;
end;

procedure NoopEffHndlrA;
begin
end;

procedure NoopEffHndlrB;
begin
end;

begin
end.
