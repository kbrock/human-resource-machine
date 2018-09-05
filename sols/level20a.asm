-- 15/15 162/109
-- may want to use 9 for accumulator
  reg 0: aa
  reg 1: bb
  reg 5: TOT
  reg 9: zero
  
start:
  copyfrom zero
  copyto TOT
  inbox
  copyto aa
  inbox
  copyto bb
loop:
  jumpz done
  copyfrom aa
  add TOT
  copyto TOT
  bumpdn 1
  jump loop
done:
  copyfrom TOT
  outbox
  jump start
