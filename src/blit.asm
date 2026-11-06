; blit.asm -- the Blit unit's inner loops, linked in with {$L BLIT.OBJ}.
;
; Nine near procedures draw one tile of a graphics set into a view buffer, one per display mode and kind.  The six cell
; impls draw a whole tile inside the buffer and return with ret 0Eh: BLITCELLCGA and BLITCELLCGAMASKED for CGA,
; BLITCELLEGA and BLITCELLEGAMASKED for EGA, BLITCELLTANDY and BLITCELLTANDYMASKED for Tandy.  The three clipped ones,
; BLITCLIPPEDCGA, BLITCLIPPEDEGA and BLITCLIPPEDTANDY, clip the tile to the buffer edges and return with ret 14h.
;
; BLITCELLCGA, BLITCELLEGA and BLITCELLTANDY copy the tile; BLITCELLCGAMASKED, BLITCELLEGAMASKED and BLITCELLTANDYMASKED
; blend it through the set's transparency plane.  A clipped impl does either, as clipFlags says.  Whatever is drawn goes
; through SPANCOPY or SPANMASK, which draw the rows and record each one in the span tables that FlushView later commits
; to the screen.

        LOCALS

IMGBUF  STRUC                           ; Blit's TImgBuf
ibHeight        dw      ?
ibWidth         dw      ?               ; in character cells
ibUnk4          dw      ?
ibUnk6          dw      ?
ibCount         db      ?
ibMap           db      8 dup (?)
ibImgSize       dw      ?
ibTransp        dd      ?               ; transparency plane, or nil
ibData          db      ?
IMGBUF  ENDS

; Arguments.  Every impl is called near.
dest            =       4               ; far ptr to the view buffer drawn into
gfx             =       8               ; far ptr to the graphics set
cellTile        =       0Ch             ; cell impls: tile index (byte)
cellY           =       0Eh             ;   character row
cellX           =       10h             ;   character column
clipFlags       =       0Ch             ; clipped impls: bit 0 blend, bit 2 save
clipTile        =       0Eh             ;   tile index (byte)
clipY           =       10h             ;   character row, may be negative
clipX           =       12h             ;   character column, may be negative
saveBuf         =       14h             ;   far ptr, gets the bytes a blend covers

; Locals, shared by the nine impls and read by the two span helpers.
maskPtr         =       -4              ; far ptr to the set's transparency plane
spanCol         =       -6              ; byte column recorded in spanY
slot            =       -8              ; first pixel row = first span-table slot
rows            =       -0Ah
destOfs         =       -0Ch
srcOfs          =       -0Eh
rowBytes        =       -10h
rightPad        =       -12h            ; buffer bytes right of the tile, per row
leftPad         =       -14h            ; buffer bytes left of the tile, per row
srcSkipR        =       -16h            ; tile bytes clipped off the right
srcSkipL        =       -18h            ; tile bytes clipped off the left
saveFlag        =       -1Ah            ; byte: copy covered bytes to saveBuf
saveOfs         =       -1Ch

DGROUP  GROUP   DATA
DATA    SEGMENT WORD PUBLIC
        EXTRN   spanActive:BYTE, spanY:WORD, spanX0:WORD, spanX1:WORD
DATA    ENDS

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE, DS:DGROUP
        PUBLIC  BLITCELLCGA, BLITCELLCGAMASKED, BLITCLIPPEDCGA, BLITCELLEGA, BLITCELLEGAMASKED, BLITCLIPPEDEGA
        PUBLIC  BLITCELLTANDY, BLITCELLTANDYMASKED, BLITCLIPPEDTANDY

; CGA cell, copied
BLITCELLCGA  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        shl     word ptr [bp+spanCol], 1
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLCGA  ENDP

; CGA cell, blended
BLITCELLCGAMASKED  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        shl     word ptr [bp+spanCol], 1
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        mov     ax, word ptr es:[di].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr es:[di].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLCGAMASKED  ENDP

; CGA, clipped
BLITCLIPPEDCGA  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si, [bp+gfx]
        les     di, [bp+dest]
        mov     ax, word ptr [si].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr [si].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        mov     ax, word ptr [bp+clipX]
        cmp     ax, 8000h
        jbe     @@leftInside
        mov     word ptr [bp+srcSkipL], ax
        neg     word ptr [bp+srcSkipL]
        mov     word ptr [bp+leftPad], 0
        jmp     @@clipRight
