# Troubleshooting Guide

## Table of Contents
- [spawn vs fork Context](#spawn-vs-fork-context)
- [CUDA_VISIBLE_DEVICES Issues](#cuda_visible_devices-issues)
- [GPU Memory OOM](#gpu-memory-oom)
- [Pickling Errors](#pickling-errors)
- [Process Hangs](#process-hangs)
- [Debugging Checklist](#debugging-checklist)
- [Quick Fixes](#quick-fixes)

## spawn vs fork Context

### Problem: Silent Failures with fork

When using `fork` context with CUDA:
- Worker processes inherit CUDA context from parent
- Functions may fail to pickle correctly
- Workers might return None silently instead of crashing

### Symptom
```
# Processing completes in seconds instead of hours
# All results are None
# No error messages
```

### Solution: Always Use spawn

```python
import multiprocessing as mp

# WRONG
with ProcessPoolExecutor(max_workers=4) as executor:
    ...

# CORRECT
ctx = mp.get_context("spawn")
with ProcessPoolExecutor(max_workers=4, mp_context=ctx) as executor:
    ...
```

### Why spawn works

| Context | Behavior | CUDA Safe |
|---------|----------|-----------|
| fork | Copy parent process memory | No |
| spawn | Start fresh process | Yes |
| forkserver | Fork from server process | Partial |

## CUDA_VISIBLE_DEVICES Issues

### Problem: All Workers Use Same GPU

Workers share parent's CUDA context if not isolated.

### Solution: Set Early in Worker

```python
def _worker_init(gpu_id: int):
    # MUST be first line - before any CUDA import
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)

    # NOW import PyTorch
    import torch

    # device:0 is now the isolated GPU
    model = Model().to("cuda:0")
```

### Verification

```python
def _worker_init(gpu_id: int):
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)
    import torch

    # Should print only 1 device
    print(f"Worker {gpu_id}: {torch.cuda.device_count()} device(s)")
    print(f"Device name: {torch.cuda.get_device_name(0)}")
```

### Common Mistake

```python
# WRONG: Setting after import
import torch
os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)  # Too late!

# WRONG: Using device index directly
model.to(f"cuda:{gpu_id}")  # Sees all GPUs, doesn't isolate
```

## GPU Memory OOM

### Symptom
```
RuntimeError: CUDA out of memory. Tried to allocate X MiB
```

### Diagnosis

```python
def check_memory():
    import torch
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        total = props.total_memory / 1e9
        reserved = torch.cuda.memory_reserved(i) / 1e9
        allocated = torch.cuda.memory_allocated(i) / 1e9
        print(f"GPU {i}: {allocated:.1f}GB allocated, {reserved:.1f}GB reserved, {total:.1f}GB total")
```

### Solutions

1. **Reduce batch size**
```python
batch_size = 64  # Start small, increase until OOM
```

2. **Enable mixed precision**
```python
with torch.cuda.amp.autocast():
    output = model(input)
```

3. **Clear cache between batches**
```python
torch.cuda.empty_cache()  # Use sparingly, has overhead
```

4. **Reduce workers per GPU**
```python
# If model uses 8GB on 24GB GPU
workers_per_gpu = 24 // 8 - 1  # Leave headroom = 2 workers
```

### Memory Planning Formula

```
available_memory = total_gpu_memory - cuda_overhead (2-3GB)
model_memory = model_size * precision_multiplier
  - FP32: model_params * 4 bytes
  - FP16: model_params * 2 bytes
  - INT8: model_params * 1 byte

workers_per_gpu = floor(available_memory / model_memory)
```

## Pickling Errors

### Symptom
```
_pickle.PicklingError: Can't pickle <local object>
```

### Common Causes

1. **Lambda functions**
```python
# WRONG
executor.submit(lambda x: process(x), data)

# CORRECT
def process_wrapper(data):
    return process(data)
executor.submit(process_wrapper, data)
```

2. **Nested functions**
```python
# WRONG
def outer():
    def inner(x):
        return x * 2
    executor.submit(inner, data)

# CORRECT: Define at module level
def inner(x):
    return x * 2
```

3. **CUDA tensors**
```python
# WRONG: Passing CUDA tensor to worker
executor.submit(process, tensor.cuda())

# CORRECT: Pass CPU tensor, move to GPU in worker
executor.submit(process, tensor.cpu())
```

## Process Hangs

### Symptom
- Workers never complete
- No progress bar updates
- CPU/GPU utilization drops to 0

### Diagnosis

```python
# Add timeout to futures
for future in as_completed(futures, timeout=300):
    try:
        result = future.result(timeout=60)
    except TimeoutError:
        print(f"Worker timed out")
```

### Common Causes

1. **Deadlock in worker**
   - Check for locks that never release
   - Ensure thread-safe data structures

2. **CUDA synchronization hang**
```python
# Add sync points for debugging
torch.cuda.synchronize()
print("Sync point reached")
```

3. **I/O blocking**
```python
# Set timeouts on I/O operations
img = cv2.imread(path)  # Can hang on network storage
```

## Debugging Checklist

1. [ ] Using spawn context?
2. [ ] CUDA_VISIBLE_DEVICES set before imports?
3. [ ] Functions defined at module level (not nested)?
4. [ ] No CUDA tensors passed between processes?
5. [ ] Sufficient GPU memory for batch size?
6. [ ] Timeouts set for futures?
7. [ ] Progress tracking (tqdm) enabled?

## Quick Fixes

| Issue | Quick Fix |
|-------|-----------|
| Silent None returns | Add spawn context |
| All workers on GPU 0 | Set CUDA_VISIBLE_DEVICES first |
| OOM | Reduce batch_size by 50% |
| Pickle error | Move function to module level |
| Process hangs | Add timeout, check I/O |
