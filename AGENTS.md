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

1. Run a dry-run of each patch: `git apply --check <patch-file>`
2. If dry-run succeeds, run the full build and verify Java compilation
3. Test the resulting Docker image with a real client app

## Patch Files

The build script uses `git apply --unidiff-zero --recount --ignore-whitespace` to apply patches, which is more forgiving than the traditional `patch` command.

### Patch Format Rules

1. **Hunk headers should be accurate**: The format is `@@ -old_start,old_count +new_start,new_count @@`
   - `old_count` is the number of lines in the hunk from the old file (context lines plus lines with `-` prefix)
   - `new_count` is the number of lines in the hunk in the new file (context lines plus lines with `+` prefix)
   - For new file patches (`--- /dev/null`), `old_count` is 0 and `new_count` is the total number of lines in the new-file hunk
   - Note: `--recount` will automatically correct line counts, but keeping them accurate is still good practice
2. **Trailing newlines are required**: Patch files must end with a newline character.
3. **Preserve exact whitespace**: Context lines must match the target file exactly, including trailing spaces and tabs. The `--ignore-whitespace` flag provides some tolerance but exact matches are preferred.
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

If a patch adds 1 line, the hunk header should reflect this:

```diff
-@@ -37,3 +37,10 @@
+@@ -37,3 +37,11 @@
```

### Why This Matters

While `git apply --recount` can fix minor line count issues, keeping patches accurate ensures reliable application and easier debugging.
