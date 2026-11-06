{ Core keyboard, mouse, and joystick input.

  Central entry is ReadGameKey: it merges the BIOS keyboard with the mouse and joystick pollers and hosts a debug side
  channel gated by the command-line password "Woof": Ctrl-D toggles a debug.txt log, Ctrl-Z dumps a "who: <name> sp#:
  <n>" object list into it, and Ctrl-C aborts. Ctrl-S is the sound on/off toggle and is not behind the password. }
{$F+,O-,S-,R-,V-,B-,I-}
unit GameIo;

interface

uses Crt, Dos, Mouse, Joystick, SoundDrv, GDConsts, GDVars, C_Keys, C_Sound, Types;

{ Returns the next key. A waiting key is read at once. Otherwise the mouse, or the joystick when there is no mouse, is
  polled until it gives input or a key is pressed: a left or right mouse button gives Enter or Escape (and marks a mouse
  click), a joystick direction gives its key from joyKeyMap, and joystick buttons 1 and 2 give Enter and Escape; a key
  pressed meanwhile wins. With neither device it waits for a key, or returns #0 while the demo runs. Ctrl-S turns the
  sound off, or back on to Tandy or speaker sound, unless sound is guarded. With Woof as the first parameter, Ctrl-D
  turns the debug log (debug.txt) on or off, Ctrl-Z writes the effects of each creature to it while it is open, and
  Ctrl-C quits.
  @returns(The key, or #0 in the demo when none was waiting.) }
function ReadGameKey: Char;

{ Tells whether input is waiting.
  @returns(True when a key is waiting, a mouse button is down, or -- without a mouse -- a joystick button is down or the
    stick is out of the center.) }
function InputPending: Boolean;

{ Reads and discards every key waiting in the keyboard buffer. }
procedure FlushKeys;

{ Reads and discards one waiting input through ReadGameKey, so its control-key commands still work. }
procedure DiscardPendingKeys;

{ Reads an overlay for the overlay manager, as installed by GameBoot: calls the saved reader until that succeeds,
  beeping (4000 Hz, 20 ms) after each failure.
  @param(n The overlay to read, passed to the saved reader.)
  @returns(0, success.) }
function OverlayReadWithBeep(n: Word): Integer;

{ Clears a block of memory with word stores, in COREINP.OBJ.
  @param(dest The block.)
  @param(count Its size in bytes.) }
procedure FillWord(var dest; count: Word);

{ Ends the program: hides and resets the mouse, restores the saved sound mode and resets the sound driver, restores the
  startup video mode, closes the debug log if it is open, and halts. }
procedure ExitGame;

implementation

const
  KEY_CTRL_C = #3;
  KEY_CTRL_D = #4;
  KEY_CTRL_S = #19;
  KEY_CTRL_Z = #26;

var
  { the debug log file }
  debugFile: Text absolute GDVars.debugFile;

procedure ExitGame;
var
  { Unused in this version; see the other implementations of this routine. }
  videoMode: Word;
begin
  Mouse.HideMouse;
  Mouse.ResetMouse;
  GDVars.soundMode := GDVars.soundSaved;
  SoundDrv.SoundCommand(GDConsts.sfxReset);
  GDVars.regs.AH := 0;
  GDVars.regs.AL := GDVars.savedVideoMode;
  Intr($10, Registers(GDVars.regs));
  if GDVars.debugOn then
    Close(debugFile);
  Halt(0);
end;

{ Writes one line per effect on a creature to the debug log: its name and the effect's id.
  @param(node The creature.) }
procedure DumpSpells(node: Types.PCharRecord);
var
  cur: Types.PEffectRec;
begin
  cur := node^.effectsAddr;
  while cur <> nil do begin
    WriteLn(debugFile, 'who: ', node^.name, '  sp#: ', cur^.id);
    cur := cur^.next;
  end;
end;

function ReadGameKey: Char;
var
  { the key that was read }
  ch: Char;
  { Ctrl-Z list cursor }
  p: Types.PCharRecord;
  { poller direction/button word }
  dir: Integer;
  { poller zone }
  zone: Byte;
  { poller "produced input" flag }
  got: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  paramIndex: Byte;

  { Waits for a key or for joystick input, turning a button into Enter or Escape and a stick zone into its keypad key. }
  procedure TranslateJoystick;
  begin
    dir := 0;
    got := False;
    while (not KeyPressed) and not got do begin
      Joystick.GetJoystick(dir, zone);
      if (zone < 8) or ((dir <> 0) <> False) then begin
        if zone < 8 then
          ch := Char(GDConsts.joyKeyMap[zone])
        else
          case dir of
            1: ch := C_Keys.ENTER;
            2: ch := C_Keys.ESCAPE;
          end;
        got := True;
      end;
    end;
  end;

  { Waits for a key or a mouse button, turning the button into Enter or Escape and noting the mouse click. }
  procedure TranslateMouse;
  begin
    dir := 0;
    got := False;
    while (not KeyPressed) and not got do begin
      Mouse.GetMouse(dir, GDVars.mouseX, GDVars.mouseY);
      if dir <> 0 then begin
        case dir of
          { left -> Enter }
          1: ch := C_Keys.ENTER;
          { right -> Esc }
          2: ch := C_Keys.ESCAPE;
        end;
        GDVars.mouseClk := True;
        got := True;
      end;
    end;
  end;

begin
  GDVars.mouseClk := False;
  if KeyPressed then
    ch := ReadKey
  else if GDVars.joyOn or GDVars.mouseOn then begin
    if GDVars.mouseOn then TranslateMouse else TranslateJoystick;
    if KeyPressed then ch := ReadKey;
  end else if GDVars.demoMode then
    ch := #0
  else
    ch := ReadKey;

  { Ctrl-S: sound on/off toggle }
  if ch = GameIo.KEY_CTRL_S then begin
    if GDVars.soundGuard = 0 then
      if GDVars.soundMode <> C_Sound.OFF then begin
        GDVars.soundSaved := GDVars.soundMode;
        SoundDrv.SoundCommand(GDConsts.sfxOff);
        GDVars.soundMode := C_Sound.OFF;
      { unmute only to Tandy or speaker }
      end else if GDVars.soundSaved in [C_Sound.TANDY,
                                          C_Sound.SPEAKER] then begin
        GDVars.soundMode := GDVars.soundSaved;
        SoundDrv.SoundCommand(GDConsts.sfxOn);
      end;
  end;

  { the debug password }
  if ParamStr(1) = 'Woof' then
    case ch of
      { Ctrl-D: toggle debug.txt logging }
      GameIo.KEY_CTRL_D:
        begin
          GDVars.debugOn := not GDVars.debugOn;
          if GDVars.debugOn then begin
            Assign(debugFile, 'debug.txt');
            Rewrite(debugFile);
          end else
            Close(debugFile);
        end;
      { Ctrl-Z: dump the who/sp# list }
      GameIo.KEY_CTRL_Z:
        begin
          if GDVars.debugOn then begin
            p := GDVars.creatureList;
            while p <> nil do begin
              GameIo.DumpSpells(p);
              p := p^.nextCharAddr;
            end;
          end;
        end;
      { Ctrl-C: abort/teardown }
      GameIo.KEY_CTRL_C:
        GameIo.ExitGame;
    end;

  ReadGameKey := ch;
end;

function InputPending: Boolean;
var
  dir: Integer;
  zone: Byte;
begin
  InputPending := KeyPressed;
  if not (GDVars.joyOn or GDVars.mouseOn) then Exit;
  if GDVars.mouseOn then begin
    Mouse.GetMouse(dir, GDVars.mouseX, GDVars.mouseY);
    InputPending := KeyPressed or ((dir <> 0) <> False);
  end else begin
    Joystick.GetJoystick(dir, zone);
    InputPending := KeyPressed or ((dir > 0) <> False) or ((zone < 8) <> False);
  end;
end;

procedure FlushKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  ch: Char;
begin
  while KeyPressed do
    ch := ReadKey;
end;

procedure DiscardPendingKeys;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  if GameIo.InputPending then
    key := GameIo.ReadGameKey;
end;

function OverlayReadWithBeep(n: Word): Integer;
begin
  while GDVars.savedOvrRead(n) <> 0 do begin
    Sound(4000);
    Delay(20);
    NoSound;
  end;
  OverlayReadWithBeep := 0;
end;

{ Zero-fill `count` bytes at dest with word stores; despite the name it always clears. }
{$L COREINP.OBJ}
procedure FillWord(var dest; count: Word); external;

begin
end.
