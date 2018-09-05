-- 17/15 115/109 (mine: 177)
-- may want to use 9 for accumulator
reg 0: aa
reg 1: bb
reg 5: TOT
reg 9: zero

start:
  inbox
  copyto TOT
  jumpz  aa_zero
  copyto aa
  inbox
  jumpz  bb_zero
  copyto bb
loop:
  bumpdn bb
  jumpz done
  copyfrom aa
  add TOT
  copyto TOT
  jump loop
aa_zero:
  inbox
done:
  copyfrom TOT
bb_zero:
  outbox
  jump start
