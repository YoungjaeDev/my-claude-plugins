# Korean Insights Library (한국어 인사이트 라이브러리)

## Format Specification

### Inline Insight
```python
# # [Category] Brief Korean insight
code_here()
```

### Block Insight
```python
"""
[Note] [Category]
Korean explanation (2-3 sentences)
- Key point 1
- Key point 2
"""
code_here()
```

### Categories
- **개념** (Concept): Fundamental understanding
- **성능** (Performance): Optimization tips
- **실무** (Practice): Real-world application
- **디버깅** (Debugging): Troubleshooting
- **주의** (Caution): Common pitfalls
- **팁** (Tip): Pro tips

## Level-Based Density Guide

| Level | Insights/Section | Style | Focus |
|-------|------------------|-------|-------|
| 초급 (Beginner) | 15-20 | Block + Inline | Concepts, explanations, safety |
| 중급 (Intermediate) | 8-12 | Mixed | Best practices, optimization |
| 고급 (Advanced) | 3-5 | Inline | Edge cases, performance |

## Section-Specific Insights

### 1. Setup (환경 설정)

#### 초급 (Beginner)
```python
# # [개념] GPU 사용 가능 여부를 먼저 확인하여 학습 속도를 극대화합니다
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

"""
[Note] [실무]
transforms.Compose는 이미지 전처리 파이프라인을 정의합니다.
- Resize: 모델 입력 크기에 맞춤
- ToTensor: PIL Image를 Tensor로 변환 (0-255 → 0-1)
- Normalize: ImageNet 평균/표준편차로 정규화
"""
transform = transforms.Compose([...])

# # [주의] num_workers는 CPU 코어 수의 절반 이하로 설정하세요
dataloader = DataLoader(dataset, batch_size=32, num_workers=4)

# # [팁] pin_memory=True는 GPU 전송 속도를 2배 향상시킵니다
dataloader = DataLoader(dataset, pin_memory=True)

"""
[Note] [개념]
DataLoader의 shuffle=True는 매 epoch마다 데이터 순서를 섞어
과적합(overfitting)을 방지하고 모델 일반화 성능을 높입니다.
"""
train_loader = DataLoader(train_dataset, shuffle=True)
```

#### 중급 (Intermediate)
```python
# # [성능] persistent_workers=True로 worker 재생성 오버헤드 제거
dataloader = DataLoader(dataset, num_workers=4, persistent_workers=True)

"""
[Note] [실무]
augmentation은 학습 시에만 적용하고 검증/테스트 시에는
원본 이미지의 정확한 성능 측정을 위해 제외합니다.
"""
train_transform = transforms.Compose([RandomCrop(), RandomHorizontalFlip()])
val_transform = transforms.Compose([Resize(), CenterCrop()])

# # [팁] prefetch_factor로 GPU 대기 시간 최소화 (기본값: 2)
dataloader = DataLoader(dataset, prefetch_factor=3, num_workers=4)
```

#### 고급 (Advanced)
```python
# # [성능] multiprocessing_context='spawn'으로 Linux CUDA 메모리 누수 방지
dataloader = DataLoader(dataset, num_workers=4, multiprocessing_context='spawn')
```

