﻿#Invokes an instance of a bot
Function Invoke-SlackBot 
{
    [cmdletbinding()]
    Param(
        [string]$Token = (Import-Clixml "$PSScriptRoot\..\Token.xml"),  #So I don't accidentally put it on the internet
        [string]$LogPath = "$Env:USERPROFILE\Logs\SlackBot.log",
        [string]$PSSlackConfigPath = "$PSScriptRoot\..\PSSlackConfig.xml"
    )
    
    #Set-PSSlackConfig -Path $PSSlackConfigPath -Token $Token
    
    #Web API call starts the session and gets a websocket URL to use.
    $RTMSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token="$Token"}
    Write-Log "I am $($RTMSession.self.name)" -Path $LogPath

    Try
    {
        Do
        {
            $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
            $CT = New-Object System.Threading.CancellationToken                                                   

            $Conn = $WS.ConnectAsync($RTMSession.URL, $CT)                                                  
            While (!$Conn.IsCompleted) 
            { 
                Start-Sleep -Milliseconds 100 
            }            

            Write-Log "Connected to $($RTMSession.URL)" -Path $LogPath

            $Size = 1024
            $Array = [byte[]] @(,0) * $Size
            $Recv = New-Object System.ArraySegment[byte] -ArgumentList @(,$Array)

            While ($WS.State -eq 'Open') 
            {
                $RTM = ""

                Do 
                {
                    $Conn = $WS.ReceiveAsync($Recv, $CT)
                    While (!$Conn.IsCompleted) 
                    { 
                        Start-Sleep -Milliseconds 100 
                    }

                    $Recv.Array[0..($Conn.Result.Count - 1)] | ForEach-Object { $RTM = $RTM + [char]$_ }

                } 
                Until ($Conn.Result.Count -lt $Size)

                Write-Log "$RTM" -Path $LogPath

                If ($RTM)
                {
                    $RTM = ($RTM | convertfrom-json)

                    Switch ($RTM)
                    {
                        {($_.type -eq 'message') -and (!$_.reply_to)} 
                        {
                            If ( ($_.text -Match "<@$($RTMSession.self.id)>") -or $_.channel.StartsWith('D') ){
                                #A message was sent to the bot

                                $response = Get-Response -Command $_.text.ToLower()
                                Send-SlackMsg -Text $response -Channel $RTM.Channel 

                                # { $words -match @("help |", "commands |") } { Send-SlackMsg `
                                #      -Text ("Right now I'm " + (0x0A -as [char]) + "not very useful!") `
                                #       -Channel $RTM.Channel }      
                            } 
                            Else
                            {
                                Write-Log "Message ignored as it wasn't sent to @$($RTMSession.self.name) or in a DM channel" -Path $LogPath
                            }
                        }
                        { $_.type -eq 'reconnect_url'} { $RTMSession.URL = $RTM.url }

                        default 
                        { 
                            Write-Log "No action specified for $($RTM.type) event" -Path $LogPath 
                        }            
                    }
                }
            }   
        } 
        Until (!$Conn)
    }
    Finally
    {
        If ($WS) 
        { 
            Write-Verbose "Closing websocket"
            $WS.Dispose()
        }
    }
}