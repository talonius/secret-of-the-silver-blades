{ Initialized data: the data segment's typed constants, grouped by the subsystem that owns them and kept in address
  order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Keys, C_Dir;

{ Copy protection: the journal question and the temple's service list. }
const
  { the scrambled letters of the journal answers; each is stored as its code minus 55 and the answer's length }
  wordChars: array[1..170] of Byte = (
      6, 16, 5, 7, 15, 22, 3, 14, 13, 11, 16, 9, 16, 12, 17, 8, 21, 22, 6, 16, 13, 18,
      8, 25, 6, 17, 10, 3, 6, 9, 16, 13, 5, 6, 19, 10, 22, 19, 23, 24, 22, 12, 15, 25,
      8, 21, 4, 16, 24, 15, 8, 23, 8, 29, 13, 18, 11, 17, 5, 11, 9, 23, 11, 25, 5, 22,
      8, 28, 10, 17, 17, 23, 24, 19, 22, 29, 25, 18, 21, 19, 4, 15, 12, 10, 18, 24, 8, 20,
      8, 14, 3, 15, 11, 16, 9, 23, 17, 5, 16, 16, 15, 8, 7, 10, 8, 21, 16, 4, 21, 6,
      24, 22, 28, 24, 15, 4, 22, 11, 13, 21, 12, 13, 1, 19, 20, 5, 18, 9, 14, 17, 25, 11,
      16, 9, 12, 19, 25, 23, 9, 22, 8, 21, 25, 8, 7, 25, 17, 23, 16, 6, 7, 6, 1, 13,
      1, 26, 15, 14, 9, 1, 14, 19, 7, 10, 6, 12, 21, 6, 15, 8
  );
  { the thirty journal questions CopyProtection picks from }
  jrec: array[1..30] of Types.TJRec = (
    (wordNum: 5; entryNum: 3; pageNum: 28; wordLen: 5; startCol: 0),
    (wordNum: 2; entryNum: 5; pageNum: 28; wordLen: 7; startCol: 5),
    (wordNum: 4; entryNum: 6; pageNum: 28; wordLen: 6; startCol: 12),
    (wordNum: 1; entryNum: 13; pageNum: 29; wordLen: 5; startCol: 18),
    (wordNum: 3; entryNum: 9; pageNum: 29; wordLen: 4; startCol: 23),
    (wordNum: 5; entryNum: 11; pageNum: 29; wordLen: 8; startCol: 27),
    (wordNum: 3; entryNum: 15; pageNum: 30; wordLen: 5; startCol: 35),
    (wordNum: 4; entryNum: 18; pageNum: 30; wordLen: 6; startCol: 40),
    (wordNum: 2; entryNum: 19; pageNum: 31; wordLen: 6; startCol: 46),
    (wordNum: 1; entryNum: 22; pageNum: 31; wordLen: 5; startCol: 52),
    (wordNum: 6; entryNum: 23; pageNum: 31; wordLen: 5; startCol: 57),
    (wordNum: 2; entryNum: 24; pageNum: 32; wordLen: 5; startCol: 62),
    (wordNum: 4; entryNum: 25; pageNum: 32; wordLen: 4; startCol: 67),
    (wordNum: 3; entryNum: 27; pageNum: 32; wordLen: 5; startCol: 71),
    (wordNum: 6; entryNum: 28; pageNum: 32; wordLen: 6; startCol: 76),
    (wordNum: 3; entryNum: 30; pageNum: 33; wordLen: 4; startCol: 82),
    (wordNum: 4; entryNum: 33; pageNum: 33; wordLen: 2; startCol: 86),
    (wordNum: 6; entryNum: 34; pageNum: 33; wordLen: 7; startCol: 88),
    (wordNum: 6; entryNum: 37; pageNum: 34; wordLen: 5; startCol: 95),
    (wordNum: 1; entryNum: 40; pageNum: 35; wordLen: 6; startCol: 100),
    (wordNum: 3; entryNum: 43; pageNum: 36; wordLen: 6; startCol: 106),
    (wordNum: 3; entryNum: 47; pageNum: 37; wordLen: 6; startCol: 112),
    (wordNum: 3; entryNum: 46; pageNum: 37; wordLen: 9; startCol: 118),
    (wordNum: 2; entryNum: 48; pageNum: 38; wordLen: 7; startCol: 127),
    (wordNum: 7; entryNum: 51; pageNum: 39; wordLen: 5; startCol: 134),
    (wordNum: 4; entryNum: 55; pageNum: 40; wordLen: 6; startCol: 139),
    (wordNum: 4; entryNum: 59; pageNum: 41; wordLen: 7; startCol: 145),
    (wordNum: 4; entryNum: 63; pageNum: 42; wordLen: 9; startCol: 152),
    (wordNum: 1; entryNum: 67; pageNum: 43; wordLen: 3; startCol: 161),
    (wordNum: 5; entryNum: 70; pageNum: 44; wordLen: 6; startCol: 164)
  );
  { what the temple prints after a cure takes }
  curedMsg: String[9] = 'is cured';
  { the temple's service menu }
  healServices: array[1..11] of String[40] = (
    'Cure Blindness', 'Cure Disease', 'Cure Light Wounds', 'Cure Serious Wounds', 'Cure Critical Wounds', 'Heal',
    'Neutralize Poison', 'Raise Dead', 'Remove Curse', 'Stone to Flesh', 'Exit'
  );

{ Treasure message, combat placement tables and the camp menus. }
const
  { the start of the treasure line after a fight; 'no ' goes between it and treasureMsgB when nothing was found }
  treasureMsgA: String[21] = 'The party has found ';
  { the end of the treasure line }
  treasureMsgB: String[11] = 'treasure!';
  { per approach type: the turns, in eighths, a monster tries in order when it cannot step straight at its target }
  approachPatterns: array[1..6, 1..5] of Byte = (
    (8, 7, 6, 1, 2), (8, 1, 2, 7, 6), (7, 1, 8, 6, 2), (1, 7, 8, 2, 6), (8, 7, 6, 5, 4), (8, 1, 2, 3, 4)
  );
  { per quadrant layout and ring: the direction the ring is laid out toward }
  quadrantGlyphs: array[0..3, 0..3] of Byte = (
    (8, 4, 6, 2), (8, 6, 4, 0), (8, 0, 6, 2), (8, 2, 0, 4)
  );
  { per quadrant layout and ring: the facing that picks the ring's start cell, in half steps }
  quadrantFacings: array[0..3, 0..3] of Byte = (
    (0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6, 4, 0)
  );
  { per quarter turn: a direction; the party faces quadrantDirs[facing div 2] when a fight starts, and the rings step
    along these }
  quadrantDirs: array[0..3] of Byte = (
    7, 2, 3, 6
  );
  { the start column of a ring, per first ring or later ring and direction }
  ringStartX: array[0..1, 0..3] of ShortInt = (
    (5, 4, 5, 6), (3, 8, 7, 2)
  );
  { the start row of a ring, per first ring or later ring and direction }
  ringStartY: array[0..1, 0..3] of ShortInt = (
    (3, 2, 2, 3), (0, 2, 5, 3)
  );
  { per quadrant and row: the first and last column a combatant may be placed in }
  zrng: array[0..4, 0..5] of record lo: ShortInt; hi: ShortInt end = (
    ((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10)),
    ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5), (lo: 3; hi: 6), (lo: 4; hi: 7)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0)),
    ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10), (lo: 8; hi: 10)),
    ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10), (lo: 4; hi: 10))
  );
  { per side of a square: the column step toward the neighbouring square scattered features are tried on }
  featDx: array[1..4] of ShortInt = (
      0, 1, 0, -1
  );
  { per side of a square: the row step }
  featDy: array[1..4] of ShortInt = (
    -1, 0, 1, 0
  );
  { the end of the memorize and scribe confirmation prompts }
  gTheseSpells: String[14] = ' these spells?';
  { the camp menu }
  campMenu: String[40] = 'Save View Magic Rest Alter Fix Exit';
  { the camp Magic menu }
  magicMenu: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { the camp Alter menu }
  alterMenu: String[40] = 'Order Drop Speed Icon Level Exit';
  { the camp Level menu, one word per difficulty }
  difficultyMenu: String[40] = 'Novice Squire Veteran Adept Champion';

