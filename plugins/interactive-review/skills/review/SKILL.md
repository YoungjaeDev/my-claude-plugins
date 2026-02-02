---
name: review
description: Interactive markdown review with web UI. Use when user says "review this", "check this plan", "피드백", "검토해줘" or specifies a file path to review.
allowed-tools:
  - mcp__interactive_review__start_review
  - Read
---

# Interactive Review Skill

This skill opens an interactive web UI where users can review content with checkboxes and comments.

## How It Works

1. Determine the content source:
   - **If user specifies a file path**: Use the `Read` tool to get the file contents
   - **If user provides content directly**: Use that content as-is
   - **Otherwise**: Collect the most recent relevant content from the conversation
2. Call `mcp__interactive_review__start_review` with the content
3. A browser window opens automatically with the review UI
4. User reviews each item:
   - Check/uncheck to approve/reject
   - Add optional comments
5. User clicks Submit
6. Process the feedback and respond accordingly

## Content Sources (Priority Order)

1. **Explicit file path**: User says "review /path/to/file.md" or "이 파일 리뷰해줘: README.md"
   - Read the file using `Read` tool and use its contents
2. **Direct content**: User provides or references specific content to review
   - Use the provided content directly
3. **Conversation context**: Extract relevant content from recent conversation
   - Plans, documents, code, etc. that were recently discussed

## Usage

When the user wants to review content:

```
# If file path is specified, read it first:
Read({ "file_path": "/path/to/file.md" })

# Then start the review:
mcp__interactive_review__start_review({
  "content": "<content from file or conversation>",
  "title": "<descriptive title>"
})
```

## Processing Results

The tool returns a JSON with review items. Handle each item based on:

| checked | comment | Action |
|---------|---------|--------|
| true | empty | Approved - proceed as planned |
| true | has text | Approved with note - consider the feedback |
| false | has text | Rejected - modify according to comment |
| false | empty | Rejected - remove or reconsider this item |

## Example Flow

User: "Review this implementation plan"

1. Extract the plan content from recent output
2. Call start_review with the content
3. Wait for user feedback (tool blocks until submit)
4. Present summary of feedback
5. Ask if user wants you to proceed with approved items or revise rejected items

## Response Template

After receiving feedback:

```
## Review Summary

**Approved**: X items
**Needs revision**: Y items

### Items requiring changes:
- [Item]: [User's comment]

Would you like me to:
1. Proceed with approved items
2. Revise the rejected items based on feedback
3. Both - revise then proceed
```
