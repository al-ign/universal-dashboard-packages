$PageTitle = 'vSphere VLAN usage by DVPG'


#Create UDPage Endpoint
$scriptBlock = {
    New-UDLayout -Columns 4 {
        New-UDCard -Endpoint {
            New-UDParagraph -Text ('This is a cached search. List is updated every 30 minutes. Last update was at ' + $Cache:VLANUsageByDVPGLastUpdate )
            }
        New-UDCounter -Title 'Unique VLAN' -Endpoint {$Cache:VLANUsageByDVPGUniqueVLAN}
        New-UDCounter -Title 'Unique DVPG' -Endpoint {$Cache:VLANUsageByDVPGUniqueDVPG}
        New-UDCounter -Title 'Skipped DVPG' -Endpoint {$Cache:VLANUsageByDVPGSkippeDVPG}
        }
    
    $arrProp = 'VLAN', 'Name', 'VM', 'View'
    New-UDTable -Title 'VLAN List by DVPG' -Headers $arrProp -ArgumentList @($arrProp) -Endpoint {
        $arrProp = $ArgumentList
        $Cache:VLANUsageByDVPG  | select VLAN, Name, VM,
        @{N='View';E={New-UDLink -Text "View" -Url ('/dvgpinfo/' + $_.Moref)}} | Out-UDTableData -Property $arrProp
        }

    New-UDTable -Title 'Empty DVPG' -Headers $arrProp -ArgumentList @($arrProp) -Endpoint {
        $arrProp = $ArgumentList
        $Cache:VLANUsageByDVPG | ? VM -eq 0 | select VLAN, Name, VM,
        @{N='View';E={New-UDLink -Text "View" -Url ('/dvgpinfo/' + $_.Moref)}} | Out-UDTableData -Property $arrProp
        }

    New-UDParagraph -Text ('Total records in the list: ' + ($Cache:VLANUsageByDVPG).Count)
    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
