{ Shared character, item, effect, and combat records. }
{$A-}
unit Types;

interface

type

  TLevelNN = 0..127;

  { the six packed icon-color nibble pairs }
  TStatPack = array[1..6] of Byte;

  TStatCell = record
    { the unmodified value }
    base: Byte;
    { the current value, which clamps read }
    cur: Byte;
  end;

  PCharRecord = ^TCharRecord;
  PItemRec = ^TItemRec;
  PEffectRec = ^TEffectRec;
  PCombatRec = ^TCombatRec;

  PCombat = ^TCombat;
  PSpell = ^TSpell;
  TStr40 = string[40];
  TCombat = record
    itemUseAllowedLead: array[$00..$01] of Byte;
    itemUseAllowed: Byte;
    itemUseAllowedTail: array[$03..$16] of Byte;
  end;
  TSpell = record
    id: Byte;
    tmr: Word;
    tmrTail: array[1..2] of Byte;
    next: PSpell;
  end;

  TCharRecord = record
    case Integer of
      0: (
            name: string[15];
            stats: array[0..5] of TStatCell;
            strExc: Byte;
            strExcMax: Byte;
            memorizedSpells: array[0..74] of Byte;
            prepBase: ShortInt;
            { 60 - THAC0: the best baseToHitTbl entry of its classes }
            baseToHit: Byte;
            { index into raceNames }
            race: ShortInt;
            charClass: ShortInt;
            { a paladin's Cure Disease uses left; effect 110 refills it }
            cureDiseaseLeft: Byte;
            age: Word;
            hpMax: Byte;
            { one flag per spell id, 1..117 }
            known: array[1..117] of Byte;
            attackLevel: Byte;
            iconDimensions: Byte;
            { saving throws, by save type }
            saves: array[0..4] of Byte;
            movementBase: Byte;
            highestLevel: ShortInt;
            dualClassThreshold: ShortInt;
            drainedLevels: Byte;
            drainedHps: Byte;
            thiefSkills: array[0..8] of Byte;
            effectsAddr: PEffectRec;
            npc: Byte;
            modified: Byte;
            { the class a dual-classed character left }
            formerClass: Byte;
            formerClassTail: Byte;
            coinsA: array[0..6] of Word;
            classLevelA: array[0..6] of TLevelNN;
            classLevelB: array[0..6] of TLevelNN;
            gender: ShortInt;
            { index into alignNames }
            alignment: ShortInt;
            attacks: Byte;
            movementAttacks: Byte;
            unarmedRollsA: array[1..2] of Byte;
            unarmedDiceA: array[1..2] of Byte;
            unarmedModA: array[1..2] of ShortInt;
            { 60 - AC before armor and Dex; chargen sets 50, AC 10 }
            acBase: Byte;
            useStrength: Byte;
            combatIconId: Byte;
            experience: LongInt;
            classMask: Byte;
            hpRolled: Byte;
            { [spell class, spell level] }
            spellSlots: array[0..3, 1..7] of Byte;
            xpAward: Word;
            pcHpRolled: Byte;
            pcHpRolledTail: array[$151..$152] of Byte;
            portraitHead: Byte;
            portraitBody: Byte;
            { icon-anim slot; maptiles' animIdx }
            orderNumber: Byte;
            raceSize: Byte;
            statPack: TStatPack;
            { bit flags }
            creatureTypeFlags: Byte;
            { bit flags }
            targetFlags: Byte;
            targetFlagsTail: Byte;
            numberOfItems: Byte;
            itemsAddr: PItemRec;
            equipped: array[0..12] of PItemRec;
            handsEquipped: Byte;
            saveBonus: ShortInt;
            encumbrance: Word;
            nextCharAddr: PCharRecord;
            combatAddr: PCombatRec;
            magicResistance: Byte;
            { index into statusNames }
            status: ShortInt;
            enabled: Byte;
            hostile: ShortInt;
            quickfight: Byte;
            { 60 - THAC0, adjusted: fxengine's attackRoll adds it to the d20 }
            toHitCur: Byte;
            { 60 - AC; [1] against a backstab, cbtacts' bsFlag }
            acCurArr: array[0..1] of Byte;
            { cbtacts indexes it by attack phase }
            curAtt: array[1..2] of Byte;
            curRollsA: array[1..2] of Byte;
            curDiceA: array[1..2] of Byte;
            curModA: array[1..2] of ShortInt;
            hpCurrent: Byte;
            movementCur: Byte);

      1: (
            chaCurLead: array[$000..$01A] of Byte;
            chaCur: Byte;
            charClassV1Lead: array[$01C..$06B] of Byte;
            charClassV1: ShortInt;
            hpMaxV1Lead: array[$06D..$06F] of Byte;
            hpMaxV1: Byte;
            xpLead: array[$071..$12B] of Byte;
            xp: LongInt;
            hostileV1Lead: array[$130..$1A7] of Byte;
            hostileV1: Byte;
            hostileV1Tail: array[$1A9..$1B6] of Byte);

      2: (
            intCurV1Lead: array[$000..$012] of Byte;
            intCurV1: Byte;
            conCurLead: array[$014..$018] of Byte;
            conCur: Byte;
            petrificationSaveLead: array[$01A..$0E8] of Byte;
            petrificationSave: Byte;
            clericLevelLead: array[$0EA..$110] of Byte;
            clericLevel: ShortInt;
            clericLevelTail: array[$112..$112] of Byte;
            fighterLevel: ShortInt;
            paladinLevel: ShortInt;
            rangerLevel: ShortInt;
            mageLevel: ShortInt;
            thiefLevel: ShortInt;
            clericOldLevel: ShortInt;
            clericOldLevelTail: array[$119..$119] of Byte;
            fighterOldLevel: ShortInt;
            paladinOldLevel: ShortInt;
            rangerOldLevel: ShortInt;
            mageOldLevel: ShortInt;
            thiefOldLevel: ShortInt;
            genderV1: ShortInt;
            genderV1Tail: array[$120..$1B6] of Byte);

      4: (
            intCurLead: array[$000..$012] of Byte;
            intCur: Byte;
            spellBookLead: array[$014..$01D] of Byte;
            spellBook: array[0..74] of Byte;
            charClassV2Lead: array[$069..$06B] of Byte;
            charClassV2: Byte;
            movementRateLead: array[$06D..$0ED] of Byte;
            movementRate: ShortInt;
            classMaskV1Lead: array[$0EF..$12F] of Byte;
            classMaskV1: Byte;
            quickfightV1Lead: array[$131..$1A8] of Byte;
            quickfightV1: Byte;
            hpCurLead: array[$1AA..$1B4] of Byte;
            hpCur: Byte;
            hpCurTail: array[$1B6..$1B6] of Byte);

      8: (
            spellsMemLead: array[$000..$01D] of Byte;
            spellsMem: array[0..74] of Byte;
            classBitsLead: array[$069..$12F] of Byte;
            classBits: Byte;
            numItemsLead: array[$131..$15F] of Byte;
            numItems: Byte;
            equippedV1Lead: array[$161..$164] of Byte;
            equippedV1: array[0..8] of PItemRec;
            slot9AddrLead: array[$189..$18C] of Byte;
            slot9Addr: PItemRec;
            arrowsAddr: PItemRec;
            quarrelsAddr: PItemRec;
            handsUsed: Byte;
            combatAddrV1Lead: array[$19A..$1A0] of Byte;
            combatAddrV1: PCombat;
            dmgDiceLead: array[$1A5..$1AE] of Byte;
            dmgDice: ShortInt;
            dmgSidesLead: array[$1B0..$1B0] of Byte;
            dmgSides: ShortInt;
            dmgBonusLead: array[$1B2..$1B2] of Byte;
            dmgBonus: ShortInt;
            dmgBonusTail: array[$1B4..$1B6] of Byte);

      11: (
            attrsLead: array[$000..$00F] of Byte;
            attrs: array[0..5] of record base: Byte; cur: Byte end;
            strExcCurLead: array[$01C..$01C] of Byte;
            strExcCur: Byte;
            dualClassThresholdV1Lead: array[$01E..$0EE] of Byte;
            dualClassThresholdV1: Byte;
            firstThiefSkillLead: array[$0F0..$0F1] of Byte;
            firstThiefSkill: Byte;
            classLevelsV1Lead: array[$0F3..$110] of Byte;
            classLevelsV1: array[0..6] of ShortInt;
            oldClassLevelsV1: array[0..6] of ShortInt;
            oldClassLevelsV1Tail: array[$11F..$1B6] of Byte);

      12: (
            dexCurLead: array[$000..$016] of Byte;
            dexCur: Byte;
            attackLevelV1Lead: array[$018..$0E5] of Byte;
            attackLevelV1: Byte;
            clericLevelV1Lead: array[$0E7..$110] of Byte;
            clericLevelV1: Byte;
            clericLevelV1Tail: array[$112..$112] of Byte;
            fighterLevelV1: Byte;
            paladinLevelV1: Byte;
            rangerLevelV1: Byte;
            mageLevelV1: Byte;
            mageLevelV1Tail: array[$117..$117] of Byte;
            clericOldLevelV1: Byte;
            clericOldLevelV1Tail: array[$119..$119] of Byte;
            fighterOldLevelV1: Byte;
            paladinOldLevelV1: Byte;
            rangerOldLevelV1: Byte;
            mageOldLevelV1: Byte;
            mageOldLevelV1Tail: array[$11E..$1B6] of Byte);
  end;

  { The list-node prefix of TItemRec: name, isHeader and the chain link. A node that only threads a menu or name list is
    allocated this much and never the item payload. }
  TItemNode = record
    name: string[40];
    isHeader: Byte;
    next: PItemRec;
  end;

  TItemRec = record
    case Integer of
      0: (
            name: string[40];
            isHeader: Byte;
            next: PItemRec;
            { 'I' (73) marks a container }
            itemType: Byte;
            firstNameId: Byte;
            secondNameId: Byte;
            thirdNameId: Byte;
            plus: ShortInt;
            saveBonus: ShortInt;
            equipped: Byte;
            unidMask: Byte;
            cursed: Byte;
            weight: Word;
            { a container's sub-item count }
            count: Byte;
            value: Word;
            spells: array[1..3] of Byte;
            bundleNext: PItemRec);

      1: (
            itemIdLead: array[$000..$02D] of Byte;
            itemId: Byte;
            bundleNextV2Lead: array[$02F..$03E] of Byte;
            bundleNextV2: PItemRec);

      2: (
            nameBytes: array[$00..$29] of Byte;
            itemTypeV1Lead: array[$02A..$02D] of Byte;
            itemTypeV1: Byte;
            secondNameIdV1Lead: array[$02F..$02F] of Byte;
            secondNameIdV1: Byte;
            plusV1Lead: array[$031..$031] of Byte;
            plusV1: ShortInt;
            itemEffectLead: array[$033..$03C] of Byte;
            itemEffect: Byte;
            itemSpecial: Byte;
            itemSpecialTail: array[$03F..$042] of Byte);

      3: (
            quantityLead: array[$000..$038] of Byte;
            quantity: Byte;
            specialLead: array[$03A..$03C] of Byte;
            special: Byte;
            specialTail: array[$03E..$042] of Byte);

      4: (
            itemTypeV2Lead: array[$000..$02D] of Byte;
            itemTypeV2: Char;
            countV1Lead: array[$02F..$038] of Byte;
            countV1: Byte;
            bundleNextV1Lead: array[$03A..$03E] of Byte;
            bundleNextV1: PItemRec);

      5: (
            nameV1: string[41];
            kindLead: array[$02A..$02D] of Byte;
            kind: Char;
            plusV2Lead: array[$02F..$031] of Byte;
            plusV2: Byte;
            saveBonusV1: Byte;
            readied: Byte;
            idFlags: Byte;
            bundleQuantityLead: array[$036..$036] of Byte;
            bundleQuantity: Word;
            bundleWeightLead: array[$039..$039] of Byte;
            bundleWeight: Word;
            scribe0: Byte;
            scribe1: Byte;
            scribe2: Byte;
            scribe2Tail: array[$03F..$042] of Byte);

      6: (
            nameV2: TStr40;
            curseFlagLead: array[$029..$033] of Byte;
            curseFlag: Byte;
            scribeLead: array[$035..$03B] of Byte;
            scribe: array[1..3] of Byte;
            scribeTail: array[$03F..$042] of Byte);

      7: (
            nameIdsLead: array[$000..$02E] of Byte;
            nameIds: array[1..3] of Byte;
            nameIdsTail: array[$032..$042] of Byte);

      8: (
            attrSelLead: array[$000..$03C] of Byte;
            attrSel: Byte;
            attrVal: Byte;
            attrValTail: array[$03F..$042] of Byte);

      9: (
            enchantChainLead: array[$000..$03E] of Byte;
            enchantChain: PItemRec);

      10: (
            equippedV1Lead: array[$000..$033] of Byte;
            equippedV1: Byte;
            cursedV1Lead: array[$035..$035] of Byte;
            cursedV1: Byte;
            cursedV1Tail: array[$037..$042] of Byte);
  end;

  TEffectRec = record
    case Integer of
      0: (
            id: Byte;
            minutes: Word;
            strength: Byte;
            onRemove: Byte;
            next: PEffectRec);
  end;

  TCombatRec = record
    case Integer of
      0: (
            spellCast: Byte;
            spellsAllowed: Byte;
            itemUseAllowed: Byte;
            initiative: ShortInt;
            attackPhase: Byte;
            attackLevel: Byte;
            movement: Byte;
            guarding: Byte;
            madeAttack: Byte;
            direction: Byte;
            other: PCharRecord;
            damageTaken: Byte;
            flankCount: Byte;
            forcedFlee: Byte;
            usedTurnUndead: Byte;
            flankSpread: Byte;
            notPcNpc: Byte;
            fleeing: Byte;
            approach: Byte;
            hasSpells: Byte);

      1: (
            spellCastV1: Byte;
            initiativeV2Lead: array[$001..$002] of Byte;
            initiativeV2: Byte;
            movementV1Lead: array[$004..$005] of Byte;
            movementV1: Byte;
            guardingV1: Byte;
            guardingV1Tail: array[$008..$016] of Byte);

      2: (
            inPlayLead: array[$000..$012] of Byte;
            inPlay: Byte;
            inPlayTail: array[$014..$016] of Byte);

      3: (
            castAllowedLead: array[$000..$000] of Byte;
            castAllowed: Byte;
            flankCountV1Lead: array[$002..$00E] of Byte;
            flankCountV1: Byte;
            flankSpreadV1Lead: array[$010..$011] of Byte;
            flankSpreadV1: Byte;
            flankSpreadV1Tail: array[$013..$016] of Byte);

      4: (
            otherV1Lead: array[$000..$009] of Byte;
            otherV1: Pointer;
            otherV1Tail: array[$00E..$016] of Byte);

      5: (
            spellsLost: Byte;
            itemUseAllowedV1Lead: array[$001..$001] of Byte;
            itemUseAllowedV1: Byte;
            guardFlagLead: array[$003..$006] of Byte;
            guardFlag: Byte;
            forcedFleeV2Lead: array[$008..$00F] of Byte;
            forcedFleeV2: Byte;
            forcedFleeV2Tail: array[$011..$016] of Byte);

      6: (
            otherV2Lead: array[$000..$009] of Byte;
            otherV2: Pointer;
            forcedFleeV1Lead: array[$00E..$00F] of Byte;
            forcedFleeV1: Byte;
            forcedFleeV1Tail: array[$011..$016] of Byte);

      7: (
            slot: Byte;
            slotTail: array[$001..$016] of Byte);

      8: (
            initiativeV1Lead: array[$000..$002] of Byte;
            initiativeV1: Byte;
            notPcNpcV1Lead: array[$004..$012] of Byte;
            notPcNpcV1: Byte;
            notPcNpcV1Tail: array[$014..$016] of Byte);
  end;

  TStr8 = string[8];
  PStr = ^String;
  { The base-item table record, indexed by an item's itemType and read whole from ITEMS. wpnClassTail and propsTail are
    read by no unit. }
  TBaseItem = record
    { equipped[] slot: 0 weapon, 1 shield, 2 body armor }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice count }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged attacks per round, doubled }
    rateOfFire: Byte;
    { AC adjustment; bit 7 set = it applies }
    acDescr: Byte;
    { melee damage type; bit 7 marks a bashing weapon }
    wpnClass: Byte;
    { unused }
    wpnClassTail: Byte;
    { damage vs small/medium: dice count }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { range; a reach is range - 1 }
    range: Byte;
    { class usability bits, ANDed with the character's class mask }
    classMask: Byte;
    { 1 arrows, 2 dex missile, 4 str bonus, 8 fires ammo, $10 thrown, $80 quarrels }
    props: Byte;
    { unused }
    propsTail: Byte;
  end;
  TTarget = record
    { index into creatures[] }
    who: Byte;
    { range to the target, doubled }
    dist2: Byte;
    { facing toward it, from pathing's isDirToward }
    dir: Byte;
  end;
  TVideoMode = (Cga, Ega, Tandy);
  TRestClock = array[0..6] of Word;
  { One slot of the three-slot wall-set cache: the WALLDEF file id loaded there and its symbol set, both -1 when the
    slot holds no set. }
  TWallSetSlot = record
    defId: Integer;
    symSet: Integer;
  end;
  { Where the party stands and what it faces. GameInit clears the five fields together and SaveLoad saves and loads them
    as one block. }
  TPartyPosition = record
    { the party's column on the 16 by 16 map; GameInit starts the party at column 7 }
    mapX: ShortInt;
    { the party's row on the map; GameInit starts the party at row 13 }
    mapY: ShortInt;
    { the direction the party faces, in steps of 2: 0 north (mapY - 1), 2 east (mapX + 1), 4 south, 6 west, matching
      dirNames' N/E/S/W entries }
    facing: Byte;
    { the wall type ahead of the party }
    wallAhead: Byte;
    { the map event at the party's cell }
    eventAtCell: Byte;
  end;
  { A combatant lying on the battle map: who, the cell it fell on, and the arena cell its corpse covers. }
  TDownedRec = record
    cr: PCharRecord;
    x: ShortInt;
    y: ShortInt;
    { the arena cell saved under it }
    terrain: Byte;
  end;
  { One terrain type of the battle map. }
  TTerrainRec = record
    { the move cost, x3 on a diagonal step and x2 orthogonal; 255 is impassable }
    cost: Byte;
    { the line-of-sight height }
    clearance: Byte;
    { how much it blocks line of sight }
    blocking: Byte;
    { the tile id CbtMap draws; CombatSt tests 22 }
    id: Byte;
  end;
  { one cell offset of a combat icon's footprint }
  TIconDelta = record
    dx: ShortInt;
    dy: ShortInt;
  end;
  { a starting age: the base age plus a dice roll }
  TStartAge = record
    base: Word;
    { number of dice }
    dice: Byte;
    { faces per die }
    sides: Byte;
  end;
  { a race's stat limits; the strength limits are per gender }
  TRaceLimits = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    strExcMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;
  { one class's level table: the experience each level needs, -1 past the last, and the spell slots gained there }
  TClassProgression = record
    nextLevelXp: array[2..18] of LongInt;
    { [level, spell level] }
    spellSlots: array[2..18, 1..7] of Byte;
  end;
  TArenaLoc = record
    { cell coordinates }
    x: ShortInt;
    y: ShortInt;
    { aux / icon size (0 = out of play) }
    aux: Byte;
    size: Byte;
  end;
  { One Word per GBVM address in zone 2, one Byte per address in zone 3; declared at the GBVM base so a full GBVM
    address subscripts them directly. }
  TZone2 = array[$7A00..$7BFF] of Word; PZone2 = ^TZone2;
  TZone3 = array[$8000..$9DFF] of Byte; PZone3 = ^TZone3;
  TEffectHandler = procedure(var cr: PCharRecord; p: Pointer; removed: Boolean);
  { A spell's casting routine, one per spell id. }
  TSpellFn = procedure;
  { The target picker a cast runs: it picks the targets for the spell and sets cast once the caster confirms them; ai is
    set when the AI casts. }
  TCastTargetMenu = procedure(spell: Byte; ai: Boolean; var cast: Boolean);

  { The GBVM zone-0 bank, the 2048 bytes zone0 points at: one Word per GBVM address $4B00..$4EFF, so address A sits at
    +2*(A - $4B00). EclVm and eclmenu index it by address through cell; the cells other units read by field are named in
    the second arm. }
  PZone0 = ^TZone0;
  TZone0 = record
    case Integer of
      0: (cell: array[$4B00..$4EFF] of Word);
      1: (markerColLead: array[$000..$185] of Byte;
          markerCol: Integer;
          markerRow: Integer;
          { load3DMap stamps it, loadGame reloads it }
          mapId: Word;
          { the world clock: [$4BC7] minutes within the turn, [$4BC8] turns, [$4BC9] the hour }
          clock: array[$4BC6..$4BCC] of Word;
          antimagicLead: array[$19A..$1C9] of Byte;
          { nonzero: no spell casting, no item Use }
          antimagic: Word;
          { nonzero while a 3D map is loaded }
          view3dFlag: Word;
          prevEclLead: array[$1CE..$1E3] of Byte;
          { EclVm keeps the current ECL id here across a call }
          prevEcl: Word;
          noAutomapLead: array[$1E6..$1F5] of Byte;
          noAutomap: Word;
          { gameDelay, saved and loaded }
          savedGameDelay: Word;
          skyIndex: Word;
          eventSkyIndex: Word;
          { picsOn * 2 + animOn, saved and loaded }
          savedPicsAnim: Word;
          areaViewLead: array[$200..$26F] of Byte;
          { nonzero: the roster may draw }
          areaView: Word;
          saveCountLead: array[$272..$277] of Byte;
          { camp's save counter }
          saveCount: Word;
          difficultyLead: array[$27A..$3E7] of Byte;
          { 0..4, Novice..Champion }
          difficulty: Word;
          { zero: postcbt awards experience }
          noXpAward: Word;
          combatCleanedUpLead: array[$3EC..$3EF] of Byte;
          { set to 1 by postcbt's cleanup }
          combatCleanedUp: Word;
          statusXLead: array[$3F2..$3F9] of Byte;
          { when 255, the status line prints partyPos.mapX/mapY; else its low byte is the X printed }
          statusX: Word;
          { the Y printed when w3fa is not 255 }
          statusY: Byte;
          statusYTail: Byte;
          { added to facing to index dirNames, doubled in the 3D view }
          facingOffset: Word;
          facingOffsetTail: array[$400..$7FF] of Byte);
  end;

  { The GBVM zone-1 bank, the 2048 bytes zone1 points at: one Word per GBVM address $7C00..$7FFF, so address A sits at
    +2*(A - $7C00). EclMenu and EclVm index it by address through cell; the cells other units read by field are named in
    the second arm, and the third reads three of them by their low byte. }
  PZone1 = ^TZone1;
  TZone1 = record
    case Integer of
      0: (cell: array[$7C00..$7FFF] of Word);
      1: (trainMaskLead: array[$000..$54F] of Byte;
          { the classes the training hall here trains, one bit each }
          trainMask: Word;
          monsterDistLead: array[$552..$581] of Byte;
          { the monster side's offset from the party when combatants are placed }
          monsterDist: Word;
          moraleThresholdLead: array[$584..$58B] of Byte;
          { CombatSt seeds monster morale from it }
          moraleThreshold: Word;
          { the fight's outcome: 0, 1, $80 or $81 }
          combatResult: Word;
          { the monsters downed in the fight }
          monstersDefeated: Word;
          { at 255 the next indoor move is skipped and the cell reset to 0 }
          moveLocked: Word;
          { bit 0 searching (Explore's Search), bit 1 looking }
          searchFlags: Word;
          { the surprise mask for the current combat, bit 0 party, bit 1 monsters; BeginRound charges the -6 initiative
            penalty against it }
          surprise: Word;
          restSafeTimeLead: array[$598..$5A3] of Byte;
          { rest ticks between interruption checks; 0 for a safe rest }
          restSafeTime: Word;
          { the percent chance a check interrupts the rest }
          restInterruptPct: Word;
          leaveMapLead: array[$5A8..$5A9] of Byte;
          { set when a step leaves the 16x16 map }
          leaveMap: Word;
          noCombatItemsLead: array[$5AC..$5C5] of Byte;
          { 1 when the fight leaves no items behind }
          noCombatItems: Word;
          mirrorDuelLead: array[$5C8..$5CB] of Byte;
          { set for a duel with a mirror image }
          mirrorDuel: Word;
          diskNumLead: array[$5CE..$623] of Byte;
          { the game disk, saved and loaded with the game }
          diskNum: Word;
          allyAttackedLead: array[$626..$665] of Byte;
          { set by CheckAttackAlly, cleared per combat }
          allyAttacked: Word;
          partySizeLead: array[$668..$67B] of Byte;
          { the party members; creatures past it are not party }
          partySize: Word;
          priceModeLead: array[$67E..$6D9] of Byte;
          { the shop's price scale: 1/2/4/8 divide prices by 16/8/4/2, $20/$40/$80 multiply them by 2/4/8 }
          priceMode: Integer;
          modMonThac0Lead: array[$6DC..$6DF] of Byte;
          { the monsters' THAC0 modifier }
          modMonThac0: Word;
          { the party's THAC0 modifier }
          modPartyThac0: Word;
          { added to the party's movement }
          partyMoveBonus: Word;
          partyMoveBonusTail: array[$6E6..$7FF] of Byte);
      2: (trainMaskLoLead: array[$000..$54F] of Byte;
          trainMaskLo: Byte;
          modMonThac0LoLead: array[$551..$6DF] of Byte;
          { the THAC0 modifiers are signed bytes to FxEngine }
          modMonThac0Lo: ShortInt;
          modMonThac0LoTail: Byte;
          modPartyThac0Lo: ShortInt;
          modPartyThac0LoTail: array[$6E3..$7FF] of Byte);
  end;

  { One record of spellDefs. }
  TSpellDef = record
    castClass: ShortInt;
    level: ShortInt;
    rangeBase: Byte;
    rangePerLevel: Byte;
    durationBase: Byte;
    durationPerLevel: Byte;
    { area of effect, packed; the target menu selects on the low nibble }
    area: Byte;
    noncombatTarget: Byte;
    saveEffect: Byte;
    saveType: Byte;
    effectId: Byte;
    { camp/combat availability }
    castContext: Byte;
    { initiative cost, scaled by div 3 }
    castTime: Byte;
    aiPriority: Byte;
    { 0 = self/beneficial target }
    offensive: Byte;
    { friendly-fire scan radius }
    aiRadius: Byte;
  end;

type
  TColorTab = array[0..15] of Byte;
  { free-list block header }
  TFreeBlk = array[0..7] of Byte;
  PFreeBlk = ^TFreeBlk;
  { The spell-list scratch block: the source item for each entry of spellIdx, over the same index range. }
  PSpellScratch = ^TSpellScratch;
  TSpellScratch = array[0..1000] of PItemRec;
  TSndProc = function(cmd, firstArg, secondArg: Word): Word;
  { The overlay manager's read routine, laid out as Overlay.OvrReadFunc so storage can hold one without using Overlay. }
  TOvrReadFunc = function(ovrSeg: Word): Integer;
  { A copy-protection question: which word of the rule book to ask for, and where its answer lies in wordChars2. }
  TRuleRec = record
    wordNum: Byte;
    page: Byte;
    { the heading the word follows, an index into headTbl }
    headingIdx: Byte;
    answerLen: Byte;
    answerOfs: Byte;
  end;
  { A journal copy-protection question: which word of which journal entry to ask for, and where its answer lies in
    wordChars. }
  TJRec = record
    wordNum: Byte;
    entryNum: Byte;
    pageNum: Byte;
    wordLen: Byte;
    startCol: Byte;
  end;
  { The characters a word-wrapped line may break after. }
  TBrkSet = set of ' '..'?';
  { A rule-book heading: where its letters lie in wordChars1. }
  THeadRec = record
    textLen: Byte;
    textOfs: Byte;
  end;
  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;
  TColorMap = array[0..7] of Byte;
  PBytes = ^TBytes;
  TBytes = array[0..65000] of Byte;
  PImgBuf = ^TImgBuf;
  TImgBuf = record
    height: Word;
    { width in characters (x8 for pixels) }
    width: Word;
    { horizontal placement; show3DSprite adds 3 - 1 }
    originX: Word;
    { vertical placement; show3DSprite adds 3 - 1 }
    originY: Word;
    count: Byte;
    map: TColorMap;
    imgSize: Word;
    transp: PBytes;
    data: array[0..32000] of Byte;
  end;
  TByteArr = array[0..65534] of ShortInt;
  PByteArr = ^TByteArr;
  { The combat arena. }
  TArena = record
    oxLead: array[1..2] of Byte;
    { view upper-left arena coords }
    ox: ShortInt;
    oy: ShortInt;
    { draw the cursor sprite }
    cursorOn: Boolean;
    { cursor icon size }
    cursorSize: Byte;
    { <> 0: walkLine ignores terrain blocking, and acquireTarget's relaxed pass takes a pick without asking CanTarget }
    distMode: Byte;
    { terrain-info indices, row-major }
    cells: array[0..24, 0..49] of Byte;
  end;
  PArena = ^TArena;
  { GOSUB return-stack node: EclGosub New()s it and EclVm's EclExit and EclReturn release it with FreeMem. }
  PEclRet = ^TEclRet;
  TEclRet = record
    addr: Word;
    next: PEclRet;
  end;
  { A node on the three cloud lists headed at blastHead, stinkHead and cloudkillHead. Magic builds them, EffHndlr and
    Combat free them, and FindCreatureAtCell walks them. }
  PCloudNode = ^TCloudNode;
  TCloudNode = record
    owner: PCharRecord;
    next: PCloudNode;
    { arena cell under each cloud cell }
    saved: array[1..9] of Byte;
    { cell in play }
    live: array[1..9] of Byte;
    x: ShortInt;
    y: ShortInt;
    { matched against the removal effect's strength div $10 }
    cnt: Byte;
    { set once the occupant has saved }
    spent: Byte;
  end;
  TMoney = array[0..6] of LongInt;
  { Line-walk state. stepX and stepY are words; err is an inline error accumulator and dist a doubled distance
    counter. }
  TPathReq = record
    { start / end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { inline error accumulator }
    err: Integer;
    { Abs(ex - sx) }
    adx: Integer;
    { Abs(ey - sy) }
    ady: Integer;
    { current x }
    cx: Integer;
    { current y }
    cy: Integer;
    { x step sign (word) }
    stepX: Integer;
    { y step sign (word) }
    stepY: Integer;
    { doubled distance walked }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;
  { one animation frame: how long it shows, and its image }
  TAnimFrame = record
    delay: LongInt;
    pic: PImgBuf;
  end;
  { an animation record: up to eight frames }
  TAnimRec = record
    { the frames loaded }
    count: Byte;
    { the frame on show, 1..count; 0 while none is }
    curFrame: Byte;
    frames: array[1..8] of TAnimFrame;
  end;
  { A portrait slot, head or body: the picture id loaded there (255 for none) and the picture. }
  TPortSlot = record
    fileId: Byte;
    pic: PImgBuf;
  end;
  { [y][x] }
  TGeoPlane = array[0..15, 0..15] of Byte;
  TGeoMap = record
    { N high nibble / E low }
    wallsNE: TGeoPlane;
    { S high nibble / W low }
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    { 2 bits per facing }
    barriers: TGeoPlane;
  end;
  PGeoMap = ^TGeoMap;
  { one WALLDEF bank: five slices of 156 cells }
  TWallDef = array[1..5, 0..155] of Byte;
  { The wall graphics of the three wall-set slots, read per bank or per slice. }
  PWallDefs = ^TWallDefs;
  TWallDefs = record
    case Integer of
      0: (banks: array[1..3] of TWallDef);
      1: (slices: array[1..15, 0..155] of Byte);
  end;
  { The 3D view's slot geometry: per wall slot, where its 156-cell slice starts, its size in columns and rows, and the
    column and row it is drawn at. }
  TWallSliceTable = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  { the sprite-shown / picture-shown pair DisplayMonster takes by reference }
  TMonFlags = array[0..1] of Boolean;
  { One joystick axis's calibration: the low reading, the five zone thresholds and the high reading; BLADES.CFG holds
    them as seven words. }
  TJoyAxis = record
    case Integer of
      0: (lo: Word;
          thr: array[1..5] of Word;
          hi: Word);
      1: (words: array[0..6] of Word);
  end;
  { one joystick's calibration }
  TJoyCal = record
    x: TJoyAxis;
    y: TJoyAxis;
  end;
  { the 8x8 game font: glyph[char][row] }
  TFontArr = array[0..255] of array[0..7] of Byte;
  PFontArr = ^TFontArr;

implementation

end.
