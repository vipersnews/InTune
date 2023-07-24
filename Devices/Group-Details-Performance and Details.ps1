#Install If needed
#Install-Module AzureAD

Try {
    Write-Host "Authenticating with MS Graph and Azure AD…" -NoNewline
    $intuneId = Connect-MSGraph -ErrorAction Stop
    $aadId = Connect-AzureAD -AccountId $intuneId.UPN -ErrorAction Stop
    Write-host "Success" -ForegroundColor Green
}
Catch {
    Write-host "Error!" -ForegroundColor Red
    Write-host "$($_.Exception.Message)" -ForegroundColor Red
    Return
}

#Check all possibilities on https://developer.microsoft.com/en-us/graph/graph-explorer searching https://graph.microsoft.com/beta/deviceManagement/managedDevices?$filter=azureADDeviceId eq 'a8fdeca4-edb2-46e5-b617-74cbd4ca9cba'

class DeviceArray {
    [string]$deviceName
    [string]$serialNumber
    [int64]$spacefreeGB
    [int64]$corebootminutes
    [int64]$coreLoginTimeInMins
    [string]$averageBlueScreens
    [string]$averageRestarts
    [string]$memberof
    [string]$disabled
    [string]$model; 
}

[System.Collections.ArrayList]$DevicesList = @()



#Select the AAD Group to search within the ' ' after DisplayName eq

$devices = get-AzureADGroupMember -All $true -ObjectId (Get-AzureADGroup -Filter "DisplayName eq 'AAD-Corporate-Devices-Students-DELL'").ObjectId 

foreach ($device in $devices){
try {
# Build and execute the query
    $uriRequest = [System.UriBuilder]"https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    $uriRequest.Query = "filter=azureADDeviceId eq '$($device.DeviceID)'"
    $uriRequest

    $DeviceDetails = (Invoke-MSGraphRequest -url $uriRequest -HttpMethod get).Value

    $dev = [DeviceArray]::new()

    #Some devices fail retrieving performance stats, so use a try catch so it can still collect available data
    try {
    $DevicePerf = Invoke-MSGraphRequest -url https://graph.microsoft.com/beta/deviceManagement/userExperienceAnalyticsDevicePerformance/$($DeviceDetails.id) -HttpMethod get
            $dev.corebootminutes = $DevicePerf.coreBootTimeInMs / 100 / 60
            $dev.coreLoginTimeInMins = $DevicePerf.coreLoginTimeInMs / 100 / 60
        }
                 catch {
            $dev.corebootminutes = "0000"
            $dev.coreLoginTimeInMins = "0000"    
            Write-Host "Failed to retrieve Performance Details " -ForegroundColor Yellow
            }

    #Collect the Student AAD Group Membership Details
    $memberof = Invoke-MSGraphRequest -url https://graph.microsoft.com/beta/devices/$($device.ObjectID)/memberOf -HttpMethod get
    


    #Store the Device details to the arrat DevicesList
    $dev.deviceName = $device.DisplayName
    $dev.model = $DeviceDetails.model
    $dev.serialNumber = $DeviceDetails.serialNumber
    $dev.spacefreeGB = $DeviceDetails.freeStorageSpaceInBytes / 1073741824
    $dev.memberof = $memberof.value.displayName -like "*Students-0*"
    $dev.disabled = $memberof.value.displayName -like "Disabled-Devices"
    $DevicesList.Add($dev)
    }

     catch {        
            Write-Host "Failed to retrieve Group Member Details " -ForegroundColor Red
        }
    }


#Write to File

$filepath = $ENV:UserProfile+'\downloads\StudentFleet.csv'
$DevicesList | select devicename, model, serialNumber, spacefreeGB, corebootminutes, coreLoginTimeInMins,  memberof, disabled | Export-Csv $filepath -NoTypeInformation
Write-Host "File has been saved: $($filepath)" -ForegroundColor Green