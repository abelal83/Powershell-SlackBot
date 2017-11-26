$moduleName = 'SlackBot'
$projectRoot = Resolve-Path "$PSScriptRoot\.."
$moduleRoot = Split-Path (Resolve-Path "$projectRoot\$moduleName\$moduleName.psm1")

@( Get-ChildItem -Path "$moduleRoot\Private\*.ps1" ) | ForEach-Object {
    . $_.FullName
}
Describe 'Get-Response tests' {

    Mock -CommandName Write-Verbose -MockWith {}

    Mock -CommandName Get-Content -ParameterFilter {$raw.IsPresent} -MockWith { return '
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
    }

    Context 'Default response checks' {

        It "Should return default response" {
            Get-Response -Command 'default' | Should Be "whatcha talking about willis?!"
        }

        It "Should return default response when something unusual asked" {
            Get-Response -Command 'abcdefghi jklmnopq' | Should Be "whatcha talking about willis?!"
        }
    }

    Context 'When asked for name' {

        It "Should return its name" {
            Get-Response -Command 'name?' | Should Be "My name is TestBot!"
        }
    }
}

Describe "Format-EscapeValue tests" {

    Mock -CommandName Write-Verbose -MockWith {}

    Context "When values have special characters" {

            $specialChars = @("[", "]", "%", "*", "'")

            foreach ($item in $specialChars) {

                It "Should return escaped $item character" {

                    switch ($item) {
                        "'" {  Format-EscapeValue -Value "contains $item" -Verbose | Should Be "contains '$item" }
                        default {  Format-EscapeValue -Value "contains $item" | Should Be "contains [$item]" }
                    }
                }         
            }
    }

    Context "When values have no special characters" {

        It "Should not change the value" {
            Format-EscapeValue -Value "no special characters" | Should Be "no special characters"
        }

    }
}