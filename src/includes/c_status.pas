{ Character status values with the STATUS_ prefix. }
unit C_Status;

interface

const
  { TCharRecord.status, the axis of statusNames. }
  OKAY = 0;
  ANIMATED = 1;
  RUNNING = 3;
  UNCONSCIOUS = 4;
  DYING = 5;
  DEAD_STATUS = 6;
  PETRIFIED = 7;
  GONE = 8;

implementation

end.
