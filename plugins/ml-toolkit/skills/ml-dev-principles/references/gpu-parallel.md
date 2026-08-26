<!-- Migrated from ml-toolkit:gpu-parallel-pipeline (skill removed, 2026-08 restructure,
     see docs/audit/2026-08-26-restructure-audit.md). One item excluded per the §5
     conflict: the source skill listed "model batching" as a hand-rolled single-GPU
     optimization technique; §5 instead delegates batching for parallel-model inference
     to an engine (e.g. vLLM) rather than a custom launcher, so that line is dropped here. -->

# GPU Parallel Processing Patterns

Supporting reference for `ml-dev-principles` §5 (GPU 처리량). These patterns are for
fanning a *dataset-processing* workload out across multiple GPUs (e.g. running one
model over millions of images) — not for serving several models in parallel, where §5
already tells you CUDA_VISIBLE_DEVICES isolation + per-process, batched by an inference
engine, beats a hand-rolled launcher.

## Quick reference

| Pattern | Use case | Speedup |
|---------|----------|---------|
| Multi-GPU ProcessPool | Large dataset, multiple GPUs | ~N x (N = GPU count) |
| ThreadPool I/O + batch | I/O bottleneck (image loading) | 2-5x |
| CUDA Streams | Overlapping transfer/compute on one GPU | 1.5-3x |

## Multi-GPU ProcessPool + CUDA_VISIBLE_DEVICES isolation

Each worker process should own exactly one GPU. Python's GIL doesn't affect GPU ops,
but CUDA context init requires process isolation for reliable multi-GPU usage — this is
why ProcessPool (not ThreadPool) and `spawn` (not `fork`) are required.

One pool per GPU, each with the initializer wired in — a single shared pool cannot give
each worker a distinct `gpu_id`:

```python
def _worker_init_with_gpu(gpu_id: int) -> None:
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)
    # Import/build the model AFTER setting CUDA_VISIBLE_DEVICES
    global _model
    _model = load_model()  # now on device:0 — the isolated GPU

def _predict_chunk(chunk: list[dict]) -> list[dict]:
    # runs inside the worker; _model was set by the initializer above
    return _model.predict_batch(chunk)

ctx = mp.get_context("spawn")  # fork silently corrupts CUDA state
chunk_size = (n_total + n_gpus - 1) // n_gpus  # ceiling division
chunks = [records[i*chunk_size:(i+1)*chunk_size] for i in range(n_gpus)]

pools = [
    ProcessPoolExecutor(max_workers=1, mp_context=ctx,
                        initializer=_worker_init_with_gpu, initargs=(gpu_id,))
    for gpu_id in range(n_gpus)
]
futures = [pool.submit(_predict_chunk, chunk) for pool, chunk in zip(pools, chunks)]
results = [f.result() for f in futures]  # index i = GPU i's chunk, order preserved
for pool in pools:
    pool.shutdown()
```

## CUDA Streams (single GPU, multiple concurrent ops)

Overlap data transfer and computation on one GPU:

```python
import torch

def process_with_streams(batches: list, model):
    streams = [torch.cuda.Stream() for _ in range(2)]
    results = []
    for i, batch in enumerate(batches):
        with torch.cuda.stream(streams[i % 2]):
            data = batch.cuda(non_blocking=True)
            results.append(model(data))
    torch.cuda.synchronize()
    return results
```

## I/O + compute pipeline

Separate disk I/O (ThreadPool — I/O releases the GIL) from GPU compute:

```python
def _load_images_parallel(paths: list[str], max_workers: int = 8) -> dict:
    # path-keyed dict: as_completed yields in completion order, so the dict alone
    # must never be treated as batch-ordered
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(cv2.imread, p): p for p in paths}
        return {futures[f]: f.result() for f in as_completed(futures)}

def process_batch_hybrid(batch: list[dict]) -> list[dict]:
    paths = [r["path"] for r in batch]
    images = _load_images_parallel(paths)          # 1. ThreadPool I/O (unordered)
    ordered = [images[p] for p in paths]           # 2. restore batch order by path
    preds = _model.predict_batch(ordered)          # 3. worker-initialized model
    return [{"path": p, "pred": pr} for p, pr in zip(paths, preds)]
```

## Memory planning rule of thumb

- Workers per GPU = GPU_Memory / Model_Memory
- Example: 24GB GPU, 5GB model → 4 workers/GPU max
- Leave 2-3GB headroom for CUDA overhead
