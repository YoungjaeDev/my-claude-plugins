#!/usr/bin/env python3
"""
GitHub Repository Search Script

Search GitHub repositories using the gh CLI.
Requires: gh CLI installed and authenticated (https://cli.github.com/)

Usage:
    python search_github.py "keyword" [options]

Examples:
    python search_github.py "object detection" --limit 10
    python search_github.py "gradio app" --language python
    python search_github.py "yolo world" --detailed --sort stars
"""

import argparse
import json
import subprocess
import sys
from typing import Optional


def check_gh_cli() -> bool:
    """Check if gh CLI is installed and authenticated."""
    try:
        result = subprocess.run(
            ["gh", "auth", "status"],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    except FileNotFoundError:
        return False


def search_repos(
    query: str,
    limit: int = 10,
    language: Optional[str] = None,
    sort: str = "stars",
    detailed: bool = False
) -> list[dict]:
    """
    Search GitHub repositories.

    Args:
        query: Search keyword
        limit: Maximum number of results
        language: Filter by programming language
        sort: Sort by 'stars', 'forks', or 'updated'
        detailed: Include detailed info (description, topics)

    Returns:
        List of repository information dictionaries
    """
    cmd = [
        "gh", "search", "repos", query,
        "--limit", str(limit),
        "--sort", sort,
        "--json", "fullName,description,stargazersCount,forksCount,updatedAt,language,url,isArchived"
    ]

    if language:
        cmd.extend(["--language", language])

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        repos = json.loads(result.stdout)
        return repos
    except subprocess.CalledProcessError as e:
        print(f"Error searching repositories: {e.stderr}", file=sys.stderr)
        return []
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}", file=sys.stderr)
        return []


def get_repo_details(repo_name: str) -> Optional[dict]:
    """
    Get detailed information about a repository.

    Args:
        repo_name: Repository full name (owner/repo)

    Returns:
        Repository details dictionary or None
    """
    cmd = [
        "gh", "repo", "view", repo_name,
        "--json", "name,owner,description,stargazersCount,forksCount,watchers,issues,pullRequests,url,homepageUrl,createdAt,updatedAt,pushedAt,isArchived,isFork,languages,repositoryTopics,licenseInfo,readme"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Error fetching repo details: {e.stderr}", file=sys.stderr)
        return None
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}", file=sys.stderr)
        return None


def format_repo_summary(repo: dict) -> str:
    """Format repository info as a summary string."""
    archived = " [ARCHIVED]" if repo.get("isArchived") else ""
    lang = repo.get("language") or "N/A"

    return (
        f"\n{'='*60}\n"
        f"{repo['fullName']}{archived}\n"
        f"{'='*60}\n"
        f"Stars: {repo['stargazersCount']:,} | Forks: {repo['forksCount']:,} | Language: {lang}\n"
        f"Updated: {repo['updatedAt'][:10]}\n"
        f"URL: {repo['url']}\n"
        f"\nDescription:\n{repo.get('description') or 'No description'}\n"
    )


def format_repo_detailed(details: dict) -> str:
    """Format detailed repository info."""
    topics = details.get("repositoryTopics", [])
    topic_names = [t.get("name", "") for t in topics] if topics else []

    languages = details.get("languages", [])
    lang_names = [l.get("node", {}).get("name", "") for l in languages] if languages else []

    license_info = details.get("licenseInfo")
    license_name = license_info.get("name", "N/A") if license_info else "N/A"

    readme = details.get("readme") or "No README available"
    # Truncate README if too long
    if len(readme) > 2000:
        readme = readme[:2000] + "\n... [truncated]"

    return (
        f"\n--- Detailed Info ---\n"
        f"Topics: {', '.join(topic_names) if topic_names else 'None'}\n"
        f"Languages: {', '.join(lang_names) if lang_names else 'N/A'}\n"
        f"License: {license_name}\n"
        f"Created: {details.get('createdAt', 'N/A')[:10]}\n"
        f"Last Push: {details.get('pushedAt', 'N/A')[:10]}\n"
        f"Open Issues: {details.get('issues', {}).get('totalCount', 'N/A')}\n"
        f"Open PRs: {details.get('pullRequests', {}).get('totalCount', 'N/A')}\n"
        f"\n--- README ---\n{readme}\n"
    )


def main():
    parser = argparse.ArgumentParser(
        description="Search GitHub repositories",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "object detection" --limit 10
  %(prog)s "gradio app" --language python
  %(prog)s "yolo world" --detailed --sort stars
        """
    )

    parser.add_argument("query", help="Search keyword")
    parser.add_argument("--limit", "-n", type=int, default=10, help="Number of results (default: 10)")
    parser.add_argument("--language", "-l", help="Filter by programming language")
    parser.add_argument("--sort", "-s", choices=["stars", "forks", "updated"], default="stars", help="Sort criteria (default: stars)")
    parser.add_argument("--detailed", "-d", action="store_true", help="Show detailed info including README")
    parser.add_argument("--json", "-j", action="store_true", help="Output as JSON")

    args = parser.parse_args()

    # Check gh CLI
    if not check_gh_cli():
        print("Error: gh CLI is not installed or not authenticated.", file=sys.stderr)
        print("Install: https://cli.github.com/", file=sys.stderr)
        print("Then run: gh auth login", file=sys.stderr)
        sys.exit(1)

    # Search repositories
    print(f"Searching GitHub for: '{args.query}'...\n", file=sys.stderr)
    repos = search_repos(
        query=args.query,
        limit=args.limit,
        language=args.language,
        sort=args.sort,
        detailed=args.detailed
    )

    if not repos:
        print("No repositories found.", file=sys.stderr)
        sys.exit(0)

    # Output results
    if args.json:
        print(json.dumps(repos, indent=2))
    else:
        print(f"Found {len(repos)} repositories:\n")

        for i, repo in enumerate(repos, 1):
            print(f"[{i}] {format_repo_summary(repo)}")

            if args.detailed:
                details = get_repo_details(repo["fullName"])
                if details:
                    print(format_repo_detailed(details))


if __name__ == "__main__":
    main()
