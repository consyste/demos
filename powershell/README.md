# Exemplos em PowerShell

## sync.ps1

Exemplo de sincronização de um diretório de XMLs com o sistema da Consyst-e.
Obtém a lista de chaves através de consultas à API da Consyst-e, e depois baixa os
XMLs que ainda não existirem no diretório especificado.

### Uso

Para utilizar, é necessário gerar uma chave de acesso de integração, acessando o
endereço: https://portal.consyste.com.br/app/perfil_usuario/editar

No parâmetro `Query` pode ser informada qualquer consulta válida para o Portal.

Exemplo de uso:

```
powershell -File sync.ps1 -OutDir "C:\XMLs" -AuthToken "abcdefg" -Query 'recebido_em: [2016-08-30 TO *]'
```
