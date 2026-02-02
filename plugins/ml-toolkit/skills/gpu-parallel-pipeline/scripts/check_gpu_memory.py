#!/usr/bin/env python
"""GPU memory check utility for parallel pipeline planning.

Reports available GPU memory and recommends workers per GPU based on model size.

Usage:
    python check_gpu_memory.py
    python check_gpu_memory.py --model-memory 5.0  # Specify model memory in GB
"""

from __future__ import annotations

import argparse
import sys


def check_gpu_memory(model_memory_gb: float | None = None) -> None:
    """Check GPU memory and recommend worker count.

    Args:
        model_memory_gb: Estimated model memory usage in GB (optional)
    """
    try:
        import torch
    except ImportError:
        print("PyTorch not installed. Install with: pip install torch")
        sys.exit(1)

    if not torch.cuda.is_available():
        print("CUDA not available")
        sys.exit(1)

    n_gpus = torch.cuda.device_count()
    print(f"Found {n_gpus} GPU(s)\n")
    print("=" * 60)

    total_available = 0
    cuda_overhead_gb = 2.5  # Reserved for CUDA context

    for i in range(n_gpus):
        props = torch.cuda.get_device_properties(i)
        total_gb = props.total_memory / 1e9
        available_gb = total_gb - cuda_overhead_gb

        print(f"GPU {i}: {props.name}")
        print(f"  Total memory: {total_gb:.1f} GB")
        print(f"  Available (after CUDA overhead): {available_gb:.1f} GB")

        if model_memory_gb:
            workers = int(available_gb / model_memory_gb)
            print(f"  Recommended workers (for {model_memory_gb}GB model): {workers}")

        total_available += available_gb
        print()

    print("=" * 60)
    print(f"Total available memory: {total_available:.1f} GB")

    if model_memory_gb:
        total_workers = int(total_available / model_memory_gb)
        print(f"Total recommended workers: {total_workers}")
        print(f"\nSuggested command:")
        print(f"  --n-gpus {n_gpus} --batch-size 64")


def main():
    parser = argparse.ArgumentParser(description="Check GPU memory for parallel pipeline")
    parser.add_argument(
        "--model-memory",
        type=float,
        default=None,
        help="Estimated model memory usage in GB",
    )
    args = parser.parse_args()

    check_gpu_memory(args.model_memory)


if __name__ == "__main__":
    main()
