
MainLoop:
; BC = BrainFuck Instruction Counter
; DE = pointer to BrainFuck data memory
        inc  bc
ML2:    ld   a, (bc)
        inc  h
        ld   l, a
        ld   l, (hl)
        dec  h
        jp   (hl)
