# Exemplos em Python

## sync.py

Exemplo de sincronização de um diretório de XMLs com o sistema da Consyst-e.
Obtém a lista de chaves através de consultas à API da Consyst-e, e depois baixa os
XMLs que ainda não existirem no diretório especificado.

### Uso

Para utilizar, é necessário gerar uma chave de acesso de integração, acessando o
endereço: https://portal.consyste.com.br/app/perfil_usuario/editar

Exemplo de uso básico:

```
./sync.py --token "abcdefg" /mnt/nas/xmls
```

Para verificar os parâmetros adicionais, pode ser utilizado o seguinte comando:

```
./sync.py --help
```
