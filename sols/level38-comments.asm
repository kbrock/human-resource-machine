reg 0: x
reg 2: one

reg 6: c1
reg 7: c10
reg 8: c100
reg 9: zero
reg 10: ten
reg 11: hundred
copyfrom zero
copyto one
bumpup one
a:
copyfrom zero
copyto c1
copyto c10
copyto c100
inbox
copyto x
b:
sub hundred
jumpn c
copyto x
bumpup c100
copyfrom x
jump b
c:
copyfrom c100
jumpz d
outbox
d:
e:
copyfrom x
sub ten
jumpn f
copyto x
bumpup c10
jump e
f:
copyfrom c10
jumpn g
outbox
jump h
g:
copyfrom c100
jumpn h
copyfrom c10
outbox
h: #h, i, j
copyfrom x
sub one
jumpn i
copyto x
bumpup c1
jump h
i:
copyfrom c1
outbox
jump a
