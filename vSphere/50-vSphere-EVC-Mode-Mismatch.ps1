$PageTitle = 'vSphere EVC Mode Mismatch'


#Create UDPage Endpoint
$scriptBlock = {
    #Your content here

    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }

    $clusterGroup = get-view -ViewType ClusterComputeResource -Property Name,'summary' | Where-Object { $PSItem.Summary.CurrentEVCModeKey }
    if ($clusterGroup) {
        $clusterGroup.UpdateViewData('host.vm.Name','host.vm.config.Version','host.vm.Runtime.MinRequiredEVCModeKey','host.vm.Runtime.PowerState')

        $result = foreach ($Cluster in $clusterGroup){
            $Cluster.LinkedView.Host.linkedView.VM.where({$PSItem.Runtime.PowerState -match 'poweredon'}) | 
                Select-Object @{ n = 'ClusterName'; e = {$Cluster.Name} },
                    @{ n = 'ClusterMinRequiredEVCModeKey'; e = {$Cluster.Summary.CurrentEVCModeKey}},
                    Name,
                    @{ n = 'MinRequiredEVCModeKey'; e = {$_.Runtime.MinRequiredEVCModeKey}},
                    @{ n = 'Version'; e = {$_.Config.Version} }
            }

        $tableData = $result.Where({ $PSItem.MinRequiredEVCModeKey -ne $PSItem.ClusterMinRequiredEVCModeKey}) | Sort-Object ClusterMinRequiredEVCModeKey -Descending
        
        $arrProp = 'ClusterName ClusterMinRequiredEVCModeKey Name MinRequiredEVCModeKey Version' -split ' '
        New-UDTable -Title $PageTitle `
            -Headers $arrProp `
            -ArgumentList @($arrProp,$tableData) `
            -Endpoint {

                $arrProp = $ArgumentList[0]
                $tableData = $ArgumentList[1]
                $tableData  |  Out-UDTableData -Property $arrProp
                }
        }
    else {
        New-UDCard -Title $PageTitle -Text "Could not get the data"
        }

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle #-replace '\s'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
