reg 0: aa
reg 4: bb

reg 9: zero
reg 8: one
reg 7: two
reg 6: four
reg 5: eight

-- setup setup:
    COPYFROM zero
    COPYTO   one
    BUMPUP   one
    ADD      one
    COPYTO   two
    ADD      two
    COPYTO   four
    ADD      four
    COPYTO   eight
start:
    INBOX   
    JUMPZ    aa_zero
    COPYTO   aa
    INBOX   
    JUMPZ    bb_zero
    COPYTO   bb
    SUB      eight
    JUMPN    bb_lt_eight
    JUMPZ    x8
    COPYFROM zero
    JUMP     x9
bb_lt_eight:
    COPYFROM bb
    SUB      four
    JUMPZ    x4
    JUMPN    bb_lt_4
    SUB      two
    JUMPZ    x6
    JUMPN    prep_x5
    SUB      one
    JUMP     x7
prep_x5:
    COPYFROM zero
    JUMP     x5
bb_lt_4:
    COPYFROM bb
    SUB      two
    JUMPZ    x2
    JUMPN    prep_x1
    SUB      one
    JUMP     x3
prep_x1:
    COPYFROM zero
    JUMP     x1
    COMMENT  2
x9:
    ADD      aa
x8:
    ADD      aa
x7:
    ADD      aa
x6:
    ADD      aa
x5:
    ADD      aa
x4:
    ADD      aa
x3:
    ADD      aa
x2:
    ADD      aa
x1:
    ADD      aa
bb_zero:
    OUTBOX  
    JUMP     start
aa_zero:
    OUTBOX  
    INBOX   
    JUMP     start
