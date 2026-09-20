Forge Silicon RC transient test
.option post=2
V1 in 0 PULSE(0 1 0 1u 1u 0.5m 1m)
R1 in out 1k
C1 out 0 1n
.tran 1u 2m
.print tran v(in) v(out)
.end