@@leftInside:
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+leftPad], ax
@@clipRight:
        add     ax, word ptr [si].ibWidth
        cmp     word ptr es:[di].ibWidth, ax
        jae     @@fitsRight
        sub     ax, word ptr es:[di].ibWidth
        mov     word ptr [bp+srcSkipR], ax
        mov     word ptr [bp+rightPad], 0
        jmp     @@clipY
@@fitsRight:
        mov     word ptr [bp+srcSkipR], 0
        mov     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+clipX]
        sub     ax, word ptr [si].ibWidth
        mov     word ptr [bp+rightPad], ax
@@clipY:
        mov     ax, word ptr [bp+clipY]
        cmp     ax, 8000h
        jbe     @@topInside
        neg     ax
        mov     cx, 3
        shl     ax, cl
        mov     bx, word ptr [si].ibHeight
        mov     word ptr [bp+rows], bx
        sub     word ptr [bp+rows], ax
        mov     bx, word ptr [si].ibWidth
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        mov     word ptr [bp+destOfs], 0
        mov     word ptr [bp+slot], 0
        jmp     @@clipDone
@@topInside:
        mov     word ptr [bp+srcOfs], 0
        mov     cx, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+slot]
        add     ax, word ptr [si].ibHeight
        cmp     ax, word ptr es:[di].ibHeight
        jbe     @@fitsBelow
        mov     ax, word ptr es:[di].ibHeight
        sub     ax, word ptr [bp+slot]
        mov     word ptr [bp+rows], ax
        jmp     @@clipDone
@@fitsBelow:
        mov     ax, word ptr [si].ibHeight
        mov     word ptr [bp+rows], ax
@@clipDone:
        mov     ax, word ptr [si].ibWidth
        cmp     ax, word ptr [bp+srcSkipL]
        jb      @@offscreen
        cmp     ax, word ptr [bp+srcSkipR]
        jb      @@offscreen
        mov     ax, word ptr [bp+srcOfs]
        cmp     ax, word ptr [si].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+destOfs]
        cmp     ax, word ptr es:[di].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+rows]
        cmp     ax, word ptr [si].ibHeight
        ja      @@offscreen
        jmp     @@visible
@@offscreen:
        pop     ds
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@visible:
        mov     ax, word ptr [bp+leftPad]
        shl     ax, 1
        mov     word ptr [bp+leftPad], ax
        mov     word ptr [bp+spanCol], ax
        mov     ax, word ptr [si].ibWidth
        sub     ax, word ptr [bp+srcSkipL]
        sub     ax, word ptr [bp+srcSkipR]
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        shl     word ptr [bp+srcSkipL], 1
        shl     word ptr [bp+srcSkipR], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+srcOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     ax, word ptr [bp+srcOfs]
        mov     word ptr [bp+saveOfs], ax
        mov     ax, word ptr [si].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+clipTile]
        mul     bx
        add     word ptr [bp+srcOfs], ax
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        pop     ds
        test    byte ptr [bp+clipFlags], 1
        jne     @@blended
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@blended:
        mov     byte ptr [bp+saveFlag], 0
        test    byte ptr [bp+clipFlags], 4
        je      @@doBlend
        mov     byte ptr [bp+saveFlag], 1
@@doBlend:
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
BLITCLIPPEDCGA  ENDP

; EGA cell, copied
BLITCELLEGA  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLEGA  ENDP

; EGA cell, blended
BLITCELLEGAMASKED  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        mov     ax, word ptr es:[di].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr es:[di].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLEGAMASKED  ENDP

; EGA, clipped
BLITCLIPPEDEGA  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si, [bp+gfx]
        les     di, [bp+dest]
        mov     ax, word ptr [si].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr [si].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        mov     ax, word ptr [bp+clipX]
        cmp     ax, 8000h
        jbe     @@leftInside
        mov     word ptr [bp+srcSkipL], ax
        neg     word ptr [bp+srcSkipL]
        mov     word ptr [bp+leftPad], 0
        jmp     @@clipRight
@@leftInside:
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+leftPad], ax
@@clipRight:
        add     ax, word ptr [si].ibWidth
        cmp     word ptr es:[di].ibWidth, ax
        jae     @@fitsRight
        sub     ax, word ptr es:[di].ibWidth
        mov     word ptr [bp+srcSkipR], ax
        mov     word ptr [bp+rightPad], 0
        jmp     @@clipY
