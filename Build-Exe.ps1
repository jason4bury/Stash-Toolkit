#requires -Version 5.1
<#
.SYNOPSIS
    Builds a small Stash-Toolkit.exe launcher next to Stash-Toolkit.ps1.

.DESCRIPTION
    This does NOT embed the toolkit script inside the exe. An earlier
    version of this script used the ps2exe module for that and it failed:
    Stash-Toolkit.ps1 is several megabytes (mostly a bundled WebView2
    component), and ps2exe compiles a script by embedding its entire text
    as one giant string literal in generated C# source. At this size that
    "succeeded" with no error but produced a corrupt .exe that Windows
    refused to load ("the given assembly name or codebase was invalid").

    Instead, this compiles a tiny stand-alone launcher .exe using nothing
    but PowerShell's own built-in C# compiler -- no module to install, no
    internet access needed. The launcher just starts
    "powershell.exe -File Stash-Toolkit.ps1" with no console window.
    Stash-Toolkit.ps1 stays next to the exe as its own file; the exe is
    only a shortcut that skips the right-click > Run with PowerShell step
    and the console window, not a container for the script.

    The exe's icon comes from stash-toolkit-icon.ico, or
    stash-toolkit-icon.png (converted to .ico automatically), next to this
    script -- pass -IconPath to use a different image. No icon is found,
    it builds without a custom one rather than failing.

    Needs Windows PowerShell 5.1's compiler, not PowerShell 7's -- if you
    run this under PowerShell 7, it automatically re-launches itself under
    Windows PowerShell 5.1 (powershell.exe) to do the actual build, so you
    don't need to do anything differently either way.

.EXAMPLE
    .\Build-Exe.ps1
    Builds Stash-Toolkit.exe next to Stash-Toolkit.ps1, using
    stash-toolkit-icon.ico/.png next to this script if present.

.EXAMPLE
    .\Build-Exe.ps1 -IconPath .\some-other-icon.png
    Builds the exe using a different image as its icon.
#>
[CmdletBinding()]
param(
    [string]$ScriptPath,
    [string]$OutputPath,
    [string]$IconPath
)

$ErrorActionPreference = 'Stop'

# Resolve the folder this script lives in. $PSScriptRoot can come back empty
# depending on how the script was launched (some "Run with PowerShell" setups,
# certain -Command invocations, etc.), so fall back to $PSCommandPath / the
# older $MyInvocation form, and only as a last resort the current directory.
$here = $PSScriptRoot
if (-not $here) {
    $herePath = $PSCommandPath
    if (-not $herePath) { $herePath = $MyInvocation.MyCommand.Path }
    if (-not $herePath) { $herePath = $MyInvocation.MyCommand.Definition }
    if ($herePath) { $here = Split-Path -Parent $herePath }
}
if (-not $here) { $here = (Get-Location).Path }

if (-not $ScriptPath) { $ScriptPath = Join-Path $here 'Stash-Toolkit.ps1' }
if (-not $OutputPath) { $OutputPath = Join-Path $here 'Stash-Toolkit.exe' }

if ($PSVersionTable.PSEdition -eq 'Core') {
    Write-Host 'Running under PowerShell 7 -- switching to Windows PowerShell 5.1 to build the .exe (its compiler is the one that can produce a stand-alone exe this way; PowerShell 7 is fine for running the toolkit itself, just not for this one build step)...'
    $relaunchTarget = $PSCommandPath
    if (-not $relaunchTarget) { $relaunchTarget = $MyInvocation.MyCommand.Path }
    if (-not $relaunchTarget) { $relaunchTarget = Join-Path $here 'Build-Exe.ps1' }
    $forwardedArgs = foreach ($key in $PSBoundParameters.Keys) { '-' + $key; $PSBoundParameters[$key] }
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $relaunchTarget @forwardedArgs
    exit $LASTEXITCODE
}

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Can't find $ScriptPath -- run this from the folder containing Stash-Toolkit.ps1, or pass -ScriptPath."
}
$scriptFileName = Split-Path -Leaf $ScriptPath

