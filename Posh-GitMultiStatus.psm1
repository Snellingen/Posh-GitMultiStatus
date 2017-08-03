
##############################################################################
#.SYNOPSIS
# Get a summary of the status of all the git repositories in the working directory.
#
#.DESCRIPTION
# The function will scan the working directory for git repositories and do an git remote update on them.
# It will then run "git fetch" and check the status of the local active branch and compare it to the remote so that it can
# inform if the branch is up-to-date, behind, ahead or divereged from the remote.
# The function will also display staged and unstaged files if they exist.
#
#.PARAMETER Path
# The path you want to scan for repositories, defualt is working directory.
#
#.PARAMETER Depth
# The recursive depth to scan for repositories, default is 0 (flat).
#
#.PARAMETER Push
# If set, the function will do a git push if the status is "Ahead".
# Be carefull as this automatically pushes commited changes to the remote!
#
#.PARAMETER Rebase
# If this paramter is set, the function will do a rebase where the status is "Behind".
#
#.PARAMETER NoFetch
# If set, the function will not fetch from remote, this is faster, but only compares from the last fetch.
#
#.LINK
# Https:\\github.com\user\matias\get-gitstatus
#
#.EXAMPLE
# Get-GitStatus
# This gets the status of the repositories in working directory.
#.EXAMPLE
# Get-GitStatus -Depth 1
# This gets the status of the repositories in working directory witha recursive depth of 1.
#.EXAMPLE
# Get-GitStatus -Rebase -Push
# This gets the status of the repositories in working directory, rebase and push them if they need it.
##############################################################################

function Get-GitMultiStatus
{
    param(
        [string]$Path = (Get-Location),
        [int]$Depth = 0,
        [switch]$NoFetch,
        [switch]$Push,
        [switch]$Rebase
    )

    # Get all repositories in the directory, assumes all of them have a .git folder
    $repsoitories = Get-ChildItem -Directory -Path $Path -Depth $Depth | Where-Object {Test-Path ($_.FullName + "\.git")}
    if ($repsoitories -eq $null)
    {
        Write-Host "No git repositories found"
    }

    # Get the string lenght for the longest basename, use for padding.
    $maxpad_name = 5
    $maxpad_branch = 5
    foreach ($repository in $repsoitories) {
        if ($repository.BaseName.length -gt $maxpad_name)
        {
            $maxpad_name = $repository.BaseName.length
        }
        $branch = git -C $repository.FullName name-rev --name-only HEAD 2> $null
        $length = $branch.length
        if ($length -gt $maxpad_branch)
        {
             $maxpad_branch = $length
        }
    }

    # Iterate through each repo and get the status
    foreach ($repository in $repsoitories)
    {
        if (-not $NoFetch)
        {
            git -C $repository.FullName fetch 2>&1 | out-null
        }

        $branch = git -C $repository.FullName name-rev --name-only HEAD 2> $null
        $local = git -C $repository.FullName rev-parse --quiet "@" 2> $null
        $remote = git -C $repository.FullName rev-parse --quiet "@{u}" 2> $null
        $base = git -C $repository.FullName merge-base "@" "@{u}" 2> $null

        if ($local -eq  $remote)
        {
            $status = "Up-to-date"
            WriteStatus -Status $status -Branch $branch
        }
        elseif ($local -eq $base)
        {
            $status = "Behind"
            WriteStatus -Status $status -Branch $branch -Color "Red"

            if ($Rebase)
            {
                git -C $repository.FullName rebase 2>&1 | out-null
                $status = "Up-to-date"
                WriteStatus -Status $status -Branch $branch -Update
            }

        }
        elseif ($remote -eq $base)
        {
            $has_remote = -not [string]::IsNullOrEmpty(((git -C $repository.FullName branch -r) -match $branch ))

            if ($has_remote)
            {
                $status = "Ahead"
                WriteStatus -Status $status -Branch $branch -Color "Green"

                if ($Push)
                {
                    git -C $repository.FullName push --quiet 2>&1 | out-null
                    $status = "Up-to-date"
                    WriteStatus -Status $status -Branch $branch -Update
                }
            }
            else
            {
                $status = "No remote"
                WriteStatus -Status $status -Branch $branch -Color "DarkRed"
            }
        }
        else
        {
            $status = "Diverged"
            WriteStatus -Status $status -Branch $branch -Color "Yellow"
            if ($Rebase)
            {
                git -C $repository.FullName rebase 2>&1 | out-null
                $status = "Ahead"
                WriteStatus -Status $status -Branch $branch -Color "Green" -Update

                if ($Push)
                {
                    git -C $repository.FullName push --quiet 2>&1 | out-null
                    $status = "Up-to-date"
                    WriteStatus -Status $status -Branch $branch -Update
                }
            }
        }

        Write-Host
        git -C $repository.FullName status --short
    }
}

function WriteStatus()
{
    param(
        [parameter(Mandatory=$true)]
        [string]$Status,
        [parameter(Mandatory=$true)]
        [string]$Branch,
        [switch]$Update,
        [string]$Color = "White"
    )
    if ($Update){Write-Host "`r"-NoNewline}
    else {Write-Host}
    Write-Host "($branch)".PadRight($maxpad_branch +5) -NoNewline
    Write-Host $repository.BaseName.padright($maxpad_name +5) -NoNewline
    Write-Host " : " -NoNewline
    Write-Host "$status".padright(10) -ForegroundColor $Color -NoNewline
}

export-modulemember -function Get-GitMultiStatus
