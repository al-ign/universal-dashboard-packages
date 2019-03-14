$PageTitle = 'vSphere VM Diag'
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

    filter Recurse-Snapshots {
        $snap = $_ 
        $snap
        foreach ($thisSnap in $snap.childSnapshotList) {
            $thisSnap | Recurse-Snapshots
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
        $view = Get-View -Id $PageParameter -ErrorAction SilentlyContinue
        }
    else {
        $view = Get-View -ViewType VirtualMachine -Filter @{Name=$PageParameter} -ErrorAction SilentlyContinue
        }

    if ($view) {
        #cards
        foreach ($vm in $view) {
            $basicVMInfo =  [pscustomobject][ordered]@{
                CPU = '{0} vCPU ({1}S * {2}C)' -f $vm.Config.Hardware.NumCPU, ($vm.Config.Hardware.NumCPU / $vm.Config.Hardware.NumCoresPerSocket), $vm.Config.Hardware.NumCoresPerSocket
                Folder = '{0}&nbsp;{1}' -f $iconFolder,( Get-VMTopFolder -VMView $vm ).Path
                Power =  $vm.Runtime.PowerState
                Host = '{0}' -f (get-view $vm.Runtime.Host -Property Name).Name
                RAM = '{0} Mb' -f $vm.Config.Hardware.MemoryMB
                PoolName = $vm.ResourcePool | Get-ViName
                PoolMoRef = $vm.ResourcePool
                GuestId = $vm.Guest.GuestId
                }
 
            $ResourcePool = Get-View -Id $basicVMInfo.PoolMoRef -Property Name, Runtime, Summary, Parent -ErrorAction SilentlyContinue  
            $ResourcePool = foreach ($thisPool in $ResourcePool) {
        [PSCustomObject][ordered]@{
            Name = $thisPool.Name 
            CpuOverallUsage = $thisPool.Runtime.Cpu.OverallUsage
            CpuMaxUsage = $thisPool.Runtime.Cpu.MaxUsage
            CpuEq = $thisPool.Runtime.Cpu.OverallUsage -eq $thisPool.Runtime.Cpu.MaxUsage
            MemoryOverallUsage = $thisPool.Runtime.Memory.OverallUsage
            MemoryMaxUsage = $thisPool.Runtime.Memory.MaxUsage
            MemoryEq = $thisPool.Runtime.Memory.OverallUsage -eq $thisPool.Runtime.Memory.MaxUsage
            SwappedMemory = $thisPool.Summary.QuickStats.SwappedMemory
            BalloonedMemory = $thisPool.Summary.QuickStats.BalloonedMemory
            ParentName = [string]($thisPool.Parent | Get-ViName)
            ParentMoRef = $thisPool.Parent.ToString()
            MoRef = $thisPool.MoRef
            OverProvisioned =  ($thisPool.Summary.QuickStats.SwappedMemory -ne 0) -or ($thisPool.Summary.QuickStats.BalloonedMemory -ne 0) 
            }
        }

            #hdd
            $VMDKRaw = $vm.Config.Hardware.Device | ? { $_ -is [VMware.Vim.VirtualDisk] } 

            $VMDK = foreach ($thisVMDK in $VMDKRaw) {
                $thisVMDKFileName = $thisVMDK.Backing.FileName -replace '\[.+\]\s*'
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
                            Origin = [string]$ip.Origin
                            Connected = [bool]($NetDevices | ? MAC -eq $guestnet.MacAddress).Connected
                            }
                        }
                    }#End guestnet

                }#end guest

            #Get list of snapshots
            $snapshotList = $vm.Snapshot.RootSnapshotList | Recurse-Snapshots | select Name, Description, CreateTime, Age | % {
                $_.Age = [math]::Round(((get-date) - $_.CreateTime[0]).TotalDays)
                $_
                }


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
        $arrProp = 'Size', 'File', 'Store', 'Thin' , 'Ctrl', 'Unit'
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

    $VMGuestNetAddress = {
        $arrProp = 'Connected Ip MAC Mask Network Origin' -split ' '
        New-UDTable -Title 'IP Addresses' -Headers $arrProp -ArgumentList @($guestnet, $arrProp)  -Endpoint {
            $ArgumentList[0]  | % {
                if ($_.Connected -eq $true) {
                    $_.Connected = '● Yes'
                    }
                else {
                    $_.Connected = '◌ No'
                    }
                $_
                } | Out-UDTableData -Property $ArgumentList[1]
             }
        }# End VMGuestNetAddress
        
    $VMSnapshots = {
        if ($snapshotList) {
            $arrProp = 'Name', 'Description', 'CreateTime', 'Age'
            New-UDTable -Title 'Snapshots' -Headers $arrProp -ArgumentList @($snapshotList, $arrProp)  -Endpoint {
                $ArgumentList[0] | Out-UDTableData -Property $ArgumentList[1]
                }
            }
        else {
            New-UDParagraph -Text 'No snapshots found'
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
            if ($ResourcePool.OverProvisioned) {
                New-UDHtml ('<font color="darkred"><b>Pool is overprovisioned!</b></font>')
                }
            New-UDHtml ('Host {0}' -f $basicVMInfo.Host)
            New-UDHtml ('Type {0}' -f $basicVMInfo.GuestId)
            }
        }
    }# End VMBasicInfo


            New-UDCard -Title $vm.Name `
            -Links @( 
                New-UDLink -Text 'View' -Url ('/vSphere VM Info/' + $vm.MoRef.ToString()) -FontColor Black
                ) `
            -Content {


 New-UDCard -Content $VMBasicInfo
                    if ($vm.Guest.ToolsRunningStatus -eq 'guestToolsRunning') {
                        New-UDCard -Content $VMGuestInfo
                        & $VMGuestDisk
                        }         
                            
                    & $VMSnapshots
                    & $VMDataStoreTotalUsage 
                    & $VMVMDKList
                    & $VMNetInterface 
                    & $VMGuestNetAddress

foreach ($netaddress in ($guestnet | ? Ip -NotMatch '^fe80' | ? Connected)) {
    New-UDCard -Title ([string]($netaddress.ip)) -Content {
        
        #ICMP
        New-UDButton -Text $('ICMP') -OnClick (
            New-UDEndpoint -Id ('ICMP' + [string]$netaddress.ip) -Endpoint {
                $thisNetAddress = $ArgumentList[0]
                Show-UDToast -Message ('ICMP Test: ' + $thisNetAddress.ip) -Duration 3000
                $test = Test-Connection -ComputerName $thisNetAddress.ip -Quiet
                if ($test) {
                    Show-UDToast -Message ('ICMP SUCCESS: ' + $thisNetAddress.ip) -BackgroundColor green -MessageColor White -Duration 5000
                    }
                else {
                    Show-UDToast -Message ('ICMP FAILED: ' + $thisNetAddress.ip)  -BackgroundColor Red -MessageColor White -Duration 5000
                    }
                } -ArgumentList @($netaddress)
            ) #end button onclick
            
    $TcpPort = 22, 3389, 80, 443
    foreach ($thisTcpPort in $TcpPort) {
            New-UDButton -Text $('TCP:' + $thisTcpPort) -OnClick (
                New-UDEndpoint -Endpoint {
                    $thisNetAddress = $ArgumentList[0]
                    $thisTcpPort = $ArgumentList[1]
                    Show-UDToast -Message ('Testing tcp/' + $thisNetAddress.IP + ':' + $thisTcpPort) -Duration 3000
                    $test = Test-NetConnection -Port $thisTcpPort -ComputerName $thisNetAddress.Ip
                    if ($test.TcpTestSucceeded) {
                        Show-UDToast -Message ('SUCCESS: ' + $test.RemoteAddress + ':' + $test.RemotePort) -BackgroundColor green -MessageColor White -Duration 5000
                        }
                    else {
                        Show-UDToast -Message ('FAILED: ' + $test.RemoteAddress + ':' + $test.RemotePort) -BackgroundColor Red -MessageColor White -Duration 5000
                        }
                    } -ArgumentList @($netaddress,$thisTcpPort)
                ) #end button onclick
            }#End foreach ($thisTcpPort in $TcpPort) 

        }#End NewCard
    } #End % $netaddress



                   

 
                Foreach ($thisNetDevice in $NetDevices) {
                    $MACMatch = @( $Cache:MacToIp.where({$_.ipNetToMediaPhysAddress -match ($thisNetDevice.MAC -replace '[:|-|\.]')}) )
                    foreach ($thisMacMatch in $MACMatch) {
                        New-UDParagraph -Text ("MAC " + $thisMacMatch.ipNetToMediaPhysAddress + ' match IP ' + $thisMacMatch.ipNetToMediaNetAddress + ' from ' + $thisMacMatch.Source)
                        }
                    }

                }#end VM Card
            #>
            }
        #end VMCard
        }
    else {
        New-UDCard -Title 'Nope' -Content {
            New-UDParagraph -Text ('Nothing found')
            }
        }

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
