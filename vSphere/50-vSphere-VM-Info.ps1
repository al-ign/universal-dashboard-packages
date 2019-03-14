$PageTitle = 'vSphere VM Info'
$PageParameter = 'PageParameter'

#Create UDPage Endpoint
$scriptBlock = {
    param ($PageParameter)
    #Your content here
    
    New-UDInput -Title "Search" -SubmitText 'Find' -Endpoint {
        param( $PageParameter )
        New-UDInputAction -RedirectUrl ('/{0}/{1}' -f $PageTitle, $PageParameter)
        }

    function AsString {
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$true,
                       ValueFromPipeline=$true,
                       Position=0)]
            [string]$String
            )
        Begin {
            [string]$EndString = ''
            }
        Process {
            $Endstring += $String
            }
        End {
            $EndString -join ''
            }
        }
    
    function Get-ViName {
        [CmdletBinding()]
        [OutputType([string])]
        Param (        
            [Parameter(Mandatory=$true,
                       ValueFromPipeline=$true,
                       Position=0)]
            $Object
            )
        Process {
            (get-view -Id $Object -Property Name).Name
            }
        }

    function Get-VMFolderPath {
    [CmdletBinding(DefaultParameterSetName='VMName')]
        param (
            [Parameter(ParameterSetName='VMName',
                Position=0
                )]
            [string]$Name,
            [Parameter(ParameterSetName='VMware.Vim.VirtualMachine',
                Position=0
                )]
            [VMware.Vim.VirtualMachine[]]$view,
            [string]$Delimiter = ', '
            )

        filter Get-FolderParents {
            $vm = $_
            $parent = get-view -id $vm.parent -Property Name, Parent 
            $list = $(
                $parent | select Name, Parent
                while ($parent -is [VMware.Vim.Folder]) {
        
                    $parent = get-view -id  $parent.Parent -Property Name, Parent
                    if ($parent.Name -eq 'vm') {
                        break
                        }
                    $parent | select Name, Parent

                    }
                )
            $list
            }

        if ($PSBoundParameters.'Name') {
            $view = Get-View -ViewType VirtualMachine -Filter @{Name = $PSBoundParameters.'Name'}
            }

        foreach ($VM in $view) {
            $folderlist = $VM | Get-FolderParents 

            [pscustomobject][ordered]@{
                Name = $vm.Name
                MoRef = $vm.MoRef
                Parent = $vm.Parent
                FolderList = $folderlist
                Path = ($folderlist).Name -join $Delimiter
                PathReverse = ($folderlist[$folderlist.GetUpperBound(0)..0]).Name -join $Delimiter
                }
            }

        }

    $iconFolder = '<i class="fa fa-folder  " id="9f397aec-e17b-41d9-8ecb-7763dac0e03c"></i>'

    if ($Cache:ViServer.Name) {
        Connect-VIServer -Server $Cache:ViServer.Name -Session $Cache:ViServer.SessionSecret
        }
    else {
        Connect-VIServer -Server $UDEPVarViServerList
        }
   
    if ($PageParameter -match 'VirtualMachine-vm-\d+') {
        $view = Get-View -Id $PageParameter #-ErrorAction SilentlyContinue
        }
    else {
        $view = Get-View -ViewType VirtualMachine -Filter @{Name=$PageParameter} #-ErrorAction SilentlyContinue
        }

    if ($view) {
            foreach ($vm in $view) {
                #precompute
             
                $basicVMInfo =  [pscustomobject][ordered]@{
                    CPU = '{0} vCPU ({1}S * {2}C)' -f $vm.Config.Hardware.NumCPU, ($vm.Config.Hardware.NumCPU / $vm.Config.Hardware.NumCoresPerSocket), $vm.Config.Hardware.NumCoresPerSocket
                    Folder = '{0}&nbsp;{1}' -f $iconFolder,( Get-VMFolderPath -view $vm ).Path
                    Power =  $vm.Runtime.PowerState
                    Host = '{0}' -f (get-view $vm.Runtime.Host -Property Name).Name
                    RAM = '{0} Mb' -f $vm.Config.Hardware.MemoryMB
                    PoolName = $vm.ResourcePool | Get-ViName
                    PoolMoRef = $vm.ResourcePool
                    GuestId = $vm.Guest.GuestId
                    }

                #hdd
                $VMDKRaw = $vm.Config.Hardware.Device | ? { $_ -is [VMware.Vim.VirtualDisk] } 

                $VMDK = foreach ($thisVMDK in $VMDKRaw) {
                    if ($thisVMDK.Backing.FileName -match '\/') {
                        $tmp = $thisVMDK.Backing.FileName.Split('/')
                        $thisVMDKFileName = $tmp[$tmp.getUpperBound(0)]
                        }
                    else {
                        $thisVMDKFileName = $thisVMDK.Backing.FileName -replace '\[.+\]\s*'
                        }
                    [pscustomobject][ordered]@{
                        Size = [math]::Round( ( $thisVMDK.CapacityInBytes / 1GB ) ) 
                        Ctrl = $thisVMDK.ControllerKey
                        Unit = $thisVMDK.UnitNumber
                        File = $thisVMDKFileName
                        Store = (get-view $thisVMDK.Backing.Datastore -Property Name).Name
                        Thin = [string]($thisVMDK.Backing.ThinProvisioned)
                        }

                    }

                $VMDKTotal = foreach ($u in $VMDK | Select-Object -Property Store -Unique) {
                    [pscustomobject][ordered]@{
                        Store = $u.Store
                        Total = ($VMDK | ? Store -eq $u.store | Measure-Object -Property Size -Sum).Sum
                        }
                    }
                $VMDKRaw = $null

                #net 
                $NetDevices = @($vm.Config.Hardware.Device | ? {$_ -is [VMware.Vim.VirtualEthernetCard]} )
                $NetDevices = foreach ($thisNetDevice in $NetDevices) {
                    if ($thisNetDevice.Backing.Port -is [VMware.Vim.DistributedVirtualSwitchPortConnection]) {
                        $thisNetDeviceNetwork = [string]((get-view -id ('DistributedVirtualPortgroup-' + $thisNetDevice.Backing.Port.PortgroupKey) -Property Name).Name)
                        }
                    if ($thisNetDevice.Backing -is [VMware.Vim.VirtualEthernetCardNetworkBackingInfo]) {
                        $thisNetDeviceNetwork = $thisNetDevice.Backing.DeviceName
                        }
                    [PSCustomObject]@{
                        MAC = $thisNetDevice.MACAddress.ToUpper() 
                        Network = $thisNetDeviceNetwork
                        Label = $thisNetDevice.DeviceInfo.Label
                        Connected = ($thisNetDevice.Connectable.Connected)
                        }
                    }
                #guest
                if ($vm.Guest.ToolsRunningStatus -eq 'guestToolsRunning') {
                    #disks
                    $GuestDisks = foreach ($disk in $vm.Guest.Disk) {
                        [pscustomobject][ordered]@{
                            Path = $disk.DiskPath
                            Size = $disk.Capacity / 1GB | Round-Value
                            Free = $disk.FreeSpace / 1GB | Round-Value
                            '%' = $disk.FreeSpace / $disk.Capacity * 100 | Round-Value
                            }
                        }#end guestdisks

                    #guest network
                    $guestnet = foreach ($guestnet in $vm.Guest.net) {
                        foreach ($Ip in $guestnet.IpConfig.IpAddress) {
                            [pscustomobject]@{
                                Network = $guestnet.network
                                MAC = $guestnet.MacAddress
                                Ip = $Ip.IpAddress
                                Mask = $Ip.PrefixLength
                                Origin = $ip.Origin
                                Connected = $guestnet.Connected
                                }
                            }
                        }#End guestnet

                    }#end guest


    #scriptblocks for UDCards
    $VMGuestInfo =  {
        New-UDHtml (
            $vm.Guest | select Hostname, IpAddress, GuestFullName | ConvertTo-Html -as List -Fragment | AsString
            )
        }
    $VMGuestDisk = {
        $arrProp = 'Path', 'Size', 'Free', '%'
        if ($GuestDisks) {
            New-UDTable -Title 'Guest Disks' -Headers $arrProp -ArgumentList @($GuestDisks, $arrProp) -Endpoint {
                $ArgumentList[0] |Out-UDTableData -Property $ArgumentList[1]
                }
            }
        else {
            New-UDHtml ('Guest disk info is unavailable')
            }
        }
    $VMVMDKList = {
        $arrProp = 'Size', 'File', 'Store', 'Thin' #, 'Ctrl', 'Unit'
        New-UDTable -Title 'Disks' -Headers $arrProp -ArgumentList @($VMDK, $arrProp) -Endpoint {
                $ArgumentList[0] |Out-UDTableData -Property $ArgumentList[1]
                }
        }
    $VMDataStoreTotalUsage = {
        $arrProp = 'Store', 'Total'
        New-UDTable -Title 'Disks Total' -Headers $arrProp -ArgumentList @($VMDKTotal, $arrProp)  -Endpoint {
            $ArgumentList[0] |Out-UDTableData -Property $ArgumentList[1]
            }
        }
    $VMNetInterface = {
        $arrProp =  'Connected', 'Label', 'MAC', 'Network'
        New-UDTable -Title 'Network Adapters' -Headers $arrProp -ArgumentList @($NetDevices, $arrProp) -Endpoint {
            $ArgumentList[0] | % {
                if ($_.Connected -eq $true) {
                    $_.Connected = '● Yes'
                    }
                else {
                    $_.Connected = '◌ No'
                    }
                $_
                } | Out-UDTableData -Property $ArgumentList[1]
            }
        }
    $VMBasicInfo = {
    New-UDLayout -Columns 2 -Content {
        New-UDParagraph -Content {
            New-UDHtml ('Folder {0}' -f $basicVMInfo.Folder)
            New-UDHtml ('CPU {0}' -f $basicVMInfo.CPU)
            New-UDHtml ('RAM {0}' -f  $basicVMInfo.RAM)
            if ([bool]$basicVMInfo.Power) {
                New-UDHtml ('Power: <font color="darkgreen">{0}</font>' -f $basicVMInfo.Power )
                }
            else {
                New-UDHtml ('Power: {0}' -f $basicVMInfo.Power)
                }
            #New-UDHtml ('Pool: ')
            
            
            }# End UDParagraph 
        New-UDParagraph -Content {
            New-UDLink -Text ('Pool: {0}' -f $basicVMInfo.PoolName) -Url ('/vSphere Resource Pool Info/' + $basicVMInfo.PoolMoRef.ToString())
            New-UDHtml ('Host {0}' -f $basicVMInfo.Host)
            New-UDHtml ('Type {0}' -f $basicVMInfo.GuestId)
            }
        }
    }# End VMBasicInfo

            New-UDCard -Title $vm.Name `
                -Content {
                    New-UDCard -Content $VMBasicInfo
                    if ($vm.Guest.ToolsRunningStatus -eq 'guestToolsRunning') {
                        New-UDCard -Content $VMGuestInfo
                        & $VMGuestDisk
                        }                    
                    & $VMDataStoreTotalUsage 
                    & $VMVMDKList
                    & $VMNetInterface 
                    } -Links @( 
                        New-UDLink -Text 'View' -Url ('/vSphere VM Info/' + $vm.MoRef.ToString()) -FontColor Black 
                        New-UDLink -Text 'Diag' -Url ('/vSphere VM Diag/' + $vm.MoRef.ToString()) -FontColor Black -Icon diamond
                        )
                    # End VM Card
                
                } #End % vm
        } #End if $view
    else {
        New-UDCard -Title 'Nope' -Content {
            New-UDParagraph -Text ('Nothing found')
            }
        }
    New-UDParagraph -Text ('This page was generated at ' + (Get-date) )
    }#End Page

#Create a proper URL depending on PageParameter
if ($PageParameter.Length -gt 0) {
    $PageUrl = '/{0}/:{1}' -f $PageTitle, $PageParameter #-replace '\s','-'
    }
else {
    $PageUrl = '/{0}' -f $PageTitle #-replace '\s','-'
    }

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