{ Copy protection: the rule-book question. }
const
  { the scrambled letters of the rule-book headings, stored like wordChars }
  wordChars1: array[1..237] of Byte = (
      0, 6, 19, 6, 9, 6, 23, 254, 17, 6, 12, 11, 19, 17, 7, 12, 5, 222, 11, 3, 12, 19,
      17, 250, 253, 255, 1, 6, 6, 1, 6, 255, 216, 12, 7, 216, 8, 4, 249, 17, 6, 11, 17, 15,
      12, 1, 18, 0, 17, 6, 12, 11, 249, 247, 6, 6, 251, 0, 249, 210, 5, 6, 243, 4, 6, 247,
      246, 210, 3, 7, 251, 245, 253, 254, 11, 252, 255, 0, 9, 12, 255, 218, 19, 9, 15, 218, 10, 6,
      251, 19, 6, 18, 16, 5, 4, 23, 4, 13, 2, 14, 20, 13, 19, 4, 17, 18, 2, 4, 249, 254,
      251, 14, 254, 3, 252, 213, 248, 253, 246, 7, 246, 248, 9, 250, 7, 8, 17, 5, 11, 13, 7, 247,
      250, 12, 251, 4, 10, 11, 8, 255, 4, 253, 214, 5, 6, 10, 255, 5, 4, 9, 8, 17, 6, 4,
      16, 19, 2, 3, 2, 225, 4, 0, 245, 13, 249, 6, 212, 247, 252, 245, 6, 245, 247, 8, 249, 6,
      7, 252, 1, 250, 11, 250, 252, 13, 254, 11, 217, 12, 13, 250, 13, 14, 12, 13, 0, 252, 14, 0,
      5, 254, 215, 250, 255, 248, 9, 248, 250, 11, 252, 9, 10, 255, 2, 20, 3, 12, 18, 19, 16, 7,
      12, 5, 254, 3, 13, 10, 6, 251, 19, 218, 13, 253, 12, 255, 255, 8, 13
  );
  { the scrambled letters of the rule-book answers, stored like wordChars }
  wordChars2: array[1..108] of Byte = (
    25, 20, 28, 19, 18, 10, 19, 26, 12, 6, 18, 10, 16, 7, 7, 10, 4, 10, 2, 13, 5, 15, 4, 7, 8, 22, 8, 20, 21, 30, 4, 16,
    14, 17, 22, 21, 6, 19, 7, 19, 17, 9, 23, 26, 14, 11, 17, 18, 22, 11, 17, 16, 21, 5, 17, 16, 22, 20, 17, 14, 17, 14,
    16, 10, 7, 24, 21, 12, 17, 10, 25, 13, 6, 25, 5, 10, 20, 17, 13, 2, 26, 20, 28, 23, 22, 8, 6, 21, 8, 23, 5, 10, 24,
    9, 22, 22, 23, 4, 23, 24, 22, 5, 17, 15, 15, 3, 16, 6
  );
  { the rule-book headings a question names }
  headTbl: array[1..17] of Types.THeadRec = (
    (textLen: 12; textOfs: 0), (textLen: 11; textOfs: 12), (textLen: 17; textOfs: 23), (textLen: 12; textOfs: 40),
    (textLen: 23; textOfs: 52), (textLen: 15; textOfs: 75), (textLen: 6; textOfs: 90), (textLen: 10; textOfs: 96),
    (textLen: 20; textOfs: 106), (textLen: 5; textOfs: 126), (textLen: 19; textOfs: 131), (textLen: 6; textOfs: 150),
    (textLen: 21; textOfs: 156), (textLen: 16; textOfs: 177), (textLen: 18; textOfs: 193), (textLen: 11; textOfs: 211),
    (textLen: 15; textOfs: 222)
  );
  { the twenty rule-book questions the camp check picks from }
  ruleBook: array[1..20] of Types.TRuleRec = (
    (wordNum: 3; page: 9; headingIdx: 1; answerLen: 4; answerOfs: 0),
    (wordNum: 4; page: 2; headingIdx: 2; answerLen: 4; answerOfs: 4),
    (wordNum: 5; page: 2; headingIdx: 3; answerLen: 4; answerOfs: 8),
    (wordNum: 4; page: 1; headingIdx: 4; answerLen: 8; answerOfs: 12),
    (wordNum: 5; page: 1; headingIdx: 5; answerLen: 6; answerOfs: 20),
    (wordNum: 4; page: 1; headingIdx: 6; answerLen: 4; answerOfs: 26),
    (wordNum: 4; page: 10; headingIdx: 7; answerLen: 8; answerOfs: 30),
    (wordNum: 4; page: 10; headingIdx: 8; answerLen: 5; answerOfs: 38),
    (wordNum: 1; page: 3; headingIdx: 9; answerLen: 3; answerOfs: 43),
    (wordNum: 6; page: 8; headingIdx: 10; answerLen: 7; answerOfs: 46),
    (wordNum: 4; page: 7; headingIdx: 11; answerLen: 7; answerOfs: 53),
    (wordNum: 6; page: 7; headingIdx: 12; answerLen: 4; answerOfs: 60),
    (wordNum: 1; page: 4; headingIdx: 13; answerLen: 6; answerOfs: 64),
    (wordNum: 4; page: 4; headingIdx: 14; answerLen: 4; answerOfs: 70),
    (wordNum: 4; page: 4; headingIdx: 15; answerLen: 8; answerOfs: 74),
    (wordNum: 3; page: 6; headingIdx: 16; answerLen: 2; answerOfs: 82),
    (wordNum: 1; page: 6; headingIdx: 17; answerLen: 6; answerOfs: 84),
    (wordNum: 1; page: 6; headingIdx: 16; answerLen: 5; answerOfs: 90),
    (wordNum: 2; page: 4; headingIdx: 14; answerLen: 6; answerOfs: 95),
    (wordNum: 3; page: 4; headingIdx: 15; answerLen: 7; answerOfs: 101)
  );

{ Camp prompts and the character-generation menus. }
const
  { the verb in the memorize prompts and messages }
  gMemorize: String[9] = 'memorize';
  { the verb in the scribe prompts }
  gScribe: String[7] = 'Scribe';
  { the party-order menu: picking a character, then placing it }
  orderMenus: array[0..1] of String[40] = ('Select Exit', 'Place Exit');
  { the training-hall main menu; CharGen enables entries as the party allows them }
  menuTbl: array[0..12] of record name: String[40]; enabled: Byte end = (
    (name: 'Create New Character'; enabled: 1), (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0), (name: 'Train Character'; enabled: 0),
    (name: 'Human Change Classes'; enabled: 0), (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1), (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1), (name: 'Save Current Game'; enabled: 0),
    (name: 'Begin Adventuring'; enabled: 0), (name: 'Initialize Mouse/Joystick'; enabled: 1),
    (name: 'Exit to DOS'; enabled: 1)
  );
  { the icon-editing menus; CharGen rewrites the third one in place to offer Hair }
  hMenuTable: array[1..5] of String[40] = (
    'Parts 1st-color 2nd-color Size Exit', 'Head Weapon Exit', 'Weapon Body xxxx Shield Arm Leg Exit', ' Keep Exit',
    'Next Prev Keep Exit'
  );

