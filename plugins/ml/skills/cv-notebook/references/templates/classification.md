# Image Classification - Notebook Cell Templates

Complete, copy-paste ready code cells for classification tasks.

---

## 1. Model Loading

### DINOv2 (torch.hub)
```python
import torch
import torchvision.transforms as T
from PIL import Image

# Load DINOv2 model
model = torch.hub.load('facebookresearch/dinov2', 'dinov2_vits14')
model.eval()
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

# Transform for DINOv2
transform = T.Compose([
    T.Resize(256),
    T.CenterCrop(224),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

print(f"DINOv2 loaded on {device}")
```

### DINOv2 (transformers)
```python
from transformers import AutoImageProcessor, AutoModel
import torch
from PIL import Image

model_name = "facebook/dinov2-base"
processor = AutoImageProcessor.from_pretrained(model_name)
model = AutoModel.from_pretrained(model_name)

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)
model.eval()

print(f"DINOv2 (transformers) loaded on {device}")
```

### ResNet (torchvision)
```python
import torch
import torchvision.models as models
import torchvision.transforms as T

# Load pretrained ResNet50
model = models.resnet50(pretrained=True)
model.eval()
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

# Standard ImageNet transform
transform = T.Compose([
    T.Resize(256),
    T.CenterCrop(224),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Load ImageNet class names
import urllib
url = "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
with urllib.request.urlopen(url) as f:
    imagenet_classes = [line.decode('utf-8').strip() for line in f.readlines()]

print(f"ResNet50 loaded with {len(imagenet_classes)} classes")
```

### Vision Transformer (timm)
```python
import timm
import torch
from timm.data import resolve_data_config
from timm.data.transforms_factory import create_transform

# Load ViT model from timm
model = timm.create_model('vit_base_patch16_224', pretrained=True)
model.eval()
device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

# Get model-specific transform
config = resolve_data_config({}, model=model)
transform = create_transform(**config)

print(f"ViT loaded on {device}")
print(f"Input size: {config['input_size']}")
```

### YOLO-Cls (ultralytics)
```python
from ultralytics import YOLO
import torch

# Load YOLO classification model
model = YOLO('yolov8n-cls.pt')  # or yolov8s-cls, yolov8m-cls, yolov8l-cls, yolov8x-cls

device = 'cuda' if torch.cuda.is_available() else 'cpu'
model.to(device)

print(f"YOLO-Cls loaded on {device}")
print(f"Model: {model.model_name}")
```

---

## 2. Inference

### Single Image Classification
```python
from PIL import Image
import torch.nn.functional as F

# Load and preprocess image
image_path = "path/to/image.jpg"
image = Image.open(image_path).convert('RGB')
input_tensor = transform(image).unsqueeze(0).to(device)

# Inference
with torch.no_grad():
    outputs = model(input_tensor)
    probabilities = F.softmax(outputs, dim=1)

# Get top prediction
confidence, predicted_idx = torch.max(probabilities, 1)
predicted_class = imagenet_classes[predicted_idx.item()]

print(f"Predicted: {predicted_class}")
print(f"Confidence: {confidence.item():.4f}")
```

### Top-K Predictions
```python
import torch.nn.functional as F

def predict_topk(image_path, model, transform, class_names, k=5):
    image = Image.open(image_path).convert('RGB')
    input_tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        outputs = model(input_tensor)
        probabilities = F.softmax(outputs, dim=1)

    # Get top-k predictions
    top_probs, top_indices = torch.topk(probabilities, k)

    results = []
    for prob, idx in zip(top_probs[0], top_indices[0]):
        results.append({
            'class': class_names[idx.item()],
            'probability': prob.item()
        })

    return results

# Usage
top5 = predict_topk("path/to/image.jpg", model, transform, imagenet_classes, k=5)
for i, result in enumerate(top5, 1):
    print(f"{i}. {result['class']}: {result['probability']:.4f}")
```

