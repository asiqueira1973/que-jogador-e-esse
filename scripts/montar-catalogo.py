#!/usr/bin/env python3
"""
Monta o Assets.xcassets do app tvOS a partir dos PNGs gerados por `gerar-icones.py`.

tvOS exige uma estrutura propria: o icone e uma "image stack" com camadas em pastas
`.imagestacklayer`, e o conjunto todo vive dentro de um `.brandassets`. Escrever isso a mao no
Xcode e trabalhoso e facil de errar — este script deixa reproduzivel.
"""
import json, os, shutil

RAIZ = "tvos-app/Resources/Assets.xcassets"
ORIGEM = "tvos-app/Resources/BrandAssets"
MARCA = f"{RAIZ}/App Icon & Top Shelf Image.brandassets"
INFO = {"author": "xcode", "version": 1}


def escrever(caminho, conteudo):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as f:
        json.dump(conteudo, f, indent=2)


def camada(destino, nome, arquivos):
    """Uma camada da pilha: pasta .imagestacklayer com um .imageset dentro."""
    pasta = f"{destino}/{nome}.imagestacklayer"
    escrever(f"{pasta}/Contents.json", {"info": INFO})
    os.makedirs(f"{pasta}/Content.imageset", exist_ok=True)
    imagens = []
    for escala, origem in arquivos:
        alvo = os.path.basename(origem)
        shutil.copy(origem, f"{pasta}/Content.imageset/{alvo}")
        imagens.append({"filename": alvo, "idiom": "tv", "scale": escala})
    escrever(f"{pasta}/Content.imageset/Contents.json", {"images": imagens, "info": INFO})


def pilha(nome, prefixos):
    """prefixos: lista de (escala, prefixo dos PNGs) — 1x e 2x quando houver."""
    destino = f"{MARCA}/{nome}.imagestack"
    escrever(f"{destino}/Contents.json",
             {"info": INFO,
              "layers": [{"filename": "Front.imagestacklayer"},
                         {"filename": "Middle.imagestacklayer"},
                         {"filename": "Back.imagestacklayer"}]})
    for parte in ("Back", "Middle", "Front"):
        camada(destino, parte,
               [(escala, f"{ORIGEM}/{pref}-{parte.lower()}.png") for escala, pref in prefixos])


def conjunto(nome, arquivos):
    destino = f"{MARCA}/{nome}.imageset"
    imagens = []
    for escala, origem in arquivos:
        alvo = os.path.basename(origem)
        os.makedirs(destino, exist_ok=True)
        shutil.copy(origem, f"{destino}/{alvo}")
        imagens.append({"filename": alvo, "idiom": "tv", "scale": escala})
    escrever(f"{destino}/Contents.json", {"images": imagens, "info": INFO})


shutil.rmtree(RAIZ, ignore_errors=True)
escrever(f"{RAIZ}/Contents.json", {"info": INFO})

pilha("App Icon", [("1x", "icone-1x"), ("2x", "icone-2x")])
pilha("App Icon - App Store", [("1x", "icone-loja")])
conjunto("Top Shelf Image", [("1x", f"{ORIGEM}/topshelf-1x.png"), ("2x", f"{ORIGEM}/topshelf-2x.png")])
conjunto("Top Shelf Image Wide", [("1x", f"{ORIGEM}/topshelf-wide-1x.png"), ("2x", f"{ORIGEM}/topshelf-wide-2x.png")])

escrever(f"{MARCA}/Contents.json", {
    "assets": [
        {"filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"},
        {"filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"},
        {"filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"},
        {"filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"},
    ],
    "info": INFO,
})
print("catalogo montado em", RAIZ)
