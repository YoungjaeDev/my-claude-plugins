# Multi-GPU Architecture

## Table of Contents
- [ProcessPool with GPU Isolation](#processpool-with-gpu-isolation)
- [Chunk Distribution Pattern](#chunk-distribution-pattern)
- [Complete Multi-GPU Orchestration](#complete-multi-gpu-orchestration)
- [Worker Lifecycle](#worker-lifecycle)
- [Error Handling Strategy](#error-handling-strategy)
- [Progress Tracking](#progress-tracking)
- [Performance Considerations](#performance-considerations)

## ProcessPool with GPU Isolation

### Why ProcessPool over ThreadPool for GPU?

Python's GIL doesn't affect GPU operations, but CUDA context initialization requires process isolation for reliable multi-GPU usage. Each process should own exactly one GPU.

### CUDA_VISIBLE_DEVICES Isolation

```python
import os
import multiprocessing as mp
from concurrent.futures import ProcessPoolExecutor, as_completed

# Process-local state
_model = None
_gpu_id = None

def _worker_init_with_gpu(gpu_id: int) -> None:
    """Initialize worker with GPU isolation.

    Must be called at the start of each worker process.
    CUDA_VISIBLE_DEVICES makes this GPU appear as device:0 to PyTorch/TF.
    """
    global _model, _gpu_id

    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)
    _gpu_id = gpu_id

    # Import ML framework AFTER setting CUDA_VISIBLE_DEVICES
    import torch
    _model = YourModel().cuda()  # Now on device:0 (the isolated GPU)
```

### Chunk Distribution Pattern

```python
def distribute_to_gpus(records: list, n_gpus: int) -> list[tuple]:
    """Distribute records evenly across GPUs.

    Returns list of (chunk, gpu_id, position) tuples.
    """
    if n_gpus < 1:
        raise ValueError(f"n_gpus must be >= 1, got {n_gpus}")

    n_total = len(records)
    chunk_size = (n_total + n_gpus - 1) // n_gpus  # ceiling division

    chunks = []
    for i in range(n_gpus):
        start = i * chunk_size
        end = min(start + chunk_size, n_total)
        if start < n_total:
            chunks.append((records[start:end], i, i))  # (data, gpu_id, tqdm_position)

    return chunks
```

### Complete Multi-GPU Orchestration

```python
def run_multi_gpu(
    records: list[dict],
    n_gpus: int = 4,
    batch_size: int = 128,
) -> list[dict]:
    """Orchestrate multi-GPU parallel processing.

    Args:
        records: Data records to process
        n_gpus: Number of GPUs to use
        batch_size: Batch size per GPU

    Returns:
        Processed records with results
    """
    if not records:
        return []

    # Distribute data
    chunks = distribute_to_gpus(records, n_gpus)
    print(f"Distributing {len(records):,} items across {len(chunks)} GPUs")

    # CRITICAL: Use spawn context for CUDA
    ctx = mp.get_context("spawn")

    # Track GPU assignments for error recovery
    gpu_to_chunk = {gpu_id: chunk for chunk, gpu_id, _ in chunks}

    all_results = []
    failed_chunks = []

    with ProcessPoolExecutor(max_workers=len(chunks), mp_context=ctx) as executor:
        futures = {
            executor.submit(_process_gpu_chunk, chunk, gpu_id, batch_size, pos): gpu_id
            for chunk, gpu_id, pos in chunks
        }

        for future in as_completed(futures):
            gpu_id = futures[future]
            try:
                results = future.result()
                all_results.extend(results)
            except Exception as e:
                print(f"[ERROR] GPU {gpu_id} failed: {e}")
                failed_chunks.append((gpu_id, gpu_to_chunk[gpu_id]))

    # Handle failures gracefully (don't lose data)
    if failed_chunks:
        for gpu_id, chunk in failed_chunks:
            for record in chunk:
                record["_error"] = f"GPU {gpu_id} failed"
                all_results.append(record)

    return all_results
```

## Worker Lifecycle

```
spawn context creates new process
    |
    v
_worker_init_with_gpu(gpu_id)
    - Set CUDA_VISIBLE_DEVICES
    - Import ML framework
    - Load model to GPU
    |
    v
Process batches in loop
    |
    v
ProcessPool cleanup (model freed)
```

### Error Handling Strategy

1. **Per-GPU failure isolation**: One GPU failure shouldn't crash others
2. **Data preservation**: Failed chunks get marked, not dropped
3. **Graceful degradation**: Continue with remaining GPUs

```python
# Track failures
failed_chunks: list[tuple[int, list]] = []

try:
    results = future.result(timeout=300)  # 5-min timeout
except Exception as e:
    failed_chunks.append((gpu_id, original_chunk))

# After all futures complete
if failed_chunks:
    print(f"[WARN] {len(failed_chunks)} GPU(s) failed")
    # Add failed records with error markers
```

## Progress Tracking

Use tqdm with position parameter for multi-bar display:

```python
from tqdm import tqdm

def _process_gpu_chunk(records, gpu_id, batch_size, position):
    _worker_init_with_gpu(gpu_id)

    batches = [records[i:i+batch_size] for i in range(0, len(records), batch_size)]
    results = []

    for batch in tqdm(batches, desc=f"GPU {gpu_id}", position=position, leave=False):
        batch_results = process_batch(batch)
        results.extend(batch_results)

    return results
```

## Performance Considerations

| Factor | Recommendation |
|--------|---------------|
| Batch size | Start with 64-128, tune based on GPU memory |
| Workers per GPU | Usually 1 for large models, 2-4 for small models |
| I/O workers | 4-8 ThreadPool workers per GPU worker |
| Chunk size | Balanced across GPUs (ceiling division) |