@@fitsRight:
        mov     word ptr [bp+srcSkipR], 0
        mov     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+clipX]
        sub     ax, word ptr [si].ibWidth
        mov     word ptr [bp+rightPad], ax
@@clipY:
        mov     ax, word ptr [bp+clipY]
        cmp     ax, 8000h
        jbe     @@topInside
        neg     ax
        mov     cx, 3
        shl     ax, cl
        mov     bx, word ptr [si].ibHeight
        mov     word ptr [bp+rows], bx
        sub     word ptr [bp+rows], ax
        mov     bx, word ptr [si].ibWidth
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        mov     word ptr [bp+destOfs], 0
        mov     word ptr [bp+slot], 0
        jmp     @@clipDone
@@topInside:
        mov     word ptr [bp+srcOfs], 0
        mov     cx, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+slot]
        add     ax, word ptr [si].ibHeight
        cmp     ax, word ptr es:[di].ibHeight
        jbe     @@fitsBelow
        mov     ax, word ptr es:[di].ibHeight
        sub     ax, word ptr [bp+slot]
        mov     word ptr [bp+rows], ax
        jmp     @@clipDone
@@fitsBelow:
        mov     ax, word ptr [si].ibHeight
        mov     word ptr [bp+rows], ax
@@clipDone:
        mov     ax, word ptr [si].ibWidth
        cmp     ax, word ptr [bp+srcSkipL]
        jb      @@offscreen
        cmp     ax, word ptr [bp+srcSkipR]
        jb      @@offscreen
        mov     ax, word ptr [bp+srcOfs]
        cmp     ax, word ptr [si].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+destOfs]
        cmp     ax, word ptr es:[di].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+rows]
        cmp     ax, word ptr [si].ibHeight
        ja      @@offscreen
        jmp     @@visible
@@offscreen:
        pop     ds
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@visible:
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        mov     ax, word ptr [bp+leftPad]
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr [si].ibWidth
        sub     ax, word ptr [bp+srcSkipL]
        sub     ax, word ptr [bp+srcSkipR]
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        shl     word ptr [bp+srcSkipL], 1
        shl     word ptr [bp+srcSkipL], 1
        shl     word ptr [bp+srcSkipR], 1
        shl     word ptr [bp+srcSkipR], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+srcOfs], 1
        shl     word ptr [bp+srcOfs], 1
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     ax, word ptr [bp+srcOfs]
        mov     word ptr [bp+saveOfs], ax
        mov     ax, word ptr [si].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+clipTile]
        mul     bx
        add     word ptr [bp+srcOfs], ax
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        pop     ds
        test    byte ptr [bp+clipFlags], 1
        jne     @@blended
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@blended:
        mov     byte ptr [bp+saveFlag], 0
        test    byte ptr [bp+clipFlags], 4
        je      @@doBlend
        mov     byte ptr [bp+saveFlag], 1
@@doBlend:
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
BLITCLIPPEDEGA  ENDP

; Tandy cell, copied
BLITCELLTANDY  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        shl     word ptr [bp+spanCol], 1
        shl     word ptr [bp+spanCol], 1
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLTANDY  ENDP

; Tandy cell, blended
BLITCELLTANDYMASKED  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        les     di, [bp+dest]
        mov     ax, word ptr [bp+cellY]
        mov     cl, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+cellX]
        mov     word ptr [bp+leftPad], ax
        mov     ax, word ptr es:[di].ibWidth
        les     di, [bp+gfx]
        sub     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+cellX]
        mov     word ptr [bp+rightPad], ax
        mov     ax, word ptr [bp+leftPad]
        mov     word ptr [bp+spanCol], ax
        shl     word ptr [bp+spanCol], 1
        shl     word ptr [bp+spanCol], 1
        mov     ax, word ptr es:[di].ibWidth
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        mov     ax, word ptr es:[di].ibHeight
        mov     word ptr [bp+rows], ax
        mov     ax, word ptr es:[di].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr es:[di].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+leftPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        mov     ax, word ptr es:[di].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+cellTile]
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+srcSkipR], 0
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     0Eh
BLITCELLTANDYMASKED  ENDP

