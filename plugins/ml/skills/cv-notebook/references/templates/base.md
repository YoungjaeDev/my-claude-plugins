# Base Notebook Template

Standard structure and templates for computer vision Jupyter notebooks.

## Standard Section Order

1. **Header** - Banner, badges, title, description
2. **Setup** - GPU check, library installation, imports
3. **Data** - Dataset loading, preprocessing, augmentation
4. **Model** - Architecture definition, loading pretrained weights
5. **Training** - Training loop, optimization, callbacks
6. **Evaluation** - Metrics, visualizations, confusion matrix
7. **Deployment** - Model export, inference examples, Gradio demo
8. **Conclusion** - Summary, next steps, references

## Cell Templates

### Header Template

```python
HEADER_TEMPLATE = """# {title}

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/{github_user}/{github_repo}/blob/main/{notebook_path})
[![GitHub](https://img.shields.io/badge/GitHub-View_on_GitHub-blue?logo=github)](https://github.com/{github_user}/{github_repo})

{description}

## Key Features
{features}

## Requirements
{requirements}
"""
```

### GPU Check Template

```python
GPU_CHECK_TEMPLATE = """import torch
import sys

print(f"Python: {{sys.version}}")
print(f"PyTorch: {{torch.__version__}}")
print(f"CUDA Available: {{torch.cuda.is_available()}}")
if torch.cuda.is_available():
    print(f"CUDA Version: {{torch.version.cuda}}")
    print(f"GPU Device: {{torch.cuda.get_device_name(0)}}")
    print(f"GPU Memory: {{torch.cuda.get_device_properties(0).total_memory / 1e9:.2f}} GB")
else:
    print("WARNING: Running on CPU. Training will be slow.")
"""
```

### Setup Template

```python
SETUP_TEMPLATE = """# Core libraries
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
from tqdm.auto import tqdm

# PyTorch
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import Dataset, DataLoader
import torchvision
import torchvision.transforms as T
from torchvision import models

# Utilities
import warnings
warnings.filterwarnings('ignore')

# Configuration
DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
SEED = 42

# Set random seeds for reproducibility
torch.manual_seed(SEED)
np.random.seed(SEED)
if torch.cuda.is_available():
    torch.cuda.manual_seed(SEED)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False

print(f"Using device: {{DEVICE}}")
"""
```

### Data Loading Template

```python
DATA_TEMPLATE = """# Dataset configuration
DATA_DIR = Path('{data_dir}')
BATCH_SIZE = {batch_size}
NUM_WORKERS = {num_workers}
IMG_SIZE = {img_size}

# Data transforms
train_transform = T.Compose([
    T.Resize((IMG_SIZE, IMG_SIZE)),
    T.RandomHorizontalFlip(p=0.5),
    T.RandomRotation(degrees=15),
    T.ColorJitter(brightness=0.2, contrast=0.2),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = T.Compose([
    T.Resize((IMG_SIZE, IMG_SIZE)),
    T.ToTensor(),
    T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# Load datasets
train_dataset = torchvision.datasets.ImageFolder(
    root=DATA_DIR / 'train',
    transform=train_transform
)

val_dataset = torchvision.datasets.ImageFolder(
    root=DATA_DIR / 'val',
    transform=val_transform
)

# Create dataloaders
train_loader = DataLoader(
    train_dataset,
    batch_size=BATCH_SIZE,
    shuffle=True,
    num_workers=NUM_WORKERS,
    pin_memory=True
)

val_loader = DataLoader(
    val_dataset,
    batch_size=BATCH_SIZE,
    shuffle=False,
    num_workers=NUM_WORKERS,
    pin_memory=True
)

print(f"Train samples: {{len(train_dataset)}}")
print(f"Val samples: {{len(val_dataset)}}")
print(f"Classes: {{train_dataset.classes}}")
"""
```

### Model Template

```python
MODEL_TEMPLATE = """# Model configuration
NUM_CLASSES = {num_classes}
MODEL_NAME = '{model_name}'

# Load pretrained model
model = models.{model_name}(pretrained=True)

# Modify final layer for our number of classes
if hasattr(model, 'fc'):
    in_features = model.fc.in_features
    model.fc = nn.Linear(in_features, NUM_CLASSES)
elif hasattr(model, 'classifier'):
    if isinstance(model.classifier, nn.Sequential):
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = nn.Linear(in_features, NUM_CLASSES)
    else:
        in_features = model.classifier.in_features
        model.classifier = nn.Linear(in_features, NUM_CLASSES)

model = model.to(DEVICE)
print(f"Model: {{MODEL_NAME}}")
print(f"Parameters: {{sum(p.numel() for p in model.parameters()):,}}")
"""
```

