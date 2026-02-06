# Environment Setup Patterns

Complete, copy-paste ready code blocks for notebook environment detection and configuration.

## Colab

### GPU Detection
```python
import torch

# Check CUDA availability
print(f"CUDA Available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    device = torch.device("cuda")
    print(f"Device: {torch.cuda.get_device_name(0)}")
    print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
else:
    device = torch.device("cpu")
    print("Device: CPU")
```

### Secrets Management
```python
from google.colab import userdata

# Get API keys and secrets
api_key = userdata.get('API_KEY')
hf_token = userdata.get('HF_TOKEN')
wandb_key = userdata.get('WANDB_API_KEY')

# Use in environment
import os
os.environ['HUGGING_FACE_TOKEN'] = hf_token
```

### Drive Mount
```python
from google.colab import drive

# Mount Google Drive
drive.mount('/content/drive')

# Access files
data_dir = '/content/drive/MyDrive/datasets/imagenet'
model_dir = '/content/drive/MyDrive/models/checkpoints'
```

### Package Installation
```python
# Quiet install (no progress bars)
!pip install -q transformers datasets accelerate

# Specific versions
!pip install -q torch==2.1.0 torchvision==0.16.0

# From GitHub
!pip install -q git+https://github.com/huggingface/transformers.git

# With extras
!pip install -q "diffusers[torch]"
```

### Complete Colab Setup Cell
```python
# === COLAB ENVIRONMENT SETUP ===

# 1. GPU Detection
import torch
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

# 2. Install packages
!pip install -q transformers datasets accelerate wandb pillow opencv-python

# 3. Mount Drive
from google.colab import drive
drive.mount('/content/drive')

# 4. Load secrets
from google.colab import userdata
import os
os.environ['HUGGING_FACE_TOKEN'] = userdata.get('HF_TOKEN')
os.environ['WANDB_API_KEY'] = userdata.get('WANDB_API_KEY')

print("[OK] Colab environment ready")
```

---

## Kaggle

### GPU Detection
```python
import torch
import subprocess

# Check CUDA via PyTorch
print(f"CUDA Available: {torch.cuda.is_available()}")

# Check via nvidia-smi
try:
    result = subprocess.run(['nvidia-smi'], capture_output=True, text=True)
    print(result.stdout)
except FileNotFoundError:
    print("nvidia-smi not found (CPU environment)")

# Check environment variable
import os
cuda_devices = os.environ.get('CUDA_VISIBLE_DEVICES', 'Not set')
print(f"CUDA_VISIBLE_DEVICES: {cuda_devices}")

# Set device
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
```

### Secrets Management
```python
from kaggle_secrets import UserSecretsClient

# Initialize secrets client
user_secrets = UserSecretsClient()

# Get secrets (set in Kaggle Notebook Settings > Add-ons)
hf_token = user_secrets.get_secret("HF_TOKEN")
wandb_key = user_secrets.get_secret("WANDB_API_KEY")

# Use in environment
import os
os.environ['HUGGING_FACE_TOKEN'] = hf_token
os.environ['WANDB_API_KEY'] = wandb_key
```

### Offline Package Installation
```python
# Kaggle has pre-installed packages in /opt/conda/lib/python3.X/site-packages
# For offline install (no internet):

# 1. Download wheels to /kaggle/input/ dataset
# 2. Install from local directory
!pip install --no-index --find-links /kaggle/input/my-wheels/ transformers

# Check available packages
!pip list | grep torch
```

### Input Data Paths
```python
import os
from pathlib import Path

# Kaggle dataset inputs (read-only)
INPUT_DIR = Path('/kaggle/input')

# List available datasets
datasets = list(INPUT_DIR.iterdir())
print("Available datasets:")
for ds in datasets:
    print(f"  {ds.name}")

# Access specific dataset
dataset_path = INPUT_DIR / 'imagenet-object-localization-challenge' / 'ILSVRC/Data/CLS-LOC/train'
print(f"Dataset path: {dataset_path}")
print(f"Exists: {dataset_path.exists()}")

# Working directory (read-write, temporary)
WORKING_DIR = Path('/kaggle/working')
output_dir = WORKING_DIR / 'outputs'
output_dir.mkdir(exist_ok=True)
```

