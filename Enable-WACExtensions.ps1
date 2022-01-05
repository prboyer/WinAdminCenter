function Enable-WACExtensions {
    <#
    .SYNOPSIS
    A PowerShell Script to automate the installation and updating of extensions in Windows Admin Center.
    
    .DESCRIPTION
    The script automates the process of setting up a new Windows Admin Center Gateway instance. It will automatically install and update the specified extensions in the JSON configuration file.
    
    .PARAMETER GatewayURL
    An override parameter for the URL of the Windows Admin Center Gateway. The script will use this value defined in the function call rather than the setting in the JSON configuration file.
    
    .PARAMETER LogPath
    An override parameter for the path to the log file. The script will use this value defined in the function call rather than the setting in the JSON configuration file.

    .PARAMETER ConfigFile
    The path to the JSON configuration file. The script will use values defined in this file unless overridden by the function call parameters.
    
    .EXAMPLE
    Enable-WACExtensions -GatewayURL "https://localhost" -ConfigFile "C:\Temp\WACExtensions.json"

    .LINK
    https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell

    .NOTES
        Author: Paul Boyer
        Date: 12-21-21
    #>
    param (
        [Parameter(Mandatory=$true, ParameterSetName="ConfigFile")]
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
        [String]$GatewayURL,
        [Parameter()]
        [String]$LogPath
    )
    <# CONTANTS #>
        # Variable to store the contents of the JSON config file
        try{
            [Object]$CONFIG = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }catch{
            Write-Error "Unable to load config file." -ErrorAction Stop -ErrorVariable +INFO
        }

        # Variable to store the gateway URL
        [String]$GATEWAY;
        if($GatewayURL -ne ""){
            $GATEWAY = $GatewayURL
        }
        else{
            $GATEWAY = $CONFIG.Extensions.Gateway
        }
        
        # Create a variable to store the status information to be recorded to the log file
        [String]$global:INFO = "";

    # Import the Windows Admin Center Extensions PowerShell Module
    Import-Module "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\ExtensionTools\ExtensionTools.psm1"

    # Specify the feed to use for acquiring new extensions
    $FeedURL = Get-Feed -GatewayEndpoint $GATEWAY

    # A string array of extension titles that will be installed. Remove (or comment out) the extension to prevent installation / enablement
    [String[]]$Extensions = $CONFIG.Extensions.Extensions

    Write-Information $("{0} ******** Begin Logging *******" -f $(Get-Date -Format "G")) -InformationVariable +INFO
    Write-Information ("{0}`tConnecting to the Windows Admin Center Gateway at {1}" -f $(Get-Date -Format "G"),$GATEWAY) -InformationVariable +INFO -InformationAction Continue
    
    # List all the extensions that were in the array above, as well as their status (installed or updateable)
    Write-Information $("{0}`tList All Windows Admin Center Extensions and Their Current Status" -f $(Get-Date -Format "G")) -InformationAction Continue -InformationVariable +INFO
    [Object[]]$script:ExtensionTable = Get-Extension -GatewayEndpoint $GATEWAY | Where-Object {$_.Title -in $Extensions -and $_.IsLatestVersion -eq $true} | Select-Object Title, ID, Status, Version, IsLatestVersion | Sort-Object Title
    Write-Information ($ExtensionTable | Format-Table -AutoSize | Out-String) -InformationAction Continue -InformationVariable +INFO

    ## Installation of new Extensions
        # Show a list of all extensions to install
        Write-Information $("{0}`tWindows Admin Center Extensions to Install" -f $(Get-Date -Format "G")) -InformationAction Continue -InformationVariable +INFO
        [Object[]]$script:InstallTable = $ExtensionTable | Where-Object {$_.status -eq "available"}
        Write-Information ($InstallTable | Format-Table -AutoSize | Out-String) -InformationAction Continue -InformationVariable +INFO

        # Install the Extensions
        $InstallTable | ForEach-Object {
            try{
                Install-Extension -ExtensionID $_.ID -GatewayEndpoint $GATEWAY -Feed $FeedURL | ForEach-Object {
                    $InstallData = ($_ | Select-Object title, version, published);
                    Write-Information ("{0}`tInstalling {1} Version {2} Published on {3}" -f (Get-Date -Format "G"),$InstallData.title, $InstallData.version, $InstallData.published) -InformationAction Continue -InformationVariable +INFO
                }
            }
            catch{
                Write-Warning -Message $("Couldn't Install $($_.ID)") -WarningVariable +INFO
            }
        }

    ## Updating current Extensions to the newest version
        # Show a list of all extensions to update
        Write-Information $("`n{0}`tWindows Admin Center Extensions to Update" -f $(Get-Date -Format "G")) -InformationAction Continue -InformationVariable +INFO
        [Object[]]$script:UpdateTable = $ExtensionTable | Where-Object {$_.status -ne "Installed" -and $_.islatestversion -eq $false}
        Write-Information ($UpdateTable | Format-Table -AutoSize | Out-String) -InformationAction Continue -InformationVariable +INFO

        # Update the Extensions
        $UpdateTable | ForEach-Object {
            Update-Extension -ExtensionID $_.ID -GatewayEndpoint $GATEWAY  ForEach-Object {
                $InstallData = ($_ | Select-Object title, version, published);
                Write-Information ("{0}`tUpdating {1} to Version {2} Published on {3}" -f (Get-Date -Format "G"),$InstallData.title, $InstallData.version, $InstallData.published) -InformationAction Continue -InformationVariable +INFO
            }
        }

    # Determine the path to save the log file
    [String]$LogFilePath;
    if ($LogPath -ne "" -and $null -ne $LogPath) {
        $LogFilePath = $LogPath
    }else{
        $LogFilePath = $CONFIG.Extensions.Logs.LogPath
    }

    # Write the log file to the path
    [string]$LogFileName = "$LogFilePath\WindowsAdminCenter_Extensions_$(Get-Date -Format FileDateTime).txt"
    Write-Information ("{0}`tWriting log file to {1}" -f (Get-Date -Format "G"),$LogFileName) -InformationAction Continue -InformationVariable +INFO
    $INFO | Out-File -FilePath $LogFileName -Force

    # Cleanup old Logs by deleting logs older than the past N days
    Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.txt /D $([Int]$CONFIG.Extensions.Logs.DaysToRetainLogs) /C `"cmd.exe /c del @file /q`""
}
Enable-WACExtensions -ConfigFile $PSScriptRoot\Config.json