#this script will try to load any .dll assemblies in the Assemblies sub-folder in the dashboard root

$assemblyLoadErrors = @()

$cache:DashboardRootPath | Join-Path -ChildPath 'Assemblies' | Get-ChildItem -Filter '*.dll' -Recurse | % {
    
    $thisFilePath = $_.fullname
    try {
        [System.Reflection.Assembly]::LoadFile($_.fullname)
        }
    catch {
        $assemblyLoadErrors += [pscustomobject]@{
            File = $thisFilePath
            Error = $Error[0]
            }
        }
    }

#can be used to debug
$cache:assemblyLoadErrors = $assemblyLoadErrors
