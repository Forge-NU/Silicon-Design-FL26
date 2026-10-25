# Record every digital and analog signal into waves.shm, then run to $finish.
database -open waves -into waves.shm -default
probe -create -all -depth all -database waves
run
exit
