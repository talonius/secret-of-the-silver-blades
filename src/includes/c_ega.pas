{ The EGA Sequencer and Graphics Controller ports, and the Map Mask value that enables the four planes. }
unit C_Ega;

interface

const
  { Sequencer address register (select which reg) }
  SEQ_ADDR_PORT = $3C4;
  { Sequencer data register (value for selected reg) }
  SEQ_DATA_PORT = $3C5;
  { Map Mask = enable all 4 planes }
  MAP_MASK_ALL_PLANES = $0F;
  { Graphics Controller address register }
  GC_ADDR_PORT = $3CE;
  { Graphics Controller data register }
  GC_DATA_PORT = $3CF;

implementation

end.
