$PageTitle = 'Status dotNet Assemblies'

$PageDescription = 'Display errors while loading dotNET assemblies'

#Create UDPage Endpoint
$scriptBlock = {
    #Your content here
    New-UDParagraph -Text (
        '$cache:assemblyLoadErrors count: {0}' -f ($cache:assemblyLoadErrors).Count
        )
    
    $cache:assemblyLoadErrors | % {
        New-UDParagraph -Text (
            '{0}' -f $_.File
            )
        New-UDParagraph -Text (
            '{0}' -f $_.Error.Exception
            )
        }

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    } #End UDPage ScriptBlock


#Create proper URL
$PageUrl = '/{0}' -f $PageTitle -replace '\s'

#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Url $PageUrl -Endpoint $scriptBlock
    )