### 2. Model Loading (모델 로딩)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
weights 파라미터로 사전학습된 가중치를 로드합니다 (PyTorch 2.0+에서 pretrained=True는 deprecated).
ImageNet 데이터셋으로 사전학습된 모델은 처음부터 학습하는 것보다 10-100배 빠르게 수렴합니다.
"""
model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V1)

# # [주의] model.eval()을 호출해야 Dropout/BatchNorm이 추론 모드로 전환됩니다
model.eval()

# # [개념] .to(device)로 모델을 GPU 메모리로 이동시킵니다
model = model.to(device)

"""
[Note] [실무]
분류 문제에서 출력 레이어의 뉴런 수는 클래스 수와 일치해야 합니다.
ImageNet(1000)과 다른 경우 마지막 fc layer를 교체하세요.
"""
model.fc = nn.Linear(model.fc.in_features, num_classes)

# # [팁] weights 파라미터로 최신 사전학습 가중치 선택 가능
model = models.resnet50(weights=models.ResNet50_Weights.IMAGENET1K_V2)
```

#### 중급 (Intermediate)
```python
"""
[Note] [실무]
전이학습 시 backbone을 freeze하면 학습 속도 3배 향상 + 메모리 50% 절약
초반 몇 epoch만 freeze 후 점진적으로 unfreeze 권장
"""
for param in model.parameters():
    param.requires_grad = False
model.fc.requires_grad = True

# # [성능] torch.compile()로 추론 속도 30% 향상 (PyTorch 2.0+)
model = torch.compile(model)

# # [팁] model.train()과 model.eval() 전환을 명시적으로 관리하세요
with torch.no_grad():
    model.eval()
    predictions = model(images)
```

#### 고급 (Advanced)
```python
# # [성능] torch.cuda.amp로 혼합 정밀도 학습 시 메모리 40% 절감, 속도 2배 향상
scaler = torch.cuda.amp.GradScaler()

# # [실무] EMA(Exponential Moving Average)로 검증 성능 1-2% 향상
ema_model = torch.optim.swa_utils.AveragedModel(model)
```

### 3. Inference (추론)

#### 초급 (Beginner)
```python
"""
[Note] [주의]
torch.no_grad() 컨텍스트는 gradient 계산을 비활성화하여
추론 속도 30% 향상 + 메모리 50% 절감
반드시 inference 시 사용하세요!
"""
with torch.no_grad():
    outputs = model(images)

# # [개념] softmax를 통과하면 확률값(0-1)으로 변환됩니다
probabilities = torch.nn.functional.softmax(outputs, dim=1)

# # [팁] argmax로 가장 높은 확률의 클래스 인덱스를 추출합니다
predictions = torch.argmax(probabilities, dim=1)

"""
[Note] [실무]
batch 단위 추론이 loop 추론보다 10-100배 빠릅니다.
가능한 한 batch로 처리하세요.
"""
outputs = model(batch_images)  # (N, C) 형태

# # [개념] .cpu()와 .numpy()로 Tensor를 NumPy 배열로 변환
result = predictions.cpu().numpy()
```

#### 중급 (Intermediate)
```python
# # [성능] @torch.inference_mode()는 no_grad()보다 5-10% 빠름
@torch.inference_mode()
def predict(images):
    return model(images)

"""
[Note] [실무]
top-k 예측으로 모델의 uncertainty를 파악할 수 있습니다.
2등 확률이 1등과 비슷하면 애매한 케이스입니다.
"""
top5_prob, top5_idx = torch.topk(probabilities, k=5, dim=1)

# # [팁] torch.cuda.synchronize()로 정확한 추론 시간 측정
torch.cuda.synchronize()
start = time.time()
```

#### 고급 (Advanced)
```python
# # [성능] TensorRT로 컴파일 시 추론 속도 5-10배 향상 (NVIDIA GPU)
import torch_tensorrt

# # [실무] 대용량 추론 시 gradient checkpointing으로 메모리 70% 절감
torch.utils.checkpoint.checkpoint(model, inputs)
```

### 4. Training (학습)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
optimizer.zero_grad()는 이전 배치의 gradient를 초기화합니다.
PyTorch는 기본적으로 gradient를 누적하므로 매 배치마다 초기화 필수!
"""
optimizer.zero_grad()

# # [개념] loss.backward()로 역전파를 수행하여 gradient를 계산합니다
loss.backward()

# # [개념] optimizer.step()으로 계산된 gradient를 이용해 가중치를 업데이트합니다
optimizer.step()