### Training Template

```python
TRAINING_TEMPLATE = """# Training configuration
NUM_EPOCHS = {num_epochs}
LEARNING_RATE = {learning_rate}

# Loss and optimizer
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=LEARNING_RATE)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
    optimizer, mode='min', factor=0.5, patience=3, verbose=True
)

# Training loop
history = {{'train_loss': [], 'train_acc': [], 'val_loss': [], 'val_acc': []}}
best_val_acc = 0.0

for epoch in range(NUM_EPOCHS):
    # Training phase
    model.train()
    train_loss = 0.0
    train_correct = 0
    train_total = 0

    for inputs, labels in tqdm(train_loader, desc=f'Epoch {{epoch+1}}/{{NUM_EPOCHS}} [Train]'):
        inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)

        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        train_loss += loss.item()
        _, predicted = outputs.max(1)
        train_total += labels.size(0)
        train_correct += predicted.eq(labels).sum().item()

    train_loss /= len(train_loader)
    train_acc = 100.0 * train_correct / train_total

    # Validation phase
    model.eval()
    val_loss = 0.0
    val_correct = 0
    val_total = 0

    with torch.no_grad():
        for inputs, labels in tqdm(val_loader, desc=f'Epoch {{epoch+1}}/{{NUM_EPOCHS}} [Val]'):
            inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)
            outputs = model(inputs)
            loss = criterion(outputs, labels)

            val_loss += loss.item()
            _, predicted = outputs.max(1)
            val_total += labels.size(0)
            val_correct += predicted.eq(labels).sum().item()

    val_loss /= len(val_loader)
    val_acc = 100.0 * val_correct / val_total

    # Update history
    history['train_loss'].append(train_loss)
    history['train_acc'].append(train_acc)
    history['val_loss'].append(val_loss)
    history['val_acc'].append(val_acc)

    # Learning rate scheduling
    scheduler.step(val_loss)

    # Save best model
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        torch.save(model.state_dict(), 'best_model.pth')
        print(f'[OK] Saved best model (val_acc: {{val_acc:.2f}}%)')

    print(f'Epoch {{epoch+1}}: train_loss={{train_loss:.4f}}, train_acc={{train_acc:.2f}}%, val_loss={{val_loss:.4f}}, val_acc={{val_acc:.2f}}%')
"""
```

### Evaluation Template

```python
EVALUATION_TEMPLATE = """# Load best model
model.load_state_dict(torch.load('best_model.pth'))
model.eval()

# Plot training history
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

# Loss plot
axes[0].plot(history['train_loss'], label='Train Loss', marker='o')
axes[0].plot(history['val_loss'], label='Val Loss', marker='s')
axes[0].set_xlabel('Epoch')
axes[0].set_ylabel('Loss')
axes[0].set_title('Training and Validation Loss')
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Accuracy plot
axes[1].plot(history['train_acc'], label='Train Acc', marker='o')
axes[1].plot(history['val_acc'], label='Val Acc', marker='s')
axes[1].set_xlabel('Epoch')
axes[1].set_ylabel('Accuracy (%)')
axes[1].set_title('Training and Validation Accuracy')
axes[1].legend()
axes[1].grid(True, alpha=0.3)

plt.tight_layout()
plt.show()

print(f"Best Validation Accuracy: {{max(history['val_acc']):.2f}}%")
"""
```

### Gradio Demo Template

