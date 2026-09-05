#!/usr/bin/env python3
"""
Gera os ativos de marca do app tvOS: o icone em camadas (efeito de profundidade quando o app
ganha foco na Apple TV) e as Top Shelf images.

tvOS nao aceita um PNG unico como iOS: o icone e uma "image stack" de 2 a 5 camadas, e cada
camada precisa ter exatamente o tamanho do icone. A camada de tras fica parada, as da frente
se deslocam conforme o controle move o foco.

Usa a identidade ja estabelecida no app (canvas "Perfil FC"): fundo indigo de noite de estadio,
amarelo de holofote como cor de marca, tipografia Anton.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONTE_ANTON = "tvos-app/Resources/Fonts/Anton-Regular.ttf"
FONTE_BARLOW = "tvos-app/Resources/Fonts/BarlowCondensed-Bold.ttf"

INDIGO_ALTO = (27, 36, 112)
INDIGO_MEIO = (12, 16, 56)
INDIGO_BASE = (7, 10, 34)
HOLOFOTE = (255, 216, 77)
TINTA = (16, 17, 42)
BRANCO = (242, 244, 255)

SUPER = 3  # supersampling: desenha grande e reduz, para borda limpa


def fundo(w, h):
    """Camada de tras: gradiente radial de noite de estadio. Opaca, e a base da pilha."""
    img = Image.new("RGB", (w, h), INDIGO_BASE)
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, h * 0.1
    raio = max(w, h) * 1.15
    passos = 180
    for i in range(passos, 0, -1):
        t = i / passos
        if t > 0.5:
            k = (t - 0.5) * 2
            cor = tuple(int(INDIGO_MEIO[j] + (INDIGO_BASE[j] - INDIGO_MEIO[j]) * k) for j in range(3))
        else:
            k = t * 2
            cor = tuple(int(INDIGO_ALTO[j] + (INDIGO_MEIO[j] - INDIGO_ALTO[j]) * k) for j in range(3))
        r = raio * t
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=cor)
    return img


def holofote(w, h):
    """Camada do meio: o facho de luz. Transparente, e o que da profundidade ao se mover."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Dois halos concentricos: o de dentro mais forte, para o facho ler como luz quente e nao
    # como uma mancha cinza quando composto sobre o indigo.
    for escala, alpha in ((0.86, 40), (0.52, 78)):
        rw, rh = w * 0.66 * escala, h * 0.82 * escala
        d.ellipse([w / 2 - rw / 2, h / 2 - rh / 2, w / 2 + rw / 2, h / 2 + rh / 2],
                  fill=HOLOFOTE + (alpha,))
    return img.filter(ImageFilter.GaussianBlur(radius=max(w, h) * 0.055))


def desenhar_bola(d, cx, cy, r):
    """Bola de futebol minimalista: circulo branco, pentagono central e costuras saindo dele.
    Nesse tamanho, mais detalhe vira sujeira — o pentagono e as costuras ja leem como bola."""
    import math
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRANCO + (255,))

    p = r * 0.46
    vertices = []
    for i in range(5):
        ang = math.radians(-90 + i * 72)
        vertices.append((cx + p * math.cos(ang), cy + p * math.sin(ang)))
    d.polygon(vertices, fill=TINTA + (255,))

    # Costuras: do vertice do pentagono ate a borda, dando o padrao classico.
    for vx, vy in vertices:
        ang = math.atan2(vy - cy, vx - cx)
        d.line([(vx, vy), (cx + r * 0.98 * math.cos(ang), cy + r * 0.98 * math.sin(ang))],
               fill=TINTA + (255,), width=max(2, int(r * 0.13)))


def achar_ponto(alfa, w, h):
    """Devolve a caixa do PONTO do "?", separando-o do corpo do glifo.

    O ponto e um pedaco solto: existe uma linha inteiramente vazia entre ele e o gancho de cima.
    Procurar essa linha de baixo para cima e confiavel em qualquer tamanho — chutar coordenadas
    quebra, porque o desenho da fonte muda de proporcao conforme o corpo."""
    pixels = alfa.load()
    def linha_vazia(y):
        return all(pixels[x, y] == 0 for x in range(w))

    fundo_glifo = None
    for y in range(h - 1, -1, -1):
        if not linha_vazia(y):
            fundo_glifo = y
            break
    if fundo_glifo is None:
        return None

    topo_ponto = None
    for y in range(fundo_glifo, -1, -1):
        if linha_vazia(y):
            topo_ponto = y + 1
            break
    if topo_ponto is None or topo_ponto >= fundo_glifo:
        return None

    xs = [x for y in range(topo_ponto, fundo_glifo + 1) for x in range(w) if pixels[x, y] > 0]
    if not xs:
        return None
    return min(xs), topo_ponto, max(xs), fundo_glifo


