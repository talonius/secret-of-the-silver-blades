{ Game-port joystick input and calibration.

  The Pascal routines probe, calibrate, classify axis zones, and expose button state. ReadJoystick is the linked
  JOYSTICK.OBJ sampling leaf. }
{$F+,O-,S-,R-,V-,B-,I-}
unit Joystick;

interface

uses Crt, GDConsts, GDVars;

{ Clears both calibration records; when the joystick is enabled, keeps it enabled only if joystick 1 can be read. }
procedure ProbeJoystick;

{ Reads a joystick and places each axis among its calibrated boundaries 1..5, then looks the column and row up in the
  zone map.
  @param(joy Joystick 1 or 2.)
  @returns(The zone from the zone map, or the no-zone value when the joystick is off or cannot be read.) }
function JoyZone(joy: Byte): Byte;

{ Tells whether a joystick button is pressed. Joystick 1's buttons are bits 0 and 1 of the button byte, joystick 2's
  bits 2 and 3; another joystick or button number reads as not pressed.
  @param(joy Joystick 1 or 2.)
  @param(button Button 1 or 2.)
  @returns(True when the button is down; False when the joystick is off or cannot be read.) }
function JoyButton(joy, button: Byte): Boolean;

{ Reads joystick 1 as input: a pressed button and the stick's zone.
  @param(dir Receives 2 when button 2 is down, else 1 when button 1 is down, else 0.)
  @param(zone Receives the stick's zone, from JoyZone.) }
procedure GetJoystick(var dir: Integer; var zone: Byte);

{ Calibrates joystick 1 and enables it. The center is the average of 20 readings; the player then holds the stick at the
  upper-left and lower-right extremes with button 1 down, each taken as the extreme of 20 readings, and the boundaries
  lie a third and two thirds of the way from each extreme to the center. 20000 polls without a press, or a failed read,
  abort the calibration with a message. Does nothing when the joystick cannot be read. }
procedure CalibrateJoystick;

{ Reads a joystick from the game port, timing each axis's capacitor discharge.
  @param(joy Joystick 1 or 2; any other number fails.)
  @param(xRaw Receives the X axis count.)
  @param(yRaw Receives the Y axis count.)
  @param(buttons Receives all four button bits of both joysticks, inverted so a set bit is a pressed button and shifted
    to the low nibble.)
  @returns(True when the read succeeded; False for a bad joystick number or when an axis times out.) }
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;

implementation

{$L JOYSTICK.OBJ}
function ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
  external;

procedure ProbeJoystick;
var
  x: Word;
  y: Word;
  b: Byte;
begin
  FillChar(GDVars.joyCal, SizeOf(GDVars.joyCal), 0);
  if GDVars.joyOn then
    GDVars.joyOn := Joystick.ReadJoystick(1, x, y, b);
end;

function JoyZone(joy: Byte): Byte;
var
  x: Word;
  y: Word;
  col: Integer;
  row: Integer;
  b: Byte;
  { Unused in this version; see the other implementations of this routine. }
  boundaryIndex: Integer;
begin
  JoyZone := 8;
  if not GDVars.joyOn then
    Exit;
  if not Joystick.ReadJoystick(joy, x, y, b) then
    Exit;
  col := 0;
  for GDVars.loopIdx := 1 to 5 do
    if GDVars.joyCal[joy].x.thr[GDVars.loopIdx] < x then
      col := GDVars.loopIdx;
  row := 0;
  for GDVars.loopIdx := 1 to 5 do
    if GDVars.joyCal[joy].y.thr[GDVars.loopIdx] < y then
      row := GDVars.loopIdx;
  JoyZone := GDConsts.zoneMap[row, col];
end;

function JoyButton(joy, button: Byte): Boolean;
var
  mask: Byte;
  x: Word;
  y: Word;
  b: Byte;
begin
  JoyButton := False;
  if not GDVars.joyOn then
    Exit;
  mask := 0;
  b := 0;
  if Joystick.ReadJoystick(joy, x, y, b) then
    case joy of
      1: case button of
           1: mask := 1;
           2: mask := 2;
         end;
      2: case button of
           1: mask := 4;
           2: mask := 8;
         end;
    end;
  JoyButton := (b and mask) > 0;
end;

procedure GetJoystick(var dir: Integer; var zone: Byte);
begin
  dir := 0;
  if Joystick.JoyButton(1, 2) then
    dir := 2
  else if Joystick.JoyButton(1, 1) then
    dir := 1;
  zone := Joystick.JoyZone(1);
end;

procedure CalibrateJoystick;
var
  sumX: Word;
  sumY: Word;
  ok: Byte;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  reading: Byte;
  j: Word;
  buttons: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.joyOn then
    Exit;
  sumX := 0;
  sumY := 0;
  for j := 1 to 20 do begin
    ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
    Inc(sumX, x);
    Inc(sumY, y);
  end;
  GDVars.joyCal[1].x.thr[3] := sumX div 20;
  GDVars.joyCal[1].y.thr[3] := sumY div 20;
  { --- upper-left corner --- }
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme upper left position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j);
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 65535;
    sumY := 65535;
    for GDVars.loopIdx := 1 to 20 do begin
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x < sumX then
            sumX := x;
          if y < sumY then
            sumY := y;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
    end;
  until ok <> 0;
  GDVars.joyCal[1].x.lo := sumX;
  GDVars.joyCal[1].x.thr[1] := GDVars.joyCal[1].x.lo + (GDVars.joyCal[1].x.thr[3] - GDVars.joyCal[1].x.lo) div 3;
  GDVars.joyCal[1].x.thr[2] := GDVars.joyCal[1].x.lo + (GDVars.joyCal[1].x.thr[3] - GDVars.joyCal[1].x.lo) * 2 div 3;
  GDVars.joyCal[1].y.lo := sumY;
  GDVars.joyCal[1].y.thr[1] := GDVars.joyCal[1].y.lo + (GDVars.joyCal[1].y.thr[3] - GDVars.joyCal[1].y.lo) div 3;
  GDVars.joyCal[1].y.thr[2] := GDVars.joyCal[1].y.lo + (GDVars.joyCal[1].y.thr[3] - GDVars.joyCal[1].y.lo) * 2 div 3;
  repeat
  until not Joystick.JoyButton(1, 1);
  { --- lower-right corner --- }
  repeat
    ClrScr;
    WriteLn('Push JOYSTICK #1 to the extreme lower right position and press BUTTON #1.');
    j := 0;
    repeat
      ok := Byte(Joystick.ReadJoystick(1, x, y, buttons));
      Inc(j);
    until (j > 20000) or ((ok <> 0) and ((buttons and 1) <> 0));
    if j > 20000 then begin
      ClrScr;
      WriteLn('Couldn''t read the joystick.  Aborting calibration.');
      Delay(2000);
      Exit;
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.loopIdx := 1 to 20 do begin
      if Joystick.ReadJoystick(1, x, y, buttons) then begin
        if (buttons and 1) <> 0 then begin
          if x > sumX then
            sumX := x;
          if y > sumY then
            sumY := y;
        end;
      end else begin
        ClrScr;
        WriteLn('Couldn''t read the joystick.  Aborting calibration.');
        Delay(2000);
        Exit;
      end;
    end;
  until ok <> 0;
  GDVars.joyCal[1].x.hi := sumX;
  GDVars.joyCal[1].x.thr[4] := GDVars.joyCal[1].x.thr[3] + (GDVars.joyCal[1].x.hi - GDVars.joyCal[1].x.thr[3]) div 3;
  GDVars.joyCal[1].x.thr[5] := GDVars.joyCal[1].x.thr[3] +
    (GDVars.joyCal[1].x.hi - GDVars.joyCal[1].x.thr[3]) * 2 div 3;
  GDVars.joyCal[1].y.hi := sumY;
  GDVars.joyCal[1].y.thr[4] := GDVars.joyCal[1].y.thr[3] + (GDVars.joyCal[1].y.hi - GDVars.joyCal[1].y.thr[3]) div 3;
  GDVars.joyCal[1].y.thr[5] := GDVars.joyCal[1].y.thr[3] +
    (GDVars.joyCal[1].y.hi - GDVars.joyCal[1].y.thr[3]) * 2 div 3;
  GDVars.joyOn := True;
end;

begin
end.
