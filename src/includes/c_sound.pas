{ Sound modes with the SND_ prefix. }
unit C_Sound;

interface

const
  { The sound mode, as GameBoot's setup sets it from the A, T and P config letters; anything else is silent. }
  TANDY = 3;
  SPEAKER = 4;
  { also what Ctrl-S mutes to }
  OFF = 5;

implementation

end.