### Batch Inference
```python
from torch.utils.data import DataLoader
from torchvision.datasets import ImageFolder
from tqdm import tqdm

# Prepare dataset
test_dataset = ImageFolder(root='path/to/test_images', transform=transform)
test_loader = DataLoader(test_dataset, batch_size=32, shuffle=False, num_workers=4)

# Batch inference
all_predictions = []
all_labels = []

model.eval()
with torch.no_grad():
    for images, labels in tqdm(test_loader, desc="Inference"):
        images = images.to(device)
        outputs = model(images)
        probabilities = F.softmax(outputs, dim=1)
        _, predicted = torch.max(probabilities, 1)

        all_predictions.extend(predicted.cpu().numpy())
        all_labels.extend(labels.numpy())

print(f"Processed {len(all_predictions)} images")
```

### YOLO-Cls Inference
```python
# Single image
results = model.predict('path/to/image.jpg', conf=0.25)

for r in results:
    probs = r.probs  # classification probabilities
    top1_idx = probs.top1  # top1 class index
    top1_conf = probs.top1conf.item()  # top1 confidence
    top5_idx = probs.top5  # top5 class indices
    top5_conf = probs.top5conf  # top5 confidences

    print(f"Top prediction: {model.names[top1_idx]} ({top1_conf:.4f})")

    # Show top-5
    print("\nTop-5 predictions:")
    for idx, conf in zip(top5_idx, top5_conf):
        print(f"  {model.names[idx]}: {conf:.4f}")
```

---

## 3. Visualization

### Probability Bar Chart
```python
import matplotlib.pyplot as plt
import numpy as np

def plot_predictions(predictions, title="Top-K Predictions"):
    """
    predictions: list of dicts with 'class' and 'probability' keys
    """
    classes = [p['class'] for p in predictions]
    probs = [p['probability'] for p in predictions]

    plt.figure(figsize=(10, 6))
    y_pos = np.arange(len(classes))
    plt.barh(y_pos, probs, color='steelblue')
    plt.yticks(y_pos, classes)
    plt.xlabel('Probability')
    plt.title(title)
    plt.xlim(0, 1)
    plt.tight_layout()
    plt.show()

# Usage
plot_predictions(top5, title="Top-5 Predictions")
```

### Image with Predictions
```python
import matplotlib.pyplot as plt
from PIL import Image

def visualize_prediction(image_path, predictions):
    """Display image with top predictions overlay"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))

    # Show image
    image = Image.open(image_path)
    ax1.imshow(image)
    ax1.axis('off')
    ax1.set_title('Input Image')

    # Show predictions
    classes = [p['class'] for p in predictions]
    probs = [p['probability'] for p in predictions]
    y_pos = np.arange(len(classes))

    ax2.barh(y_pos, probs, color='steelblue')
    ax2.set_yticks(y_pos)
    ax2.set_yticklabels(classes)
    ax2.set_xlabel('Probability')
    ax2.set_title('Top Predictions')
    ax2.set_xlim(0, 1)

    plt.tight_layout()
    plt.show()

# Usage
visualize_prediction("path/to/image.jpg", top5)
```

### Prediction Grid
```python
import matplotlib.pyplot as plt
from PIL import Image
import os

def plot_prediction_grid(image_dir, model, transform, class_names, n_images=9):
    """Display grid of images with predictions"""
    image_files = [f for f in os.listdir(image_dir) if f.endswith(('.jpg', '.png'))][:n_images]

    cols = 3
    rows = (n_images + cols - 1) // cols

    fig, axes = plt.subplots(rows, cols, figsize=(15, 5*rows))
    axes = axes.flatten()

    for idx, img_file in enumerate(image_files):
        img_path = os.path.join(image_dir, img_file)
        image = Image.open(img_path).convert('RGB')

        # Predict
        input_tensor = transform(image).unsqueeze(0).to(device)
        with torch.no_grad():
            outputs = model(input_tensor)
            probs = F.softmax(outputs, dim=1)
            conf, pred_idx = torch.max(probs, 1)

        # Display
        axes[idx].imshow(image)
        axes[idx].axis('off')
        pred_class = class_names[pred_idx.item()]
        axes[idx].set_title(f"{pred_class}\n{conf.item():.3f}", fontsize=10)

    # Hide extra subplots
    for idx in range(len(image_files), len(axes)):
        axes[idx].axis('off')

    plt.tight_layout()
    plt.show()

# Usage
plot_prediction_grid('path/to/images', model, transform, imagenet_classes, n_images=9)
```

