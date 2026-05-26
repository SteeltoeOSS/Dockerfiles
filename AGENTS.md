# Agent Instructions and Reminders

This file contains important reminders and guidelines for AI agents working on this codebase.

## Architecture Overview

Each Java image (config-server, eureka-server, spring-boot-admin) has a committed `source/` directory containing the complete, ready-to-build Gradle project. The build flow is:

1. **`update-project.ps1`** — Regenerates `<image>/source/` from scratch:
   - Downloads a fresh project from `start.spring.io`
   - Applies patches from `<image>/patches/`
   - Commits the result to `<image>/source/`

2. **`build.ps1`** — Builds the Docker image:
   - Copies `<image>/source/` into `workspace/<image>/`
   - Downloads `gradle-wrapper.jar` from the Gradle GitHub repo into the workspace copy (not committed to source; version is resolved from `gradle-wrapper.properties`)
   - Runs `./gradlew bootBuildImage` to produce the container image

The UAA server uses a static Dockerfile and does not have a `source/` directory.

## Build Script

### Avoid `-DisableCache` Flag

`-DisableCache` is a no-op for the Java images (source is committed). It only affects UAA server builds (disables Docker layer cache). Do not use it from agentic contexts.

### Updating Source for a Java Image

To update an image's committed source to a new Spring Boot version or dependency:

1. Update `<image>/metadata/SPRING_BOOT_VERSION` and/or `<image>/metadata/IMAGE_VERSION`
2. Update patches in `<image>/patches/` if needed
3. Run: `.\update-project.ps1 -Names <image-name>`
4. Review and commit the changes in `<image>/source/`

### Testing Changes

Before submitting patch or source changes:

1. Dry-run each patch: `patch --dry-run -p1 < <patch-file>` (run from the extracted project root)
2. If dry-run succeeds, run `.\update-project.ps1` and verify the output in `source/`
3. Run `.\build.ps1 -Name <image>` to verify Docker image build
4. Test the resulting Docker image with a real client app

## Patch Files

Patches are applied by `update-project.ps1` using `patch -p1`, run from inside the extracted project directory.

### Patch Format Rules

1. **Hunk headers must be accurate**: The format is `@@ -old_start,old_count +new_start,new_count @@`
   - `old_count` is the number of lines in the hunk from the old file (context lines plus lines with `-` prefix)
   - `new_count` is the number of lines in the hunk in the new file (context lines plus lines with `+` prefix)
   - Unlike `git apply --recount`, `patch -p1` does not auto-correct wrong counts — incorrect headers cause patch failures
2. **Trailing newlines are required**: Patch files must end with a newline character.
3. **Preserve exact whitespace**: Context lines must match the target file exactly. Use `--ignore-whitespace` only as a diagnostic aid, not a crutch.
4. **Path prefix with `-p1`**: The leading path component is stripped. Patches use paths like `configserver/src/...` so with `-p1` the applied path is `src/...`, matching the project layout.
5. **New content patches**: Patches that add lines to an (effectively) empty file use `@@ -0,0 +1,N @@`. Spring Initializr generates `spring.application.name=<AppName>` in `application.properties`; this line will appear after the patched lines in the final file.

### Example — Adding Lines

If a patch adds 2 lines to a 3-line context block:

```diff
-@@ -37,3 +37,5 @@
+@@ -37,3 +37,5 @@
  context line 1
  context line 2
  context line 3
+added line 1
+added line 2
```

old_count = 3 (context), new_count = 5 (3 context + 2 added).

### Why This Matters

`patch -p1` is strict about line counts. A mismatch causes the hunk to fail outright rather than being silently corrected.
