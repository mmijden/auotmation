$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/")
$listener.Start()
Write-Host "Listening for requests..."

while ($true) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Handle the request
    $dccred = Import-Clixml -Path "C:\Users\admin\Documents\dc_credentials.xml"
    $dccred = New-Object System.Management.Automation.PSCredential ($dccred.UserName, $dccred.Password)
    Invoke-Command -ComputerName 10.3.0.2 -Credential $dccred -ScriptBlock {
        $bestaandeGebruikers = @()
        $Response = Invoke-RestMethod http://10.3.0.40:8085/Staff
        Write-Host $Response 
        foreach ($user in $Response.data) {
            $voornaam = $user.Voornaam
            $achternaam = $user.Achternaam
            $personeelsnummer = $user.Personeelsnummer
            $afdeling = $user.Afdeling
            $email = $user.Email
            
            $samAccountName = "$voornaam $achternaam"
            $wachtwoord = [System.Web.Security.Membership]::GeneratePassword(8,2)
            $controlegebruiker = Get-ADUser -Filter {SamAccountName -eq $samAccountName}
            if ($controlegebruiker -eq $null) {
                New-ADUser -Name $voornaam -GivenName $voornaam -Surname $achternaam -SamAccountName $samAccountName -Department $afdeling -UserPrincipalName "$samAccountName@mijden.lan" -Path "OU=$afdeling,DC=mijden,DC=lan" -AccountPassword (ConvertTo-SecureString $wachtwoord -AsPlainText -Force) -Enabled $true -ChangePasswordAtLogon $true
                $emailontvanger = $email
                $emailafzender = "mike.fhict@gmail.com"
                $onderwerp = "Uw nieuwe account"
                $body = @"
Beste $voornaam,
Uw account is aangemaakt.
Uw gebruikersnaam is: $samAccountName 
Uw wachtwoord is: $wachtwoord
Met vriendelijke groet,
IT-afdeling vd M
"@
                $smtpServer = "smtp.gmail.com"
                $port= 587
                $userName = 'mike.fhict@gmail.com'
                $password = "lyzd gjuh otjy szdg"
                [SecureString]$securepassword = $password | ConvertTo-SecureString -AsPlainText -Force
                $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securepassword
                Send-MailMessage -To $emailontvanger -From $emailafzender -Subject $onderwerp -Body $body -SmtpServer $smtpServer -Port $port -UseSsl -Credential $credential
                Write-Host "Gebruiker $samAccountName aangemaakt met wachtwoord: $wachtwoord er is een email verstuurd naar het opgegeven mail adress"
            } else {
                if (-not $bestaandeGebruikers.Contains($samAccountName)) {
                    Write-Host "Gebruiker $samAccountName bestaat al."
                    $bestaandeGebruikers += $samAccountName  
                }
            }
        }
    }

    # Respond to the request
    $response.StatusCode = 200
    $response.Close()
}