```python
GRADIO_TEMPLATE = """try:
    import gradio as gr
except ImportError:
    !pip install -q gradio
    import gradio as gr

# Inference function
def predict(image):
    model.eval()

    # Preprocess
    transform = T.Compose([
        T.Resize((IMG_SIZE, IMG_SIZE)),
        T.ToTensor(),
        T.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])

    img_tensor = transform(image).unsqueeze(0).to(DEVICE)

    # Predict
    with torch.no_grad():
        outputs = model(img_tensor)
        probs = F.softmax(outputs, dim=1)[0]

    # Format results
    class_names = train_dataset.classes
    confidences = {{class_names[i]: float(probs[i]) for i in range(len(class_names))}}

    return confidences

# Create Gradio interface
demo = gr.Interface(
    fn=predict,
    inputs=gr.Image(type="pil"),
    outputs=gr.Label(num_top_classes={num_classes}),
    title="{title}",
    description="{description}",
    examples={examples}
)

# Launch
demo.launch(share=True)
"""
```

### Conclusion Template

```python
CONCLUSION_TEMPLATE = """## Summary

This notebook demonstrated:
- {summary_points}

## Results
- Best Validation Accuracy: **{best_acc:.2f}%**
- Total Training Time: {training_time}
- Model Size: {model_size}

## Next Steps
{next_steps}

## References
{references}
"""
```

## NotebookEdit Cell Management Strategy

### Sequential Generation Approach

When creating a new notebook:

1. **Initialize with header** (cell 0)
2. **Add cells sequentially** using `edit_mode="insert"` with `cell_id` pointing to previous cell
3. **Track cell IDs** as they're created for future edits

```python
# Step 1: Create header
NotebookEdit(
    notebook_path=path,
    cell_id=None,  # First cell
    cell_type="markdown",
    new_source=header_content,
    edit_mode="insert"
)

# Step 2: Add GPU check after header
NotebookEdit(
    notebook_path=path,
    cell_id="cell-0",  # Insert after header
    cell_type="code",
    new_source=gpu_check,
    edit_mode="insert"
)
```

### Cell ID Tracking

Maintain a map of logical sections to cell IDs:

```python
cell_map = {
    "header": "cell-0",
    "gpu_check": "cell-1",
    "setup": "cell-2",
    "data": "cell-3",
    "model": "cell-4",
    "training": "cell-5",
    "evaluation": "cell-6",
    "gradio": "cell-7",
    "conclusion": "cell-8"
}
```

### Section Markers

Add comments at the start of code cells to identify sections:

```python
source = f"# SECTION: {section_name}\n\n{template_content}"
```

This enables:
- Easy identification during modifications
- Grep-based searching for specific sections
- Clear notebook structure

### Modification Strategy for Existing Notebooks

1. **Read entire notebook** first
2. **Parse cell structure** to identify sections
3. **Use `edit_mode="replace"`** for updating existing cells
4. **Use `edit_mode="insert"`** for adding new sections
5. **Use `edit_mode="delete"`** for removing obsolete sections

```python
# Example: Update training configuration
NotebookEdit(
    notebook_path=path,
    cell_id=cell_map["training"],
    new_source=new_training_code,
    edit_mode="replace"
)
```

## Badge URLs

### Colab Badge

```
[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/{user}/{repo}/blob/main/{path})
```

### GitHub Badge

```
[![GitHub](https://img.shields.io/badge/GitHub-View_on_GitHub-blue?logo=github)](https://github.com/{user}/{repo})
```

### Common Shield Patterns

```
[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.0+-ee4c2c.svg)](https://pytorch.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
```

## Template Variable Conventions

All templates use `{variable_name}` for string formatting with Python's `.format()` method.

Common variables:
- `{title}` - Notebook title
- `{description}` - Brief description
- `{github_user}` - GitHub username
- `{github_repo}` - Repository name
- `{notebook_path}` - Path to .ipynb file
- `{data_dir}` - Dataset directory
- `{batch_size}` - Training batch size (default: 32)
- `{num_workers}` - DataLoader workers (default: 4)
- `{img_size}` - Image resolution (default: 224)
- `{num_classes}` - Number of output classes
- `{model_name}` - PyTorch model name (e.g., 'resnet50')
- `{num_epochs}` - Training epochs (default: 10)
- `{learning_rate}` - Learning rate (default: 0.001)
- `{best_acc}` - Best accuracy achieved
- `{training_time}` - Total training duration
- `{model_size}` - Model file size
- `{examples}` - List of example images for Gradio
- `{features}` - Bulleted list of key features
- `{requirements}` - Bulleted list of requirements
- `{summary_points}` - Bulleted summary
- `{next_steps}` - Bulleted next steps
- `{references}` - Bulleted references
