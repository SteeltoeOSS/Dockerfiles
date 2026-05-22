#!/usr/bin/env pwsh

# =============================================================================
# update-project.ps1: Regenerate image source from start.spring.io and apply patches
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

    $imagesDirectory = Split-Path -Parent $PSCommandPath
    $imageDirectory = Join-Path $imagesDirectory $Name

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
        $bootVersion    = Get-Content (Join-Path $imageDirectory "metadata" "SPRING_BOOT_VERSION")
        $imageVersion   = Get-Content (Join-Path $imageDirectory "metadata" "IMAGE_VERSION")
    } else {
        Write-Error "No metadata found for $Name"
        return
    }

    $serverName  = $Name -replace '-', ''
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
            } else {
                Write-Host "  Spring Boot $cleanBootVersion is current in the $bootVersionTrack track" -ForegroundColor Green
            }
        }

        $cleanDefaultVersion = $initializrMetadata.bootVersion.default -replace '\.RELEASE$', ''
        $defaultVersionTrack = ($cleanDefaultVersion -split '\.')[0..1] -join '.'
        if ($defaultVersionTrack -ne $bootVersionTrack) {
            Write-Host "  (Initializr default is Spring Boot $cleanDefaultVersion / $defaultVersionTrack track)" -ForegroundColor Cyan
        }
    }

    $temporaryDirectory = Join-Path $imagesDirectory "temp_update_$Name"
    if (Test-Path $temporaryDirectory) { Remove-Item -Recurse -Force $temporaryDirectory }
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
        $committedBuildContent  = Get-Content (Join-Path $imageDirectory "source" "build.gradle") -Raw -ErrorAction SilentlyContinue

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
                        $imageVersion = $generatedBomVersion
                        $versionChangeNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { " (was $previousVersion)" }
                        Write-Host "  [UPDATED] IMAGE_VERSION -> $generatedBomVersion$versionChangeNote" -ForegroundColor Green
                    } else {
                        Write-Host "  $bomVersionKey`: $generatedBomVersion  IMAGE_VERSION: $imageVersion  (in sync)" -ForegroundColor Green
                    }
                } else {
                    # Spring Cloud release train (e.g. 2025.0.2) does not equal the artifact version;
                    # resolve it from the Spring Cloud BOM POM on GitHub.
                    $bomPomPropertyName = if ($Name -eq "eureka-server") { "spring-cloud-netflix.version" } else { "spring-cloud-config.version" }
                    $artifactVersion = $null
                    try {
                        [xml]$bomPomDocument = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/spring-cloud/spring-cloud-release/v$generatedBomVersion/spring-cloud-dependencies/pom.xml" -TimeoutSec 10
                        $artifactVersion = $bomPomDocument.project.properties.$bomPomPropertyName
                    } catch { }

                    if ($artifactVersion) {
                        if ($artifactVersion -ne $imageVersion) {
                            $previousVersion = $imageVersion
                            Set-Content (Join-Path $imageDirectory "metadata" "IMAGE_VERSION") $artifactVersion
                            $imageVersion = $artifactVersion
                            $bomVersionNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { " (was $previousVersion)" }
                            Write-Host "  [UPDATED] IMAGE_VERSION -> $artifactVersion via $bomPomPropertyName$bomVersionNote" -ForegroundColor Green
                        } else {
                            $bomVersionNote = if ($bomVersionChanged) { " (BOM $committedBomVersion -> $generatedBomVersion)" } else { "" }
                            Write-Host "  $bomVersionKey`: $generatedBomVersion  IMAGE_VERSION: $imageVersion (in sync)$bomVersionNote" -ForegroundColor Green
                        }
                    } else {
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
                        } else {
                            throw "'patch' command not found"
                        }
                    }

                    $patchOutput = $patchContent | & patch -p1 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        if ($patchContent -match '(?m)^--- /dev/null') {
                            Write-Host "  (New file patch assumed successful)"
                        } else {
                            $patchOutput | ForEach-Object { Write-Host "  $_" }
                            throw "Patch $($patch.Name) failed"
                        }
                    }
                }
            }
        }
        finally {
            Pop-Location
        }

        $sourceDirectory = Join-Path $imageDirectory "source"
        if (Test-Path $sourceDirectory) { Remove-Item -Recurse -Force $sourceDirectory }
        New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null

        # Remove files we don't want committed (repo has its own)
        Get-ChildItem -Path $extractionDirectory -Recurse -Filter "*.orig" | Remove-Item -Force
        if (Test-Path (Join-Path $extractionDirectory ".gitignore"))    { Remove-Item -Force (Join-Path $extractionDirectory ".gitignore") }
        if (Test-Path (Join-Path $extractionDirectory ".gitattributes")) { Remove-Item -Force (Join-Path $extractionDirectory ".gitattributes") }

        Copy-Item -Path "$extractionDirectory\*" -Destination $sourceDirectory -Recurse -Force

        # git does not preserve Unix execute permissions on Windows; restore the bit so Linux CI can run gradlew
        if (Test-Path (Join-Path $sourceDirectory "gradlew")) {
            & git -C $imagesDirectory update-index --chmod=+x "$Name/source/gradlew" 2>&1 | Out-Null
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

$imageNames = if ($Names) { $Names } else { @("config-server", "eureka-server", "spring-boot-admin") }

for ($index = 0; $index -lt $imageNames.Count; $index++) {
    Update-Project -Name $imageNames[$index]
    if ($index -lt $imageNames.Count - 1) {
        Write-Host ""
        Write-Host ('=' * 60) -ForegroundColor DarkGray
        Write-Host ""
    }
}
