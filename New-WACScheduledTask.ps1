<#
.SYNOPSIS
This script creates Scheduled Tasks to run functions on a schedule to automate Windows Admin Center tasks.

.DESCRIPTION
The script can be used to create a scheduled task to run a function on a schedule. You can use the function to setup a scheduled execution of either the connections management or extensions management script included in this repo.

.PARAMETER ConfigFile
Path to the JSON configuration file.

.PARAMETER Extensions
Switch parameter directing the script to register a scheduled task to run the extensions management script.

.PARAMETER Connections
Switch parameter directing the script to register a scheduled task to run the connections management script.

.PARAMETER ExtensionsFile
An override parameter to specify the path to the extensions management script. This supersedes the default path to the script configured in the JSON file.

.PARAMETER ConnectionsFile
An override parameter to specify the path to the connections management script. This supersedes the default path to the script configured in the JSON file.

.EXAMPLE
New-WACScheduledTask -ConfigFile "C:\WAC\WACScheduledTask.json" -Extensions

In this example the script will create a scheduled task to run the extensions management script.

.EXAMPLE
New-WACScheduledTask -ConfigFile "C:\WAC\WACScheduledTask.json" -Connections -ConnectionsFile "C:\WAC\Connections.csv"

In this example the script will create a scheduled task to run the connections management script, but will use the specified path to the connections management script rather than the one in the JSON file.

.LINK
http://woshub.com/group-managed-service-accounts-in-windows-server-2012/

.NOTES
    Author: Paul Boyer
    Date: 01-06-2022
#>
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({
        # Check that a path to a JSON file was passed
        if([IO.Path]::getExtension($_) -eq ".json"){
            $true
        }else{
            $false
        }
    })]
    [String]
    $ConfigFile,
    [Parameter()]
    [Switch]
    $Extensions,
    [Parameter()]
    [Switch]
    $Connections,
    [Parameter()]
    [string]
    $ExtensionsFile,
    [Parameter()]
    [string]
    $ConnectionsFile
)

# Import the settings from the JSON config file
[Object]$CONFIG = Get-Content -Raw -Path $ConfigFile | ConvertFrom-Json

# Configure settings for the scheduled task. Applies to both Extensions and Connections tasks
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Create a new scheduled task for Extension Management if $Extensions is true
if($Extensions){
    [String] $ExtensionsAction
    # Check if a value for the ExtensionsFile parameter was passed. Then assign the appropriate action to $ExtensionsAction
    if ($ExtensionsFile -ne "") {
        $ExtensionsAction = $ExtensionsFile
    }else{
        $ExtensionsAction = $CONFIG.ScheduledTask.Action.ExtensionPath
    }

    # Create the action for the Extension Management scheduled task
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$($ExtensionsAction)`" -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden"

    # Create the trigger for the Extension Management scheduled task
    $Trigger = New-ScheduledTaskTrigger -Daily -At $($CONFIG.ScheduledTask.Trigger.ExtensionTime)

    # Create the principal for the Extension Management scheduled task
    $Principal = New-ScheduledTaskPrincipal -UserId $($CONFIG.ScheduledTask.Principal.UserId) -LogonType Password -RunLevel Highest

    # Create the scheduled task for Extension Management
    Register-ScheduledTask -TaskPath "\WindowsAdminCenter" -TaskName "Windows Admin Center - Extension Management" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Scheduled Task that runs every day at $($CONFIG.ScheduledTask.Trigger.ExtensionTime) to update and install WAC extensions." -Force
}elseif ($Connections) {
    [String] $ConnectionsAction
    # Check if a value for the ConnectionsFile parameter was passed. Then assign the appropriate action to $ConnectionsAction
    if ($ConnectionsFile -ne "") {
        $ConnectionsAction = $ConnectionsFile
    }else{
        $ConnectionsAction = $CONFIG.ScheduledTask.Action.ConnectionPath
    }

    # Create the action for the Connection Management scheduled task
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$($ConnectionsAction)`" -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -WindowStyle Hidden"

    # Create the trigger for the Connection Management scheduled task
    $Trigger = New-ScheduledTaskTrigger -Daily -At $($CONFIG.ScheduledTask.Trigger.ExtensionTime)

    # Create the principal for the Connection Management scheduled task
    $Principal = New-ScheduledTaskPrincipal -UserId $($CONFIG.ScheduledTask.Principal.UserId) -LogonType Password 

    # Create the scheduled task for Connection Management
    Register-ScheduledTask -TaskPath "\WindowsAdminCenter" -TaskName "Windows Admin Center - Connections Management" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Description "Scheduled Task that runs every day at $($CONFIG.ScheduledTask.Trigger.ConnectionTime) to update and import computer and server connections into WAC." -Force 
}else{
    Write-Error "No action specified. Please specify either -Extensions or -Connections."
}