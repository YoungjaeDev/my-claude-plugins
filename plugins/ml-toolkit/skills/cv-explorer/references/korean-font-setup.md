# Korean Font Setup for matplotlib

Guide for rendering Korean fonts correctly in matplotlib.

## Basic Setup

```python
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm

# Step 1: Search for system Korean fonts
korean_fonts = [
    f.name for f in fm.fontManager.ttflist
    if any(keyword in f.name.lower()
           for keyword in ['nanum', 'malgun', 'gothic', 'batang', 'gulim'])
]

if korean_fonts:
    plt.rcParams['font.family'] = korean_fonts[0]
    print(f"Korean font set: {korean_fonts[0]}")
else:
    print("No Korean font found. Installing NanumGothic...")
    import subprocess
    subprocess.run(['pip', 'install', '-q', 'fonts-nanum-gothic'], check=False)

    # Rebuild font cache
    fm._load_fontmanager(try_read_cache=False)

    plt.rcParams['font.family'] = 'NanumGothic'

# Step 2: Fix minus sign rendering (must be set after font.family)
plt.rcParams['axes.unicode_minus'] = False
```

## Important Notes

### Order Matters

```python
# Wrong order - style.use() overwrites rcParams
plt.rcParams['font.family'] = 'NanumGothic'
plt.style.use('seaborn-v0_8-whitegrid')  # This resets font.family!

# Correct order - style first, font second
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'NanumGothic'
plt.rcParams['axes.unicode_minus'] = False
```

### Environment Differences

| Environment | Default Korean Font | Install Required |
|-------------|---------------------|------------------|
| Ubuntu/Debian | None | `apt install fonts-nanum` or pip |
| macOS | Apple Gothic | Usually not needed |
| Windows | Malgun Gothic | Usually not needed |
| Google Colab | NanumGothic (pre-installed) | No |
| Kaggle | NanumBarunGothic | No |

### Font Cache Issues in Jupyter

After installing a font, the cache may not refresh and a kernel restart may be needed:

```python
# Force rebuild font cache (without kernel restart)
import matplotlib.font_manager as fm
fm._load_fontmanager(try_read_cache=False)
```

## Korean in ipywidgets HTML Widgets

`widgets.HTML()` in ipywidgets uses system fonts independently from matplotlib.
You need to specify fonts directly via CSS:

```python
html = widgets.HTML(f"""
<div style="font-family: 'NanumGothic', 'Malgun Gothic', 'Apple Gothic', sans-serif;">
    <h3>Dataset Statistics</h3>
    <p>Total images: {total_images}</p>
</div>
""")
```
