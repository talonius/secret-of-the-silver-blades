; coreinp.asm -- FillWord, linked into the GameIo unit with {$L COREINP.OBJ}.
;
; procedure FillWord(var dest; count: Word);
;
; Clears count BYTES at dest, a word at a time.  Despite the name there is no
; fill value: it always writes zero.

CODE    SEGMENT BYTE PUBLIC             ; no 'CODE' class -> {$L} merges into the unit seg
        ASSUME  CS:CODE
        PUBLIC  FILLWORD

FILLWORD        PROC FAR
        mov     bx,sp                   ; no frame: args off SP
        les     di,ss:[bx+6]            ; dest
        mov     cx,ss:[bx+4]            ; count, in bytes
        xor     ax,ax
        cld
        shr     cx,1
        jnc     dowords
        stosb                           ; the odd byte
        jcxz    done
dowords:
        rep     stosw
done:
        ret     6
FILLWORD        ENDP

CODE    ENDS
        END
