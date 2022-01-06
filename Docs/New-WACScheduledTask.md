---
Author: Paul Boyer
external help file: WinAdminCenter-help.xml
Module Guid: e2aed9d2-2a17-4273-b9ab-909fc8bd5531
Module Name: WinAdminCenter
online version:
schema: 2.0.0
---

# New-WACScheduledTask

## SYNOPSIS
This script creates Scheduled Tasks to run functions on a schedule to automate Windows Admin Center tasks.

## SYNTAX

```
New-WACScheduledTask [-ConfigFile] <String> [-Extensions] [-Connections] [[-ExtensionsFile] <String>]
 [[-ConnectionsFile] <String>] [<CommonParameters>]
```

## DESCRIPTION
The script can be used to create a scheduled task to run a function on a schedule.
You can use the function to setup a scheduled execution of either the connections management or extensions management script included in this repo.

## EXAMPLES

### EXAMPLE 1
```
New-WACScheduledTask -ConfigFile "C:\WAC\WACScheduledTask.json" -Extensions
```

In this example the script will create a scheduled task to run the extensions management script.

### EXAMPLE 2
```
New-WACScheduledTask -ConfigFile "C:\WAC\WACScheduledTask.json" -Connections -ConnectionsFile "C:\WAC\Connections.csv"
```

In this example the script will create a scheduled task to run the connections management script, but will use the specified path to the connections management script rather than the one in the JSON file.

## PARAMETERS

### -ConfigFile
Path to the JSON configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Extensions
Switch parameter directing the script to register a scheduled task to run the extensions management script.

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

### -Connections
Switch parameter directing the script to register a scheduled task to run the connections management script.

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

### -ExtensionsFile
An override parameter to specify the path to the extensions management script.
This supersedes the default path to the script configured in the JSON file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ConnectionsFile
An override parameter to specify the path to the connections management script.
This supersedes the default path to the script configured in the JSON file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Paul Boyer
Date: 01-06-2022

## RELATED LINKS

[http://woshub.com/group-managed-service-accounts-in-windows-server-2012/](http://woshub.com/group-managed-service-accounts-in-windows-server-2012/)

