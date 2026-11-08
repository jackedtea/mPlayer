# This file is part of mPlayer.
# Copyright (C) 2026 Nam <namicedtea@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# See the LICENSE file at the app root for the full notice.

# Fetches the native archives the Windows build downloads during CMake
# configure, with retries and checksums, into the folder CMake looks in.
#
# media_kit_libs_windows_video downloads libmpv and ANGLE with a single
# `file(DOWNLOAD)`, no retry, and fails the whole build on a truncated file
# ("Integrity check failed, please try to re-build project again"). A GitHub
# release download comes back short often enough to break CI. Each checks for
# an existing archive first and skips the download when its hash matches, and
# so does our own full-libmpv download in windows/CMakeLists.txt, so a valid
# file left here is simply used.
#
# The URLs and hashes are read from the CMake files themselves, so a media_kit
# upgrade or a libmpv repin needs no change here.
#
# Usage (from the app root, after `flutter pub get`):
#   pwsh windows/packaging/prefetch-native.ps1

$ErrorActionPreference = 'Stop'

$out = Join-Path $PWD 'build/windows/x64'
New-Item -ItemType Directory -Force $out | Out-Null

function Read-CMakeSets([string]$path) {
  $text = Get-Content $path -Raw
  $vars = @{}
  # `set(NAME "value")` and `set(NAME\n  "value")`.
  foreach ($m in [regex]::Matches($text, 'set\(\s*(\w+)\s+"([^"]*)"\s*\)')) {
    $vars[$m.Groups[1].Value] = $m.Groups[2].Value
  }
  # Expand ${OTHER} references between them.
  foreach ($k in @($vars.Keys)) {
    $vars[$k] = [regex]::Replace($vars[$k], '\$\{(\w+)\}', {
      param($r) if ($vars.ContainsKey($r.Groups[1].Value)) { $vars[$r.Groups[1].Value] } else { $r.Value }
    })
  }
  return $vars
}

function Get-Verified([string]$url, [string]$dest, [string]$algorithm, [string]$hash) {
  $hash = $hash.ToUpperInvariant()
  if ((Test-Path $dest) -and (Get-FileHash $dest -Algorithm $algorithm).Hash -eq $hash) {
    Write-Host "OK (already here): $dest"
    return
  }
  New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
  for ($try = 1; $try -le 5; $try++) {
    Write-Host "Downloading $url (try $try)"
    try {
      Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
      $got = (Get-FileHash $dest -Algorithm $algorithm).Hash
      if ($got -eq $hash) {
        Write-Host "OK: $dest"
        return
      }
      Write-Host "Checksum mismatch: expected $hash, got $got"
    } catch {
      Write-Host "Download failed: $($_.Exception.Message)"
    }
    Remove-Item $dest -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds (5 * $try)
  }
  throw "Could not fetch $url after 5 tries"
}

# media_kit_libs_windows_video: libmpv and ANGLE, MD5-checked.
$deps = Get-Content '.flutter-plugins-dependencies' -Raw | ConvertFrom-Json
$plugin = $deps.plugins.windows | Where-Object { $_.name -eq 'media_kit_libs_windows_video' }
if (-not $plugin) { throw 'media_kit_libs_windows_video is not a Windows plugin dependency' }
$vars = Read-CMakeSets (Join-Path $plugin.path 'windows/CMakeLists.txt')

foreach ($name in 'LIBMPV', 'ANGLE') {
  foreach ($k in $name, "${name}_URL", "${name}_MD5") {
    if (-not $vars.ContainsKey($k)) { throw "$k not found in the media_kit CMakeLists" }
  }
  Get-Verified $vars["${name}_URL"] (Join-Path $out $vars[$name]) 'MD5' $vars["${name}_MD5"]
}

# Our own full libmpv (windows/CMakeLists.txt), SHA256-checked.
$ours = Read-CMakeSets 'windows/CMakeLists.txt'
Get-Verified $ours['FULL_LIBMPV_URL'] `
  (Join-Path $out "libmpv-full/$($ours['FULL_LIBMPV_ARCHIVE'])") `
  'SHA256' $ours['FULL_LIBMPV_SHA256']
