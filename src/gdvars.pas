{ Global variables: the data segment's variables, grouped by the subsystem that owns them and kept in address order. A
  new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ Start-up menu: the title screen's play-or-demo choice. }
var
  { the letter MenuHorizontal returned on the title screen; 'D' starts the demo }
  menuResult: Char;
  { set when the title-screen key was an extended key; nothing acts on it }
  menuOut: Boolean;
  { loop counter for the copy-protection check over the four protectFlags }
  checkIdx: Byte;

{ Sound driver call and ECL interpreter run control. }
var
  { the sound driver's entry point, installed by InstallSoundDriver }
  sndProc: Types.TSndProc;
  { the two setup words copied from the driver's data block }
  sndArg: array[0..1] of Word;
  { what the driver returned from the last call SndLoad made }
  sndRes: Word;
  { the first setup word, passed to the driver's initialization call }
  setupArg0: Word;
  { the second setup word }
  setupArg1: Word;
  { nonzero stops the interpreter loop after the current opcode }
  eclStop: Byte;
  { set when a script asks for a new ECL block; the main loop loads it before running on }
  newEclFlag: Byte;
  { set while savedChar must be restored as the active character }
  restoreChar: Byte;
  { set once the current script has loaded area data }
  filesLoaded: Byte;
  { set once the current script has loaded wall sets }
  piecesLoaded: Byte;
  { set once the current script has loaded a 3D map }
  mapLoaded: Byte;
  { creatures added to the encounter so far; EclLoadMonster stops at 63 }
  creatureCnt: Byte;
  { the active character saved across a script that picks someone else }
  savedChar: Types.PCharRecord;

{ Post-combat outcome. }
var
  { set once an enemy has been downed, so the fight leaves loot behind }
  monstersKilled: Byte;
  { set when the party ran from the fight }
  partyFled: Byte;
  { set by DetermineTreasure when the treasure holds coins }
  treasureHasMoney: Boolean;
  { set by DetermineTreasure when the treasure holds items }
  treasureHasItems: Boolean;
  { the shop's Buy menu redraw request, passed to MenuVertical by reference }
  buyRedraw: Boolean;

{ Combat AI movement: oscillation detection for a monster that keeps stepping back and forth. }
var
  { the direction of the last step, or 8 for none }
  gOccA: Byte;
  { how many times in a row the monster has stepped back the way it came }
  gOccB: Byte;
  { reset at the start of each move but never read }
  gOccC: Byte;

{ Combat placement: where each side's combatants start on the battle map. }
var
  { per side, ring, quadrant row and column: whether the spot is still free }
  occ: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { per side: the quadrant column the side's rings are laid out from }
  quadrantOx: array[0..1] of ShortInt;
  { per side: the quadrant row the side's rings are laid out from }
  quadrantOy: array[0..1] of ShortInt;
  { per side: how many rows the side fills, half its head count rounded up }
  qCnt: array[0..1] of ShortInt;
  { per side: the quadrant layout, which picks the side's rows from quadrantGlyphs and quadrantFacings }
  qId: array[0..1] of ShortInt;
  { the map-square column being scanned while the battle map is built from the area map }
  arenaOx: ShortInt;
  { the map-square row being scanned }
  arenaOy: ShortInt;
  { the wall type on the north side of the area-map square being converted }
  qfA: Byte;
  { the wall type on the west side }
  qfB: Byte;
  { the wall type on the east side }
  qfC: Byte;
  { the wall type on the south side }
  qfD: Byte;
  { the side being placed: 0 the party, 1 the monsters }
  sideIx: ShortInt;
  { unused }
  sideIxTail: array[0..1] of Byte;
  { the party cell's map-event bit $40; gates DecorateCell }
  featureEvent: Byte;
  { set when the square's walls allow scattered features }
  featureLayout: Byte;

{ Game initialization: loop counters, the start-up mouse sample and the ITEMS file. }
var
  { unused }
  gILead: array[0..3] of Byte;
  { loop counter for the row-address tables }
  gI: Byte;
  { unused }
  gITail: array[0..2] of Byte;
  { whether OpenWithRetry found ITEMS }
  itemsOpened: Boolean;
  { unused }
  itemsOpenedTail: array[0..42] of Byte;
  { the buttons of the mouse sample taken at start-up }
  mouseBtn: Integer;
  { the column of that sample; past 320 means a 640-wide driver }
  mouseRawX: Integer;
  { the row of that sample }
  mouseRawY: Integer;
  { the ITEMS file, read once into baseItems }
  itemsFile: File;
  { unused }
  itemsFileTail: Byte;
  { the running row offset while the Tandy and frame-buffer row tables are built }
  rowOfs: Word;

{ Character view, spell lists and start-up configuration. }
var
  { the character shown on the character sheet }
  cr: Types.PCharRecord;
  { the character whose items the inventory screen works on }
  viewedChar: Types.PCharRecord;
  { One flag per creatureList member, sized to the 72-slot combat list: still carries a timed effect, cleared as the
    timers run out. }
  castFlag: array[1..72] of Byte;
  { head of the menu list built for a spell choice; freed after the pick }
  spellList: Types.PItemRec;
  { the duplicate count parallel to spellIdx, printed as ' (n)' when it exceeds 1 }
  spellQty: array[0..1000] of Byte;
  { the id list GenerateSpellList appends to }
  spellIdx: array[0..1000] of Byte;
  { per menu line: the scroll or item the spell comes from }
  spellScratch: Types.PSpellScratch;
  { the fill index shared by spellIdx and spellScratch^ }
  scratchCount: Word;
  { the strength score a spell grants, such as Strength's }
  gScratchA: Byte;
  { the exceptional strength that goes with gScratchA }
  gScratchB: Byte;
  { equipped-item weight subtotal; written but never read }
  gEquipWeight: Word;
  { the free-list block GameBoot moves down to hold the graphics reserve }
  gfxTmp: Types.PFreeBlk;
  { the digit just typed at a configuration prompt }
  keyChar: Char;
  { the configuration menu choice }
  menuChoice: Byte;
  { BLADES.CFG, written while the player answers the set-up questions }
  cfgFile: Text;
  { unused }
  cfgFileTail: array[0..127] of Byte;
  { IOResult of the last configuration-file operation }
  ioErr: Byte;
  { loop counter while the save path is checked and upper-cased }
  ix: Byte;
  { the save path typed by the player }
  pathBuf: String[80];
  { the program's file name, split from its full path }
  exeName: String[8];
  { the program's extension }
  exeExt: String[4];
  { the save path offered when the player just presses Enter }
  fsPath: String[79];

{ Disk paths. }
var
  { the directory the data files are read from; GameBoot sets it from the program's own path }
  gDataPath: string[79];
  { the other place the data may be found, swapped with gDataPath when a file is missing }
  gAltPath: string[79];
  { the drive letter named in the insert-disk prompt }
  gPromptDrive: Char;

{ Play session: zones, ECL entry points, interface state and game options. }
var
  { points at SoundDrv's timeout counter }
  haltPtr: Pointer;
  { set to -1 by Ub74's initialization; nothing reads it }
  initMarker: LongInt;
  { unused }
  initMarkerTail: array[0..5] of Byte;
  { set when the full introduction plays rather than the short one }
  fullIntro: Boolean;
  { set once play has started, so the low-memory handler saves the game before it exits }
  heapFailureSaveEnabled: Byte;
  { The GBVM bank table: four far pointers, one per zone id returned by EclMenu.GbvmZone. The blocks they address are
    allocated once at startup and never freed. This one is the game-state block. }
  zone0: Types.PZone0;
  { the area-state block }
  zone1: Types.PZone1;
  { the script's own data block }
  zone2: Types.PZone2;
  { the script code the interpreter runs }
  zone3: Types.PZone3;
  { the game speed, 0 fastest to 9 slowest }
  gameDelay: Byte;
  { the five entry points read from the head of the current ECL block; Explore's Look resumes at the second }
  vmRun: array[1..5] of Word;
  { the interpreter's offset into zone3 }
  eclIp: Word;
  { unused }
  eclIpTail: array[0..3] of Byte;
  { what the screen is showing: a C_Ifc mode }
  interfaceState: Byte;
  { the interface mode before the last location change }
  savedInterface: Byte;
  { set while the demo plays }
  demoMode: Boolean;
  { unused }
  demoModeTail: Byte;
  { the player's pictures-on option }
  picsOn: Byte;
  { set while a full-screen picture covers the roster, so the roster is not redrawn }
  rosterLock: Byte;
  { the player's animations-on option }
  animOn: Byte;
  { while the encounter menu is open and this is 0, no encounter picture is drawn; nothing sets it }
  monsterPics: Byte;
  { set to trace each ECL opcode on screen and wait for a key }
  debugOn: Boolean;
  { set after a saved game is loaded, until the first script has run }
  loadedSave: Byte;
  { clock ticks spent resting toward the area's rest period }
  restTicks: Word;
  { the head picture of the portrait last shown }
  portraitHeadId: Byte;
  { the body picture of the portrait last shown }
  portraitBodyId: Byte;
  { set when no party member is left in play }
  partyDefeated: Byte;
  { cleared around EclProgram's finale call and raised again after }
  returnedFromCharGen: Byte;
  { set while the training hall is training a newly created character }
  newCharTraining: Byte;
  { set while text is printed slowly, letter by letter }
  msgDelayFlag: Byte;

{ Video: BIOS registers, EGA pages and video modes. }
var
  { the register block for BIOS and DOS calls }
  regs: Types.TRegisters;
  { the EGA segment of the page being shown }
  egaCurPage: Word;
  { the EGA segment of the page being drawn }
  egaOtherPage: Word;
  { the EGA page being drawn }
  otherEgaPage: Byte;
  { the EGA page being shown }
  curEgaPage: Byte;
  { the video mode found at start-up, restored on exit }
  savedVideoMode: Byte;
  { the BIOS video mode the game set }
  curVideoMode: Byte;
  { the display adapter the game draws for }
  displayMode: Types.TVideoMode;

{ Video: the view buffer, dirty spans and row tables. }
var
  { the off-screen buffer the view is drawn into }
  viewBuf: Types.PImgBuf;
  { the save-under buffer for clipped sprites }
  saveUnder: Types.PImgBuf;
  { unused }
  saveUnderTail: array[0..15] of Byte;
  { the dirty-span tables, also read by blit.asm: per span slot, whether it holds a span to flush }
  spanActive: array[0..167] of Byte;
  { per span slot: its screen row }
  spanY: array[0..167] of Word;
  { per span slot: its first column }
  spanX0: array[0..167] of Word;
  { per span slot: its last column }
  spanX1: array[0..167] of Word;
  { Unused; the span tables above have no bound check, so a slot past 167 would land here. }
  spanX1Tail: array[0..671] of Byte;
  { per screen row: the CGA segment of the row }
  cgaRowSeg: array[0..199] of Word;
  { per screen row: the offset of the row in the frame buffer }
  fbRowOfs: array[0..199] of Word;
  { per screen row: the Tandy segment of the row }
  tandyRowSeg: array[0..199] of Word;
  { set once game initialization has run }
  initFlag: Byte;

{ Sound: sound mode and state. }
var
  { the sound hardware chosen at set-up: a C_Sound mode }
  soundMode: Byte;
  { the sound mode saved while sound is switched off }
  soundSaved: Byte;
  { set once the sound driver is running; FixMain and EclVm send a sound command while it is set and call StartSound
    while it is clear }
  soundActive: Byte;

{ Sound: the Ctrl-S lock. }
var
  { set by the title sequence; while set, the Ctrl-S sound toggle does nothing }
  soundGuard: Byte;

{ Disk, saved games and the party and treasure lists. }
var
  { the game disk the data files are read from }
  diskNum: Byte;
  { diskNum saved across a read from another disk }
  savedDiskNum: Byte;
  { the directory saved games go to; it also holds vault.dat }
  saveDir: String;
  { the key that answers an insert-disk prompt without asking, or 0 }
  suppressInsertPrompt: Char;
  { set after a save, cleared by anything that changes the game }
  gameSaved: Byte;
  { the 128 base item records read from ITEMS }
  baseItems: array[0..127] of Types.TBaseItem;
  { The ITEMS loader asks for 129 records into the 128-record table, but the file holds 128, so these bytes are never
    written. }
  baseItemsTail: array[0..15] of Byte;
  { the creature whose roster line is redrawn next, or nil }
  redrawChar: Types.PCharRecord;
  { the active character }
  curChar: Types.PCharRecord;
  { head of the list of party members and monsters in play }
  creatureList: Types.PCharRecord;
  { the last treasure item that was on the list before the fight; items thrown during it are appended after }
  lastItem: Types.PItemRec;
  { set when the clock has aged the party a year, so combat checks for deaths from old age }
  agingFlag: Byte;
  { the file handle DeleteIfPresent erases through }
  delFile: file;
  { bytes BlockRead returned for ITEMS }
  itemsRead: Word;

{ Font, text cursor, pictures, icons and the combat arena. }
var
  { the 8x8 font }
  gameFont: Types.PFontArr;
  { glyph row staging buffer for the text blitters }
  glyphBuf: array[0..7] of Byte;
  { the text cursor's column }
  curCol: Byte;
  { text cursor row; displayMessageWindow advances it }
  curRow: Byte;
  { unused }
  curRowTail: array[0..19] of Byte;
  { five symbol-set pointers }
  gfxSet: array[0..4] of Types.PImgBuf;
  { the 8x8 symbol being drawn }
  workPic: Types.PImgBuf;
  { what the map cursor covers }
  cursorBackground: Types.PImgBuf;
  { the map cursor laid over what it covers }
  cursorComposite: Types.PImgBuf;
  { the first map tile set }
  tileSet1: Types.PImgBuf;
  { the second map tile set }
  tileSet2: Types.PImgBuf;
  { per icon slot, the icon's two frames; slot 11 holds the head overlay SaveLoad merges into a character's icon, and
    slot 24 the two skull frames flashed over a downed combatant }
  iconAnims: array[0..25, 0..1] of Types.PImgBuf;
  { the number of combatants on the battle map }
  arenaCount: Byte;
  { each combatant's arena position and size }
  arenaLoc: array[1..72] of Types.TArenaLoc;
  { each combatant's column relative to the visible part of the arena }
  gridX: array[1..72] of ShortInt;
  { each combatant's row relative to the visible part of the arena }
  gridY: array[1..72] of ShortInt;
  { per arena square: the combatant standing on it, or 0 }
  creatureIndexGrid: array[0..24, 0..49] of Byte;
  { the combatants, by combat index }
  creatures: array[1..72] of Types.PCharRecord;
  { the combatants lying on the map, drawn as corpses }
  downed: array[1..8] of Types.TDownedRec;
  { entries in the table above }
  downedCount: Byte;
  { the battle map }
  arenaPtr: Types.PArena;
  { the number of entries in targets }
  targetCount: Byte;
  { the targets in reach of the current attack or spell }
  targets: array[1..72] of Types.TTarget;

{ Treasure and effect resolution. }
var
  { the coins the party has won and not yet picked up, by C_Money kind; coins a seller cannot carry go here too }
  treasureMoney: Types.TMoney;
  { the items the party has won and not yet picked up }
  treasureItems: Types.PItemRec;
  { per side: how many combatants are in play; CountTeams tallies them }
  teamCount: array[0..1] of Byte;
  { the vault list entry being filled or walked }
  vaultCur: Types.PItemRec;
  { the d20 rolled for the current saving throw, after bonuses }
  saveRoll: Byte;
  { the effect being applied }
  currentEffectId: Byte;
  { the pending damage for the attack or effect being resolved; 255 while the effect chain runs, and a handler that
    cancels the damage clears it }
  pendingDamage: Byte;
  { the elements the current attack carries, one bit each }
  elemMask: Byte;
  { the attack rate or the doubled movement being converted to attacks }
  movementAttacks: Byte;
  { the doubled movement RecalcMovement works out; the haste and slow handlers double or halve it }
  movement: Byte;
  { the id of the spell being cast; CastSpell stores it just before dispatching through spellFns and clears it just
    after }
  spellId: Byte;
  { the dice count the current effect rolls }
  damageDice: Byte;
  { unused }
  damageDiceTail: Byte;
  { CanTarget's veto flag, set by the fx pass }
  suppressTargeting: Byte;
  { set while the temple cures a character, so AddEffectIfNoLock adds no new effect meanwhile }
  effectLock: Byte;
  { part of the "no spell in flight" reset, cleared together with spellId }
  areaTargets: Byte;
  { set to make the inventory menu redraw on its next pass }
  redrawInvMenu: Byte;
  { the attack roll being resolved, adjusted by the effect handlers }
  attackRoll: ShortInt;
  { per attack phase: the hits made this round }
  attacksHit: array[1..2] of Byte;
  { the morale the AI compares hostileHpPercent against; some effect handlers raise or lower it }
  morale: Byte;
  { the creature the effect handlers are working on }
  combatTarget: Types.PCharRecord;
  { the saving-throw category of the current effect }
  saveType: Byte;
  { the result of the last saving throw: True when it was made }
  saveResult: Boolean;

{ Effect dispatch, 3D view and pictures. }
var
  { per effect id: the routine that applies it }
  effectHandlers: array[1..119] of Types.TEffectHandler;
  { the handler called in place of the table while overrideFlag is set }
  overrideHandler: Types.TEffectHandler;
  { the wall graphics block; GameInit allocates it, View3D reads it }
  wallDefs: Types.PWallDefs;
  { the area's geometry map; View3D loads and draws it, Explore edits barriers }
  geo: Types.PGeoMap;
  { the 3D view's sky color }
  viewColSky: Byte;
  { the color of the upper horizon row }
  viewColHorz1: Byte;
  { the color of the lower horizon row }
  viewColHorz2: Byte;
  { the 3D view's floor color }
  viewColFloor: Byte;
  { Explore toggles it; View3D draws the automap in place of the view while set }
  automapOn: Boolean;
  { where the party stands and what it faces }
  partyPos: Types.TPartyPosition;
  { the wall sets loaded into the 3D view's three slots }
  wallSetCache: array[1..3] of Types.TWallSetSlot;
  { sky picture 250, drawn at the top of the 3D view }
  skyPic1: Types.PImgBuf;
  { sky picture 251 }
  skyPic2: Types.PImgBuf;
  { sky picture 252 }
  skyPic3: Types.PImgBuf;
  { the animated picture on show: a script's, a menu's or the encounter's }
  animData: Types.TAnimRec;
  { the portrait on show: [1] its head, [2] its body }
  portraits: array[1..2] of Types.TPortSlot;
  { the picture archive the view window's picture came from }
  picArcName: Types.TStr8;
  { picArcName saved while the camp menu covers the picture }
  savedPicArcName: Types.TStr8;
  { the id of the view window's picture in picArcName }
  picArcId: Byte;
  { camp's saved picArcId; newEclDone invalidates it with 255 }
  savedPicArcId: Byte;
  { the full-screen picture }
  bigPicBuf: Types.PImgBuf;
  { the id of the full-screen picture, so it is loaded once; 255 for none }
  bigPicId: Byte;

{ Menus: menu state and mouse hit areas. }
var
  { set while the selector picks selOverrideWho instead of curChar }
  selOverride: Byte;
  { the character the selector picks while selOverride is set }
  selOverrideWho: Types.PCharRecord;
  { the list entry shown on the menu's top line }
  menuTop: Integer;
  { the horizontal menu's current option, 1-based; sticky across MenuHorizontal calls, so a caller saves and restores
    it }
  horizChoice: Byte;
  { set when the menu's last key was an extended key }
  extKeyFlag: Boolean;
  { how long a menu waits for a key before it returns defaultKey; 0 waits for ever }
  autoDelay: LongInt;
  { the key a menu returns when autoDelay runs out; set by FixMain }
  defaultKey: Byte;
  { per menu line: the screen row it sits on; 255 ends the table }
  hotRows: array[1..25] of Byte;
  { the vertical menu's left column for mouse clicks; 127 when no list is shown }
  clickColLo: ShortInt;
  { the vertical menu's right column for mouse clicks; -128 when no list is shown }
  clickColHi: ShortInt;
  { the roster's left column for mouse clicks }
  rosterLeft: Byte;
  { the roster's right column }
  rosterRight: Byte;
  { the roster's top row }
  rosterTop: Byte;
  { roster rect: bottom row, grown per entry }
  rosterBottom: Byte;
  { the stat row the mouse picked on the modify screen; 255 for none }
  mouseMenuRow: Byte;
  { set while a roster click picks a character for the menu that set it }
  rosterPickMenu: Byte;

{ Magic: spell casting and targeting. }
var
  { the item a spell is cast or read from }
  useItem: Types.PItemRec;
  { the target picker for a cast: one for camp, one for combat }
  castTargetMenu: Types.TCastTargetMenu;
  { per spell id: the routine that casts it }
  spellFns: array[1..117] of Types.TSpellFn;
  { the number of entries in castTargets }
  castTargetCount: Byte;
  { the creatures the current spell will affect }
  castTargets: array[1..72] of Types.PCharRecord;
  { the last character a camp spell was cast on, offered first next time }
  castTarget: Types.PCharRecord;
  { the column a spell is aimed at }
  targetCellX: ShortInt;
  { the row a spell is aimed at }
  targetCellY: ShortInt;
  { head of the list of fireball and other blast clouds on the battle map }
  blastHead: Types.PCloudNode;
  { head of the list of stinking clouds }
  stinkHead: Types.PCloudNode;
  { head of the list of cloudkill clouds }
  cloudkillHead: Types.PCloudNode;
  { set while a spell is cast from an item rather than from memory }
  usingItemFlag: Byte;
  { set when the treasure on offer holds coins }
  treasureMoneyFlag: Boolean;

{ Rest and healing. }
var
  { the rest duration being set, one digit per time unit }
  restClock: Types.TRestClock;
  { per party member: the time left before the next spell is memorized }
  prepTimers: array[1..8] of Byte;
  { clock ticks toward the next natural healing }
  healTicks: Word;
  { set while the party is resting }
  restActive: Byte;

{ 3D view redraw request. }
var
  { set when the 3D view must be drawn again }
  viewDirty: Byte;

{ Effect override, character generation and door opening. }
var
  { SpellRemoveCurse sets it to 1 immediately before dispatching the cursed item's effect handler with removed = True;
    while it is set, callEffectHandler dispatches the override handler instead of the indexed one. }
  overrideFlag: Byte;
  { set while the item screen waits for the player to pick a character }
  pickingCharacter: Byte;
  { where Add takes a character from: 0 for the menu's Curse ('*.guy' files), 1 for Secret ('*.who') }
  saveMode: ShortInt;
  { set to leave the training menu }
  trainMenuDone: Byte;
  { set to let training run while the hall's train mask is empty }
  freeTraining: Byte;
  { set while the modify-character screen is open }
  modifyMenuActive: Byte;
  { cleared by the camp Fix command; the spell menu reads it as its redraw flag }
  fixByte: Byte;
  { unused }
  fixByteTail: array[0..2] of Byte;
  { The first of three door-opening offers, read whole by GameInit: whether Bash may still be tried at the current
    door. }
  bashOffered: Byte;
  { whether Pick may still be tried }
  pickOffered: Byte;
  { whether Knock may still be tried }
  knockOffered: Byte;

{ Combat round. }
var
  { set once a party member has attacked an ally }
  allyAttacked: Byte;
  { the round counter; the breath weapon is refilled to 3 uses whenever it is zero }
  roundCounter: Byte;
  { the round after which the fight ends on its own }
  roundLimit: Byte;
  { per target slot: the combat index of the target }
  targetIdx: array[1..72] of Byte;
  { per attack phase: the attacks made this round }
  attacksTried: array[1..2] of Byte;
  { the hostile-HP percentage UpdateHostileHpPercent publishes }
  hostileHpPercent: Byte;
  { the combat magic-on option, toggled by Alt-M; while set, the AI may cast for party members too }
  quickMagic: Boolean;
  { set when the combat menu's last key was an extended key }
  menuExt: Boolean;
  { unused }
  menuExtTail: array[0..3] of Byte;
  { the icon picture of the combatant acting }
  iconBuf: Types.PImgBuf;
  { unused }
  iconBufTail: Byte;
  { the combat cursor's column }
  aimCursorX: ShortInt;
  { the combat cursor's row }
  aimCursorY: ShortInt;
  { set while the aiming cursor shows on the battle map }
  aimActive: Byte;
  { set while the combat move menu is open }
  inMoveMenu: Byte;
  { the combatant acting }
  curCreature: Types.PCharRecord;
  { set when the AI's chosen target is within reach }
  moveBlocked: Byte;
  { CombatPrintCreatureInfo redraws only when set, and clears it itself }
  panelDirty: Byte;
  { set while combat moves are drawn rather than resolved off screen }
  actorVisible: Boolean;
  { the combatants in the order they act this round }
  initOrder: array[1..72] of Types.PCharRecord;
  { the position in initOrder of the combatant acting }
  combatantIdx: Byte;

{ ECL interpreter: registers, stack, operands and the encounter it runs. }
var
  { GBVM color selector for the 3D view's walls }
  wallColorSel: Byte;
  { GBVM color selector for the 3D view's ceiling and floor }
  ceilFloorColorSel: Byte;
  { values a script reads back through the special read addresses, one per address }
  readReg1: Word;
  { the second read register }
  readReg2: Word;
  { the third read register }
  readReg3: Word;
  { the stack of ECL blocks called and not yet returned from }
  eclStack: Types.PEclRet;
  { the stack entry below the top, while a call is pushed }
  eclStackPrv: Types.PEclRet;
  { the six comparison results of the last compare opcode }
  compareFlags: array[0..5] of Boolean;
  { the opcode before the current one }
  prevOp: Byte;
  { the opcode being run }
  curOp: Byte;
  { unused }
  curOpTail: Byte;
  { the monster picture of the encounter }
  approachA: Byte;
  { the approach type of the encounter }
  approachB: Byte;
  { icon-anim slot, and the order number stamped into every cloned monster }
  iconAnimIdx: Byte;
  { unused }
  iconAnimIdxTail: array[0..129] of Byte;
  { per operand of the current opcode: its type }
  varTypes: array[1..64] of Byte;
  { per operand: the high byte of its value }
  varHi: array[1..64] of Byte;
  { per operand: the low byte of its value }
  varLo: array[1..64] of Byte;
  { set when the caster confirms the targets of a spell }
  castConfirmed: Boolean;
  { scratch index shared by the loops that walk tables }
  loopIdx: ShortInt;
  { the strings the current opcode reads as operands }
  gbStrings: array[1..20] of String;
  { the encounter's monster flags }
  monFlags: Types.TMonFlags;
  { unused }
  monFlagsTail: array[0..1] of Byte;
  { the sound effect a script asked for }
  sndEffect: Word;
  { values a script writes through the special write addresses, one per address }
  writeReg1: Word;
  { the second write register }
  writeReg2: Word;
  { nothing sets it, so the drop it guards with dumpPartyRecords never happens }
  dumpMonsterRecords: Boolean;
  { set when a script writes 0 to GBVM $7C00; a creature is dropped only while dumpMonsterRecords is set too }
  dumpPartyRecords: Boolean;
  { set while the shop's item panel is shown }
  shopPanelOn: Byte;

{ Post-combat: duel and experience. }
var
  { set when the fight is a duel }
  duelFlag: Byte;
  { party members out of the fight, left out of the experience share }
  nonAnimCount: Byte;
  { each surviving party member's share of the experience }
  expShare: LongInt;
  { set when the party won the fight }
  combatWon: Byte;

{ ECL display state, the overlay reader and the debug log. }
var
  { the id of the ECL block running }
  curEclId: Byte;
  { the area's search flag, saved across the search-and-look pass }
  searchBak: Byte;
  { set once the CLEAR BOX opcode has cleared the text box }
  boxCleared: Byte;
  { EclPrintReturn clears it after parking the cursor }
  printRetFlag: Byte;
  { set while a script's picture is on screen }
  eclGraphics: Boolean;
  { set once the view window holds the picture a script asked for }
  picDrawn: Byte;
  { never set; the EXIT opcode would redraw the explore frame while it is }
  eclProtection: Byte;
  { set while a script's sprite is on screen }
  sprShown: Boolean;
  { set once Explore has cleared the bottom text rows }
  bottomClear: Byte;
  { set while the picture region holds something other than the 3D view }
  picRegionW: Boolean;
  { set after the party moves, so the view and the cell's event are refreshed }
  movedParty: Boolean;
  { set while an encounter's monsters are loaded }
  monstersPresent: Byte;
  { set when the sky must be drawn again }
  redrawSky: Boolean;
  { set while the encounter menu is open }
  inEncMenu: Byte;
  { the id of the picture the encounter menu last drew, so it is drawn once }
  picIdShown: Byte;
  { set when a script names a party member who is not in the party }
  charNotFound: Byte;
  { set when the overland status panel must be drawn again }
  needPanelRedraw: Byte;
  { cleared at start-up and on reset; nothing reads it }
  needPanelRedrawTail: Byte;
  { 0 for the normal indoor menu, 1 for move mode }
  moveMode: Byte;
  { bumped per creature whose thiefSkills[0] is non-zero }
  thiefCount: Byte;
  { the block held back at the top of the heap for the graphics buffers }
  gfxReserve: Pointer;
  { unused }
  gfxReserveTail: Byte;
  { the overlay manager's read routine, saved when GameBoot installs its own }
  savedOvrRead: Types.TOvrReadFunc;

{ Debug log, STING key and copy protection. }
var
  { the debug log GameIo writes; GameIo reads it as a Text }
  debugFile: array[0..256] of Byte;
  { cleared at start-up as a LongInt in its first four bytes; nothing reads it }
  debugFileTail: array[0..4] of Byte;
  { compared against ParamStr(2) to unlock free training, the automap and the other STING options }
  stingKey: String[20];
  { The copy-protection marks, set as the protection screen gets that far: [1] the screen ran, [2] the question was
    asked, [3] an answer was typed, [4] the right answer was given. FixMain ends the game if any is still 0. }
  protectFlags: array[1..4] of Byte;

{ Mouse and joystick. }
var
  { set when the mouse driver reports a 320-wide range, so positions are not halved }
  mouseScaled: Boolean;
  { set while the roster answers mouse clicks }
  rosterMouseOn: Byte;
  { the player's mouse-on option }
  mouseOn: Boolean;
  { set when the last mouse click was taken as a key }
  mouseClk: Boolean;
  { the number of mouse buttons the driver reports }
  buttonCount: Byte;
  { the mouse column }
  mouseX: Integer;
  { the mouse row }
  mouseY: Integer;
  { the mouse column at the previous poll }
  mouseOldX: Integer;
  { the mouse row at the previous poll }
  mouseOldY: Integer;
  { the mouse cursor shape for the display mode: cursorMaskCga or cursorMaskHi }
  cursorMask: Pointer;

{ Joystick calibration and the sound driver blocks. }
var
  { the calibration of joysticks 1 and 2; joystick 1's is written to BLADES.CFG }
  joyCal: array[1..2] of Types.TJoyCal;
  { the player's joystick-on option }
  joyOn: Boolean;
  { the joystick cursor's column }
  joyCursorX: Word;
  { the joystick cursor's row }
  joyCursorY: Word;
  { unused }
  joyCursorYTail: array[0..116] of Byte;
  { the sound driver's code block as allocated, kept to free it }
  comPtr: Pointer;
  { the paragraph-aligned start inside comPtr's block, where the driver code is copied }
  alignPtr: Pointer;
  { the sound data block }
  sndPtr: Pointer;
  { scratch pointer while the driver is loaded and installed }
  workPtr: Pointer;
  { the size of the driver code }
  comSize: Word;
  { the size of the sound data }
  sndSize: Word;

implementation

end.
