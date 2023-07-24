#Track Expired Devices - Gather IP Address and Last User loggedin
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
    [string]$lastsync
    [string]$ipadd
    [string]$lastuser
    [string]$memberof
    [string]$disabled
    [string]$model; 
}

[System.Collections.ArrayList]$DevicesList = @()


#Select the AAD Group to search within the ' ' after DisplayName eq

$devices = get-AzureADGroupMember -All $true -ObjectId (Get-AzureADGroup -Filter "DisplayName eq 'AAD-Melbourne-Devices-Students-001-3.13-Presenter PC'").ObjectId 

foreach ($device in $devices){
try {
# Build and execute the query
    $uriRequest = [System.UriBuilder]"https://graph.microsoft.com/beta/deviceManagement/managedDevices"
    $uriRequest.Query = "filter=azureADDeviceId eq '$($device.DeviceID)'"
    $uriRequest

    $DeviceDetails = (Invoke-MSGraphRequest -url $uriRequest -HttpMethod get).Value

    $dev = [DeviceArray]::new()


    #Collect the List of Last Logged on Users
    $memberof = Invoke-MSGraphRequest -url https://graph.microsoft.com/beta/devices/$($device.ObjectID)/memberOf -HttpMethod get

    $DeviceDetails.usersLoggedOn.userId | ForEach-Object {
    $users = Invoke-MSGraphRequest -url https://graph.microsoft.com/v1.0/users/$($_)/ -HttpMethod get
    $dev.lastuser = $dev.lastuser + ", " + $users.displayName
}

    
  
    #Store the Device details to the arrat DevicesList
    $dev.deviceName = $device.DisplayName
    $dev.model = $DeviceDetails.model
    $dev.lastsync = $DeviceDetails.lastSyncDateTime
    $dev.ipadd = $DeviceDetails.hardwareInformation.wiredIPv4Addresses
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
$DevicesList | select devicename, model, serialNumber, spacefreeGB, lastsync, lastuser,  memberof, disabled | Export-Csv $filepath -NoTypeInformation
Write-Host "File has been saved: $($filepath)" -ForegroundColor Green