; Tandy, clipped
BLITCLIPPEDTANDY  PROC    NEAR
        push    bp
        mov     bp, sp
        sub     sp, 1Ch
        sub     sp, 1Ch
        push    ss
        push    ds
        cld
        push    ds
        lds     si, [bp+gfx]
        les     di, [bp+dest]
        mov     ax, word ptr [si].ibTransp
        mov     word ptr [bp+maskPtr], ax
        mov     ax, word ptr [si].ibTransp+2
        mov     word ptr [bp+maskPtr+2], ax
        mov     ax, word ptr [bp+clipX]
        cmp     ax, 8000h
        jbe     @@leftInside
        mov     word ptr [bp+srcSkipL], ax
        neg     word ptr [bp+srcSkipL]
        mov     word ptr [bp+leftPad], 0
        jmp     @@clipRight
@@leftInside:
        mov     word ptr [bp+srcSkipL], 0
        mov     word ptr [bp+leftPad], ax
@@clipRight:
        add     ax, word ptr [si].ibWidth
        cmp     word ptr es:[di].ibWidth, ax
        jae     @@fitsRight
        sub     ax, word ptr es:[di].ibWidth
        mov     word ptr [bp+srcSkipR], ax
        mov     word ptr [bp+rightPad], 0
        jmp     @@clipY
@@fitsRight:
        mov     word ptr [bp+srcSkipR], 0
        mov     ax, word ptr es:[di].ibWidth
        sub     ax, word ptr [bp+clipX]
        sub     ax, word ptr [si].ibWidth
        mov     word ptr [bp+rightPad], ax
@@clipY:
        mov     ax, word ptr [bp+clipY]
        cmp     ax, 8000h
        jbe     @@topInside
        neg     ax
        mov     cx, 3
        shl     ax, cl
        mov     bx, word ptr [si].ibHeight
        mov     word ptr [bp+rows], bx
        sub     word ptr [bp+rows], ax
        mov     bx, word ptr [si].ibWidth
        mul     bx
        mov     word ptr [bp+srcOfs], ax
        mov     word ptr [bp+destOfs], 0
        mov     word ptr [bp+slot], 0
        jmp     @@clipDone
@@topInside:
        mov     word ptr [bp+srcOfs], 0
        mov     cx, 3
        shl     ax, cl
        mov     word ptr [bp+slot], ax
        mov     bx, word ptr es:[di].ibWidth
        mul     bx
        mov     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+slot]
        add     ax, word ptr [si].ibHeight
        cmp     ax, word ptr es:[di].ibHeight
        jbe     @@fitsBelow
        mov     ax, word ptr es:[di].ibHeight
        sub     ax, word ptr [bp+slot]
        mov     word ptr [bp+rows], ax
        jmp     @@clipDone
@@fitsBelow:
        mov     ax, word ptr [si].ibHeight
        mov     word ptr [bp+rows], ax
@@clipDone:
        mov     ax, word ptr [si].ibWidth
        cmp     ax, word ptr [bp+srcSkipL]
        jb      @@offscreen
        cmp     ax, word ptr [bp+srcSkipR]
        jb      @@offscreen
        mov     ax, word ptr [bp+srcOfs]
        cmp     ax, word ptr [si].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+destOfs]
        cmp     ax, word ptr es:[di].ibImgSize
        ja      @@offscreen
        mov     ax, word ptr [bp+rows]
        cmp     ax, word ptr [si].ibHeight
        ja      @@offscreen
        jmp     @@visible
@@offscreen:
        pop     ds
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@visible:
        mov     ax, word ptr [bp+leftPad]
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+leftPad], ax
        mov     word ptr [bp+spanCol], ax
        mov     ax, word ptr [si].ibWidth
        sub     ax, word ptr [bp+srcSkipL]
        sub     ax, word ptr [bp+srcSkipR]
        shl     ax, 1
        shl     ax, 1
        mov     word ptr [bp+rowBytes], ax
        shl     word ptr [bp+srcSkipL], 1
        shl     word ptr [bp+srcSkipL], 1
        shl     word ptr [bp+srcSkipR], 1
        shl     word ptr [bp+srcSkipR], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+rightPad], 1
        shl     word ptr [bp+srcOfs], 1
        shl     word ptr [bp+srcOfs], 1
        shl     word ptr [bp+destOfs], 1
        shl     word ptr [bp+destOfs], 1
        mov     ax, word ptr [bp+srcOfs]
        mov     word ptr [bp+saveOfs], ax
        mov     ax, word ptr [si].ibImgSize
        xor     bx, bx
        mov     bl, byte ptr [bp+clipTile]
        mul     bx
        add     word ptr [bp+srcOfs], ax
        mov     bx, word ptr [bp+slot]
        mov     cx, word ptr [bp+rows]
        mov     byte ptr [bp+saveFlag], 0
        pop     ds
        test    byte ptr [bp+clipFlags], 1
        jne     @@blended
        call    SPANCOPY
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
@@blended:
        mov     byte ptr [bp+saveFlag], 0
        test    byte ptr [bp+clipFlags], 4
        je      @@doBlend
        mov     byte ptr [bp+saveFlag], 1
