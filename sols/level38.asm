copyfrom 9
copyto 2
bumpup 2
a:
copyfrom 9
copyto 6
copyto 7
copyto 8
inbox
copyto 0
b:
sub 11
jumpn c
copyto 0
bumpup 8
copyfrom 0
jump b
c:
copyfrom 8
jumpz d
outbox
d:
e:
copyfrom 0
sub 10
jumpn f
copyto 0
bumpup 7
jump e
f:
copyfrom 7
jumpn g
outbox
jump h
g:
copyfrom 8
jumpn h
copyfrom 7
outbox
h: #h, i, j
copyfrom 0
sub 2
jumpn i
copyto 0
bumpup 6
jump h
i:
copyfrom 6
outbox
jump a
