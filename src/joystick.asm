; Game-port sampler linked into the Joystick unit through {$L JOYSTICK.OBJ}.
; ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean.
; Normally counts X/Y discharge polls; buttons holds four pressed=1 bits in its low nibble.
; AL returns False for an invalid selector or a polling timeout; outputs may be partial.
; Pascal far-call ABI: three far var pointers and a word-sized Byte argument.
; BP and DS survive; AX, BX, CX, DX, DI, ES and flags are scratch.

joy             =       12h             ; selector in the low byte of a stack word
xRawPtr         =       0Eh             ; far pointer to xRaw: Word
yRawPtr         =       0Ah             ; far pointer to yRaw: Word
buttonsPtr      =       06h             ; far pointer to buttons: Byte

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE
        PUBLIC  READJOYSTICK

READJOYSTICK    PROC FAR
        push    bp
        mov     bp,sp                   ; BP operands use SS, the caller stack
        cmp     byte ptr [bp+joy],1     ; joy must be 1 or 2
        jz      valid
        cmp     byte ptr [bp+joy],2
        jz      valid
        mov     al,0                    ; bad joy -> False
        pop     bp
        ret     0Eh                     ; remove 14 argument bytes on far return
valid:
        mov     ah,1                    ; X-axis bit (joy 1: bit 0; joy 2: bit 2)
        xor     bx,bx
        cmp     byte ptr [bp+joy],2
        jnz     m_set
        shl     ah,1
        shl     ah,1
m_set:
        mov     bx,1                    ; count includes the first poll
        xor     cx,cx                   ; zero gives LOOP a 65536-poll limit
        mov     al,0FFh
        mov     dx,201h                 ; PC game port
        out     dx,al                   ; fire the one-shots
xLoop:
        in      al,dx
        not     al                      ; expired axes and pressed buttons become set bits
        test    al,ah
        jnz     xDone
        inc     bx
        loop    xLoop
        mov     al,0                    ; X axis timed out -> False
        pop     bp
        ret     0Eh
xDone:
        mov     cx,1FFFh                ; delay budget, reduced by the poll count
        sub     cx,bx
        jc      xStore                  ; over budget: skip the delay
        loop    $                       ; a zero remainder wraps to 65536 iterations
xStore:
        les     di,[bp+xRawPtr]          ; ES:DI addresses the caller's output
        mov     es:[di],bx              ; store the count in xRaw
        shl     ah,1                    ; shift mask left; normal path selects Y
        xor     cx,cx
yLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     yPre                    ; selected bit is clear; retrigger
        loop    yLoop
        mov     al,0
        pop     bp
        ret     0Eh
yPre:
        mov     bx,1
        xor     cx,cx
        mov     al,0FFh
        out     dx,al                   ; retrigger for a separate count
yLoop2:
        in      al,dx
        not     al
        test    al,ah
        jnz     yDone
        inc     bx
        loop    yLoop2
        mov     al,0
        pop     bp
        ret     0Eh
yDone:
        mov     cx,1FFFh
        sub     cx,bx
        jc      xStore                  ; Note: over budget, this count overwrites xRaw and the mask shifts again
        loop    $
        les     di,[bp+yRawPtr]
        mov     es:[di],bx              ; store the count in yRaw
        shr     ah,1                    ; previous mask bit (normally X)
        xor     cx,cx
bLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     bDone                   ; accept the sample when the selected bit is clear
        loop    bLoop
        mov     al,0
        pop     bp
        ret     0Eh
bDone:
        mov     cx,4
        shr     al,cl                   ; port bits 4..7: both joysticks' buttons
        les     di,[bp+buttonsPtr]
        mov     es:[di],al              ; store the button bits
        mov     al,1                    ; success
        pop     bp
        ret     0Eh
READJOYSTICK    ENDP
CODE    ENDS
        END