@@doBlend:
        call    SPANMASK
        pop     ds
        pop     ss
        mov     sp, bp
        pop     bp
        ret     14h
BLITCLIPPEDTANDY  ENDP

; Copy rows tile -> buffer.  In: bx = first slot, cx = row count.  Note: it
; never steps over srcSkipL/srcSkipR as SPANMASK does, so a copy clipped at the
; side reads its source rows from the wrong column.
SPANCOPY PROC    NEAR
        mov     spanActive[bx], 1
        shl     bx, 1
        mov     ax, word ptr [bp+leftPad]
        add     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+destOfs]
        cmp     ax, spanX0[bx]
        ja      @@copyRow
        mov     spanX0[bx], ax
        mov     ax, word ptr [bp+spanCol]
        mov     spanY[bx], ax
@@copyRow:
        push    ds
        lds     si, [bp+gfx]
        les     di, [bp+dest]
        add     si, ibData
        add     si, word ptr [bp+srcOfs]
        add     di, ibData
        add     di, word ptr [bp+destOfs]
        push    cx
        mov     cx, word ptr [bp+rowBytes]
        rep movsb
        pop     cx
        pop     ds
        mov     ax, word ptr [bp+rowBytes]
        add     word ptr [bp+srcOfs], ax
        add     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+destOfs]
        dec     ax
        cmp     ax, spanX1[bx]
        jb      @@nextRow
        mov     spanX1[bx], ax
@@nextRow:
        mov     ax, word ptr [bp+rightPad]
        add     word ptr [bp+destOfs], ax
        shr     bx, 1
        inc     bx
        loop    SPANCOPY
        ret
SPANCOPY ENDP

; Blend rows tile -> buffer through the transparency plane.  Same inputs.
SPANMASK PROC    NEAR
        mov     spanActive[bx], 1
        shl     bx, 1
        mov     ax, word ptr [bp+srcSkipL]
        add     word ptr [bp+srcOfs], ax
        mov     ax, word ptr [bp+leftPad]
        add     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+destOfs]
        cmp     ax, spanX0[bx]
        jae     @@blendRow
        mov     spanX0[bx], ax
        mov     ax, word ptr [bp+spanCol]
        mov     spanY[bx], ax
@@blendRow:
        push    ds
        les     di, [bp+dest]
        add     di, word ptr [bp+destOfs]
        push    cx
        mov     cx, word ptr [bp+rowBytes]
@@nextByte:
        cmp     byte ptr [bp+saveFlag], 0
        je      @@noSave
        lds     si, [bp+saveBuf]
        add     si, word ptr [bp+saveOfs]
        mov     al, byte ptr es:[di].ibData
        mov     byte ptr [si].ibData, al
@@noSave:
        lds     si, [bp+maskPtr]
        add     si, word ptr [bp+srcOfs]
        mov     ah, byte ptr [si]
        lds     si, [bp+gfx]
        add     si, word ptr [bp+srcOfs]
        mov     al, byte ptr [si].ibData
        and     byte ptr es:[di].ibData, ah
        or      byte ptr es:[di].ibData, al
        inc     word ptr [bp+srcOfs]
        inc     word ptr [bp+saveOfs]
        inc     word ptr [bp+destOfs]
        inc     di
        loop    @@nextByte
        pop     cx
        pop     ds
        mov     ax, word ptr [bp+destOfs]
        dec     ax
        cmp     ax, spanX1[bx]
        jbe     @@nextRow
        mov     spanX1[bx], ax
@@nextRow:
        mov     ax, word ptr [bp+rightPad]
        add     word ptr [bp+destOfs], ax
        mov     ax, word ptr [bp+srcSkipR]
        add     word ptr [bp+srcOfs], ax
        add     word ptr [bp+saveOfs], ax
        shr     bx, 1
        inc     bx
        dec     cx
        je      @@done
        jmp     SPANMASK
@@done:
        ret
SPANMASK ENDP

CODE    ENDS
        END
