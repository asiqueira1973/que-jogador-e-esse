/**
 * Gera as artes de screenshot para a App Store da Apple TV.
 *
 * A Apple aceita 1920x1080 ou 3840x2160 para tvOS. As artes sao montadas em HTML e renderizadas
 * pelo Chrome em modo headless, o que garante o tamanho exato do pixel — compor "quase do tamanho"
 * e depois reamostrar degrada a tipografia, que e justamente o que precisa ler numa vitrine.
 *
 * A identidade e a MESMA do app (indigo de noite de estadio, amarelo de holofote, Anton + Barlow):
 * arte de loja com tipografia diferente da do produto promete uma coisa e entrega outra.
 */
import { writeFileSync, readFileSync, mkdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const CAPTURAS = process.argv[2];                    // pasta com os PNGs do simulador
const SAIDA = process.argv[3] ?? `${CAPTURAS}/artes`;
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const FONTES = 'tvos-app/Resources/Fonts';

mkdirSync(SAIDA, { recursive: true });

/** Fontes embutidas em base64: o Chrome headless nao carrega @font-face por file:// de forma confiavel. */
const fonte = (arquivo) => readFileSync(`${FONTES}/${arquivo}`).toString('base64');
const ANTON = fonte('Anton-Regular.ttf');
const COND = fonte('BarlowCondensed-Bold.ttf');
const BARLOW = fonte('Barlow-Regular.ttf');
const BARLOW_SEMI = fonte('Barlow-SemiBold.ttf');

const CSS = `
@font-face { font-family: Anton; src: url(data:font/ttf;base64,${ANTON}) format('truetype'); }
@font-face { font-family: Cond; src: url(data:font/ttf;base64,${COND}) format('truetype'); }
@font-face { font-family: Barlow; src: url(data:font/ttf;base64,${BARLOW}) format('truetype'); font-weight: 400; }
@font-face { font-family: Barlow; src: url(data:font/ttf;base64,${BARLOW_SEMI}) format('truetype'); font-weight: 600; }

:root {
  --fundo: #070A22;
  --indigo: #131A52;
  --holofote: #FFD84D;
  --tinta: #10112A;
  --texto: #F2F4FF;
  --texto-2: #8E96BF;
  --acerto: #34D399;
}
* { margin: 0; padding: 0; box-sizing: border-box; }
html, body { width: 1920px; height: 1080px; overflow: hidden; }
body {
  background: radial-gradient(120% 100% at 18% 0%, var(--indigo) 0%, #0B1030 42%, var(--fundo) 100%);
  color: var(--texto);
  font-family: Barlow, sans-serif;
  display: grid;
  grid-template-columns: 600px 1fr;
  align-items: center;
  gap: 48px;
  padding: 0 0 0 88px;
}
/* Faixa da marca no topo, igual a do app — costura a arte ao produto. */
body::before {
  content: ''; position: absolute; inset: 0 0 auto 0; height: 10px;
  background: linear-gradient(90deg, var(--holofote), #7C5CFF 55%, var(--acerto));
}
.texto { display: flex; flex-direction: column; gap: 30px; }
.sobrancelha {
  font-family: Cond, sans-serif; font-size: 30px; letter-spacing: 6px;
  text-transform: uppercase; color: var(--holofote);
}
h1 {
  font-family: Anton, sans-serif; font-weight: 400; font-size: 86px; line-height: 0.98;
  letter-spacing: 0.5px; text-wrap: balance;
}
h1 em { font-style: normal; color: var(--holofote); }
p { font-size: 32px; line-height: 1.45; color: var(--texto-2); max-width: 30ch; }

/* A captura do app: reta, inteira, com o halo de holofote atras — a TV acesa no escuro. */
.palco { position: relative; display: grid; place-items: center; height: 100%; }
.palco::before {
  content: ''; position: absolute; width: 90%; height: 78%;
  background: radial-gradient(closest-side, rgba(255,216,77,.16), transparent 72%);
}
.tela {
  position: relative; width: 1060px; border-radius: 20px; overflow: hidden;
  box-shadow: 0 48px 90px -30px rgba(0,0,0,.85), 0 0 0 1px rgba(255,255,255,.10);
}
.tela img { display: block; width: 100%; }

/* Escada de pontos: existe porque a mecanica do jogo E a queda de pontos a cada pista. */
.escada { display: flex; gap: 14px; align-items: flex-end; }
.degrau {
  font-family: Anton, sans-serif; display: grid; place-items: center;
  border-radius: 12px; background: rgba(255,216,77,.14);
  border: 1px solid rgba(255,216,77,.42); color: var(--holofote);
}

/* Celular ao lado da TV: a unica arte que precisa dos dois para explicar o produto. */
.dupla { display: flex; align-items: center; justify-content: center; gap: 40px;
         height: 100%; padding-right: 56px; }
.dupla .tela { width: 790px; flex: none; }
.celular {
  flex: none; width: 286px; height: 620px;
  border-radius: 42px; background: linear-gradient(180deg, #131A52 0%, #0A0E2A 62%, #070A22 100%);
  border: 8px solid #05060F;
  box-shadow: 0 40px 80px -20px rgba(0,0,0,.9), 0 0 0 1px rgba(255,255,255,.12);
  padding: 36px 18px 22px; display: flex; flex-direction: column; gap: 12px;
}
.cel-topo { display: flex; justify-content: space-between; align-items: center; }
.cel-quem { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; color: #C7CCEC; }
.avatar {
  width: 26px; height: 26px; border-radius: 999px; background: #FFF; color: var(--tinta);
  font-family: Anton, sans-serif; font-size: 13px; display: grid; place-items: center;
}
.cel-pts { font-family: Anton, sans-serif; font-size: 19px; color: var(--holofote); }
.cel-faixa {
  display: flex; justify-content: space-between; padding: 9px 12px; border-radius: 10px;
  background: rgba(255,255,255,.05); font-family: Cond, sans-serif;
  font-size: 12px; letter-spacing: 2px; color: var(--texto-2);
}
.cel-faixa b { color: var(--acerto); font-weight: 700; }
.buzz {
  /* aspect-ratio trava o circulo: com flex:1 o botao esticava e virava oval. */
  flex: none; aspect-ratio: 1; width: 214px; margin: auto; border-radius: 999px;
  background: radial-gradient(120% 120% at 30% 20%, #FFE585, #FFC61A);
  color: var(--tinta); display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 4px;
  box-shadow: 0 0 0 10px rgba(255,216,77,.14), 0 20px 44px -14px rgba(255,198,26,.7);
}
.buzz b { font-family: Anton, sans-serif; font-size: 46px; line-height: 1; font-weight: 400; }
.buzz span { font-family: Cond, sans-serif; font-size: 13px; letter-spacing: 3px; opacity: .72; }
.cel-rodape { font-size: 12px; color: var(--texto-2); text-align: center; line-height: 1.4; }
`;

/** Cada arte: sobrancelha, titulo, apoio, captura e um enfeite opcional que carrega informacao. */
const ARTES = [
  {
    arquivo: '01-ninguem-instala',
    captura: '01-sala.png',
    sobrancelha: 'Jogo de festa para Apple TV',
    titulo: 'Ninguém instala <em>nada</em>.',
    apoio: 'Os convidados apontam a câmera para o QR e já estão jogando. Sem app, sem conta, sem cadastro.',
  },
  {
    arquivo: '02-arrisque-cedo',
    captura: '02-pista.png',
    sobrancelha: 'A cada pista, menos pontos',
    titulo: 'Quem arrisca cedo <em>ganha mais</em>.',
    apoio: 'A ilustração começa borrada e vai abrindo. Quanto mais você espera, mais barata fica a resposta.',
    extra: `<div class="escada">
      ${[[100, 96], [80, 84], [60, 72], [40, 60]].map(([v, t]) =>
        `<div class="degrau" style="width:${t + 40}px;height:${t + 22}px;font-size:${t * 0.46}px">${v}</div>`).join('')}
    </div>`,
  },
  {
    arquivo: '03-toque-primeiro',
    captura: '03-buzz.png',
    sobrancelha: 'O celular é o controle',
    titulo: 'Quem tocar primeiro <em>responde</em>.',
    apoio: 'Um toque em EU SEI! trava o botão de todo mundo. O empate é resolvido no servidor, não no grito.',
    celular: true,
  },
  {
    arquivo: '04-revelacao',
    captura: '04-revelacao.png',
    sobrancelha: 'A hora da verdade',
    titulo: 'E aí o jogo <em>revela</em> quem era.',
    apoio: 'Nome completo, clube e Copas disputadas — e quantos pontos foram para quem acertou.',
  },
  {
    arquivo: '05-placar',
    captura: '05-placar.png',
    sobrancelha: 'Fim de partida',
    titulo: 'O placar <em>decide</em> a treta da família.',
    apoio: 'Pontos somados ao vivo, rodada a rodada, no celular de cada um e na TV.',
  },
];

const celularHTML = `
  <div class="celular">
    <div class="cel-topo">
      <div class="cel-quem"><span class="avatar">D</span>Duda</div>
      <div class="cel-pts">160<span style="font-family:Cond;font-size:11px;letter-spacing:2px;color:#8E96BF"> PTS</span></div>
    </div>
    <div class="cel-faixa"><span>RODADA 3 · PISTA 2</span><b>VALE 80</b></div>
    <div class="buzz"><b>EU SEI!</b><span>TOQUE PARA COMPRAR</span></div>
    <div class="cel-rodape">A pista está na TV.<br>Quem tocar primeiro responde.</div>
  </div>`;

for (const arte of ARTES) {
  const html = `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8"><style>${CSS}</style></head>
<body>
  <div class="texto">
    <div class="sobrancelha">${arte.sobrancelha}</div>
    <h1>${arte.titulo}</h1>
    <p>${arte.apoio}</p>
    ${arte.extra ?? ''}
  </div>
  <div class="${arte.celular ? 'dupla' : 'palco'}">
    <div class="tela"><img src="${resolve(CAPTURAS, arte.captura)}"></div>
    ${arte.celular ? celularHTML : ''}
  </div>
</body></html>`;

  const caminhoHTML = `${SAIDA}/${arte.arquivo}.html`;
  writeFileSync(caminhoHTML, html);

  execFileSync(CHROME, [
    '--headless', '--disable-gpu', '--hide-scrollbars',
    '--force-device-scale-factor=1', '--window-size=1920,1080',
    `--screenshot=${resolve(SAIDA, `${arte.arquivo}.png`)}`,
    `file://${resolve(caminhoHTML)}`,
  ], { stdio: 'ignore' });

  console.log(`  ${arte.arquivo}.png`);
}
console.log(`\n${ARTES.length} artes em ${SAIDA}`);
