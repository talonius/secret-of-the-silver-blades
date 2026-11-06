{ Data-unit init: a LongInt global set to -1. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Ub74;
interface

uses GDVars;
implementation
begin
  GDVars.initMarker := -1;
end.