---

## 4. Dataset Preparation

### ImageFolder Structure
```python
from torchvision.datasets import ImageFolder
import torchvision.transforms as T
from torch.utils.data import DataLoader

# Define transforms
train_transform = T.Compose([
    T.Resize(256),
    T.RandomResizedCrop(224),
    T.RandomHorizontalFlip(),
    T.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = T.Compose([
    T.Resize(256),
    T.CenterCrop(224),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Expected structure:
# data/
#   train/
#     class1/
#       img1.jpg
#       img2.jpg
#     class2/
#       img1.jpg
#   val/
#     class1/
#     class2/

train_dataset = ImageFolder(root='data/train', transform=train_transform)
val_dataset = ImageFolder(root='data/val', transform=val_transform)

train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True, num_workers=4)
val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False, num_workers=4)

print(f"Classes: {train_dataset.classes}")
print(f"Train samples: {len(train_dataset)}")
print(f"Val samples: {len(val_dataset)}")
```

### Roboflow Classification Dataset
```python
from roboflow import Roboflow

# Initialize Roboflow
rf = Roboflow(api_key="YOUR_API_KEY")
project = rf.workspace("workspace-name").project("project-name")
dataset = project.version(1).download("folder")

# Dataset will be downloaded to:
# {project-name}-{version}/
#   train/
#   valid/
#   test/

# Create datasets
from torchvision.datasets import ImageFolder

train_dataset = ImageFolder(
    root=f'{dataset.location}/train',
    transform=train_transform
)

val_dataset = ImageFolder(
    root=f'{dataset.location}/valid',
    transform=val_transform
)

print(f"Downloaded {len(train_dataset)} training images")
print(f"Classes: {train_dataset.classes}")
```

### Custom Dataset with Data Augmentation
```python
import torch
from torch.utils.data import Dataset
from PIL import Image
import os
import albumentations as A
from albumentations.pytorch import ToTensorV2

class CustomClassificationDataset(Dataset):
    def __init__(self, root_dir, transform=None, use_albumentations=False):
        self.root_dir = root_dir
        self.use_albumentations = use_albumentations

        # Get class folders
        self.classes = sorted(os.listdir(root_dir))
        self.class_to_idx = {cls: idx for idx, cls in enumerate(self.classes)}

        # Build image list
        self.images = []
        for cls in self.classes:
            cls_dir = os.path.join(root_dir, cls)
            for img_name in os.listdir(cls_dir):
                if img_name.endswith(('.jpg', '.png', '.jpeg')):
                    self.images.append({
                        'path': os.path.join(cls_dir, img_name),
                        'label': self.class_to_idx[cls]
                    })

        self.transform = transform

    def __len__(self):
        return len(self.images)

    def __getitem__(self, idx):
        img_info = self.images[idx]
        image = Image.open(img_info['path']).convert('RGB')
        label = img_info['label']

        if self.use_albumentations:
            import numpy as np
            image = np.array(image)
            if self.transform:
                transformed = self.transform(image=image)
                image = transformed['image']
        else:
            if self.transform:
                image = self.transform(image)

        return image, label

# Albumentations transforms
train_transform_albu = A.Compose([
    A.Resize(256, 256),
    A.RandomCrop(224, 224),
    A.HorizontalFlip(p=0.5),
    A.ShiftScaleRotate(shift_limit=0.1, scale_limit=0.2, rotate_limit=15, p=0.5),
    A.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.1, p=0.5),
    A.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ToTensorV2()
])

# Usage
train_dataset = CustomClassificationDataset(
    root_dir='data/train',
    transform=train_transform_albu,
    use_albumentations=True
)
```

---

## 5. Training

