# debug_mceq_kernel.py — standalone, safe, no pipeline files touched
import numpy
print("numpy version:", numpy.__version__)
numpy.show_config()

try:
    import mkl
    print("mkl package: IMPORTED OK, version", mkl.__version__)
except ImportError as e:
    print("mkl package: NOT AVAILABLE —", e)

import MCEq.config as config
print("MCEq detected kernel_config:", config.kernel_config)