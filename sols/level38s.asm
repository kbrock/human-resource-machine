    COMMENT  0
    COPYFROM 11
    SUB      10
    COPYTO   8
    COPYFROM 9
    COPYTO   6
    JUMP     c
a:
    COPYFROM 6
    OUTBOX  
    COPYFROM 9
    COPYTO   6
b:
    COPYFROM 0
    OUTBOX  
c:
    INBOX   
    COPYTO   0
    SUB      10
    JUMPN    b
    COMMENT  1
    SUB      8
    JUMPN    h
    COMMENT  2
d:
    COPYTO   0
    BUMPUP   6
    COPYFROM 0
    SUB      11
    JUMPN    e
    JUMP     d
e:
    COPYFROM 6
    OUTBOX  
    COPYFROM 9
    COPYTO   6
f:
    COPYFROM 0
    SUB      10
    JUMPN    a
g:
    COPYTO   0
    BUMPUP   6
    JUMP     f
h:
    ADD      8
    JUMP     g
    