### Fine-Tuning Pretrained Model
```python
import torch
import torch.nn as nn
import torch.optim as optim
from torch.optim.lr_scheduler import ReduceLROnPlateau
from tqdm import tqdm

# Modify model for custom classes
num_classes = len(train_dataset.classes)
model = models.resnet50(pretrained=True)

# Freeze early layers
for param in model.parameters():
    param.requires_grad = False

# Replace final layer
num_ftrs = model.fc.in_features
model.fc = nn.Linear(num_ftrs, num_classes)

model = model.to(device)

# Training setup
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.fc.parameters(), lr=0.001)
scheduler = ReduceLROnPlateau(optimizer, mode='min', factor=0.1, patience=3, verbose=True)

print(f"Training for {num_classes} classes")
print(f"Trainable parameters: {sum(p.numel() for p in model.parameters() if p.requires_grad)}")
```

### Training Loop with Progress
```python
def train_epoch(model, train_loader, criterion, optimizer, device):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0

    pbar = tqdm(train_loader, desc="Training")
    for images, labels in pbar:
        images, labels = images.to(device), labels.to(device)

        # Forward pass
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)

        # Backward pass
        loss.backward()
        optimizer.step()

        # Statistics
        running_loss += loss.item()
        _, predicted = torch.max(outputs.data, 1)
        total += labels.size(0)
        correct += (predicted == labels).sum().item()

        pbar.set_postfix({
            'loss': f'{running_loss/len(pbar):.4f}',
            'acc': f'{100.*correct/total:.2f}%'
        })

    epoch_loss = running_loss / len(train_loader)
    epoch_acc = 100. * correct / total
    return epoch_loss, epoch_acc

def validate(model, val_loader, criterion, device):
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0

    with torch.no_grad():
        pbar = tqdm(val_loader, desc="Validation")
        for images, labels in pbar:
            images, labels = images.to(device), labels.to(device)

            outputs = model(images)
            loss = criterion(outputs, labels)

            running_loss += loss.item()
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()

            pbar.set_postfix({
                'loss': f'{running_loss/len(pbar):.4f}',
                'acc': f'{100.*correct/total:.2f}%'
            })

    epoch_loss = running_loss / len(val_loader)
    epoch_acc = 100. * correct / total
    return epoch_loss, epoch_acc

# Training loop
num_epochs = 10
best_val_acc = 0.0

for epoch in range(num_epochs):
    print(f"\nEpoch {epoch+1}/{num_epochs}")

    train_loss, train_acc = train_epoch(model, train_loader, criterion, optimizer, device)
    val_loss, val_acc = validate(model, val_loader, criterion, device)

    print(f"Train Loss: {train_loss:.4f}, Train Acc: {train_acc:.2f}%")
    print(f"Val Loss: {val_loss:.4f}, Val Acc: {val_acc:.2f}%")

    # Learning rate scheduling
    scheduler.step(val_loss)

    # Save best model
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        torch.save(model.state_dict(), 'best_model.pth')
        print(f"Saved best model with val_acc: {val_acc:.2f}%")

print(f"\nTraining complete. Best val_acc: {best_val_acc:.2f}%")
```

### Training with Early Stopping
```python
class EarlyStopping:
    def __init__(self, patience=5, min_delta=0, verbose=True):
        self.patience = patience
        self.min_delta = min_delta
        self.verbose = verbose
        self.counter = 0
        self.best_loss = None
        self.early_stop = False

    def __call__(self, val_loss):
        if self.best_loss is None:
            self.best_loss = val_loss
        elif val_loss > self.best_loss - self.min_delta:
            self.counter += 1
            if self.verbose:
                print(f"EarlyStopping counter: {self.counter}/{self.patience}")
            if self.counter >= self.patience:
                self.early_stop = True
        else:
            self.best_loss = val_loss
            self.counter = 0

# Usage
early_stopping = EarlyStopping(patience=5, verbose=True)

for epoch in range(num_epochs):
    train_loss, train_acc = train_epoch(model, train_loader, criterion, optimizer, device)
    val_loss, val_acc = validate(model, val_loader, criterion, device)

    print(f"Epoch {epoch+1}: Train Loss={train_loss:.4f}, Val Loss={val_loss:.4f}")

    scheduler.step(val_loss)
    early_stopping(val_loss)

    if early_stopping.early_stop:
        print("Early stopping triggered")
        break
```

