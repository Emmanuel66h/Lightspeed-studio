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
    throw "Package-Windows.ps1 requires CI environment"
}

if ( ! ( [System.Environment]::Is64BitOperatingSystem ) ) {
    throw "obs-studio requires a 64-bit system to build and run."
}

if ( $PSVersionTable.PSVersion -lt '7.2.0' ) {
    Write-Warning 'The obs-studio packaging script requires PowerShell Core 7. Install or upgrade your PowerShell version: https://aka.ms/pscore6'
    exit 2
}

function Package {
    trap {
        Write-Error $_
        exit 2
    }

    $ScriptHome = $PSScriptRoot
    $ProjectRoot = Resolve-Path -Path "$PSScriptRoot/../.."

    $UtilityFunctions = Get-ChildItem -Path $PSScriptRoot/utils.pwsh/*.ps1 -Recurse

    foreach ( $Utility in $UtilityFunctions ) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    Install-BuildDependencies -WingetFile "${ScriptHome}/.Wingetfile"

    # Determine package version.
    # Use Git tags when available.
    # Otherwise use OBS_VERSION_OVERRIDE for Lightspeed Studio.

    $GitDescription = git describe --tags --long 2>$null

    if ( $LASTEXITCODE -eq 0 -and $GitDescription ) {

        Write-Host "Git description: $GitDescription"

        $Tokens = ($GitDescription -split '-')

        if ( $Tokens.Count -ge 3 ) {
            $CommitVersion = $Tokens[0..$($Tokens.Count - 3)] -join '-'
            $CommitHash = $($Tokens[-1]).SubString(1)
            $CommitDistance = $Tokens[-2]

            if ( $CommitDistance -gt 0 ) {
                $OutputName = "obs-studio-${CommitVersion}-${CommitHash}"
            }
            else {
                $OutputName = "obs-studio-${CommitVersion}"
            }
        }
        else {
            throw "Invalid Git description returned: $GitDescription"
        }

    }
    else {

        if ( $env:OBS_VERSION_OVERRIDE ) {

            $CommitVersion = $env:OBS_VERSION_OVERRIDE

            Write-Warning "No Git tags found."
            Write-Host "Using OBS_VERSION_OVERRIDE: $CommitVersion"

            $OutputName = "obs-studio-${CommitVersion}"

        }
        else {

            $CommitVersion = '30.0.0-lightspeed'

            Write-Warning "No Git tags found and OBS_VERSION_OVERRIDE is not set."
            Write-Warning "Using fallback version: $CommitVersion"

            $OutputName = "obs-studio-${CommitVersion}"
        }
    }

    Write-Host "Package output name: ${OutputName}"

    $CpackArgs = @(
        '-C', "${Configuration}"
    )

    if ( $DebugPreference -eq 'Continue' ) {
        $CpackArgs += ('--verbose')
    }

    Log-Group "Packaging obs-studio..."

    Push-Location -Stack PackageTemp "build_${Target}"

    try {

        cpack @CpackArgs

        if ( $LASTEXITCODE -ne 0 ) {
            throw "CPack failed with exit code $LASTEXITCODE."
        }

        $Package = Get-ChildItem `
            -Filter "obs-studio-*-windows-${Target}.zip" `
            -File `
            -ErrorAction SilentlyContinue

        if ( -not $Package ) {
            throw "Could not find generated package: obs-studio-*-windows-${Target}.zip"
        }

        Write-Host "Generated package:"
        Write-Host $Package.FullName

        $OutputPackage = "${OutputName}-windows-${Target}.zip"

        Write-Host "Renaming package to:"
        Write-Host $OutputPackage

        Move-Item `
            -Path $Package.FullName `
            -Destination $OutputPackage `
            -Force

        Write-Host "Package created successfully:"
        Write-Host (Join-Path (Get-Location) $OutputPackage)

    }
    finally {

        Pop-Location -Stack PackageTemp
    }
}

Package