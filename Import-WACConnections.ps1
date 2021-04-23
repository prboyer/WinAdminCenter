function Import-WACConnections {
    # param (
    #     [Parameter(Mandatory=$true)]
    #     [String]
    #     $Gateway,
    #     [Parameter(Mandatory=$true)]
    #     [ValidateScript({
    #         # Check that a path to a CSV file was passed
    #         if([IO.Path]::getExtension($_) -eq "csv"){
    #             $true
    #         }else{
    #             $false
    #         }
    #     })]
    #     [String]
    #     $FilePath
    # )
    #Requires -Module ActiveDirectory

    $Gateway = "EST"

    # Import required modules
        Import-Module $PSScriptRoot\Modules\ConnectionTools\ConnectionTools.psm1

    <# CONSTANTS #>
        # Constant string type for windows 10 PCs
        [String]$WIN_PC = "msft.sme.connection-type.windows-client"

        # Constant string type for windows servers
        [String]$WIN_SERVER = "msft.sme.connection-type.server"

        # Variable to hold log information
        [String]$INFO

    <# Variables #>
        # Computer Configuration #
        [String[]]$Computer_SearchBaseList = @(
            "OU=Test,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Windows 10,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=High Security,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Windows,OU=Anthropology,DC=ads,DC=ssc,DC=wisc,DC=edu",
            "OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu"
        )

        # Server Configuration #
        [String[]]$Server_SearchBaseList = @(
            "OU=Servers,OU=Service,DC=ads,DC=ssc,DC=wisc,DC=edu"
        )
    <# Discover Computers to import into WAC #>
        Write-Information $("{0}`tBegin importing Computers into Windows Admin Center ({1})`n" -f $(Get-Date -Format "G"),$Gateway.ToUpper()) -InformationVariable +INFO

        # Tags to apply to all imported computers
        [String[]]$Computer_Tags = "SSCC","Windows 10"

        # Array list to hold Computer objects
        [System.Collections.ArrayList]$Computers = @(); 

        # Parse through the SearchBase list for computer objects
        foreach($s in $Computer_SearchBaseList){
            Get-ADComputer -Filter * -SearchBase $s | ForEach-Object{
                # Clear tagging for each iteration through the loop. Then add back in necessary tags
                [String[]]$Tags = "";
                $Tags += $Computer_Tags;

                # For each computer, evaluate what search base it falls into and then apply additional tags as appropriate
                switch -Wildcard ($_.DistinguishedName) {
                    "CN=*,OU=Laptops,OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu" {$Tags += "Mobile Lab"}
                    "CN=*,OU=Lab,DC=ads,DC=ssc,DC=wisc,DC=edu" {$Tags += "Lab" }
                    "CN=*,OU=High Security,OU=SSCC,DC=ads,DC=ssc,DC=wisc,DC=edu" {$Tags += "High Security"}
                    "CN=*,OU=Test,DC=ads,DC=ssc,DC=wisc,DC=edu" {$Tags += "Test Group"}
                    Default {}
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
                    Write-Information $("`n{0}`tDiscovered PC {1}" -f $(Get-Date -Format "G"),$Computers[$_].name) -InformationVariable +INFO
                }
            }
        }

}
Import-WACConnections