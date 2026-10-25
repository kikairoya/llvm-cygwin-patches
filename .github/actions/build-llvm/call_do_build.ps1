[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $BuildArgs = @()
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $Env:ACTION_PATH 'do_build.sh'

if ($Env:RUNNER_OS -eq "Linux") {
    exec bash -e -o pipefail $scriptPath @BuildArgs
    exit $LASTEXITCODE
}

$unsudoPath = Join-Path $Env:ACTION_PATH 'unsudo'
& clang "--target=x86_64-w64-mingw32" "${unsudoPath}.cc" "-o" "${unsudoPath}.exe" "-O" "-Wl,-s" "-nodefaultlibs" "-nostartfiles" "-ladvapi32" "-lkernel32" "-fuse-ld=lld" "-e" "main"

$cygwinRoot = [IO.Path]::GetFullPath($Env:CYGWIN_ROOT)
$cygwinBin = Join-Path $cygwinRoot 'bin'
$Env:PATH = "$cygwinBin;$Env:PATH"
$bashPath = Join-Path $cygwinBin 'bash.exe'

Remove-Item Env:TEMP -ErrorAction SilentlyContinue
Remove-Item Env:TMP -ErrorAction SilentlyContinue

# The build script expects these variables to be Cygwin-format paths.
foreach ($name in @('ACTION_PATH', 'LLVM_PATH', 'PATCH_PATH')) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) {
        $result = & cygpath "-u" "${value}"
        if ($LASTEXITCODE -eq 0) {
            [Environment]::SetEnvironmentVariable($name, ($result | Select-Object -Last 1).Trim(), 'Process')
        }
    }
}

& "${unsudoPath}.exe" $bashPath -e -o pipefail -o igncr $scriptPath @BuildArgs
exit $LASTEXITCODE
