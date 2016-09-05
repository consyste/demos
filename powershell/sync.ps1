###############################################################################
# Script para sincronização de XMLs com o Portal Consyst-e
# Documentação da integração: https://portal.consyste.com.br/doc/api
###############################################################################

param (
   [Parameter(Mandatory=$true)][string]$AuthToken,   # o token de autenticação no Consyst-e
   [string]$OutDir = '/tmp/xmls',                    # o diretório onde os XMLs serão salvos
   [string]$Query = ''                               # consulta a rodar
)

$ErrorActionPreference = 'Stop'
$baseUri = 'https://portal.consyste.com.br/api/v1'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

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

$res = Call-Consyste "/nfe/lista/recebidos?q=$([uri]::EscapeDataString($Query))"

$sw1 = New-Object Diagnostics.Stopwatch
$sw1.Start()

$chaves = New-Object System.Collections.Generic.List[System.Object]
while ($true) {
  $novos = $res | foreach {$_.documentos.chave}
  If ($novos.Count -eq 0) { break }
  $chaves.AddRange($novos)
  $pp = $res.proxima_pagina
  Write-Progress "Coletando chaves" -PercentComplete ($chaves.Count / $res.total * 100)
  $res = Call-Consyste "/nfe/lista/continua/$pp"
}
Write-Progress "Coletando chaves" -Completed
$sw1.Stop()

Write-Host
Write-Host
Write-Host
Write-Host
Write-Host
Write-Host "Obtidas $($chaves.Count) chaves em $($sw1.Elapsed)"

$sw2 = New-Object Diagnostics.Stopwatch
$sw2.Start()
$baixados = 0
foreach ($chave in $chaves) {
  Write-Host -NoNewLine "$chave "
  $existe = Test-Path "$OutDir/$chave.xml"
  If ($existe) {
    Write-Host -ForegroundColor Gray "encontrado"
  }
  Else {
    Write-Host -NoNewLine "baixando... "
    Try {
      Call-Consyste "/nfe/$chave/download.xml" -OutFile "$OutDir/$chave.xml" | Out-Null
      Write-Host -ForegroundColor Green "OK!"
      $baixados += 1
    }
    Catch {
      Write-Host -ForegroundColor Red "ERRO: $($_.Exception.Message)"
    }
  }
}
$sw2.Stop()

Write-Host "Realizado o download de ${baixados} XMLs, em $($sw2.Elapsed)"
