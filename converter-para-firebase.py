#!/usr/bin/env python3
"""
Converte o array de jogadores (saida do pipeline n8n) para o formato de
arvore que o Firebase Realtime Database espera: um objeto com uma chave
unica por jogador, em vez de uma lista.

Uso:
    python3 converter-para-firebase.py jogadores.json jogadores_futebol_seed.json
"""
import json
import re
import sys
import unicodedata


def slugify(nome_desambiguado, indice):
    """Gera uma chave legivel e unica a partir do nome (ou nome+epoca, se homonimo).
    Ex: 'Danilo (2018-2026)' -> 'danilo_2018_2026'. Se colidir, acrescenta indice."""
    s = unicodedata.normalize('NFKD', nome_desambiguado or f'jogador_{indice}')
    s = s.encode('ascii', 'ignore').decode('ascii')
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '_', s).strip('_')
    return s or f'jogador_{indice}'


def main():
    if len(sys.argv) != 3:
        print('Uso: python3 converter-para-firebase.py <entrada.json> <saida.json>')
        sys.exit(1)

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        jogadores = json.load(f)

    arvore = {}
    chaves_usadas = set()

    for i, j in enumerate(jogadores):
        chave_base = slugify(j.get('nome_desambiguado') or j.get('nome'), i)
        chave = chave_base
        n = 2
        while chave in chaves_usadas:
            chave = f'{chave_base}_{n}'
            n += 1
        chaves_usadas.add(chave)

        arvore[chave] = {
            'nome': j.get('nome'),
            'nome_exibicao': j.get('nome_desambiguado') or j.get('nome'),
            'posicao': j.get('posicao'),
            'clube_atual': j.get('clube_atual'),
            'copas_disputadas': j.get('copas_disputadas', []),
            'nivel_dificuldade': j.get('nivel_dificuldade_sugerido'),
            'possivel_homonimo': j.get('possivel_homonimo', False),
            'revisao_manual': j.get('revisao_manual', False),
            'imagem_url': None
        }

    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(arvore, f, ensure_ascii=False, indent=2)

    print(f'{len(arvore)} jogadores convertidos -> {sys.argv[2]}')


if __name__ == '__main__':
    main()
