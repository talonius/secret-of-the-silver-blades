{ The heap error handler: warn about low memory, save the game if play has begun, and exit.

  HeapErrorHandler loops displaying the WARNING line. Each pass, if heapFailureSaveEnabled is set it calls
  SaveLoad.SaveGame and reads gameSaved, saveGame's success flag, into the loop flag; otherwise it sets the flag and
  shows the "Exiting Program" line. It leaves the loop once the flag is nonzero, then aborts through GameIo.ExitGame.

  GameInit clears heapFailureSaveEnabled, and ResetGameState, Intro.FinishIntroduction and FixMain's password skip of
  the title set it: once play can begin, a failed allocation saves the game before exiting. HeapErrorHandler never
  assigns its result.

  The unit initializer installs HeapErrorHandler as System.HeapError. }
{$O+,F+}
unit HeapErr;

interface

{ Warns that memory is short. While a game is in progress it saves the game, warning again until the saved flag shows
  the save went through; otherwise it says it is exiting. Note: the saved flag is not cleared before the save, so a flag
  still set by an earlier save ends the loop even if this save failed.
  @param(size Unused.)
  @returns(Never: ExitGame halts the program.) }
function HeapErrorHandler(size: Word): Word;

implementation
uses Crt, GDVars, TextRend, GameIo, SaveLoad;

function HeapErrorHandler(size: Word): Word;
var
  flag: Byte;
begin
  flag := 0;
  repeat
    TextRend.DisplayAndPause(Yellow, 0, 'WARNING: Insufficient Memory');
    if GDVars.heapFailureSaveEnabled <> 0 then begin
      SaveLoad.SaveGame;
      flag := GDVars.gameSaved;
    end else begin
      flag := 1;
      TextRend.DisplayAndPause(Yellow, 0, 'Insufficient Memory. Exiting Program');
    end;
  until flag <> 0;
  GameIo.ExitGame;
end;

begin
  HeapError := @HeapErr.HeapErrorHandler;
end.
