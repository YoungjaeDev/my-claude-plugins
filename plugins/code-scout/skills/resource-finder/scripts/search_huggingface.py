#!/usr/bin/env python3
"""
Hugging Face Search Script

Search Models, Datasets, and Spaces on Hugging Face Hub.
Requires: huggingface_hub library (pip install huggingface_hub)

Usage:
    python search_huggingface.py "keyword" --type {models,datasets,spaces,all}

Examples:
    python search_huggingface.py "object detection" --type models --limit 10
    python search_huggingface.py "coco" --type datasets --limit 5
    python search_huggingface.py "gradio demo" --type spaces --limit 10
    python search_huggingface.py "segment anything" --type all
"""

import argparse
import json
import sys
from typing import Optional

try:
    from huggingface_hub import HfApi, list_models, list_datasets, list_spaces
    HF_AVAILABLE = True
except ImportError:
    HF_AVAILABLE = False


def search_models(
    query: str,
    limit: int = 10,
    task: Optional[str] = None,
    library: Optional[str] = None
) -> list[dict]:
    """
    Search Hugging Face models.

    Args:
        query: Search keyword
        limit: Maximum number of results
        task: Filter by task (e.g., 'object-detection', 'image-segmentation')
        library: Filter by library (e.g., 'transformers', 'diffusers')

    Returns:
        List of model information dictionaries
    """
    api = HfApi()

    kwargs = {
        "search": query,
        "limit": limit,
        "sort": "downloads",
        "direction": -1,  # Descending
    }

    if task:
        kwargs["task"] = task
    if library:
        kwargs["library"] = library

    try:
        models = list(api.list_models(**kwargs))
        return [
            {
                "id": m.id,
                "author": m.author,
                "downloads": m.downloads,
                "likes": m.likes,
                "task": m.pipeline_tag,
                "library": m.library_name,
                "tags": m.tags[:10] if m.tags else [],
                "url": f"https://huggingface.co/{m.id}",
                "last_modified": str(m.last_modified) if m.last_modified else None,
            }
            for m in models
        ]
    except Exception as e:
        print(f"Error searching models: {e}", file=sys.stderr)
        return []


def search_datasets(
    query: str,
    limit: int = 10,
    task: Optional[str] = None
) -> list[dict]:
    """
    Search Hugging Face datasets.

    Args:
        query: Search keyword
        limit: Maximum number of results
        task: Filter by task category

    Returns:
        List of dataset information dictionaries
    """
    api = HfApi()

    kwargs = {
        "search": query,
        "limit": limit,
        "sort": "downloads",
        "direction": -1,
    }

    if task:
        kwargs["task_categories"] = task

    try:
        datasets = list(api.list_datasets(**kwargs))
        return [
            {
                "id": d.id,
                "author": d.author,
                "downloads": d.downloads,
                "likes": d.likes,
                "tags": d.tags[:10] if d.tags else [],
                "url": f"https://huggingface.co/datasets/{d.id}",
                "last_modified": str(d.last_modified) if d.last_modified else None,
            }
            for d in datasets
        ]
    except Exception as e:
        print(f"Error searching datasets: {e}", file=sys.stderr)
        return []


def search_spaces(
    query: str,
    limit: int = 10,
    sdk: Optional[str] = None
) -> list[dict]:
    """
    Search Hugging Face Spaces.

    Args:
        query: Search keyword
        limit: Maximum number of results
        sdk: Filter by SDK ('gradio', 'streamlit', 'docker', 'static')

    Returns:
        List of space information dictionaries
    """
    api = HfApi()

    kwargs = {
        "search": query,
        "limit": limit,
        "sort": "likes",
        "direction": -1,
    }

    if sdk:
        kwargs["sdk"] = sdk

    try:
        spaces = list(api.list_spaces(**kwargs))
        return [
            {
                "id": s.id,
                "author": s.author,
                "likes": s.likes,
                "sdk": s.sdk,
                "tags": s.tags[:10] if s.tags else [],
                "url": f"https://huggingface.co/spaces/{s.id}",
                "last_modified": str(s.last_modified) if s.last_modified else None,
            }
            for s in spaces
        ]
    except Exception as e:
        print(f"Error searching spaces: {e}", file=sys.stderr)
        return []