### YOLO-Cls Training
```python
from ultralytics import YOLO

# Load pretrained model
model = YOLO('yolov8n-cls.pt')

# Train
results = model.train(
    data='path/to/dataset',  # ImageFolder structure
    epochs=50,
    imgsz=224,
    batch=32,
    device=0,  # GPU 0
    workers=8,
    optimizer='AdamW',
    lr0=0.001,
    patience=10,
    save=True,
    project='runs/classify',
    name='exp'
)

# Validate
metrics = model.val()
print(f"Top-1 Accuracy: {metrics.top1:.4f}")
print(f"Top-5 Accuracy: {metrics.top5:.4f}")
```

---

## 6. Evaluation

### Accuracy Metrics
```python
from sklearn.metrics import accuracy_score, precision_recall_fscore_support

# Get predictions and labels from validation set
all_predictions = []
all_labels = []

model.eval()
with torch.no_grad():
    for images, labels in val_loader:
        images = images.to(device)
        outputs = model(images)
        _, predicted = torch.max(outputs, 1)

        all_predictions.extend(predicted.cpu().numpy())
        all_labels.extend(labels.numpy())

# Calculate metrics
accuracy = accuracy_score(all_labels, all_predictions)
precision, recall, f1, support = precision_recall_fscore_support(
    all_labels, all_predictions, average='weighted'
)

print(f"Accuracy: {accuracy:.4f}")
print(f"Precision: {precision:.4f}")
print(f"Recall: {recall:.4f}")
print(f"F1 Score: {f1:.4f}")
```

### Confusion Matrix
```python
from sklearn.metrics import confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt

# Compute confusion matrix
cm = confusion_matrix(all_labels, all_predictions)

# Plot
plt.figure(figsize=(12, 10))
sns.heatmap(
    cm,
    annot=True,
    fmt='d',
    cmap='Blues',
    xticklabels=train_dataset.classes,
    yticklabels=train_dataset.classes
)
plt.xlabel('Predicted')
plt.ylabel('True')
plt.title('Confusion Matrix')
plt.tight_layout()
plt.show()

# Normalized confusion matrix
cm_normalized = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]

plt.figure(figsize=(12, 10))
sns.heatmap(
    cm_normalized,
    annot=True,
    fmt='.2f',
    cmap='Blues',
    xticklabels=train_dataset.classes,
    yticklabels=train_dataset.classes
)
plt.xlabel('Predicted')
plt.ylabel('True')
plt.title('Normalized Confusion Matrix')
plt.tight_layout()
plt.show()
```

### Classification Report
```python
from sklearn.metrics import classification_report

# Generate detailed report
report = classification_report(
    all_labels,
    all_predictions,
    target_names=train_dataset.classes,
    digits=4
)

print("Classification Report:")
print(report)

# Save to file
with open('classification_report.txt', 'w') as f:
    f.write(report)
```

### Per-Class Analysis
```python
import pandas as pd
from sklearn.metrics import precision_recall_fscore_support

# Calculate per-class metrics
precision, recall, f1, support = precision_recall_fscore_support(
    all_labels,
    all_predictions,
    average=None
)

# Create DataFrame
metrics_df = pd.DataFrame({
    'Class': train_dataset.classes,
    'Precision': precision,
    'Recall': recall,
    'F1-Score': f1,
    'Support': support
})

# Sort by F1-Score
metrics_df = metrics_df.sort_values('F1-Score', ascending=False)

print(metrics_df.to_string(index=False))

# Visualize per-class F1 scores
plt.figure(figsize=(12, 6))
plt.barh(metrics_df['Class'], metrics_df['F1-Score'], color='steelblue')
plt.xlabel('F1-Score')
plt.ylabel('Class')
plt.title('Per-Class F1-Score')
plt.xlim(0, 1)
plt.tight_layout()
plt.show()
```

