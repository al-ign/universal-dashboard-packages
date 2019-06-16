$PageTitle = 'Status PowerShell Errors'

#Create UDPage Content
$scriptBlock = {
    #Your content here
    New-UDParagraph -Text ('$Error.count: {0}' -f $ArgumentList.Count )
                
    New-UDGrid -Title "Errors" -DefaultSortDescending -Endpoint {
        $GridData = foreach ($thisArgument in $ArgumentList)  {
            [pscustomobject]@{
                Text = $thisArgument.Exception.Message
                ScriptStackTrace = $thisArgument.ScriptStackTrace
                }
            }
        $GridData | Out-UDGridData 
        } -ArgumentList @($ArgumentList)

    #footer
    New-UDParagraph -Text "This page was generated at $(Get-Date)"
    }
        
#Create UDPage variable
New-Variable -Name ("UDPage" + $PageTitle -replace '\s') -Value (
    New-UDPage -Name $PageTitle -Endpoint $scriptBlock  -ArgumentList @($Error)
    )
