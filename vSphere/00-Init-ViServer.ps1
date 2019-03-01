#load ViServerList list, if available
$Config_ViServerList = (Join-Path  (Join-Path $cache:DashboardRootPath 'Config') 'config_ViServerList.json' )
if (Test-Path $Config_ViServerList -ea 0) {
    try {
        $UDEPVarViServerList = @( Get-Content $Config_ViServerList | ConvertFrom-Json )
        }
    catch {
        $UDEPVarViServerList = @()
        }
    }

$UDEPVarViModulesList = @(
    'VMware.VimAutomation.Common', 
    'VMware.VimAutomation.Core', 
    'VMware.VimAutomation.Vds',
    'vmware-supplements'
    )

$global:DefaultVIServer = $null
$global:DefaultVIServers = $null

$UDEndPointViServer = New-UDEndpoint -Id 'ViServer' -Schedule (New-UDEndpointSchedule -Every 5 -Minute)  -Endpoint {
    if (!($Cache:vCenterServer)) {
        $Cache:ViServer = $UDEPVarViServerList
        }

    if (!($global:DefaultVIServer.Name -eq $Cache:ViServer)) {
        try {
            #Write-UDLog -Level Warning -Message 'init viserver endpoint' 
            #Write-UDLog -Level Warning -Message ('vcentername = ' + $Cache:vCenterServer)
            #Import-Module $UDEPVarViModulesList
            Connect-VIServer -Server $Cache:ViServer -Force -ErrorAction Stop
            Get-view -ViewType Datacenter -Property Name
            }
        catch {
            $err = $_.Exception.Message
            }
        }
    $Cache:ViServer = $global:DefaultVIServer
}
#>
