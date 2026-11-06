{ Effect ids (TEffectRec.id) with the EFF_ prefix. }
unit C_Effect;

interface

const
  { the paladin's protection: against an evil creature, 2 onto the saving-throw roll and 2 off the attack roll }
  PROTECTION_FROM_EVIL = 8;
  { grants strength through FxEngine.StrengthEffectToStrength }
  ENLARGE = 12;
  { removed with POISONED when poison is cured }
  SLOW_POISON_HIT = 15;
  { removed with POISONED when poison is cured }
  SLOW_POISON_END = 22;
  { set by the invisibility handlers }
  INVISIBLE = 25;
  { 'starts to cough' (Stinking Cloud, saved) }
  STINKING_CLOUD_COUGH = 30;
  { added when disease drives strength down to 3 }
  HELPLESS = 31;
  { cured as blindness ('regains sight', 'can see!') }
  BLIND = 33;
  { counted with the disease effects }
  DISEASED = 34;
  { removed by Remove Curse ('un-cursed') }
  BESTOW_CURSE = 36;
  { strength bonus read by FxEngine.StrengthEffectToStrength }
  STRENGTH = 38;
  { doubles movement (recalcStats) }
  HASTED = 39;
  { halves movement (recalcStats); Haste removes it }
  SLOWED = 42;
  { cured by Neutralize Poison ('is detoxified') }
  POISONED = 55;
  { Feeblemind; Heal removes it }
  FEEBLEMINDED = 68;
  { the ranger's damage bonus: the ranger level, added against an adjacent target of the giant class }
  RANGER_DAMAGE_BONUS = 105;

implementation

end.
