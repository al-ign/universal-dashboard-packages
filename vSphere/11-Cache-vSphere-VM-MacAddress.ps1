$EndPointName = 'vSphere-VM-MacAddress'

#Create Endpoint scriptblock
$scriptBlock = {
    #Endpoint Code
        
        if ($Cache:ViServer.Name) {
            Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
            }
        else {
            Connect-VIServer -Server $UDEPVarViServerList
            }
        $view = Get-View -ViewType VirtualMachine -Property Name, Config | Select-Object Name, Config, MoRef
        if ($view) {
            $Cache:VMMacAddress = foreach ($vm in $view) {
                foreach ($VEC in ($vm.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualEthernetCard]}) ) {
                    [pscustomobject][ordered]@{
                        Name = $vm.Name
                        MacAddress = $vec.MacAddress
                        Connected = $vec.connectable.connected
                        MoRef = $vm.MoRef.ToString()
                        }
                    }
                }
            }#End view
        }#End UDEndPoint

#Create EndPoint variable
New-Variable -Name ("UDEndPoint" + $EndPointName -replace '\s') -Value (
    New-UDEndpoint -Id $EndPointName -Schedule $udSchedule30min -Endpoint $scriptBlock
    )
