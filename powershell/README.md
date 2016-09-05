# Exemplos em PowerShell

## sync.ps1

Exemplo de sincronização de um diretório de XMLs com o sistema da Consyst-e.
Obtém a lista de chaves através de consulas ao webservice, e depois baixa os
XMLs que ainda não existirem no diretório especificado.

### Uso

```
powershell -File sync.ps1 -OutDir "C:\XMLs" -AuthToken "abcdefg" -Query 'recebido_em: [2016-08-30 TO *]'
```