{ Hit dice, saved-character file layouts and the spell-level names. }
const
  { per class: the number of hit dice rolled at first level }
  firstLevelDiceTbl: array[0..6] of Byte = (
    2, 1, 1, 1, 2, 1, 1
  );
  { per class: the sides of its hit die }
  hitDieSidesTbl: array[0..6] of Byte = (
    8, 8, 10, 10, 8, 4, 6
  );
  { fifteen spaces, used to pad a character name to the width of the load list }
  blanks: String[15] = '               ';
  { per saved-character format: the offset of the first name field in the file }
  name1Tab: array[0..1] of Byte = (
    $00, $00
  );
  { per saved-character format: the offset of the second name field }
  name2Tab: array[0..1] of Word = (
    $0084, $00FF
  );
  { per saved-character format: the file size a valid character file has }
  sizeTab: array[0..1] of Word = (
      422, 439
  );
  { the letter that picks the small or tall combat icon heads, as in CHEADS and CHEADT }
  iconClass: array[1..2] of Char = (
    'S', 'T'
  );
  { appended to an ordinal to head a spell level in the spell lists }
  lvlSuffix: String[6] = ' Level';
  { indexed by spellDefs[].level }
  levelOrdinal: array[0..9] of String[3] = (
    '', '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th', '9th'
  );

{ Spell geometry, random items, colors and the name tables. }
const
  { per step direction: the column offset of one cell flanking an area spell's path }
  flank1Dx: array[0..7] of ShortInt = (
    -1, 0, 0, 1, 1, 0, 0, -1
  );
  { per step direction: the row offset of that cell }
  flank1Dy: array[0..7] of ShortInt = (
    0, -1, -1, 0, 0, 1, 1, 0
  );
  { per step direction: the column offset of the cell on the other side }
  flank2Dx: array[0..7] of ShortInt = (
    1, 1, 0, 0, -1, -1, 0, 0
  );
  { per step direction: the row offset of the cell on the other side }
  flank2Dy: array[0..7] of ShortInt = (
      0, 0, 1, 1, 0, 0, -1, -1
  );
  { seven random-item templates of eight words: three name ids, weight, value and three spells }
  randItemW: array[1..56] of Word = (
      95, 94, 53, 1, 400, 3, 99, 0, 80, 90, 53, 1, 550, 1, 59,
      0, 95, 90, 53, 1, 200, 1, 62, 0, 92, 90, 53, 1, 225, 1,
      57, 0, 98, 90, 51, 1, 5500, 30, 65, 0, 104, 90, 53, 1, 500,
      1, 97, 0, 88, 90, 7, 20, 1500, 1, 60, 0
  );
  { the effects removed from a creature whose hit points reach zero }
  hpZeroEffects: array[1..14] of Byte = (
      3, 11, 21, 23, 27, 30, 31, 51, 52, 53, 91, 106, 107, 111
  );
  { per sky index: the 3D view's sky color; MapView picks one from the area or the party's event }
  skyColors: array[0..15] of Byte = (
    0, 15, 4, 11, 13, 2, 9, 14, 0, 15, 4, 11, 13, 2, 9, 14
  );
  { the colors a portrait animation frame is remapped from }
  remapFrom: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
  );
  { the colors it is remapped to: color 13 becomes 0 }
  remapTo: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 0, 14, 15
  );
  { the 3D view's slot geometry }
  wallSliceTable: Types.TWallSliceTable = (
    start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154); cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2); xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5); yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { per CGA color: the byte that fills four pixels with it }
  cgaColorFill: array[0..3] of Byte = (
    $00, $55, $AA, $FF
  );
  { per Tandy color: the byte that fills two pixels with it }
  tandyColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF
  );
  { the characters a word-wrapped line may break after }
  breakChars: Types.TBrkSet = ['!', ',', '-', '.', ':', ';', '?'];
  { the characters a save-game name may not contain }
  invalidFileChars: array[1..10] of Char = (
    ' ', '.', '*', ',', '?', '/', '\', ':', ';', '|'
  );
  { per coin kind: its value in copper pieces }
  coinValue: array[0..4] of LongInt = (
      1, 10, 100, 200, 1000
  );
  { the prompt shown before the game waits for Enter }
  continuePrompt: String[40] = 'press <enter>/<return> to continue';
  { the configuration file the start-up questions write }
  cfgName: String[13] = 'blades.cfg';
  { per class id: its name, multi-classes included }
  classNames: array[0..17] of String[26] = (
    'Cleric', 'Druid', 'Fighter', 'Paladin', 'Ranger', 'Magic-User', 'Thief', 'Monk', 'Cleric/Fighter',
    'Cleric/Fighter/Magic-User', 'Cleric/Ranger', 'Cleric/Magic-User', 'Cleric/Thief', 'Fighter/Magic-User',
    'Fighter/Thief', 'Fighter/Magic-User/Thief', 'Magic-User/Thief', 'Illegal type'
  );
  { per race id: its name }
  raceNames: array[0..7] of String[8] = (
    'Tribble', 'Elf', 'Half-Elf', 'Dwarf', 'Gnome', 'Halfling', 'Human', 'Monster'
  );
  { per alignment: its name }
  alignNames: array[0..8] of String[16] = (
    'Lawful Good', 'Lawful Neutral', 'Lawful Evil', 'Neutral Good', 'True Neutral', 'Neutral Evil', 'Chaotic Good',
    'Chaotic Neutral', 'Chaotic Evil'
  );
  { per gender: its name }
  genderNames: array[0..1] of String[6] = (
    'Male', 'Female'
  );
  { per coin kind: its name }
  moneyNames: array[0..6] of String[10] = (
    'Copper', 'Silver', 'Electrum', 'Gold', 'Platinum', 'Gems', 'Jewelry'
  );
  { per status: its name }
  statusNames: array[0..8] of String[12] = (
    'Okay', 'Animated', 'tempgone', 'Running', 'Unconscious', 'Dying', 'Dead', 'Petrified', 'Gone'
  );
  { Item-name fragments. charhlp's printItemString builds a name from an item's nameIds (0 is none), and modeinit copies
    one of them as the STING key. }
  itemNames: array[1..123] of String[20] = (
    'Battle Axe', 'Hand Axe', 'Club', 'Dagger', 'Dart', 'Hammer', 'Javelin', 'Mace', 'Morning Star', 'Military Pick',
    'Awl Pike', 'Quarrel', 'Scimitar', 'Spear', 'Quarter Staff', 'Bastard Sword', 'Broad Sword', 'Long Sword',
    'Short Sword', 'Two-Handed Sword', 'Trident', 'Composite Long Bow', 'Composite Short Bow', 'Long Bow',
    'Short Bow', 'Fine', 'Light Crossbow', 'Sling', 'Staff', 'Arrow', 'Leather', 'Ring', 'Scale', 'Chain', 'Banded',
    'Plate', 'Shield', 'Cler', 'Scroll', 'Mage', 'Helm', 'Belt', 'Robe', 'Cloak', 'Boots', 'Ring', 'Mail', 'Armor',
    'Of Prot', 'Bracers', 'Wand', 'Elixer', 'Potion', 'Youth', 'Ruby', 'Boulder', 'Dragon Breath', 'Displacement',
    'Eyes', 'Drow', 'Elven Chain', 'Ice Storm', 'Saphire', 'Emerald', 'Wizardry', 'Hornet''s Nest', 'Fire Resistance',
    'Stone', 'Good Luck', 'Flail', 'Halberd', 'Gauntlets', 'Periapt', 'Health', '', '', 'Bundle of', 'Ogre Power',
    'Girdle', 'Giant Strength', 'Mirror', 'Necklace', 'Dragon', 'vs Giants', '', '', 'Diamond', 'Lightning',
    'Fireballs', 'of', 'Vulnerability', 'Speed', 'Silver', 'Extra', 'Healing', 'Charming', 'Fear', 'Magic Missiles',
    'Missiles', '1 Spell', '2 Spells', '3 Spells', 'Paralyzation', 'Invisibility', 'Cute Yellow Canary', 'AC 10',
    'AC 6', 'AC 4', 'AC 3', 'AC 2', '+1', '+2', '+3', '+4', '+5', '-1', '-2', '-3', '', '', 'Spiritual', 'Gem',
    'Jewelry'
  );