### Complete Kaggle Setup Cell
```python
# === KAGGLE ENVIRONMENT SETUP ===

# 1. GPU Detection
import torch
import os
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Device: {device}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"CUDA_VISIBLE_DEVICES: {os.environ.get('CUDA_VISIBLE_DEVICES', 'Not set')}")

# 2. Load secrets
from kaggle_secrets import UserSecretsClient
user_secrets = UserSecretsClient()
os.environ['HUGGING_FACE_TOKEN'] = user_secrets.get_secret("HF_TOKEN")
os.environ['WANDB_API_KEY'] = user_secrets.get_secret("WANDB_API_KEY")

# 3. Setup paths
from pathlib import Path
INPUT_DIR = Path('/kaggle/input')
WORKING_DIR = Path('/kaggle/working')
output_dir = WORKING_DIR / 'outputs'
output_dir.mkdir(exist_ok=True)

print(f"Input datasets: {list(INPUT_DIR.iterdir())}")
print(f"Output directory: {output_dir}")

# 4. Install additional packages (if needed)
# !pip install -q --no-index --find-links /kaggle/input/pip-packages/ package-name

print("[OK] Kaggle environment ready")
```

---

## Local

### GPU Detection
```python
import torch

# Assert GPU is available (fail fast if not)
assert torch.cuda.is_available(), "CUDA not available! Check GPU drivers and PyTorch installation."

device = torch.device("cuda")
print(f"Device: {torch.cuda.get_device_name(0)}")
print(f"CUDA Version: {torch.version.cuda}")
print(f"PyTorch Version: {torch.__version__}")
print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

# Multiple GPUs
if torch.cuda.device_count() > 1:
    print(f"Available GPUs: {torch.cuda.device_count()}")
    for i in range(torch.cuda.device_count()):
        print(f"  GPU {i}: {torch.cuda.get_device_name(i)}")
```

### Environment Variables
```python
import os
from pathlib import Path
from dotenv import load_dotenv

# Load from .env file
env_path = Path(__file__).parent / '.env'
load_dotenv(env_path)

# Get secrets
HF_TOKEN = os.getenv('HUGGING_FACE_TOKEN')
WANDB_API_KEY = os.getenv('WANDB_API_KEY')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

# Validate
assert HF_TOKEN is not None, "HUGGING_FACE_TOKEN not found in .env"
assert WANDB_API_KEY is not None, "WANDB_API_KEY not found in .env"

print("[OK] Environment variables loaded")
```

### .env Template
```bash
# .env file (add to .gitignore!)
HUGGING_FACE_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
WANDB_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optional
CUDA_VISIBLE_DEVICES=0
TORCH_HOME=/path/to/torch/cache
HF_HOME=/path/to/huggingface/cache
```

### Virtual Environment Setup

#### Using venv
```bash
# Create virtual environment
python -m venv .venv

# Activate
source .venv/bin/activate  # Linux/Mac
# .venv\Scripts\activate    # Windows

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Verify GPU support
python -c "import torch; print(torch.cuda.is_available())"
```

#### Using uv (fast)
```bash
# Install uv (if not installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create virtual environment
uv venv

# Activate
source .venv/bin/activate  # Linux/Mac
# .venv\Scripts\activate    # Windows

# Install dependencies (much faster than pip)
uv pip install -r requirements.txt

# Verify GPU support
python -c "import torch; print(torch.cuda.is_available())"
```

### requirements.txt Pattern
```txt
# Deep Learning Frameworks
torch==2.1.0
torchvision==0.16.0
torchaudio==2.1.0

# Transformers & NLP
transformers==4.36.0
datasets==2.16.0
tokenizers==0.15.0
accelerate==0.25.0

# Computer Vision
opencv-python==4.8.1.78
pillow==10.1.0
albumentations==1.3.1
timm==0.9.12

# Experiment Tracking
wandb==0.16.2
tensorboard==2.15.1

# Utilities
python-dotenv==1.0.0
tqdm==4.66.1
numpy==1.26.2
pandas==2.1.4
matplotlib==3.8.2
seaborn==0.13.0

# Optional: Jupyter
jupyter==1.0.0
ipywidgets==8.1.1
```

