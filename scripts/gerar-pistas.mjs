/**
 * Regera o campo `pistas` de `jogadores_futebol/` seguindo a ordem que o spec exige.
 *
 * A secao 7 manda as pistas virem "da mais dificil pra mais facil", e a tabela da secao 11 paga
 * mais por acertar cedo (100/80/60/40). Logo a ordem nao e enfeite: se a ultima pista revela menos
 * que a anterior, a pista mais barata ajuda menos, e o placar perde o sentido.
 *
 * Corrige tres problemas encontrados ao rodar o app contra o conteudo real:
 *   1. metadado interno vazando como pista ("Nivel de dificuldade sugerido para esse jogador");
 *   2. ordem invertida no fim (clube atual, que e revelador, vinha antes de uma pista vaga);
 *   3. texto sem acentuacao, que aparece assim na TV a 3 metros.
 *
 * NAO toca em nenhum outro campo — em particular, `imagem_url` fica intacto (as ilustracoes sao
 * geradas pelo fluxo do n8n em paralelo). A escrita usa caminhos `{id}/pistas`, entao e impossivel
 * sobrescrever o registro inteiro por acidente.
 *
 * Uso:
 *   node scripts/gerar-pistas.mjs              # so mostra o que mudaria (dry-run)
 *   node scripts/gerar-pistas.mjs --aplicar    # grava no Firebase real (via Firebase CLI, admin)
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const BANCO = 'https://que-jogador-e-esse-default-rtdb.firebaseio.com';
const PATCH = 'content/patch-pistas.json';
const aplicar = process.argv.includes('--aplicar');

/** Mesmo slug do `converter-para-firebase.py`, para casar o dado bruto com os ids ja em producao. */
function slug(nome) {
  return (nome ?? '')
    .normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

/** Como a posicao aparece na pista. Evita o enum quebrado do dado ("defensor", "meias"). */
const TEXTO_POSICAO = {
  goleiro: 'Defendeu o gol.',
  zagueiro: 'Atuou na zaga.',
  defensor: 'Atuou na defesa.',
  lateral: 'Atuou pelas laterais do campo.',
  'meio-campista': 'Atuou no meio-campo.',
  meias: 'Atuou no meio-campo.',
  atacante: 'Atuou no ataque.',
};

function listarAnos(anos) {
  if (anos.length === 1) return anos[0];
  return `${anos.slice(0, -1).join(', ')} e ${anos[anos.length - 1]}`;
}

/**
 * Monta as pistas em ordem crescente de quanto entregam. O indice do array e a ordem de revelacao,
 * entao a primeira (100 pontos) precisa ser a mais vaga e a ultima (40) a mais reveladora.
 */
function montarPistas(jogador, gols) {
  const copas = Array.isArray(jogador.copas_disputadas) ? jogador.copas_disputadas : [];
  const candidatas = [];

  // A ordem de insercao e a ordem de revelacao: do mais generico para o mais revelador.
  // O campo `tipo` existe so para decidir o que cortar quando sobram candidatas (ver abaixo).

  // Posicao — a informacao mais generica que existe (centenas de jogadores compartilham).
  // Quando a posicao foi INFERIDA na curadoria, nao afirmamos: seria uma pista possivelmente falsa.
  if (jogador.posicao && !jogador.posicao_inferida) {
    candidatas.push({ tipo: 'posicao', texto: TEXTO_POSICAO[jogador.posicao] ?? 'Atuou no meio-campo.' });
  }

  // Quantas Copas — estreita bastante sem entregar a epoca.
  if (copas.length === 0) {
    candidatas.push({ tipo: 'copas_quantas', texto: 'Nunca disputou uma Copa do Mundo pela Seleção principal.' });
  } else if (copas.length === 1) {
    candidatas.push({ tipo: 'copas_quantas', texto: 'Disputou uma Copa do Mundo pela Seleção Brasileira.' });
  } else {
    candidatas.push({ tipo: 'copas_quantas', texto: `Disputou ${copas.length} Copas do Mundo pela Seleção Brasileira.` });
  }

  // Em quais Copas — entrega a epoca, o que reduz muito o campo de chute.
  if (copas.length) candidatas.push({ tipo: 'copas_anos', texto: `Esteve na Copa de ${listarAnos(copas)}.` });

  // Gols no Brasileirao — numero especifico, bem revelador para quem acompanha.
  if (gols > 0) candidatas.push({ tipo: 'gols', texto: `Marcou ${gols} gols no último Brasileirão.` });

  // Clube atual — a pista mais reveladora de todas, por isso sempre a última.
  if (jogador.clube_atual) candidatas.push({ tipo: 'clube', texto: `Hoje joga no ${jogador.clube_atual}.` });

  // Sobrando candidatas para 4 vagas, corta-se pelo MEIO, nunca pelas pontas: a primeira pista
  // precisa continuar sendo a mais vaga (vale 100) e a ultima a mais reveladora (vale 40).
  // Ordem de descarte: primeiro os gols, depois a contagem de Copas — que fica redundante
  // quando os anos das Copas ja aparecem na pista seguinte.
  const descartaveis = ['gols', 'copas_quantas'];
  let escolhidas = [...candidatas];
  for (const tipo of descartaveis) {
    if (escolhidas.length <= 4) break;
    const i = escolhidas.findIndex((c) => c.tipo === tipo);
    if (i >= 0) escolhidas.splice(i, 1);
  }

  return escolhidas.slice(0, 4).map((c) => c.texto);
}

// --- dado bruto, so para recuperar os gols do Brasileirao (nao existem na arvore do Firebase) ---
const brutos = JSON.parse(readFileSync('content/raw/jogadores.json', 'utf8'));
const golsPorId = new Map();
for (const b of brutos) {
  const id = slug(b.nome_desambiguado || b.nome);
  if (typeof b.gols_brasileirao === 'number') golsPorId.set(id, b.gols_brasileirao);
}

const resposta = await fetch(`${BANCO}/jogadores_futebol.json`);
const jogadores = await resposta.json();

/** Ids de homonimos ganham sufixo (`danilo_santos_2`); o dado bruto nao tem esse sufixo. */
function golsDo(id) {
  return golsPorId.get(id) ?? golsPorId.get(id.replace(/_\d+$/, '')) ?? 0;
}

const patch = {};
let semMinimo = 0;
for (const [id, jogador] of Object.entries(jogadores)) {
  const pistas = montarPistas(jogador, golsDo(id));

  // A secao 7 pede pelo menos 3 pistas. Quem nao chega la (dado pobre demais) ganha uma pista
  // final pela inicial do nome — bem reveladora, por isso entra por ultimo, valendo menos.
  const inicial = (jogador.nome_exibicao ?? jogador.nome ?? '?').trim().charAt(0).toUpperCase();
  while (pistas.length < 3 && inicial !== '?') {
    const dica = `O nome dele começa com a letra ${inicial}.`;
    if (pistas.includes(dica)) break;
    pistas.push(dica);
  }

  if (pistas.length < 3) { semMinimo++; continue; }
  patch[`${id}/pistas`] = pistas;
}

writeFileSync(PATCH, `${JSON.stringify(patch, null, 2)}\n`);

const total = Object.keys(patch).length;
const distrib = {};
for (const p of Object.values(patch)) distrib[p.length] = (distrib[p.length] ?? 0) + 1;

console.log(`jogadores com pistas novas: ${total}`);
console.log(`quantidade de pistas: ${JSON.stringify(distrib)}`);
if (semMinimo) console.log(`sem as 3 pistas mínimas (mantidos como estavam): ${semMinimo}`);
console.log(`\namostra:`);
for (const id of ['neymar', 'vini_jr', 'a_barreal', 'taffarel'].filter((k) => patch[`${k}/pistas`])) {
  console.log(`\n  ${jogadores[id].nome_exibicao} (${id})`);
  patch[`${id}/pistas`].forEach((p, i) => {
    console.log(`    pista ${i + 1} — ${[100, 80, 60, 40][i]} pts — ${p}`);
  });
}

if (!aplicar) {
  console.log(`\nNada foi gravado. Rode com --aplicar para publicar.`);
  process.exit(0);
}

// Chaves com barra fazem o Realtime Database atualizar SO o filho `pistas` de cada jogador.
execFileSync('npx', ['firebase', 'database:update', '/jogadores_futebol', PATCH,
                     '--project', 'que-jogador-e-esse', '--force'],
             { stdio: 'inherit' });
console.log(`\n${total} jogadores atualizados no Firebase.`);
