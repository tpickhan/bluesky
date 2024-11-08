# This script converts the aka.csv file to json files for checking into the repo
# This script along with Convert-AkaJsonToCsv is used to convert the json to csv format for easy editing in Excel
# The csv should not be checked in. The json files are the source of truth.


$filePath = $MyInvocation.MyCommand.Path
$folderPath = Split-Path $filePath -Parent
$configPath = $folderPath -replace "bluesky/build/scripts", "bluesky/website/config"
$csvFilePath = Join-Path $configPath "aka.csv"

$isHttp2Supported = !($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -eq 2) #7.2 doesn't support http2

function Get-AkaCustomObject ($item) {
    $akaLink = [PSCustomObject]@{
        title    = $item.title
        category = $item.category
        bluesky  = $item.bluesky
        twitter  = $item.twitter
        type     = $item.type
        did      = $item.did
    }

    return $akaLink
}

function Convert-AkaCsvToJson {
    Write-Host "Reading csv file from $csvFilePath"

    $csv = Import-Csv $csvFilePath

    $akaLinks = @()

    foreach ($line in $csv) {
        $akaLink = Get-AkaCustomObject $line
        $akaLinks += $akaLink
        Write-AkaObjectToJsonFile $akaLink
    }
    Write-Host "Json files created at $configPath"
}

function Write-AkaObjectToJsonFile ($akaLink) {
    $jsonFileName = $akaLink.bluesky.ToLower() -replace "/", ":"
    Write-Host "Writing to $jsonFileName.json"
    $akaLink | ConvertTo-Json | Out-File (Join-Path $configPath "$($jsonFileName).json") -Encoding utf8
}
function Convert-AkaJsonToCsv {
    Get-AkaJsonsFromFolder | Export-Csv $csvFilePath -Encoding utf8 -NoTypeInformation
    Write-Host "Csv created at $csvFilePath"
}

function Get-AkaJsonsFromFolder {
    $jsonFiles = Get-ChildItem $configPath -Filter *.json

    $akaLinks = @()
    foreach ($jsonFile in $jsonFiles) {
        Write-Host "Reading " $jsonFile.FullName
        $json = Get-Content $jsonFile.FullName | Out-String | ConvertFrom-Json

        $akaLink = Get-AkaCustomObject $json
        $akaLinks += $akaLink
    }

    return $akaLinks
}
function Update-MissingDids {
    $akaLinks = Get-AkaJsonsFromFolder
    foreach ($akaLink in $akaLinks) {

        if([string]::IsNullOrEmpty($akaLink.did)) {
            $did = Get-Did $akaLink.bluesky
            if ($did) {
                $akaLink.did = $did
                Write-AkaObjectToJsonFile $akaLink
            }
        }
        Write-Host "Update did: $($akaLink.bluesky)"
    }
}

function Get-Did($blueskyHandle) {

    $didResolveUrl = "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=$blueskyHandle"
    Write-Host "Get did: $didResolveUrl"
    if ($isHttp2Supported) {
        $request = Invoke-WebRequest -Uri $didResolveUrl -ErrorAction Ignore -SkipHttpErrorCheck -HttpVersion 2.0
    }
    else {
        $request = Invoke-WebRequest -Uri $didResolveUrl -ErrorAction Ignore -SkipHttpErrorCheck
    }

    $result = $null
    if ($request.StatusCode -eq 200) {
        $content = $request.Content.ToString()
        $json = ConvertFrom-Json $content
        $result = $json.did
    }
    return $result
}

function Update-AkaAll {
    Update-MissingDids
}

function Set-AkaGitHubAuth() {
    $token = $env:GITHUB_TOKEN
    if ([string]::IsNullOrEmpty($token)) {
        Write-Error "GITHUB_TOKEN environment variable is not set. Please set it to a valid GitHub token."
    }
    else {
        $secureString = ConvertTo-SecureString -String $token -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
        Set-GitHubAuthentication -Credential $cred -SessionOnly
    }
}

