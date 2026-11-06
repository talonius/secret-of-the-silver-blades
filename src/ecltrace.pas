{ ECL opcode debug trace: OpName maps an ECL opcode number to its mnemonic, and ShowTrace displays the current opcode
  name and three operand bytes when the trace flag is set. }
{$O+,F+}
unit EclTrace;

interface

uses TextRend, Crt, GDVars, Types;

{ While debugOn is set, prints the three bytes on row 0, shows name on the bottom row and waits for a key, then clears
  row 0.
  @param(name The trace text.)
  @param(a First byte shown.)
  @param(b Second byte shown.)
  @param(c Third byte shown.) }
procedure ShowTrace(name: Types.TStr40; a, b, c: Byte);

{ Returns the mnemonic of the current script opcode (GDVars.curOp) for the interpreter's debug trace; an unknown opcode
  gives 'BULLSHIT' followed by op. Note: the subtract opcode's mnemonic is spelled SUBTRAT.
  @param(op The opcode number shown for an unknown opcode.)
  @returns(The mnemonic.) }
function OpName(op: Byte): String;

implementation

function OpName(op: Byte): String;
var
  s: String;
begin
  case GDVars.curOp of
    0: OpName := 'EXIT';
    1: OpName := 'GOTO';
    2: OpName := 'GOSUB';
    3: OpName := 'COMPARE';
    4: OpName := 'ADD';
    5: OpName := 'SUBTRAT';
    6: OpName := 'DIVIDE';
    7: OpName := 'MULTIPLY';
    8: OpName := 'RANDOM';
    9: OpName := 'SAVE';
    10: OpName := 'LOAD CHARACTER';
    11: OpName := 'LOAD MONSTER';
    12: OpName := 'SETUP MONSTER';
    13: OpName := 'APPROACH';
    14: OpName := 'PICTURE';
    15: OpName := 'INPUT NUMBER';
    16: OpName := 'INPUT STRING';
    17: OpName := 'PRINT';
    18: OpName := 'PRINTCLEAR';
    19: OpName := 'RETURN';
    20: OpName := 'COMPARE AND';
    21: OpName := 'VERTICAL MENU';
    22: OpName := 'IF = ';
    23: OpName := 'IF <>';
    24: OpName := 'IF <';
    25: OpName := 'IF >';
    26: OpName := 'IF <=';
    27: OpName := 'IF >=';
    28: OpName := 'CLEARMONSTERS';
    29: OpName := 'PARTYSTRENGTH';
    30: OpName := 'CHECKPARTY';
    32: OpName := 'NEWECL';
    33: OpName := 'LOAD FILES';
    55: OpName := 'LOAD PIECES';
    34: OpName := 'PARTY SURPRISE';
    35: OpName := 'SURPRISE';
    36: OpName := 'COMBAT';
    37: OpName := 'ON GOTO';
    38: OpName := 'ON GOSUB';
    39: OpName := 'TREASURE';
    40: OpName := 'ROB';
    41: OpName := 'ENCOUNTER MENU';
    42: OpName := 'GETTABLE';
    43: OpName := 'HORIZONTAL MENU';
    44: OpName := 'PARLAY';
    45: OpName := 'CALL';
    46: OpName := 'DAMAGE';
    47: OpName := 'AND';
    48: OpName := 'OR';
    49: OpName := 'SPRITE OFF';
    50: OpName := 'FIND ITEM';
    51: OpName := 'PRINT RETURN';
    52: OpName := 'ECL CLOCK';
    53: OpName := 'SAVE TABLE';
    54: OpName := 'ADD NPC';
    56: OpName := 'PROGRAM';
    57: OpName := 'WHO';
    58: OpName := 'DELAY';
    59: OpName := 'SPELL';
    60: OpName := 'PROTECTION';
    61: OpName := 'CLEAR BOX';
    62: OpName := 'DUMP';
    63: OpName := 'FIND SPECIAL';
    64: OpName := 'DESTROY ITEMS';
    65: OpName := 'ADD EP';
  else begin
      Str(op, s);
      OpName := 'BULLSHIT ' + s;
    end;
  end;
end;

procedure ShowTrace(name: Types.TStr40; a, b, c: Byte);
var
  sa: String;
  sb: String;
  sc: String;
  { Unused in this version; see the other implementations of this routine. }
  lineIndex: Byte;
begin
  if GDVars.debugOn then begin
    Str(a, sa);
    Str(b, sb);
    Str(c, sc);
    TextRend.ClearRect(0, 0, 39, 0);
    TextRend.DisplayString(0, 0, Yellow, 0, sa + ' , ' + sb + ' , ' + sc);
    TextRend.DisplayAndPause(Yellow, 0, name);
    TextRend.ClearRect(0, 0, 39, 0);
  end;
end;

begin
end.
