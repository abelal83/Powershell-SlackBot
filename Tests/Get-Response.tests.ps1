$moduleName = 'SlackBot'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")

Describe 'Get-Response tests' {

    Mock -CommandName Write-Verbose -MockWith {}

    Mock -CommandName Get-Content -MockWith { return '
        { "command" : 
            [
                {
                    "keywords":  [
                                        "default"
                                    ],
                    "response":  "whatcha talking about?!"
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
                    "response":  "My name is OmniBot!"
                }
            ] 
        }' 
    }

    @( Get-ChildItem -Path "$moduleRoot\Private\*.ps1" ) | ForEach-Object {
        . $_.FullName
    }

    Context 'Defaut response checks' {

        It "Should return default response" {
            Get-Response -Command 'default' | Should Be "whatcha talking about?!"
        }

        It "Should return default response when something unusual asked" {
            Get-Response -Command 'abcdefghi jklmnopq' | Should Be "whatcha talking about?!"
        }
    }

    Context 'When asked for name' {

        It "Should return default its name" {
            Get-Response -Command 'name?' | Should Be "My name is OmniBot!"
        }
    }
}