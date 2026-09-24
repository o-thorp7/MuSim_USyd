# debug_mkl_threads.py
import time, os
import numpy as np
import mkl

print("nproc (os.cpu_count):", os.cpu_count())
print("MKL max threads:", mkl.get_max_threads())
print("SLURM_CPUS_PER_TASK:", os.environ.get("SLURM_CPUS_PER_TASK", "not set"))
print("OMP_NUM_THREADS:", os.environ.get("OMP_NUM_THREADS", "not set"))
print("MKL_NUM_THREADS:", os.environ.get("MKL_NUM_THREADS", "not set"))

# small-ish matmul, similar order of magnitude to MCEq's euler step matrices
n = 2000
a = np.random.rand(n, n)
b = np.random.rand(n, n)
t0 = time.time()
for _ in range(20):
    c = a @ b
print("20x matmul time:", time.time() - t0, "s")