---
Author: Paul Boyer
external help file: WinAdminCenter-help.xml
Module Guid: 59e65a61-edfe-4a14-b887-ca777d6b2e17
Module Name: WinAdminCenter
online version:
schema: 2.0.0
---

# Import-WACConnections

## SYNOPSIS
Script for importing Computers and Servers into Windows Admin Center

## SYNTAX

### ConfigFile
```
Import-WACConnections [-GatewayURL <String>] [-CSVPath <String>] -ConfigFile <String> [-Quiet]
 [<CommonParameters>]
```

### CommandLine
```
Import-WACConnections -GatewayURL <String> -CSVPath <String> [-LogPath <String>] [-Quiet] [<CommonParameters>]
```

### CustomMatching
```
Import-WACConnections [-ComputersCustomMatching] [-ServersCustomMatching] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
The script will import computers and servers into Windows Admin Center as global connections that all users can utilize.
It reads in settings from a JSON configuration file, and then generates a CSV file that can be imported into WAC.

## EXAMPLES

### EXAMPLE 1
```
Import-WACConnections -GatewayURL "http://localhost:8080" -CSVPath "C:\Temp\Connections.csv" -ConfigFile "C:\Temp\Config.json"
```

In this example, the script will ignore the gateway URL from the configuration file, and instead use the one specified by the -Gateway parameter.
Similarly, the CSV file will be saved to the C:\Temp directory, rather than the location specified in the configuration file.
Other parameters in the configuration file will be applied.

### EXAMPLE 2
```
Import-WACConnections -ConfigFile "C:\Temp\Config.json"
```

The script will use all values from the configuration file.

## PARAMETERS

### -GatewayURL
An override parameter for the gateway URL.
If not specified, the script will attempt to determine the gateway URL from the configuration file.

```yaml
Type: String
Parameter Sets: ConfigFile
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: CommandLine
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -CSVPath
An override parameter for the location to save the CSV file.
If not specified, the script will attempt to determine the location from the configuration file.

```yaml
Type: String
Parameter Sets: ConfigFile
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: CommandLine
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
An override parameter for the location to save the log file.
If not specified, the script will attempt to determine the location from the configuration file.

```yaml
Type: String
Parameter Sets: CommandLine
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConfigFile
Path to the JSON configuration file.
If not specified, the script will fail to continue execution.

```yaml
Type: String
Parameter Sets: ConfigFile
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ComputersCustomMatching
An override parameter that tells the script to ignore the default tagging algorithm for computers and instead use the custom matching algorithm.
It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.

```yaml
Type: SwitchParameter
Parameter Sets: CustomMatching
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServersCustomMatching
An override parameter that tells the script to ignore the default tagging algorithm for servers and instead use the custom matching algorithm.
It will not use the tags defined in the JSON file and will instead rely on the tags defined in the custom section of the script.

```yaml
Type: SwitchParameter
Parameter Sets: CustomMatching
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quiet
A switch parameter that sets the InformationPreference to SilentlyContinue.
This will limit the standard output of the script.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Paul Boyer
Date: 4-23-21

## RELATED LINKS

[https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell](https://docs.microsoft.com/en-us/windows-server/manage/windows-admin-center/configure/use-powershell)

