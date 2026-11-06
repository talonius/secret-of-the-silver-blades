{ The menu core: the horizontal menu frame (MenuHorizontal) and the vertical scrolling list menu (MenuVertical), with
  their nested helpers, plus the Yes/No prompt and the node-chain utilities. }
{$O+,F+,I-,R-,S-}
unit MenuCore;

interface

uses Types, TextRend, GameIo, Mouse, Border, Joystick, Portrait, CbtMap, GDConsts, GDVars, C_Keys, C_Ifc;

type
  TSpan = record start: Byte; stop: Byte; end;

{ Finds a member of a string list by position.
  @param(n The member's position, counting from 0.)
  @param(head The list's first member.)
  @returns(The member, or nil when the list is shorter.) }
function FindListMember(n: Word; head: Types.PItemRec): Types.PItemRec;

{ Counts the members of a string list.
  @param(head The list's first member, or nil.)
  @returns(The number of members.) }
function ListCount(head: Types.PItemRec): Word;

{ Shows s1p and a one-line menu on the bottom row and waits for a choice. Each option starts at a digit or capital
  letter, its hotkey, drawn in hlCol; the highlighted option (horizChoice, kept between calls) is drawn inverse. With
  several options the left and right arrows, or 4 and 6, move the highlight, wrapping; any other extended key is
  returned as its scan code. A hotkey picks its option; Space returns ' ' and Escape #0. Enter takes the highlighted
  option, unless it came from a mouse click: a click on the party list makes that member current (selOverrideWho while
  selOverride is set) and returns the up arrow, a click on the combat or exploration map returns the arrow toward it, a
  click on the bottom row picks the option under it, a click while modifying a character returns Home with the row in
  mouseMenuRow, and a click on a row of a vertical menu's list takes the highlighted option. While it waits the portrait
  animation plays when showAnim asks for it and frames are loaded; once autoDelay ticks pass with no new frame,
  defaultKey is returned. Afterwards pending keys are drained and it waits for the mouse or joystick buttons to be
  released; extKeyFlag mirrors outb.
  @param(s1p Text shown first, in qCol; empty for none.)
  @param(s2p The options.)
  @param(qCol Color of s1p.)
  @param(wordCol Color of the option text.)
  @param(hlCol Color of the hotkeys and the highlight; 0 for no highlight.)
  @param(remapEdgeKeys True to return the digits 1 to 9 as keypad scan codes, and the backslash as 7.)
  @param(showAnim True to play the portrait animation.)
  @param(outb Set when the result is a scan code.)
  @returns(The chosen option's hotkey, a space, #0 for Escape, defaultKey or a scan code.) }
function MenuHorizontal(s1p, s2p: Types.TStr40; qCol: Byte; wordCol, hlCol: Byte; remapEdgeKeys, showAnim: Byte;
                        var outb: Boolean): Char;

{ Blanks the bottom text row. }
procedure ClearBottomLine;

{ Runs a menu over a string list in a window. Members with isHeader set are labels, drawn in fgAlt and skipped by the
  highlight; the others are choices, drawn in fgNorm. A horizontal menu on the bottom row (MenuHorizontal, with the
  digits read as keypad keys) takes the command: header's options, then Next when a later page exists, Prev when the
  page top is past the leading labels, and Exit with showExit. The up and down arrows move the highlight, wrapping
  within the page; Page Up and Page Down turn pages when Prev and Next are offered, P and N whether or not they are; a
  mouse click on a row moves the highlight there, and a click on the highlighted row chooses it. With the mouse active a
  command key is taken only when it repeats the previous one. The page top (menuTop) is kept between calls; it is pulled
  back to cnt when it lies past it, and to 0 when it lies past the end of the list.
  @param(prompt Text shown before the command menu.)
  @param(header The command menu's own options.)
  @param(fgAlt Color of the prompt and the labels.)
  @param(fgNorm Color of the choices and the command menu.)
  @param(bgHi Color of the highlight and the hotkeys.)
  @param(ulCol Left column of the window.)
  @param(ulRow Top row of the window.)
  @param(lrCol Right column of the window.)
  @param(lrRow Bottom row of the window.)
  @param(head The list's first member; nil returns at once.)
  @param(showExit True to offer Exit.)
  @param(redrawList True to redraw the window first, which a page top pulled back also forces; cleared unless head is
    nil.)
  @param(cnt The highlighted member, counting from 0, kept between calls; set to 0 for an empty list.)
  @param(cur Receives the highlighted member when a command is chosen, or nil.)
  @returns(The command key, or #0 for Escape, Exit or an empty list.) }
function MenuVertical(prompt, header: Types.TStr40; fgAlt, fgNorm, bgHi: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      head: Types.PItemRec; showExit: Byte; var redrawList: Boolean; var cnt: Integer;
                      var cur: Types.PItemRec): Char;

{ Asks prompt with a Yes/No menu until Y or N is chosen; Escape does not leave it.
  @param(prompt The question.)
  @param(qCol Color of the question.)
  @param(wordCol Color of the options.)
  @param(hlCol Color of the hotkeys and the highlight.)
  @param(sel The option highlighted first: 1 for Yes, 2 for No.)
  @returns('Y' or 'N'.) }
function YesNoMenu(prompt: Types.TStr40; qCol, wordCol, hlCol, sel: Byte): Char;

{ Allocates a list of empty members, as many as asked; the first is allocated before the count is read, so a count below
  1 gives one member.
  @param(n Members wanted.)
  @param(head Receives the first member.) }
procedure AllocStringList(n: Integer; var head: Types.PItemRec);

{ Frees each member of a string list; the caller's pointer is not set to nil.
  @param(head The list's first member, or nil.) }
procedure FreeStringList(var head: Types.PItemRec);

implementation

function FindListMember(n: Word; head: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Word;
begin
  i := 0;
  p := head;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then FindListMember := p else FindListMember := nil;
end;

function ListCount(head: Types.PItemRec): Word;
var
  p: Types.PItemRec;
  n: Word;
begin
  n := 0;
  p := head;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function MenuHorizontal(s1p, s2p: Types.TStr40; qCol: Byte; wordCol, hlCol: Byte; remapEdgeKeys, showAnim: Byte;
                        var outb: Boolean): Char;
var
  ticks: LongInt;
  tick30: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  tick80: LongInt;
  key: Byte;
  { text column, mouseX div 8 }
  mcol: Integer;
  { text row, mouseY div 8 }
  mrow: Integer;
  idx: Byte;
  rosterRow: Byte;
  done: Byte;
  { Length(s2p) }
  menuLen: Byte;
  { Length(s1p), the start column }
  menuCol: Byte;
  words: array[0..20] of TSpan;
  pc: Types.PCharRecord;
  { the three GetMouse var targets in the epilogue }
  mb: Integer;
  mx: Integer;
  my: Integer;

  { Splits the menu text into options, each starting at a digit or capital letter, its hotkey. }
  procedure ParseMenu(src: Types.TStr40);
  var
    wordIdx: Byte;
    i: Byte;
    len: Byte;
    { Unused in this version; see the other implementations of this routine. }
    hotkey: Byte;
  begin
    GameIo.FillWord(words[1], SizeOf(words) - SizeOf(words[0]));
    wordIdx := 1;
    len := Length(src);
    for i := 1 to len do
      if src[i] in ['0'..'9', 'A'..'Z'] then
        if words[wordIdx].start = 0 then
          words[wordIdx].start := i
        else begin
          words[wordIdx].stop := i - 2;
          Inc(wordIdx);
          words[wordIdx].start := i;
        end;
    words[wordIdx].stop := len;
    words[0].stop := wordIdx;
  end;

  { Redraws the menu after s1p with option sel highlighted and the hotkeys in hlCol, and blanks the rest of the row. }
  procedure DisplayOption(sel: Byte);
  var
    i: Byte;
  begin
    Mouse.HideMouse;
    if menuLen > 0 then begin
      for i := 1 to menuLen do
        if (words[sel].start <= i) and (words[sel].stop >= i) and (hlCol <> 0) then
          TextRend.RenderChar(menuCol + i - 1, 24, 0, hlCol, 1, Ord(s2p[i]), 1)
        else if s2p[i] in ['0'..'9', 'A'..'Z'] then
          TextRend.RenderChar(menuCol + i - 1, 24, hlCol, 0, 1, Ord(s2p[i]), 1)
        else
          TextRend.RenderChar(menuCol + i - 1, 24, wordCol, 0, 1, Ord(s2p[i]), 1);
      if menuCol + menuLen < 39 then
        TextRend.RenderChar(menuCol + menuLen, 24, 0, 0, 39 - menuLen - menuCol + 1, 32, 1);
    end;
    Mouse.ShowMouse;
  end;

begin
  GDVars.extKeyFlag := False;
  words[0].start := Ord((wordCol <> 0) or (hlCol <> 0));
  menuCol := Length(s1p) + 0;
  ParseMenu(s2p);
  if (GDVars.horizChoice > words[0].stop) or (GDVars.horizChoice = 0) then GDVars.horizChoice := 1;
  menuLen := Length(s2p);
  key := 0;
  outb := False;
  done := 0;
  ticks := TextRend.GetTicks;
  tick30 := TextRend.GetTicks + 30;
  tick80 := tick30 + 50;
  if s1p <> '' then
    TextRend.DisplayString(0, 24, qCol, 0, s1p);
  DisplayOption(GDVars.horizChoice);
  if (showAnim <> 0) and (GDVars.animData.curFrame > 0) then begin
    Portrait.DisplayImageBuf(3, 3, Boolean(showAnim), GDVars.animData.frames[GDVars.animData.curFrame].pic);
    if GDVars.animData.count < 2 then showAnim := 0;
  end;
  repeat
    if (showAnim <> 0) and (GDVars.animData.curFrame > 0) then
      if TextRend.GetTicks - ticks >= GDVars.animData.frames[GDVars.animData.curFrame].delay * 10 then begin
        Inc(GDVars.animData.curFrame);
        if GDVars.animData.curFrame > GDVars.animData.count then GDVars.animData.curFrame := 1;
        Portrait.DisplayImageBuf(3, 3, Boolean(showAnim), GDVars.animData.frames[GDVars.animData.curFrame].pic);
        ticks := TextRend.GetTicks;
      end;
    if GDVars.autoDelay > 0 then
      if TextRend.GetTicks - ticks >= GDVars.autoDelay then begin
        key := GDVars.defaultKey;
        done := 1;
      end;
    if GameIo.InputPending then begin
      key := Ord(GameIo.ReadGameKey);
      if key = 0 then begin
        key := Ord(GameIo.ReadGameKey);
        outb := True;
        if words[0].stop > 1 then
          case key of
            Ord(C_Keys.LEFT): begin
                   if GDVars.horizChoice =
                       1 then GDVars.horizChoice := words[0].stop else Dec(GDVars.horizChoice);
                   DisplayOption(GDVars.horizChoice);
                 end;
            Ord(C_Keys.RIGHT): begin
                   if GDVars.horizChoice =
                       words[0].stop then GDVars.horizChoice := 1 else Inc(GDVars.horizChoice);
                   DisplayOption(GDVars.horizChoice);
                 end;
          else
            done := 1;
          end else
          done := 1;
      end else begin
        outb := False;
        case key of
          Ord(C_Keys.ESCAPE): begin
                 done := 1;
                 key := 0;
               end;
          { Enter, via a mouse click }
          Ord(C_Keys.ENTER): if GDVars.mouseClk then begin
                 mrow := GDVars.mouseY div 8;
                 mcol := GDVars.mouseX div 8;
                 if (GDVars.rosterMouseOn <> 0) and
                     not ((GDVars.interfaceState = C_Ifc.OVERLAND) and (GDVars.zone0^.areaView = 0)) and
                     (GDVars.moveMode = 0) and (GDVars.rosterPickMenu <> 0) and
                     (GDVars.interfaceState <> C_Ifc.IN_COMBAT) and (GDVars.rosterLeft <= mcol) and
                     (GDVars.rosterRight >= mcol) and (GDVars.rosterTop <= mrow) and
                     (GDVars.rosterBottom >= mrow) then begin
                   idx := mrow - GDVars.rosterTop;
                   pc := GDVars.creatureList;
                   for rosterRow := 1 to idx do
                     if pc <> nil then pc := pc^.nextCharAddr;
                   if pc <> nil then begin
                     key := Ord(C_Keys.UP);
                     outb := True;
                     done := 1;
                     if GDVars.selOverride <> 0 then begin
                       if GDVars.selOverrideWho = pc then begin
                         outb := False;
                         { the selected word's first letter is the accelerator }
                         key := Ord(s2p[words[GDVars.horizChoice].start]);
                         if key = 0 then key := Ord(C_Keys.ENTER);
                       end else
                         GDVars.selOverrideWho := pc;
                     end else if GDVars.curChar = pc then begin
                       outb := False;
                       key := Ord(s2p[words[GDVars.horizChoice].start]);
                       if key = 0 then key := Ord(C_Keys.ENTER);
                     end else begin
                       GDVars.redrawChar := GDVars.curChar;
                       GDVars.curChar := pc;
                     end;
                   end;
                 end else if ((GDVars.inMoveMenu <> 0) or (GDVars.aimActive <> 0)) and
                     (GDVars.interfaceState = C_Ifc.IN_COMBAT)
                    and (mcol >= 1) and (mcol <= 21)
                    and (mrow >= 1) and (mrow <= 21) then begin
                   outb := True;
                   if GDVars.aimActive <> 0 then begin
                     mx := GDVars.aimCursorX - GDVars.arenaPtr^.ox + 1;
                     my := GDVars.aimCursorY - GDVars.arenaPtr^.oy + 1;
                   end else begin
                     idx := CbtMap.CombatSlot(GDVars.curChar);
                     mx := GDVars.arenaLoc[idx].x - GDVars.arenaPtr^.ox + 1;
                     my := GDVars.arenaLoc[idx].y - GDVars.arenaPtr^.oy + 1;
                   end;
                   key := Mouse.MouseDirection(mx, my, mcol div 3 + 1, mrow div 3 + 1);
                   done := 1;
                 end else if (GDVars.moveMode <> 0) and
                   (((mcol >= 3) and (mcol <= 13) and (mrow >= 3) and (mrow <= 13)) or
                    ((GDVars.zone0^.view3dFlag = 0) and (GDVars.interfaceState = C_Ifc.OVERLAND) and
                     (mcol >= 1) and (mcol <= 38) and (mrow >= 1) and (mrow <= 15))) then begin
                   outb := True;
                   if GDVars.zone0^.view3dFlag = 0 then
                     key := Mouse.MouseDirection(GDVars.zone0^.markerCol + 1, GDVars.zone0^.markerRow + 1, mcol,
                                                 mrow)
                   else
                     key := GDConsts.dirTable[mrow, mcol];
                   done := 1;
                 end else if (mrow = 24) and (done = 0) then begin
                   Inc(mcol);
                   if menuCol < mcol then begin
                     mcol := mcol - menuCol;
                     { scans every word span }
                     for idx := 1 to words[0].stop do
                       if (words[idx].start <= mcol)
                          and (words[idx].stop >= mcol) then begin
                         key := Ord(s2p[words[idx].start]);
                         GDVars.horizChoice := idx;
                         DisplayOption(GDVars.horizChoice);
                         done := 1;
                       end;
                   end;
                 end else if (GDVars.modifyMenuActive <> 0) and (done = 0) then begin
                   done := 1;
                   case mrow of
                     1: if (mcol >= 1) and (mcol <= 16) then GDVars.mouseMenuRow := 6;
                     3: if (mcol >= 31) and (mcol <= 33) then GDVars.mouseMenuRow := 7;
                     9..14: if (mcol >= 5) and (mcol <= 9) then GDVars.mouseMenuRow := mrow - 9;
                   else
                     done := 0;
                   end;
                   outb := True;
                   key := Ord(C_Keys.HOME);
                 end else if done = 0 then begin
                   if (GDVars.clickColLo <= mcol) and (GDVars.clickColHi >= mcol) then begin
                     idx := 1;
                     while (idx <= 25) and (GDVars.hotRows[idx] <> 255)
                           and (done = 0) do begin
                       if GDVars.hotRows[idx] <= mrow then begin
                         done := 1;
                         key := Ord(s2p[words[GDVars.horizChoice].start]);
                       end;
                       Inc(idx);
                     end;
                   end;
                 end;
               end else begin
                 { no mouse click pending: Enter picks the SELECTED word, returning its accelerator letter (#13 when
                   that letter is #0). }
                 key := Ord(s2p[words[GDVars.horizChoice].start]);
                 if key = 0 then key := Ord(C_Keys.ENTER);
                 done := 1;
               end;
          { page left }
          Ord('4'): if words[0].stop > 1 then begin
                 if GDVars.horizChoice =
                     1 then GDVars.horizChoice := words[0].stop else Dec(GDVars.horizChoice);
                 DisplayOption(GDVars.horizChoice);
               end else begin
                 if remapEdgeKeys <> 0 then begin
                   key := GDConsts.keyRemap[key - Ord('1')];
                   outb := True;
                 end;
                 done := 1;
               end;
          { page right }
          Ord('6'): if words[0].stop > 1 then begin
                 if GDVars.horizChoice =
                     words[0].stop then GDVars.horizChoice := 1 else Inc(GDVars.horizChoice);
                 DisplayOption(GDVars.horizChoice);
               end else begin
                 done := 1;
                 if remapEdgeKeys <> 0 then begin
                   key := GDConsts.keyRemap[key - Ord('1')];
                   outb := True;
                 end;
               end;
        else
          { Accelerator typing. mcol and idx are reused here as the word index and the scan counter. }
          key := Ord(UpCase(Chr(key)));
          if Chr(key) in [' ', '0'..'9', 'A'..'Z'] then begin
            if key = Ord(' ') then
              done := 1
            else
              for idx := 1 to menuLen do
                if s2p[idx] = Chr(key) then begin
                  done := 1;
                  mcol := 1;
                  while idx <> words[mcol].start do Inc(mcol);
                  GDVars.horizChoice := mcol;
                  DisplayOption(GDVars.horizChoice);
                end;
          end;
          if remapEdgeKeys <> 0 then
            if Chr(key) in ['1'..'9', '\'] then begin
              if key = Ord('\') then key := Ord('7') else key := GDConsts.keyRemap[key - Ord('1')];
              outb := True;
              done := 1;
            end;
        end;
      end;
    end;
  until done <> 0;
  MenuHorizontal := Chr(key);
  GDVars.extKeyFlag := outb;
  GameIo.FlushKeys;
  { Wait for the input device to be released before returning, so the caller's next menu does not re-consume this click
    or deflection: the mouse if one is active, otherwise the joystick. mb serves as both the button count and the
    joystick direction. }
  if GDVars.mouseClk then
    repeat
      Mouse.GetMouse(mb, mx, my);
    until mb = 0
  else if GDVars.joyOn then
    repeat
      Joystick.GetJoystick(mb, idx);
    until mb = 0;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, 0, 40);
end;

function MenuVertical(prompt, header: Types.TStr40; fgAlt, fgNorm, bgHi: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      head: Types.PItemRec; showExit: Byte; var redrawList: Boolean; var cnt: Integer;
                      var cur: Types.PItemRec): Char;
var
  { lrCol - ulCol + 1 }
  width: Byte;
  { DrawPage's write index into the hot rows }
  slot: Byte;
  { ListCount(head) }
  total: Integer;
  { MenuHorizontal's `var outb` }
  ext: Boolean;
  { lrRow - ulRow + 1 }
  rows: Integer;
  key: Char;
  prevKey: Char;
  tail: Types.TStr40;
  { set only in the ' Next' block; read only by the PgDn arm }
  hasNext: Byte;
  { set only in the ' Prev' block; read only by the PgUp arm }
  hasPrev: Byte;
  node: Types.PItemRec;
  nFlag: Integer;
  nTotal: Integer;
  { mouseX div 8; compared against the click column bounds }
  mcol: Byte;
  { mouseY div 8; compared against 24 and the hot rows }
  mrow: Byte;

  { Returns the last label among the first limit members, else the first member if it is a label, else nil. }
  function LastLabelBefore(limit: Integer; head: Types.PItemRec): Types.PItemRec;
  var
    p: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    p := head;
    found := nil;
    while (p <> nil) and (i < limit) do begin
      if p^.isHeader <> 0 then found := p;
      p := p^.next;
      Inc(i);
    end;
    if (found = nil) and (head^.isHeader <> 0) then
      LastLabelBefore := head
    else
      LastLabelBefore := found;
  end;

  { Clears the window and draws one member per row from member top on, recording each row in hotRows. }
  procedure DrawPage(top: Word);
  var
    p: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    q: Types.PItemRec;
    row: ShortInt;
  begin
    FillChar(GDVars.hotRows[1], SizeOf(GDVars.hotRows), 255);
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    Mouse.HideMouse;
    p := MenuCore.FindListMember(top, head);
    q := LastLabelBefore(top, head);
    row := ulRow;
    slot := 1;
    while (p <> nil) and (row <= lrRow) do begin
      GDVars.hotRows[slot] := row;
      if p^.isHeader <> 0 then
        TextRend.DisplayString(ulCol, row, fgAlt, 0, p^.name)
      else
        TextRend.DisplayString(ulCol, row, fgNorm, 0, p^.name);
      if Length(p^.name) < width then
        TextRend.RenderChar(ulCol + Length(p^.name), row, 0, 0, width - Length(p^.name), 32, 1);
      p := p^.next;
      Inc(row);
      Inc(slot);
    end;
    Mouse.ShowMouse;
  end;

  { Returns the position of the first non-space character of s (its length when all spaces, 1 when empty). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do Inc(i);
    FirstNonBlank := i;
  end;

  { Returns the position of the last non-space character of s (1 when all spaces, 0 when empty). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
  begin
    i := Length(s);
    while (i > 1) and (s[i] = ' ') do Dec(i);
    LastNonBlank := i;
  end;

  { Redraws member n, trimmed of spaces, inverse in bgHi. }
  procedure HighlightLine(n: Integer);
  var
    p: Types.PItemRec;
    first: Byte;
    count: Byte;
  begin
    p := MenuCore.FindListMember(n, head);
    first := FirstNonBlank(p^.name);
    count := LastNonBlank(p^.name) - first + 1;
    TextRend.DisplayString(ulCol + first - 1, ulRow + (n - GDVars.menuTop), 0, bgHi, Copy(p^.name, first, count));
  end;

  { Redraws member n, trimmed of spaces, in its resting color (fgAlt for a label, fgNorm otherwise). }
  procedure UnhighlightLine(n: Integer);
  var
    p: Types.PItemRec;
    first: Byte;
    count: Byte;
  begin
    p := MenuCore.FindListMember(n, head);
    first := FirstNonBlank(p^.name);
    count := LastNonBlank(p^.name) - first + 1;
    if p^.isHeader <> 0 then
      TextRend.DisplayString(ulCol + first - 1, ulRow + (n - GDVars.menuTop), fgAlt, 0, Copy(p^.name, first, count))
    else
      TextRend.DisplayString(ulCol + first - 1, ulRow + (n - GDVars.menuTop), fgNorm, 0, Copy(p^.name, first, count));
  end;

  { Moves the highlight off labels, wrapping within the page, for at most a page of steps. }
  procedure SkipLabels(down: Byte);
  var
    steps: Integer;
  begin
    steps := 0;
    if down <> 0 then begin
      while (steps < rows) and (MenuCore.FindListMember(cnt, head)^.isHeader <> 0) do begin
        Inc(steps);
        Inc(cnt);
        if GDVars.menuTop + rows - 1 < cnt then cnt := GDVars.menuTop;
        if total - 1 < cnt then cnt := GDVars.menuTop;
      end;
    end else begin
      while (steps < rows) and (MenuCore.FindListMember(cnt, head)^.isHeader <> 0) do begin
        Inc(steps);
        Dec(cnt);
        if cnt < GDVars.menuTop then cnt := GDVars.menuTop + rows - 1;
        if total - 1 < cnt then cnt := total - 1;
      end;
    end;
  end;

  { Turns a page down or up, keeping the highlight on the same row, then moves it off labels and redraws the window. }
  procedure MovePage(down: Byte);
  var
    delta: Integer;
  begin
    delta := cnt - GDVars.menuTop;
    if down <> 0 then begin
      Inc(GDVars.menuTop, rows);
      if total - rows < GDVars.menuTop then GDVars.menuTop := total - rows;
    end else begin
      Dec(GDVars.menuTop, rows);
      if GDVars.menuTop < 0 then GDVars.menuTop := 0;
    end;
    cnt := GDVars.menuTop + delta;
    SkipLabels(down);
    DrawPage(GDVars.menuTop);
  end;

  { Moves the highlight one member down or up, wrapping within the page and the list, then off labels. }
  procedure MoveLine(down: Byte);
  var
    { Unused in this version; see the other implementations of this routine. }
    pp: Types.PItemRec;
    { Unused in this version; see the other implementations of this routine. }
    k: Integer;
    { Unused in this version; see the other implementations of this routine. }
    n: Integer;
  begin
    if down <> 0 then begin
      Inc(cnt);
      if GDVars.menuTop + rows - 1 < cnt then cnt := GDVars.menuTop;
      if total - 1 < cnt then cnt := GDVars.menuTop;
    end else begin
      Dec(cnt);
      if cnt < GDVars.menuTop then cnt := GDVars.menuTop + rows - 1;
      if total - 1 < cnt then cnt := total - 1;
    end;
    { Note: the two arms' second clamps differ (menuTop vs total - 1). }
    SkipLabels(down);
  end;

begin
  if head = nil then begin
    cnt := 0;
    cur := nil;
    { an inverted, empty bounds pair, so no click column can fall inside it }
    GDVars.clickColLo := 127;
    GDVars.clickColHi := -128;
    MenuVertical := C_Keys.NONE;
    Exit;
  end;
  prevKey := 'N';
  GDVars.clickColLo := ulCol;
  GDVars.clickColHi := lrCol;
  width := lrCol - ulCol + 1;
  total := MenuCore.ListCount(head);
  rows := lrRow - ulRow + 1;
  node := head;
  nFlag := 0;
  { count the leading run of FLAGGED (unselectable) nodes }
  while (node <> nil) and (node^.isHeader <> 0) do begin
    node := node^.next;
    Inc(nFlag);
  end;
  { and the chain length again, walked inline }
  node := head;
  nTotal := 0;
  while node <> nil do begin
    node := node^.next;
    Inc(nTotal);
  end;
  if nTotal <= rows then GDVars.menuTop := 0;
  if GDVars.menuTop > cnt then begin
    GDVars.menuTop := cnt;
    redrawList := True;
  end;
  if GDVars.menuTop > nTotal then begin
    GDVars.menuTop := 0;
    redrawList := True;
  end;
  Inc(cnt);
  MoveLine(0);
  if redrawList then DrawPage(GDVars.menuTop);
  redrawList := False;
  repeat
    HighlightLine(cnt);
    { the header plus whichever of Next/Prev/Exit are currently legal }
    tail := header;
    hasNext := 0;
    hasPrev := 0;
    if total - rows > GDVars.menuTop then begin
      tail := tail + ' Next';
      hasNext := 1;
    end;
    if GDVars.menuTop > nFlag then begin
      tail := tail + ' Prev';
      hasPrev := 1;
    end;
    { Exit is offered only with showExit set, but Escape and E leave in any case }
    if showExit <> 0 then tail := tail + ' Exit';
    key := MenuCore.MenuHorizontal(prompt, tail, fgAlt, fgNorm, bgHi, 1, 0, ext);
    UnhighlightLine(cnt);
    mrow := GDVars.mouseY div 8;
    mcol := GDVars.mouseX div 8;
    if ext then
      { no else arm }
      case key of
        C_Keys.UP: MoveLine(0);
        C_Keys.DOWN: MoveLine(1);
        C_Keys.PAGE_UP: if hasPrev <> 0 then MovePage(0);
        C_Keys.PAGE_DOWN: if hasNext <> 0 then MovePage(1);
      end else
      case key of
        { Note: the second `mouseClk` term is redundant. }
        'P': if not GDVars.mouseClk or (GDVars.mouseClk and (mrow = 24)) then MovePage(0);
        'N': if not GDVars.mouseClk or (GDVars.mouseClk and (mrow = 24)) then MovePage(1);
        C_Keys.ESCAPE, 'E', C_Keys.NONE: begin
          cur := nil;
          MenuVertical := C_Keys.NONE;
          GDVars.clickColLo := 127;
          GDVars.clickColHi := -128;
          Exit;
        end;
      else
        if GDVars.mouseClk and (mrow <> 24) then begin
          if (mcol >= GDVars.clickColLo) and (mcol <= GDVars.clickColHi) then begin
            { `slot` is reused here as the click-scan index }
            slot := 1;
            while (slot <= 25) and (GDVars.hotRows[slot] <> 255) do begin
              if GDVars.hotRows[slot] = mrow then
                if slot - 1 + GDVars.menuTop = cnt then begin
                  cur := MenuCore.FindListMember(cnt, head);
                  MenuVertical := key;
                  Exit;
                end else begin
                  UnhighlightLine(cnt);
                  cnt := slot - 1 + GDVars.menuTop;
                  HighlightLine(cnt);
                end;
              Inc(slot);
            end;
          end;
        end else if not GDVars.mouseClk or (GDVars.mouseClk and (prevKey = key)) then begin
          cur := MenuCore.FindListMember(cnt, head);
          MenuVertical := key;
          GDVars.clickColLo := 127;
          GDVars.clickColHi := -128;
          Exit;
        end;
      end;
    prevKey := key;
  until False;
end;

function YesNoMenu(prompt: Types.TStr40; qCol, wordCol, hlCol, sel: Byte): Char;
var
  { MenuHorizontal's `var outb` }
  ext: Boolean;
  { MenuHorizontal's Char result }
  key: Char;
begin
  GDVars.horizChoice := sel;
  repeat
    key := MenuCore.MenuHorizontal(prompt, 'Yes No', qCol, wordCol, hlCol, 0, 0, ext);
  until key in ['Y', 'N'];
  YesNoMenu := key;
end;

procedure AllocStringList(n: Integer; var head: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(head, SizeOf(Types.TItemNode));
  head^.next := nil;
  head^.isHeader := 0;
  head^.name := '';
  p := head;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TItemNode));
    p := p^.next;
    p^.next := nil;
    p^.isHeader := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var head: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := head;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TItemNode));
  end;
end;

begin
end.
