# Agent Instructions and Reminders

This file contains important reminders and guidelines for AI agents working on this codebase.

## Build Script

### Avoid `-DisableCache` Flag

**Do NOT use `-DisableCache`** when running `build.ps1` from agentic contexts. The `start.spring.io` service may block or rate-limit automated traffic, causing connection failures.

Instead, to get a fresh build:

1. Delete the expanded project folder (e.g., `workspace/springbootadmin/`)
2. Run `.\build.ps1 <image-name>` without the flag

### Testing Changes

Before submitting patch changes:

1. Run a dry-run of each patch: `Get-Content patch.patch | & patch --dry-run -p1`
2. If dry-run succeeds, run the full build and verify Java compilation
3. Test the resulting Docker image with a real client app

## Patch Files

**CRITICAL**: When modifying patch files (`.patch` files in `patches/` directories), you MUST update the line numbers in the hunk headers when adding or removing lines.

### Patch Format Rules

1. **Hunk headers must be accurate**: The format is `@@ -old_start,old_count +new_start,new_count @@`
   - `old_count` is the number of lines in the hunk from the old file (context lines plus lines with `-` prefix)
   - `new_count` is the number of lines in the hunk in the new file (context lines plus lines with `+` prefix)
   - For new file patches (`--- /dev/null`), `old_count` is 0 and `new_count` is the total number of lines in the new-file hunk
2. **Trailing newlines are required**: Patch files must end with a newline character. The `patch` utility will fail with "unexpected end of file" otherwise.
3. **Preserve exact whitespace**: Context lines must match the target file exactly, including trailing spaces and tabs.
4. **New file patches**: Use `/dev/null` as the old file:

   ```diff
   --- /dev/null
   +++ ./path/to/NewFile.java	2026-01-27 00:00:00.000000000 +0000
   @@ -0,0 +1,N @@
   +line 1
   +line 2
   ...
   ```

### Example

If a patch adds 1 line, the hunk header must reflect this:

```diff
-@@ -37,3 +37,10 @@
+@@ -37,3 +37,11 @@
```

### Why This Matters

Incorrect line numbers cause patch application to fail, breaking the build process.
