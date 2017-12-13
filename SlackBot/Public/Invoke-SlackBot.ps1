Function Invoke-SlackBot 
{
    [cmdletbinding()]
    Param(
        [string]$SlackBotConfigFile,
        [string]$LogPath = "$Env:USERPROFILE\Logs\SlackBot.log"
    )
    
    $SlackBotConfig = (Get-Content $SlackBotConfigFile -Raw | ConvertFrom-Json)

    $token = $SlackBotConfig.slackapi
    
    #Web API call starts the session and gets a websocket URL to use.
    $rtmSession = Invoke-RestMethod -Uri https://slack.com/api/rtm.start -Body @{token="$token"}
    # $users.members contains all users
    $users = Invoke-RestMethod -Uri 'https://slack.com/api/users.list' -Body @{token="$token"}

    Write-Log "I am $($rtmSession.self.name)" -Path $LogPath

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

            Write-Log "Connected to $($rtmSession.URL)" -Path $LogPath

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
                            If ( ($_.text -Match "<@$($rtmSession.self.id)>") -or $_.channel.StartsWith('D') )
                            {
                                #A message was sent to the bot
                                # export message and all related info to be picked up by a new powershell process
                                # which will handle this message, this is to ensure long running botactions don't 
                                # block this process
                                $jsonMessageOutput = New-Object PSCustomObject
                                $jsonMessageOutput | Add-Member -Name message `
                                -Value $_ -MemberType NoteProperty
                                
                                $jsonMessageOutput | Add-Member -Name user `
                                -Value ($users.members.Where( {$_.id -eq $jsonMessageOutput.message.user} ) | Select-Object -First 1) `
                                -MemberType NoteProperty

                                $jsonMessageOutput | Add-Member -Name slacktoken `
                                -Value $token -MemberType NoteProperty
                             
                                $outFileName = [guid]::NewGuid()
                                $outFilePath = "$PSScriptRoot\..\Private\temp\$outFileName.json"

                                $jsonMessageOutput | ConvertTo-Json | Out-File $outFilePath
                                Write-Log "running powershell with -NoLogo -File $PSScriptRoot\Invoke-BotAction.ps1 $outFilePath"

                                Start-Process powershell -ArgumentList `
                                "-NoExit", "-NoLogo", "-File $PSScriptRoot\Invoke-BotAction.ps1 $outFilePath" `
                                -WorkingDirectory "$PSScriptRoot"                                
                            } 
                            Else
                            {
                                Write-Log "Message ignored as it wasn't sent to @$($rtmSession.self.name) or in a DM channel" -Path $LogPath
                            }
                        }
                        { $_.type -eq 'reconnect_url'} 
                        { 
                            $rtmSession.URL = $RTM.url 
                        }
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