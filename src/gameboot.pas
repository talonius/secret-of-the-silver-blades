{ The boot sequence: OvrInit, the write-protect check, the interactive first-run config menu (graphics, sound, input,
  save path), the config read-back, EGA/Tandy video and the heap reserve, the overlay buffer claim, and joystick
  calibration persistence. The whole unit is its initialization section. }
{$F+,O+,S-,R-,V-,B-,I-}
unit GameBoot;

interface

implementation

uses Types, Crt, Dos, Overlay, DaxIo, TextRend, Joystick, GameIo, GDConsts, GDVars, C_Sound;

const
  { paras reserved below heap top for Tandy graphics }
  GFX_RESERVE_PARAS = 1024;
  { overlay buffer size }
  OVERLAY_BUF_BYTES = 163840;
  { sound mode for the A (AdLib) config letter }
  SND_ADLIB = 2;

type
  THeapEndW = record o: Word; s: Word; extra: Word; end;

var
  ovrDbgFlag: Byte absolute CheckBreak;
  { view of System.FreePtr }
  heapEndW: THeapEndW absolute FreePtr;
  { Move source }
  heapTopBlk: Types.PFreeBlk absolute FreePtr;

{ Waits for a digit key in a range and echoes it.
  @param(min The lowest digit accepted.)
  @param(max The highest digit accepted.)
  @returns(The digit's value.) }
function ReadDigit(min, max: Byte): Byte;
begin
  repeat
    GDVars.keyChar := ReadKey;
  until (GDVars.keyChar in ['0'..'9']) and ((Ord(GDVars.keyChar) - Ord('0')) in [min..max]);
  Write(GDVars.keyChar);
  ReadDigit := Ord(GDVars.keyChar) - Ord('0');
end;

{ The unit initialization: the boot sequence. }
begin
  ClrScr;
  ovrDbgFlag := 0;
  DaxIo.OverlayPrompt;
  WriteLn('TANDY 1000 USERS - Make sure NUMLOCK is on.');
  OvrInit('GAME.OVR');

  { swap in the custom overlay reader }
  GDVars.savedOvrRead := OvrReadBuf;
  OvrReadBuf := GameIo.OverlayReadWithBeep;

  { locate the launch directory / drive letter }
  FSplit(FExpand('*.exe'), GDVars.gDataPath, GDVars.exeName, GDVars.exeExt);
  if GDVars.gDataPath[1] < 'C' then
  begin
    if GDVars.gDataPath[1] = 'A' then
      { booted from A: -> data on B: }
      GDVars.gAltPath := 'B:\'
    else
      { booted from B: -> data on A: }
      GDVars.gAltPath := 'A:\';
  end else
    { hard drive: own dir }
    GDVars.gAltPath := GDVars.gDataPath;
  GDVars.gPromptDrive := GDVars.gAltPath[1];

  if not DaxIo.FileExists(GDConsts.cfgName) then begin
    { -------- first run: build the config interactively -------- }
    Delay(2000);
    Assign(GDVars.cfgFile, GDConsts.cfgName);
    Rewrite(GDVars.cfgFile);
    GDVars.ioErr := IOResult;
    if GDVars.ioErr <> 0 then begin
      { copy-protection: write-protected boot disk = pirated master }
      ClrScr;
      WriteLn('Sorry, disk A can''t be write-protected.');
      WriteLn;
      WriteLn('If these are your masters, use DISKCOPY to make duplicates.');
      Halt(1);
    end;

    ClrScr;
    Write('GRAPHICS ADAPTER TYPE:  [1] CGA  [2] EGA  [3] Tandy  ');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgFile, 'C');
      2: WriteLn(GDVars.cfgFile, 'E');
      3: WriteLn(GDVars.cfgFile, 'T');
    end;

    ClrScr;
    WriteLn('SOUND TYPE:  [1] AdLib');
    WriteLn('             [2] Tandy 1000');
    WriteLn('             [3] PC speaker');
    WriteLn('             [4] Silent');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 4);
    case GDVars.menuChoice of
      1: WriteLn(GDVars.cfgFile, 'A');
      2: WriteLn(GDVars.cfgFile, 'T');
      3: WriteLn(GDVars.cfgFile, 'P');
      4: WriteLn(GDVars.cfgFile, 'S');
    end;

    GDVars.joyOn := False;
    ClrScr;
    Write('ALTERNATE INPUT TYPE:  [1] JOYSTICK  [2] MOUSE  [3] NEITHER  ');
    GDVars.menuChoice := GameBoot.ReadDigit(1, 3);
    case GDVars.menuChoice of
      1: begin WriteLn(GDVars.cfgFile, 'J'); GDVars.joyOn := True; end;
      2: WriteLn(GDVars.cfgFile, 'M');
      3: WriteLn(GDVars.cfgFile, 'N');
    end;

    { save-path prompt }
    ClrScr;
    GDVars.fsPath := GDVars.gAltPath + 'SAVE';
    Write('PATH TO SAVE DATA (DEFAULT - ' + GDVars.fsPath + '):  ');
    ReadLn(GDVars.pathBuf);
    GDVars.pathBuf[1] := UpCase(GDVars.pathBuf[1]);

    if not ((Length(GDVars.pathBuf) >= 4) and (GDVars.pathBuf[2] = ':') and
            (not (GDVars.pathBuf[1] in ['A',
                                        'B']) or (GDVars.pathBuf[1] <> GDVars.gDataPath[1])) and
                                        (GDVars.pathBuf[1] in ['A'..'P'])) then
    begin
      GDVars.pathBuf := GDVars.fsPath;
      WriteLn('USING DEFAULT PATH: ' + GDVars.pathBuf);
      Delay(2000);
    end;

    for GDVars.ix := 1 to Length(GDVars.pathBuf) do
      GDVars.pathBuf[GDVars.ix] := UpCase(GDVars.pathBuf[GDVars.ix]);
    if GDVars.pathBuf[Length(GDVars.pathBuf)] <> '\' then
      GDVars.pathBuf := GDVars.pathBuf + '\';
    WriteLn(GDVars.cfgFile, GDVars.pathBuf);
    WriteLn(GDVars.cfgFile, 'F');

    Joystick.CalibrateJoystick;
    for GDVars.ix := 0 to 6 do begin
      WriteLn(GDVars.cfgFile, GDVars.joyCal[1].x.words[GDVars.ix]);
      WriteLn(GDVars.cfgFile, GDVars.joyCal[1].y.words[GDVars.ix]);
    end;
    Close(GDVars.cfgFile);
  end;

  { -------- read-back path -------- }
  Assign(GDVars.cfgFile, GDConsts.cfgName);
  Reset(GDVars.cfgFile);
  { display-type char }
  ReadLn(GDVars.cfgFile, GDVars.keyChar);

  GDVars.regs.ah := $0F;
  Intr($10, Registers(GDVars.regs));
  GDVars.savedVideoMode := GDVars.regs.al;
  GDVars.curVideoMode := GDVars.savedVideoMode;

  case GDVars.keyChar of
    'E': begin
      GDVars.displayMode := Types.Ega;
      GDVars.curEgaPage := 0;
      GDVars.otherEgaPage := 0;
      TextRend.SetupEgaCurrentPage(GDVars.curEgaPage);
      TextRend.SetupEgaOtherPage(GDVars.otherEgaPage);
    end;
    'T': begin
      GDVars.displayMode := Types.Tandy;
      GDVars.gfxTmp := Ptr(heapEndW.s - GameBoot.GFX_RESERVE_PARAS, heapEndW.o);
      Move(heapTopBlk^, GDVars.gfxTmp^, SizeOf(Types.TFreeBlk));
      FreePtr := GDVars.gfxTmp;
      heapEndW.extra := 80;
      GDVars.gfxReserve := FreePtr;
    end;
    else GDVars.displayMode := Types.Cga;
  end;

  if GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf <= MemAvail then
    OvrSetBuf(GameBoot.OVERLAY_BUF_BYTES)
  else begin
    WriteLn('Not enough memory to run game.  You need ', GameBoot.OVERLAY_BUF_BYTES - OvrGetBuf - MemAvail,
      ' more bytes.');
    Halt;
  end;
  if OvrResult <> 0 then begin
    WriteLn('Overlay error, program abort!');
    Halt;
  end;

  { sound-type char }
  ReadLn(GDVars.cfgFile, GDVars.keyChar);
  case GDVars.keyChar of
    'A': GDVars.soundMode := GameBoot.SND_ADLIB;
    'T': GDVars.soundMode := C_Sound.TANDY;
    'P': GDVars.soundMode := C_Sound.SPEAKER;
    else GDVars.soundMode := C_Sound.OFF;
  end;

  { input-type char }
  ReadLn(GDVars.cfgFile, GDVars.keyChar);
  case GDVars.keyChar of
    'J': begin GDVars.joyOn := True; GDVars.mouseOn := False; end;
    'M': begin GDVars.mouseOn := True; GDVars.joyOn := False; end;
    'N': begin GDVars.mouseOn := False; GDVars.joyOn := False; end;
  end;

  ReadLn(GDVars.cfgFile, GDVars.saveDir);
  { full-intro char }
  ReadLn(GDVars.cfgFile, GDVars.keyChar);
  if GDVars.keyChar = 'F' then
    GDVars.fullIntro := True
  else
    GDVars.fullIntro := False;

  Joystick.ProbeJoystick;
  if GDVars.joyOn then
    for GDVars.ix := 0 to 6 do begin
      ReadLn(GDVars.cfgFile, GDVars.joyCal[1].x.words[GDVars.ix]);
      ReadLn(GDVars.cfgFile, GDVars.joyCal[1].y.words[GDVars.ix]);
    end;
  Close(GDVars.cfgFile);
end.
