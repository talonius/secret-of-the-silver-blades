{ INT 33h mouse driver. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Mouse;

interface

uses Dos, GDVars, C_Keys;

{ Resets the mouse driver through INT 33h; when a driver answers, marks the mouse present and records the button count,
  otherwise marks it absent. }
procedure InitMouse;

{ Shows the mouse cursor. Does nothing without a mouse. }
procedure ShowMouse;

{ Hides the mouse cursor. Does nothing without a mouse. }
procedure HideMouse;

{ Reads the mouse buttons and position, halving the column unless the mouse's scale flag is set. Does nothing without a
  mouse.
  @param(buttons Receives the button state.)
  @param(x Receives the column.)
  @param(y Receives the row.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the mouse cursor, doubling the column unless the mouse's scale flag is set. Does nothing without a mouse.
  @param(x Column.)
  @param(y Row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor shape and hot spot. Does nothing without a mouse.
  @param(hotX Hot spot column within the cursor.)
  @param(hotY Hot spot row within the cursor.)
  @param(mask Screen and cursor masks of the shape.) }
procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);

{ Resets the mouse driver's software state. Does nothing without a mouse. }
procedure ResetMouse;

{ Classifies a mouse move into one of eight 45-degree sectors and returns the matching keypad key. The slopes 618/256
  and 106/256 stand for tan 67.5 and tan 22.5 degrees; the sectors are tried clockwise from up, so a move with no motion
  counts as up. Note: the horizontal change times 618 overflows an Integer for moves wider than 53 units, which can give
  the wrong direction.
  @param(oldX Starting column.)
  @param(oldY Starting row.)
  @param(newX Ending column.)
  @param(newY Ending row.)
  @returns(The scan code of the arrow, Home, End, Page Up or Page Down key for that direction.) }
function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;

implementation

procedure InitMouse;
begin
  GDVars.regs.AX := 0;
  Intr($33, Registers(GDVars.regs));
  if GDVars.regs.AX = $FFFF then begin
    GDVars.buttonCount := GDVars.regs.BX;
    GDVars.mouseOn := True;
  end else
    GDVars.mouseOn := False;
end;

procedure ShowMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := 1;
  Intr($33, Registers(GDVars.regs));
end;

procedure HideMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := 2;
  Intr($33, Registers(GDVars.regs));
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := 3;
  Intr($33, Registers(GDVars.regs));
  buttons := GDVars.regs.BX;
  x := GDVars.regs.CX;
  if not GDVars.mouseScaled then
    x := x div 2;
  y := GDVars.regs.DX;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := 4;
  if not GDVars.mouseScaled then
    x := x shl 1;
  GDVars.regs.CX := x;
  GDVars.regs.DX := y;
  Intr($33, Registers(GDVars.regs));
end;

procedure SetMouseCursor(hotX, hotY: Integer; mask: Pointer);
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := 9;
  GDVars.regs.BX := hotX;
  GDVars.regs.CX := hotY;
  GDVars.regs.ES := Seg(mask^);
  GDVars.regs.DX := Ofs(mask^);
  Intr($33, Registers(GDVars.regs));
end;

procedure ResetMouse;
begin
  if not GDVars.mouseOn then
    Exit;
  GDVars.regs.AX := $21;
  Intr($33, Registers(GDVars.regs));
end;

function MouseDirection(oldX, oldY, newX, newY: Integer): Byte;
var
  i: Byte;
  found: Boolean;
  scanCode: Byte;
  dx: Integer;
  dy: Integer;
begin
  dx := Abs(newX - oldX);
  dy := Abs(newY - oldY);
  i := 0;
  found := False;
  while not found do begin
    case i of
      0: begin
           found := (newY <= oldY) and (dx * 618 div 256 <= dy);
           scanCode := Ord(C_Keys.UP);
         end;
      2: begin
           found := (newX >= oldX) and (dx * 106 div 256 >= dy);
           scanCode := Ord(C_Keys.RIGHT);
         end;
      4: begin
           found := (newY >= oldY) and (dx * 618 div 256 <= dy);
           scanCode := Ord(C_Keys.DOWN);
         end;
      6: begin
           found := (newX <= oldX) and (dx * 106 div 256 >= dy);
           scanCode := Ord(C_Keys.LEFT);
         end;
      1: begin
           found := (newY < oldY) and (newX > oldX) and (dx * 618 div 256 >= dy) and (dx * 106 div 256 <= dy);
           scanCode := Ord(C_Keys.PAGE_UP);
         end;
      3: begin
           found := (newY > oldY) and (newX > oldX) and (dx * 618 div 256 >= dy) and (dx * 106 div 256 <= dy);
           scanCode := Ord(C_Keys.PAGE_DOWN);
         end;
      5: begin
           found := (newY > oldY) and (newX < oldX) and (dx * 618 div 256 >= dy) and (dx * 106 div 256 <= dy);
           scanCode := Ord(C_Keys.END_KEY);
         end;
      7: begin
           found := (newY < oldY) and (newX < oldX) and (dx * 618 div 256 >= dy) and (dx * 106 div 256 <= dy);
           scanCode := Ord(C_Keys.HOME);
         end;
    end;
    if not found then
      Inc(i);
  end;
  MouseDirection := scanCode;
end;

begin
end.
