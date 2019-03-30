#!/usr/bin/env python3

###############################################################################
# Script para sincronização de XMLs com o Portal Consyst-e
# Documentação da integração: https://portal.consyste.com.br/doc/api
###############################################################################

import argparse
import json
import os
import sys
import time
import http.client
from urllib import request, parse


def main(params):
    # cria diretório de saída, se não existir
    if not os.path.isdir(params.out):
        os.makedirs(params.out)

    # cria cliente de API
    api = ConsysteClient(params.token)

    # coleta as chaves a baixar, de acordo com a consulta solicitada
    chaves = coleta_chaves(api, params.kind, params.query)

    # baixa os XMLs para o diretório de saída
    baixa_xmls(api, params.kind, chaves, params.out)


def coleta_chaves(api, kind, q):
    start = time.perf_counter()
    print("Coletando chaves... ", end='')
    res = api.call_consyste(f"/{kind}/lista/recebidos", q=q)

    chaves = list()
    while True:
        novos = [d['chave'] for d in res['documentos']]
        if len(novos) == 0:
            break
        chaves.extend(novos)
        print('.', end='')
        res = api.call_consyste(f"/{kind}/lista/continua/{res['proxima_pagina']}")

    print()
    print(f'Obtidas {len(chaves)} chaves em {round(time.perf_counter() - start)}s')

    return chaves


def baixa_xmls(api, kind, chaves, outdir):
    baixados = 0
    start = time.perf_counter()
    for chave in progressbar(chaves):
        print(f'{chave} ', end='')
        outfile = os.path.join(outdir, f"{chave}.xml")

        if os.path.isfile(outfile):
            print('encontrado')
            continue

        try:
            api.call_consyste(f'/{kind}/{chave}/download.xml', outfile=outfile)
            print('OK!')
            baixados += 1
        except Exception as e:
            print('ERRO:', e)

    print(f'Realizado o download de {baixados} XMLs, em {round(time.perf_counter() - start)}s')


class ConsysteClient:
    def __init__(self, token):
        self.token = token
        self.conn = http.client.HTTPSConnection('portal.consyste.com.br')

    def call_consyste(self, path, outfile=None, **kwargs):
        if len(kwargs) > 0:
            path += '?' + parse.urlencode(dict(kwargs))

        self.conn.request('GET', '/api/v1/' + path, headers={'X-Consyste-Auth-Token': self.token})
        with self.conn.getresponse() as res:
            body = res.read()
            rjs = json.loads(body.decode('utf8')) if body[0] == b'{'[0] else None

            if res.status != 200:
                if rjs is not None:
                    raise Exception(f'HTTP {res.status} - {rjs["error"]}')
                else:
                    raise Exception(f'HTTP {res.status} - {body}')

            if outfile is None:
                return rjs if rjs is not None else body

            with open(outfile, 'wb') as f:
                f.write(body)


def progressbar(it, prefix="", size=60, file=sys.stdout):
    count = len(it)

    def show(j):
        if sys.stdout.isatty():
            x = int(size*j/count)
            file.write("\n\u001B[K\n\u001B[K")
            file.write("%s[%s%s] %i/%i\r" % (prefix, "#"*x, "."*(size-x), j, count))
            file.write("\u001B[2A")
        file.flush()

    show(0)
    for i, item in enumerate(it):
        yield item
        show(i+1)

    if sys.stdout.isatty():
        file.write("\n\n\n")

    file.flush()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Faz o download de XMLs da Plataforma Consyst-e")
    parser.add_argument('out', default="./xmls", nargs='?',
                        help="diretório onde os XMLs serão salvos, padrão: ./xmls")
    parser.add_argument('-k', '--kind', default='nfe', choices=('nfe', 'cte'),
                        help="tipo de documento a baixar (nfe ou cte), padrão: nfe")
    parser.add_argument('-q', '--query', default='recebido_em: [now-30d TO *]',
                        help="consulta a rodar, se não for especificado serão baixados os documentos recebidos nos últimos 30 dias")
    parser.add_argument('-t', '--token', default=os.environ.get('CONSYSTE_TOKEN'),
                        help="token de autenticação na Consyst-e, se não for especificado será lido da variável de ambiente CONSYSTE_TOKEN")

    params = parser.parse_args()

    if params.token is None or len(params.token) == 0:
        print('ERRO: O token deve ser especificado', file=sys.stderr)
        parser.print_help(file=sys.stderr)
        exit(1)

    main(params)