"""
[Note] [실무]
학습률(learning rate)은 가장 중요한 하이퍼파라미터입니다.
- 너무 크면: 발산 (loss가 NaN)
- 너무 작으면: 학습 느림
일반적으로 0.001 ~ 0.1 범위에서 시작
"""
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

# # [팁] 학습 중 loss를 출력하여 학습 진행 상황을 모니터링하세요
print(f'Epoch {epoch}, Loss: {loss.item():.4f}')

"""
[Note] [주의]
model.train() 모드에서는 Dropout/BatchNorm이 활성화됩니다.
학습 시작 전 반드시 호출하세요!
"""
model.train()

# # [개념] nn.CrossEntropyLoss는 분류 문제의 표준 손실 함수입니다
criterion = nn.CrossEntropyLoss()
```

#### 중급 (Intermediate)
```python
"""
[Note] [성능]
gradient accumulation으로 큰 배치 효과를 작은 메모리에서 구현
accumulation_steps=4이면 실제 배치 크기 4배 효과
"""
if (i + 1) % accumulation_steps == 0:
    optimizer.step()
    optimizer.zero_grad()

# # [실무] gradient clipping으로 exploding gradient 방지
torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)

"""
[Note] [팁]
학습률 스케줄러로 학습 후반부 성능 2-5% 향상
- CosineAnnealingLR: 점진적 감소
- ReduceLROnPlateau: 성능 정체 시 감소
"""
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=100)

# # [실무] label smoothing으로 과신(overconfidence) 방지, 일반화 성능 향상
criterion = nn.CrossEntropyLoss(label_smoothing=0.1)

# # [성능] mixed precision training으로 메모리 40% 절감, 속도 2-3배
with torch.cuda.amp.autocast():
    outputs = model(images)
    loss = criterion(outputs, labels)
```

#### 고급 (Advanced)
```python
# # [성능] torch.backends.cudnn.benchmark=True로 최적 알고리즘 자동 선택 (입력 크기 고정 시)
torch.backends.cudnn.benchmark = True

# # [실무] SAM optimizer로 일반화 성능 1-3% 향상 (계산 비용 2배)
from torch.optim import SAM
```

### 5. Evaluation (평가)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
평가 시에는 model.eval() + torch.no_grad()를 함께 사용하여
Dropout/BatchNorm 비활성화 + gradient 계산 제외
"""
model.eval()
with torch.no_grad():
    outputs = model(test_images)

# # [개념] 정확도(Accuracy)는 전체 예측 중 맞춘 비율입니다
correct = (predictions == labels).sum().item()
accuracy = correct / total

"""
[Note] [실무]
혼동 행렬(Confusion Matrix)로 클래스별 성능을 자세히 파악할 수 있습니다.
- 대각선: 정확히 분류된 샘플
- 비대각선: 오분류된 샘플
"""
from sklearn.metrics import confusion_matrix
cm = confusion_matrix(y_true, y_pred)

# # [팁] 검증 데이터로 overfitting을 조기에 감지하세요
if val_loss > best_val_loss:
    print("Overfitting 징후 감지!")
```

#### 중급 (Intermediate)
```python
"""
[Note] [실무]
불균형 데이터셋에서는 Accuracy 대신 F1-Score 사용
- Precision: 예측한 positive 중 실제 positive 비율
- Recall: 실제 positive 중 예측한 positive 비율
- F1: Precision과 Recall의 조화평균
"""
from sklearn.metrics import f1_score
f1 = f1_score(y_true, y_pred, average='macro')

# # [팁] class별 정확도를 따로 계산하여 weak class 파악
class_correct = [0] * num_classes
class_total = [0] * num_classes

# # [실무] AUC-ROC로 threshold-independent 성능 측정
from sklearn.metrics import roc_auc_score
auc = roc_auc_score(y_true, y_prob, multi_class='ovr')
```

