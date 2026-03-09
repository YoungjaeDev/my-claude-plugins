# Interactive Exploration Korean Insights

Korean insight library for the cv-explorer skill.

## Format Specification

Shares the same category system as cv-notebook but uses its own markup format optimized for interactive exploration.

### Inline Insight (code cell comment)
```python
# ★ Insight: continuous_update=False는 슬라이더 드래그 중 콜백을 억제하여 성능을 보장합니다
slider = widgets.IntSlider(continuous_update=False)
```

### Block Insight (standalone markdown cell)
```markdown
> ★ **Insight** | 카테고리
>
> 설명 텍스트 (2-3문장)
```

### Categories
| Category | Purpose | Example |
|----------|---------|---------|
| 개념 | Core concept explanation | Widget observe pattern |
| 성능 | Optimization | Image cache, continuous_update |
| 실무 | Practical tips | Data format selection criteria |
| 디버깅 | Troubleshooting | clear_output flicker |
| 주의 | Common mistakes | Missing BGR/RGB conversion |
| 팁 | Productivity | Keyboard shortcuts, Play widget |

---

## Level-Based Density Guide

| Level | Insight Count | Placement Strategy |
|-------|---------------|--------------------|
| beginner | 12-15 | All sections, every widget explained |
| intermediate | 6-10 | Key sections only, major patterns |
| expert | 2-4 | Performance/advanced tips only, no basics |

---

## Setup Section Insights

### beginner
```markdown
> ★ **Insight** | 개념
>
> `ipywidgets`는 Jupyter 노트북에서 interactive UI를 만드는 라이브러리입니다.
> 슬라이더, 드롭다운, 버튼 등을 Python 코드로 생성하고, 값 변경 시 자동으로 콜백 함수를 실행합니다.
> 데이터 탐색에서 `for` 루프 대신 위젯을 사용하면 원하는 이미지를 즉시 확인할 수 있어 효율적입니다.
```

```markdown
> ★ **Insight** | 주의
>
> `cv2.imread()`는 이미지를 BGR 순서로 로드하지만, `matplotlib`과 `PIL`은 RGB를 기대합니다.
> `cv2.cvtColor(img, cv2.COLOR_BGR2RGB)` 변환을 빠뜨리면 빨간색과 파란색이 뒤바뀌어 표시됩니다.
> 이 변환은 로드 시점에 한 번만 수행하는 것이 가장 안전합니다.
```

### intermediate
```python
# ★ Insight: cv2.imread는 BGR, matplotlib/PIL은 RGB — 캐시 로더에서 한 번만 변환
```

---

## Interactive Viewer Section Insights

### beginner
```markdown
> ★ **Insight** | 성능
>
> `continuous_update=False`는 ipywidgets 슬라이더의 핵심 설정입니다.
> `True`(기본값)이면 드래그하는 동안 매 픽셀마다 콜백이 실행되어 심각한 렉이 발생합니다.
> `False`로 설정하면 슬라이더를 놓는 순간에만 콜백이 실행되어 부드러운 인터랙션이 가능합니다.
```

```markdown
> ★ **Insight** | 개념
>
> `widgets.Output()`은 matplotlib 그래프나 print 출력을 위젯 컨테이너 안에 캡처합니다.
> `with output:` 컨텍스트 매니저 안에서 실행되는 모든 출력이 해당 위젯에 렌더링됩니다.
> `clear_output(wait=True)`의 `wait=True`는 새 출력이 준비될 때까지 이전 출력을 유지하여 깜빡임을 방지합니다.
```

```markdown
> ★ **Insight** | 디버깅
>
> `observe()` 콜백에서 에러가 발생하면 Jupyter 셀 출력에 표시되지 않을 수 있습니다.
> `widgets.Output()` 안에서 `try/except`로 감싸고 traceback을 출력하면 디버깅이 쉬워집니다.
> 또는 `%debug` 매직 커맨드를 사용하여 마지막 예외를 디버깅할 수 있습니다.
```

### intermediate
```python
# ★ Insight: continuous_update=False — 슬라이더 놓을 때만 콜백 실행 (드래그 중 렉 방지)
```

```python
# ★ Insight: clear_output(wait=True) — 새 출력이 준비될 때까지 이전 출력 유지 (flicker 방지)
```

### expert
```python
# ★ Insight: observe('value')는 trait change만 감지 — 동일 값 재선택 시 콜백 미실행에 주의
```

---

## Cache Section Insights

### beginner
```markdown
> ★ **Insight** | 성능
>
> 이미지를 매번 디스크에서 읽는 것은 느립니다. `_cache` 딕셔너리에 한 번 로드한 이미지를 저장해두면,
> 같은 이미지를 다시 볼 때 디스크 I/O 없이 메모리에서 즉시 반환됩니다.
> `MAX_CACHE_SIZE`를 설정하여 메모리 사용량을 제한하는 것이 중요합니다.
```

