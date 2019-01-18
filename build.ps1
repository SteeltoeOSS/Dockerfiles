#!/usr/bin/env pwsh

# =============================================================================
# build.ps1: build script for SteeltoeOSS Docker images
# =============================================================================

# -----------------------------------------------------------------------------
# help
# -----------------------------------------------------------------------------

<#
    .SYNOPSIS
    Build Steeltoe Docker images

    .DESCRIPTION
    Builds a specified Steeltoe Docker image.

    The image will be compatible with the Docker host container type.  For example, if the Docker host is using Windows containers, the built image will be run on hosts using Windows containers.

    By default, the image will be tagged using the name '<image>:[<version>[-<rev>]]' where:
      image      the specified Image name
      version    the value of 'ImageVersion' if specified in Dockerfile
      rev        the value of 'ImageRevision' if specified in Dockerfile

    .PARAMETER Help
    Print this message.

    .PARAMETER List
    List available images.

    .PARAMETER Name
    Docker image name.

    .PARAMETER Tag
    Override the image tag.
#>

# -----------------------------------------------------------------------------
# args
# -----------------------------------------------------------------------------

param(
   [Switch] $Help,
   [Switch] $List,
   [String] $Name,
   [String] $Tag
)

# -----------------------------------------------------------------------------
# impl
# -----------------------------------------------------------------------------

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    return
}

if ($Name -And $List) {
    throw "-Name and -List are mutually exclusive"
}

$ImagesDirectory = Split-Path -Parent $PSCommandPath

if ($List) {
    Get-Childitem -Path $ImagesDirectory -Directory | Select-Object Name
    return
}

if (!$Name) {
    throw "Name not specified; run with -Help for help"
}

$ImageDirectory = Join-Path $ImagesDirectory $Name
if (!(Test-Path $ImageDirectory)) {
    throw "Unknown image $Name; run with -List to list available images"
}
$Name =Split-Path -Leaf $ImageDirectory   # this removes stuff like ".\" prefix

if (!(Get-Command "docker" -ErrorAction SilentlyContinue)) {
    throw "'docker' command not found"
}

$DockerOSMatcher = docker info 2>&1 | Select-String  -Pattern "OSType: (.*)"
if ($LastExitCode) {
    throw "Error running 'docker'; is Docker daemon running?"
}
if (!$DockerOSMatcher) {
    throw "Couldn't determine Docker OS"
}

$DockerOS = $DockerOSMatcher.Matches.Groups[1]
$DockerContextDir = Join-Path $ImageDirectory $DockerOS
$Dockerfile = Join-Path $DockerContextDir Dockerfile

if (!(Test-Path $Dockerfile)) {
    throw "No Dockerfile for $Image on $DockerOS (expected $Dockerfile)"
}

$DockerBuildFiles = Join-Path $ImageDirectory "files"
if (Test-Path $DockerBuildFiles) {
    $Target = Join-Path $DockerContextDir "files"
    if (Test-Path $Target) {
        Remove-Item -Recurse $Target
    }
    Copy-Item -Recurse $DockerBuildFiles $Target
}

if (!$Tag) {
    $Tag = "steeltoeoss/$Name"
    $VersionMatcher = Select-String -Path $Dockerfile -Pattern '^ENV\s+IMAGE_VERSION\s*=?\s*(.+)$'
    if ($VersionMatcher) {
        $Version = $VersionMatcher.Matches.Groups[1]
        $Tag += ":$Version"
        $RevisionMatcher = Select-String -Path $Dockerfile -Pattern '^ENV\s+IMAGE_REVISION\s*=?\s*(.+)$'
        if ($RevisionMatcher) {
            $Revision = $RevisionMatcher.Matches.Groups[1]
            $Tag += "-$Revision"
        }
    }
    $Tag += "-$DockerOS"
}

docker build -t $Tag $DockerContextDir

# vim: et sw=4 sts=4
