# Agent Instructions

See [README.md](README.md) for the full architecture, build flow, and maintenance workflows. This file covers agent-specific concerns only.

## Critical Rules

- **Never edit `source/` directly.** It is fully overwritten by `update-project.ps1`. All substantive changes go in `patches/` or `customizations/`, then regenerate with `update-project.ps1`.
- **Never use `-DisableCache`** when running `build.ps1` from agentic contexts. It is effectively a no-op for Java images (source is committed) and risks triggering rate-limiting on start.spring.io for the UAA server.

## Patch Files

Patches are applied by `update-project.ps1` using `patch -p1`, run from inside the extracted project directory. See [README.md § Architecture](README.md#architecture) for when to use a patch vs a customization.

### Patch Format Rules

Agents frequently get hunk counts wrong. The format is:

```
@@ -old_start,old_count +new_start,new_count @@
```

- `old_count` = context lines + lines with a `-` prefix
- `new_count` = context lines + lines with a `+` prefix
- For new content in an (effectively) empty file: `@@ -0,0 +1,N @@`

`patch -p1` does not auto-correct wrong counts — incorrect headers cause patch failures.

**Trailing newlines are required.** Patch files must end with a newline character.

**Preserve exact whitespace.** Context lines must match the target file exactly.

**Path prefix with `-p1`:** Patches use paths like `configserver/src/...`; with `-p1` the applied path becomes `src/...`, matching the project layout.

### Example — Adding Lines

If a patch adds 2 lines to a 3-line context block:

```diff
-@@ -37,3 +37,3 @@
+@@ -37,3 +37,5 @@
 context line 1
 context line 2
 context line 3
+added line 1
+added line 2
```

`old_count = 3` (context), `new_count = 5` (3 context + 2 added).