def format_model(model: dict, index: int) -> str:
    """Format model info as a summary string."""
    return (
        f"\n[{index}] MODEL: {model['id']}\n"
        f"    Downloads: {model['downloads']:,} | Likes: {model['likes']:,}\n"
        f"    Task: {model['task'] or 'N/A'} | Library: {model['library'] or 'N/A'}\n"
        f"    Tags: {', '.join(model['tags'][:5]) if model['tags'] else 'None'}\n"
        f"    URL: {model['url']}\n"
    )


def format_dataset(dataset: dict, index: int) -> str:
    """Format dataset info as a summary string."""
    return (
        f"\n[{index}] DATASET: {dataset['id']}\n"
        f"    Downloads: {dataset['downloads']:,} | Likes: {dataset['likes']:,}\n"
        f"    Tags: {', '.join(dataset['tags'][:5]) if dataset['tags'] else 'None'}\n"
        f"    URL: {dataset['url']}\n"
    )


def format_space(space: dict, index: int) -> str:
    """Format space info as a summary string."""
    return (
        f"\n[{index}] SPACE: {space['id']}\n"
        f"    Likes: {space['likes']:,} | SDK: {space['sdk'] or 'N/A'}\n"
        f"    Tags: {', '.join(space['tags'][:5]) if space['tags'] else 'None'}\n"
        f"    URL: {space['url']}\n"
    )


def main():
    parser = argparse.ArgumentParser(
        description="Search Hugging Face Hub (Models, Datasets, Spaces)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "object detection" --type models --limit 10
  %(prog)s "coco" --type datasets --limit 5
  %(prog)s "gradio demo" --type spaces --limit 10
  %(prog)s "segment anything" --type all

Tasks (for --task filter):
  Models: object-detection, image-segmentation, image-classification, etc.
  Datasets: object-detection, image-classification, etc.

SDKs (for --sdk filter):
  gradio, streamlit, docker, static
        """
    )

    parser.add_argument("query", help="Search keyword")
    parser.add_argument("--type", "-t", choices=["models", "datasets", "spaces", "all"], default="all", help="Resource type to search (default: all)")
    parser.add_argument("--limit", "-n", type=int, default=10, help="Number of results per type (default: 10)")
    parser.add_argument("--task", help="Filter by task (models/datasets only)")
    parser.add_argument("--library", help="Filter by library (models only)")
    parser.add_argument("--sdk", help="Filter by SDK (spaces only): gradio, streamlit, docker, static")
    parser.add_argument("--json", "-j", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # Check huggingface_hub
    if not HF_AVAILABLE:
        print("Error: huggingface_hub is not installed.", file=sys.stderr)
        print("Install: pip install huggingface_hub", file=sys.stderr)
        sys.exit(1)

    results = {}

    # Search based on type
    if args.type in ["models", "all"]:
        print(f"Searching Models for: '{args.query}'...", file=sys.stderr)
        results["models"] = search_models(
            query=args.query,
            limit=args.limit,
            task=args.task,
            library=args.library
        )

    if args.type in ["datasets", "all"]:
        print(f"Searching Datasets for: '{args.query}'...", file=sys.stderr)
        results["datasets"] = search_datasets(
            query=args.query,
            limit=args.limit,
            task=args.task
        )

    if args.type in ["spaces", "all"]:
        print(f"Searching Spaces for: '{args.query}'...", file=sys.stderr)
        results["spaces"] = search_spaces(
            query=args.query,
            limit=args.limit,
            sdk=args.sdk
        )

    # Output results
    if args.json:
        print(json.dumps(results, indent=2, default=str))
    else:
        print(f"\n{'='*60}")
        print(f"Hugging Face Search Results for: '{args.query}'")
        print(f"{'='*60}")

        if "models" in results:
            print(f"\n--- MODELS ({len(results['models'])} found) ---")
            if results["models"]:
                for i, model in enumerate(results["models"], 1):
                    print(format_model(model, i))
            else:
                print("  No models found.")

        if "datasets" in results:
            print(f"\n--- DATASETS ({len(results['datasets'])} found) ---")
            if results["datasets"]:
                for i, dataset in enumerate(results["datasets"], 1):
                    print(format_dataset(dataset, i))
            else:
                print("  No datasets found.")

        if "spaces" in results:
            print(f"\n--- SPACES ({len(results['spaces'])} found) ---")
            if results["spaces"]:
                for i, space in enumerate(results["spaces"], 1):
                    print(format_space(space, i))
            else:
                print("  No spaces found.")


if __name__ == "__main__":
    main()
