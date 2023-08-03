#!/bin/bash
MODE="${1:-single}"
if [ $MODE == "single" ]; then
    export TPU_NAME=local
else
    export TPU_NAME=$SLURMD_NODENAME
    export TPU_LOAD_LIBRARY=0
fi

python3 /slurm/jobs/tpu.py 2>/dev/null
