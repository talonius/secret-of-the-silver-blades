{ Interrupt-driven PC-speaker and Tandy SN76489 sound driver.

  The Pascal front end submits commands and suspends playback. SOUNDDRV.OBJ owns the note and music tables, interrupt
  service routine, sequencer, and voice writers linked after the unit initialization body. }
{$F+,O-,S-,R-,V-,B-,I-}
unit SoundDrv;

interface

{ Sends a command to the sound driver; a command whose low byte is not 0..15 or 255 is ignored, and with sound off only
  command 15 acts. 0 silences both banks of voices, 1 sets the voice byte to 1, 15 arms the driver's forced-exit
  countdown with 5000 ticks, and 255 silences the voices, removes the driver and marks sound inactive; any other command
  plays sound cmd - 1 on the Tandy voices in Tandy mode and on the PC speaker otherwise.
  @param(cmd The command.) }
procedure SoundCommand(cmd: Word);

{ Starts sound: remembers the sound mode and marks sound active, then, unless sound is off, installs the driver's timer
  interrupt and silences both banks of voices. }
procedure StartSound;

implementation
uses GDVars, C_Sound;

{ The driver's entry points, in SOUNDDRV.OBJ. }
{$L SOUNDDRV.OBJ}
{ Starts a sound on the Tandy voices; sound 0 silences them.
  @param(song The sound number.) }
procedure ProgramTandyVoices(song: Word); external;

{ Starts a sound on the PC-speaker voices; sound 0 silences them.
  @param(song The sound number.) }
procedure ProgramSpeakerVoices(song: Word); external;

{ Sets the voice byte; while it is 0 the timer interrupt keeps both banks quiet.
  @param(onOff The new voice byte, in its low byte.) }
procedure SetVoiceByte(onOff: Word); external;

{ Installs the driver's timer interrupt handler, saving the old one, and speeds up the timer. }
procedure InstallSoundTimer; external;

{ Restores the old timer interrupt handler and the BIOS timer rate, and silences both banks of voices. }
procedure UninstallSoundTimer; external;

{ Not code: the forced-exit countdown word that the driver's timer interrupt counts down. }
procedure TimeoutCtr; external;

procedure SoundCommand(cmd: Word);
var
  { Unused in this version; see the other implementations of this routine. }
  savedState: array[0..1] of Byte;
begin
  if not (Lo(cmd) in [0..15, 255]) then Exit;
  case cmd of
    0:
      if GDVars.soundMode <> C_Sound.OFF then begin
        SoundDrv.ProgramTandyVoices(0);
        SoundDrv.ProgramSpeakerVoices(0);
      end;
    1:
      if GDVars.soundMode <> C_Sound.OFF then SoundDrv.SetVoiceByte(1);
    255:
      if GDVars.soundMode <> C_Sound.OFF then begin
        SoundDrv.ProgramTandyVoices(0);
        SoundDrv.ProgramSpeakerVoices(0);
        SoundDrv.UninstallSoundTimer;
        GDVars.soundActive := 0;
      end;
    15:
      Word(GDVars.haltPtr^) := 5000;
  else
    if GDVars.soundMode <> C_Sound.OFF then
      if GDVars.soundMode = C_Sound.TANDY then SoundDrv.ProgramTandyVoices(cmd - 1)
      else SoundDrv.ProgramSpeakerVoices(cmd - 1);
  end;
end;

procedure StartSound;
var
  { Unused in this version; see the other implementations of this routine. }
  divisorBytes: array[0..1] of Byte;
begin
  GDVars.soundSaved := GDVars.soundMode;
  GDVars.soundActive := 1;
  if GDVars.soundMode = C_Sound.OFF then Exit;
  SoundDrv.InstallSoundTimer;
  SoundDrv.ProgramSpeakerVoices(0);
  SoundDrv.ProgramTandyVoices(0);
end;

begin
  GDVars.haltPtr := @SoundDrv.TimeoutCtr;
  Word(GDVars.haltPtr^) := 0;
end.
