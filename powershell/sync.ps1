###############################################################################
# Script para sincronização de XMLs com o Portal Consyst-e
# Documentação da integração: https://portal.consyste.com.br/doc/api
###############################################################################

param (
   [Parameter(Mandatory=$true)][string]$AuthToken,   # o token de autenticação no Consyst-e
   [string]$OutDir = '/tmp/xmls',                    # o diretório onde os XMLs serão salvos
   [string]$Kind = 'nfe',                            # o tipo de documento a consultar ('nfe' ou 'cte')
   [string]$Filter = 'todos',                        # o tipo de filtro a consultar:
                                                     #   para nfe, usar: 'recebidos', 'emitidos' ou 'todos'
                                                     #   para cte, usar: 'tomados', 'emitidos' ou 'todos'
   [string]$Query = 'recebido_em: [now-30d TO *]'    # consulta a rodar
)

$ErrorActionPreference = 'Stop'
$baseUri = 'https://portal.consyste.com.br/api/v1'

# cria o diretório de saída, se não existir
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# função para chamar a API da Consyst-e
function Call-Consyste {
  param (
    [Parameter(Position=0)][string]$path,
    $OutFile
  )
  $uri = "$baseUri$path"
  $pp = $progressPreference
  $progressPreference = 'silentlyContinue'
  Invoke-RestMethod -Headers @{ 'X-Consyste-Auth-Token' = $AuthToken } -Uri $uri -OutFile $OutFile
  $progressPreference = $pp
}

# inicia um cronômetro
$sw1 = New-Object Diagnostics.Stopwatch
$sw1.Start()

# prepara uma lista de chaves
$chaves = New-Object System.Collections.Generic.List[System.Object]

# chama a API com a consulta solicitada
$res = Call-Consyste "/${Kind}/lista/${Filter}?q=$([uri]::EscapeDataString($Query))"

# percorre a API, preenchendo a lista de chaves, até não encontrar mais documentos 
while ($true) {
  $novos = $res | foreach {$_.documentos.chave}
  If ($novos.Count -eq 0) { break }
  $chaves.AddRange($novos)
  $pp = $res.proxima_pagina
  Write-Progress "Coletando chaves" -PercentComplete ($chaves.Count / $res.total * 100)
  $res = Call-Consyste "/${Kind}/lista/continua/$pp"
}
Write-Progress "Coletando chaves" -Completed

# encerra o cronômetro
$sw1.Stop()

Write-Host
Write-Host
Write-Host
Write-Host
Write-Host
Write-Host "Obtidas $($chaves.Count) chaves em $($sw1.Elapsed)"

# inicia um novo cronômetro
$sw2 = New-Object Diagnostics.Stopwatch
$sw2.Start()

# cria um contador de XMLs baixados
$baixados = 0

# para cada chave, verifica se já foi baixada ou não
foreach ($chave in $chaves) {
  Write-Host -NoNewLine "$chave "
  $existe = Test-Path "$OutDir/$chave.xml"
  If ($existe) {
    # caso positivo, informa que o XML já foi encontrado
    Write-Host -ForegroundColor Gray "encontrado"
  }
  Else {
    # caso negativo, tenta baixar
    Write-Host -NoNewLine "baixando... "
    Try {
      Call-Consyste "/$Kind/$chave/download.xml" -OutFile "$OutDir/$chave.xml" | Out-Null
      
      # se o download funcionar, sinaliza e contabiliza
      Write-Host -ForegroundColor Green "OK!"
      $baixados += 1
    }
    Catch {
      # se ocorrer erro no download, sinaliza
      Write-Host -ForegroundColor Red "ERRO: $($_.Exception.Message)"
    }
  }
}
$sw2.Stop()

# apresenta a quantidade de XMLs baixados e o tempo decorrido
Write-Host "Realizado o download de ${baixados} XMLs, em $($sw2.Elapsed)"
