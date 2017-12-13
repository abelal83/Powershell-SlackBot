Remove-Module SlackBot -ErrorAction SilentlyContinue
Import-Module "$PSScriptRoot\SlackBot.psd1"
Invoke-SlackBot -SlackBotConfigFile "$PSScriptRoot\SlackBot.json"