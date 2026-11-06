; sounddrv.asm -- the music driver, linked into the SoundDrv unit with
; {$L SOUNDDRV.OBJ}.  It keeps its data in the code segment: every routine that
; can be entered from outside loads DS with CODE.
;
; It plays on the PC speaker or on the Tandy 1000's SN76489, from INT 8.
; InstallSoundTimer speeds the timer up to BIOS_EVERY times the BIOS rate and passes
; every BIOS_EVERY-th tick on to the old handler.  Each tick steps two banks
; of voices, one per device; ProgramSpeakerVoices starts a song on the speaker bank and
; ProgramTandyVoices one on the Tandy bank, and SetVoiceByte mutes or unmutes both.
;
; A song gives each of four voices a stream of bytes.  A byte below FIRST_CMD
; begins a three-byte note event (the `note' and `last' macros): the voice it
; is for, times 20h; the pitch in semitones, REST for none, with bit 7 set on
; the event that ends the step; and the step's length in ticks, which goes to
; the voice the commands are addressing.  Only events for voice 0 of the bank
; take a pitch -- for the others the driver keeps the length alone.  The
; commands:
;
;   0FAh                 clear the voice's fields from vPeriod to vWaveLen,
;                        all but vTempo and vSustain
;   0FBh                 return from 0FCh
;   0FCh target          call; one level deep, through streamReturn
;   0FDh voice           go on with another voice of the bank, cleared the
;                        same way
;   0FEh counter target  count the field down and jump while it is not zero;
;                        a counter already at zero always jumps
;   0FFh field value     store a word in a field of the voice.  Storing to
;                        vTicks ends the step; the stream ends if its own
;                        voice is then left at zero.

        LOCALS

BIOS_EVERY      =       13              ; driver ticks to a BIOS tick
TIMER_COUNT     =       10000h / BIOS_EVERY
VOICES          =       4               ; voices a bank plays
FIRST_CMD       =       0FAh            ; stream bytes from here up are commands
REST            =       7Fh             ; the pitch of a silent note
RELEASE         =       4               ; envelope entry a sustain ends at

Voice   STRUC
vTicks          dw      ?               ; left in the current step
vStream         dw      ?               ; next stream byte, 0 when done
vPeriod         dw      ?               ; divider of the note
vSlide          dw      ?               ;   added to it every tick
vOutput         dw      ?               ; vPeriod with vibrato: what is played
vLevel          dw      ?               ; volume
vLevelSlide     dw      ?               ;   added to it every tick
vTempo          dw      ?               ; above 1, multiplies event lengths
vSpare          dw      ?               ; set by the music, read by nothing
vTranspose      dw      ?               ; semitones added to every pitch
vSustain        dw      ?               ; ticks to the release
vEnvelope       dw      ?               ; the envelope table
vEnvStep        dw      ?               ;   byte offset of its current entry
vEnvTicks       dw      ?               ;   ticks left on that entry
vWave           dw      ?               ; the vibrato wave
vPhase          dw      ?               ;   position in it, 12.4 fixed point
vRate           dw      ?               ;   added to vPhase every tick
vDepth          dw      ?               ;   scale of a sample
vWaveLen        dw      ?               ;   vPhase wraps here
vCount1         dw      ?               ; loop counters for 0FEh
vCount2         dw      ?
                dw      3 dup (?)
Voice   ENDS

EnvStep STRUC                           ; an envelope entry
esValue         dw      ?               ; a level, or a slide
esTicks         dw      ?               ; -1 for a level, else the slide's length
EnvStep ENDS

; Text with bit 7 set on every character.
hibit   MACRO   text
        IRPC    c, <text>
        db      '&c' OR 80h
        ENDM
        ENDM

; The stream language, as described above.
note    MACRO   who, pitch, ticks
        db      (who) SHL 5, pitch, ticks
        ENDM

last    MACRO   who, pitch, ticks       ; the event that ends the step
        db      (who) SHL 5, (pitch) OR 80h, ticks
        ENDM

vset    MACRO   field, value
        db      0FFh, field
        dw      value
        ENDM

envelope MACRO  target
        db      0FFh, vEnvelope
        dw      offset target
        ENDM

wave    MACRO   target
        db      0FFh, vWave
        dw      offset target
        ENDM

vloop   MACRO   counter, target
        db      0FEh, counter
        dw      offset target
        ENDM

vcall   MACRO   target
        db      0FCh
        dw      offset target
        ENDM

vret    MACRO
        db      0FBh
        ENDM

vselect MACRO   which
        db      0FDh
        dw      (which) * SIZE Voice
        ENDM

; Envelope entries.
envSet  MACRO   level                   ; set the level
        dw      level, -1
        ENDM

envRamp MACRO   slide, ticks            ; slide the level for so many ticks
        dw      slide, ticks
        ENDM

envHold MACRO                           ; stay put
        dw      0, 0
        ENDM

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE, DS:CODE
        PUBLIC  TimeoutCtr, InstallSoundTimer, UninstallSoundTimer
        PUBLIC  ProgramTandyVoices, ProgramSpeakerVoices, SetVoiceByte

; ---------------------------------------------------------------------------
; Driver state

tickCount       db      BIOS_EVERY              ; counts down to the BIOS tick
inTick          db      0                       ; the sequencer is busy: keep the ISR out
voicesLeft      db      0                       ; voice loop counter
voiceSize       db      SIZE Voice              ; for playEvent's mul
TimeoutCtr   dw      0                       ; ticks to the error exit, 0 = off

; What the driver prints when TimeoutCtr runs out.  It is kept with bit 7
; set on every byte and unmasked in place just before it is written.
errorText       label   byte
        hibit   <Run-time  Error 209 at 0BAD:0038>
        db      0Ah OR 80h
errorLen        =       $ - errorText
        db      0Dh OR 80h                      ; past errorLen: never shown

; These five cells, the voice banks and oldInt8 need no initial value; they
; hold whatever the build left in the space, scraps of other code and text.
currentSong     dw      0000h                   ; the song playing, 0 = none
streamVoice     dw      0000h                   ; the voice whose stream is being read
bankVoices      dw      0000h                   ; the bank being ticked: its voices
bankDividers    dw      0000h                   ;   and its semitone table
streamReturn    dw      0000h                   ; where 0FBh returns to
voiceSong       db      VOICES dup (0)          ; each voice's song; not read by the driver
outputOn        db      1                       ; 0 mutes both devices
; Not read by the driver.
        db      0, 0, 0, 2, 0, 3, 4, 0, 6, 8, 0, 12, 16, 0, 24, 32, 0, 48, 64

; The stream commands, 0FAh to 0FFh
cmdTable        dw      offset cmdClear, offset cmdReturn, offset cmdCall
                dw      offset cmdSelect, offset cmdLoop, offset cmdSet

; ---------------------------------------------------------------------------
; The two banks.  Each holds eight voices, of which the tick runs the first
; four, and a table of the twelve semitones of its lowest octave; a note an
; octave up halves the divider.

speakerVoices   label   byte                    ; 8 Voice records
        db      80 dup (0)
        db      30h,4Ch,00h,00h,00h,07h,00h,00h,30h,48h,00h,00h,00h,0Fh,00h,00h
        db      30h,50h,00h,00h,00h,14h,00h,06h,30h,28h,00h,00h,00h,0Ah,00h,06h
        db      30h,2Ch,00h,00h,00h,07h,00h,11h,50h,18h,00h,00h,00h,2Bh,00h,1Ah
        db      30h,60h,00h,00h,00h,30h,00h,23h,90h,20h,00h,00h,00h,43h,00h,11h
        db      00h,1Ch,00h,00h,00h,4Dh,00h,11h,00h,18h,00h,00h,00h,54h,00h,23h
        db      90h,20h,00h,00h,00h,5Fh,00h,11h,00h,20h,00h,00h,00h,6Ah,00h,23h
        db      90h,20h,00h,00h,00h,75h,00h,11h,00h,1Ch,00h,00h,00h,7Fh,00h,11h
        db      00h,18h,00h,00h,00h,86h,00h,11h,00h,14h,00h,00h,00h,8Ah,00h,23h
        db      90h,20h,00h,02h,00h,8Eh,00h,11h,90h,00h,00h,00h,00h,9Ah,00h,23h
        db      90h,20h,00h,00h,00h,0A5h,00h,23h,90h,20h,00h,00h,00h,0ACh,00h,11h
        db      00h,1Ch,00h,00h,00h,0B8h,00h,11h,00h,18h,00h,00h,00h,0C3h,00h,23h
        db      90h,20h,00h,00h,00h,07h,00h,23h,90h,20h,00h,01h,00h,0Ah,00h,23h
        db      90h,20h,00h,02h,00h,0Eh,00h,23h,90h,20h,00h,00h,00h,13h,00h,11h
        db      00h,10h,00h,00h,00h,1Ch,00h,11h,00h,18h,00h,00h,00h,23h,00h,11h
        db      00h,1Ch,00h,00h,00h,2Ah,00h,11h,10h,28h,00h,00h,00h,04h,00h,11h
        db      20h,28h,00h,00h,00h,07h,00h,11h,90h,00h,00h,00h,00h,0Ah,00h,11h
        db      90h,00h,00h,02h,00h,0Eh,00h,11h,90h,00h,00h,00h,00h,12h
        db      34 dup (0)

; Timer counts, 1193182 Hz / frequency, from C at 32.7 Hz.
speakerDividers dw      36484, 34436, 32503, 30679, 29007, 27332
                dw      25798, 24350, 22983, 21693, 20476, 19326
speakerVoice    dw      0                       ; the voice the speaker plays

tandyVoices     label   byte                    ; 8 Voice records
        db      183 dup (0)
        db      04h,0B8h,0Eh,11h,10h,28h,00h,00h,00h,04h,0BAh,0Eh,11h,20h,28h,00h
        db      00h,00h,02h,00h,02h,00h,04h,0A3h,0Eh,11h,90h,00h,00h,00h,00h,06h
        db      89h,16h,0Eh,11h,90h,00h,00h,02h,00h,02h,12h,79h,00h,00h,15h,00h
        db      02h,06h,0C4h,3Eh,0Eh,11h,90h,00h,00h,00h,00h,02h,00h,33h,00h,06h
        db      31h,0C0h,04h,26h,06h,89h,05h,02h,12h,7Ah,00h,00h,3Eh,00h,02h,00h
        db      2Ch,00h,00h,4Ah,00h,12h,7Bh,00h,02h,04h,55h,06h,89h,0E5h,02h,06h
        db      89h,0ECh,04h,5Dh,04h,0CBh,02h,00h,5Bh,00h,00h,51h,00h,00h,61h,00h
        db      12h,7Ch,00h,14h,06h,31h,0C0h,04h,50h,02h,00h,76h,00h,04h,0Eh,04h
        db      0E8h,0Eh,11h,00h,18h,00h,00h,00h,02h,12h,73h,00h,00h,7Ch,00h,02h
        db      06h,31h,0C0h,04h,50h,02h,00h,92h,00h,04h,0Eh,04h,0E8h,0Eh,11h,00h
        db      1Ch,00h,00h,00h,02h,12h,74h,00h,00h,98h,00h,02h,00h,15h,00h,00h
        db      29h,00h,00h,5Ch,00h,00h,6Fh,00h,00h,8Bh,00h,00h,0A7h,00h,12h,75h
        db      00h,02h,04h,55h,06h,89h,0E5h,06h,83h

; SN76489 counts, 3579545 Hz / 32 / frequency, from A at 109 Hz, shifted up
; six bits; tickTandy shifts them back as it splits them into two bytes.
tandyDividers   dw      1023 SHL 6, 965 SHL 6, 911 SHL 6, 860 SHL 6, 813 SHL 6, 766 SHL 6
                dw      723 SHL 6, 682 SHL 6, 644 SHL 6, 608 SHL 6, 574 SHL 6, 541 SHL 6

; ---------------------------------------------------------------------------
; The songs: a stream for each of the four voices, or 0 to leave it alone.
; Song 0 stops all four.

speakerSongs    dw      offset speakerSilence, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 0
                dw      offset speakerSong1, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 1
                dw      offset speakerSong2, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 2
                dw      offset speakerSong3, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 3
                dw      offset speakerSong4, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 4
                dw      offset speakerSong5, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 5
                dw      offset speakerSong6, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 6
                dw      offset speakerSong7, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 7
                dw      offset speakerSong8, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 8
                dw      offset speakerSong9, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 9
                dw      offset speakerSong10, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 10
                dw      offset speakerSong11, offset speakerSilence, offset speakerSilence, offset speakerSilence  ; 11
                dw      offset speakerSong12, 0, 0, 0  ; 12

tandySongs      dw      offset tandySilence, offset tandySilence, offset tandySilence, offset tandySilence  ; 0
                dw      offset tandySong1v0, offset tandySong1v1, offset tandySong1v2, offset tandySilence  ; 1
                dw      offset tandySilence, offset tandySilence, offset tandySilence, offset tandySong2  ; 2
                dw      offset tandySong3v0, offset tandySong3v1, offset tandySong3v2, offset tandySilence  ; 3
                dw      offset tandySong4v0, offset tandySilence, offset tandySong4v2, offset tandySong4v3  ; 4
                dw      offset tandySong5, offset tandySilence, offset tandySilence, offset tandySilence  ; 5
                dw      offset tandySilence, offset tandySilence, offset tandySong6v2, offset tandySong6v3  ; 6
                dw      offset tandySong7v0, offset tandySong7v1, offset tandySilence, offset tandySilence  ; 7
                dw      offset tandySilence, offset tandySilence, offset tandySilence, offset tandySong8  ; 8
                dw      offset tandySilence, offset tandySilence, offset tandySilence, offset tandySong9  ; 9
                dw      offset tandySilence, offset tandySilence, offset tandySong10v2, offset tandySong10v3  ; 10
                dw      offset tandySong11v0, offset tandySong11v1, offset tandySong11v2, offset tandySilence  ; 11
                dw      offset tandySong12, offset tandySilence, offset tandySilence, offset tandySilence  ; 12

; ---------------------------------------------------------------------------
; Vibrato waves, as signed bytes.  A voice steps through one by vRate a tick,
; in sixteenths of an entry, and wraps at vWaveLen.

sineWave        label   byte
        db      0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45
        db      48, 51, 54, 57, 59, 62, 65, 67, 70, 73, 75, 78, 80, 82, 85, 87
        db      89, 91, 94, 96, 98, 100, 102, 103, 105, 107, 108, 110, 112, 113, 114, 116
        db      117, 118, 119, 120, 121, 122, 123, 123, 124, 125, 125, 126, 126, 126, 126, 126
        db      126, 126, 126, 126, 126, 126, 125, 125, 124, 123, 123, 122, 121, 120, 119, 118
        db      117, 116, 114, 113, 112, 110, 108, 107, 105, 103, 102, 100, 98, 96, 94, 91
        db      89, 87, 85, 82, 80, 78, 75, 73, 70, 67, 65, 62, 59, 57, 54, 51
        db      48, 45, 42, 39, 36, 33, 30, 27, 24, 21, 18, 15, 12, 9, 6, 3
        db      0, -3, -6, -9, -12, -15, -18, -21, -24, -27, -30, -33, -36, -39, -42, -45
        db      -48, -51, -54, -57, -59, -62, -65, -67, -70, -73, -75, -78, -80, -82, -85, -87
        db      -89, -91, -94, -96, -98, -100, -102, -103, -105, -107, -108, -110, -112, -113, -114, -116
        db      -117, -118, -119, -120, -121, -122, -123, -123, -124, -125, -125, -126, -126, -126, -126, -126
        db      -126, -126, -126, -126, -126, -126, -125, -125, -124, -123, -123, -122, -121, -120, -119, -118
        db      -117, -116, -114, -113, -112, -110, -108, -107, -105, -103, -102, -100, -98, -96, -94, -91
        db      -89, -87, -85, -82, -80, -78, -75, -73, -70, -67, -65, -62, -59, -57, -54, -51
        db      -48, -45, -42, -39, -36, -33, -30, -27, -24, -21, -18, -15, -12, -9, -6, -3
SINE_LEN        =       $ - sineWave

squareWave      db      16 dup (0), 16 dup (120)
SQUARE_LEN      =       $ - squareWave

noiseWave       label   byte
        db      29h,23h,0BEh,84h,0E1h,6Ch,0D6h,0AEh,52h,90h,49h,0F1h,0F1h,0BBh,0E9h,0EBh
        db      0B3h,0A6h,0DBh,3Ch,87h,0Ch,3Eh,99h,24h,5Eh,0Dh,1Ch,06h,0B7h,47h,0DEh
        db      0B3h,12h,4Dh,0C8h,43h,0BBh,8Bh,0A6h,1Fh,03h,5Ah,7Dh,09h,38h,25h,1Fh
        db      5Dh,0D4h,0CBh,0FCh,96h,0F5h,45h,3Bh,13h,0Dh,89h,0Ah,1Ch,0DBh,0AEh,32h
        db      20h,9Ah,50h,0EEh,40h,78h,36h,0FDh,12h,49h,32h,0F6h,9Eh,7Dh,49h,0DCh
        db      0ADh,4Fh,14h,0F2h,44h,40h,66h,0D0h,6Bh,0C4h,30h,0B7h,32h,3Bh,0A1h,22h
        db      0F6h,22h,91h,9Dh,0E1h,8Bh,1Fh,0DAh,0B0h,0CAh,99h,02h,0B9h,72h,9Dh,49h
        db      2Ch,80h,7Eh,0C5h,99h,0D5h,0E9h,80h,0B2h,0EAh,0C9h,0CCh,53h,0BFh,67h,0D6h
        db      0BFh,14h,0D6h,7Eh,2Dh,0DCh,8Eh,66h,83h,0EFh,57h,49h,61h,0FFh,69h,8Fh
        db      61h,0CDh,0D1h,1Eh,9Dh,9Ch,16h,72h,72h,0E6h,1Dh,0F0h,84h,4Fh,4Ah,77h
        db      02h,0D7h,0E8h,39h,2Ch,53h,0CBh,0C9h,12h,1Eh,33h,74h,9Eh,0Ch,0F4h,0D5h
        db      0D4h,9Fh,0D4h,0A4h,59h,7Eh,35h,0CFh,32h,22h,0F4h,0CCh,0CFh,0D3h,90h,2Dh
        db      48h,0D3h,8Fh,75h,0E6h,0D9h,1Dh,2Ah,0E5h,0C0h,0F7h,2Bh,78h,81h,87h,44h
        db      0Eh,5Fh,50h,00h,0D4h,61h,8Dh,0BEh,7Bh,05h,15h,07h,3Bh,33h,82h,1Fh
        db      18h,70h,92h,0DAh,64h,54h,0CEh,0B1h,85h,3Eh,69h,15h,0F8h,46h,6Ah,04h
        db      96h,73h,0Eh,0D9h,16h,2Fh,67h,68h,0D4h,0F7h,4Ah,4Ah,0D0h,57h,68h,76h
        db      0FAh,16h,0BBh,11h,0ADh,0AEh,24h,88h,79h,0FEh,52h,0DBh,25h,43h,0E5h,3Ch
        db      0F4h,45h,0D3h,0D8h,28h,0CEh,0Bh,0F5h,0C5h,60h,59h,3Dh,97h,27h,8Ah,59h
        db      76h,2Dh,0D0h,0C2h,0C9h,0CDh,68h,0D4h,49h,6Ah,79h,25h,08h,61h,40h,14h
        db      0B1h,3Bh,6Ah,0A5h,11h,28h,0C1h,8Ch,0D6h,0A9h,0Bh,87h,97h,8Ch,2Fh,0F1h
        db      15h,1Dh,9Ah,95h,0C1h,9Bh,0E1h,0C0h,7Eh,0E9h,0A8h,9Ah,0A7h,86h,0C2h,0B5h
        db      54h,0BFh,9Ah,0E7h,0D9h,23h,0D1h,55h,90h,38h,28h,0D1h,0D9h,6Ch,0A1h,66h
        db      5Eh,4Eh,0E1h,30h,9Ch,0FEh,0D9h,71h,9Fh,0E2h,0A5h,0E2h,0Ch,9Bh,0B4h,47h
        db      65h,38h,2Ah,46h,89h,0A9h,82h,79h,7Ah,76h,78h,0C2h,63h,0B1h,26h,0DFh
        db      0DAh,29h,6Dh,3Eh,62h,0E0h,96h,12h,34h,0BFh,39h,0A6h,3Fh,89h,5Eh,0F1h
        db      6Dh,0Eh,0E3h,6Ch,28h,0A1h,1Eh,20h,1Dh,0CBh,0C2h,03h,3Fh,41h,07h,84h
        db      0Fh,14h,05h,65h,1Bh,28h,61h,0C9h,0C5h,0E7h,2Ch,8Eh,46h,36h,08h,0DCh
        db      0F3h,0A8h,8Dh,0FEh,0BEh,0F2h,0EBh,71h,0FFh,0A0h,0D0h,3Bh,75h,06h,8Ch,7Eh
        db      87h,78h,73h,4Dh,0D0h,0BEh,82h,0BEh,0DBh,0C2h,46h,41h,2Bh,8Ch,0FAh,30h
        db      7Fh,70h,0F0h,0A7h,54h,86h,32h,95h,0AAh,5Bh,68h,13h,0Bh,0E6h,0FCh,0F5h
        db      0CAh,0BEh,7Dh,9Fh,89h,8Ah,41h,1Bh,0FDh,0B8h,4Fh,68h,0F6h,72h,7Bh,14h
        db      99h,0CDh,0D3h,0Dh,0F0h,44h,3Ah,0B4h,0A6h,66h,53h,33h,0Bh,0CBh,0A1h,10h
NOISE_LEN       =       $ - noiseWave

; ---------------------------------------------------------------------------
; The streams

speakerSong10:
        vset    vLevel, 3
        vset    vPeriod, 30000
        wave    noiseWave
        vset    vWaveLen, NOISE_LEN*16
        vset    vDepth, 10000
        vset    vRate, 16
        vset    vTicks, 28
        vset    vLevel, 0
        vset    vTicks, 12
        vset    vLevel, 3
        vset    vPeriod, 4100
        vset    vDepth, 2200
        vset    vSlide, 16
        vset    vTicks, 300
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong8:
        vset    vLevel, 3
        vset    vPeriod, 4000
        vset    vTicks, 5
        vset    vPeriod, 1000
        vset    vTicks, 4
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong9:
        vset    vLevel, 3
        vset    vPeriod, 14000
        vset    vSlide, 200
        wave    noiseWave
        vset    vWaveLen, NOISE_LEN*16
        vset    vDepth, 6000
        vset    vRate, 123
        vset    vTicks, 8
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong7:
        vset    vLevel, 3
        vset    vPeriod, 16308
        vset    vCount1, 30
speakerSong7Loop:
        vset    vSlide, -452
        vset    vTicks, 12
        vset    vSlide, 631
        vset    vTicks, 8
        vloop   vCount1, speakerSong7Loop
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong2:
        vset    vLevel, 3
        wave    noiseWave
        vset    vWaveLen, NOISE_LEN*16
        vset    vDepth, 1600
        vset    vRate, 411
        vset    vPeriod, 4300
        vset    vSlide, 10
        vset    vTicks, 30
        vset    vDepth, 900
        vset    vPeriod, 1300
        vset    vSlide, 80
        vset    vTicks, 5
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong5:
        vset    vLevel, 3
        vset    vCount1, 5
        vset    vPeriod, 6200
speakerSong5Loop1:
        vset    vSlide, 0
        vset    vTicks, 6
        vset    vCount2, 12
speakerSong5Loop2:
        vset    vSlide, -930
        vset    vTicks, 1
        vset    vSlide, 900
        vset    vTicks, 1
        vloop   vCount2, speakerSong5Loop2
        vloop   vCount1, speakerSong5Loop1
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong3:
        vset    vLevel, 3
        vset    vPeriod, 6523
        vset    vCount1, 10
speakerSong3Loop:
        vset    vSlide, -45
        vset    vTicks, 20
        vset    vSlide, 500
        vset    vTicks, 1
        vloop   vCount1, speakerSong3Loop
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong4:
        vset    vLevel, 3
        wave    noiseWave
        vset    vWaveLen, NOISE_LEN*16
        vset    vDepth, 10000
        vset    vRate, 16
        vset    vPeriod, 12000
        vset    vCount1, 44
speakerSong4Loop:
        vset    vSlide, -3600
        vset    vTicks, 2
        vset    vSlide, 3720
        vset    vTicks, 2
        vloop   vCount1, speakerSong4Loop
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong6:
        vset    vLevel, 3
        wave    noiseWave
        vset    vWaveLen, NOISE_LEN*16
        vset    vDepth, 2600
        vset    vRate, 16
        vset    vPeriod, 6000
        vset    vSlide, -160
        vset    vTicks, 30
        vset    vSlide, 70
        vset    vTicks, 35
        vset    vLevel, 0
        vset    vTicks, 0

speakerSilence:
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong1:
        vset    vLevel, 3
        vset    vPeriod, 5000
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 500
        vset    vRate, 78
        vset    vCount1, 40
speakerSong1Loop:
        vset    vSlide, 0
        vset    vTicks, 2
        vset    vSlide, -595
        vset    vTicks, 1
        vset    vSlide, 0
        vset    vTicks, 2
        vset    vSlide, 500
        vset    vTicks, 1
        vloop   vCount1, speakerSong1Loop
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong11:
        vset    vLevel, 3
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 1000
        vset    vRate, 256
        vset    vPeriod, 3300
        vset    vSlide, -20
        vset    vTicks, 30
        vset    vLevel, 0
        vset    vTicks, 0

speakerSong12:
        vcall   speakerSong12Setup
        note    1, 60, 6
        note    0, 60, 13
        note    2, 24, 133
        note    3, 36, 15
        last    4, 31, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        last    4, 36, 22
        last    0, REST, 4
        last    0, REST, 3
        note    1, 67, 4
        note    0, 60, 5
        last    3, 36, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 67, 4
        note    0, 60, 7
        last    3, 36, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 67, 6
        note    0, 60, 13
        last    3, 36, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 55, 13
        last    3, 31, 12
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 67, 4
        note    0, 60, 13
        last    3, 36, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 60, 6
        note    0, 64, 13
        last    3, 40, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 60, 13
        last    3, 36, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 64, 10
        last    3, 40, 8
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 67, 13
        note    3, 43, 13
        last    2, 28, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 59, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 64, 13
        note    3, 40, 13
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 3
        note    1, 64, 4
        last    4, 31, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 67, 10
        note    3, 43, 7
        last    4, 36, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 1
        note    1, 64, 4
        last    4, 31, 6
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 6
        note    0, 69, 43
        note    2, 33, 164
        note    3, 48, 43
        last    4, 36, 16
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 69, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 6
        note    0, 72, 43
        last    3, 52, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 69, 43
        last    3, 53, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 14
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 64, 29
        last    3, 52, 30
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 11
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 31, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 60, 6
        note    0, 60, 13
        note    2, 24, 131
        note    3, 48, 13
        last    4, 36, 32
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 67, 4
        note    0, 60, 4
        last    3, 48, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 67, 4
        note    0, 60, 5
        last    3, 48, 6
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 1
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 67, 6
        note    0, 60, 13
        last    3, 48, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 55, 13
        last    3, 43, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 60, 13
        last    3, 48, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 5
        note    0, 64, 13
        last    3, 52, 13
        last    0, REST, 5
        last    0, REST, 2
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 60, 13
        last    3, 48, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 60, 4
        note    0, 64, 8
        last    3, 52, 7
        last    0, REST, 4
        last    0, REST, 3
        last    1, 60, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 4
        note    1, 71, 5
        note    0, 67, 13
        note    2, 28, 43
        last    3, 55, 13
        last    0, REST, 5
        last    0, REST, 2
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 71, 4
        note    0, 64, 13
        last    3, 52, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 67, 11
        last    3, 55, 7
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 69, 43
        note    3, 60, 43
        last    2, 33, 158
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 69, 4
        last    4, 36, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        last    4, 36, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 36, 7
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        note    1, 69, 5
        note    0, 72, 43
        last    3, 64, 43
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 1
        last    4, 36, 5
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        note    4, 36, 5
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        last    4, 36, 5
        last    0, REST, 1
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        note    4, 36, 6
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 5
        note    0, 69, 43
        last    3, 65, 43
        last    0, REST, 5
        last    0, REST, 2
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 69, 4
        last    4, 36, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 4
        last    4, 36, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 36, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 5
        note    0, 64, 31
        last    3, 64, 31
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 64, 6
        last    0, REST, 6
        last    0, REST, 2
        last    0, REST, 7
        last    4, 36, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 1
        note    1, 53, 28
        note    0, 65, 13
        note    2, 29, 28
        note    3, 45, 14
        last    4, 29, 19
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 5
        last    0, REST, 3
        note    0, 65, 5
        last    3, 45, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 65, 17
        note    0, 65, 5
        note    3, 45, 8
        last    2, 36, 28
        last    0, REST, 5
        last    0, REST, 3
        last    0, REST, 7
        note    0, 65, 13
        last    3, 45, 13
        last    0, REST, 2
        last    0, REST, 11
        last    0, REST, 2
        note    1, 53, 12
        note    0, 67, 13
        note    2, 41, 28
        last    3, 47, 13
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    1, 65, 13
        note    0, 69, 7
        last    3, 48, 13
        last    0, REST, 7
        last    0, REST, 6
        last    0, REST, 2
        note    1, 53, 28
        note    0, 68, 12
        note    2, 29, 28
        last    3, 41, 16
        last    0, REST, 12
        last    0, REST, 4
        last    0, REST, 6
        note    0, 68, 5
        last    3, 41, 5
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        note    1, 65, 40
        note    0, 68, 5
        note    3, 41, 7
        last    2, 36, 28
        last    0, REST, 5
        last    0, REST, 2
        last    0, REST, 8
        note    0, 68, 13
        last    3, 41, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 70, 13
        note    2, 41, 28
        last    3, 43, 13
        last    0, REST, 10
        last    0, REST, 3
        last    0, REST, 2
        note    0, 72, 13
        last    3, 44, 7
        last    0, REST, 7
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 36
        note    0, 76, 43
        note    3, 47, 28
        last    2, 36, 26
        last    0, REST, 26
        last    0, REST, 2
        last    0, REST, 2
        last    3, 48, 13
        last    0, REST, 6
        last    0, REST, 1
        last    0, REST, 6
        last    0, REST, 2
        note    0, 72, 43
        last    3, 43, 42
        last    0, REST, 42
        last    0, REST, 1
        last    0, REST, 2
        note    0, 67, 43
        last    3, 40, 42
        last    0, REST, 42
        last    0, REST, 1
        last    0, REST, 2
        note    0, 64, 27
        last    3, 36, 28
        last    0, REST, 27
        last    0, REST, 1
        last    0, REST, 2
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 1
        note    1, 60, 22
        note    0, 65, 12
        note    2, 41, 28
        note    3, 53, 13
        last    4, 29, 30
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 9
        note    0, 65, 4
        last    3, 53, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 65, 22
        note    0, 65, 5
        note    2, 48, 28
        last    3, 53, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 9
        note    0, 65, 13
        last    3, 53, 13
        last    0, REST, 7
        last    0, REST, 6
        last    0, REST, 2
        note    1, 53, 11
        note    0, 67, 13
        note    2, 53, 25
        last    3, 55, 13
        last    0, REST, 11
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 60, 10
        note    0, 69, 12
        last    3, 57, 9
        last    0, REST, 9
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 3
        note    1, 50, 31
        note    0, 66, 13
        last    3, 57, 12
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 9
        note    0, 66, 4
        last    3, 57, 4
        last    0, REST, 4
        last    0, REST, 4
        note    0, 66, 5
        last    3, 57, 6
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 9
        note    1, 57, 32
        note    0, 66, 13
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 67, 13
        last    3, 59, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 69, 13
        last    3, 60, 13
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 10
        last    0, REST, 2
        note    1, 55, 158
        note    0, 71, 150
        note    2, 43, 157
        last    3, 50, 161
        last    0, REST, 15
        last    4, 38, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 38, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 38, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 38, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 38, 12
        last    0, REST, 12
        last    0, REST, 3
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 4
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 2
        last    4, 31, 6
        last    0, REST, 6
        last    0, REST, 3
        last    4, 31, 7
        last    0, REST, 7
        last    0, REST, 8
        last    4, 26, 11
        last    0, REST, 11
        last    0, REST, 4
        last    4, 31, 8
        last    0, REST, 8
        last    0, REST, 7
        last    4, 38, 6
        last    0, REST, 6
        last    0, REST, 9
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 4
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        note    1, 67, 6
        note    0, 48, 14
        note    2, 24, 133
        note    3, 60, 13
        last    4, 36, 27
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 1
        last    0, REST, 1
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 67, 4
        note    0, 48, 5
        last    3, 60, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 67, 4
        note    0, 48, 5
        last    3, 60, 6
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 1
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 60, 5
        note    0, 48, 13
        last    3, 60, 13
        last    0, REST, 5
        last    0, REST, 2
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 60, 4
        note    0, 43, 13
        last    3, 55, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 48, 13
        last    3, 60, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 6
        note    0, 52, 13
        last    3, 64, 13
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 48, 13
        last    3, 60, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 52, 8
        last    3, 64, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 55, 13
        note    2, 28, 43
        last    3, 67, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 59, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 52, 13
        last    3, 64, 12
        last    0, REST, 4
        last    0, REST, 3
        last    1, 71, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        note    0, 55, 10
        last    3, 67, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 57, 43
        note    2, 33, 176
        last    3, 69, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 28, 15
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 60, 43
        last    3, 72, 40
        last    0, REST, 6
        last    0, REST, 1
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 33, 14
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 57, 43
        last    3, 77, 42
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 28, 8
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 4
        note    1, 64, 4
        last    4, 33, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 52, 27
        last    3, 76, 33
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 6
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 40, 9
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 4
        note    1, 60, 6
        note    0, 60, 13
        note    2, 24, 133
        note    3, 72, 12
        last    4, 36, 20
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 60, 4
        note    0, 60, 4
        last    3, 72, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 67, 4
        note    0, 60, 4
        last    3, 72, 6
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 1
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 60, 6
        note    0, 60, 13
        last    3, 72, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 60, 4
        note    0, 55, 13
        last    3, 67, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 60, 13
        last    3, 72, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 60, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 6
        note    0, 64, 13
        last    3, 76, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 60, 4
        note    0, 60, 13
        last    3, 72, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 64, 9
        last    3, 76, 8
        last    0, REST, 4
        last    0, REST, 3
        last    1, 60, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 67, 13
        note    2, 28, 43
        last    3, 79, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 59, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 64, 13
        last    3, 76, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 71, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 67, 10
        last    3, 79, 8
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 69, 43
        note    2, 33, 164
        last    3, 81, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 69, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 4
        last    4, 33, 7
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        note    1, 64, 5
        note    0, 72, 43
        last    3, 77, 43
        last    0, REST, 5
        last    0, REST, 2
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 69, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 5
        note    0, 69, 43
        last    3, 76, 43
        last    0, REST, 5
        last    0, REST, 2
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 69, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 69, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 64, 29
        last    3, 79, 34
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 3
        last    0, REST, 1
        note    1, 69, 4
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 1
        last    4, 36, 2
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 3
        last    4, 36, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 53, 13
        note    0, 65, 14
        last    4, 29, 19
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 1
        last    1, 65, 13
        last    0, REST, 4
        last    0, REST, 3
        last    0, 65, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 53, 11
        note    0, 65, 5
        last    2, 36, 28
        last    0, REST, 5
        last    0, REST, 6
        last    0, REST, 4
        note    1, 53, 13
        note    0, 65, 13
        last    3, 69, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 65, 13
        note    0, 67, 13
        note    2, 41, 13
        last    3, 71, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 53, 13
        note    0, 69, 8
        note    2, 36, 6
        last    3, 72, 12
        last    0, REST, 6
        last    0, REST, 1
        last    2, 29, 33
        last    0, REST, 1
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        note    1, 53, 13
        last    0, 68, 12
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        last    1, 65, 13
        last    0, REST, 7
        last    0, 68, 5
        last    0, REST, 3
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 2
        note    1, 53, 12
        note    0, 68, 5
        last    2, 36, 28
        last    0, REST, 5
        last    0, REST, 7
        last    0, REST, 3
        note    1, 53, 13
        note    0, 68, 13
        last    3, 65, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 65, 28
        note    0, 70, 13
        note    2, 41, 28
        last    3, 67, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 72, 13
        last    3, 68, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 64, 73
        note    0, 76, 43
        note    2, 36, 25
        last    3, 71, 26
        last    0, REST, 25
        last    0, REST, 1
        last    0, REST, 4
        last    3, 72, 14
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 1
        note    0, 72, 43
        last    3, 67, 43
        last    0, REST, 28
        last    0, REST, 15
        last    0, REST, 2
        note    0, 67, 43
        last    3, 64, 42
        last    0, REST, 42
        last    0, REST, 1
        last    0, REST, 2
        note    0, 64, 29
        last    3, 60, 29
        last    0, REST, 29
        last    0, REST, 1
        last    4, 36, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 36, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        note    1, 53, 13
        note    0, 65, 16
        note    2, 29, 33
        note    3, 65, 11
        last    4, 29, 20
        last    0, REST, 11
        last    0, REST, 2
        last    0, REST, 2
        last    1, 60, 13
        last    0, REST, 1
        last    0, REST, 4
        last    0, REST, 2
        note    0, 65, 4
        last    3, 65, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 53, 9
        note    0, 65, 5
        last    3, 65, 7
        last    0, REST, 3
        last    0, REST, 2
        last    0, REST, 2
        last    2, 36, 30
        last    0, REST, 2
        last    0, REST, 6
        note    1, 53, 13
        note    0, 65, 13
        last    3, 65, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 65, 15
        note    0, 67, 13
        last    3, 67, 13
        last    0, REST, 7
        last    0, REST, 6
        last    0, REST, 2
        note    0, 69, 7
        last    3, 69, 9
        last    0, REST, 7
        last    0, REST, 2
        last    0, REST, 6
        note    1, 57, 13
        note    0, 66, 12
        last    2, 26, 88
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        last    1, 62, 13
        last    0, REST, 7
        note    0, 66, 4
        last    3, 57, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 57, 9
        note    0, 66, 6
        last    3, 57, 6
        last    0, REST, 6
        last    0, REST, 3
        last    0, REST, 6
        note    1, 57, 13
        note    0, 66, 13
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 69, 13
        note    0, 67, 13
        last    3, 59, 12
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    0, 69, 13
        last    3, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 59, 150
        note    0, 71, 51
        note    2, 31, 133
        last    3, 50, 86
        last    0, REST, 15
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 5
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 5
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 4
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 5
        last    4, 31, 9
        last    0, REST, 6
        last    0, REST, 1
        last    0, 74, 6
        last    0, REST, 2
        last    0, REST, 4
        last    0, REST, 2
        note    0, 79, 107
        last    4, 26, 7
        last    0, REST, 7
        last    0, REST, 8
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 8
        last    0, REST, 4
        note    3, 62, 63
        last    4, 31, 6
        last    0, REST, 6
        last    0, REST, 9
        last    4, 26, 7
        last    0, REST, 7
        last    0, REST, 8
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 9
        last    0, REST, 2
        note    2, 38, 37
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 13
        last    0, REST, 3
        last    0, REST, 12
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 31, 3
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 2
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        note    0, 59, 43
        note    2, 55, 88
        note    3, 40, 43
        last    4, 28, 12
        last    0, REST, 12
        last    0, REST, 31
        last    0, REST, 2
        note    0, 64, 20
        last    3, 47, 43
        last    0, REST, 20
        last    0, REST, 2
        last    0, 62, 6
        last    0, REST, 6
        last    0, REST, 2
        last    0, 60, 12
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    0, 59, 13
        note    2, 57, 88
        last    3, 41, 43
        last    0, REST, 13
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        last    0, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 59, 13
        last    3, 48, 43
        last    0, REST, 13
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        last    0, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 59, 42
        note    2, 55, 77
        last    3, 40, 42
        last    0, REST, 42
        last    0, REST, 3
        note    0, 64, 20
        last    3, 47, 43
        last    0, REST, 20
        last    0, REST, 2
        last    0, 62, 6
        last    0, REST, 6
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 2
        last    0, REST, 11
        last    0, REST, 2
        note    0, 59, 5
        note    2, 50, 74
        last    3, 43, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        note    0, 57, 6
        last    3, 38, 6
        last    0, REST, 6
        last    0, REST, 2
        note    0, 55, 59
        last    3, 31, 60
        last    0, REST, 59
        last    0, REST, 1
        last    0, REST, 15
        note    0, 59, 43
        note    2, 52, 88
        last    3, 40, 43
        last    0, REST, 43
        last    0, REST, 2
        note    0, 64, 20
        last    3, 47, 43
        last    0, REST, 20
        last    0, REST, 2
        last    0, 62, 6
        last    0, REST, 6
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 59, 13
        note    2, 53, 75
        last    3, 41, 43
        last    0, REST, 13
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        last    0, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 59, 13
        last    3, 48, 35
        last    0, REST, 13
        last    0, REST, 2
        last    0, 60, 13
        last    0, REST, 13
        last    0, REST, 2
        last    0, 57, 13
        last    0, REST, 5
        last    0, REST, 8
        last    0, REST, 2
        note    0, 59, 28
        note    2, 52, 22
        last    3, 52, 6
        last    0, REST, 6
        last    0, REST, 1
        last    3, 50, 6
        last    0, REST, 6
        last    0, REST, 2
        last    3, 47, 11
        last    0, REST, 7
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    0, 62, 28
        note    2, 55, 22
        last    3, 45, 6
        last    0, REST, 6
        last    0, REST, 1
        last    3, 43, 6
        last    0, REST, 6
        last    0, REST, 2
        last    3, 40, 11
        last    0, REST, 7
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    0, 64, 28
        note    2, 50, 22
        last    3, 38, 11
        last    0, REST, 11
        last    0, REST, 4
        last    3, 38, 6
        last    0, REST, 6
        last    0, REST, 1
        last    3, 31, 6
        last    0, REST, 6
        last    0, REST, 2
        note    0, 59, 13
        note    2, 55, 13
        last    3, 35, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 62, 61
        note    2, 47, 73
        last    3, 38, 59
        last    0, REST, 59
        last    0, REST, 2
        last    0, REST, 12
        last    0, REST, 2
        note    1, 64, 43
        note    0, 71, 43
        note    2, 52, 81
        last    3, 28, 43
        last    0, REST, 43
        last    0, REST, 2
        note    1, 67, 21
        note    0, 76, 20
        last    3, 35, 43
        last    0, REST, 1
        last    0, REST, 19
        last    0, REST, 1
        last    0, REST, 1
        note    1, 66, 6
        last    0, 74, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 6
        last    0, REST, 2
        last    0, REST, 5
        last    0, REST, 2
        note    1, 62, 12
        note    0, 71, 13
        note    2, 57, 42
        last    3, 29, 43
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 60, 13
        last    0, 69, 13
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 1
        last    2, 60, 34
        last    0, REST, 1
        note    1, 62, 13
        note    0, 71, 13
        last    3, 36, 43
        last    0, REST, 13
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 60, 13
        last    0, 69, 13
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 10
        last    0, REST, 2
        note    1, 64, 43
        note    0, 71, 43
        note    2, 55, 43
        last    3, 28, 43
        last    0, REST, 43
        last    0, REST, 2
        note    1, 67, 21
        note    0, 76, 20
        note    2, 59, 34
        last    3, 35, 34
        last    0, REST, 20
        last    0, REST, 1
        last    0, REST, 1
        note    1, 66, 6
        last    0, 74, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 4
        last    0, REST, 9
        last    0, REST, 2
        note    1, 62, 6
        note    0, 71, 6
        last    3, 43, 6
        last    0, REST, 6
        last    0, REST, 1
        note    1, 60, 6
        note    0, 69, 6
        last    3, 38, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 59, 56
        note    0, 67, 54
        note    3, 31, 62
        last    2, 50, 58
        last    0, REST, 54
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 4
        last    0, REST, 13
        note    1, 64, 43
        note    0, 71, 43
        note    3, 28, 43
        last    2, 52, 78
        last    0, REST, 43
        last    0, REST, 2
        note    1, 67, 20
        note    0, 76, 20
        last    3, 35, 43
        last    0, REST, 20
        last    0, REST, 2
        note    1, 66, 6
        last    0, 74, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 9
        last    0, REST, 2
        note    1, 62, 13
        note    0, 71, 13
        note    3, 29, 43
        last    2, 53, 78
        last    0, REST, 13
        last    0, REST, 2
        note    1, 64, 13
        last    0, 72, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 60, 13
        last    0, 69, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 62, 13
        note    0, 71, 13
        last    3, 36, 32
        last    0, REST, 13
        last    0, REST, 2
        note    1, 64, 14
        last    0, 72, 13
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 1
        note    1, 60, 13
        last    0, 69, 13
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 8
        last    0, REST, 2
        note    1, 62, 13
        note    0, 70, 13
        last    2, 58, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 58, 13
        note    0, 65, 13
        note    3, 34, 27
        last    2, 53, 14
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 1
        note    1, 53, 13
        note    0, 70, 13
        last    2, 58, 13
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    1, 60, 13
        note    0, 72, 13
        note    2, 62, 42
        last    3, 43, 42
        last    0, REST, 13
        last    0, REST, 2
        note    1, 55, 13
        last    0, 67, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 52, 13
        last    0, 72, 13
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    1, 50, 6
        note    0, 74, 75
        note    3, 38, 85
        last    2, 55, 86
        last    0, REST, 6
        last    0, REST, 1
        last    1, 43, 59
        last    0, REST, 59
        last    0, REST, 9
        last    0, REST, 10
        last    0, REST, 1
        last    0, REST, 4
        note    1, 64, 6
        note    0, 48, 16
        note    4, 31, 12
        last    2, 24, 133
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        last    4, 36, 20
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 3
        note    1, 67, 4
        last    0, 48, 4
        last    0, REST, 4
        last    0, REST, 4
        note    1, 64, 4
        last    0, 48, 9
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 4
        note    1, 64, 6
        last    0, 48, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    0, 43, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        last    0, 48, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 6
        last    0, 52, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 48, 13
        note    3, 36, 13
        last    4, 31, 22
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 52, 10
        last    3, 40, 10
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 71, 6
        note    0, 55, 13
        note    2, 28, 43
        last    3, 43, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 52, 13
        note    3, 40, 13
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 36, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 71, 4
        note    0, 55, 12
        note    3, 43, 8
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 36, 5
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 57, 43
        note    2, 33, 133
        note    3, 48, 43
        last    4, 36, 14
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 1
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 6
        note    0, 60, 42
        last    3, 52, 43
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 28, 32
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 57, 43
        last    3, 53, 43
        last    0, REST, 2
        last    0, REST, 4
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 14
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 52, 28
        note    2, 28, 43
        last    3, 52, 32
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 4
        last    4, 31, 3
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 1
        last    4, 31, 3
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 1
        last    0, REST, 2
        last    4, 31, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 48, 17
        note    2, 24, 133
        last    4, 36, 18
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 3
        note    1, 67, 4
        note    0, 48, 5
        last    3, 43, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 64, 4
        note    0, 48, 12
        last    3, 43, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 6
        note    0, 48, 13
        last    3, 43, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 43, 13
        last    3, 36, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 48, 13
        last    3, 43, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 52, 13
        last    3, 48, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 48, 13
        last    3, 43, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 52, 12
        last    3, 48, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 6
        note    0, 55, 13
        note    2, 28, 43
        last    3, 52, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 71, 4
        note    0, 52, 13
        last    3, 47, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 71, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 71, 4
        note    0, 55, 10
        last    3, 52, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 57, 43
        note    2, 33, 133
        last    3, 48, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 17
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 69, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 6
        note    0, 60, 43
        last    3, 52, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 69, 4
        last    4, 40, 30
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 57, 43
        last    3, 53, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 14
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        note    1, 64, 4
        last    4, 40, 15
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 15
        note    0, 52, 31
        note    2, 28, 43
        last    3, 55, 30
        last    0, REST, 11
        last    0, REST, 4
        last    0, REST, 15
        last    4, 31, 2
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 3
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        note    0, 53, 14
        note    2, 29, 43
        note    3, 53, 12
        last    4, 29, 11
        last    0, REST, 11
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 1
        last    1, 53, 13
        last    0, REST, 7
        note    0, 53, 4
        last    3, 53, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 65, 10
        note    0, 53, 10
        last    3, 53, 6
        last    0, REST, 6
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 2
        note    0, 53, 13
        note    2, 36, 21
        last    3, 53, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 65, 13
        note    0, 55, 13
        last    3, 55, 13
        last    0, REST, 6
        last    0, REST, 1
        last    2, 41, 21
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        note    0, 57, 13
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 56, 14
        note    2, 29, 36
        last    3, 53, 13
        last    0, REST, 13
        last    0, REST, 1
        last    0, REST, 8
        note    0, 56, 4
        last    3, 53, 3
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 4
        note    0, 56, 10
        last    3, 53, 7
        last    0, REST, 6
        last    0, REST, 1
        last    2, 36, 33
        last    0, REST, 3
        last    0, REST, 5
        note    1, 53, 28
        note    0, 56, 13
        last    3, 53, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 58, 13
        last    3, 55, 13
        last    0, REST, 10
        last    0, REST, 3
        last    0, REST, 2
        note    0, 60, 13
        note    2, 41, 13
        last    3, 56, 9
        last    0, REST, 9
        last    0, REST, 4
        last    0, REST, 2
        note    1, 52, 40
        note    0, 64, 43
        note    2, 24, 85
        last    3, 59, 28
        last    0, REST, 28
        last    0, REST, 2
        last    3, 60, 13
        last    0, REST, 10
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    0, 60, 43
        last    3, 55, 43
        last    0, REST, 40
        last    0, REST, 3
        last    0, REST, 2
        note    0, 55, 41
        last    3, 52, 43
        last    0, REST, 41
        last    0, REST, 2
        last    0, REST, 2
        note    0, 52, 29
        last    3, 48, 30
        last    0, REST, 29
        last    0, REST, 1
        last    4, 36, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 36, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        note    0, 65, 18
        note    2, 29, 35
        note    3, 57, 15
        last    4, 29, 16
        last    0, REST, 15
        last    1, 53, 15
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 4
        note    0, 65, 4
        last    3, 57, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    0, 65, 11
        last    3, 57, 12
        last    0, REST, 5
        last    0, REST, 2
        last    2, 36, 26
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    0, 65, 13
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 53, 15
        note    0, 67, 13
        last    3, 59, 13
        last    0, REST, 3
        last    0, REST, 4
        last    2, 41, 18
        last    0, REST, 6
        last    0, REST, 2
        note    0, 69, 10
        last    3, 60, 13
        last    0, REST, 10
        last    0, REST, 3
        last    0, REST, 2
        note    0, 66, 15
        note    2, 26, 33
        last    3, 57, 14
        last    0, REST, 14
        last    0, REST, 1
        last    1, 50, 15
        last    0, REST, 7
        note    0, 66, 5
        last    3, 57, 5
        last    0, REST, 5
        last    0, REST, 3
        note    0, 66, 11
        last    3, 57, 11
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 4
        last    2, 33, 47
        last    0, REST, 4
        last    0, REST, 4
        note    0, 66, 13
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 67, 13
        last    3, 59, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 69, 13
        last    3, 60, 13
        last    0, REST, 9
        last    0, REST, 4
        last    0, REST, 2
        note    1, 43, 145
        note    0, 71, 165
        note    2, 31, 64
        last    3, 62, 124
        last    0, REST, 15
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 33, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 33, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 33, 7
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 8
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 31, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 31, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 31, 9
        last    0, REST, 9
        last    0, REST, 6
        last    4, 38, 6
        last    0, REST, 6
        last    0, REST, 9
        last    4, 31, 7
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 8
        last    4, 26, 16
        last    0, REST, 7
        last    0, REST, 3
        last    0, REST, 6
        last    0, REST, 14
        last    4, 31, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 2
        note    1, 67, 6
        note    0, 36, 16
        note    2, 24, 131
        note    3, 60, 14
        last    4, 36, 16
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 1
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 3
        note    1, 67, 4
        note    0, 36, 5
        last    3, 60, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 64, 4
        note    0, 36, 11
        last    3, 60, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 4
        note    1, 64, 6
        note    0, 36, 13
        last    3, 60, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 31, 13
        last    3, 55, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 36, 13
        last    3, 60, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 67, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 40, 13
        last    3, 64, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 36, 13
        last    3, 60, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 40, 11
        last    3, 64, 9
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 4
        note    1, 64, 5
        note    0, 43, 13
        note    2, 28, 43
        last    3, 67, 13
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 40, 13
        last    3, 64, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 67, 4
        note    0, 43, 11
        last    3, 67, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 45, 43
        note    2, 33, 75
        last    3, 60, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 11
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 69, 4
        last    4, 40, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 48, 43
        last    3, 64, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 28, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 45, 43
        last    3, 65, 43
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 76, 4
        last    4, 28, 11
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 69, 4
        last    4, 40, 13
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 76, 6
        note    0, 40, 30
        note    2, 28, 43
        last    3, 67, 29
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 76, 4
        last    4, 28, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 76, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 1
        last    1, 76, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 48, 16
        note    2, 24, 133
        last    3, 72, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 48, 6
        last    0, REST, 6
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 3
        note    1, 64, 4
        note    0, 48, 4
        last    3, 72, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    1, 64, 4
        note    0, 48, 10
        last    3, 72, 12
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 3
        note    1, 64, 6
        note    0, 48, 13
        last    3, 72, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 67, 4
        note    0, 43, 13
        last    3, 67, 12
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 64, 4
        note    0, 48, 13
        last    3, 72, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 52, 13
        last    3, 76, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 55, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        note    0, 48, 13
        last    3, 72, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 52, 10
        last    3, 76, 11
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 71, 6
        note    0, 55, 13
        note    2, 28, 43
        last    3, 79, 13
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 71, 4
        note    0, 52, 13
        last    3, 76, 13
        last    0, REST, 4
        last    0, REST, 3
        last    1, 71, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 4
        note    0, 55, 12
        last    3, 79, 11
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 69, 6
        note    0, 57, 43
        note    3, 81, 43
        last    2, 33, 95
        last    0, REST, 6
        last    0, REST, 1
        last    1, 52, 6
        last    0, REST, 6
        last    0, REST, 1
        last    4, 28, 10
        last    0, REST, 1
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 3
        last    4, 40, 4
        last    0, REST, 1
        last    1, 69, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 3
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 60, 43
        last    3, 84, 43
        last    0, REST, 6
        last    0, REST, 1
        note    1, 52, 6
        last    4, 33, 33
        last    0, REST, 6
        last    0, REST, 2
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 4
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 69, 6
        note    0, 57, 43
        last    3, 81, 43
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 2
        note    1, 64, 4
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 33, 3
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 3
        last    4, 33, 4
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 3
        note    4, 33, 6
        last    1, 69, 4
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 64, 6
        note    0, 52, 30
        note    2, 28, 42
        last    3, 76, 29
        last    0, REST, 6
        last    0, REST, 1
        last    1, 57, 6
        last    0, REST, 6
        last    0, REST, 1
        last    4, 33, 5
        last    0, REST, 1
        last    1, 64, 4
        last    0, REST, 4
        last    0, REST, 3
        note    1, 64, 4
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 3
        last    0, REST, 1
        note    1, 64, 4
        last    4, 33, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        last    4, 33, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        note    0, 53, 14
        note    2, 29, 43
        note    3, 69, 12
        last    4, 29, 15
        last    0, REST, 12
        last    0, REST, 2
        last    0, REST, 1
        last    1, 65, 13
        last    0, REST, 7
        note    0, 53, 5
        last    3, 69, 5
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 2
        note    0, 53, 9
        last    3, 69, 12
        last    0, REST, 9
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        note    0, 53, 13
        note    2, 36, 28
        last    3, 69, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 53, 12
        note    0, 55, 13
        last    3, 71, 13
        last    0, REST, 12
        last    0, REST, 1
        last    0, REST, 2
        note    0, 57, 11
        note    2, 41, 13
        last    3, 72, 13
        last    0, REST, 11
        last    0, REST, 2
        last    0, REST, 2
        note    0, 56, 16
        note    2, 29, 43
        last    3, 65, 15
        last    0, REST, 15
        last    0, REST, 1
        last    0, REST, 6
        note    1, 53, 4
        note    0, 56, 4
        last    3, 65, 4
        last    0, REST, 4
        last    0, REST, 4
        note    0, 56, 10
        last    3, 65, 9
        last    0, REST, 9
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 2
        note    0, 56, 13
        note    2, 36, 26
        last    3, 65, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 68, 15
        note    0, 58, 13
        last    3, 67, 13
        last    0, REST, 11
        last    0, REST, 2
        last    0, REST, 2
        note    0, 60, 13
        note    2, 41, 13
        last    3, 68, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 67, 42
        note    0, 64, 43
        note    2, 24, 34
        last    3, 71, 28
        last    0, REST, 28
        last    0, REST, 2
        last    3, 72, 13
        last    0, REST, 4
        last    0, REST, 8
        last    0, REST, 1
        last    0, REST, 2
        note    0, 60, 39
        last    3, 67, 43
        last    0, REST, 39
        last    0, REST, 4
        last    0, REST, 2
        note    0, 55, 31
        last    3, 64, 43
        last    0, REST, 31
        last    0, REST, 12
        last    0, REST, 2
        note    0, 52, 33
        last    3, 60, 30
        last    0, REST, 30
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    4, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        note    0, 65, 16
        note    2, 29, 43
        note    3, 53, 15
        last    4, 29, 15
        last    0, REST, 15
        last    1, 69, 13
        last    0, REST, 1
        last    0, REST, 6
        note    0, 65, 4
        last    3, 53, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    0, 65, 9
        last    3, 53, 11
        last    0, REST, 9
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 2
        note    0, 65, 13
        note    2, 36, 28
        last    3, 53, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 53, 17
        note    0, 67, 13
        last    3, 55, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 69, 10
        note    2, 41, 13
        last    3, 57, 10
        last    0, REST, 2
        last    0, REST, 8
        last    0, REST, 3
        last    0, REST, 2
        note    0, 66, 16
        note    2, 26, 42
        last    3, 57, 14
        last    0, REST, 14
        last    0, REST, 2
        last    0, REST, 6
        note    0, 66, 4
        last    3, 57, 5
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        note    0, 66, 11
        last    3, 57, 12
        last    0, REST, 11
        last    0, REST, 1
        last    0, REST, 3
        note    0, 66, 13
        note    2, 33, 41
        last    3, 57, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 67, 13
        last    3, 59, 13
        last    0, REST, 13
        last    0, REST, 2
        note    0, 69, 7
        last    3, 60, 13
        last    0, REST, 7
        last    0, REST, 4
        last    0, REST, 2
        last    0, REST, 2
        note    1, 55, 90
        note    0, 71, 6
        note    3, 62, 50
        note    4, 31, 6
        last    2, 31, 173
        last    0, REST, 6
        last    0, REST, 1
        last    0, 74, 6
        last    0, REST, 6
        last    0, REST, 2
        last    0, 79, 151
        last    0, REST, 15
        last    4, 38, 5
        last    0, REST, 5
        last    0, REST, 2
        last    4, 38, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 38, 6
        last    0, REST, 5
        last    0, REST, 1
        last    0, REST, 1
        last    3, 59, 5
        last    0, REST, 5
        last    0, REST, 3
        last    3, 55, 89
        last    0, REST, 30
        last    4, 31, 5
        last    0, REST, 1
        last    0, REST, 4
        last    0, REST, 25
        last    4, 38, 6
        last    0, REST, 6
        last    0, REST, 23
        last    0, REST, 17
        last    0, REST, 7
        last    0, REST, 7
        note    1, 67, 15
        note    0, 36, 15
        note    2, 31, 131
        note    3, 36, 15
        last    4, 31, 7
        last    0, REST, 7
        last    0, REST, 8
        last    0, REST, 7
        note    1, 67, 3
        note    0, 36, 5
        last    3, 36, 3
        last    0, REST, 3
        last    0, REST, 2
        last    0, REST, 2
        last    4, 38, 5
        last    0, REST, 1
        note    1, 67, 5
        note    0, 36, 5
        last    3, 36, 8
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 2
        last    4, 38, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 4
        note    1, 67, 13
        note    0, 36, 13
        note    3, 36, 13
        last    4, 38, 5
        last    0, REST, 5
        last    0, REST, 8
        last    0, REST, 2
        note    1, 60, 13
        note    0, 31, 13
        last    3, 31, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 67, 13
        note    0, 36, 12
        note    3, 36, 13
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 4
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 72, 13
        note    0, 40, 13
        note    3, 40, 13
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 9
        last    0, REST, 2
        note    1, 67, 13
        note    0, 36, 13
        last    3, 36, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 72, 13
        note    0, 40, 13
        note    3, 40, 8
        last    4, 38, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 38, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 2
        last    0, REST, 2
        note    1, 73, 13
        note    0, 44, 13
        note    2, 25, 41
        note    3, 44, 13
        last    4, 38, 6
        last    0, REST, 6
        last    0, REST, 7
        last    0, REST, 2
        note    1, 68, 13
        note    0, 40, 13
        last    3, 40, 13
        last    0, REST, 13
        last    0, REST, 2
        note    1, 73, 13
        note    0, 44, 13
        last    3, 44, 10
        last    0, REST, 10
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        note    1, 76, 43
        note    0, 45, 43
        note    2, 33, 86
        last    3, 45, 43
        last    0, REST, 43
        last    0, REST, 2
        note    1, 69, 43
        note    0, 52, 43
        last    3, 52, 42
        last    0, REST, 15
        last    4, 33, 3
        last    0, REST, 3
        last    0, REST, 4
        last    4, 33, 4
        last    0, REST, 4
        last    0, REST, 4
        last    4, 33, 7
        last    0, REST, 7
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 1
        last    0, REST, 2
        note    1, 70, 43
        note    0, 45, 43
        note    2, 27, 86
        note    3, 45, 43
        last    4, 33, 5
        last    0, REST, 5
        last    0, REST, 25
        last    4, 27, 6
        last    0, REST, 6
        last    0, REST, 7
        last    0, REST, 2
        note    1, 75, 43
        note    0, 39, 35
        last    3, 27, 38
        last    0, REST, 15
        last    4, 27, 4
        last    0, REST, 4
        last    0, REST, 11
        last    4, 27, 4
        last    0, REST, 4
        last    0, REST, 1
        last    0, REST, 3
        last    0, REST, 1
        last    0, REST, 2
        last    0, REST, 2
        last    0, REST, 2
        note    1, 79, 14
        note    0, 36, 5
        note    2, 24, 182
        last    3, 31, 20
        last    0, REST, 5
        last    0, REST, 2
        last    0, 43, 6
        last    0, REST, 6
        last    0, REST, 2
        note    0, 43, 168
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 4
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 2
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 4
        last    4, 31, 4
        last    0, REST, 4
        last    0, REST, 26
        last    4, 31, 5
        last    0, REST, 5
        last    0, REST, 2
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 25
        last    4, 31, 3
        last    0, REST, 3
        last    0, REST, 4
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 25
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 36, 15
        last    0, REST, 2
        last    0, REST, 1
        last    0, REST, 12
        last    0, REST, 60
        last    4, 36, 4
        last    0, REST, 4
        last    0, REST, 3
        last    4, 36, 5
        last    0, REST, 5
        last    0, REST, 3
        last    4, 36, 30
        last    0, REST, 1
        last    0, REST, 5
        last    0, REST, 24
        vset    vTicks, 0

speakerSong12Setup:
        vselect 1
        vset    vTranspose, -24
        envelope speakerEnv2
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 40
        vset    vRate, 300
        vselect 2
        vset    vTranspose, -24
        vset    vSpare, 5
        envelope speakerEnv1
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 20
        vset    vRate, 120
        vselect 0
        vset    vTranspose, -24
        envelope speakerEnv3
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 120
        vset    vRate, 228
        vselect 3
        vset    vTranspose, -24
        envelope speakerEnv4
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 120
        vset    vRate, 228
        vset    vTempo, 1
        vret

; Envelopes: entries 0-3 shape the attack, a sustain that runs out jumps to
; entry RELEASE.  An entry after a hold is reached only that way.
speakerEnv1:
        envSet  3
        envHold
        envSet  0
        envHold
        envSet  0
        envHold
speakerEnv2:
        envSet  3
        envRamp 0, 16
        envSet  0
        envHold
        envRamp 0, 30
        envHold
speakerEnv3:
        envSet  3
        envRamp 0, 8
        envSet  0
        envHold
        envRamp 0, 30
        envHold
speakerEnv4:
        envSet  3
        envRamp 0, 20
        envSet  0
        envHold
        envRamp 0, 30
        envHold

tandySong10v2:
        vset    vPeriod, 3000
        vset    vTicks, 28
        vset    vPeriod, 16000
        vset    vSlide, -25
        vset    vTicks, 400
        vset    vTicks, 0

tandySong10v3:
        vset    vPeriod, 448
        vset    vLevel, 60000
        vset    vTicks, 28
        vset    vLevel, 50000
        vset    vLevelSlide, -100
        vset    vTicks, 400
        vset    vLevel, 0
        vset    vTicks, 0

tandySong8:
        vset    vPeriod, 256
        vset    vLevel, 30000
        vset    vLevelSlide, 1000
        vset    vTicks, 20
        vset    vLevelSlide, -1000
        vset    vTicks, 40
        vset    vLevel, 0
        vset    vTicks, 0

tandySong9:
        vset    vPeriod, 384
        vset    vLevel, 60000
        vset    vLevelSlide, -3500
        vset    vTicks, 16
        vset    vLevel, 0
        vset    vTicks, 0

tandySong7v1:
        vset    vTicks, 4

tandySong7v0:
        vset    vLevel, 60000
        vset    vLevelSlide, -100
        vset    vPeriod, 65000
        vset    vCount1, 30
tandySong7v0Loop:
        vset    vSlide, -630
        vset    vTicks, 12
        vset    vSlide, 630
        vset    vTicks, 8
        vloop   vCount1, tandySong7v0Loop
        vset    vLevel, 0
        vset    vTicks, 0

tandySong6v2:
        vset    vPeriod, 2000
        vset    vSlide, 90
        vset    vTicks, 20
        vset    vTicks, 0

tandySong6v3:
        vset    vPeriod, 448
        vset    vLevel, 60000
        vset    vLevelSlide, -2000
        vset    vTicks, 20
        vset    vLevel, 0
        vset    vTicks, 0

tandySong5:
        vset    vPeriod, 2498
        vset    vLevel, 30000
        vset    vCount1, 12
tandySong5Loop:
        vset    vSlide, -9
        vset    vTicks, 12
        vset    vSlide, 9
        vset    vTicks, 8
        vloop   vCount1, tandySong5Loop
        vset    vLevel, 0
        vset    vTicks, 0

tandySong3v2:
        vset    vTicks, 20

tandySong3v1:
        vset    vTicks, 20

tandySong3v0:
        vset    vPeriod, 39139
        vset    vLevel, 60000
        vset    vLevelSlide, -200
        vset    vSlide, -178
        vset    vTicks, 200
        vset    vLevel, 0
        vset    vTicks, 0

tandySong4v0:
        vset    vLevel, 10000
        vset    vLevelSlide, 500
        vset    vPeriod, 64000
        vset    vSlide, -240
        vset    vTicks, 80
        vset    vLevelSlide, 0
        vset    vCount1, 44
tandySong4v0Loop:
        vset    vSlide, -1200
        vset    vTicks, 2
        vset    vSlide, 1240
        vset    vTicks, 2
        vloop   vCount1, tandySong4v0Loop
        vset    vLevelSlide, -415
        vset    vSlide, 60
        vset    vTicks, 120
        vset    vLevel, 0
        vset    vTicks, 0

tandySong4v2:
        vset    vPeriod, 4400
        vset    vSlide, 11
        vset    vTicks, 188
        vset    vSlide, -11
        vset    vTicks, 188
        vset    vTicks, 0

tandySong4v3:
        vset    vPeriod, 448
        vset    vLevel, 25000
        vset    vLevelSlide, 159
        vset    vTicks, 188
        vset    vLevelSlide, -159
        vset    vTicks, 188
        vset    vLevel, 0
        vset    vTicks, 0

tandySong2:
        vset    vLevelSlide, 2400
        vset    vPeriod, 256
        vset    vTicks, 25
        vset    vLevelSlide, -2400
        vset    vTicks, 25
        vset    vLevel, 0
        vset    vTicks, 0

tandySilence:
        vset    vLevel, 0
        vset    vTicks, 0

tandySong1v0:
        vset    vLevel, 60000
        vset    vLevelSlide, -235
        vset    vPeriod, 8160
        vset    vCount1, 6
tandySong1v0Loop:
        vset    vSlide, 30
        vset    vTicks, 16
        vset    vSlide, -30
        vset    vTicks, 16
        vloop   vCount1, tandySong1v0Loop
        vset    vLevel, 0
        vset    vTicks, 0

tandySong1v1:
        vset    vLevel, 50000
        vset    vLevelSlide, -200
        vset    vPeriod, 16400
        vset    vCount1, 10
tandySong1v1Loop:
        vset    vSlide, 66
        vset    vTicks, 8
        vset    vSlide, -66
        vset    vTicks, 8
        vloop   vCount1, tandySong1v1Loop
        vset    vLevel, 0
        vset    vTicks, 0

tandySong1v2:
        vset    vLevel, 65000
        vset    vLevelSlide, -300
        vset    vPeriod, 14000
        vset    vCount1, 8
tandySong1v2Loop:
        vset    vSlide, 82
        vset    vTicks, 12
        vset    vSlide, -78
        vset    vTicks, 12
        vloop   vCount1, tandySong1v2Loop
        vset    vLevel, 0
        vset    vTicks, 0

tandySong11v0:
        vset    vLevel, 60000
        vset    vLevelSlide, -1200
        vset    vPeriod, 13520
        vset    vTicks, 30
        vset    vLevel, 0
        vset    vTicks, 0

tandySong11v1:
        vset    vLevel, 60000
        vset    vLevelSlide, -1200
        vset    vPeriod, 32800
        vset    vTicks, 30
        vset    vLevel, 0
        vset    vTicks, 0

tandySong11v2:
        vset    vLevel, 60000
        vset    vLevelSlide, -1200
        vset    vPeriod, 6000
        vset    vTicks, 10
        vset    vLevel, 0
        vset    vTicks, 0

tandySong12:                                    ; sets its voices up and ends: it plays nothing
        vcall   tandySong12Setup
        vset    vTicks, 0

tandySong12Setup:
        vselect 1
        vset    vSpare, 12
        vset    vTranspose, -45
        envelope tandyEnv2
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 40
        vset    vRate, 300
        vselect 2
        vset    vSpare, 7
        vset    vTranspose, -45
        envelope tandyEnv1
        wave    sineWave
        vset    vWaveLen, SINE_LEN*16
        vset    vDepth, 22
        vset    vRate, 120
        vselect 0
        vset    vSpare, 7
        vset    vTranspose, -45
        envelope tandyEnv3
        wave    squareWave
        vset    vWaveLen, SQUARE_LEN*16
        vset    vDepth, 200
        vset    vRate, 16
        vset    vTempo, 6
        vret

; Envelopes: entries 0-3 shape the attack, a sustain that runs out jumps to
; entry RELEASE.  An entry after a hold is reached only that way.
tandyEnv1:
        envSet  50000
        envRamp 2500, 4
        envRamp -2000, 6
        envHold
        envSet  48000
        envRamp -8000, 6
        envSet  0
        envHold
tandyEnv2:
        envSet  40000
        envRamp 2500, 8
        envRamp -3000, 5
        envHold
        envSet  45000
        envRamp -4000, 11
        envSet  0
        envHold
tandyEnv3:
        envSet  57000
        envRamp -1500, 6
        envHold
        envHold
        envSet  48000
        envRamp -8000, 6
        envSet  0
        envHold

oldInt8         label   dword                   ; the BIOS timer handler
        db      20h,31h,30h,34h

; ---------------------------------------------------------------------------
; Installing and removing the driver
; procedure InstallSoundTimer;  hooks INT 8 and speeds the timer up
InstallSoundTimer       PROC    FAR
        push    ds
        push    es
        mov     ax, CODE
        mov     ds, ax
        mov     ax, 3508h                       ; get the INT 8 vector
        int     21h
        mov     word ptr cs:oldInt8, bx
        mov     word ptr cs:oldInt8+2, es
        push    ds
        mov     dx, CODE
        mov     ds, dx
        mov     dx, offset soundIsr
        mov     ax, 2508h                       ; set the INT 8 vector
        int     21h
        pop     ds
        mov     al, 0B6h                        ; channel 2: square wave, for the speaker
        out     43h, al
        mov     ax, TIMER_COUNT                 ; channel 0: the faster tick
        out     40h, al
        mov     al, ah
        out     40h, al
        pop     es
        pop     ds
        ret
InstallSoundTimer       ENDP

; procedure UninstallSoundTimer;  gives INT 8 back and silences both devices
UninstallSoundTimer     PROC    FAR
        push    ds
        mov     ax, CODE
        mov     ds, ax
        push    ds
        mov     dx, word ptr cs:oldInt8
        mov     ax, word ptr cs:oldInt8+2
        mov     ds, ax
        mov     ax, 2508h                       ; set the INT 8 vector
        int     21h
        pop     ds
        mov     ax, 0FFFFh                      ; channel 0 back to the BIOS rate, or 1 short
        out     40h, al
        mov     al, ah
        out     40h, al
        in      al, 61h                         ; speaker off
        and     al, 0FCh
        out     61h, al
        mov     al, 9Fh                         ; all four SN76489 channels to
        out     0C0h, al                        ;   full attenuation
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        pop     ds
        ret
UninstallSoundTimer     ENDP

; ---------------------------------------------------------------------------
; The timer interrupt

soundIsr        PROC    FAR
        sti
        push    ax
        push    bx
        push    dx
        push    ds
        push    si
        mov     ax, CODE
        mov     ds, ax
        cmp     TimeoutCtr, 0
        je      @@music
        dec     TimeoutCtr
        jne     @@music
        mov     ah, 0Fh                         ; get the video mode
        int     10h
        mov     ah, 0                           ; and set it again, clearing
        int     10h                             ;   the screen
        mov     bl, 7                           ; (set again below)
        mov     ah, 7Fh
        mov     cx, errorLen
        mov     bx, CODE
        mov     es, bx
        mov     bx, offset errorText
@@unmask:
        mov     al, es:[bx]
        and     al, ah
        mov     es:[bx], al
        inc     bx
        loop    @@unmask
        mov     bl, 7                           ; light gray
        mov     ah, 13h                         ; write string, cursor moves
        mov     al, 1
        mov     bh, 0
        mov     cx, errorLen
        xor     dx, dx                          ; at the top left
        mov     bp, CODE
        mov     es, bp
        mov     bp, offset errorText
        int     10h
        mov     ah, 4Ch                         ; and end the program
        mov     al, 0FFh
        int     21h
@@music:
        cmp     inTick, 0
        jne     @@chain
        mov     inTick, 1
        call    tickSpeaker
        call    tickTandy
        mov     inTick, 0
@@chain:
        dec     tickCount
        jne     @@eoi
        mov     tickCount, BIOS_EVERY
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        jmp     cs:oldInt8                      ; the BIOS acknowledges this one
@@eoi:
        mov     al, 20h
        out     20h, al
        pop     si
        pop     ds
        pop     dx
        pop     bx
        pop     ax
        iret
soundIsr        ENDP

; Steps the speaker bank, then sounds the first of its voices that is both
; playing and not silent.  Its level's low two bits are the speaker gate and
; data bits of port 61h.
tickSpeaker     PROC    NEAR
        mov     bx, currentSong
        cmp     bx, 0
        je      @@out
        mov     speakerVoice, 0
        mov     voicesLeft, VOICES
        mov     si, offset speakerDividers
        mov     bankDividers, si
        mov     si, offset speakerVoices
        mov     bankVoices, si
@@voice:
        cmp     [si].vTicks, 0
        je      @@next
        call    stepVoice
        cmp     speakerVoice, 0
        jne     @@next
        cmp     [si].vLevel, 0
        je      @@next
        cmp     [si].vTicks, 0
        je      @@next
        mov     speakerVoice, si
@@next:
        add     si, SIZE Voice
        dec     voicesLeft
        jne     @@voice
        mov     bl, outputOn
        cmp     bl, 0
        je      @@out
        mov     bx, speakerVoice
        cmp     bx, 0
        je      @@out
        mov     si, bx
        mov     ax, [si].vOutput
        out     42h, al
        mov     al, ah
        out     42h, al
        mov     bx, [si].vLevel
        and     bl, 3
@@out:
        in      al, 61h
        and     al, 0FCh
        or      al, bl
        out     61h, al
        ret
tickSpeaker     ENDP

; Steps the Tandy bank and writes all four voices to the SN76489: channels
; 0-2 take a ten-bit count in two bytes, the noise channel one byte.
tickTandy       PROC    NEAR
        mov     bx, currentSong
        cmp     bx, 0
        je      @@silence
        mov     voicesLeft, VOICES
        mov     si, offset tandyDividers
        mov     bankDividers, si
        mov     si, offset tandyVoices
        mov     bankVoices, si
@@voice:
        cmp     [si].vTicks, 0
        je      @@next
        call    stepVoice
@@next:
        add     si, SIZE Voice
        dec     voicesLeft
        jne     @@voice
        mov     al, outputOn
        cmp     al, 0
        je      @@silence
        mov     voicesLeft, VOICES
        mov     si, offset tandyVoices
        mov     dl, 80h                         ; channel 0, tone register
@@write:
        mov     ax, [si].vOutput
        shr     ax, 1
        shr     ax, 1
        shr     al, 1
        shr     al, 1
        shr     al, 1
        shr     al, 1
        xor     al, dl
        out     0C0h, al
        cmp     dl, 0E0h                        ; the noise channel
        je      @@level
        mov     al, ah
        out     0C0h, al
@@level:
        mov     ax, 0FFFFh                      ; attenuation is level inverted
        sub     ax, [si].vLevel
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        shr     ah, 1
        mov     al, ah
        xor     al, dl
        add     al, 10h                         ; the channel's volume register
        out     0C0h, al
        add     dl, 20h
        add     si, SIZE Voice
        dec     voicesLeft
        jne     @@write
        ret
@@silence:
        mov     al, 9Fh
        out     0C0h, al
        mov     al, 0BFh
        out     0C0h, al
        mov     al, 0DFh
        out     0C0h, al
        mov     al, 0FFh
        out     0C0h, al
        ret
tickTandy       ENDP

; One tick of the voice at SI: slides, vibrato, sustain, the stream when the
; step runs out, and the envelope.
stepVoice       PROC    NEAR
        push    cx
        push    di
        mov     ax, [si].vLevelSlide
        add     [si].vLevel, ax
        mov     ax, [si].vSlide
        add     [si].vPeriod, ax
        sub     dx, dx
        mov     ax, [si].vPhase                 ; phase is 12.4 fixed point
        add     ax, [si].vRate
        je      @@output
        cmp     ax, [si].vWaveLen
        jb      @@phase
        sub     ax, [si].vWaveLen
@@phase:
        mov     [si].vPhase, ax
        mov     cl, 4
        sar     ax, cl
        add     ax, [si].vWave
        mov     di, ax
        mov     ah, [di]
        mov     al, 0
        imul    [si].vDepth                     ; DX = wave sample * depth / 256
@@output:
        add     dx, [si].vPeriod
        mov     [si].vOutput, dx
        cmp     [si].vSustain, 0
        je      @@count
        dec     [si].vSustain
        jne     @@count
        mov     [si].vEnvStep, RELEASE * SIZE EnvStep
        mov     [si].vEnvTicks, 1
@@count:
        dec     [si].vTicks
        jne     @@envelope
        call    readStream
@@envelope:
        cmp     [si].vEnvTicks, 0
        je      @@done
        dec     [si].vEnvTicks
        jne     @@done
@@envStep:
        mov     bx, [si].vEnvelope
        add     bx, [si].vEnvStep
        cmp     [bx].esTicks, -1
        jne     @@ramp
        mov     ax, [bx].esValue                ; a level to set
        mov     [si].vLevel, ax
        cmp     ax, 0
        jne     @@setDone
        mov     [si].vLevelSlide, ax
@@setDone:
        add     [si].vEnvStep, SIZE EnvStep
        jmp     @@envStep
@@ramp:
        mov     ax, [bx].esValue                ; a slide, and how long
        mov     [si].vLevelSlide, ax
        mov     ax, [bx].esTicks
        mov     [si].vEnvTicks, ax
        add     [si].vEnvStep, SIZE EnvStep
@@done:
        pop     di
        pop     cx
        ret
stepVoice       ENDP

; Reads the stream of the voice at SI up to the end of its next step.  The
; command handlers are reached through cmdTable.
readStream      PROC    NEAR
        mov     di, [si].vStream
        cmp     di, 0
        jne     @@read
        ret
@@read:
        mov     streamVoice, si
nextByte:
        mov     bl, [di]
        inc     di
        cmp     bl, FIRST_CMD
        jae     @@command
        jmp     playEvent
@@command:
        sub     bh, bh
        sub     bl, FIRST_CMD
        add     bl, bl
        jmp     cmdTable[bx]

cmdLoop:                                        ; 0FEh counter, target
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        add     di, 2
        cmp     word ptr [bx+si], 0
        je      @@jump
        dec     word ptr [bx+si]
        je      nextByte
@@jump:
        mov     di, ax
        jmp     nextByte

cmdSelect:                                      ; 0FDh voice offset
        mov     si, [di]
        add     di, 2
        add     si, bankVoices
cmdClear:                                       ; 0FAh
        sub     bx, bx
        mov     [si].vPeriod, bx
        mov     [si].vSlide, bx
        mov     [si].vOutput, bx
        mov     [si].vLevel, bx
        mov     [si].vLevelSlide, bx
        mov     [si].vSpare, bx
        mov     [si].vTranspose, bx
        mov     [si].vEnvelope, bx
        mov     [si].vEnvStep, bx
        mov     [si].vEnvTicks, bx
        mov     [si].vWave, bx
        mov     [si].vPhase, bx
        mov     [si].vRate, bx
        mov     [si].vDepth, bx
        mov     [si].vWaveLen, bx
        jmp     nextByte

cmdSet:                                         ; 0FFh field, value
        mov     bl, [di]
        inc     di
        mov     bh, 0
        mov     ax, [di]
        inc     di
        inc     di
        mov     [bx+si], ax
        cmp     bl, 0                           ; vTicks: the step is set
        jne     nextByte
endStep:
        mov     si, streamVoice
        cmp     [si].vTicks, 0
        jne     @@save
        mov     bl, VOICES                      ; the stream has ended
        sub     bl, voicesLeft
        sub     bh, bh
        mov     voiceSong[bx], 0
        mov     di, 0
@@save:
        mov     [si].vStream, di
        ret

cmdReturn:                                      ; 0FBh
        mov     di, streamReturn
        jmp     nextByte

cmdCall:                                        ; 0FCh target
        mov     ax, [di]
        add     di, 2
        mov     streamReturn, di
        mov     di, ax
        jmp     nextByte

nextEvent:
        mov     bl, [di]
        inc     di
playEvent:
        push    di
        mov     al, bl
        mov     cl, 5
        shr     al, cl
        mov     cl, al                          ; the event's voice
        mul     voiceSize
        add     ax, bankVoices
        mov     di, ax
        pop     bx
        push    bx
        mov     ax, [si].vTempo
        cmp     al, 1
        ja      @@scaled
        xor     ah, ah
        mov     al, [bx+1]
        jmp     short @@length
@@scaled:
        mul     byte ptr [bx+1]
@@length:
        mov     [si].vTicks, ax
        mov     al, [bx]
        and     ax, 7Fh
        cmp     ax, REST
        je      @@next
        cmp     cl, 0                           ; only voice 0 takes a pitch
        ja      @@next
        mov     cx, [si].vTicks
        mov     [di].vTicks, cx
        mov     [di].vSustain, cx
        add     ax, [di].vTranspose
        mov     [di].vEnvStep, 0
        mov     [di].vEnvTicks, 1
        mov     cx, 0FFh
@@octave:
        inc     cl
        sub     ax, 12
        jae     @@octave
        add     ax, 12
        mov     bx, ax
        add     bx, bx
        cmp     di, offset tandyVoices + 3 * SIZE Voice
        jne     @@divider                       ; either way
@@divider:
        add     bx, bankDividers
        mov     ax, [bx]
        shr     ax, cl
        mov     [di].vPeriod, ax
        mov     [di].vOutput, ax
@@next:
        pop     di
        mov     al, [di]
        inc     di
        inc     di
        and     al, 80h                         ; the last event of the step?
        jne     @@stepEnds
        jmp     nextEvent
@@stepEnds:
        jmp     endStep
readStream      ENDP

; ---------------------------------------------------------------------------
; The Pascal entry points.  Each takes one word.

song            =       6                       ; ProgramTandyVoices/B's argument
onOff           =       6                       ; SetVoiceByte's argument

; procedure ProgramSpeakerVoices(song: Word);  starts a song on the speaker bank
ProgramSpeakerVoices     PROC    FAR
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+song]
        mov     currentSong, si
        add     si, si
        add     si, si
        add     si, si                          ; eight bytes a song
        mov     inTick, 1                       ; keep the ISR out
        mov     voicesLeft, VOICES
        mov     di, offset speakerVoices
