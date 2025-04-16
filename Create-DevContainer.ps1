param (
    [bool]
    $debug = $false,
    [bool]
    $dry = $false
)

#region Variables
# Get Values for SSL and DNS
$settings = @{
    accept_eula				= $true
    containerName			= "bcserver"
    memoryLimit				= "8G"
    updateHosts				= $true
}
#endregion Variables

#region Functions
function Test-IsAdmin {
    # Check if the current user has administrative privileges
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Read-String {
    param (
        [string[]]$message,
        [string]$prompt = "Enter string",
        [ValidateSet("Plain", "Secure", "SecureMasked")]
        [string]$mode = "Plain"
    )

    $validInput = $false
    $userInput = $null

    foreach ($line in $message) {
        Write-Host $line
    }

    while (-not $validInput) {
        switch ($mode) {
            "Plain" {
                $userInput = Read-Host -Prompt $prompt
                $validInput = $true
            }
            "Secure" {
                $userInput = Read-Host -Prompt $prompt
		        if (-not $userInput){
		            Write-Host "Input cannot be null or empty. Please try again."
                } else {
		            $userInput = $userInput | ConvertTo-SecureString -AsPlainText -Force
		            $validInput = $true
		        }
            }
            "SecureMasked" {
                $userInput = Read-Host -Prompt $prompt -AsSecureString
		        $validInput = $true
            }
        }
    }
    return $userInput
}


function Read-StringNonEmpty {
    param (
        [string[]]$message,
        [string]$prompt = "Enter string",
        [ValidateSet("Plain", "Secure", "SecureMasked")]
        [string]$mode = "Plain"
    )

    $validInput = $false
    $userInput = $null

    foreach ($line in $message) {
        Write-Host $line
    }

    while (-not $validInput) {
        switch ($mode) {
            "Plain" {
                $userInput = Read-Host -Prompt $prompt
		        if (-not $userInput){
                    Write-Host "Input cannot be null or empty. Please try again."
                } else {
                    $validInput = $true
                }
            }
            "Secure" {
                $userInput = Read-Host -Prompt $prompt
                if (-not $userInput){
                    Write-Host "Input cannot be null or empty. Please try again."
                } else {
                $userInput = $userInput | ConvertTo-SecureString -AsPlainText -Force
                $validInput = $true
                }
            }
            "SecureMasked" {
                $userInput = Read-Host -Prompt $prompt -AsSecureString
                $validInput = $true
            }
        }
    }
    return $userInput
}

function Get-Selection {
    param (
        [string[]]$message,
        [string[]]$choices,
        [int]$default
    )

    # Bounds checking the Index given defaulting to 0 if invalid
    if ($defaultChoice -lt 0 -or $defaultChoice -ge $choices.Length) {
        $defaultChoice = 0
    }

    foreach ($line in $message) {
        Write-Host $line
    }

    for ($i = 0; $i -lt $choices.Length; $i++) {
        if ($i -eq $defaultChoice) {
            Write-Host "$i. $($choices[$i]) *"
        } else {
            Write-Host "$i. $($choices[$i])"
        }
    }

    $prompt = "Please select a choice (0 to $($choices.Length - 1)," +
    " or leave empty for [$($choices[$defaultChoice])])"

    while ($true) {
        $userSelection = Read-Host -Prompt $prompt

        # If no input is provided (empty or whitespace), return the default
        if (-not $userSelection.Trim()) {
            return $choices[$defaultChoice]
        }

        if (-not [int]::TryParse($userSelection, [ref]$null)) {
            Write-Host "Invalid selection: '$userSelection'. Please enter a numeric value."
        } else {
            $index = [int]$userSelection
            if ($index -ge 0 -and $index -lt $choices.Length) {
                return $choices[$index]
            } else {
                Write-Host "Invalid selection: '$userSelection'. Please select a valid choice."
            }
        }
    }
}

function Read-PathWithExtensions {
    param (
        [string[]]$message,
        [string]$inputPrompt = "Enter path",
        [string[]]$validExtensions
    )

    $validPath = $false
    $path = ""

    foreach ($line in $message) {
        Write-Host $line
    }

    while (-not $validPath) {
        $path = Read-Host $inputPrompt
        $path = TrimQuotes -value $path
        if ("" -eq $path){
            Write-Host "Empty String is not an path. Try again." -ForegroundColor Red
            continue
        }

        if (Test-Path $path) {
            $fileExtension = [System.IO.Path]::GetExtension($path)
            if ($validExtensions -contains $fileExtension) {
                return $path
            } else {
                Write-Host "The file does not have a valid extension." + 
                " Accepted extensions are: $($validExtensions -join ', ')"
            }
        } else {
            Write-Host "Invalid path. Try again." -ForegroundColor Red
        }
    }

    return $path
}

function BranchDBType{
    param (
        [ValidateSet("chronus", "bak", "sql")]
        [string]$type
    )
    switch($type){
        "chronus"{
            return
        }
        "bak"{
            return Get-BakValues
        }
        "sql"{
            return Get-SQLValues
        }
    }
}

function Get-BakValues{
    $bakPathPrompt = @(
        "Please specify the absolute path of the database backup (.bak file) you want to use."
        "Note: The Backup should be from the same version as the containers version"
    )
    $bakPathIPrompt = "Enter Path"
    $settings["bakFile"] = Read-PathWithExtensions -message $bakPathPrompt `
        -inputPrompt $bakPathIPrompt `
        -validExtensions @(".bak")
}

function Get-SQLValues{
    # 1. Read in Database Server
    $dbServerPrompt = @(
        "Please Specify the Hostname of the Server running the SQL Server."
        "Specify localhost or . if the server is hosted on this device."
    )
    $dbServerIPrompt = "Enter Hostname"
    $settings["databaseServer"] = Read-StringNonEmpty -message $dbServerPrompt `
                                    -prompt $dbServerIPrompt
    Clear-Host
    # 2. Read in Database Instance
    $dbInstancePrompt = "Please Specify the Database Instance you want to use."
    $dbInstanceIPrompt = "Enter Instance"
    $settings["DatabaseInstance"] = Read-StringNonEmpty -message $dbInstancePrompt `
                                    -prompt $dbInstanceIPrompt
    Clear-Host
    # 3. Read in Database Name
    $dbNamePrompt = "Please Enter the Name of the Database you want to use."
    $dbNameIPrompt = "Enter Name"
    $settings["DatabaseName"] = Read-StringNonEmpty -message $dbNamePrompt `
                                -inputPrompt $dbNameIPrompt
    Clear-Host
    # 4. Read in Database User
    $dbUserPrompt = "Please Enter the Username for the Database User you want to use."
    $dbUserIPrompt = "Enter Username"
    $dbUser = Read-StringNonEmpty -message $dbUserPrompt `
                -prompt $dbUserIPrompt
    Clear-Host
    # 5. Read in Database Password as SecureString
    $dbPasswordPrompt = "Please Enter the Password for the User you entered previously"
    $dbPasswordIPrompt = "Enter Password"
    $dbPassword = Read-StringNonEmpty -message $dbPasswordPrompt `
                    -prompt $dbPasswordIPrompt `
                    -mode "SecureMasked"
    Clear-Host
    # 6. Generate PSCredential
    $settings["databaseCredential"] = New-Object pscredential $dbUser, $dbPassword
}

function TrimQuotes {
    param (
        [string]$value
    )
    # Check if the string starts and ends with the same type of quote
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        return $value.Substring(1, $value.Length - 2)
    }
    return $value
}

