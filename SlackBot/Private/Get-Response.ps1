Function Get-Response 
{
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    $responses = Get-Content -Path "$PSScriptRoot\Responses.json" -Raw | ConvertFrom-Json    

    Write-Verbose ($responses | Out-String)

    $words = $Command -split ' '

    $possibleResponses = New-Object System.Data.DataTable
    $possibleResponses.Columns.Add((New-Object System.Data.DataColumn('response', [string])))
    $possibleResponses.Columns.Add((New-Object System.Data.DataColumn('responsecount', [int])))

    foreach ($word in $words) 
    {
        # search responses.json under keywords for each word until something common found
        $itemWithWord = $responses.Where( { $_.keywords.Contains($word) } )
        
        if ($itemWithWord.Count -eq 0)
        {
            $responseMessage = $responses.Where( { $_.keywords.Contains('default') } ).response
            Write-Verbose -Message "No keywords found, replying with default response $responseMessage"
            return $responseMessage
        }

        $itemWithWord.ForEach(
            {
                # check if response exists, if so increment responsecount
                $responseRows = $possibleResponses.Select("response = '" + $_.response + "'")

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

    $responseMessage = $possibleResponses.Select("responsecount = MAX(responsecount)").response
    return $possibleResponses.Select("responsecount = MAX(responsecount)").response
}