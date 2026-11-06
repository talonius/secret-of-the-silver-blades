{ Compass directions with the DIR_ prefix. }
unit C_Dir;

interface

const
  { The compass axis: GDConsts.dirNames names the first eight, and dirDX/dirDY hold nine deltas, the ninth (0,0) at
    CENTER. }
  NORTH = 0;
  NORTHEAST = 1;
  EAST = 2;
  SOUTHEAST = 3;
  SOUTH = 4;
  SOUTHWEST = 5;
  WEST = 6;
  NORTHWEST = 7;
  CENTER = 8;

implementation

end.
