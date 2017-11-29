$ErrorActionPreference = "Stop"
Set-PSDebug -Strict

function Invoke-BotAction 
{
    [CmdletBinding()]
    param(
    # Parameter help description
        [Parameter(Mandatory=$true)]
        $JsonResponse
    )
 
    if (![string]::IsNullOrEmpty($JsonResponse.action))
    {
        try 
        {
            # the path is actually relative to the parent script (invoke-slackbot.ps1) whre this is scoped to
            
            $modulePath = ($PSScriptRoot + "\SlackBotActions\" + $JsonResponse.action + ".psm1")

            if (!(Test-Path -Path $modulePath))
            {
                $modulePath = ($PSScriptRoot + "\..\Private\SlackBotActions\" + $JsonResponse.action + ".psm1")
            }
                                 
            Import-Module $modulePath
            #run the function
            $actionResponse = Invoke-Expression -Command $JsonResponse.action   
            
            return [string] $actionResponse
        }
        catch 
        {
            return $_.ToString()
        }
    }

    return ""    
}