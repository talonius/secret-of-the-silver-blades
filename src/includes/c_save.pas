{ Saving-throw categories with the SAVE_ prefix. }
unit C_Save;

interface

const
  { Saving-throw categories in AD&D order: indices into TCharRecord.saves and the saveType argument of
    FxEngine.RollSavingThrow }
  { paralyzation / poison / death magic }
  PARALYZATION = 0;
  { breath weapon }
  BREATH_WEAPON = 3;
  { spell }
  SPELL = 4;

implementation

end.
