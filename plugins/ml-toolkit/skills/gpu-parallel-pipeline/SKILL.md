---
name: gpu-parallel-pipeline
description: Design and implement PyTorch GPU parallel processing pipelines for maximum throughput. Use when scaling workloads across multiple GPUs (ProcessPool, CUDA_VISIBLE_DEVICES isolation), optimizing single GPU utilization (CUDA Streams, async inference, model batching), or building I/O + compute pipelines (ThreadPool for loading, batch inference). Triggers on "multi-GPU", "GPU parallel", "batch inference", "CUDA isolation", "GPU utilization", "ProcessPool GPU", "PyTorch multi-GPU".
---

# GPU Parallel Pipeline

## Hermes Agent Compatibility

When this skill is loaded through Hermes as `ml-toolkit:gpu-parallel-pipeline`, map Claude/Codex tool names to Hermes tools:

| Claude/Codex term | Hermes tool |
|---|---|
| Bash | terminal |
| Read | read_file |
| Write | write_file |
| Edit | patch |

Treat `$ARGUMENTS` as the natural-language arguments supplied when the user asks Hermes to load the skill. Plugin-provided skills are explicit opt-in loads in Hermes; use `skill_view("ml-toolkit:gpu-parallel-pipeline")` (or ask Hermes to load that qualified skill) rather than relying on bare text.

## Overview

This skill provides patterns for maximizing GPU throughput in data processing pipelines.

**Three core patterns:**
1. **Multi-GPU Distribution** - ProcessPool with GPU isolation via CUDA_VISIBLE_DEVICES
2. **Single GPU Optimization** - CUDA Streams, async inference, model batching
3. **I/O + Compute Pipeline** - ThreadPool for I/O parallelization + batch inference

## Quick Reference

| Pattern | Use Case | Speedup |
|---------|----------|---------|
| Multi-GPU ProcessPool | Large dataset, multiple GPUs | ~N x (N = GPU count) |
| ThreadPool I/O + Batch | I/O bottleneck (image loading) | 2-5x |
| CUDA Streams | Multiple models on single GPU | 1.5-3x |

## Multi-GPU Architecture

```
Main Process (Coordinator)
    |
    +-- GPU 0: ProcessPool Worker (CUDA_VISIBLE_DEVICES=0)
    |       +-- ThreadPool (I/O)
    |       +-- Model batch inference
    |
    +-- GPU 1: ProcessPool Worker (CUDA_VISIBLE_DEVICES=1)
    |       +-- ThreadPool (I/O)
    |       +-- Model batch inference
    |
    +-- GPU N: ...
```

### Key Implementation Steps

1. **Worker initialization with GPU isolation**
```python
def _worker_init_with_gpu(gpu_id: int) -> None:
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_id)
    # Initialize model here (once per worker)
    global _model
    _model = load_model()
```

2. **Spawn context (not fork)**
```python
ctx = mp.get_context("spawn")  # Required for CUDA
with ProcessPoolExecutor(max_workers=n_gpus, mp_context=ctx) as executor:
    ...
```

3. **Chunk distribution**
```python
chunk_size = (n_total + n_gpus - 1) // n_gpus
chunks = [records[i*chunk_size:(i+1)*chunk_size] for i in range(n_gpus)]
```

## I/O + Compute Pipeline

Separate I/O (disk read) from compute (GPU inference) using ThreadPool:

```python
def _load_images_parallel(paths: list[str], max_workers: int = 8) -> dict:
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(cv2.imread, p): p for p in paths}
        return {futures[f]: f.result() for f in as_completed(futures)}

def process_batch_hybrid(batch: list[dict]) -> list[dict]:
    # 1. ThreadPool I/O
    images = _load_images_parallel([r["path"] for r in batch])
    # 2. GPU batch inference
    results = model.predict_batch(list(images.values()))
    return results
```

## Detailed References

- **[architecture.md](references/architecture.md)**: Multi-GPU ProcessPool design, worker lifecycle, error handling
- **[single-gpu-patterns.md](references/single-gpu-patterns.md)**: CUDA Streams, async inference, model parallelism
- **[troubleshooting.md](references/troubleshooting.md)**: spawn vs fork, OOM, CUDA_VISIBLE_DEVICES issues

## Memory Planning

Before implementation, check GPU memory:
```bash
# Codex 0.135 does not export CLAUDE_PLUGIN_ROOT and does not run from the repo
# CWD, so the resolver adds a plugin-cache branch (highest version: numeric
# dotted-field sort on the version basename; plain `sort` misranks 10.x under
# 9.x, `sort -V` is GNU-only). The final guard aborts loudly instead of running
# python against a path that does not exist.
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT/skills/gpu-parallel-pipeline" ]; then
  SKILL_DIR="$CLAUDE_PLUGIN_ROOT/skills/gpu-parallel-pipeline"                 # Claude Code (installed)
elif [ -d "plugins/ml-toolkit/skills/gpu-parallel-pipeline" ]; then
  SKILL_DIR="plugins/ml-toolkit/skills/gpu-parallel-pipeline"                  # Claude/Codex (repo CWD)
elif SKILL_DIR=$(ls -1d "${CODEX_PLUGIN_CACHE:-$HOME/.codex/plugins/cache}"/*/ml-toolkit/*/ 2>/dev/null \
       | awk -F/ '{print $(NF-1)"\t"$0}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -f2- | sed 's#/$##')/skills/gpu-parallel-pipeline
     [ -d "$SKILL_DIR" ]; then :                                              # Codex 0.135 plugin cache
elif [ -n "${HERMES_HOME:-}" ] && [ -d "$HERMES_HOME/plugins/ml-toolkit/skills/gpu-parallel-pipeline" ]; then
  SKILL_DIR="$HERMES_HOME/plugins/ml-toolkit/skills/gpu-parallel-pipeline"     # Hermes profile install
elif [ -n "${HERMES_HOME:-}" ] && [ -d "$HERMES_HOME/skills/gpu-parallel-pipeline" ]; then
  SKILL_DIR="$HERMES_HOME/skills/gpu-parallel-pipeline"                        # Hermes skill-level install (unverified)
else
  SKILL_DIR="$HOME/.hermes/plugins/ml-toolkit/skills/gpu-parallel-pipeline"    # Hermes default install
fi
[ -d "$SKILL_DIR" ] || { echo "gpu-parallel-pipeline: skill dir not resolved" >&2; exit 1; }
python "$SKILL_DIR/scripts/check_gpu_memory.py"
```

**Rule of thumb:**
- Workers per GPU = GPU_Memory / Model_Memory
- Example: 24GB GPU, 5GB model = 4 workers/GPU max
- Leave 2-3GB headroom for CUDA overhead