{ Compass names and the CGA text colors. }
const
  { the compass names of the eight directions, shown on the status line }
  dirNames: array[0..7] of String[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'
  );
  { [row step + 1, column step + 1]: the direction that step is }
  dirByDelta: array[0..2, 0..2] of Byte = (
    (7, 0, 1), (6, 8, 2), (5, 4, 3)
  );
  { unused }
  dirByDeltaTail: array[0..11] of Byte = (
    8, 4, 2, 1, 0, 0, $55, $55, $AA, $AA, $FF, $FF
  );
  { CGA 2bpp color pattern, read by the text blitters }
  colorTab: array[0..15] of Byte = (
    0, 0, 0, 1, 2, 2, 2, 3, 0, 1, 1, 1, 2, 2, 3, 3
  );
  { per pixel of a CGA word: the mask that selects it }
  cgaBankMask: array[0..7] of Word = (
    $C000, $3000, $0C00, $0300, $00C0, $0030, $000C, $0003
  );

{ Video tables, sound commands, disk prompts, symbols, combat geometry and effect text. }
const
  { per EGA plane: its bit in the sequencer's map mask }
  egaPlaneBit: array[0..3] of Byte = (
      $01, $02, $04, $08
  );
  { per CGA color and pixel position: the bits that draw it }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00), ($40, $10, $04, $01), ($80, $20, $08, $02), ($C0, $30, $0C, $03)
  );
  { the standard color map the picture blitters remap through }
  cmapStd: Types.TColorMap = (
    $00, $11, $22, $12, $01, $21, $30, $33
  );
  { the identity color map }
  cmapIdent: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
  );
  { the color map that turns color 8 into 0 }
  cmap8To0: Types.TColorTab = (
    0, 1, 2, 3, 4, 5, 6, 7, 0, 9, 10, 11, 12, 13, 14, 15
  );
  { the sound command sent before the sound is started again }
  sfxReset: Word = 255;
  { the sound command that pauses sound while a DAX file is read }
  sfxOff: Word = 0;
  { the sound command that resumes it }
  sfxOn: Word = 1;
  { the sound a spell plays when it has none of its own }
  defaultSpellSound: Word = 2;
  { the sound of a missed attack }
  missSound: Word = 3;
  { the sound of a hit }
  hitSound: Word = 4;
  { the sound of a combatant going down }
  downedSound: Word = 5;
  { the sound of a sling shot }
  slingSound: Word = 6;
  { the sound of a weapon striking }
  strikeSound: Word = 7;
  { the sound of a lightning bolt }
  lightningSound: Word = 8;
  { the sound of a weapon swing }
  swingSound: Word = 9;
  { the sound of a step }
  stepSound: Word = 10;
  { the sound of an explosion }
  explosionSound: Word = 11;
  { the four arrow sounds }
  arrowSounds: array[0..3] of Word = (
    12, 13, 14, 15
  );
  { per game disk: the prompt asking for it }
  diskPath: array[1..5] of String[29] = (
    'Insert disk 2 in drive ', 'Insert disk 3 in drive ', 'Insert disk 4 in drive ', '', 'Insert disk 5 in drive '
  );
  { per 8x8 symbol set: the index of its first symbol }
  symSetFirst: array[0..4] of Word = (
    1, 46, 116, 186, 256
  );
  { per 8x8 symbol set: the index of its last symbol }
  symSetLast: array[0..4] of Word = (
    45, 115, 185, 255, 295
  );
  { dirDX/dirDY: the per-direction X and Y deltas; index 0..7 = N NE E SE S SW W NW, 8 = no move. This is the X table. }
  dirDx: array[0..8] of ShortInt = (
    0, 1, 1, 1, 0, -1, -1, -1, 0
  );
  { the per-direction Y deltas }
  dirDy: array[0..8] of ShortInt = (
    -1, -1, 0, 1, 1, 1, 0, -1, 0
  );
  { the battle map's terrain types, by terrain index }
  terrainInfo: array[1..30] of Types.TTerrainRec = (
    (cost: 255; clearance: 1; blocking: 2; id: 0),
    (cost: 255; clearance: 1; blocking: 2; id: 1),
    (cost: 255; clearance: 1; blocking: 2; id: 2),
    (cost: 255; clearance: 1; blocking: 2; id: 3),
    (cost: 1; clearance: 1; blocking: 0; id: 4),
    (cost: 255; clearance: 1; blocking: 2; id: 5),
    (cost: 255; clearance: 1; blocking: 2; id: 6),
    (cost: 255; clearance: 1; blocking: 2; id: 7),
    (cost: 1; clearance: 1; blocking: 0; id: 8),
    (cost: 255; clearance: 1; blocking: 2; id: 9),
    (cost: 1; clearance: 1; blocking: 0; id: 10),
    (cost: 255; clearance: 1; blocking: 2; id: 11),
    (cost: 1; clearance: 1; blocking: 0; id: 12),
    (cost: 255; clearance: 1; blocking: 2; id: 13),
    (cost: 1; clearance: 1; blocking: 0; id: 14),
    (cost: 255; clearance: 1; blocking: 2; id: 15),
    (cost: 1; clearance: 1; blocking: 0; id: 16),
    (cost: 255; clearance: 1; blocking: 2; id: 17),
    (cost: 255; clearance: 1; blocking: 2; id: 18),
    (cost: 255; clearance: 1; blocking: 2; id: 19),
    (cost: 255; clearance: 1; blocking: 2; id: 20),
    (cost: 255; clearance: 1; blocking: 2; id: 21),
    (cost: 1; clearance: 1; blocking: 0; id: 22),
    (cost: 1; clearance: 1; blocking: 0; id: 23),
    (cost: 255; clearance: 1; blocking: 2; id: 24),
    (cost: 1; clearance: 1; blocking: 0; id: 25),
    (cost: 1; clearance: 1; blocking: 0; id: 26),
    (cost: 1; clearance: 1; blocking: 0; id: 27),
    (cost: 1; clearance: 1; blocking: 0; id: 28),
    (cost: 1; clearance: 1; blocking: 0; id: 29)
  );
  { per icon size and footprint cell: the cell's offset }
  iconDelta: array[1..4, 0..3] of Types.TIconDelta = (
    ((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1)),
    ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1), (dx: 1; dy: 1))
  );
  { paralysis-type effect ids }
  helplessFx: array[1..4] of Byte = (
      31, 51, 52, 53
  );
  { the disease effect ids a cure strips }
  diseaseFx: array[1..4] of Byte = (
    31, 34, 43, 44
  );
  { the effect ids PostCbt removes from the party after a fight }
  animTable: array[1..11] of Byte = (
    3, 11, 21, 23, 27, 35, 40, 31, 51, 52, 53
  );
  { the verb between a creature's name and the state a spell leaves it in }
  msgIs: String = 'is ';
  { the state a healing spell reports }
  msgHealed: String = 'Healed';
  { the state a spell reports when it took }
  msgAffected: String = 'Affected';
  { the state a spell reports when it did not take }
  msgUnaffected: String = 'Unaffected';
  { the state a protection spell reports }
  msgProtected: String = 'Protected';
  { the verb before what a creature gains }
  msgGains: String = 'gains ';
  { the start of the protection messages }
  msgProtectedFrom: String = 'Protected from ';
  { per effect id: the name of the state it leaves a creature in, shown on the character sheet and in spell messages }
  effectNames: array[1..120] of String[37] = (
    'Blessed', 'Cursed', 'Harrassed by Snakes', 'Dispelling Evil', 'Detecting Magic', '', '', 'Protected from Evil',
    'Protected from Good', 'Resistant to Cold', 'Charmed', 'Enlarged', 'Barkskin', 'Friendly', 'Slow Poison',
    'Reading Magic', 'Shielded', '', 'Able to Find Traps', 'Fire Resistant (spell)', 'Silenced', '',
    'Carries Spiritual Hammer', 'Sees Invisible', 'Invisible (spell)', '', 'Befuddled', 'Duplicated', 'Weakened',
    'Nauseated', '', '', 'Blind', 'Diseased', 'Confused', 'Accursed', 'Blinking', 'Strengthened', 'Hastened', '',
    'Protected from Normal Missiles', 'Slowed', '', '', 'Protected from Evil, 10'' Radius',
    'Protected from Good, 10'' Radius', '', '', 'Affected by Prayer', 'Fire Shield, Hot flames', '', 'Held', 'Asleep',
    'Fire Shield, Cold flames', 'POISONED', 'Invisible (ring)', 'Enveloped in Globe of Invulnerability', '', '', '',
    'Fire Resistant (ring)', '', 'Within Minor Globe of Invulnerability', '', '', '', '', 'Mentally Enfeebled',
    'Invisible to Animals', '', 'Magically Highlighted', '', 'Immune to Dragon Breath', 'Wearing Magical Boots', '',
    'Immune to Disease', 'Confused', 'Carrying Magical Stone', '', '', '', '', '', '', '', '', '', '',
    'Wearing Magical Cloak', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'STUNNED', 'Berserk', '',
    '', '', 'FRIGHTENED', '', 'Giant Strength', '', '', '', '', '', '', ''
  );

{ Keypad, mouse direction and cloud tables. }
const
  { per keypad digit '1' to '9': the scan code it stands for }
  keyRemap: array[0..8] of Byte = (
    Ord(C_Keys.END_KEY), Ord(C_Keys.DOWN), Ord(C_Keys.PAGE_DOWN), Ord(C_Keys.LEFT), 32, Ord(C_Keys.RIGHT),
    Ord(C_Keys.HOME), Ord(C_Keys.UP), Ord(C_Keys.PAGE_UP)
  );
  { the mouse direction grid: per row and column around the cursor, the scan code of the arrow key a click there gives }
  dirTable: array[3..13, 3..13] of Byte = (
    (72, 72, 72, 72, 72, 72, 72, 72, 72, 72, 72),
    (75, 72, 72, 72, 72, 72, 72, 72, 72, 72, 77),
    (75, 75, 72, 72, 72, 72, 72, 72, 72, 77, 77),
    (75, 75, 75, 72, 72, 72, 72, 72, 77, 77, 77),
    (75, 75, 75, 75, 72, 72, 72, 77, 77, 77, 77),
    (75, 75, 75, 75, 75, 72, 77, 77, 77, 77, 77),
    (75, 75, 75, 75, 80, 80, 80, 77, 77, 77, 77),
    (75, 75, 75, 80, 80, 80, 80, 80, 77, 77, 77),
    (75, 75, 80, 80, 80, 80, 80, 80, 80, 77, 77),
    (75, 80, 80, 80, 80, 80, 80, 80, 80, 80, 77),
    (80, 80, 80, 80, 80, 80, 80, 80, 80, 80, 80)
  );
  { the directions of the four cells a small cloud covers }
  cloudDirs: array[1..4] of Byte = (
    C_Dir.CENTER, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.SOUTH
  );
  { the directions of the nine cells a large cloud covers }
  cloudDirs9: array[1..9] of Byte = (
    C_Dir.CENTER, C_Dir.NORTH, C_Dir.NORTHEAST, C_Dir.EAST, C_Dir.SOUTHEAST, C_Dir.SOUTH,
    C_Dir.SOUTHWEST, C_Dir.WEST, C_Dir.NORTHWEST
  );

{ Spell names and spell definitions. }
const
  { per spell id: its name }
  spellNames: array[1..117] of String[34] = (
    'Bless', 'Curse', 'Cure Light Wounds', 'Cause Light Wounds', 'Detect Magic', 'Protection From Evil',
    'Protection from Good', 'Resist Cold', 'Burning Hands', 'Charm Person', 'Detect Magic', 'Enlarge', 'Reduce',
    'Friends', 'Magic Missile', 'Protection From Evil', 'Protection From Good', 'Read Magic', 'Shield',
    'Shocking Grasp', 'Sleep', 'Find Traps', 'Hold Person', 'Resist Fire', 'Silence, 15'' Radius', 'Slow Poison',
    'Snake Charm', 'Spiritual Hammer', 'Detect Invisibility', 'Invisibility', 'Knock', 'Mirror Image',
    'Ray of Enfeeblement', 'Stinking Cloud', 'Strength', 'Heal', 'Cure Blindness', 'Cause Blindness', 'Cure Disease',
    'Cause Disease', 'Dispel Magic', 'Prayer', 'Remove Curse', 'Bestow Curse', 'Blink', 'Dispel Magic', 'Fireball',
    'Haste', 'Hold Person', 'Invisibility, 10'' Radius', 'Lightning Bolt', 'Protection From Evil, 10'' Radius',
    'Protection From Good, 10'' Radius', 'Protection From Normal Missiles', 'Slow', 'Harm', 'spell 57',
    'Cure Serious Wounds', 'spell 59', 'spell 60', 'spell 61', 'spell 62', 'spell 63', 'spell 64', 'spell 65',
    'Cause Serious Wounds', 'Neutralize Poison', 'Poison', 'Protection Evil, 10'' Radius', 'Sticks to Snakes',
    'Cure Critical Wounds', 'Cause Critical Wounds', 'Dispel Evil', 'Flame Strike', 'Raise Dead', 'Slay Living',
    'Detect Magic', 'Entangle', 'Faerie Fire', 'Invisibility to Animals', 'Charm Monsters', 'Confusion',
    'Dimension Door', 'Fear', 'Fire Shield', 'Fumble', 'Ice Storm', 'Minor Globe Of Invulnerability', 'Remove Curse',
    'Barkskin', 'Cloud Kill', 'Cone of Cold', 'Feeblemind', 'Hold Monsters', 'spell 95', 'Charm Person Or Mammal',
    'spell 97', 'Cure Light Wounds', 'spell 99', 'Bestow Curse', 'spell 101', 'spell 102', 'spell 103', 'spell 104',
    'spell 105', 'spell 106', 'spell 107', 'spell 108', 'spell 109', 'Death Spell', 'Disintegrate',
    'Globe of Invulnerability', 'Stone to Flesh', 'Flesh to Stone', 'Delayed Blast Fireball', 'Mass Invisibility',
    'Power Word Stun'
  );
  { per spell id: its class, level, range, duration, area, saving throw, effect and AI hints }
  spellDefs: array[1..117] of Types.TSpellDef = (
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durationBase: 6; durationPerLevel: 0; area: 10;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 1; castContext: 2; castTime: 10; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 6; rangePerLevel: 0; durationBase: 6; durationPerLevel: 0; area: 10;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 2; castContext: 1; castTime: 10; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 5; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 5; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 3; rangePerLevel: 0; durationBase: 10; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 5; castContext: 2; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 3; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 8; castContext: 2; castTime: 4; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 3; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 9; castContext: 2; castTime: 4; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 10; castContext: 2; castTime: 10; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 2;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 12; rangePerLevel: 0; durationBase: 60; durationPerLevel: 60; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 11; castContext: 1; castTime: 1; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 5; castContext: 2; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 2; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 12; castContext: 2; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 2; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 1; saveType: 4; effectId: 12; castContext: 2; castTime: 1; aiPriority: 0;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 14; castContext: 0; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 6; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 8; castContext: 2; castTime: 1; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 9; castContext: 2; castTime: 1; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 16; castContext: 0; castTime: 10; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 5; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 17; castContext: 2; castTime: 1; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 2;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 1; rangeBase: 3; rangePerLevel: 4; durationBase: 0; durationPerLevel: 5; area: 9;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 53; castContext: 1; castTime: 1; aiPriority: 4;
     offensive: 1; aiRadius: 1),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 30; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 19; castContext: 0; castTime: 5; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 6; rangePerLevel: 0; durationBase: 4; durationPerLevel: 1; area: 6;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 52; castContext: 1; castTime: 5; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 20; castContext: 2; castTime: 5; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 31;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 21; castContext: 1; castTime: 5; aiPriority: 2;
     offensive: 1; aiRadius: 1),
    (castClass: 0; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 60; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 22; castContext: 0; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 240;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 51; castContext: 1; castTime: 5; aiPriority: 0;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 2; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 23; castContext: 2; castTime: 5; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 5; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 24; castContext: 2; castTime: 2; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 25; castContext: 2; castTime: 2; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 0; castTime: 1; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 28; castContext: 2; castTime: 2; aiPriority: 3;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 1; rangePerLevel: 1; durationBase: 0; durationPerLevel: 1; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 29; castContext: 1; castTime: 2; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 2; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 9;
     noncombatTarget: 0; saveEffect: 3; saveType: 0; effectId: 30; castContext: 1; castTime: 2; aiPriority: 4;
     offensive: 1; aiRadius: 1),
    (castClass: 3; level: 2; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 60; area: 0;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 38; castContext: 0; castTime: 10; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 6; rangeBase: 5; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 0; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 10; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 33; castContext: 1; castTime: 10; aiPriority: 3;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 0; castTime: 100; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 34; castContext: 1; castTime: 100; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 9;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 4; aiPriority: 1;
     offensive: 1; aiRadius: 1),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 49; castContext: 2; castTime: 6; aiPriority: 5;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 6; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 3; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 36; castContext: 1; castTime: 6; aiPriority: 2;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 37; castContext: 1; castTime: 1; aiPriority: 4;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 9;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 3; aiPriority: 1;
     offensive: 1; aiRadius: 1),
    (castClass: 3; level: 3; rangeBase: 10; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 11;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 3; aiPriority: 7;
     offensive: 1; aiRadius: 3),
    (castClass: 3; level: 3; rangeBase: 6; rangePerLevel: 0; durationBase: 3; durationPerLevel: 1; area: 10;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 39; castContext: 2; castTime: 3; aiPriority: 5;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 7;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 52; castContext: 1; castTime: 3; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 9;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 25; castContext: 2; castTime: 3; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 4; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 8;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 3; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 45; castContext: 2; castTime: 3; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 46; castContext: 2; castTime: 3; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 41; castContext: 2; castTime: 3; aiPriority: 3;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 3; rangeBase: 9; rangePerLevel: 4; durationBase: 3; durationPerLevel: 1; area: 10;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 42; castContext: 1; castTime: 3; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 10; aiPriority: 0;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 39; castContext: 2; castTime: 0; aiPriority: 3;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 7; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 113; castContext: 2; castTime: 0; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 9; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 0; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 0; effectId: 52; castContext: 1; castTime: 0; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 0; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 7;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 0; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 7; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 11;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 0; aiPriority: 7;
     offensive: 1; aiRadius: 3),
    (castClass: 4; level: 6; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 0; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 7; aiPriority: 3;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 0; castTime: 7; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 0; effectId: 0; castContext: 1; castTime: 7; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 45; castContext: 2; castTime: 7; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 4; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 3; castContext: 1; castTime: 7; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 8; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 8; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 32; castContext: 1; castTime: 8; aiPriority: 5;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 8; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 0; castTime: 10; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 0; level: 5; rangeBase: 3; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 10; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 3; rangePerLevel: 0; durationBase: 12; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 5; castContext: 2; castTime: 3; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durationBase: 10; durationPerLevel: 0; area: 11;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 3; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 8; rangePerLevel: 0; durationBase: 0; durationPerLevel: 4; area: 5;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 71; castContext: 1; castTime: 3; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 1; level: 1; rangeBase: 255; rangePerLevel: 0; durationBase: 10; durationPerLevel: 1; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 69; castContext: 2; castTime: 4; aiPriority: 1;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 5;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 11; castContext: 1; castTime: 4; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 12; rangePerLevel: 0; durationBase: 2; durationPerLevel: 1; area: 11;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 35; castContext: 1; castTime: 4; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 12; durationBase: 0; durationPerLevel: 0; area: 8;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 0;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 8;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 111; castContext: 1; castTime: 4; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 2; durationPerLevel: 1; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 4; aiPriority: 7;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 1; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 27; castContext: 1; castTime: 4; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 10;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 4; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 16; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 63; castContext: 2; castTime: 4; aiPriority: 6;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 4; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 1; level: 2; rangeBase: 1; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 240;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 13; castContext: 2; castTime: 3; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 5; rangeBase: 2; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 9;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 5; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 5; rangeBase: 6; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 8;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 5; aiPriority: 6;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 5; rangeBase: 16; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 68; castContext: 1; castTime: 5; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 5; rangeBase: 0; rangePerLevel: 2; durationBase: 0; durationPerLevel: 1; area: 7;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 52; castContext: 1; castTime: 5; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 73; castContext: 2; castTime: 10; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 1; level: 2; rangeBase: 8; rangePerLevel: 0; durationBase: 60; durationPerLevel: 60; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 11; castContext: 1; castTime: 4; aiPriority: 5;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 25; castContext: 2; castTime: 0; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 1; level: 2; rangeBase: 255; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 4; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 0; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 4; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 10; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 36; castContext: 1; castTime: 4; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 3; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 2; area: 31;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 5; aiPriority: 2;
     offensive: 1; aiRadius: 1),
    (castClass: 4; level: 0; rangeBase: 0; rangePerLevel: 0; durationBase: 10; durationPerLevel: 0; area: 0;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 0; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 6; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 6; rangePerLevel: 0; durationBase: 6; durationPerLevel: 0; area: 10;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 10; aiPriority: 1;
     offensive: 0; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 12; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 4;
     offensive: 1; aiRadius: 0),
    (castClass: 4; level: 0; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 3;
     offensive: 1; aiRadius: 0),
    (castClass: 1; level: 9; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 0;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 0; aiPriority: 0;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 0; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 3;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 9;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 0; castContext: 1; castTime: 6; aiPriority: 3;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 2; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 0; castContext: 1; castTime: 6; aiPriority: 8;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 0; durationBase: 0; durationPerLevel: 1; area: 4;
     noncombatTarget: 1; saveEffect: 0; saveType: 4; effectId: 57; castContext: 2; castTime: 1; aiPriority: 3;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 2; saveEffect: 0; saveType: 4; effectId: 0; castContext: 2; castTime: 6; aiPriority: 2;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 6; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 1; saveType: 4; effectId: 65; castContext: 1; castTime: 6; aiPriority: 7;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 7; rangeBase: 10; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 11;
     noncombatTarget: 0; saveEffect: 2; saveType: 4; effectId: 0; castContext: 1; castTime: 1; aiPriority: 9;
     offensive: 1; aiRadius: 0),
    (castClass: 3; level: 7; rangeBase: 0; rangePerLevel: 4; durationBase: 0; durationPerLevel: 0; area: 10;
     noncombatTarget: 3; saveEffect: 0; saveType: 4; effectId: 25; castContext: 2; castTime: 7; aiPriority: 3;
     offensive: 0; aiRadius: 0),
    (castClass: 3; level: 7; rangeBase: 0; rangePerLevel: 2; durationBase: 0; durationPerLevel: 0; area: 4;
     noncombatTarget: 0; saveEffect: 0; saveType: 4; effectId: 106; castContext: 1; castTime: 1; aiPriority: 3;
     offensive: 1; aiRadius: 0)
  );

