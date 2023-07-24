# Create a file browser dialog to select a CSV file
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{
    InitialDirectory = [Environment]::GetFolderPath('Desktop')
    Filter = 'SpreadSheet (*.csv)|*.csv'
}
$null = $FileBrowser.ShowDialog()

$csvPath = $FileBrowser.FileName

# Import the CSV file
$csvData = Import-Csv -Path $csvPath

$ServiceTags = @()

# Iterate through each entry in the CSV data
foreach ($entry in $csvData) {
    # Output the value from the "Serial Number" column to the host
    $serialNumber = $entry.'serialNumber'
    $ServiceTags += $serialNumber
}

# The section above is the section where data is being passed to the varible $ServiceTags this being the Serial Numbers it finds in the csv file
###########################################################################################################################################################

# Set constant variables
Set-Variable API_KEY -Option Constant -Value 'APIKEYGOESHERE' -ErrorAction SilentlyContinue
Set-Variable KEY_SECRET -Option Constant -Value 'SECRETGOESHERE' -ErrorAction SilentlyContinue

Set-Variable AUTH_URI -Option Constant -Value 'https://apigtwb2c.us.dell.com/auth/oauth/v2/token' -ErrorAction SilentlyContinue
Set-Variable WARRANTY_URI -Option Constant -Value 'https://apigtwb2c.us.dell.com/PROD/sbil/eapi/v5/asset-entitlements' -ErrorAction SilentlyContinue

# Function to retrieve the access token
function Get-Token {
    $encodedOAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$API_KEY`:$KEY_SECRET"))
    $authHeaders = @{'Authorization' = "Basic $encodedOAuth"}
    $authBody = 'grant_type=client_credentials'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $authResult = Invoke-RestMethod -Uri $AUTH_URI -Method Post -Headers $authHeaders -Body $authBody
    return $authResult.access_token
}

$token = Get-Token
$headers = @{'Accept' = 'application/json'; 'Authorization' = "Bearer $token"}

# Function to calculate the difference between two dates
function Get-DateDifference {
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$StartDate,

        [Parameter(Mandatory = $true)]
        [DateTime]$EndDate
    )

    # Calculate the difference
    $years = $EndDate.Year - $StartDate.Year
    $months = $EndDate.Month - $StartDate.Month
    $days = $EndDate.Day - $StartDate.Day

    # Adjust for negative differences
    if ($days -lt 0) {
        $months -= 1
        $days += [DateTime]::DaysInMonth($StartDate.Year, $StartDate.Month)
    }
    if ($months -lt 0) {
        $years -= 1
        $months += 12
    }

    # Create a formatted string for the result
    $result = "{0} years, {1} months, and {2} days" -f $years, $months, $days

    # Output the result
    $result
}

# Get the current date and time
$currentTime = Get-Date -Format "dd_MM_yyyy_HH_mm_ss"

# Get the current logged-in user
$currentUserName = $env:USERNAME

# Output file path
$csvFilePath = "C:\temp\Dell_Warranty_${currentUserName}_${currentTime}.csv"

$batchSize = 99
$csvDataCount = $ServiceTags.Count
$currentIndex = 0

$uniqueServiceTags = $ServiceTags | Select-Object -Unique

while ($currentIndex -lt $uniqueServiceTags.Count) {
    # Get the current batch of service tags
    $batchEndIndex = [Math]::Min($currentIndex + $batchSize - 1, $uniqueServiceTags.Count - 1)
    $currentBatch = $uniqueServiceTags[$currentIndex..$batchEndIndex]

    # Prepare the request body for the current batch
    $body = @{'servicetags' = ($currentBatch -join ', ')}

    # Invoke the REST API for the current batch
    $assets = Invoke-RestMethod -Uri $WARRANTY_URI -Method Get -Headers $headers -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue

    if ($assets) {
        $csvData = foreach ($asset in $assets) {
            if ($asset.invalid) {
                continue
            }
            $serviceTag = $asset.serviceTag
            $WarrantyEndDateRaw = ((($asset.entitlements) | Sort-Object -Property endDate -Descending | Select-Object -First 1 -ExpandProperty endDate).split("T"))[0]
            $WarrantyEndDate = $WarrantyEndDateRaw | Get-Date -Format "dd-MM-yyyy"
            $WarrantyStartDateRaw = (($asset.entitlements) | Sort-Object -Property startDate | Select-Object -First 1 -ExpandProperty startDate).split("T")[0]
            $WarrantyStartDate = $WarrantyStartDateRaw | Get-Date -Format "dd-MM-yyyy"
            $WarrantyLevel = ($asset.entitlements) | Sort-Object -Property endDate -Descending | Select-Object -First 1 -ExpandProperty serviceLevelDescription
            $Model = $asset.productLineDescription

            # Calculate the date difference
            $startDate = Get-Date
            $endDate = [datetime]::ParseExact($WarrantyEndDateRaw, "yyyy-MM-dd", $null)
            $result = Get-DateDifference -StartDate $startDate -EndDate $endDate

            $object = New-Object PSObject -Property @{
                'Service Tag' = $serviceTag
                'Model' =  $Model
                'Warranty Level' =  $WarrantyLevel
                'Start Date' = $WarrantyStartDate
                'End Date' = $WarrantyEndDate
                'Remain' = $result
            }

            $object | Select-Object 'Service Tag', 'Model', 'Warranty Level', 'Start Date', 'End Date', 'Remain'
        }

        # Export the current batch to the CSV file (append mode)
        $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Append
    }

    $currentIndex += $batchSize
}
