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
    [string]$AppName
    [string]$AppVer
    [string]$AppDev; 
}

[System.Collections.ArrayList]$AppList = @()

#Select the Applicationp to search within the ' ' after DisplayName eq
    $uriRequest = [System.UriBuilder]"https://graph.microsoft.com/beta/deviceManagement/detectedApps"
    $uriRequest.Query = "filter=displayName eq 'Photos'"
    $uriRequest


    $AppDetails = (Invoke-MSGraphRequest -url $uriRequest -HttpMethod get)

    $Devices = $AppDetails.value

    $DevicesNextLink = $AppDetails."@odata.nextLink"

        while ($DevicesNextLink -ne $null){

            $AppDetails = (Invoke-MSGraphRequest -url $DevicesNextLink -HttpMethod Get)
            $DevicesNextLink = $AppDetails."@odata.nextLink"
            $Devices += $AppDetails.value

        }

# The request comes back as an object, loop through the object, for each application, grab a list of devices installed on. $_ references the current object in the loop

$Devices | ForEach-Object {

    $Installed = Invoke-MSGraphRequest -url https://graph.microsoft.com/beta/deviceManagement/detectedApps/$($_.id)/managedDevices -HttpMethod get
    $app = [DeviceArray]::new()

    $app.AppName = $_.displayName
    $app.AppVer = $_.version

    $Installed | ForEach-Object {
    $app.AppDev = $_.value.deviceName
    }

    $AppList.Add($app)  

}


$filepath = $ENV:UserProfile+'\downloads\App.csv'
$AppList | Export-Csv $filepath -NoTypeInformation
Write-Host "File has been saved: $($filepath)" -ForegroundColor Green