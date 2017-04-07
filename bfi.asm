                output  bfi.o

                org     0x1000


MACRO exos n
        rst   030h
        defb  n
ENDM

VID_CH:         equ     70h
KEY_CH:         equ     105
dataPtr:        equ     8000h
insPtr:         equ     4000h
ARRAY_SIZE:     equ     4000h
opCodeTable:    equ     ((HIGH MainLoop) + 1) * 256

        ld   ix, MainLoop
        call DeCompress         ; at return: A = 0
        call ClearDataArray     ; at return: DE = dataPtr
        ld   h, HIGH MainLoop
        ld   bc, insPtr - 1

        ; disable interrupts
        ld   a, 0xc9
        ld   (0x38), a

        ; skip "push bc"
        ; equivalent to "jr MainLoop", but one byte shorter
        db   0x3e       ; ld a, ...

noJumpFw:
        push bc
        ; falls to MainLoop

MainLoop:
; BC = BrainFuck Instruction Counter
; DE = pointer to BrainFuck data memory
        inc  bc
ML2:    ld   a, (bc)
        inc  h                      ;  4
        ld   l, a                   ;  4
        ld   l, (hl)                ;  7
        dec  h                      ;  4
        jp   (hl)                   ;  4
                                    ; --
                                    ; 23

;MainLoop:
; BC = BrainFuck Instruction Counter

;        inc  bc
;ML2:    ld   a, (bc)
;        cp   ">"               ; 7
;        jr   z, OpIncDataPtr   ; 12 / 7
;        cp   "<"
;        jr   z, OpDecDataPtr
;        cp   "["
;        jr   z, OpJmpForward
;        cp   "]"
;        jr   z, OpJmpBack
;        cp   "+"
;        jr   z, OpIncByte
;        cp   ","
;        jr   z, OpInChar
;        cp   "-"
;        jr   z, OpDecByte
;        cp   "."
;        jr   z, OpOutChar
;        or   a
;        ret  z
;        jp   MainLoop

; ===============================================

retu:   ld   a, 0xf5
        ld   (0x38), a
        ret

OpIncDataPtr:
        inc  de
        jp   (ix)

OpDecDataPtr:
        dec  de
        jp   (ix)

OpIncByte:
        ld   a, (de)
        inc  a
        ld   (de), a
        jp   (ix)

OpDecByte:
        ld   a, (de)
        dec  a
        ld   (de), a
        jp   (ix)

OpOutChar:
        ld   a, (de)
        cp   10
        jr   nz, not10
        ld   a, 13
        call PutChar
        ld   a, 10
not10:  call PutChar
        jp   (ix)

OpInChar:
        ld   a, 0xf5
        ld   (0x38), a
        call CursorOn
        call GetChar
        call PutChar
        cp   13
        jr   nz, not13
        ld   a, 10
        call PutChar
not13:  ld   (de), a
        call CursorOff
        ld   a, 0xc9
        ld   (0x38), a
        jp   (ix)

OpJmpForward:
        ld   a, (de)
        or   a
        jp   nz, noJumpFw
        ld   l, a           ; L = 0

LeftSquareBracketFound:
        inc  l
jfLoop: inc  bc
        ld   a, (bc)
        cp   "["
        jp   z, LeftSquareBracketFound
        cp   "]"
        jp   nz, jfLoop
        ; falls to RightSquareBracketFound

RightSquareBracketFound:
        dec  l
        jp   nz, jfLoop
        jp   (ix)

OpJmpBack:
        ld   a, (de)
        or   a
        jp   z, doNotJumpBack
        pop  bc
        jp   ML2
doNotJumpBack:
        pop  af                     ; drop top of the stack (address of matching '[' command)
        jp   (ix)

; =====================================================================

ClearDataArray:
;  input:  A = 0
; output:  A = 0
;         BC = 0
;         DE = dataPtr
;         HL = dapaPtr - 1

        ld   bc, ARRAY_SIZE - 1
        ld   de, dataPtr + ARRAY_SIZE - 2
        ld   hl, dataPtr + ARRAY_SIZE - 1
        ld   (hl), a
        lddr
        ex   de, hl
        ret

; =====================================================================

CursorOn:
        ld   a, 27
        call PutChar
        ld   a, "O"
        jr   PutChar

CursorOff:
        ld   a, 27
        call PutChar
        ld   a, "o"
        ; falls to PutChar

PutChar:
        push af
        push bc
        push de
        ld   b, a
        ld   a, VID_CH
        exos 7
        pop  de
        pop  bc
        pop  af
        ret

GetChar:
        ld   a, KEY_CH
        push bc
        push de
        exos 5
        ld   a, b
        pop  de
        pop  bc
        ret

; =====================================================================

DeCompress:
        ld   hl, compressedOpcodeTable
        ld   de, opCodeTable    ; opCodeTable is aligned to 0x100
        ld   b, e               ; B = 0
_c1:    ld   a, (hl)
        inc  hl
        inc  b                  ; B = 1
        or   a
        ret  z
        jp   p, _c2
        and  0x7f
        ld   b, a
        ld   a, (hl)
        inc  hl
_c2:    ld   (de), a
        inc  e
        djnz _c2
        jr   _c1

compressedOpcodeTable:
    db   LOW retu
    db   128 + 42, LOW MainLoop
    db   LOW OpIncByte, LOW OpInChar, LOW OpDecByte, LOW OpOutChar
    db   128 + 13, LOW MainLoop
    db   LOW OpDecDataPtr, LOW MainLoop, LOW OpIncDataPtr
    db   128 + 28, LOW MainLoop
    db   LOW OpJmpForward, LOW MainLoop, LOW OpJmpBack
    db   128 + 35, LOW MainLoop
    db   128 + 127, LOW MainLoop
    db   0

; =====================================================================

        end

