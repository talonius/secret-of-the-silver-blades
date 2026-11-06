{ Sound driver loading and management: load SOUND.dax, install the driver as a procvar, and send it commands. }
{$O+,F+,I-}
unit SndLoad;

interface

uses Blit, GameIo, DaxIo, GDVars, Types;

{ Saves the speaker port ($61) and installs the sound driver loaded at p as the sound procedure, through a far pointer
  moved to the driver's entry, and calls its setup command (0) with the offset and segment of data. Halts when p is not
  paragraph-aligned.
  @param(p The driver's code, paragraph-aligned.)
  @param(data The music data.) }
procedure InstallSoundDriver(p: Pointer; data: Pointer);

{ Sends the driver command 1 (play) with x as both arguments.
  @param(x The music number.) }
procedure PlaySound(x: Word);

{ Empty routine with no callers. }
procedure NoopSndLoad;

{ Sends the driver command 3 (stop), then restores the speaker port ($61) InstallSoundDriver saved. }
procedure StopSound;

{ Frees the sound driver's code buffer and the music data. }
procedure FreeSoundBuffers;

{ Loads the sound driver's code (block 1 of SOUND.DAX) into a paragraph-aligned buffer and the music data (block 2);
  either failing is reported in text mode and quits after a key. }
procedure LoadSound;

{ Calls the installed sound driver with a command and two arguments, which it takes in reverse order.
  @param(cmd The command.)
  @param(firstArg First argument.)
  @param(secondArg Second argument.)
  @returns(The driver's result.) }
function CallSoundDriver(cmd, firstArg, secondArg: Word): Word;

implementation
const
  { PC speaker control (8255 port B) }
  SPEAKER_PORT = $61;

function CallSoundDriver(cmd, firstArg, secondArg: Word): Word;
begin
  { the arguments go to the handler in reverse order }
  CallSoundDriver := GDVars.sndProc(secondArg, firstArg, cmd);
end;

procedure FreeSoundBuffers;
begin
  FreeMem(GDVars.comPtr, GDVars.comSize + 606);
  FreeMem(GDVars.sndPtr, GDVars.sndSize);
end;

procedure LoadSound;
var
  buf: Types.PByteArr;
  { Unused in this version; see the other implementations of this routine. }
  swallowedKey: Byte;
begin
  buf := nil;
  DaxIo.LoadDax('SOUND', '.dax', 1, GDVars.comSize, buf);
  if GDVars.comSize = 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('unable to load com file');
    swallowedKey := Ord(GameIo.ReadGameKey);
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  { paragraph-align the raw allocation }
  GetMem(GDVars.comPtr, GDVars.comSize + 606);
  FillChar(GDVars.comPtr^, GDVars.comSize + 606, 0);
  GDVars.workPtr := GDVars.comPtr;
  if (LongInt(GDVars.workPtr) and $F) > 0 then begin
    Inc(LongInt(GDVars.workPtr), $10000);
    LongInt(GDVars.workPtr) := LongInt(GDVars.workPtr) and $FFFF0000;
  end;
  LongInt(GDVars.workPtr) := ((LongInt(GDVars.workPtr) and $FFF0) shl 12) + LongInt(GDVars.workPtr);
  LongInt(GDVars.workPtr) := LongInt(GDVars.workPtr) and $FFFF0000;
  GDVars.alignPtr := GDVars.workPtr;
  Move(buf^, GDVars.alignPtr^, GDVars.comSize);
  FreeMem(buf, GDVars.comSize);
  DaxIo.LoadDax('SOUND', '.dax', 2, GDVars.sndSize, buf);
  if GDVars.sndSize = 0 then begin
    Blit.RestoreVideoMode;
    WriteLn('unable to load sound data');
    swallowedKey := Ord(GameIo.ReadGameKey);
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  GDVars.sndPtr := buf;
end;

procedure InstallSoundDriver(p: Pointer; data: Pointer);
begin
  GDVars.savedSpeakerPort := Port[SndLoad.SPEAKER_PORT];
  { halt unless paragraph-aligned, then shift $10 paragraphs from the segment into the offset }
  if Byte(LongInt(p) and $F) <> 0 then
    Halt(0);
  Inc(LongInt(p), $100);
  Dec(LongInt(p), $100000);
  GDVars.sndProc := Types.TSndProc(p);
  Move(data, GDVars.sndArg, SizeOf(GDVars.sndArg));
  GDVars.setupArg0 := GDVars.sndArg[0];
  GDVars.setupArg1 := GDVars.sndArg[1];
  GDVars.sndRes := SndLoad.CallSoundDriver(0, GDVars.setupArg0, GDVars.setupArg1);
end;

procedure PlaySound(x: Word);
begin
  GDVars.sndRes := SndLoad.CallSoundDriver(1, x, x);
end;

procedure StopSound;
begin
  GDVars.sndRes := SndLoad.CallSoundDriver(3, 0, 0);
  Port[SndLoad.SPEAKER_PORT] := GDVars.savedSpeakerPort;
end;

procedure NoopSndLoad;
begin
end;

begin
end.
