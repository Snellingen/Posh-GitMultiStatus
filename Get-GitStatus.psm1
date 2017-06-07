
function Get-GitStatus
{
    param(
        [int]$Depth = 0,
        [switch]$Push,
        [switch]$Pull
    )

    # Get all repositories in the directory, assumes all of them have a .git folder
    $repsoitories = Get-ChildItem -Directory -Depth $Depth | Where-Object {Test-Path ($_.FullName + "\.git")}

    # Get the string lenght for the longest basename, use for padding.
    $maxpad = 5
    foreach ($repository in $repsoitories) {
        if ($repository.BaseName.length -gt $maxpad)
        {
            $maxpad = $repository.BaseName.length
        }
    }
    $maxpad += 10

    # Iterate through each repo and get the status
    foreach ($repository in $repsoitories)
    {

        $branch = git -C $repository.FullName name-rev --name-only HEAD
        $local = git -C $repository.FullName rev-parse --quiet "@" 2> $null
        $remote = git -C $repository.FullName rev-parse --quiet "@{u}" 2> $null
        $base = git -C $repository.FullName merge-base "@" "@{u}" 2> $null

        if ($local -eq  $remote)
        {
            Write-Host "($branch)".PadRight(10) -NoNewline
            Write-Host $repository.BaseName.padright($maxpad) -NoNewline
            Write-Host " : " -NoNewline
            Write-Host "Up-to-date" -ForegroundColor Green

        }
        elseif ($local -eq $base)
        {
            Write-Host "($branch)".PadRight(10) -NoNewline
            Write-Host $repository.BaseName.padright($maxpad) -NoNewline
            Write-Host " : " -NoNewline
            Write-Host "Need to pull" -ForegroundColor Magenta
            if ($Pull)
            {
                git -C $repository.FullName pull --quiet 2> $null
            }

        }
        elseif ($remote -eq $base)
        {
            $has_remote = -not [string]::IsNullOrEmpty(((git -C $repository.FullName branch -r) -match $branch ))

            Write-Host "($branch)".PadRight(10) -NoNewline
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
                git -C $repository.FullName push --quiet 2> $null
            }
        }
        else
        {
            Write-Host "($branch)".PadRight(10) -NoNewline
            Write-Host $repository.BaseName.padright($maxpad) -NoNewline
            Write-Host " : " -NoNewline
            Write-Host "Diverged" -ForegroundColor Red

        }

        git -C $repository.FullName status --short
    }
}