### intermediate
```python
# ★ Insight: dict 기반 캐시는 LRU와 달리 FIFO 순서로 제거 — 대규모 데이터에서 더 예측 가능
```

### expert
```python
# ★ Insight: lru_cache는 hashable 인자만 지원 — Path 대신 str(path)로 전달 필수
```

---

## Comparison Section Insights

### beginner
```markdown
> ★ **Insight** | 실무
>
> Side-by-side 비교는 annotation 품질 검수에서 가장 유용합니다.
> Raw vs Annotated를 나란히 보면 bbox가 실제 객체를 정확히 감싸는지 한눈에 확인할 수 있습니다.
> 두 모델의 예측 결과를 비교할 때도 동일한 패턴을 활용할 수 있습니다.
```

### intermediate
```python
# ★ Insight: plt.subplots(1, 2)로 side-by-side — figsize 비율은 (W, W//2)가 자연스럽다
```

---

## Threshold Tuning Section Insights

### beginner
```markdown
> ★ **Insight** | 개념
>
> Confidence threshold는 모델 예측의 "확신도" 기준값입니다.
> 낮추면 더 많은 detection이 표시되지만 false positive도 증가합니다.
> 높이면 false positive는 줄지만 일부 정탐(true positive)도 놓칠 수 있습니다.
> 슬라이더로 실시간 조정하며 최적값을 찾는 것이 이 섹션의 목적입니다.
```

```markdown
> ★ **Insight** | 개념
>
> NMS(Non-Maximum Suppression)는 겹치는 bbox 중 가장 확신도가 높은 것만 남기는 후처리입니다.
> IoU threshold가 낮을수록 공격적으로 제거하고, 높을수록 많이 남깁니다.
> 밀집 객체(예: 군중)에서는 IoU를 높여야 작은 객체가 사라지지 않습니다.
```

### intermediate
```python
# ★ Insight: NMS IoU 0.45는 COCO 기본값 — 밀집 객체는 0.6~0.7로 상향 권장
```

---

## Statistics Section Insights

### beginner
```markdown
> ★ **Insight** | 실무
>
> Class distribution이 불균형하면 모델이 다수 클래스에 편향됩니다.
> 히스토그램으로 분포를 확인한 후, 소수 클래스에 대해 오버샘플링이나 데이터 증강을 고려하세요.
> 일반적으로 가장 많은 클래스와 가장 적은 클래스의 비율이 10:1을 넘으면 대응이 필요합니다.
```

### intermediate
```python
# ★ Insight: bbox 크기 분포는 anchor 설계의 근거 — 작은 객체가 많으면 FPN 필수
```

### expert
```python
# ★ Insight: 이미지당 annotation 수 분포의 긴 꼬리는 배치 내 패딩 비효율의 원인
```

---

## Supervision Library Insights

### beginner
```markdown
> ★ **Insight** | 개념
>
> `supervision`은 Roboflow에서 만든 CV 시각화 라이브러리입니다.
> `sv.Detections`로 통일된 데이터 구조에 bbox, mask, confidence를 담고,
> `BoxAnnotator`, `MaskAnnotator` 등으로 일관되게 시각화합니다.
> cv2로 직접 그리는 것보다 코드가 간결하고 색상/스타일이 자동 관리됩니다.
```

### intermediate
```python
# ★ Insight: sv.Detections은 numpy 기반 — COCO bbox [x,y,w,h]를 xyxy로 변환 필요
```

---

## Injection Points Matrix

Guide for which insights to inject in which sections at which levels.

| Section | beginner | intermediate | expert |
|---------|----------|--------------|--------|
| Setup | BGR/RGB conversion, ipywidgets intro | BGR inline | - |
| Config | Cache size, DISPLAY_WIDTH | - | - |
| Data Loading | Format structure explanation | Loader selection criteria | - |
| Interactive Viewer | continuous_update, Output, observe | continuous_update, clear_output inline | trait change caveat |
| Comparison | Side-by-side usage | figsize tip | - |
| Threshold | confidence/NMS concepts | NMS defaults | - |
| Statistics | Imbalance handling | anchor design | padding inefficiency |
| Supervision | Library intro | xyxy conversion | - |

### Insight Count Targets per Level

| Level | Block (markdown cell) | Inline (code comment) | Total |
|-------|----------------------|-----------------------|-------|
| beginner | 8-10 | 4-5 | 12-15 |
| intermediate | 2-3 | 4-7 | 6-10 |
| expert | 0 | 2-4 | 2-4 |
