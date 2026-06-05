[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $Workspace,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string] $Path,

    [Parameter(Mandatory=$true, Position=2)]
    [securestring] $Token,

    [Parameter(Mandatory=$true, Position=3)]
    [securestring] $Cookies
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name "curl.exe")) {
    throw "curl.exe not found."
}

$emoji = Get-ChildItem -Path $Path

if ($emoji.Count -eq 0) {
    Write-Host "No files found to upload".
    return
}

$results = @()

$cookieStr = ([pscredential]::new("_", $Cookies)).GetNetworkCredential().Password
$tokenStr = ([pscredential]::new("_", $Token)).GetNetworkCredential().Password

foreach ($e in $emoji) {
    $emojiName = $e.Name.Substring(0, $e.Name.LastIndexOf("."))

    Write-Host -NoNewLine "$($emojiName): "

    $attempts = 0

    do {
        $result = curl.exe "https://$Workspace.slack.com/api/emoji.add" `
            --compressed `
            -X POST `
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:151.0) Gecko/20100101 Firefox/151.0" `
            -H "Accept: */*" `
            -H "Accept-Language: en-GB,en;q=0.9" `
            -H "Origin: https://$Workspace.slack.com" `
            -H "Alt-Used: $Workspace.slack.com" `
            -H "Connection: keep-alive" `
            -H "Sec-Fetch-Dest: empty" `
            -H "Sec-Fetch-Mode: cors" `
            -H "Sec-Fetch-Site: same-origin" `
            -H "Cookie: $cookieStr" `
            -H "Priority: u=0" `
            -H "TE: trailers" `
            -F token=$tokenStr `
            -F name=$emojiName `
            -F mode=data `
            -F "search_args={}" `
            -F image=@$($e.FullName) `
            -F _x_reason=add-custom-emoji-dialog-content `
            -F _x_mode=online `
            -s

        Write-Host -NoNewline "$result "

        $result = $result | ConvertFrom-Json

        if ($result.error -eq "ratelimited" -and $attempts -lt 3) {
            Start-Sleep -Seconds 5
            $attempts++
        } else {
            $result | Add-Member -NotePropertyName name -NotePropertyValue $emojiName
            $results += $result

            Write-Host ""

            Start-Sleep -Seconds 2
        }
    } while ($result.error -eq "ratelimited" -and $attempts -lt 3)
}

return $results