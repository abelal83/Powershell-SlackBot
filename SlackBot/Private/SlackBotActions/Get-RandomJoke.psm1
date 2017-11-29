$ErrorActionPreference = "Stop"
Set-PSDebug -Strict

function Get-RandomJoke
{
    [CmdletBinding()]
    param( )

    $joke = Invoke-RestMethod -Uri 'http://api.icndb.com/jokes/random/'

    return $joke.value.joke
}