def marca(w, h, com_bola=True):
    """Camada da frente: a interrogacao, simbolo do jogo. Transparente.

    O ponto da interrogacao E a bola de futebol — junta as duas ideias do produto (adivinhar e
    futebol) num simbolo so, em vez de empilhar dois desenhos concorrendo por atencao."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 0.66 da altura deixa margem para a bola, que fica um pouco maior que o ponto original.
    fonte = ImageFont.truetype(FONTE_ANTON, int(h * 0.66))
    caixa = d.textbbox((0, 0), "?", font=fonte)
    lw, lh = caixa[2] - caixa[0], caixa[3] - caixa[1]
    x = (w - lw) / 2 - caixa[0]
    y = (h - lh) / 2 - caixa[1]

    glifo = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(glifo).text((x, y), "?", font=fonte, fill=HOLOFOTE + (255,))

    if com_bola:
        ponto = achar_ponto(glifo.split()[3], w, h)
        if ponto:
            x0, y0, x1, y1 = ponto
            # Apaga SO a caixa do ponto, sem encostar no corpo do glifo.
            ImageDraw.Draw(glifo).rectangle([x0 - 1, y0 - 1, x1 + 1, y1 + 1], fill=(0, 0, 0, 0))
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            raio = max(x1 - x0, y1 - y0) * 0.62
            desenhar_bola(ImageDraw.Draw(glifo), cx, cy, raio)

    # Sombra da peca inteira (interrogacao + bola), para ela descolar do fundo ao ganhar foco.
    sombra = glifo.copy()
    sombra.putdata([(0, 0, 0, min(160, a)) for (_, _, _, a) in glifo.getdata()])
    img.alpha_composite(sombra.filter(ImageFilter.GaussianBlur(radius=h * 0.018)),
                        (0, int(h * 0.015)))
    img.alpha_composite(glifo)
    return img


def salvar(img, caminho, tamanho):
    img.resize(tamanho, Image.LANCZOS).save(caminho, optimize=True)
    print(f"  {caminho}  {tamanho[0]}x{tamanho[1]}")


def camadas_do_icone(largura, altura, prefixo, com_bola=True):
    w, h = largura * SUPER, altura * SUPER
    salvar(fundo(w, h).convert("RGBA"), f"{prefixo}-back.png", (largura, altura))
    salvar(holofote(w, h), f"{prefixo}-middle.png", (largura, altura))
    salvar(marca(w, h, com_bola), f"{prefixo}-front.png", (largura, altura))


def top_shelf(largura, altura, caminho):
    """Faixa larga que a Apple TV mostra quando o app esta na primeira fileira da tela inicial."""
    w, h = largura * SUPER, altura * SUPER
    img = fundo(w, h).convert("RGBA")
    img.alpha_composite(holofote(w, h))
    d = ImageDraw.Draw(img)

    fonte_titulo = ImageFont.truetype(FONTE_ANTON, int(h * 0.30))
    titulo = "QUE JOGADOR É ESSE?"
    caixa = d.textbbox((0, 0), titulo, font=fonte_titulo)
    tw = caixa[2] - caixa[0]
    d.text(((w - tw) / 2 - caixa[0], h * 0.30), titulo, font=fonte_titulo, fill=BRANCO + (255,))

    fonte_sub = ImageFont.truetype(FONTE_BARLOW, int(h * 0.10))
    sub = "O CELULAR É O CONTROLE  ·  A TV É O PALCO"
    caixa2 = d.textbbox((0, 0), sub, font=fonte_sub)
    sw = caixa2[2] - caixa2[0]
    d.text(((w - sw) / 2 - caixa2[0], h * 0.62), sub, font=fonte_sub, fill=HOLOFOTE + (255,))

    salvar(img.convert("RGB"), caminho, (largura, altura))


if __name__ == "__main__":
    import os
    saida = "tvos-app/Resources/BrandAssets"
    os.makedirs(saida, exist_ok=True)
    print("icone da tela inicial (400x240 e 800x480):")
    camadas_do_icone(400, 240, f"{saida}/icone-1x")
    camadas_do_icone(800, 480, f"{saida}/icone-2x")
    print("icone da App Store (1280x768):")
    camadas_do_icone(1280, 768, f"{saida}/icone-loja")
    print("top shelf:")
    top_shelf(1920, 720, f"{saida}/topshelf-1x.png")
    top_shelf(3840, 1440, f"{saida}/topshelf-2x.png")
    top_shelf(2320, 720, f"{saida}/topshelf-wide-1x.png")
    top_shelf(4640, 1440, f"{saida}/topshelf-wide-2x.png")
