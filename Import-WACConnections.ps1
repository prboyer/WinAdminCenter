function Import-WACConnections {
    <#
    .SYNOPSIS
    Script for importing Computers and Servers into Windows Admin Center

    .DESCRIPTION
    The script will import computers and servers into Windows Admin Center as global connections that all users can utilize. It reads in settings from a JSON configuration file, and then generates a CSV file that can be imported into WAC.
    
    .PARAMETER Gateway
    An override parameter for the gateway URL. If not specified, the script will attempt to determine the gateway URL from the configuration file.
    
    .PARAMETER CSVPath
    An override parameter for the location to save the CSV file. If not specified, the script will attempt to determine the location from the configuration file.
    
    .PARAMETER LogPath
    An override parameter for the location to save the log file. If not specified, the script will attempt to determine the location from the configuration file.
    
    .PARAMETER ConfigFile
    Path to the JSON configuration file. If not specified, the script will fail to continue execution.
    
    .PARAMETER ComputersCustomMatching
    An override parameter that tells the script to ignore the default tagging algorithm for computers and instead use the custom matching algorithm. It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.
    
    .PARAMETER ServersCustomMatching
    An override parameter that tells the script to ignore the default tagging algorithm for servers and instead use the custom matching algorithm. It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.
    
    .PARAMETER Quiet
    A switch parameter that sets the InformationPreference to SilentlyContinue. This will limit the standard output of the script.
    
    .EXAMPLE
    Import-WACConnections -Gateway "http://localhost:8080" -CSVPath "C:\Temp\Connections.csv" -ConfigFile "C:\Temp\Config.json"

    In this example, the script will ignore the gateway URL from the configuration file, and instead use the one specified by the -Gateway parameter. Similarly, the CSV file will be saved to the C:\Temp directory, rather than the location specified in the configuration file. Other parameters in the configuration file will be applied.

    .EXAMPLE
    Import-WACConnections -ConfigFile "C:\Temp\Config.json"

    The script will use all values from the configuration file.
    
    .LINK
    https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell

    .NOTES
        Author: Paul Boyer
        Date: 4-23-21
    #>
    param (
        [Parameter(Mandatory=$true, ParameterSetName="CommandLine")]
        [Parameter(Mandatory=$false, ParameterSetName="ConfigFile")]
        [String]
        $Gateway,
        [Parameter(Mandatory=$true, ParameterSetName="CommandLine")]
        [Parameter(Mandatory=$false, ParameterSetName="ConfigFile")]
        [String]
        $CSVPath,
        [Parameter(Mandatory=$false, ParameterSetName="CommandLine")]
        [String]
        $LogPath,
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
        [Parameter(Mandatory=$false, ParameterSetName="CustomMatching")]
        [Switch]
        $ComputersCustomMatching,
        [Parameter(Mandatory=$false, ParameterSetName="CustomMatching")]
        [Switch]
        $ServersCustomMatching,
        [Parameter(Mandatory=$false)]
        [Switch]
        $Quiet

    )
    #Requires -Module ActiveDirectory
    
    # Set script verbosity
    if($Quiet){
        $InformationPreference = "SilentlyContinue"
    }else{
        $InformationPreference = "Continue"
    }

    # Import required modules
        Import-Module "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\ConnectionTools\ConnectionTools.psm1"
    
        <# CONSTANTS #>
        # Variable to store the contents of the JSON config file
        try{
            [Object]$CONFIG = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json
        }catch{
            Write-Error "Unable to load config file." -ErrorAction Stop -ErrorVariable +INFO
        }

        # Constant string type for windows 10 PCs
        [String]$WIN_PC = "msft.sme.connection-type.windows-client"

        # Constant string type for windows servers
        [String]$WIN_SERVER = "msft.sme.connection-type.server"

        # Constant for storing the Gateway URL
        [String]$GATEWAY;
        if($Null -eq $Gateway -or $Gateway -eq ""){
            $GATEWAY = $CONFIG.Connections.Gateway
        }else{
            $GATEWAY = $Gateway
        }

        # Variable to hold log information
        [String]$INFO

    <# Variables #>
        # Computer Configuration #
        [String[]]$Computer_SearchBaseList = $CONFIG.Connections.Computers.SearchBases.SearchBase

        # Server Configuration #
        [String[]]$Server_SearchBaseList = $CONFIG.Connections.Servers.SearchBases.SearchBase

    Write-Information $("{0} ******** Begin Logging *******" -f $(Get-Date -Format "G")) -InformationVariable +INFO

    <# Discover Computers to import into WAC #>
        Write-Information $("{0}`tBegin importing Computers into Windows Admin Center ({1})" -f $(Get-Date -Format "G"),$GATEWAY.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported computers
        [String[]]$Computer_Tags = $CONFIG.Connections.Computers.DefaultTags

        # Array list to hold Computer objects
        [System.Collections.ArrayList]$Computers = @(); 

        # Parse through the SearchBase list for computer objects
        foreach($s in $Computer_SearchBaseList){
            Get-ADComputer -Filter * -SearchBase $s | ForEach-Object{
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default computer tags
                $Tags += $Computer_Tags;

                if(-not $ComputersCustomMatching){
                    # Apply the tags correlated to the SearchBase
                    $Tags += ($CONFIG.Connections.Computers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
                }else{
                    <# CUSTOM MATCHING FOR COMPUTER OBJECTS #>
                    <# Enter custom matching logic in this section #>
                    


                    <# End of custom matching section. Do not modify code outside this section.#>
                }

                #Add computers to an array list as custom objects
                $Computers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_PC
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("{0}`t`tDiscovered PC {1}" -f $(Get-Date -Format "G"),$Computers[$_].name) -InformationVariable +INFO
                }
            }
        }
    <# Discover Servers to import into WAC #>
        Write-Information $("{0}`tBegin importing Servers into Windows Admin Center ({1})" -f $(Get-Date -Format "G"),$GATEWAY.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported servers
        [String[]]$Server_Tags = $CONFIG.Connections.Servers.DefaultTags

        # Array list to hold all Server objects
        [System.Collections.ArrayList]$Servers = @();

        foreach($s in $Server_SearchBaseList){
            Get-ADComputer -Filter * -SearchBase $s | ForEach-Object {
    
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$private:Tags = $null;

                # Apply the default server tags
                $Tags += $Server_Tags;

                if(-not $ServersCustomMatching){
                    # Apply the tags correlated to the SearchBase
                    $Tags += ($CONFIG.Connections.Servers.SearchBases | Where-Object{$_.SearchBase -eq $s}).Tags;
                }else{
                    <# CUSTOM MATCHING FOR SERVER OBJECTS #>
                    <# Enter custom matching logic in this section #>
                    


                    <# End of custom matching section. Do not modify code outside this section.#>
                }

                #Add computers to an array list as custom objects
                $Servers.Add(
                    [PSCustomObject]@{
                        name = $_.DNSHostname
                        type = $WIN_SERVER
                        tags = $($Tags -join '|');
                        groupId = "global"
                    } 
                ) | ForEach-Object {
                    Write-Information $("{0}`t`tDiscovered Server {1}" -f $(Get-Date -Format "G"),$Servers[$_].name) -InformationVariable +INFO
                }
            }
        }
    
    <# Generate a CSV file for importing into WAC #>
        # Resolve the $CSVPath location
        if ($null -eq $CSVPath -or $CSVPath -eq ""){
            $CSVPath = $CONFIG.Connections.Computers.CSVFilePath
        }
    
        # Write the connections to a CSV file
        Write-Information $("{0}`tGenerating a CSV file and saving to {1}" -f $(Get-Date -Format "G"),$CSVPath) -InformationVariable +INFO
        [String]$CSVFileName = "$CSVPath\WindowsAdminCenter_DeviceDiscovery_$(Get-Date -Format FileDateTime).csv"
        $($Computers+$Servers)| Sort-Object -Property Name | Where-Object {$null -ne $_.Name} | Export-Csv -Path $CSVFileName -Force -NoTypeInformation

    <# Import connections into WAC from the generated CSV file #>
        Write-Information $("{0}`tImporting CSV file {1} to WAC ({2})" -f $(Get-Date -Format "G"),$CSVPath,$GATEWAY) -InformationVariable +INFO
        Import-Connection -Prune -GatewayEndpoint $GATEWAY -FileName $CSVFileName -ErrorAction SilentlyContinue -ErrorVariable +INFO -InformationVariable +INFO

    <# Write Log to File #>
        # Determine where to write the log file
        if ($null -eq $LogPath -or $LogPath -eq ""){
            $LogPath = $CONFIG.Connections.Logs.LogPath
        }
        Write-Information $("{0}`tWriting Log file to {1}" -f $(Get-Date -Format "G"),$($(Split-Path $LogPath -Parent)+"\"+$(Get-Date -Format FileDateTime)+".txt")) -InformationVariable +INFO
        Write-Information $("{0} ******** Finished Logging *******" -f $(Get-Date -Format "G")) -InformationVariable +INFO
        $INFO | Out-File -FilePath  $($LogPath+"\"+$(Get-Date -Format FileDateTime)+".txt") -Force

    <# Cleanup old Logs by deleting logs older than the past N days #>
        Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.txt /D $([Int]$CONFIG.Connections.Logs.DaysToRetainLogs) /C `"cmd.exe /c del @file /q`""

    <# Cleanup old CSVs by deleting files older than the past N days #>
        Start-Process -FilePath cmd.exe -ArgumentList "/c forfiles /P $LogPath /M *.csv /D $([Int]$CONFIG.Connections.CSV.DaysToRetainCSV) /C `"cmd.exe /c del @file /q`""
}
Import-WACConnections -ConfigFile "$PSScriptRoot\Config.json"