#### 고급 (Advanced)
```python
# # [실무] Calibration plot으로 모델 신뢰도 보정 필요성 파악
from sklearn.calibration import calibration_curve

# # [성능] TTA(Test Time Augmentation)로 추론 정확도 1-2% 향상 (시간 비용 증가)
predictions = []
for transform in tta_transforms:
    predictions.append(model(transform(image)))
```

## Injection Points Matrix

**Per-Notebook Totals** (all sections combined):
- 초급: 15-20 insights total
- 중급: 8-12 insights total
- 고급: 3-5 insights total

| Section | 초급 Density | 중급 Density | 고급 Density | Priority Locations |
|---------|-------------|-------------|-------------|-------------------|
| Setup | 4-5 | 2-3 | 1 | DataLoader, transforms, device |
| Model Loading | 4-5 | 2-3 | 1 | weights parameter, .to(device), layer replacement |
| Inference | 3-4 | 2 | 1 | torch.no_grad(), softmax, argmax |
| Training | 4-5 | 2-3 | 1 | zero_grad(), backward(), step(), learning rate |
| Evaluation | 3-4 | 2 | 1 | model.eval(), metrics calculation |
| Detection | 4-5 | 2-3 | 1 | YOLO/RT-DETR NMS, anchors, supervision |
| Segmentation | 4-5 | 2-3 | 1 | SAM prompts, YOLO-Seg masks, supervision |
| VLM | 4-5 | 2-3 | 1 | Florence-2/PaliGemma/Qwen prompts, multimodal |

## Usage Guidelines

### 1. Inline vs Block Decision
- **Inline**: Single-line concepts, quick tips, warnings
- **Block**: Multi-step processes, complex explanations, best practices

### 2. Category Selection
```
개념 (Concept)   → Fundamental understanding, "what is this?"
성능 (Performance) → Speed, memory, optimization
실무 (Practice)  → Real-world application, industry patterns
디버깅 (Debugging) → Troubleshooting, common errors
주의 (Caution)   → Pitfalls, what NOT to do
팁 (Tip)        → Pro tips, shortcuts, quality-of-life
```

### 3. Placement Strategy
- **Before code**: Context, explanation
- **After code**: Rationale, expected outcome
- **Within loop**: Per-iteration explanation

### 4. Level Adaptation
```
초급 → Explain everything, use analogies, show alternatives
중급 → Assume basic knowledge, focus on best practices
고급 → Edge cases, performance tuning, research-level insights
```

### 6. Detection (객체 탐지)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
YOLO는 이미지를 그리드로 나누어 각 셀에서 객체를 동시에 탐지합니다.
- Bounding Box: 객체의 위치 (x, y, width, height)
- Confidence: 탐지 확신도 (0-1)
- Class: 객체 클래스 (person, car, dog, ...)
"""
from ultralytics import YOLO
model = YOLO('yolov8n.pt')

# # [개념] conf는 confidence threshold로 낮은 확신도 탐지를 필터링합니다
results = model.predict(image, conf=0.25)

"""
[Note] [실무]
NMS(Non-Maximum Suppression)는 중복 박스를 제거합니다.
iou_threshold=0.5는 IoU 50% 이상인 박스를 중복으로 간주합니다.
"""
results = model.predict(image, iou=0.5)

# # [팁] supervision 라이브러리로 탐지 결과를 시각화할 수 있습니다
import supervision as sv
detections = sv.Detections.from_ultralytics(results[0])
```

#### 중급 (Intermediate)
```python
"""
[Note] [실무]
RT-DETR은 Transformer 기반 탐지 모델로 YOLO보다 작은 객체 탐지에 강합니다.
- YOLO: 속도 우선 (실시간 영상)
- RT-DETR: 정확도 우선 (정밀 탐지)
"""
from ultralytics import RTDETR
model = RTDETR('rtdetr-l.pt')

# # [성능] imgsz를 늘리면 작은 객체 탐지 성능 향상 (속도 감소)
results = model.predict(image, imgsz=1280)  # 기본값 640

"""
[Note] [팁]
supervision의 BoxAnnotator로 커스텀 시각화 가능
- 색상, 두께, 레이블 위치 조정
- 다중 탐지 결과 병합
"""
box_annotator = sv.BoxAnnotator(thickness=2, color=sv.Color.RED)
annotated = box_annotator.annotate(scene=image, detections=detections)
```

#### 고급 (Advanced)
```python
# # [성능] SAHI(Slicing Aided Hyper Inference)로 고해상도 이미지 탐지 정확도 30% 향상
from sahi import AutoDetectionModel
from sahi.predict import get_sliced_prediction

# # [실무] tracker='botsort.yaml'로 동영상 객체 추적 (ID 유지)
results = model.track(source='video.mp4', tracker='botsort.yaml', persist=True)
```

### 7. Segmentation (분할)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
SAM(Segment Anything Model)은 프롬프트 기반 세그멘테이션 모델입니다.
- Point Prompt: 클릭한 위치의 객체 분할
- Box Prompt: 박스 영역의 객체 분할
- Mask Prompt: 기존 마스크 개선
"""
from segment_anything import SamPredictor, sam_model_registry
sam = sam_model_registry["vit_h"](checkpoint="sam_vit_h.pth")
predictor = SamPredictor(sam)

