{ Resident text output, disk prompting, and DAX archive loading.

  BIOS text primitives support the framed retry prompts. The loader opens the archive pair, locates a record, streams
  its run-length data from disk, and brackets disk activity with sound cues. Volume-label and file helpers handle floppy
  and installed-game paths, including the MON archive prompt. }
{$O+,F+}
{$R-,S-,V-,I-,B-}
unit DaxIo;

interface

uses Dos, GameIo, SoundDrv, Crt, GDConsts, GDVars, Types;

type
  TString2 = string[2];
  TString20 = string[20];
  TString80 = string[80];

{ Writes a run of one character in text mode through the video BIOS on page 0, placing the cursor first. On CGA the
  attribute is translated through the CGA attribute table.
  @param(col Text column.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(count How many copies to write.)
  @param(ch The character.) }
procedure WriteChar(col, row, attr, count, ch: Byte);

{ Writes a string in text mode through the video BIOS, one character per column.
  @param(col Text column of the first character.)
  @param(row Text row.)
  @param(attr Text attribute.)
  @param(source The text.) }
procedure WriteString(col, row, attr: Byte; source: string);

{ Writes a run of solid block characters through the BIOS.
  @param(col Column of the first block.)
  @param(row Row of the run.)
  @param(attr Text attribute.)
  @param(count Number of blocks.) }
procedure WriteBlock(col, row, attr, count: Byte);

{ Shows a message on the bottom text row over a cleared bar, waits for a key, then clears the bar.
  @param(attr Attribute of the message.)
  @param(message The message.) }
procedure PromptBox(attr: Byte; message: Types.TStr40);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: TString80);

{ Waits until GAME.OVR can be found, asking for the overlay disk and a key each time it is missing. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: TString2): Types.TStr40;