function Get-HashtableValues {
    param (
        [Hashtable]$hashtable
    )

    foreach ($key in $hashtable.Keys) {
        $value = $hashtable[$key]
        $valueAsString = $value.ToString()

        Write-Host "${key}: $valueAsString"
    }
}
#endregion Functions

#region Script
if (-not (Test-IsAdmin)) {
    Write-Host "This script requires administrative privileges. Please run as administrator." -ForegroundColor Red
    exit 1
}
#region ContainerName
Clear-Host
$conNamePrompt = @(
    "Enter the name of the container."
    "Container names are case sensitive and must start with a letter."
    "We recommend short lower case names as container names."
)
$conNameIPrompt = "Enter the Container name (default bcserver)"
$temp = Read-String -message $conNamePrompt -prompt $conNameIPrompt
if ($temp -ne "") {
    $settings["containerName"] = $temp
}
#endregion ContainerName
Clear-Host
#region License
$licensePrompt = @(
    "Please specify a license file url."
    "If you do not specify a license file, you will use the default Cronus Demo License."
)
$licenseIPrompt = "Enter License Path (default blank)"
$temp = Read-String -message $licensePrompt -prompt $licenseIPrompt
if ($temp -ne "") {
	$settings["licenseFile"] = TrimQuotes -value $temp
}
#endregion License
Clear-Host
#region Memory Limit
$memLimitPrompt = @(
    "How much memory will be given to the Container?"
    "The Recommended Values are:"
    "4G for demo/test usage of BC"
    "4-8G for App development"
    "16G for base App development"
)
$memLimitIPrompt = "Enter the Memory Limit (default 8G)"
$temp = Read-String -message $memLimitPrompt -prompt $memLimitIPrompt
if ($temp -ne ""){
    $settings["memoryLimit"] = $temp
}
#endregion Memory Limit
Clear-Host
#region Artifact
# TODO: Add support for the Get-BcArtifactURL
$artifactPrompt = @(
    "What Version of Business Central is needed?"
    "Please Specify an Artifact Url for the Version you want to use."
)
$artifactIPrompt = "Enter URL"
$temp = Read-String -message $artifactPrompt -prompt $artifactIPrompt
if ($temp -ne ""){
    $settings["artifactUrl"] = TrimQuotes -value $temp
}
#endregion Artifact
# TODO: DNS
# TODO: SSL
# TODO: Auth
Clear-Host
#region DB Type 
$dbPrompt = "Choose which kind of Database you would like to use for this container?"
$dbChoices = @(
    "chronus"
    "bak"
    "sql"
)
$dbChoice = Get-Selection -message $dbPrompt -choices $dbChoices -default 0
#endregion DB Type
Clear-Host
# Branch Off to Read the required Data for the choice
BranchDBType -type $dbChoice

if (-not $dry){
    #Splatted call to New-BcContainer
    New-BcContainer @settings
} else {
    Get-HashtableValues -hashtable $settings
}
#endregion Script