# # [개념] 이미지를 먼저 set_image로 인코딩해야 빠른 추론 가능
predictor.set_image(image)

"""
[Note] [실무]
YOLO-Seg는 YOLO + 세그멘테이션으로 실시간 인스턴스 분할 가능
- SAM: 프롬프트 기반, 정밀도 높음
- YOLO-Seg: 자동 탐지 + 분할, 속도 빠름
"""
from ultralytics import YOLO
model = YOLO('yolov8n-seg.pt')
results = model.predict(image)
```

#### 중급 (Intermediate)
```python
"""
[Note] [팁]
SAM의 multimask_output=True는 3개의 마스크 후보를 반환합니다.
uncertainty가 높은 경우 여러 옵션을 제공하여 best mask 선택 가능
"""
masks, scores, logits = predictor.predict(
    point_coords=points,
    point_labels=labels,
    multimask_output=True
)

# # [실무] supervision으로 세그멘테이션 마스크 시각화 및 병합
mask_annotator = sv.MaskAnnotator(color=sv.Color.GREEN, opacity=0.5)
annotated = mask_annotator.annotate(scene=image, detections=detections)

"""
[Note] [성능]
SAM의 vit_b < vit_l < vit_h 순으로 정확도 증가, 속도 감소
- vit_b: 실시간 처리 필요 시
- vit_h: 최고 정밀도 필요 시
"""
```

#### 고급 (Advanced)
```python
# # [성능] SAM2는 동영상 세그멘테이션 지원, temporal consistency 유지
from sam2.build_sam import build_sam2_video_predictor

# # [실무] FastSAM으로 SAM 속도 50배 향상 (YOLOv8 기반)
from ultralytics import FastSAM
model = FastSAM('FastSAM-x.pt')
```

### 8. Vision-Language Models (비전-언어 모델)

#### 초급 (Beginner)
```python
"""
[Note] [개념]
Florence-2는 Microsoft의 멀티태스크 비전 모델로 하나의 모델로 여러 작업 수행
- 캡셔닝: 이미지 설명 생성
- 객체 탐지: <OD> 태스크로 bounding box 추출
- OCR: <OCR> 태스크로 텍스트 인식
"""
from transformers import AutoProcessor, AutoModelForCausalLM
model = AutoModelForCausalLM.from_pretrained("microsoft/Florence-2-large")
processor = AutoProcessor.from_pretrained("microsoft/Florence-2-large")

# # [개념] task_prompt로 수행할 작업을 지정합니다
inputs = processor(text="<CAPTION>", images=image, return_tensors="pt")

