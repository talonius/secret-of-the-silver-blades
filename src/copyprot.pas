{ Journal copy-protection challenge. CopyProtection picks a random journal entry, prompts "what is word # W of journal
  entry # E (journal, page P)?", reads the player's answer, up to 3 tries, and returns whether it matched. Its nested
  function Decode unscrambles the expected answer from the journal tables. }
{$O+,F+,I-}
unit CopyProt;

interface

uses Border, GameIo, CharHlp, TextRend, Crt, GDConsts, GDVars;

{ Runs the documentation check: asks for word N of journal entry M on page P of the journal, giving three tries to type
  it, with a new question each try. The answer is decoded from GDConsts.wordChars through the entry's record in
  GDConsts.jrec. Each stage sets one of the protectFlags, which are cleared on entry.
  @returns(True when the last answer typed was right.) }
function CopyProtection: Boolean;

implementation

function CopyProtection: Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  charIndex: Byte;
  entry: Byte;
  attempts: Byte;
  { Unused in this version; see the other implementations of this routine. }
  passed: Byte;
  answer: String;
  wordNum: Byte;
  entryNum: Byte;
  pageNum: Byte;
  reply: String;

  { Decodes a journal answer word; each stored letter is a signed delta from 55 plus the word length. }
  function Decode(entry: Word): String;
  var
    wordLen: Byte;
    i: Byte;
    startCol: Byte;
    ch: Byte;
    acc: String;
  begin
    acc := '';
    wordLen := GDConsts.jrec[entry].wordLen;
    startCol := GDConsts.jrec[entry].startCol;
    for i := 1 to wordLen do begin
      ch := ShortInt(GDConsts.wordChars[startCol + i]) + 55 + wordLen;
      acc := acc + Chr(ch);
    end;
    Decode := acc;
  end;

begin
  GameIo.FillWord(GDVars.protectFlags, SizeOf(GDVars.protectFlags));
  Border.DrawWindowFrame(1);
  attempts := 0;
  repeat
    Inc(attempts);
    answer := '';
    GDVars.protectFlags[1] := 1;
    TextRend.DisplayString(3, 2, LightGreen, 0, ' what is word # ');
    entry := Random(30) + 1;
    wordNum := GDConsts.jrec[entry].wordNum;
    entryNum := GDConsts.jrec[entry].entryNum;
    pageNum := GDConsts.jrec[entry].pageNum;
    answer := Decode(entry);
    GDVars.protectFlags[2] := 1;
    TextRend.DisplayString(19, 2, LightGreen, 0, CharHlp.Uint8Str(wordNum) + '    ');
    TextRend.DisplayString(3, 4, LightGreen, 0, ' of journal entry # ' + CharHlp.Uint8Str(entryNum) + '     ');
    TextRend.DisplayString(3, 6, LightGreen, 0, ' (journal, page ' + CharHlp.Uint8Str(pageNum) + ')?      ');
    reply := TextRend.ReadString('Enter ', Yellow, 0, 20);
  until (attempts = 3) or (reply = answer);
  GDVars.protectFlags[3] := 1;
  if reply = answer then
    CopyProtection := True
  else
    CopyProtection := False;
  GDVars.protectFlags[4] := 1;
end;

begin
end.