# ---------------------------------------------------------------------------
# Icon: auto-detect stash-toolkit-icon.ico/.png next to this script unless
# -IconPath was given; convert a .png to .ico (a single 256x256 image --
# plenty for a taskbar/Explorer icon, just not a hand-tuned multi-size one).
# ---------------------------------------------------------------------------
function Convert-PngToIcon {
    param([Parameter(Mandatory)][string]$PngPath, [Parameter(Mandatory)][string]$IcoPath)
    Add-Type -AssemblyName System.Drawing
    $source = [System.Drawing.Image]::FromFile($PngPath)
    try {
        $size = 256
        $square = New-Object System.Drawing.Bitmap($size, $size)
        try {
            $g = [System.Drawing.Graphics]::FromImage($square)
            try {
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.DrawImage($source, 0, 0, $size, $size)
            } finally { $g.Dispose() }
            $hIcon = $square.GetHicon()
            $icon = [System.Drawing.Icon]::FromHandle($hIcon)
            try {
                $fs = [System.IO.File]::Open($IcoPath, [System.IO.FileMode]::Create)
                try { $icon.Save($fs) } finally { $fs.Dispose() }
            } finally { $icon.Dispose() }
        } finally { $square.Dispose() }
    } finally { $source.Dispose() }
}

if (-not $IconPath) {
    $candidateIco = Join-Path $here 'stash-toolkit-icon.ico'
    $candidatePng = Join-Path $here 'stash-toolkit-icon.png'
    if (Test-Path -LiteralPath $candidateIco) { $IconPath = $candidateIco }
    elseif (Test-Path -LiteralPath $candidatePng) { $IconPath = $candidatePng }
}

$icoForCompile = $null
if ($IconPath) {
    if (-not (Test-Path -LiteralPath $IconPath)) {
        throw "Icon file not found: $IconPath"
    }
    if ([IO.Path]::GetExtension($IconPath) -ieq '.ico') {
        $icoForCompile = $IconPath
    } else {
        Write-Host "Converting $IconPath to a .ico for the exe..."
        $icoForCompile = Join-Path ([IO.Path]::GetTempPath()) 'stash-toolkit-icon-build.ico'
        Convert-PngToIcon -PngPath $IconPath -IcoPath $icoForCompile
    }
    Write-Host "Using icon: $IconPath"
} else {
    Write-Host 'No icon found (looked for stash-toolkit-icon.ico / stash-toolkit-icon.png next to this script) -- building without a custom icon.'
}

Write-Host "Building $OutputPath (a launcher for $scriptFileName, which stays alongside it) ..."

$source = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

internal static class StashToolkitLauncher
{
    [STAThread]
    private static void Main()
    {
        string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string scriptPath = Path.Combine(exeDir, "$scriptFileName");

        if (!File.Exists(scriptPath))
        {
            MessageBox.Show(
                "Can't find $scriptFileName next to this .exe.\n\nExpected at:\n" + scriptPath,
                "Stash Toolkit",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + scriptPath + "\"",
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            Process.Start(psi);
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                "Could not start Stash Toolkit:\n\n" + ex.Message,
                "Stash Toolkit",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }
}
"@

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

# Compiled directly via CSharpCodeProvider (rather than the simpler Add-Type
# -OutputAssembly/-OutputType parameters) because that's what lets us pass
# the /win32icon compiler option to embed the icon. No preceding Add-Type
# call is needed for this -- CSharpCodeProvider/CompilerParameters live in
# Microsoft.CSharp.dll/System.dll, which Windows PowerShell 5.1 already has
# loaded. (An earlier version of this script added
# "Add-Type -AssemblyName System.CodeDom" here, which actually broke this:
# .NET Framework has no assembly literally named "System.CodeDom" -- that's
# a .NET Core/5+ package name -- so the call failed, and Add-Type's assembly
# -load failures are thrown in a way that ignores -ErrorAction, stopping the
# script even with SilentlyContinue.)
$provider = New-Object Microsoft.CSharp.CSharpCodeProvider
$compilerParams = New-Object System.CodeDom.Compiler.CompilerParameters
$compilerParams.GenerateExecutable = $true
$compilerParams.OutputAssembly = $OutputPath
[void]$compilerParams.ReferencedAssemblies.Add('System.dll')
[void]$compilerParams.ReferencedAssemblies.Add('System.Windows.Forms.dll')
$compilerOptions = '/target:winexe'
if ($icoForCompile) { $compilerOptions += " /win32icon:`"$icoForCompile`"" }
$compilerParams.CompilerOptions = $compilerOptions

$results = $provider.CompileAssemblyFromSource($compilerParams, $source)
if ($results.Errors.HasErrors) {
    foreach ($err in $results.Errors) { Write-Host $err.ToString() }
    throw 'Compilation failed -- see errors above.'
}

if (Test-Path -LiteralPath $OutputPath) {
    Write-Host "Done: $OutputPath"
    Write-Host "Keep $scriptFileName in the same folder -- the exe just launches it, it doesn't contain it."
} else {
    throw 'Compilation reported no errors, but no .exe was produced.'
}