"""
[Note] [실무]
PaliGemma는 Google의 VLM으로 자연어 질문에 답변합니다.
"What is in this image?"와 같은 open-ended question 처리 가능
"""
from transformers import PaliGemmaForConditionalGeneration
model = PaliGemmaForConditionalGeneration.from_pretrained("google/paligemma-3b-pt-224")
```

#### 중급 (Intermediate)
```python
"""
[Note] [팁]
Qwen2.5-VL은 다국어 지원 VLM으로 한국어 질문/답변 가능
- 이미지 이해도가 Florence-2/PaliGemma보다 높음
- 복잡한 시각적 추론 문제 해결
"""
from transformers import Qwen2VLForConditionalGeneration
model = Qwen2VLForConditionalGeneration.from_pretrained("Qwen/Qwen2.5-VL-7B-Instruct")

# # [실무] VLM 프롬프트 엔지니어링: 구체적인 질문일수록 정확도 향상
prompt = "이 이미지에서 빨간색 차량의 개수를 세어주세요."

"""
[Note] [성능]
Florence-2의 task prompt 최적화:
- <CAPTION>: 일반 설명
- <DETAILED_CAPTION>: 상세 설명
- <MORE_DETAILED_CAPTION>: 초상세 설명
task에 맞게 선택하여 추론 시간 단축
"""
inputs = processor(text="<DETAILED_CAPTION>", images=image, return_tensors="pt")
```

#### 고급 (Advanced)
```python
# # [성능] VLM의 batch inference로 다중 이미지 처리 속도 5-10배 향상
inputs = processor(text=prompts, images=images, return_tensors="pt", padding=True)

# # [실무] LLaVA-NeXT는 고해상도 이미지 처리에 특화 (최대 4096px)
from transformers import LlavaNextForConditionalGeneration
model = LlavaNextForConditionalGeneration.from_pretrained("llava-hf/llava-v1.6-mistral-7b-hf")
```

## Additional Insights Pool

### Data Handling
```python
# # [팁] ImageFolder는 디렉토리 구조를 자동으로 클래스 레이블로 인식합니다
dataset = datasets.ImageFolder(root='data/train')

# # [주의] 이미지 경로에 한글이 있으면 PIL에서 에러 발생 가능
# 영문 경로 사용 권장

"""
[Note] [실무]
train/val/test split 비율은 일반적으로 70/15/15 또는 80/10/10
데이터가 적으면 K-fold cross validation 사용
"""
train_size = int(0.8 * len(dataset))
```

### Optimization
```python
# # [성능] torch.set_float32_matmul_precision('high')로 A100에서 속도 20% 향상
torch.set_float32_matmul_precision('high')

"""
[Note] [팁]
AdamW는 Adam보다 weight decay를 올바르게 처리하여
일반화 성능이 1-2% 더 좋습니다.
"""
optimizer = torch.optim.AdamW(model.parameters(), lr=0.001, weight_decay=0.01)
```

### Debugging
```python
# # [디버깅] torch.autograd.set_detect_anomaly(True)로 NaN 발생 위치 추적
torch.autograd.set_detect_anomaly(True)

"""
[Note] [디버깅]
CUDA out of memory 에러 해결법:
1. batch_size 줄이기
2. 이미지 해상도 낮추기
3. gradient_accumulation 사용
4. model을 더 작은 것으로 변경
"""
```

### Model Architecture
```python
# # [개념] torchsummary로 모델 구조와 파라미터 수 확인
from torchsummary import summary
summary(model, input_size=(3, 224, 224))

"""
[Note] [실무]
Vision Transformer(ViT)는 ResNet보다 큰 데이터셋에서 성능이 좋지만
작은 데이터셋(<100k)에서는 ResNet/EfficientNet 권장
"""
```

---

**Total Insights**: 80+ Korean insights across all sections and levels (including Detection, Segmentation, VLM)

**Version**: 1.1.0
**Last Updated**: 2026-02-07
