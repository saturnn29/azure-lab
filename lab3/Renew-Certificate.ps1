param(
    [Parameter(Mandatory=$true)]
    [string]$DomainName,

    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,

    [Parameter(Mandatory=$true)]
    [string]$CertName
)

try {
    # 1. Authenticate using Managed Identity
    Write-Output "Authenticating using Managed Identity..."
    Disable-AzContextAutosave -Scope Process
    Connect-AzAccount -Identity

    # 2. Generate a Self-Signed Certificate
    Write-Output "Generating Self-Signed Certificate for $DomainName..."
    $certPassword = ConvertTo-SecureString -String "LocalLabPassword123!" -AsPlainText -Force
    
    # Create the certificate in memory (valid for 1 year)
    $cert = New-SelfSignedCertificate `
        -DnsName $DomainName `
        -CertStoreLocation "cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(1) `
        -KeyExportPolicy Exportable

    # 3. Export to PFX format temporarily
    $pfxPath = "$env:TEMP\selfsigned.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $certPassword

    # 4. Upload to Azure Key Vault
    Write-Output "Uploading certificate to Key Vault: $KeyVaultName"
    Import-AzKeyVaultCertificate `
        -VaultName $KeyVaultName `
        -Name $CertName `
        -FilePath $pfxPath `
        -Password $certPassword

    # Cleanup local temp files
    Remove-Item -Path $pfxPath -Force
    
    Write-Output "SUCCESS: Self-Signed Certificate uploaded to Key Vault."
    Write-Output "Thumbprint: $($cert.Thumbprint)"
} catch {
    Write-Error "Error during certificate generation: $_"
    throw
}