{ Opens a file for reading in records of one byte. A path without a directory looks in the data path; when the file is
  not there the data path and master path are swapped and it looks again. While the file is missing and prompts are
  allowed, it asks for the disk (a floppy drive) or reports the missing file (a hard disk) and tries again.
  @param(fileName The file's name, with or without a directory.)
  @param(promptMsg The disk prompt shown for a floppy drive, followed by the drive letter.)
  @param(noPrompt #0 to keep asking until the file is found; anything else fails at once.)
  @param(f Receives the open file.)
  @returns(True when the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: TString80; noPrompt: Char; var f: file): Boolean;

{ Tells whether a normal file matching a name exists.
  @param(name The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(name: TString80): Boolean;

{ Removes the occurrences of one string from another. Note: the scan limit is computed once from the starting lengths
  and the scan moves on after each deletion, so a match shifted into the current position survives, and a substring
  longer than the string wraps the limit round to a large byte value.
  @param(src The string.)
  @param(del The text to remove.)
  @returns(The string without the text.) }
function SanitizeString(src, del: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): TString80;

{ Decodes a run-length packed entry. A control byte 0..$7E copies the next control+1 bytes; -127..-1 repeats the next
  byte -control times. Note: controls $7F and $80 do nothing, so a stream holding one makes no progress, and `total` is
  checked only between runs, so bad data can overrun the buffer by one run.
  @param(dst The buffer that receives the decoded bytes.)
  @param(total The number of bytes to decode.)
  @param(f The archive, positioned at the entry.) }
procedure DecompressDax(var dst: Types.PByteArr; var total: Word; var f: file);

{ Opens an archive twice, one handle for its entry directory from the start and one positioned at the first data byte.
  Note: if the second open fails, the first handle is left open.
  @param(dirName The archive's base name.)
  @param(ext Its extension.)
  @param(headerSize Receives the offset of the first data byte.)
  @param(dataFile Receives the handle positioned at the data.)
  @param(indexFile Receives the handle that reads the directory.)
  @returns(True when both opens succeeded.) }
function OpenDax(dirName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(indexFile The directory handle.) }
procedure CloseDax(var dataFile, indexFile: file);

{ Loads and decodes one block of a DAX archive into a new buffer. The directory is searched for the block's ID; each
  entry gives the block's offset and its decoded and compressed sizes. Sound output is silenced during the load. A
  missing archive or block gives a size of 0 and nil.
  @param(fileName The archive's name.)
  @param(ext The archive's extension.)
  @param(fileId The block's ID.)
  @param(sizeRead Receives the decoded size, 0 on failure.)
  @param(data Receives the buffer, nil on failure.) }
procedure LoadDax(fileName, ext: TString80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);

{ Remembers the current disk and switches to the disk that holds a given part of the game, two parts to a disk.
  @param(v The part, 1 up.) }
procedure PushState(v: Byte);

{ Returns to the disk PushState remembered. }
procedure PopState;

implementation

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  GDVars.regs.ah := 2;
  GDVars.regs.bh := 0;
  GDVars.regs.dh := row;
  GDVars.regs.dl := col;
  Intr($10, Registers(GDVars.regs));
  GDVars.regs.ah := 9;
  GDVars.regs.al := ch;
  GDVars.regs.bh := 0;
  if GDVars.displayMode = Types.Cga then
    GDVars.regs.bl := GDConsts.colorTab[attr]
  else
    GDVars.regs.bl := attr;
  GDVars.regs.cx := count;
  Intr($10, Registers(GDVars.regs));
end;

procedure WriteString(col, row, attr: Byte; source: string);
var
  n: Byte;
  i: Byte;
begin
  n := Length(source);
  for i := 1 to n do begin
    DaxIo.WriteChar(col, row, attr, 1, Ord(source[i]));
    Inc(col);
  end;
end;

procedure WriteBlock(col, row, attr, count: Byte);
begin
  DaxIo.WriteChar(col, row, attr, count, 219);
end;

procedure PromptBox(attr: Byte; message: Types.TStr40);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  DaxIo.WriteBlock(0, 24, 0, 40);
  DaxIo.WriteString(0, 24, attr, message);
  key := GameIo.ReadGameKey;
  DaxIo.WriteBlock(0, 24, 0, 40);
end;

procedure DeleteIfPresent(name: TString80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.delFile, name);
    Close(GDVars.delFile);
    Erase(GDVars.delFile);
  end;
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      WriteLn('Please insert overlay disk.');
      key := GameIo.ReadGameKey;
    end;
  until found;
end;

function GetVolumeLabel(drive: TString2): Types.TStr40;
var sr: SearchRec;
begin
  FillChar(sr.Name, SizeOf(sr.Name), 0);
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name;
end;

function OpenWithRetry(fileName, promptMsg: TString80; noPrompt: Char; var f: file): Boolean;
var found: Boolean;
    tmp: string[79];
    dir: string[67];
    nm: string[8];
    ext: string[4];
begin
  FSplit(fileName, dir, nm, ext);
  if dir = '' then
    dir := GDVars.gDataPath;
  repeat
    found := DaxIo.FileExists(dir + nm + ext);
    if not found then
      if dir = GDVars.gDataPath then begin
        tmp := GDVars.gDataPath;
        GDVars.gDataPath := GDVars.gAltPath;
        GDVars.gAltPath := tmp;
        dir := GDVars.gDataPath;
        found := DaxIo.FileExists(dir + nm + ext);
      end;
    if not found then
      if noPrompt = #0 then begin
        if dir[1] < 'C' then begin
          if (nm[1] = 'M') and (nm[2] = 'O') and (nm[3] = 'N')
             and (ext = '.DAX') then
            DaxIo.PromptBox(Yellow, GDConsts.diskPath[2] + GDVars.gPromptDrive + ':')
          else
            DaxIo.PromptBox(Yellow, promptMsg + GDVars.gPromptDrive + ':');
        end else
          DaxIo.PromptBox(Yellow, 'Couldn''t find ' + nm + ext + '. Check install.');
      end;
  until found or (noPrompt <> #0);
  if found then begin
    Assign(f, dir + nm + ext);
    Reset(f, 1);
  end;
  OpenWithRetry := found;
end;

function FileExists(name: TString80): Boolean;
var sr: SearchRec;
begin
  FindFirst(name, 0, sr);
  FileExists := (DosError = 0) and (name <> '');
end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then
      Delete(src, i, delLen);
  SanitizeString := src;
end;

function SanitizeFileName(name: string): TString80;
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileChars[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do
    name[i] := UpCase(name[i]);
  SanitizeFileName := name;
end;

procedure DecompressDax(var dst: Types.PByteArr; var total: Word; var f: file);
var
  { Unused in this version; see the other implementations of this routine. }
  inputIndex: Word;
    dstIdx: Word;
    b: ShortInt;
    fill: Byte;
    { Unused in this version; see the other implementations of this routine. }
    inputBuffer: array[0..511] of Byte;
begin
  inputIndex := 0;
  dstIdx := 0;
  repeat
    BlockRead(f, b, SizeOf(b));
    case b of
      0..$7E: begin
        BlockRead(f, dst^[dstIdx], b + 1);
        Inc(dstIdx, b + 1);
      end;
      -127..-1: begin
        b := -b;
        BlockRead(f, fill, SizeOf(fill));
        FillChar(dst^[dstIdx], b, fill);
        Inc(dstIdx, b);
      end;
    end;
  until dstIdx >= total;
end;

function OpenDax(dirName, ext: TString20; var headerSize: Word; var dataFile, indexFile: file): Boolean;
var nread: Word;
    { Unused in this version; see the other implementations of this routine. }
    ioStatus: Word;
begin
  if DaxIo.OpenWithRetry(dirName + ext, GDConsts.diskPath[GDVars.diskNum], GDVars.suppressInsertPrompt,
                         dataFile) then begin
    if not DaxIo.OpenWithRetry(dirName + ext, GDConsts.diskPath[GDVars.diskNum], GDVars.suppressInsertPrompt,
                               indexFile) then begin
      OpenDax := False;
      Exit;
    end;
    BlockRead(indexFile, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, 2);
    Seek(dataFile, headerSize);
    OpenDax := True;
  end else
    OpenDax := False;
end;

procedure CloseDax(var dataFile, indexFile: file);
begin
  Close(dataFile);
  Close(indexFile);
end;

procedure LoadDax(fileName, ext: TString80; fileId: Byte; var sizeRead: Word; var data: Types.PByteArr);
var compSize: Word;
    offset: LongInt;
    id: Byte;
    n: Word;
    dataFile: file;
    indexFile: file;
    headerSize: Word;
    { Unused in this version; see the other implementations of this routine. }
    soundState: Byte;
    { Unused in this version; see the other implementations of this routine. }
    numStr: String[6];
begin
  SoundDrv.SoundCommand(GDConsts.sfxOff);
  if not DaxIo.OpenDax(fileName, ext, headerSize, dataFile, indexFile) then begin
    sizeRead := 0;
    data := nil;
    SoundDrv.SoundCommand(GDConsts.sfxOn);
    Exit;
  end;
  repeat
    BlockRead(indexFile, id, SizeOf(id), n);
    BlockRead(indexFile, offset, SizeOf(offset), n);
    BlockRead(indexFile, sizeRead, SizeOf(sizeRead), n);
    BlockRead(indexFile, compSize, SizeOf(compSize), n);
  until (id = fileId) or (FilePos(indexFile) >= headerSize);
  if id <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, indexFile);
    SoundDrv.SoundCommand(GDConsts.sfxOn);
  end else begin
    GetMem(data, sizeRead);
    Seek(dataFile, headerSize + offset);
    DaxIo.DecompressDax(data, sizeRead, dataFile);
    DaxIo.CloseDax(dataFile, indexFile);
    SoundDrv.SoundCommand(GDConsts.sfxOn);
  end;
end;

procedure PushState(v: Byte);
begin
  GDVars.savedDiskNum := GDVars.diskNum;
  GDVars.diskNum := (v + 1) div 2;
end;

procedure PopState;
begin
  GDVars.diskNum := GDVars.savedDiskNum;
end;

begin
end.
