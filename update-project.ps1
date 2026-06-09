#!/usr/bin/env pwsh
#Requires -Version 7.4

# =============================================================================
# update-project.ps1: Regenerate image source from start.spring.io, apply
#   patches and customizations, and update IMAGE_VERSION when a new dependency
#   version is detected.
# =============================================================================

param (
    [Parameter(ValueFromRemainingArguments = $true)]
    [String[]] $Names
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Cache Initializr metadata for use with all images
$script:InitializrMetadata = $null
function Get-InitializrMetadata {
    if ($null -ne $script:InitializrMetadata) {
        return $script:InitializrMetadata
    }

    try {
        $script:InitializrMetadata = Invoke-RestMethod `
            -Uri "https://start.spring.io/metadata/client" `
            -Headers @{ Accept = "application/json" } `
            -TimeoutSec 10
    }
    catch {
        Write-Host "  (Could not fetch Initializr metadata: $_; version checks will be skipped)" -ForegroundColor DarkGray
    }

    return $script:InitializrMetadata
}

# Returns the current manifest list digest for the :latest tag of a Docker Hub image,
# or $null if the query fails.
function Get-BuildpackImageDigest {
    param ([String] $ImageName)  # format: "namespace/name" (no tag or digest suffix)
    $parts = $ImageName -split '/', 2
    try {
        $response = Invoke-RestMethod `
            -Uri "https://hub.docker.com/v2/repositories/$($parts[0])/$($parts[1])/tags/latest" `
            -TimeoutSec 10
        return $response.digest
    }
    catch {
        return $null
    }
}

function Update-Project {
    param ([String] $Name)

    $imagesDirectory = Split-Path -Parent $PSCommandPath
    $imageDirectory  = Join-Path $imagesDirectory $Name

    if (!(Test-Path $imageDirectory)) {
        Write-Error "Unknown image $Name"
        return
    }

    if ($Name -eq "uaa-server") {
        Write-Host "Skipping $Name (static Dockerfile)"
        return
    }

    Write-Host "Updating $Name..."

    switch ($Name) {
        "config-server" {
            $applicationName = "ConfigServer"
            $dependencies    = "cloud-config-server,actuator,cloud-eureka,security"
        }
        "eureka-server" {
            $applicationName = "EurekaServer"
            $dependencies    = "cloud-eureka-server,actuator"
        }
        "spring-boot-admin" {
            $applicationName = "SpringBootAdmin"
            $dependencies    = "codecentric-spring-boot-admin-server"
        }
        Default {
            Write-Error "$Name is not supported for auto-generation"
            return
        }
    }

    if (Test-Path (Join-Path $imageDirectory "metadata")) {
        $bootVersion  = Get-Content (Join-Path $imageDirectory "metadata" "SPRING_BOOT_VERSION")
        $imageVersion = Get-Content (Join-Path $imageDirectory "metadata" "IMAGE_VERSION")
    }
    else {
        Write-Error "No metadata found for $Name"
        return
    }

    $serverName = $Name -replace '-', ''
    $javaVersion = "25"

    $encodedDescription = [Uri]::EscapeDataString("$applicationName for local development with Steeltoe")
    $initializrProjectUrl = "https://start.spring.io/#!type=gradle-project&language=java" +
                            "&bootVersion=$bootVersion&groupId=io.steeltoe.docker&artifactId=$serverName" +
                            "&name=$applicationName&description=$encodedDescription&packageName=io.steeltoe.docker.$serverName" +
                            "&javaVersion=$javaVersion&dependencies=$dependencies"
    Write-Host "  Initializr: $initializrProjectUrl"

    $initializrMetadata = Get-InitializrMetadata
    if ($initializrMetadata) {
        $cleanBootVersion = $bootVersion -replace '\.RELEASE$', ''
        $bootVersionTrack = ($cleanBootVersion -split '\.')[0..1] -join '.'

        $latestStable = $initializrMetadata.bootVersion.values |
            Where-Object { $_.id -match "^$([regex]::Escape($bootVersionTrack))\." -and
                           $_.id -notmatch 'SNAPSHOT|\.M\d+|\.RC\d+|\.BUILD' } |
            Select-Object -First 1

        if ($latestStable) {
            $cleanLatestVersion = $latestStable.id -replace '\.RELEASE$', ''
            if ($cleanLatestVersion -ne $cleanBootVersion) {
                Write-Host "  [BOOT UPDATE AVAILABLE] Spring Boot $cleanBootVersion -> $cleanLatestVersion" -ForegroundColor Yellow
                Write-Host "  To apply: Set-Content '$imageDirectory\metadata\SPRING_BOOT_VERSION' '$cleanLatestVersion'" -ForegroundColor DarkYellow
            }
            else {
                Write-Host "  Spring Boot $cleanBootVersion is current in the $bootVersionTrack track" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  (No stable Spring Boot version found in the $bootVersionTrack track)" -ForegroundColor DarkGray
        }

        $cleanDefaultVersion = $initializrMetadata.bootVersion.default -replace '\.RELEASE$', ''
        $defaultVersionTrack = ($cleanDefaultVersion -split '\.')[0..1] -join '.'
        if ($defaultVersionTrack -ne $bootVersionTrack) {
            Write-Host "  (Initializr default is Spring Boot $cleanDefaultVersion / $defaultVersionTrack track)" -ForegroundColor Cyan
        }
    }

    $temporaryDirectory = Join-Path $imageDirectory "workspace"
    if (Test-Path $temporaryDirectory) {
        Remove-Item -Recurse -Force $temporaryDirectory
    }
    New-Item -ItemType Directory -Path $temporaryDirectory | Out-Null

    try {
        Push-Location $temporaryDirectory

        Write-Host "Downloading from start.spring.io..."
        Invoke-WebRequest `
            -Uri "https://start.spring.io/starter.zip" `
            -Method Post `
            -Body @{
                type            = "gradle-project"
                bootVersion     = $bootVersion
                javaVersion     = $javaVersion
                groupId         = "io.steeltoe.docker"
                artifactId      = $serverName
                name            = $applicationName
                applicationName = $applicationName
                description     = "$applicationName for local development with Steeltoe"
                language        = "java"
                dependencies    = $dependencies
                version         = $imageVersion
            } `
            -OutFile "$serverName.zip"

        $extractionRoot = Join-Path $temporaryDirectory "extracted"
        New-Item -ItemType Directory -Path $extractionRoot | Out-Null
        Expand-Archive -Path "$serverName.zip" -DestinationPath $extractionRoot -Force

        $extractedItems     = Get-ChildItem -Path $extractionRoot
        $extractionDirectory = if ($extractedItems.Count -eq 1 -and $extractedItems[0].PSIsContainer) { $extractedItems[0].FullName } else { $extractionRoot }

        # Compare BOM version from the freshly-generated build.gradle against the committed source.
        # BOM key: springCloudVersion for config/eureka (BOM != artifact), springBootAdminVersion for SBA (BOM = artifact)
        $bomVersionKey = if ($Name -eq "spring-boot-admin") { "springBootAdminVersion" } else { "springCloudVersion" }

        $generatedBuildContent = Get-Content (Join-Path $extractionDirectory "build.gradle") -Raw -ErrorAction SilentlyContinue
        $committedBuildContent = Get-Content (Join-Path $imageDirectory "source" "build.gradle") -Raw -ErrorAction SilentlyContinue

        if ($generatedBuildContent) {
            $bomVersionPattern = "set\('$bomVersionKey',\s*`"([^`"]+)`"\)"
            $generatedBuildContent -match $bomVersionPattern | Out-Null; $generatedBomVersion = $Matches[1]
            if ($committedBuildContent) {
                $committedBuildContent -match $bomVersionPattern | Out-Null; $committedBomVersion = $Matches[1]
            }

            if ($generatedBomVersion) {
                $bomVersionChanged = $committedBomVersion -and ($committedBomVersion -ne $generatedBomVersion)

                if ($Name -eq "spring-boot-admin") {
                    if ($generatedBomVersion -ne $imageVersion) {
                        $previousVersion = $imageVersion
                        Set-Content (Join-Path $imageDirectory "metadata" "IMAGE_VERSION") $generatedBomVersion
                        Set-Content (Join-Path $imageDirectory "metadata" "IMAGE_REVISION") ""
                        $imageVersion = $generatedBomVersion
                        $versionChangeNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { " (was $previousVersion)" }
                        Write-Host "  [UPDATED] IMAGE_VERSION -> $generatedBomVersion$versionChangeNote" -ForegroundColor Green
                    }
                    else {
                        Write-Host "  $bomVersionKey`: $generatedBomVersion  IMAGE_VERSION: $imageVersion  (in sync)" -ForegroundColor Green
                    }
                }
                else {
                    # Spring Cloud release train (for example: 2025.0.2) does not equal the artifact version;
                    # resolve it from the Spring Cloud BOM POM on GitHub.
                    $bomPomPropertyName = if ($Name -eq "eureka-server") { "spring-cloud-netflix.version" } else { "spring-cloud-config.version" }
                    $artifactVersion = $null
                    try {
                        [xml]$bomPomDocument = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spring-cloud/spring-cloud-release/v$generatedBomVersion/spring-cloud-dependencies/pom.xml" -TimeoutSec 10
                        $artifactVersion = $bomPomDocument.project.properties.$bomPomPropertyName
                    }
                    catch {
                        Write-Host "  (Could not fetch BOM POM for $generatedBomVersion`: $_)" -ForegroundColor DarkGray
                    }

                    if ($artifactVersion) {
                        if ($artifactVersion -ne $imageVersion) {
                            $previousVersion = $imageVersion
                            Set-Content (Join-Path $imageDirectory "metadata" "IMAGE_VERSION") $artifactVersion
                            Set-Content (Join-Path $imageDirectory "metadata" "IMAGE_REVISION") ""
                            $imageVersion = $artifactVersion
                            $bomVersionNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { " (was $previousVersion)" }
                            Write-Host "  [UPDATED] IMAGE_VERSION -> $artifactVersion via $bomPomPropertyName$bomVersionNote" -ForegroundColor Green
                        }
                        else {
                            $bomVersionNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { "" }
                            Write-Host "  $bomVersionKey`: $generatedBomVersion  IMAGE_VERSION: $imageVersion (in sync)$bomVersionNote" -ForegroundColor Green
                        }
                    }
                    else {
                        $statusMessage = if ($bomVersionChanged) { "[BOM CHANGED] $bomVersionKey`: $committedBomVersion -> $generatedBomVersion" } else { "$bomVersionKey`: $generatedBomVersion" }
                        Write-Host "  $statusMessage  IMAGE_VERSION: $imageVersion  (BOM fetch failed)" -ForegroundColor Yellow
                        Write-Host "  Check $bomPomPropertyName in: https://github.com/spring-cloud/spring-cloud-release/blob/v$generatedBomVersion/spring-cloud-dependencies/pom.xml" -ForegroundColor Cyan
                    }
                }
            }
        }

        Push-Location $extractionDirectory
        try {
            if (Test-Path (Join-Path $imageDirectory "patches")) {
                foreach ($patch in Get-ChildItem -Path (Join-Path $imageDirectory patches) -Filter "*.patch") {
                    Write-Host "Applying patch $($patch.Name)"
                    $patchContent = Get-Content $patch -Raw

                    if (!(Get-Command "patch" -ErrorAction SilentlyContinue)) {
                        if (Test-Path "$Env:ProgramFiles\Git\usr\bin\patch.exe") {
                            $env:Path += ";$Env:ProgramFiles\Git\usr\bin"
                        }
                        else {
                            throw "'patch' command not found"
                        }
                    }

                    try {
                        $patchContent | & patch -p1 2>&1 | ForEach-Object { Write-Host "  $_" }
                    }
                    catch {
                        throw "Patch $($patch.Name) failed"
                    }
                }
            }
        }
        finally {
            Pop-Location
        }

        $sourceDirectory = Join-Path $imageDirectory "source"
        if (Test-Path $sourceDirectory) {
            Remove-Item -Recurse -Force $sourceDirectory
        }

        New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null

        # Remove files we don't want committed.
        # gradle-wrapper.jar is intentionally left in place, so local builds can skip the download.
        # build.ps1 still validates its checksum against services.gradle.org on every build.
        Get-ChildItem -Path $extractionDirectory -Recurse -Filter "*.orig" | Remove-Item -Force
        foreach ($unwanted in @(".gitignore", ".gitattributes", "HELP.md")) {
            $unwantedPath = Join-Path $extractionDirectory $unwanted
            if (Test-Path $unwantedPath) {
                Remove-Item -Force $unwantedPath
            }
        }

        Copy-Item -Path "$extractionDirectory\*" -Destination $sourceDirectory -Recurse -Force

        $customizationsDirectory = Join-Path $imageDirectory "customizations"
        if (Test-Path $customizationsDirectory) {
            # Append the image-build hardening block (builder/run-image digest pins, reproducible
            # createdDate, dependency locking, test gating) to the generated build.gradle.
            $buildGradleAppend = Join-Path $customizationsDirectory "build.gradle.append"
            if (Test-Path $buildGradleAppend) {
                Write-Host "Appending build.gradle customizations"
                $buildGradlePath = Join-Path $sourceDirectory "build.gradle"
                $generated = ([System.IO.File]::ReadAllText($buildGradlePath)) -replace "`r`n", "`n"
                $append    = ([System.IO.File]::ReadAllText($buildGradleAppend)) -replace "`r`n", "`n"
                [System.IO.File]::WriteAllText($buildGradlePath, $generated.TrimEnd("`n") + "`n`n" + $append)
            }

            # Overlay hand-written files on top of the generated project.
            $overlayDirectory = Join-Path $customizationsDirectory "overlay"
            if (Test-Path $overlayDirectory) {
                Write-Host "Applying overlay files"
                Copy-Item -Path (Join-Path $overlayDirectory "*") -Destination $sourceDirectory -Recurse -Force
            }
        }

        # git does not preserve Unix execute permissions on Windows; restore the bit so Linux CI can run gradlew
        if (Test-Path (Join-Path $sourceDirectory "gradlew")) {
            & git -C $imagesDirectory update-index --chmod=+x "$Name/source/gradlew" 2>&1 | Out-Null
        }

        # Regenerate dependency lockfiles so they always match the freshly resolved dependencies.
        # Uses the wrapper jar shipped in the generated project; requires JDK 25 and network access.
        Write-Host "Regenerating dependency locks (resolving all dependencies)..."
        Push-Location $sourceDirectory
        try {
            if ($IsLinux -or $IsMacOS) {
                & chmod +x gradlew
            }
            $gradlewCommand = if ($IsWindows) { ".\gradlew.bat" } else { "./gradlew" }
            # Pipe stdout (verbose dependency tree) to Out-Null; stderr is not redirected so that
            # Gradle errors remain visible. Do not add 2>&1 here! Doing so would hide real failures.
            & $gradlewCommand --no-daemon --console=plain dependencies --write-locks | Out-Null

            # Drop the transient Gradle outputs from the lock run; they are not part of source.
            Remove-Item -Recurse -Force (Join-Path $sourceDirectory "build") -ErrorAction Ignore
            Remove-Item -Recurse -Force (Join-Path $sourceDirectory ".gradle") -ErrorAction Ignore
        }
        finally {
            Pop-Location
        }

        Write-Host "Updated source for $Name in $sourceDirectory"
    }
    catch {
        Write-Error "Failed to update $Name : $_"
        throw
    }
    finally {
        Set-Location $imagesDirectory
        if (Test-Path $temporaryDirectory) {
            Start-Sleep -Milliseconds 500
            Remove-Item -Recurse -Force $temporaryDirectory
        }
    }
}