# $isUpdateGitHubIssue - If true updates GitHub (used during worklfow run). If false doesn't update GitHub (used during local batch runs)
# $isGitPush - If true, does an update back to GitHub.
function New-AkaLinkFromIssue {
    param(
        [Parameter(Mandatory = $false)]
        $issue,
        [Parameter(Mandatory = $false)]
        [string]$issueNumber,
        [Parameter(Mandatory = $false)]
        [bool]$isUpdateGitHubIssue = $true,
        [Parameter(Mandatory = $false)]
        [bool]$isGitPush = $true
    )
    if (!$issueNumber -and !$issue) {
        Write-Error "Either issue or issueNumber must be specified"
    }
    if ($issueNumber) {
        Write-Host "Process Issue: $issueNumber"
        $issue = Get-GitHubIssue  -Issue $issueNumber -OwnerName merill -RepositoryName bluesky
    }
    $issueNumber = $issue.IssueNumber

    if ([string]::IsNullOrEmpty($issue.body) -or $issue.body.IndexOf("### Bluesky profile url") -eq -1) {
        #Only process new item template
        Write-Host "Skipping issue $($issue.IssueNumber) because it doesn't match the new link template"
    }
    else {
        $lines = $issue.body.Split([Environment]::NewLine)

        $title = $lines[2]
        $bluesky = $lines[6]
        $twitter = $lines[10]
        $category = $lines[14]
        $type = $lines[18]
        if ($category -eq "None") {
            $category = $null
        }
        if ($type -eq "None") {
            $category = $null
        }

        $twitter = Get-CleanProfileName -url $twitter -prefix 'https://twitter.com/'
        $twitter = Get-CleanProfileName -url $twitter -prefix 'https://x.com/'

        $blueSky = Get-CleanProfileName -url $bluesky -prefix 'https://bsky.app/profile/'

        $exists = Test-Path (Join-Path $configPath "$($bluesky).json")

        if ($exists) {
            Write-Host "Profile already exists. Skipping $bluesky"
            if ($isUpdateGitHubIssue) {
                $message = "Thank you for submitting https://bsky.app/profile/$bluesky. This profile already exists in the [bluesky.ms](https://bluesky.ms) database. 🙏✅"
                New-GitHubIssueComment -OwnerName merill -RepositoryName bluesky -Issue $issueNumber -Body $message | Out-Null
                Update-GitHubIssue -Issue $issueNumber -State Closed -Label "Existing" -OwnerName merill -RepositoryName bluesky | Out-Null
            }
        }
        else {
            $did = Get-Did $bluesky

            if ($null -eq $did) {
                Write-Host "Invalid bluesky handle: $bluesky"
                if ($isUpdateGitHubIssue) {
                    $message = "Thank you for submitting https://bsky.app/profile/$bluesky. Unfortunately the link is not a valid Bluesky link. If this is an error, please try submitting the form again. If it is not resolved please reach out to me at https://bsky.app/profile/merill.net and let me know. Thanks!"
                    Write-Host $message
                    Write-Host "New-GitHubIssueComment"
                    New-GitHubIssueComment -OwnerName merill -RepositoryName bluesky -Issue $issueNumber -Body $message | Out-Null
                    Update-GitHubIssue -Issue $issueNumber -State Closed -Label "Invalid aka.ms link" -OwnerName merill -RepositoryName bluesky | Out-Null
                }
            }
            else {

                ## Default to new object and update if it exists
                $akaLink = Get-AkaCustomObject $newItem

                $state = "Added"

                $akaLink.title = $title
                $akaLink.bluesky = $bluesky
                $akaLink.twitter = $twitter
                $akaLink.category = $category
                $akaLink.type = $type
                $akaLink.did = $did

                Write-AkaObjectToJsonFile $akaLink

                if ($isGitPush) {
                    Write-Host "Update-AkaGitPush"
                    Update-AkaGitPush
                }

                $message = "Thank you for submitting https://bsky.app/profile/$bluesky. This profile will soon be available in the [bluesky.ms](https://bluesky.ms) database. 🙏✅"
                Write-Host $message
                if ($isUpdateGitHubIssue) {
                    Write-Host "New-GitHubIssueComment"
                    New-GitHubIssueComment -OwnerName merill -RepositoryName bluesky -Issue $issueNumber -Body $message | Out-Null
                    Update-GitHubIssue -Issue $issueNumber -State Closed -Label $state -OwnerName merill -RepositoryName bluesky | Out-Null
                }
            }
        }
    }
}

function Get-CleanProfileName($url, $prefix) {
    $profileName = $url -replace $prefix, ""
    # Remove any trailing slashes
    $profileName = $profileName -replace "/$", ""

    $profileName = $profileName.Trim()
    $profileName = $profileName.ToLower()
    return $profileName
}

# Get's all the open issues and processed them
function Update-AllOpenGitHubIssues() {

    $issues = Get-GitHubIssue -OwnerName merill -RepositoryName bluesky -State Open
    Write-Host "Found $($issues.Count) open issues"
    foreach ($issue in $issues) {
        New-AkaLinkFromIssue -issue $issue -isUpdateGitHubIssue $true -isGitPush $true
    }
}

# Get's all the closed issues and reprocess them for local testing (does not commit or update issues)
# Useful to reprocess any entries that might not have been updated to GitHub.
function Update-ReprocessAllGitHubIssuesLocal() {

    $issues = Get-GitHubIssue -OwnerName merill -RepositoryName bluesky -State Closed
    Write-Host "Found $($issues.Count) open issues"
    foreach ($issue in $issues) {
        New-AkaLinkFromIssue -issue $issue -isUpdateGitHubIssue $false -isGitPush $false
    }
}

function Update-AkaGitPush() {
    git config --global user.name 'merill'
    git config --global user.email 'merill@users.noreply.github.com'
    git add --all
    git commit -am "Automated push from new issue request"
    git push
}