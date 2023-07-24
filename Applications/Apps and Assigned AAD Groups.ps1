#Get a list of all applications and AAD Groups they are Assigned to
# Check if module required is installed.. connect once/if installed

if(-not(Get-InstalledModule -Name Microsoft.Graph.Intune)){
    Install-Module Microsoft.Graph.Intune -AllowClobber -Scope AllUsers
}
# Connect to graph to do the things
Connect-MSGraph


# make sure our try catches work
$ErrorActionPreference = "Stop"    

# Create a custom classes to store the info we want
class CustomAppList {
    [string]$AppName
    [string]$AppSize
    [array]$AppAssignments;
}
# Create a custom class to store the info we want
class CustomGroup {
    [string]$Type
    [string]$GroupName;
}
[System.Collections.ArrayList]$appList = @()

# Add the group assignment for the policy
try {
    # Get a list of all the apps
    $clientApps = Invoke-MSGraphRequest -Url 'deviceAppManagement/mobileApps' | Get-MSGraphAllPages
    Write-Host "Successfully got the list of apps with thier assignments" -ForegroundColor Green

    foreach ($clientApp in $clientApps) {
        try {
            # Get a list of all the apps
            $clientAppAssignment = Invoke-MSGraphRequest -Url "deviceAppManagement/mobileApps/$($clientapp.id)/assignments"
            # Get the app assignment type and groups
            [System.Collections.ArrayList]$grouplist = @()
            foreach ($assignment in $clientAppAssignment.value){
                    foreach($group in $assignment){
                    $group = Invoke-MSGraphRequest -Url "groups/$($assignment.target.groupId)"

                    $CustomGroup = [CustomGroup]::new()
                    $CustomGroup.Type = $assignment.intent
                    $CustomGroup.GroupName = $group.displayName
                    $grouplist.Add($CustomGroup)
                }
            }        

            $app = [CustomAppList]::new()
            $app.AppName = $clientApp.displayName
            $app.AppSize = $clientApp.minimumFreeDiskSpaceInMB
            $app.AppAssignments = $grouplist
            $appList.Add($app)
            Write-Host "Successfully got the the assignments for app $($clientApp.displayName)" -ForegroundColor Green
        }
        catch {        
            Write-Host "Failed to retrieve the app assignments for app $($clientApp.displayName)" -ForegroundColor Red
        }
    }
}
catch {        
    Write-Host "Failed to retrieve the app list from Intune... Check the reason below" -ForegroundColor Red
    Write-Error $_
}


$filepath = $ENV:UserProfile+'\downloads\IntuneAppList.csv'
$appList | select AppName,AppSize  -ExpandProperty AppAssignments | Export-Csv $filepath -NoTypeInformation
Write-Host "A copy of the app list has been saved too $($filepath)" -ForegroundColor Green
# Disconnect-MsGraph <-- there is no disconnect option