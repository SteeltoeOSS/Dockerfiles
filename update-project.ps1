#!/usr/bin/env pwsh

# =============================================================================
# update-project.ps1: Update project sources from start.spring.io
# =============================================================================

param (
    [String[]] $Names
)

$ErrorActionPreference = 'Stop'

# Cache Initializr metadata for use with all images
$script:InitializrMetadata = $null
function Get-InitializrMetadata {
    if ($null -ne $script:InitializrMetadata) { return $script:InitializrMetadata }
    try {
        $script:InitializrMetadata = Invoke-RestMethod `
            -Uri "https://start.spring.io/metadata/client" `
            -Headers @{ Accept = "application/json" } `
            -TimeoutSec 10
    } catch {
        Write-Host "  (Could not fetch Initializr metadata: $_)"
    }
    return $script:InitializrMetadata
}

function Update-Project {
    param (
        [String] $Name
    )

    $ImagesDirectory = Split-Path -Parent $PSCommandPath
    $ImageDirectory = Join-Path $ImagesDirectory $Name

    if (!(Test-Path $ImageDirectory)) {
        Write-Error "Unknown image $Name"
        return
    }

    if ($Name -eq "uaa-server") {
        Write-Host "Skipping $Name (static Dockerfile)"
        return
    }

    Write-Host "Updating $Name..."

    # Define dependencies
    switch ($Name) {
        "config-server" {
            $appName      = "ConfigServer"
            $dependencies = "cloud-config-server,actuator,cloud-eureka,security"
        }
        "eureka-server" {
            $appName      = "EurekaServer"
            $dependencies = "cloud-eureka-server,actuator"
        }
        "spring-boot-admin" {
            $appName      = "SpringBootAdmin"
            $dependencies = "codecentric-spring-boot-admin-server"
        }
        Default {
            Write-Error "$Name is not supported for auto-generation"
            return
        }
    }

    # Metadata
    if (Test-Path (Join-Path $ImageDirectory "metadata")) {
        $bootVersion   = Get-Content (Join-Path $ImageDirectory "metadata" "SPRING_BOOT_VERSION")
        $serverVersion = Get-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION")
    } else {
        Write-Error "No metadata found for $Name"
        return
    }

    $serverName = $Name -replace '-', ''
    $JVM = "25"

    # Print Initializr link for this project
    $encodedDesc   = [Uri]::EscapeDataString("$appName for local development with Steeltoe")
    $initializrUrl = "https://start.spring.io/#!type=gradle-project&language=java" +
                     "&bootVersion=$bootVersion&groupId=io.steeltoe.docker&artifactId=$serverName" +
                     "&name=$appName&description=$encodedDesc&packageName=io.steeltoe.docker.$serverName" +
                     "&javaVersion=$JVM&dependencies=$dependencies"
    Write-Host "  Initializr: $initializrUrl"

    # Check current Spring Boot version against Initializr's published versions for this track
    $metadata = Get-InitializrMetadata
    if ($metadata) {
        $cleanBoot = $bootVersion -replace '\.RELEASE$', ''
        $track     = ($cleanBoot -split '\.')[0..1] -join '.'

        # Latest stable in track: first value matching major.minor with no pre-release suffix
        $latestStable = $metadata.bootVersion.values |
            Where-Object { $_.id -match "^$([regex]::Escape($track))\." -and
                           $_.id -notmatch 'SNAPSHOT|\.M\d+|\.RC\d+|\.BUILD' } |
            Select-Object -First 1

        if ($latestStable) {
            $cleanLatest = $latestStable.id -replace '\.RELEASE$', ''
            if ($cleanLatest -ne $cleanBoot) {
                Write-Host "  [BOOT UPDATE AVAILABLE] Spring Boot $cleanBoot -> $cleanLatest" -ForegroundColor Yellow
                Write-Host "  To apply: Set-Content '$ImageDirectory\metadata\SPRING_BOOT_VERSION' '$cleanLatest'" -ForegroundColor DarkYellow
            } else {
                Write-Host "  Spring Boot $cleanBoot is current in the $track track" -ForegroundColor Green
            }
        }

        # Inform when the Initializr default has moved to a different major.minor track
        $cleanDefault = $metadata.bootVersion.default -replace '\.RELEASE$', ''
        $defaultTrack = ($cleanDefault -split '\.')[0..1] -join '.'
        if ($defaultTrack -ne $track) {
            Write-Host "  (Initializr default is Spring Boot $cleanDefault / $defaultTrack track)" -ForegroundColor Cyan
        }
    }

    # Temporary workspace for generation
    $tempDir = Join-Path $ImagesDirectory "temp_update_$Name"
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Push-Location $tempDir

        # Download from start.spring.io
        $artifactName = "$serverName.zip"
        Write-Host "Downloading from start.spring.io..."
        Invoke-WebRequest `
            -Uri "https://start.spring.io/starter.zip" `
            -Method Post `
            -Body @{
                type            = "gradle-project"
                bootVersion     = $bootVersion
                javaVersion     = $JVM
                groupId         = "io.steeltoe.docker"
                artifactId      = $serverName
                name            = $appName
                applicationName = $appName
                description     = "$appName for local development with Steeltoe"
                language        = "java"
                dependencies    = $dependencies
                version         = $serverVersion
            } `
            -OutFile $artifactName

        # Extract
        $extractRoot = Join-Path $tempDir "extracted"
        New-Item -ItemType Directory -Path $extractRoot | Out-Null
        Expand-Archive -Path $artifactName -DestinationPath $extractRoot -Force

        $items = Get-ChildItem -Path $extractRoot
        if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
            $extractDir = $items[0].FullName
            Write-Host "Found extracted project at $extractDir"
        } else {
            $extractDir = $extractRoot
            Write-Host "Project files found in root of extraction"
        }

        # -----------------------------------------------------------------------
        # Dependency version check
        #
        # The generated build.gradle is the authoritative source for which BOM version
        # Initializr pairs with our configured SPRING_BOOT_VERSION.
        # Compare against the committed source/build.gradle to surface updates.
        #
        # BOM key mapping:
        #   config-server / eureka-server -> springCloudVersion  (BOM != artifact version)
        #   spring-boot-admin             -> springBootAdminVersion (BOM == artifact version)
        # -----------------------------------------------------------------------
        if ($Name -eq "spring-boot-admin") {
            $bomKey = "springBootAdminVersion"
        } else {
            $bomKey = "springCloudVersion"
        }

        $generatedBuildContent = Get-Content (Join-Path $extractDir "build.gradle") -Raw -ErrorAction SilentlyContinue
        $committedBuildContent  = Get-Content (Join-Path $ImageDirectory "source" "build.gradle") -Raw -ErrorAction SilentlyContinue

        if ($generatedBuildContent -and $bomKey) {
            $pattern = "set\('$bomKey',\s*`"([^`"]+)`"\)"
            $generatedBuildContent -match $pattern | Out-Null
            $newBom = $Matches[1]

            if ($committedBuildContent) {
                $committedBuildContent -match $pattern | Out-Null
                $oldBom = $Matches[1]
            }

            if ($newBom) {
                $bomChanged = $oldBom -and ($oldBom -ne $newBom)

                if ($Name -eq "spring-boot-admin") {
                    # BOM version = artifact version = IMAGE_VERSION; auto-apply if out of sync
                    if ($newBom -ne $serverVersion) {
                        $prevVersion = $serverVersion
                        Set-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION") $newBom
                        $serverVersion = $newBom
                        $changeNote = if ($bomChanged) { " (BOM $oldBom -> $newBom)" } else { " (was $prevVersion)" }
                        Write-Host "  [UPDATED] IMAGE_VERSION -> $newBom$changeNote" -ForegroundColor Green
                    } else {
                        Write-Host "  $bomKey`: $newBom  IMAGE_VERSION: $serverVersion  (in sync)" -ForegroundColor Green
                    }
                } else {
                    # Spring Cloud: BOM version is the release train (e.g. 2025.0.2), not the artifact version.
                    # Resolve the exact artifact version by fetching the Spring Cloud BOM POM from GitHub.
                    $bomPomProp = if ($Name -eq "eureka-server") { "spring-cloud-netflix.version" } else { "spring-cloud-config.version" }
                    $bomGhUrl   = "https://raw.githubusercontent.com/spring-cloud/spring-cloud-release/v$newBom/spring-cloud-dependencies/pom.xml"
                    $artifactVersion = $null
                    try {
                        [xml]$bomXml = Invoke-RestMethod -Uri $bomGhUrl -TimeoutSec 10
                        $artifactVersion = $bomXml.project.properties.$bomPomProp
                    } catch {
                        # Fall through to the link-only fallback below
                    }

                    if ($artifactVersion) {
                        if ($artifactVersion -ne $serverVersion) {
                            # Auto-apply: source was just regenerated, metadata must stay in sync
                            $prevVersion = $serverVersion
                            Set-Content (Join-Path $ImageDirectory "metadata" "IMAGE_VERSION") $artifactVersion
                            $serverVersion = $artifactVersion
                            $bomNote = if ($bomChanged) { " (BOM $oldBom -> $newBom)" } else { " (was $prevVersion)" }
                            Write-Host "  [UPDATED] IMAGE_VERSION -> $artifactVersion via $bomPomProp$bomNote" -ForegroundColor Green
                        } else {
                            $bomNote = if ($bomChanged) { " (BOM $oldBom -> $newBom)" } else { "" }
                            Write-Host "  $bomKey`: $newBom  IMAGE_VERSION: $serverVersion (in sync)$bomNote" -ForegroundColor Green
                        }
                    } else {
                        # BOM fetch failed — cannot auto-update; provide the link for manual lookup
                        $msg = if ($bomChanged) { "[BOM CHANGED] $bomKey`: $oldBom -> $newBom" } else { "$bomKey`: $newBom" }
                        Write-Host "  $msg  IMAGE_VERSION: $serverVersion  (BOM fetch failed)" -ForegroundColor Yellow
                        Write-Host "  Check $bomPomProp in: https://github.com/spring-cloud/spring-cloud-release/blob/v$newBom/spring-cloud-dependencies/pom.xml" -ForegroundColor Cyan
                    }
                }
            }
        }

        # Apply Patches
        Push-Location $extractDir
        try {
            if (Test-Path (Join-Path $ImageDirectory "patches")) {
                foreach ($patch in Get-ChildItem -Path (Join-Path $ImageDirectory patches) -Filter "*.patch") {
                    Write-Host "Applying patch $($patch.Name)"
                    $patchContent = Get-Content $patch -Raw

                    # Ensure patch is available
                    if (!(Get-Command "patch" -ErrorAction SilentlyContinue)) {
                         if (Test-Path "$Env:ProgramFiles\Git\usr\bin\patch.exe") {
                            $env:Path += ";$Env:ProgramFiles\Git\usr\bin"
                        } else {
                            throw "'patch' command not found"
                        }
                    }

                    $patchOutput = $patchContent | & patch -p1 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        if ($patchContent -match '(?m)^--- /dev/null') {
                            # New-file patches may exit non-zero even when successful
                            Write-Host "  (New file patch assumed successful)"
                        } else {
                            $patchOutput | ForEach-Object { Write-Host "  $_" }
                            throw "Patch $($patch.Name) failed"
                        }
                    }
                }
            }

            # Copy SSL Config
            $repoRoot = $ImagesDirectory
            $sharedSslDir = Join-Path $repoRoot "shared" "ssl-config"
            if (Test-Path $sharedSslDir) {
                $appJavaDir = Join-Path "src" "main" "java" "io" "steeltoe" "docker" $serverName
                if (!(Test-Path $appJavaDir)) { New-Item -ItemType Directory -Path $appJavaDir -Force | Out-Null }

                $sslTrustConfig = Join-Path $sharedSslDir "SslTrustConfiguration.java"
                if (Test-Path $sslTrustConfig) {
                    $targetFile = Join-Path $appJavaDir "SslTrustConfiguration.java"
                    Copy-Item $sslTrustConfig $targetFile -Force

                    $packagePattern = 'package\s+io\.steeltoe\.docker\.ssl;'
                    $newPackageDeclaration = "package io.steeltoe.docker.$serverName;"
                    (Get-Content $targetFile) -replace $packagePattern, $newPackageDeclaration | Set-Content $targetFile
                }
            }
        }
        finally {
            Pop-Location
        }

        # Update Source Directory
        $sourceDir = Join-Path $ImageDirectory "source"
        if (Test-Path $sourceDir) { Remove-Item -Recurse -Force $sourceDir }
        New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null

        # Cleanup artifacts we don't want to commit
        Get-ChildItem -Path $extractDir -Recurse -Filter "*.orig" | Remove-Item -Force
        if (Test-Path (Join-Path $extractDir ".gitignore")) { Remove-Item -Force (Join-Path $extractDir ".gitignore") }
        if (Test-Path (Join-Path $extractDir ".gitattributes")) { Remove-Item -Force (Join-Path $extractDir ".gitattributes") }

        # Copy generated files to source/
        Copy-Item -Path "$extractDir\*" -Destination $sourceDir -Recurse -Force

        Write-Host "Updated source for $Name in $sourceDir"

    }
    catch {
        Write-Error "Failed to update $Name : $_"
        throw
    }
    finally {
        Set-Location $ImagesDirectory

        if (Test-Path $tempDir) {
            Start-Sleep -Milliseconds 500
            Remove-Item -Recurse -Force $tempDir
        }

        Write-Host "--------------------------------"
    }
}

# Main execution
if ($Names) {
    foreach ($n in $Names) {
        Update-Project -Name $n
    }
} else {
    Update-Project -Name "config-server"
    Update-Project -Name "eureka-server"
    Update-Project -Name "spring-boot-admin"
}
