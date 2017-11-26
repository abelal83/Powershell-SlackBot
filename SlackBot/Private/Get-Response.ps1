$ErrorActionPreference = "Stop"
Function Get-Response 
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    $responses = Get-Content -Path "$PSScriptRoot\Responses.json" -Raw | ConvertFrom-Json    

    Write-Verbose ($responses.command | Out-String)

    $words = $Command -split ' '

    $possibleResponses = New-Object System.Data.DataTable
    $possibleResponses.Columns.Add((New-Object System.Data.DataColumn('response', [string])))
    $possibleResponses.Columns.Add((New-Object System.Data.DataColumn('responsecount', [int])))

    foreach ($word in $words) 
    {
        # search responses.json under keywords for each word until something common found
        $itemWithWord = $responses.command.Where( { $_.keywords.ToLower().Contains($word.ToLower()) } )
        
        if ($itemWithWord.Count -eq 0)
        {
            Write-Log -Message "No keywords found for $word"
            continue
        }

        $itemWithWord.ForEach(
            {
                # check if response exists, if so increment responsecount
                $escapedResponse = Set-EscapeLikeValue -Value $_.response
                $responseRows = $possibleResponses.Select("response = '" + $escapedResponse + "'")

                if ($responseRows.Count -eq 0)
                {
                    # add response
                    $row = $possibleResponses.NewRow()
                    $row.response = $_.response
                    $row.responsecount = 1
                    $possibleResponses.Rows.Add($row)
                }
                else 
                {
                    # increment
                    $responseRows.ForEach(
                        {
                            $currentCount = $_.responsecount
                            $currentCount++
                            $_.responsecount = $currentCount

                        }
                    )
                }
            }
        )
    }

    $responseRow = $possibleResponses.Select("responsecount = MAX(responsecount)")

    switch ($responseRow.Count) 
    {
        0 {  return $responses.command.Where( { $_.keywords.Contains('default') } ).response }
        1 { return $responseRow.response }
        default { return $responses.command.Where( { $_.keywords.Contains('default') } ).response }
    }
}

# helper for stupid datatable.select method which can't handle certain characters
function Set-EscapeLikeValue
{
    param(
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string] $Value
    )
    $sb = New-Object System.Text.StringBuilder::($value.Length);
    for ($i = 0; $i -lt $value.Length; $i++)
    {
        [char] $c = $value[$i];
        switch ($c)
        {
            ']' {}
            '[' {}
            '%' {}
            '*' {
                $sb.Append("[").Append($c).Append("]") | Out-Null
                break;
            }
            "'" {
                $sb.Append("''") | Out-Null
                break;
            }
            default {
                $sb.Append($c) | Out-Null
                break;
            }
        }
    }
    return (,$sb.ToString())
}

#function write-log 
#{}
 #Get-Response -Command 'are you still a baby?'
 #Get-Response -Command 'hi'