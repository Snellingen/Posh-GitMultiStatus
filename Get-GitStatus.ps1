<#
    First find all repositories in the folder, this is done by checking if
    the directory contrains a .git directory
#>

param(
    [switch]$Push,
    [switch]$Pull
)

$repsoitories = Get-ChildItem -Directory | Where-Object {Test-Path ($_.FullName + "\.git")}

# Get the string lenght for the longest basename, use for padding.
$maxpad = 5
foreach ($repository in $repsoitories) {
    if ($repository.BaseName.length -gt $maxpad)
    {
        $maxpad = $repository.BaseName.length
    }
}
$maxpad += 20

# Ithereate through each repo and get the status
foreach ($repository in $repsoitories)
{
    $local = git -C $repository.FullName rev-parse --quiet "@" 2> $null
    $remote = git -C $repository.FullName rev-parse --quiet "@{u}" 2> $null
    $base = git -C $repository.FullName merge-base "@" "@{u}" 2> $null

    if ($local -eq  $remote)
    {
        Write-Host $repository.BaseName.padright($maxpad) -NoNewline
        Write-Host " : " -NoNewline
        Write-Host "Up-to-date" -ForegroundColor Green

    }
    elseif ($local -eq $base)
    {
        Write-Host $repository.BaseName.padright($maxpad) -NoNewline
        Write-Host " : " -NoNewline
        Write-Host "Need to pull" -ForegroundColor Magenta
        if ($Pull)
        {
            git -C $repository pull --quiet 2> $null
        }

    }
    elseif ($remote -eq $base)
    {
        $has_remote = -not [string]::IsNullOrEmpty(((git -C $repository branch -r) -match (git -C $repository name-rev --name-only HEAD)))

        Write-Host $repository.BaseName.padright($maxpad) -NoNewline
        Write-Host " : " -NoNewline
        if ($has_remote)
        {
            Write-Host "Need to push" -ForegroundColor Yellow
        }
        else
        {
            Write-Host "No remote" -ForegroundColor Red
        }

        if ($Push)
        {
            git -C $repository push --quiet 2> $null
        }
    }
    else
    {
        Write-Host $repository.BaseName.padright($maxpad) -NoNewline
        Write-Host " : " -NoNewline
        Write-Host "Diverged" -ForegroundColor Red

    }

    git -C $repository status --short
}
