$EndPointName = 'vSphere-VM-List'


#Create Endpoint scriptblock
$scriptBlock = {
    #Endpoint Code
        
    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }
    $view = Get-View -ViewType VirtualMachine -Property Name, Runtime, Guest | Select-Object Name, Runtime, Guest, MoRef
    if ($view) {
        $Cache:VMList = foreach ($vm in $view) {
            [pscustomobject][ordered]@{
                Name = $vm.Name
                PowerState = $vm.Runtime.PowerState
                IpAddress = $vm.Guest.IpAddress
                MoRef = $vm.MoRef.ToString()
                }
            }
        $Cache:VMCount = ($Cache:VMList).Count
        $Cache:VMListTimeStamp = Get-Date
        }#End view
    }#End UDEndPoint


#Create EndPoint variable
New-Variable -Name ("UDEndPoint" + $EndPointName -replace '\s') -Value (
    New-UDEndpoint -Id $EndPointName -Schedule $udSchedule5min -Endpoint $scriptBlock
    )
