{ Initialize the command-line STING key, a copy of one of GDConsts' item-name fragments. }
{$F+,O-,S-,R-,V-,B-,I-}
unit ModeInit;
interface
implementation
uses GDConsts, GDVars;
begin
  GDVars.stingKey := GDConsts.itemNames[122];
end.
