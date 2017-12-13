param(
    $JsonEventFile = "C:\Users\abube\OneDrive\Documents\GitHub\Powershell-SlackBot\SlackBot\Private\temp\5d3980b5-ebe1-4c4f-a69e-72685caff489.json"
)

Remove-Module SlackBot -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\SlackBot.psd1"

$JsonEvent = Get-Content $JsonEventFile -Raw | ConvertFrom-Json

$token = $JsonEvent.slacktoken
#Web API call starts the session and gets a websocket URL to use.
$rtmSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token="$token"}

Write-Log "I am $($rtmSession.self.name)" 

Try
{
    Do
    {
        $WS = New-Object System.Net.WebSockets.ClientWebSocket                                                
        $CT = New-Object System.Threading.CancellationToken                                                   

        $Conn = $WS.ConnectAsync($rtmSession.URL, $CT)                                                  
        While (!$Conn.IsCompleted) 
        { 
            Start-Sleep -Milliseconds 100 
        }            

        Write-Log "Connected to $($rtmSession.URL)" 

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

            Write-Log "$RTM" 

            If ($RTM)
            {
                $RTM = ($RTM | convertfrom-json)

                Switch ($RTM)
                {
                    {($_.type -eq 'message') -and (!$_.reply_to)} 
                    {
                        If ( ($_.text -Match "<@$($rtmSession.self.id)>") -or $_.channel.StartsWith('D') )
                        {
                            #A message was sent to the bot
                            Send-SlackMsg -Text "Yo" -Channel $JsonEvent.message.channel
                               
                        } 
                        Else
                        {
                            Write-Log "Message ignored as it wasn't sent to @$($rtmSession.self.name) or in a DM channel" 
                        }
                    }
                    { $_.type -eq 'reconnect_url'} 
                    { 
                        $rtmSession.URL = $RTM.url 
                    }
                    default 
                    { 
                        Write-Log "No action specified for $($RTM.type) event"  
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