# Check for updates to the Paketo Buildpack images pinned in build.gradle.append.
# All Java-based images should share these digests, so read from the first file found and report once.
# Update the builder/runImage lines in all three build.gradle.append files when an update is available.
$firstAppend = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter "build.gradle.append" -ErrorAction Ignore | Select-Object -First 1
if ($firstAppend) {
    $appendContent = Get-Content $firstAppend.FullName -Raw
    foreach ($check in @(
        @{ Label = "builder";  Pattern = 'builder\s*=\s*"([^@"]+)@(sha256:[a-f0-9]+)"' },
        @{ Label = "runImage"; Pattern = 'runImage\s*=\s*"([^@"]+)@(sha256:[a-f0-9]+)"' }
    )) {
        if ($appendContent -match $check.Pattern) {
            $imageName    = $Matches[1]
            $pinnedDigest = $Matches[2]
            $latestDigest = Get-BuildpackImageDigest $imageName
            if ($latestDigest) {
                if ($latestDigest -ne $pinnedDigest) {
                    Write-Host "[UPDATE AVAILABLE] $($check.Label): $imageName" -ForegroundColor Yellow
                    Write-Host "  $pinnedDigest  ->  $latestDigest" -ForegroundColor Yellow
                    Write-Host "  Update $($check.Label) in all build.gradle.append files" -ForegroundColor DarkYellow
                }
                else {
                    Write-Host "$($check.Label) digest is current  ($pinnedDigest)" -ForegroundColor Green
                }
            }
            else {
                Write-Host "(Could not check Docker Hub for $imageName)" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host ""
    Write-Host ('=' * 60) -ForegroundColor DarkGray
    Write-Host ""
}

# Wrap in @() so a single -Names value stays an array (prevent iterating on the characters in the name).
$imageNames = @(if ($Names) { $Names } else { @("config-server", "eureka-server", "spring-boot-admin") })

for ($index = 0; $index -lt $imageNames.Count; $index++) {
    Update-Project -Name $imageNames[$index]
    if ($index -lt $imageNames.Count - 1) {
        Write-Host ""
        Write-Host ('=' * 60) -ForegroundColor DarkGray
        Write-Host ""
    }
}
