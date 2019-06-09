#this script will try to load any .dll assemblies in the Assemblies sub-folder in the dashboard root

$assemblyLoadResults = @()

$cache:DashboardRootPath | Join-Path -ChildPath 'Assemblies' | Get-ChildItem -Filter '*.dll' -Recurse | % {
    
    $obj = [pscustomobject]@{
            File = $_.fullname
            Loaded = $false
            Error = $null
            }
    
    try {
        [System.Reflection.Assembly]::LoadFile($obj.File)
        $obj.Loaded = $true
        }
    catch {
        $obj.Error = $Error[0].Exception.Message
        }

    $assemblyLoadResults += $obj
    }

#can be used to debug
$cache:assemblyLoadResults = $assemblyLoadResults
