$ErrorActionPreference = "Stop"

function Invoke-BotAction 
{
    [CmdletBinding()]
    param(
    # Parameter help description
    [Parameter(Mandatory=$true)]
    $JsonRespone
    )
 
    if (![string]::IsNullOrEmpty($JsonRespone.action))
    {
        try 
        {
            $modulePath = ($PSScriptRoot + "\..\Private\SlackBotActions\" + $response.action + ".psm1")                                  
            Import-Module $modulePath
            #run the function
            $actionResponse = Invoke-Expression -Command $JsonRespone.action
    
            return $actionResponse
        }
        catch 
        {
            return $_.ToString()
        }
    }

    return ""
    
}