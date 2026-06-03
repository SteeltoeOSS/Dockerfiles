# Agent Instructions and Reminders

This file contains important reminders and guidelines for AI agents working on this codebase.

## Architecture Overview

Each Java image (config-server, eureka-server, spring-boot-admin) has a committed `source/` directory containing the complete, ready-to-build Gradle project. The build flow is:

1. **`update-project.ps1`** — Regenerates `<image>/source/` from scratch:
   - Downloads a fresh project from `start.spring.io`
   - Applies patches from `<image>/patches/` (modifications to Initializr-generated files)
   - Applies customizations from `<image>/customizations/` (see below)
   - Regenerates `gradle.lockfile` via `./gradlew dependencies --write-locks` so the locked dependency versions always match the resolved graph
   - Writes the result to `<image>/source/`
   - **Requires JDK 25 and network access** (it resolves dependencies to regenerate the lock)

2. **`build.ps1`** — Builds the Docker image:
   - Copies `<image>/source/` into `workspace/<image>/`
   - Downloads `gradle-wrapper.jar` into the workspace copy (not committed; version resolved from `gradle-wrapper.properties`) and verifies it against Gradle's published SHA-256
   - Runs `./gradlew bootBuildImage`, which runs `test` first (the image build is gated on tests) and pins the builder and run image by digest for reproducible image contents

The UAA server uses a static Dockerfile and does not have a `source/` directory.

### Customizations (`<image>/customizations/`)

Content that Spring Initializr does not generate lives here so it survives regeneration:

- **`build.gradle.append`** — appended to the generated `build.gradle`. Holds the image-build hardening: digest-pinned `builder`/`runImage`, a reproducible `createdDate` (overridable via `-PimageCreatedDate`), `dependencyLocking`, and the `bootBuildImage` → `test` dependency.
- **`overlay/`** — files copied verbatim over the generated project after patching (mirrors the project layout). Holds the hand-written tests.

Edit these (or `patches/`), **not `source/` directly**, then run `update-project.ps1` to regenerate. `build.gradle` is customized via `build.gradle.append` (an append is more robust than a line-anchored patch), so there is no `build.gradle.patch`.

## Build Script

### Avoid `-DisableCache` Flag

`-DisableCache` is a no-op for the Java images (source is committed). It only affects UAA server builds (disables Docker layer cache). Do not use it from agentic contexts.

### Updating Source for a Java Image

To update an image's committed source to a new Spring Boot version or dependency:

1. Update `<image>/metadata/SPRING_BOOT_VERSION` and/or `<image>/metadata/IMAGE_VERSION`
2. Update `<image>/patches/` and/or `<image>/customizations/` if needed
3. Run: `.\update-project.ps1 -Names <image-name>` (requires JDK 25; regenerates `gradle.lockfile`)
4. Review and commit the changes in `<image>/source/`, including the regenerated lockfile

### Testing Changes

Before submitting patch, customization, or source changes:

1. Dry-run each patch: `patch --dry-run -p1 < <patch-file>` (run from the extracted project root)
2. If dry-run succeeds, run `.\update-project.ps1` and verify the output in `source/`
3. Iterate on tests directly with `./gradlew test` from `<image>/source/`
4. Run `.\build.ps1 -Name <image>` to verify the Docker image build (it runs `test` first and fails if any test fails)
5. Test the resulting Docker image with a real client app

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
