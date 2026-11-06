{ Key codes with the KEY_ prefix. }
unit C_Keys;

interface

const
  { Key codes: ReadKey's ASCII values and, after a #0 prefix, the extended scan codes. NONE is also a menu's result when
    nothing was chosen. }
  ENTER = #13;
  ESCAPE = #27;
  BACKSPACE = #8;
  UP = #72;
  DOWN = #80;
  LEFT = #75;
  RIGHT = #77;
  HOME = #71;
  END_KEY = #79;
  PAGE_UP = #73;
  PAGE_DOWN = #81;
  ALT_X = #45;
  ALT_M = #50;
  NONE = #0;

implementation

end.