@@voice:
        mov     ax, speakerSongs[si]
        cmp     ax, 0
        je      @@next
        mov     bx, SIZE Voice - 2
@@clear:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     @@clear
        mov     [di].vStream, ax
        mov     bl, VOICES
        sub     bl, voicesLeft
        sub     bh, bh
        mov     ax, currentSong
        mov     voiceSong[bx], al
        mov     [di].vTicks, 1
@@next:
        add     di, SIZE Voice
        add     si, 2
        dec     voicesLeft
        jne     @@voice
        mov     inTick, 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        ret     2
ProgramSpeakerVoices     ENDP

; procedure ProgramTandyVoices(song: Word);  starts a song on the Tandy bank
ProgramTandyVoices     PROC    FAR
        push    bp
        mov     bp, sp
        push    ax
        push    bx
        push    di
        push    si
        push    ds
        mov     si, CODE
        mov     ds, si
        mov     si, [bp+song]
        mov     currentSong, si
        add     si, si
        add     si, si
        add     si, si
        mov     inTick, 1
        mov     voicesLeft, VOICES
        mov     di, offset tandyVoices
@@voice:
        mov     ax, tandySongs[si]
        cmp     ax, 0
        je      @@next
        mov     bx, SIZE Voice - 2
@@clear:
        mov     word ptr [bx+di], 0
        sub     bx, 2
        jge     @@clear
        mov     [di].vStream, ax
        mov     bl, VOICES
        sub     bl, voicesLeft
        sub     bh, bh
        mov     ax, currentSong
        mov     voiceSong[bx], al
        mov     [di].vTicks, 1
@@next:
        add     di, SIZE Voice
        add     si, 2
        dec     voicesLeft
        jne     @@voice
        mov     inTick, 0
        pop     ds
        pop     si
        pop     di
        pop     bx
        pop     ax
        pop     bp
        ret     2
ProgramTandyVoices     ENDP

; procedure SetVoiceByte(onOff: Word);  zero mutes both devices
SetVoiceByte    PROC    FAR
        push    bp
        mov     bp, sp
        push    ax
        push    ds
        mov     ax, CODE
        mov     ds, ax
        mov     ax, [bp+onOff]
        mov     outputOn, al
        pop     ds
        pop     ax
        pop     bp
        ret     2
SetVoiceByte    ENDP

CODE    ENDS
        END
