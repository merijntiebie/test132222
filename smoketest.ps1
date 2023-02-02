param(
    [string]$gitUsername,
    [string]$gitRepo,
    [string]$githubPAT
)

# ----- UTILITY START -----

function CheckIfVSCIsInstalled() {
    $VSC = Get-Command -Name code.cmd -ErrorAction SilentlyContinue
    if ($null -eq $VSC) { 
        Write-Error "Visual Studio Code is not installed!"
        exit 1
    }
    Write-Host "Visual Studio Code is installed"
}

function RunUnitTests() {
    Write-Host "Running unit tests"
    npm test
    if ($LASTEXITCODE -ne 0) { 
        Write-Error 'Unit tests failed' 
        exit $LASTEXITCODE
    }
    Write-Host "Unit tests passed"
}

function CheckLinterSmells() {
    Write-Host "Making Linter angry"

    $jsFile = Join-Path -Path $PSScriptRoot -ChildPath "src\linterangrymaker.js"
    New-Item -ItemType File -Path $jsFile -Force

    $code = "console.log('Hello World!')     ;     "
    Add-Content -Path $jsFile -Value $code

    npm run lint:fix

    $code = Get-Content -Path $jsFile
    if ($code -ne "console.log(`"Hello World!`");") { 
        Write-Error "Linter failed, this is the value of the file: $code" 
        exit 1
    }

    Remove-Item -Path $jsFile -Force

    Write-Host "Linter passed"
}

function CheckCommitLint() {
    Write-Host "Checking commitlint to make sure you don't commit bad messages"
    $commitMessage = "This is a bad commit message"

    git commit --allow-empty -m $commitMessage

    # git commit will return 1 if commitlint fails
    if ($LASTEXITCODE -ne 1) { 
        Write-Host "Commitlint failed, this is the commit message: $commitMessage" 
        exit 1
    }

    Write-Host "Commitlint passed"
}

function CheckGithubActions() {
    Write-Host "Checking github actions to see if the pipeline has run successfully"
    $headers = @{ "Authorization" = "Bearer $githubPAT" }
    $baseUrl = ""
    $owner = $gitUsername
    $repo = $gitRepo
    $url = "$baseUrl/repos/$owner/$repo/actions/runs"

    do {
        Write-Host "Waiting 10 seconds before checking github actions"
        Start-Sleep -Seconds 10
        Write-Host "Checking github actions"

        $response = Invoke-RestMethod -Uri $url -Headers $headers
        if ($response.total_count -eq 0) {
            Write-Error "No github actions found"
            exit 1
        }

        $runStatus = $response.workflow_runs[0].status
        $runConclusion = $response.workflow_runs[0].conclusion
    } while ($runStatus -eq "queued" -or $runStatus -eq "in_progress")

    if ($runStatus -eq "completed" -and $runConclusion -eq "success") {
        Write-Host "Pipeline has successfully run"
    }
    else {
        Write-Error "Pipeline has not successfully run or not completed"
        exit 1
    }
}

# ----- UTILITY END -----

Write-Host "Running smoke test for test132222"

CheckIfVSCIsInstalled

RunUnitTests

CheckLinterSmells

CheckCommitLint

CheckGithubActions