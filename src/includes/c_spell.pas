{ Spell-definition and spell-slot values with the SPELL_ prefix. }
unit C_Spell;

interface

const
  { The spell list a spell belongs to (TSpellDef.castClass): cleric, druid (cast by rangers), magic-user, and special
    spells that no class casts. The three class lists also index the first dimension of TCharRecord.spellSlots. }
  CLERIC_LIST = 0;
  DRUID_LIST = 1;
  MAGE_LIST = 3;
  SPECIAL_LIST = 4;

  { TSpellDef.castContext -- where the spell may be cast }
  CAMP_ONLY = 0;

  { TCharRecord.memorizedSpells and TItemRec.spells hold the spell id in the low seven bits; 0 is an empty slot. }
  ID_MASK = $7F;
  { high bit: still being memorized or scribed; camp sets it, rest finishes it }
  PENDING_FLAG = $80;

implementation

end.
