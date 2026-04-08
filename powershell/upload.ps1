###############################################################################
# Script para sincronização de XMLs com o Portal Consyst-e
# Documentação da integração: https://portal.consyste.com.br/doc/api
###############################################################################

param (
    [System.IO.DirectoryInfo[]] $WatchDirs, # os diretórios onde os XMLs a custodiar estão salvos
    [System.IO.DirectoryInfo]   $StateDir,  # o diretório onde manter o estado das credenciais e XMLs já enviados
    [bool] $KeepRunning = $true             # se verdadeiro, mantém o script rodando até que seja encerrado manualmente
)

$ErrorActionPreference = "Stop"

if (-not $WatchDirs) { throw "É obrigatório informar pelo menos um diretório a observar, com -WatchDirs" }
if (-not $StateDir) { throw "É obrigatório informar um diretório para salvar o estado da sincronização, com -StateDir" }

# Verifica se os diretórios informados são válidos
Write-Information "Observando diretórios:"
$diretoriosOK = $true
foreach ($dir in $WatchDirs + @($StateDir)) {
    $exists = Test-Path -Path $dir -PathType Container
    if ($exists) {
        Write-Information "- $dir => OK" -InformationAction Continue
    }
    else {
        $msg = "- $dir => Não é um diretório, ou não está acessível"
        Write-Error $msg -Category OpenError
        $diretoriosOK = $false
    }
}

if (-not $diretoriosOK) { exit 1 }

$credFile = Join-Path $StateDir "creds.xml"
if (Test-Path -Path $credFile -PathType Leaf) {
    $cred = Import-CliXml $credFile
}
else {
    $cred = Get-Credential -Username 'Consyste' -Title 'Integração Consyste - Uploads' -Message 'Informe o token de integração com a plataforma Consyste'
    $cred | Export-CliXml $credFile
}

# Função para chamar a API da Consyste
function Invoke-UploadXML
{
    param (
        [string] $Conteudo,
        [string] $Chave,
        [System.Management.Automation.PSCredential] $Cred
    )

    $headers = @{
        'X-Consyste-Auth-Token' = $Cred.GetNetworkCredential().Password
        'Content-Type' = 'application/json'
    }
    $body = @{
        'xml' = $Conteudo.Trim()
        'log' = 'Enviado por upload.ps1'
    }

    $response = Invoke-RestMethod -Uri 'https://portal.consyste.com.br/api/v1/envio/rapido' -Method Post -Headers $headers -Body ($body | ConvertTo-Json) -SkipHttpErrorCheck
    if ($response.error) {
        Write-Warning "- Falha ao fazer upload: $( $response.error )"
        return $false
    }

    return $true
}

# Regex para extrair a chave do conteúdo do XML
$chaveRegex = [regex]'\bId="[A-Za-z]+([^"]+)"'

# Hash para armazenar as chaves já processadas, organizadas por ano e mês
$cacheChaves = @{ }

# Função para processar um único arquivo XML
function Process-XmlFile
{
    param (
        [System.IO.FileInfo] $xmlFile
    )

    Write-Debug "Processando arquivo: $( $xmlFile.FullName )" -InformationAction Continue

    # Lê o conteúdo do arquivo XML
    $conteudo = Get-Content -Path $xmlFile.FullName -Raw -Encoding UTF8

    # Extrai a chave do arquivo usando a regex
    $match = $chaveRegex.Match($conteudo)

    if (-not $match.Success) {
        Write-Warning "Arquivo $( $xmlFile.Name ) não contém uma chave válida no formato esperado."
        return
    }

    $chave = $match.Groups[1].Value

    if ($chave.Length -ne 44) {
        Write-Warning "Chave $chave inválida."
        return
    }

    $ano = 2000 + [int] $chave.Substring(2, 2)
    $mes = $chave.Substring(4, 2)

    Write-Debug "- Chave: $chave, Ano: $ano, Mês: $mes" -InformationAction Continue

    # Define o caminho do arquivo de estado para este ano e mês
    $arquivoEstado = Join-Path $StateDir "chaves-$ano-$mes.xml"

    # Carrega o arquivo de lista de chaves do ano e mês, se existir
    if (-not $cacheChaves.ContainsKey($arquivoEstado)) {
        $cacheChaves[$arquivoEstado] = ( Test-Path -Path $arquivoEstado -PathType Leaf) ? ( Import-CliXml $arquivoEstado) : @{ }
    }

    $chavesExistentes = $cacheChaves[$arquivoEstado]

    # Confere se a nova chave consta no arquivo
    if ( $chavesExistentes.ContainsKey($chave)) {
        Write-Debug "- Chave: $chave, já processada anteriormente, ignorando." -InformationAction Continue
        return
    }

    # Não está na lista, faz o upload
    $sucesso = Invoke-UploadXML -Conteudo $conteudo -Chave $chave -Cred $cred
    if (-not $sucesso) { return }

    Write-Information "$( $chave ): upload OK!" -InformationAction Continue

    # Upload concluído com sucesso, adiciona a chave na lista e persiste
    $chavesExistentes[$chave] = @{
        Arquivo = $xmlFile.FullName
        DataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $chavesExistentes | Export-CliXml -Path $arquivoEstado
    Write-Debug "- Upload realizado com sucesso. Estado salvo em $arquivoEstado" -InformationAction Continue
}

do {
    try {
        # Percorre todos os arquivos XML nos diretórios watchdirs, recursivamente, usando travessia BFS incremental
        foreach ($watchDir in $WatchDirs) {
            $dirQueue = New-Object System.Collections.Queue
            $dirQueue.Enqueue($watchDir.FullName)

            while ($dirQueue.Count -gt 0) {
                $currentDir = $dirQueue.Dequeue()
                $dirName = Resolve-Path -Path $currentDir -RelativeBasePath $watchDir

                Write-Debug "Listando diretório $dirName"
                $files = Get-ChildItem -Path $currentDir -Filter '*.xml' -File | Sort-Object LastWriteTime -Descending
                $total = $files.Count
                Write-Debug "$dirName : $total arquivos encontrados"

                $i = 0
                foreach ($file in $files) {
                    $i++
                    Write-Progress -Activity "Processando diretório" -Status "$i de $total" -PercentComplete (($i / $total) * 100)
                    try {
                        Process-XmlFile -xmlFile $file
                    }
                    catch {
                        Write-Error "Erro ao transmitir XML $file : $( $_.Exception.Message )"
                    }
                }
                Write-Progress -Activity "Processando diretório" -Status "Concluído" -PercentComplete 100 -Completed
                Get-ChildItem -Path $currentDir -Directory | ForEach-Object { $dirQueue.Enqueue($_.FullName) }
            }
        }
        Write-Information "Sincronização concluída, será repetida em 1min."
    }
    catch {
        Write-Warning "Ocorreu um erro durante a sincronização, será repetida em 1min"
    }
    Start-Sleep -Seconds 60
}
while ($KeepRunning);