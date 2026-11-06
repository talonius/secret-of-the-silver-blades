{ Character class values with the CLASS_ prefix. }
unit C_Class;

interface

const
  { TCharRecord.charClass. The single classes double as the index of TCharRecord.classLevelA and classLevelB. }
  CLERIC = 0;
  FIGHTER = 2;
  PALADIN = 3;
  RANGER = 4;
  MAGE = 5;
  THIEF = 6;
  CLERIC_FIGHTER = 8;
  CLERIC_FIGHTER_MAGE = 9;
  CLERIC_RANGER = 10;
  CLERIC_MAGE = 11;
  CLERIC_THIEF = 12;
  FIGHTER_MAGE = 13;
  FIGHTER_THIEF = 14;
  FIGHTER_MAGE_THIEF = 15;
  MAGE_THIEF = 16;

implementation

end.
