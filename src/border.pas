{ Screen-border and panel composition for the text-grid display. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Border;

interface

uses Types, Mouse, TextRend, GameIo, GDVars, Sym8x8;

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22) and draws the outer frame: horizontal rules
  across rows 0 and 23, and columns 0 and 39 from row 1 to row 22 with their top and bottom end pieces.
  @param(layout Unused.) }
procedure DrawWindowFrame(layout: Byte);

{ Clears the whole screen and draws the credits window: horizontal rules across rows 1 and 23 joined by plain side
  columns 0 and 39. Note: the end pieces for rows 2 and 22 are picked into tile but never drawn. }
procedure DrawCreditsFrame;

{ Draws the base frame through ScreenText, then a vertical rule down column 16 from row 1 to row 15 and an inner box
  with corners at columns 2 and 14, rows 2 and 14. }
procedure DrawExploreFrame;

{ Draws the side columns, the bottom rule and a horizontal rule across row 16 like ScreenText, but clears only rows
  1..16 inside the frame, leaving rows 17..22 as they were. }
procedure DrawMemorizeFrame;

{ Clears columns 1..38 of rows 1..21 and draws the combat layout: the side columns and bottom rule, a vertical rule down
  column 22 from row 1 to row 21 and a horizontal rule across row 22; row 23 is then cleared. }
procedure DrawCombatFrame;

{ Clears the screen inside the outer frame and draws the character sheet layout: the side columns and bottom rule,
  horizontal rules across rows 8, 16 and 20, and a vertical rule down column 19 from row 9 to row 19. }
procedure DrawCharViewFrame;

{ Clears rows 1..16 inside the outer frame and draws the side columns and the bottom rule. }
procedure DrawListFrame;

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory, with the mouse cursor
  hidden. CGA clears the four scanlines of each cell row in both of its banks, EGA clears both display pages, and Tandy
  clears two scanlines in each of its four banks.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Clears the screen inside the outer frame (columns 1..38, rows 1..22) and draws the side columns, the bottom rule and a
  horizontal rule across row 16. }
procedure ScreenText;

implementation
const
  { 8x8 border glyph selectors. The Sym8x8 symbol index = sel + 241, so sel 67/68/69 -> glyph 308/309/310 (top-corner /
    vertical-bar / bottom), sel 71/72/73 -> glyph 312/313/314 (inner-box variants). 311 = the full-width horizontal bar;
    315 = the inner-box horizontal. }
  { horizontal edge run }
  SYM_HBAR = 311;
  { plain vertical edge }
  SYM_VERT = 309;
  { junction / vertical top piece (used raw) }
  SYM_VTOP = 310;
  { junction / vertical bottom piece (used raw) }
  SYM_VBOT = 308;
  { inner-panel horizontal }
  SYM_INNERH = 315;
  { sel + 241 = symbol index }
  GLYPH_BIAS = 241;

procedure DrawWindowFrame(layout: Byte);
var
  column: Byte;
  row: Byte;
  tile: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  for column := 0 to 39 do begin
    Sym8x8.Put8x8Sym(ShortInt(column), ShortInt(0), Border.SYM_HBAR, Byte(False), Byte(False));
    Sym8x8.Put8x8Sym(ShortInt(column), ShortInt(23), Border.SYM_HBAR, Byte(False), Byte(False));
  end;
  for row := 1 to 22 do begin
    tile := 68;
    if row = 1 then tile := 67
    else if row = 22 then tile := 69;
    Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(row), tile + Border.GLYPH_BIAS, Byte(False), Byte(False));
    Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(row), tile + Border.GLYPH_BIAS, Byte(False), Byte(False));
  end;
  Mouse.ShowMouse;
end;

{ Draws a horizontal rule across a row and the junction pieces that join it to the side columns 0 and 39 on the rows
  just above and below.
  @param(row Row of the rule.) }
procedure DrawHRule(row: Byte);
var
  col: Byte;
begin
  for col := 0 to 39 do
    Sym8x8.Put8x8Sym(ShortInt(col), ShortInt(row), Border.SYM_HBAR, Byte(False), Byte(False));
  Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(row - 1), Border.SYM_VTOP, Byte(False), Byte(False));
  Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(row + 1), Border.SYM_VBOT, Byte(False), Byte(False));
  Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(row - 1), Border.SYM_VTOP, Byte(False), Byte(False));
  Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(row + 1), Border.SYM_VBOT, Byte(False), Byte(False));
end;

{ Draws the side columns 0 and 39 from row 2 to row 21, their end pieces on row 22 and the bottom rule across row 23,
  leaving the top open. }
procedure DrawSidesAndBottom;
var
  col: Byte;
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  sel: Byte;
begin
  for row := 2 to 21 do begin
    Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(row), Border.SYM_VERT, Byte(False), Byte(False));
    Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(row), Border.SYM_VERT, Byte(False), Byte(False));
  end;
  Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(22), Border.SYM_VTOP, Byte(False), Byte(False));
  Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(22), Border.SYM_VTOP, Byte(False), Byte(False));
  for col := 0 to 39 do
    Sym8x8.Put8x8Sym(ShortInt(col), ShortInt(23), Border.SYM_HBAR, Byte(False), Byte(False));
end;

