{ Interface states with the IFC_ prefix. }
unit C_Ifc;

interface

const
  { Values of interfaceState. }
  { chargen's mainMenu }
  MAIN_MENU = 0;
  { shop and temple }
  SHOP_TEMPLE = 1;
  CAMPING = 2;
  { the overland map: no 3D map is loaded and the party moves over a full-screen picture }
  OVERLAND = 3;
  { the 3D view: explore's Move/Area/Cast/View/Encamp/Search/Look menu }
  INDOORS = 4;
  IN_COMBAT = 5;
  { postcbt, after a fight }
  LOOT = 6;
  { Vault }
  IN_VAULT = 8;

implementation

end.
