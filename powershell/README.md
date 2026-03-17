# Exemplos em PowerShell

## download.ps1

Exemplo que realiza download dos XMLs no sistema da Consyst-e para um diretório local.
Obtém a lista de chaves através de consultas à API da Consyst-e, e depois baixa os
XMLs que ainda não existirem no diretório especificado.

### Uso

Para utilizar, é necessário gerar uma chave de acesso de integração, acessando o
endereço: https://portal.consyste.com.br/app/perfil_usuario/editar

No parâmetro `Query` pode ser informada qualquer consulta válida para o Portal.

Exemplo de uso:

```
powershell -File download.ps1 -OutDir "C:\XMLs" -AuthToken "abcdefg" -Query 'recebido_em: [2016-08-30 TO *]'
```

## upload.ps1

Exemplo que realiza o upload de XMLs de um diretório local para o sistema da Consyst-e.
Ele inicia listando todos os arquivos nos diretórios especificados, e faz o upload dos
arquivos que não tenha enviado anteriormente.

### Uso

Para utilizar, é necessário gerar uma chave de acesso de integração, acessando o
endereço: https://portal.consyste.com.br/app/perfil_usuario/editar

Na primeira execução, o script irá solicitar a chave de acesso. Após informar a chave,
ela será salva de forma segura e criptografada em um arquivo chamado `creds.xml`
no diretório especificado em `-StateDir`.

Exemplo de uso:

```
powershell -File upload.ps1 -StateDir "C:\XMLs\ConsysteState" -WatchDirs "C:\XMLs" "D:\XMLs"
```
