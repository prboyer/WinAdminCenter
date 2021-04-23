# Script to query AD and create a CSV file to import into Windows Admin Center
# Paul Boyer - 7-14-2020
###########################

# Import necessary modules
    Import-Module ActiveDirectory

    # Import the Windows Admin Center module
    Import-Module "$env:ProgramFiles\windows admin center\PowerShell\Modules\ConnectionTools"

### Variables ###
    $WAC_Gateway = "https://winadmin.ads.ssc.wisc.edu:6516"

    $CSV_Path = "C:\Users\Public\Documents"

### Computer Configuration ###
    $Computer_SearchBaseList = @(
        "OU=Test,DC=ads,DC=ssc,DC=wisc,DC=edu",
        "OU=Windows 10,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
        "OU=High Security,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
        "OU=Windows,OU=Anthropology,DC=ads,DC=ssc,DC=wisc,DC=edu",
        "OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu"
    )

### Server Configuration ###
    $Server_SearchBaseList = @(
        "OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu"
    )

############ CONSTANTS########
    # Constant string type for windows 10 PCs
    [String]$WIN10_PC = "msft.sme.connection-type.windows-client"

    # Constant string type for windows servers
    [String]$WIN_SERVER = "msft.sme.connection-type.server"

# Setup Logging
    # . "$env:ProgramFiles\Windows Admin Center\PowerShell\Modules\Function-Write-Log.ps1"
    # $Log = "$PSScriptRoot\Logs\$(Get-Date -Format 'yyyy-mm-dd_hh-mm-ss').log"
    # Write-Log -Message "*** Begin Log ***" -Path $Log

######## Global Functions ########
    # Parse-Tags : Takes in a string array of tags and formats them with pipe symbols
    function Parse-Tags {
        param(
            [Parameter (Mandatory = $true)]$Tags
        )

        [String]$return = "";

        if($Tags.Count -eq 1){
            $return = $Tags.ToString();
        }else{
            for ($n = 0; $n -lt $Tags.Count; $n ++){
                if($n -eq $Tags.Count -1){
                    $return += $Tags[$n]
                }
                else{
                    $return += $Tags[$n]+"|";
                }
            }
        }
        return $return;
    }
####################
# Begin importing computers
############
    # Write-Log "***Importing Computers***" -Path $Log

    # Tags to add to machines
    $COMP_TAGS = 'SSCC','Windows 10'

    # Build list of computers
    $Computers = [System.Collections.ArrayList]@();

    foreach($s in $Computer_SearchBaseList){
        Get-ADComputer -Filter * -SearchBase $s | %{

            $TAGS = $COMP_TAGS;

            switch -Wildcard ($_.DistinguishedName) {
                "CN=*,OU=Laptops,OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Mobile Lab"}
                "CN=*,OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Lab" }
                "CN=*,OU=High Security,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "High Security"}
                "CN=*,OU=Test,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS+= "Test Group"}
                Default {}
            }

            #Add computers to an array list as custom objects
            $Computers.Add(
                [PSCustomObject]@{
                    name = $_.DNSHostname
                    type = $WIN10_PC
                    tags = (Parse-Tags -Tags $TAGS);
                    groupId = "global"
                } 
            ) | Out-Null
        }
    }

##############
# Begin importing servers
############
    # Write-Log "***Importing Servers***" -Path $Log
    
    # Tags to add to machines
    $SERV_TAGS = "SSCC","Windows Server"

    # Build list of computers
    $Servers = [System.Collections.ArrayList]@();

    foreach($s in $Server_SearchBaseList){
        Get-ADComputer -Filter * -SearchBase $s | %{

            $TAGS = $SERV_TAGS;

            switch -Wildcard ($_.DistinguishedName) {
                "CN=*,OU=RDS,OU=2016,OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Winstat"}
                "CN=*,OU=SILO,OU=2016,OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Silo"}
                "CN=*,OU=SILO,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Silo"}
                "CN=*,OU=2016,OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu" {$TAGS += "Server 2016"}
                Default {}
            }

            #Add computers to an array list as custom objects
            $Servers.Add(
                [PSCustomObject]@{
                    name = $_.DNSHostname
                    type = $WIN_SERVER
                    tags = (Parse-Tags -Tags $TAGS);
                    groupId = "global"
                } 
            ) | Out-Null
        }
    }

##################
# Create the CSV file and Import
################

    # Write the connections to a CSV file
    $($Computers+$Servers)| Sort-Object -Property Name | ?{$_.Name -ne $null} | Export-Csv -Path "$CSV_Path\connections.csv" -Force -NoTypeInformation

    # Import the connections
    Import-Connection -prune -GatewayEndpoint $WAC_Gateway -FileName "$CSV_Path\connections.csv" -ErrorAction SilentlyContinue