procedure DrawCreditsFrame;
var
  column: Byte;
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tile: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 39, 23);
  for row := 1 to 23 do begin
    case row of
      1, 23:
        for column := 0 to 39 do
          Sym8x8.Put8x8Sym(ShortInt(column), ShortInt(row), Border.SYM_HBAR, Byte(False), Byte(False));
    else begin
        tile := 68;
        if row = 2 then tile := 67
        else if row = 22 then tile := 69;
        { Note: tile is computed and then not used; the side verticals draw a uniform 309. }
        Sym8x8.Put8x8Sym(ShortInt(0), ShortInt(row), Border.SYM_VERT, Byte(False), Byte(False));
        Sym8x8.Put8x8Sym(ShortInt(39), ShortInt(row), Border.SYM_VERT, Byte(False), Byte(False));
      end;
    end;
  end;
  Mouse.ShowMouse;
end;

procedure DrawExploreFrame;
var
  col: Byte;
  row: Byte;
  sel: Byte;
begin
  Mouse.HideMouse;
  Border.ScreenText;
  for row := 1 to 15 do begin
    sel := 68;
    if row = 1 then sel := 67
    else if row = 15 then sel := 69;
    Sym8x8.Put8x8Sym(ShortInt(16), ShortInt(row), sel + Border.GLYPH_BIAS, Byte(False), Byte(False));
  end;
  for col := 2 to 14 do begin
    Sym8x8.Put8x8Sym(ShortInt(col), ShortInt(2), Border.SYM_INNERH, Byte(False), Byte(False));
    Sym8x8.Put8x8Sym(ShortInt(col), ShortInt(14), Border.SYM_INNERH, Byte(False), Byte(False));
  end;
  for row := 3 to 13 do begin
    sel := 72;
    if row = 3 then sel := 71
    else if row = 13 then sel := 73;
    Sym8x8.Put8x8Sym(ShortInt(2), ShortInt(row), sel + Border.GLYPH_BIAS, Byte(False), Byte(False));
    Sym8x8.Put8x8Sym(ShortInt(14), ShortInt(row), sel + Border.GLYPH_BIAS, Byte(False), Byte(False));
  end;
  Mouse.ShowMouse;
end;

procedure ScreenText;
var
  { Unused in this version; see the other implementations of this routine. }
  row: Word;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawSidesAndBottom;
  Border.DrawHRule(16);
  Mouse.ShowMouse;
end;

procedure DrawMemorizeFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  column: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  tileOffset: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 16);
  Border.DrawSidesAndBottom;
  Border.DrawHRule(16);
  Mouse.ShowMouse;
end;

procedure DrawCombatFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  row: Byte;
  sel: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 21);
  Border.DrawSidesAndBottom;
  for row := 1 to 21 do begin
    sel := 68;
    if row = 1 then sel := 67
    else if row = 21 then sel := 69;
    Sym8x8.Put8x8Sym(ShortInt(22), ShortInt(row), sel + Border.GLYPH_BIAS, Byte(False), Byte(False));
  end;
  Border.DrawHRule(22);
  Border.ClearBox(0, 23, 39, 23);
  Mouse.ShowMouse;
end;

procedure DrawCharViewFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  row: Byte;
  sel: Byte;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 22);
  Border.DrawSidesAndBottom;
  Border.DrawHRule(8);
  for row := 9 to 19 do begin
    sel := 68;
    if row = 9 then sel := 67
    else if row = 19 then sel := 69;
    Sym8x8.Put8x8Sym(ShortInt(19), ShortInt(row), sel + Border.GLYPH_BIAS, Byte(False), Byte(False));
  end;
  Border.DrawHRule(16);
  Border.DrawHRule(20);
  Mouse.ShowMouse;
end;

procedure DrawListFrame;
var
  { Unused in this version; see the other implementations of this routine. }
  row: Word;
begin
  Mouse.HideMouse;
  Border.ClearBox(1, 1, 38, 16);
  Border.DrawSidesAndBottom;
  Mouse.ShowMouse;
end;

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  top: Word;
  bot: Word;
  colOff: Word;
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColOff: Word;
  r: Word;
begin
  Mouse.HideMouse;
  case GDVars.displayMode of
    Types.Cga:
      begin
        top := ulRow * 4;
        bot := lrRow * 4 + 3;
        rowBytes := (lrCol - ulCol + 1) * 2;
        for r := top to bot do begin
          GameIo.FillWord(TextRend.cgaBank0.bytes[r][ulCol * 2], rowBytes);
          GameIo.FillWord(TextRend.cgaBank1.bytes[r][ulCol * 2], rowBytes);
        end;
      end;
    Types.Ega:
      begin
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, 0);
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, 0);
      end;
    Types.Tandy:
      begin
        top := ulRow * 2;
        bot := lrRow * 2 + 1;
        colOff := ulCol * 4;
        rowBytes := (lrCol - ulCol + 1) * 4;
        for r := top to bot do begin
          GameIo.FillWord(TextRend.tandyBank0[r][colOff], rowBytes);
          GameIo.FillWord(TextRend.tandyBank1[r][colOff], rowBytes);
          GameIo.FillWord(TextRend.tandyBank2[r][colOff], rowBytes);
          GameIo.FillWord(TextRend.tandyBank3[r][colOff], rowBytes);
        end;
      end;
  end;
  Mouse.ShowMouse;
end;

begin
end.
