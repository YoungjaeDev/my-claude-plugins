# Single GPU Optimization Patterns

## Table of Contents
- [CUDA Streams for Concurrent Operations](#cuda-streams-for-concurrent-operations)
- [Async Inference Pattern](#async-inference-pattern)
- [Model Batching for Multiple Small Models](#model-batching-for-multiple-small-models)
- [Dynamic Batching](#dynamic-batching)
- [Memory Optimization](#memory-optimization)
- [Throughput Measurement](#throughput-measurement)
- [Best Practices Summary](#best-practices-summary)

## CUDA Streams for Concurrent Operations

CUDA streams allow overlapping data transfer and computation:

```python
import torch

def process_with_streams(batches: list, model):
    """Process batches using CUDA streams for overlap."""
    streams = [torch.cuda.Stream() for _ in range(2)]
    results = []

    for i, batch in enumerate(batches):
        stream = streams[i % 2]

        with torch.cuda.stream(stream):
            # Transfer to GPU
            data = batch.cuda(non_blocking=True)
            # Compute
            output = model(data)
            results.append(output)

    # Synchronize all streams
    torch.cuda.synchronize()
    return results
```

## Async Inference Pattern

For pipelines with I/O and compute stages:

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

class AsyncInferencePipeline:
    def __init__(self, model, io_workers: int = 4):
        self.model = model
        self.io_executor = ThreadPoolExecutor(max_workers=io_workers)
        self.batch_queue = asyncio.Queue(maxsize=2)  # Prefetch 2 batches

    async def load_batch(self, paths: list[str]):
        """Load batch in thread pool (non-blocking)."""
        loop = asyncio.get_event_loop()
        images = await loop.run_in_executor(
            self.io_executor,
            lambda: [load_image(p) for p in paths]
        )
        return torch.stack(images)

    async def producer(self, all_paths: list[str], batch_size: int):
        """Continuously load batches."""
        for i in range(0, len(all_paths), batch_size):
            batch_paths = all_paths[i:i+batch_size]
            batch = await self.load_batch(batch_paths)
            await self.batch_queue.put(batch)
        await self.batch_queue.put(None)  # Signal end

    async def consumer(self):
        """Process batches as they arrive."""
        results = []
        while True:
            batch = await self.batch_queue.get()
            if batch is None:
                break
            with torch.no_grad():
                output = self.model(batch.cuda())
            results.append(output.cpu())
        return results

    async def run(self, paths: list[str], batch_size: int = 32):
        producer_task = asyncio.create_task(self.producer(paths, batch_size))
        results = await self.consumer()
        await producer_task
        return results
```

## Model Batching for Multiple Small Models

Run multiple small models on single GPU:

```python
class MultiModelPipeline:
    """Run multiple models efficiently on single GPU."""

    def __init__(self, models: list):
        self.models = [m.cuda() for m in models]
        self.streams = [torch.cuda.Stream() for _ in models]

    def forward_all(self, inputs: list[torch.Tensor]) -> list[torch.Tensor]:
        """Run all models concurrently using streams."""
        outputs = [None] * len(self.models)

        # Launch all models
        for i, (model, stream, x) in enumerate(zip(self.models, self.streams, inputs)):
            with torch.cuda.stream(stream):
                outputs[i] = model(x.cuda(non_blocking=True))

        # Wait for all
        torch.cuda.synchronize()
        return outputs
```

## Dynamic Batching

Maximize GPU utilization with variable batch sizes:

```python
class DynamicBatcher:
    """Accumulate inputs until batch is full or timeout."""

    def __init__(self, model, max_batch: int = 64, timeout_ms: int = 10):
        self.model = model
        self.max_batch = max_batch
        self.timeout_ms = timeout_ms
        self.pending = []
        self.last_submit = time.time()

    def add(self, item):
        self.pending.append(item)

        should_process = (
            len(self.pending) >= self.max_batch or
            (time.time() - self.last_submit) * 1000 > self.timeout_ms
        )

        if should_process and self.pending:
            return self._process_batch()
        return None

    def _process_batch(self):
        batch = torch.stack(self.pending[:self.max_batch])
        self.pending = self.pending[self.max_batch:]
        self.last_submit = time.time()

        with torch.no_grad():
            return self.model(batch.cuda())
```

## Memory Optimization

### Gradient Checkpointing (Training)

```python
from torch.utils.checkpoint import checkpoint

class EfficientModel(nn.Module):
    def forward(self, x):
        # Checkpoint intermediate layers to save memory
        x = checkpoint(self.layer1, x)
        x = checkpoint(self.layer2, x)
        x = self.head(x)
        return x
```

### Mixed Precision Inference

```python
with torch.cuda.amp.autocast():
    output = model(input)  # Uses FP16 automatically
```

### Memory-Efficient Attention (for transformers)

```python
# Use torch.nn.functional.scaled_dot_product_attention (PyTorch 2.0+)
# Automatically uses FlashAttention when available
from torch.nn.functional import scaled_dot_product_attention

attn_output = scaled_dot_product_attention(q, k, v, is_causal=True)
```

## Throughput Measurement

```python
import time
import torch

def benchmark_throughput(model, input_shape, n_iterations=100, warmup=10):
    """Measure model throughput in samples/second."""
    model.eval()
    dummy_input = torch.randn(*input_shape).cuda()

    # Warmup
    for _ in range(warmup):
        with torch.no_grad():
            _ = model(dummy_input)

    torch.cuda.synchronize()
    start = time.perf_counter()

    for _ in range(n_iterations):
        with torch.no_grad():
            _ = model(dummy_input)

    torch.cuda.synchronize()
    elapsed = time.perf_counter() - start

    batch_size = input_shape[0]
    throughput = (n_iterations * batch_size) / elapsed
    print(f"Throughput: {throughput:.1f} samples/sec")
    return throughput
```

## Best Practices Summary

| Technique | When to Use | Memory Impact |
|-----------|-------------|---------------|
| CUDA Streams | Multiple independent ops | Minimal |
| Async I/O | I/O bottleneck | Minimal |
| Multi-model | Multiple small models | +1 model per stream |
| Dynamic batching | Variable input rate | Configurable |
| Mixed precision | Large models, Ampere+ GPU | -50% |
| Checkpointing | Training large models | -60% (slower) |