### Complete Local Setup Cell
```python
# === LOCAL ENVIRONMENT SETUP ===

# 1. Load environment variables
import os
from pathlib import Path
from dotenv import load_dotenv

env_path = Path(__file__).parent / '.env'
load_dotenv(env_path)

# 2. GPU Detection (fail fast)
import torch
assert torch.cuda.is_available(), "CUDA not available! Check GPU drivers."

device = torch.device("cuda")
print(f"Device: {torch.cuda.get_device_name(0)}")
print(f"CUDA Version: {torch.version.cuda}")
print(f"PyTorch Version: {torch.__version__}")

# 3. Set cache directories (optional)
os.environ['TORCH_HOME'] = str(Path.home() / '.cache/torch')
os.environ['HF_HOME'] = str(Path.home() / '.cache/huggingface')

# 4. Verify secrets
HF_TOKEN = os.getenv('HUGGING_FACE_TOKEN')
WANDB_API_KEY = os.getenv('WANDB_API_KEY')

assert HF_TOKEN is not None, "HUGGING_FACE_TOKEN not found in .env"
assert WANDB_API_KEY is not None, "WANDB_API_KEY not found in .env"

# 5. Setup project paths
PROJECT_ROOT = Path(__file__).parent
DATA_DIR = PROJECT_ROOT / 'data'
OUTPUT_DIR = PROJECT_ROOT / 'outputs'
CHECKPOINT_DIR = PROJECT_ROOT / 'checkpoints'

DATA_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)
CHECKPOINT_DIR.mkdir(exist_ok=True)

print("[OK] Local environment ready")
print(f"Project root: {PROJECT_ROOT}")
print(f"Data directory: {DATA_DIR}")
print(f"Output directory: {OUTPUT_DIR}")
```

---

## Environment Detection (Universal)

```python
def detect_environment():
    """
    Detect which environment the notebook is running in.

    Returns:
        str: 'colab', 'kaggle', or 'local'
    """
    import sys

    if 'google.colab' in sys.modules:
        return 'colab'
    elif 'kaggle_secrets' in sys.modules or os.path.exists('/kaggle'):
        return 'kaggle'
    else:
        return 'local'

# Usage
ENV = detect_environment()
print(f"Running in: {ENV}")

if ENV == 'colab':
    from google.colab import userdata
    HF_TOKEN = userdata.get('HF_TOKEN')
elif ENV == 'kaggle':
    from kaggle_secrets import UserSecretsClient
    HF_TOKEN = UserSecretsClient().get_secret('HF_TOKEN')
else:  # local
    from dotenv import load_dotenv
    load_dotenv()
    HF_TOKEN = os.getenv('HUGGING_FACE_TOKEN')
```

---

## Common Patterns

### Model Caching
```python
import os
from pathlib import Path

# Set cache directories before importing transformers/torch
if detect_environment() == 'colab':
    CACHE_DIR = Path('/content/drive/MyDrive/model_cache')
elif detect_environment() == 'kaggle':
    CACHE_DIR = Path('/kaggle/working/model_cache')
else:  # local
    CACHE_DIR = Path.home() / '.cache/huggingface'

CACHE_DIR.mkdir(parents=True, exist_ok=True)

os.environ['TRANSFORMERS_CACHE'] = str(CACHE_DIR)
os.environ['HF_HOME'] = str(CACHE_DIR)
os.environ['TORCH_HOME'] = str(CACHE_DIR / 'torch')

print(f"Cache directory: {CACHE_DIR}")
```

### Mixed Precision Setup
```python
import torch

# Check if AMP is available
if torch.cuda.is_available():
    # Enable TF32 for better performance on Ampere GPUs
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True

    # Check for mixed precision support
    if torch.cuda.get_device_capability()[0] >= 7:
        print("[OK] Mixed precision (FP16) supported")
        USE_AMP = True
    else:
        print("[WARN] Mixed precision not supported on this GPU")
        USE_AMP = False
else:
    USE_AMP = False
```

### Memory Management
```python
import torch
import gc

def cleanup_memory():
    """Force garbage collection and clear CUDA cache."""
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
        torch.cuda.synchronize()
    print("[OK] Memory cleaned")

def print_memory_stats():
    """Print current GPU memory usage."""
    if torch.cuda.is_available():
        allocated = torch.cuda.memory_allocated() / 1e9
        reserved = torch.cuda.memory_reserved() / 1e9
        print(f"GPU Memory - Allocated: {allocated:.2f} GB, Reserved: {reserved:.2f} GB")
    else:
        print("CPU-only mode")
```
