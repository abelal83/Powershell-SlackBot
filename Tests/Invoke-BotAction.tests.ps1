$moduleName = 'SlackBot'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")

@( Get-ChildItem -Path "$moduleRoot\Private\*.ps1" ) | ForEach-Object {
    . $_.FullName
}
Describe 'Invoke-BotAction tests' {

    Mock -CommandName Write-Verbose -MockWith {}

    $jsonFile = '
        { "command" : 
            [
                {
                    "keywords":  [
                                        "default"
                                    ],
                    "response":  "whatcha talking about willis?!"
                },
                {
                    "keywords":  [
                                        "name?",
                                        "name",
                                        "your",
                                        "whats",
                                        "what",
                                        "is"
                                    ],
                    "response":  "My name is TestBot!"
                }
            ] 
        }'

    Context 'When module exists' {

        It "Should return response from action" {
            #Get-Response -Command 'default' | Should Be "whatcha talking about willis?!"
        }
    }

    Context 'When no action exist' {
        
        It "Should return an empty string" {
            
        }
    }

    Context 'When module does not exist' {

        It "Should return the exception thrown as a string" {
            #Get-Response -Command 'name?' | Should Be "My name is TestBot!"
        }
    }
}