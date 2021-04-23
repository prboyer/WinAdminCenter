# Script to automate the process of updating Windows Admin Center extensions
# Paul B 7-15-2020
###################

#### Variables ####
$Gateway = "https://winadmin.ads.ssc.wisc.edu:6516"

$FirewallRuleGUID = "{73B0202C-49FF-4F2B-9BD3-5F56F61147C3}"

# The other firewall rule
#"{D0BCD2EC-B6A5-4B45-918F-6B75CD219100}" 

$DefaultMSFeed = "https://aka.ms/sme-extension-feed"

########
#Import WAC module
Import-Module "$env:ProgramFiles\windows admin center\PowerShell\Modules\ExtensionTools"

#Disable Windows Firewall
Get-NetFirewallRule $FirewallRuleGUID  | Disable-NetFirewallRule

Start-Sleep -Seconds 5

#Add Feed
$feeds = Get-Feed $Gateway

if ($feeds -notcontains $DefaultMSFeed ) {
    Add-Feed -GatewayEndpoint $Gateway -Feed $DefaultMSFeed
}

#Update Extensions
Get-Extension $Gateway | %{
    Update-Extension $Gateway $_.id
}

Start-Sleep -Seconds 10

#Enable Windows Firewall
Get-NetFirewallRule $FirewallRuleGUID  | Enable-NetFirewallRule