### ROC Curve (Binary Classification)
```python
from sklearn.metrics import roc_curve, auc
import matplotlib.pyplot as plt

# For binary classification only
if len(train_dataset.classes) == 2:
    # Get probability scores for positive class
    all_probs = []

    model.eval()
    with torch.no_grad():
        for images, labels in val_loader:
            images = images.to(device)
            outputs = model(images)
            probs = F.softmax(outputs, dim=1)
            all_probs.extend(probs[:, 1].cpu().numpy())  # Positive class probs

    # Calculate ROC curve
    fpr, tpr, thresholds = roc_curve(all_labels, all_probs)
    roc_auc = auc(fpr, tpr)

    # Plot
    plt.figure(figsize=(8, 6))
    plt.plot(fpr, tpr, color='darkorange', lw=2, label=f'ROC curve (AUC = {roc_auc:.2f})')
    plt.plot([0, 1], [0, 1], color='navy', lw=2, linestyle='--', label='Random classifier')
    plt.xlim([0.0, 1.0])
    plt.ylim([0.0, 1.05])
    plt.xlabel('False Positive Rate')
    plt.ylabel('True Positive Rate')
    plt.title('Receiver Operating Characteristic (ROC)')
    plt.legend(loc="lower right")
    plt.grid(alpha=0.3)
    plt.tight_layout()
    plt.show()
```

### Error Analysis
```python
import matplotlib.pyplot as plt
from PIL import Image
import os

def find_misclassified_samples(model, val_dataset, device, n_samples=16):
    """Find and visualize misclassified samples"""
    model.eval()
    misclassified = []

    with torch.no_grad():
        for idx in range(len(val_dataset)):
            image, true_label = val_dataset[idx]
            image_tensor = image.unsqueeze(0).to(device)

            outputs = model(image_tensor)
            _, predicted = torch.max(outputs, 1)

            if predicted.item() != true_label:
                # Get probabilities
                probs = F.softmax(outputs, dim=1)
                misclassified.append({
                    'idx': idx,
                    'true_label': true_label,
                    'predicted_label': predicted.item(),
                    'confidence': probs[0, predicted.item()].item(),
                    'true_prob': probs[0, true_label].item()
                })

            if len(misclassified) >= n_samples:
                break

    return misclassified

# Find misclassified samples
errors = find_misclassified_samples(model, val_dataset, device, n_samples=16)

# Visualize
fig, axes = plt.subplots(4, 4, figsize=(16, 16))
axes = axes.flatten()

for idx, error in enumerate(errors[:16]):
    # Get original image (before transform)
    img_path = val_dataset.samples[error['idx']][0]
    image = Image.open(img_path).convert('RGB')

    axes[idx].imshow(image)
    axes[idx].axis('off')

    true_class = val_dataset.classes[error['true_label']]
    pred_class = val_dataset.classes[error['predicted_label']]

    title = f"True: {true_class}\nPred: {pred_class}\nConf: {error['confidence']:.3f}"
    axes[idx].set_title(title, fontsize=9, color='red')

plt.tight_layout()
plt.show()

print(f"Found {len(errors)} misclassified samples")
```

---

## Quick Start Example

Complete end-to-end classification pipeline:

```python
# 1. Load model
import torch
import torchvision.models as models
import torchvision.transforms as T
from torchvision.datasets import ImageFolder
from torch.utils.data import DataLoader
import torch.nn as nn
import torch.optim as optim

device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = models.resnet50(pretrained=True)

# 2. Prepare data
train_transform = T.Compose([
    T.Resize(256), T.RandomCrop(224), T.RandomHorizontalFlip(),
    T.ToTensor(), T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])

train_dataset = ImageFolder('data/train', transform=train_transform)
train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)

# 3. Modify for custom classes
num_classes = len(train_dataset.classes)
model.fc = nn.Linear(model.fc.in_features, num_classes)
model = model.to(device)

# 4. Train
criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)

# 5. Inference
from PIL import Image
image = Image.open('test.jpg')
input_tensor = train_transform(image).unsqueeze(0).to(device)

model.eval()
with torch.no_grad():
    outputs = model(input_tensor)
    _, predicted = torch.max(outputs, 1)
    print(f"Predicted: {train_dataset.classes[predicted.item()]}")
```