{ Game clock and base to-hit. }
const
  { clockRadix: the mixed-radix ladder for both game-time values. }
  clockRadix: array[0..6] of Word = (
      10, 10, 6, 24, 30, 12, 100
  );
  { per class and level: the base to-hit value }
  baseToHitTbl: array[0..6, 0..18] of Byte = (
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50),
    (40, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50),
    (39, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57),
    (40, 40, 40, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57),
    (39, 39, 39, 39, 39, 39, 41, 41, 41, 41, 41, 43, 43, 43, 43, 43, 46, 46, 46),
    (40, 40, 40, 40, 40, 41, 41, 41, 41, 44, 44, 44, 44, 46, 46, 46, 46, 48, 48)
  );

{ Class, race and stat rules, experience and spell-slot tables, saving throws and the mouse and joystick maps. }
const
  { per class: its bit in a character's class mask }
  classMaskTbl: array[0..6] of Byte = (
    $02, $10, $08, $40, $40, $01, $04
  );
  { per class: the bit that marks it in the hit-point roll mask }
  rollClassMaskTbl: array[0..15] of Byte = (
    $02, $02, $08, $10, $20, $01, $04, $10, $10, $10, $20, $20, $20, $40, $40, $40
  );
  { per class 0..6, the first level whose hit points are a fixed gain instead of a die }
  firstFixedHpLevel: array[0..6] of Byte = (
    10, 15, 10, 10, 11, 12, 11
  );
  { per icon color slot 1..6: the base color of the slot's color pair }
  statInitTbl: array[1..6] of Byte = (
    1, 2, 3, 4, 6, 7
  );
  { per thief level: the base skill percentages }
  thiefBase: array[1..18, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0),
    (35, 29, 25, 21, 15, 10, 86, 0),
    (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20),
    (50, 42, 40, 40, 31, 20, 90, 25),
    (55, 47, 45, 47, 37, 20, 92, 30),
    (60, 52, 50, 55, 43, 25, 94, 35),
    (65, 57, 55, 62, 49, 25, 96, 40),
    (70, 62, 60, 70, 56, 30, 98, 45),
    (80, 67, 65, 78, 63, 30, 99, 50),
    (90, 72, 70, 86, 70, 35, 99, 55),
    (100, 77, 75, 94, 77, 35, 99, 60),
    (105, 82, 80, 99, 85, 40, 99, 65),
    (110, 87, 85, 99, 93, 40, 99, 70),
    (115, 92, 90, 99, 99, 50, 100, 75),
    (125, 97, 95, 99, 99, 50, 100, 80),
    (125, 99, 99, 99, 99, 55, 100, 80),
    (130, 99, 99, 99, 99, 55, 100, 85)
  );
  { per race: the thief skill adjustments. Rows 1..5 are AD&D's Elf, Half-Elf, Dwarf, Gnome and Halfling adjustments, in
    chargen's race-menu order; row 6 carries AD&D's Half-Orc row, and raceNames[6] is 'Human'. }
  raceAdj: array[1..6, 1..8] of ShortInt = (
    (5, -5, 0, 5, 10, 5, 0, 0),
    (10, 0, 0, 0, 5, 0, 0, 0),
    (0, 10, 15, 0, 0, 0, -10, -5),
    (0, 5, 10, 5, 5, 10, -15, 0),
    (5, 5, 5, 10, 15, 5, -15, -5),
    (-5, 5, 5, 0, 0, 5, 5, -10)
  );
  { per Dexterity 9..19: the adjustments to the first five thief skills. Note: Dexterity 10 gives -19 to pick pockets
    and Dexterity 16 gives -5 to open locks, where the AD&D table has -10 and +5. }
  dexAdj: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10),
    (-19, -5, -10, -15, -5),
    (-5, 0, -5, -10, 0),
    (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, 0, 0, 0, 0),
    (0, -5, 0, 0, 0),
    (5, 10, 0, 5, 5),
    (10, 15, 5, 10, 10),
    (15, 20, 10, 12, 12)
  );
  { per race: the stat limits; the strength limits are per gender }
  raceLimits: array[1..6] of Types.TRaceLimits = (
    (strMin: (3, 3); strMax: (18, 16); strExcMax: (75, 0); intMin: 8; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 7; dexMax: 19; conMin: 6; conMax: 18; chaMin: 8;
     chaMax: 18),
    (strMin: (3, 3); strMax: (18, 17); strExcMax: (90, 0); intMin: 4; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 6; dexMax: 18; conMin: 6; conMax: 18; chaMin: 3;
     chaMax: 18),
    (strMin: (8, 8); strMax: (18, 17); strExcMax: (99, 0); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 17; conMin: 12; conMax: 19; chaMin: 3;
     chaMax: 16),
    (strMin: (6, 6); strMax: (18, 15); strExcMax: (50, 0); intMin: 7; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 8; conMax: 18; chaMin: 3;
     chaMax: 18),
    (strMin: (6, 6); strMax: (17, 14); strExcMax: (0, 0); intMin: 6; intMax: 18;
     wisMin: 3; wisMax: 17; dexMin: 8; dexMax: 18; conMin: 10; conMax: 19; chaMin: 3;
     chaMax: 18),
    (strMin: (3, 3); strMax: (18, 18); strExcMax: (100, 50); intMin: 3; intMax: 18;
     wisMin: 3; wisMax: 18; dexMin: 3; dexMax: 18; conMin: 3; conMax: 18; chaMin: 3;
     chaMax: 18)
  );
  { per race: how many classes it may take, then their ids }
  raceClassTbl: array[1..6, 0..13] of ShortInt = (
      (7, 2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0), (13, 0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16),
      (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
      (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (6, 0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0)
  );
  { per race and class: the starting age and the dice added to it }
  startAgeTbl: array[1..6, 0..6] of Types.TStartAge = (
    ((base: 650; dice: 10; sides: 10), (base: 0; dice: 0; sides: 0), (base: 130; dice: 5; sides: 6),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 150; dice: 5; sides: 6),
     (base: 100; dice: 5; sides: 6)),
    ((base: 40; dice: 2; sides: 4), (base: 0; dice: 0; sides: 0), (base: 22; dice: 3; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 30; dice: 2; sides: 8),
     (base: 22; dice: 3; sides: 8)),
    ((base: 250; dice: 2; sides: 20), (base: 0; dice: 0; sides: 0), (base: 40; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 75; dice: 3; sides: 6)),
    ((base: 300; dice: 3; sides: 12), (base: 0; dice: 0; sides: 0), (base: 60; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 100; dice: 2; sides: 12),
     (base: 80; dice: 5; sides: 4)),
    ((base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 20; dice: 3; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 40; dice: 2; sides: 4)),
    ((base: 18; dice: 1; sides: 4), (base: 18; dice: 1; sides: 4), (base: 15; dice: 1; sides: 4),
     (base: 17; dice: 1; sides: 4), (base: 20; dice: 1; sides: 4), (base: 24; dice: 2; sides: 4),
     (base: 18; dice: 1; sides: 4))
  );
  { per race: the ages at which a character moves to the next age category }
  ageTbl: array[1..6, 0..4] of Word = (
    (175, 550, 875, 1200, 1600), (40, 100, 175, 250, 325), (50, 150, 250, 350, 450),
    (90, 300, 450, 600, 750), (33, 68, 101, 144, 199), (20, 40, 60, 90, 120)
  );
  { per class and stat: the minimum score the class needs }
  classMinTbl: array[0..16, 0..5] of Byte = (
      (6, 6, 9, 0, 0, 0), (0, 0, 12, 0, 0, 15), (9, 0, 6, 6, 7, 0),
      (12, 9, 13, 0, 9, 17), (13, 13, 14, 0, 14, 0), (0, 9, 6, 6, 0, 0),
      (6, 6, 0, 9, 0, 0), (15, 0, 15, 15, 11, 0), (9, 0, 9, 0, 0, 0),
      (9, 9, 9, 0, 0, 0), (0, 13, 14, 0, 14, 0), (0, 9, 9, 0, 0, 0),
      (0, 0, 9, 9, 0, 0), (9, 9, 0, 0, 0, 0), (9, 0, 0, 9, 0, 0),
      (9, 9, 0, 9, 0, 0), (0, 9, 0, 9, 0, 0)
  );
  { per class: how many alignments it may take, then the alignments }
  classAlignTbl: array[0..16, 0..9] of Byte = (
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (5, 1, 3, 4, 5, 7, 0, 0, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (1, 0, 0, 0, 0, 0, 0, 0, 0, 0), (3, 0, 3, 6, 0, 0, 0, 0, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (3, 0, 3, 6, 0, 0, 0, 0, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0)
  );
  { per Constitution score: the hit-point bonus }
  conBonusTbl: array[3..25] of ShortInt = (
    -2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2
  );
  { per class: the experience each level needs and the spell slots gained at each level }
  classProgression: array[0..6] of Types.TClassProgression = (
    (nextLevelXp: (
       1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001, 450001, 675001, 900001, 1125001, 1350001, 1575001, -1,
       -1, -1);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0, 0), (1, 1, 0, 0, 0, 0, 0), (0, 1, 1, 0, 0, 0, 0),
       (0, 0, 1, 0, 0, 0, 0), (0, 0, 0, 1, 0, 0, 0), (0, 0, 1, 1, 0, 0, 0), (1, 1, 0, 0, 1, 0, 0),
       (0, 0, 0, 1, 1, 0, 0), (1, 0, 1, 0, 0, 1, 0), (1, 1, 1, 0, 0, 1, 0), (0, 1, 1, 1, 0, 0, 0),
       (0, 0, 0, 1, 1, 0, 0), (1, 1, 1, 0, 1, 0, 0), (0, 0, 0, 1, 1, 1, 1), (1, 1, 1, 0, 0, 0, 0),
       (0, 0, 0, 1, 1, 1, 0))),
    (nextLevelXp: (
       -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0))),
    (nextLevelXp: (
       2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001, 500001, 750001, 1000001, 1250001, 1500001, 1750001, -1,
       -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0))),
    (nextLevelXp: (
       2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001, 700001, 1050001, 1400001, 1750001, 2100001, 2460001,
       -1, -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (1, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0, 0), (0, 0, 1, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0), (1, 0, 0, 0, 0, 0, 0), (0, 0, 0, 1, 0, 0, 0), (0, 0, 1, 0, 0, 0, 0),
       (0, 0, 0, 1, 0, 0, 0))),
    (nextLevelXp: (
       2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001, 325001, 650001, 975001, 1300001, 1625001, 1950001, -1,
       -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (1, 0, 0, 0, 0, 0, 0), (0, 0, 0, 1, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0), (0, 0, 0, 1, 0, 0, 0), (0, 1, 0, 0, 0, 0, 0), (0, 0, 0, 0, 1, 0, 0),
       (0, 1, 0, 0, 0, 0, 0), (0, 0, 0, 0, 1, 0, 0), (0, 0, 1, 0, 0, 0, 0), (0, 0, 1, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0))),
    (nextLevelXp: (
       2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001, 250001, 375001, 750001, 1125001, 1500001, 1875001, -1,
       -1, -1);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0), (0, 1, 0, 0, 0, 0, 0), (1, 1, 0, 0, 0, 0, 0), (1, 0, 1, 0, 0, 0, 0),
       (0, 0, 1, 0, 0, 0, 0), (0, 1, 0, 1, 0, 0, 0), (0, 0, 1, 1, 0, 0, 0), (0, 0, 0, 0, 1, 0, 0),
       (0, 1, 0, 0, 1, 0, 0), (0, 0, 1, 1, 1, 0, 0), (0, 0, 0, 1, 1, 1, 0), (1, 1, 1, 0, 0, 1, 0),
       (0, 0, 0, 0, 0, 0, 1), (0, 0, 0, 1, 1, 0, 0), (0, 0, 0, 0, 0, 1, 1), (0, 0, 0, 0, 0, 0, 1),
       (0, 0, 0, 0, 0, 0, 0))),
    (nextLevelXp: (
       1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, 160001, 220001, 440001, 660001, 880001, 1100001, 1320001,
       1540001, 1760001);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0), (0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0)))
  );
  { per class: the dice of its starting money (count, sides); unused, CharGen rolls its own }
  startingMoneyDice: array[0..6, 0..1] of Byte = (
    (3, 6), (3, 6), (5, 4), (5, 4), (5, 4), (2, 4), (2, 6)
  );
  { per class, level and save: the saving-throw target }
  saveTbl: array[0..6, 1..18, 0..4] of Byte = (
    (
     (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10),
     (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9)),
    (
     (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10),
     (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9)),
    (
     (14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10), (5, 6, 7, 5, 8), (5, 6, 7, 5, 8), (4, 5, 6, 4, 7), (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6), (3, 4, 5, 4, 6)),
    (
     (12, 13, 14, 15, 15), (12, 13, 14, 15, 15), (11, 12, 13, 14, 14), (11, 12, 13, 14, 14), (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12), (8, 9, 10, 10, 11), (9, 9, 10, 10, 11), (6, 7, 8, 7, 9), (6, 7, 8, 7, 9), (5, 6, 7, 6, 8),
     (5, 6, 7, 6, 8), (3, 4, 5, 3, 6), (3, 4, 5, 3, 6), (2, 3, 4, 2, 5), (2, 3, 4, 2, 5), (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4)),
    (
     (14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10), (5, 6, 7, 5, 8), (5, 6, 7, 5, 8), (4, 5, 6, 4, 7), (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6), (3, 4, 5, 4, 6)),
    (
     (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6), (10, 7, 5, 9, 6)),
    (
     (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11), (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11), (11, 10, 10, 14, 11), (10, 9, 8, 13, 9), (10, 9, 8, 13, 9), (10, 9, 8, 13, 9),
     (10, 9, 8, 13, 9), (9, 8, 6, 12, 7), (9, 8, 6, 12, 7))
  );
  { per spell level: its spells, rows 1 to 6 the cleric's and rows 7 and 8 the druid's first two; Money picks random
    scroll spells from it }
  clericSpellsByLevel: array[1..8, 1..10] of Byte = (
    (1, 2, 3, 4, 5, 6, 7, 8, 0, 0),
    (22, 23, 24, 25, 26, 27, 28, 0, 0, 0),
    (37, 38, 39, 40, 46, 42, 43, 44, 0, 0),
    (58, 66, 67, 68, 69, 70, 0, 0, 0, 0),
    (71, 72, 73, 74, 75, 76, 0, 0, 0, 0),
    (36, 56, 0, 0, 0, 0, 0, 0, 0, 0),
    (77, 78, 79, 80, 0, 0, 0, 0, 0, 0),
    (90, 96, 98, 0, 0, 0, 0, 0, 0, 0)
  );
  { per spell level: the magic-user spells of that level, offered for learning and picked for random scrolls }
  spellsByLevel: array[1..7, 1..11] of Byte = (
      (9, 10, 13, 16, 17, 19, 20, 14, 15, 12, 0),
      (29, 30, 31, 32, 33, 34, 35, 0, 0, 0, 0),
      (45, 46, 48, 49, 50, 51, 52, 53, 54, 55, 47),
      (81, 82, 83, 84, 85, 86, 87, 88, 89, 100, 0),
      (91, 92, 93, 94, 0, 0, 0, 0, 0, 0, 0),
      (111, 112, 113, 114, 110, 0, 0, 0, 0, 0, 0),
      (115, 116, 117, 0, 0, 0, 0, 0, 0, 0, 0)
  );
  { the mouse cursor for EGA and Tandy: the screen mask, then the cursor mask }
  cursorMaskHi: array[0..1, 0..15] of Word = (
    ($3FFF, $1FFF, $0FFF, $87FF, $A3FF, $E1FF, $F0FF, $F847, $FC23, $FE0F, $FF07, $F807, $FC43, $FFE0, $FFF9, $FFFF),
    ($0000, $4000, $6000, $3000, $1800, $0C00, $0600, $0310, $0188, $00B0, $0030, $02F0, $0118, $000E, $0000, $0000)
  );
  { the mouse cursor for CGA: the screen mask, then the cursor mask }
  cursorMaskCga: array[0..1, 0..15] of Word = (
    ($0FFF, $03FF, $00FF, $003F, $000F, $0003, $0000, $0003, $0003, $3F03, $FF00, $FF00, $FFC3, $FFFF, $FFFF, $FFFF),
    ($0000, $3000, $3C00, $3F00, $3FC0, $3FF0, $3FFC, $3FC0, $3CF0, $00F0, $003C, $003C, $0000, $0000, $0000, $0000)
  );
  { joystick zone lookup }
  zoneMap: array[0..5, 0..5] of Byte = (
      (7, 7, 0, 0, 1, 1), (7, 8, 8, 8, 8, 1), (6, 8, 8, 8, 8, 2),
      (6, 8, 8, 8, 8, 2), (5, 8, 8, 8, 8, 3), (5, 5, 4, 4, 3, 3)
  );
  { per joystick zone: the key it stands for }
  joyKeyMap: array[0..9] of Byte = (
    Ord('8'), Ord('9'), Ord('6'), Ord('3'), Ord('2'), Ord('1'), Ord('4'), Ord('7'), Ord(' '), 0
  );

implementation

end.
