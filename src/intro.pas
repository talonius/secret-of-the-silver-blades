{ Title screen and credits roll. }
{$O+,F+}
unit Intro;

interface

uses Blit, Border, GameIo, Mouse, SndLoad, Portrait, SoundDrv, TextRend, Crt, GDVars,
  C_Sound, Types;

{ Runs the title sequence: resets the sound driver, frees the shared animation, guards the sound against Ctrl-S and,
  unless sound is off, loads the music and its driver and starts the title music; then shows the four TITLE.DAX screens,
  waiting 15, 50, 50 and 60 seconds, and the credit roll for 80. Input during any wait skips straight to
  FinishIntroduction, where every path ends. }
procedure Introduction;

{ Waits up to a number of seconds or until a key is pressed, draining pending keystrokes before and after.
  @param(ticks The longest wait, in seconds.)
  @returns(True when a key ended the wait, False on timeout.) }
function DelayOrKey(ticks: Word): Boolean;

{ Ends the introduction: clears the screen, stops the music and frees its buffers unless sound is off, shows the mouse
  cursor again and enables the save on a heap failure. The sound guard Introduction set stays set. }
procedure FinishIntroduction;

{ Draws the credits window and the two-column credit roll: headings in magenta, names in yellow. }
procedure Credits;

implementation

function DelayOrKey(ticks: Word): Boolean;
var
  base: LongInt;
  target: LongInt;
begin
  GameIo.FlushKeys;
  base := TextRend.GetTicks;
  target := base + ticks * 100;
  repeat
  until GameIo.InputPending or (TextRend.GetTicks >= target);
  if TextRend.GetTicks >= target then
    DelayOrKey := False
  else
    DelayOrKey := True;
  GameIo.FlushKeys;
end;

procedure FinishIntroduction;
begin
  TextRend.ClearScreen;
  if GDVars.soundMode <> C_Sound.OFF then begin
    SndLoad.StopSound;
    SndLoad.FreeSoundBuffers;
  end;
  Mouse.ShowMouse;
  GDVars.heapFailureSaveEnabled := 1;
end;

procedure Credits;
begin
  Border.DrawCreditsFrame;
  TextRend.DisplayString(7, 0, Magenta, 0, 'secret of the silver blades');
  TextRend.DisplayString(2, 3, Magenta, 0, 'game created by:    story and');
  TextRend.DisplayString(2, 4, Yellow, 0, 'ssi special');
  TextRend.DisplayString(22, 4, Magenta, 0, 'development by:');
  TextRend.DisplayString(2, 5, Yellow, 0, 'projects team       Dave Shelley');
  TextRend.DisplayString(2, 7, Magenta, 0, 'programming:        graphic arts:');
  TextRend.DisplayString(2, 8, Yellow, 0, 'ken nicholson       mark johnson');
  TextRend.DisplayString(2, 9, Yellow, 0, 'russ brown          laura bowen');
  TextRend.DisplayString(22, 10, Yellow, 0, 'fred butts');
  TextRend.DisplayString(2, 11, Magenta, 0, 'Encounter Design:');
  TextRend.DisplayString(22, 11, Yellow, 0, 'cyrus lum');
  TextRend.DisplayString(2, 12, Yellow, 0, 'dave shelley        susan manley');
  TextRend.DisplayString(2, 13, Yellow, 0, 'michael mancuso     mike provenza');
  TextRend.DisplayString(2, 14, Yellow, 0, 'ken humphries       tom wahl');
  TextRend.DisplayString(2, 15, Yellow, 0, 'graeme Bayless');
  TextRend.DisplayString(2, 16, Yellow, 0, 'rick white');
  TextRend.DisplayString(22, 16, Magenta, 0, 'Musical Score:');
  TextRend.DisplayString(22, 17, Yellow, 0, 'john halbleib');
  TextRend.DisplayString(2, 19, Magenta, 0, 'playtest:');
  TextRend.DisplayString(12, 19, Yellow, 0, 'rick white,don mc clure,');
  TextRend.DisplayString(2, 20, Yellow, 0, 'dave lucca,cliff mann,rick wilson,');
  TextRend.DisplayString(2, 21, Yellow, 0, 'erik flom,james young,larry webber');
end;

procedure Introduction;
var
  pic: Types.PImgBuf;
  { Unused in this version; see the other implementations of this routine. }
  creditPage: Byte;
  { Unused in this version; see the other implementations of this routine. }
  keyed: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  rndAcc: Integer;
begin
  SoundDrv.SoundCommand(255);
  Portrait.FreeAnimation(GDVars.animData);
  GDVars.soundGuard := 1;
  if GDVars.soundMode <> C_Sound.OFF then begin
    SndLoad.LoadSound;
    SndLoad.InstallSoundDriver(GDVars.workPtr, GDVars.sndPtr);
    SndLoad.PlaySound(0);
  end;
  Mouse.HideMouse;
  pic := nil;
  Blit.LoadPic('title', 1, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(15) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(50) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  Blit.LoadPic('title', 3, False, 0, pic);
  Blit.ShowPic(2, 5, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(50) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  Blit.LoadPic('title', 2, False, 0, pic);
  Blit.ShowPic(0, 0, pic);
  Blit.FreePic(pic);
  Blit.LoadPic('title', 4, False, 0, pic);
  Blit.ShowPic(5, 5, pic);
  Blit.FreePic(pic);
  if Intro.DelayOrKey(60) then begin
    Intro.FinishIntroduction;
    Exit;
  end;
  TextRend.ClearScreen;
  Intro.Credits;
  keyed := Intro.DelayOrKey(80);
  Intro.FinishIntroduction;
end;

begin
end.
