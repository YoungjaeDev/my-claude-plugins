---
name: ml-dev-principles
description: "Working discipline for ML / multimodal / CV development: candidate model and dataset selection with license filtering, EDA, training and fine-tuning (SFT/DPO/LoRA), eval-harness and train/val/test isolation, FP/FN error analysis, GPU throughput and multi-GPU pipelines (ProcessPool + CUDA isolation, batch inference). Load at the START of an ML task, on /ml:ml-dev-principles, 'EDA', 'error analysis', 'fine-tune', 'eval harness', 'test leakage', 'multi-GPU', 'GPU parallel', 'batch inference'. How to work, not which library; demo UIs go to /ml:gradio-cv-app, notebooks to /ml:cv-notebook."
---

# ML / Multimodal Development Principles

Six rules for *how* to run ML, multimodal and CV work, not which library to use. Skim them once at the start of a task and apply them. In one line: **do not look only at aggregates and rule text; look at the real thing (images, the source text, GPU utilization) yourself.**

Rules have types. Separate hard-block rules (compliance, safety, leaking into the deliverable) from process-caution rules (conservatism, style, convention), because reading every rule reflexively at its strictest also blocks legitimate fast paths. Classify first, gate only on hard-blocks, and judge the rest as trade-offs.

## 1. Candidate selection: read the rule text before filtering on license or eligibility

- Do not over-filter models or data up front ("excluded because the license is non-commercial / research-only"). When the task is research or a competition and the rule text does not actually forbid it, keep the candidate. A permissive license (Apache/MIT) is a tiebreaker between equals, not a gate.
- **Why**: a wrong exclusion at selection propagates through the whole pipeline and bends the direction itself. It is the most expensive mistake to undo.
- **Apply**: list the eligibility constraints literally, classify each as hard-block or preference, and exclude only on hard-blocks.

## 2. Eval isolation: separate the hard rule from process caution

- **Hard rule (never)**: do not train, early-stop, select or tune the submitted or deployed model on held-out or test labels. That is leakage.
- **Allowed and encouraged**: using test GT (or any held-out proxy) as a flag-gated dev diagnostic, to sanity-check that the pipeline runs end to end and the numbers make sense, is legitimate. Do not refuse a harmless pipeline check on purity grounds. Isolate the diagnostic path behind a flag so it never flows into the deliverable.
- **Why**: confusing "no leakage into the deliverable" with "never look at labels, even to check the plumbing" cuts off fast feedback exactly when time is short.
- **Apply**: training and selection signals for the submitted model come only from a train-disjoint independent val set. Test GT goes only into an isolated path that touches nothing flowing into the deliverable.

## 3. EDA is mandatory: for multimodal data a person looks at raw and overlay images

- EDA before modeling is non-negotiable. For labeled multimodal or CV data, do not stop at distribution statistics: a person (or Claude vision) actually looks at raw images, with overlays for detection and segmentation.
- **Why**: aggregate statistics give a false impression of having seen everything. In multimodal data the image carries the evidence, so label-image consistency cannot be read from statistics.
- **Apply**: look at per-stratum samples by eye in an interactive viewer (for example the exploration mode of `ml:cv-notebook`) before trusting the numbers.

## 4. Error analysis: look at the actual FP/FN images, not the metric

- Open the actual image of each wrong case (FP/FN), compare it with the question, options and answer (overlays included), and infer *why* it failed. Feed that insight into the next data or model change.
- **Why**: a metric says how much is wrong, never why. The why (label error, ambiguous image, a model ignoring the image and leaning on a text prior) shows only in the pixels, and it drives the next iteration.
- **Apply**: *run* code that dumps FP/FN cases with their images after eval, review samples by eye, and reduce what you see to a concrete data, augmentation or prompt change.

## 5. GPU throughput: a parallel strategy that fits the model size, plus the eff-batch invariant

- Match parallelism to model size: a small model (about 3B or less) gets plain DDP with ZeRO/DeepSpeed off, since partitioning overhead exceeds the gain. No ZeRO cargo cult.
- Keep the eff-batch invariant (per_device x accum x n_gpu = constant) and raise only the per-device batch, which buys speed without changing convergence dynamics.
- LoRA rank, flash-attn, gradient checkpointing and bf16 are the standard levers. Tune rank to the memory ceiling.
- For parallel inference over several models, CUDA_VISIBLE_DEVICES isolation with one process per model is simpler than a hand-rolled multi-GPU launcher and sufficient. Leave batching to the engine (for example vLLM).
- **Why**: more GPU machinery != faster. The win is a strategy that fits the model plus a fixed eff-batch: free speed with no accuracy regression.
- **Apply**: profile utilization. Below 90%, suspect DeepSpeed/ZeRO overhead or an undersized batch before reaching for exotic parallelism.
- **One model over a whole dataset on several GPUs** (a batch job, not the multi-model case above): ProcessPool + CUDA_VISIBLE_DEVICES isolation, CUDA Streams and I/O+compute pipelines are in [references/gpu-parallel.md](references/gpu-parallel.md).
- **Library-level traps**: per-file inference loops, BGR/RGB order, the Ultralytics YOLO internal-conversion exception and the WandB toggle are in [references/ml-pitfalls.md](references/ml-pitfalls.md).

## 6. Dual judgment runs on a flat-rate subscription: use it freely

- Wherever a VLM insight or a second opinion helps (data-pair checks, GT or label generation, error review, cross-checking designs and hypotheses), run Codex read and Claude vision side by side by default. The OAuth flat-rate subscription makes the per-call cost effectively zero, so do not ration judgments the way API tokens are rationed.
- No judgment by a single model alone. Escalate a disagreement to a careful re-pass plus a comparison of rationales.
- **Why**: where the image is the evidence, two independent judgments are the cheapest insurance against mislabels and hallucinations, and on a flat rate that insurance is free. Stopping at a single pass to save cost misses errors that would have been caught.
- **Apply**: in 3 (EDA) and 4 (error review), call Claude read and Codex read together by default, then reconcile or compare them.
