[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string] $Target = 'x64',

    [ValidateSet('Debug', 'RelWithDebInfo', 'Release', 'MinSizeRel')]
    [string] $Configuration = 'RelWithDebInfo'
)

$ErrorActionPreference = 'Stop'

if ( $DebugPreference -eq 'Continue' ) {
    $VerbosePreference = 'Continue'
    $InformationPreference = 'Continue'
}

if ( $env:CI -eq $null ) {
    throw "Build-Windows.ps1 requires CI environment"
}

if ( ! ( [System.Environment]::Is64BitOperatingSystem ) ) {
    throw "obs-studio requires a 64-bit system to build and run."
}

if ( $PSVersionTable.PSVersion -lt '7.2.0' ) {
    Write-Warning 'The obs-studio PowerShell build script requires PowerShell Core 7. Install or upgrade your PowerShell version: https://aka.ms/pscore6'
    exit 2
}

function Build {
    trap {
        Pop-Location -Stack BuildTemp -ErrorAction 'SilentlyContinue'
        Write-Error $_
        Log-Group
        exit 2
    }

    $ScriptHome = $PSScriptRoot
    $ProjectRoot = Resolve-Path -Path "$PSScriptRoot/../.."

    $UtilityFunctions = Get-ChildItem -Path $PSScriptRoot/utils.pwsh/*.ps1 -Recurse

    foreach ($Utility in $UtilityFunctions) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    Install-BuildDependencies -WingetFile "${ScriptHome}/.Wingetfile"

    Push-Location -Stack BuildTemp
    Ensure-Location $ProjectRoot

    # ============================================================
    # Lightspeed Studio version
    # ============================================================
    #
    # The Lightspeed Studio repository does not contain the original
    # OBS release tags. Without an OBS tag, git describe can return
    # the commit hash, which is not a valid OBS version.
    #
    # Explicitly provide a valid OBS version to CMake.
    #
    # ============================================================

    $ObsVersion = '30.0.0-lightspeed'

    $CmakeArgs = @(
        '--preset', "windows-ci-${Target}"
        "-DOBS_VERSION_OVERRIDE=$ObsVersion"
    )

    $CmakeBuildArgs = @('--build')
    $CmakeInstallArgs = @()

    if ( $DebugPreference -eq 'Continue' ) {
        $CmakeArgs += '--debug-output'
        $CmakeBuildArgs += '--verbose'
        $CmakeInstallArgs += '--verbose'
    }

    $CmakeBuildArgs += @(
        '--preset', "windows-${Target}"
        '--config', $Configuration
        '--parallel'
        '--', '/consoleLoggerParameters:Summary', '/noLogo'
    )

    $CmakeInstallArgs += @(
        '--install', "build_${Target}"
        '--prefix', "${ProjectRoot}/build_${Target}/install"
        '--config', $Configuration
    )

    # ============================================================
    # Configure
    # ============================================================

    Log-Group "Configuring obs-studio..."

    Write-Host "OBS Studio version: $ObsVersion"
    Write-Host "Windows target: $Target"
    Write-Host "Build configuration: $Configuration"

    Invoke-External cmake @CmakeArgs

    # ============================================================
    # Build
    # ============================================================

    Log-Group "Building obs-studio..."

    Invoke-External cmake @CmakeBuildArgs

    # ============================================================
    # Install
    # ============================================================

    Log-Group "Installing obs-studio..."

    Invoke-External cmake @CmakeInstallArgs

    Pop-Location -Stack BuildTemp

    Log-Group
}

Build