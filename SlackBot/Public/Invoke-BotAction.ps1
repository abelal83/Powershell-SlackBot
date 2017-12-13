param(
    $JsonEventFile = "C:\Users\abube\OneDrive\Documents\GitHub\Powershell-SlackBot\SlackBot\Private\temp\5d3980b5-ebe1-4c4f-a69e-72685caff489.json"
)

Remove-Module SlackBot -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\..\SlackBot.psd1"

$Private = Get-ChildItem -Path "$PSScriptRoot\..\Private\*.ps1"

$Private | ForEach-Object {
    Try {

        write-host "importing $_.FullName "
        . $_.FullName
    } Catch {
        Write-Error -Message "Failed to import function $($_.FullName): $_"
    }
}

$JsonEvent = Get-Content $JsonEventFile -Raw | ConvertFrom-Json

$botResponse = Get-Response -Command $JsonEvent.message.text

#Web API call starts the session and gets a websocket URL to use.
$rtmSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token=$JsonEvent.slacktoken}

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
        
        if (![System.String]::IsNullOrEmpty($botResponse.response))
        {
            Send-SlackMsg -Text $botResponse.response -Channel $JsonEvent.message.channel
        }

        if ($botResponse.auth.Count -ge 1)
        {
            #auth required before action can be run
            # send message to the auth user and wait for response 
            $imList = Invoke-RestMethod -Uri https://slack.com/api/im.list -Body @{token=$JsonEvent.slacktoken}

            $userList = Invoke-RestMethod -Uri https://slack.com/api/users.list -Body @{token=$JsonEvent.slacktoken}

            $authUser = $userList.members.Where({ $_.name -eq $botResponse.auth[0]})
        }
        else 
        { 
            break 
        }

        
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
                            Write-Host Messagerex

                               
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
