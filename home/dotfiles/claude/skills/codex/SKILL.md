---
name: codex
description: Use this skill when the user asks to query Codex ("codexに聞いて", "codexで調べて", "codexにレビューを依頼", "ask codex", "consult codex", "codex review") for technical questions, code reviews, code analysis, architecture discussions, best practices, or implementation guidance. Handles interaction with the Codex CLI tool.
allowed-tools: Read, Grep, Glob, Write, Bash(codex:*), Bash(cat:*) 
---
# How to Use Codex from Claude Code

Codex is an AI-powered CLI tool that can help with complex debugging, code analysis, and technical questions. When you encounter difficult problems that would benefit from a second perspective or deep analysis, use Codex.

## When to Use Codex

- Debugging subtle bugs (e.g., bitstream alignment issues, off-by-one errors)
- Analyzing complex algorithms against specifications
- Getting a detailed code review with specific bug identification
- Understanding obscure file formats or protocols
- When you've tried multiple approaches and are stuck

## The File-Based Pattern

Codex works best with a file-based input/output pattern. To avoid conflicts between multiple sessions and preserve history, use session directories with timestamped files.

### Step 0: Initialize Session Directory (First time per session)

```bash
export CODEX_SESSION_DIR=$(mktemp -d /tmp/claude-codex-XXXXXX)
echo "Codex session: $CODEX_SESSION_DIR"
```

This creates a unique directory like `/tmp/claude-codex-a1b2c3/` for the current session.

### Step 1: Create a Question File

Generate a timestamped filename and write your question:

```bash
QUESTION_FILE="$CODEX_SESSION_DIR/question-$(date +%Y%m%d-%H%M%S).txt"
REPLY_FILE="${QUESTION_FILE/question/reply}"
```

Write your question and all relevant context to `$QUESTION_FILE`:

```
Write to $QUESTION_FILE:
- Clear problem statement
- The specific error or symptom
- The relevant code (full functions, not snippets)
- What you've already tried
- Specific questions you want answered
```

Example structure:
```
I have a [component] that fails with [specific error].

Here is the full function:
```c
[paste complete code]
```

Key observations:
1. [What works]
2. [What fails]
3. [When it fails]

Can you identify:
1. [Specific question 1]
2. [Specific question 2]
```

### Step 2: Invoke Codex

Use this command pattern:

```bash
codex exec -o "$REPLY_FILE" --full-auto < "$QUESTION_FILE"
```

Flags:
- `exec`: Non-interactive execution mode (required for CLI use)
- `-o "$REPLY_FILE"`: Write output to timestamped reply file
- `--full-auto`: Run autonomously without prompts

### Step 3: Read the Reply

```bash
Read $REPLY_FILE
```

Codex will provide detailed analysis. Evaluate its suggestions critically - it may identify real bugs but can occasionally misinterpret specifications.

### Reviewing History

List all Q&A pairs in the session:
```bash
ls -la "$CODEX_SESSION_DIR"
```

Example output:
```
question-20250204-143022.txt
reply-20250204-143022.txt
question-20250204-144511.txt
reply-20250204-144511.txt
```

## Example Session

```bash
# 0. Initialize session (once per Claude Code session)
export CODEX_SESSION_DIR=$(mktemp -d /tmp/claude-codex-XXXXXX)

# 1. Create timestamped files
QUESTION_FILE="$CODEX_SESSION_DIR/question-$(date +%Y%m%d-%H%M%S).txt"
REPLY_FILE="${QUESTION_FILE/question/reply}"

# 2. Write the question
Write $QUESTION_FILE with:
- Problem: "Progressive JPEG decoder fails at block 1477 with Huffman error"
- Code: [full AC refinement function]
- Questions: "Identify bugs in EOB handling, ZRL handling, run counting"

# 3. Invoke Codex
codex exec -o "$REPLY_FILE" --full-auto < "$QUESTION_FILE"

# 4. Read and apply
Read $REPLY_FILE
# Codex identified 12 potential bugs with detailed explanations
# Evaluate each, verify against spec, apply fixes

# 5. For follow-up questions, repeat steps 1-4 (new timestamp)
```

## Tips

1. **Provide complete code**: Don't truncate functions. Codex needs full context.

2. **Be specific**: "Why does this fail?" is worse than "Why does Huffman decoding fail after processing 1477 blocks in AC refinement scan?"

3. **Include the spec**: If debugging against a standard (JPEG, PNG, etc.), mention the relevant spec sections.

4. **Verify suggestions**: Codex is helpful but not infallible. In one session, it incorrectly identified the EOB run formula as buggy when it was actually correct. Always verify against authoritative sources.

5. **Iterate if needed**: If the first response doesn't solve the problem, create a new question.txt with additional context from what you learned.

## Common Issues

**"stdin is not a terminal"**: Use `codex exec` not bare `codex`

**No output**: Check that `-o` flag has a valid path

**Timeout**: For very complex questions, Codex may take time. The `--full-auto` flag helps avoid interactive prompts that would block.

## Alternative: Direct Piping

For shorter questions:
```bash
echo "Explain the JPEG progressive AC refinement algorithm" | codex exec --full-auto
```

But for debugging, the file-based pattern is better because you can refine the question and keep a record.
