
#App Registration Information will need to be changed to your environment
$TenantID = ""
$ClientID = ""
$ClientSecret = ""

#Change for your tenant and script to match the group of devices that need a category
$DeviceGroupID = ""

#Change for your tenant and script
$DeviceCategoryID = ""

#Json body for connection to graph
$Body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $ClientID
    Client_Secret = $ClientSecret
}

#Connect to graph and get token
$Connection = Invoke-RestMethod `
    -Uri https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token `
    -Method POST `
    -Body $body

#Token from Connection variable
$Token = ConvertTo-SecureString -string $Connection.access_token -AsPlainText -Force

#May need to install module the first time uncomment if you do
#Install-Module -Name Microsoft.Graph.DeviceManagement

#Add module for Intune Device Management
Import-Module -Name Microsoft.Graph.DeviceManagement

Import-Module -Name Microsoft.Graph.Groups

Import-Module -name Microsoft.Graph.Identity.DirectoryManagement



#Connect via App Registration using token we got earlier
Connect-MgGraph -AccessToken $Token 

#Grab all the group members from Entra
$GroupMembers = Get-MgGroupMember -GroupId $DeviceGroupID -All

$90daysago = [DateTime]::Now.AddDays(-90)

Foreach ($Device in $GroupMembers) {
    $Device_Name = $Device.AdditionalProperties.displayName
    $Device_Object_Id = $Device.Id

    if ( $90daysago -lt [DateTime]$Device.AdditionalProperties.approximateLastSignInDateTime -and $Device.AdditionalProperties.isManaged) {
    
        $EntraDevice = Get-MgDevice -DeviceId $Device_Object_Id
        $EntraDeviceID = $EntraDevice.deviceid
   
        $IntuneDevice = Get-MgDeviceManagementManagedDevice -Filter "Azureaddeviceid eq '$EntraDeviceID'" -Property "Id"

        $DeviceID = $IntuneDevice.Id
        $ref = '$ref'

        $loopbody = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategoryID" }

        Invoke-MggraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$DeviceId/deviceCategory/$ref" -Body $loopbody -ContentType "Application/JSON"

        Write-Output  "Completed attempted category update for $Device_Name `n " 
    }
    else {

        Write-Output "Skipped $Device_Name with ID: $Device_Object_Id as it was not seen in the last 90 days and/or shows as not managed `n"
   
    }
}
