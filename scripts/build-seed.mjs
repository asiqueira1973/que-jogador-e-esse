/**
 * Gera o conteudo de `jogadores_futebol/` (secao 7 do spec) a partir do dado bruto do
 * pipeline n8n (secao 27) e separa o que ainda precisa de curadoria humana.
 *
 * Este script NAO implementa nenhuma regra da secao 11 — ele so prepara conteudo.
 * Ele existe para atender o Definition of Done (secao 26): "nenhum dado de jogadores_futebol/
 * publicado sem curadoria manual do campo nome_exibicao e sem revisao_manual: false".
 *
 * Saidas:
 *   content/jogadores_futebol.json      -> pronto para importar no Realtime Database
 *   content/pendencias-curadoria.json   -> registros barrados, com o motivo de cada um
 *   content/pendencias-curadoria.md     -> a mesma lista em formato de checklist humano
 */
import { writeFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { loadRaw } from './rtf-to-json.mjs';

/** Enum de `posicao` fixado pela secao 7 do spec. Nada fora desta lista pode ser publicado. */
const POSICOES_VALIDAS = ['goleiro', 'zagueiro', 'lateral', 'meio-campista', 'atacante'];

/** Sinonimos que o pipeline produziu e que mapeiam sem ambiguidade para o enum da secao 7. */
const SINONIMOS_POSICAO = {
  meias: 'meio-campista',
  meia: 'meio-campista',
  'meio-campo': 'meio-campista',
};

/**
 * Normaliza a posicao vinda do pipeline para o enum da secao 7.
 * Devolve `null` quando o valor e ambiguo (ex.: "defensor", que pode ser zagueiro ou lateral)
 * — nesse caso o jogador vira pendencia de curadoria em vez de receber um chute.
 */
function normalizarPosicao(bruta) {
  if (!bruta) return null;
  const valor = String(bruta).trim().toLowerCase();
  if (POSICOES_VALIDAS.includes(valor)) return valor;
  return SINONIMOS_POSICAO[valor] ?? null;
}

/**
 * Detecta nome abreviado do tipo "K. Viveros" — risco listado na secao 23: um nome abreviado
 * na tela de revelacao estraga a graca do "quem e". Nome assim vira pendencia de curadoria.
 */
function nomeEhAbreviado(nome) {
  return /(^|\s)[A-ZÀ-Ý]\.(\s|$)/.test(nome);
}

/** Gera um id estavel e legivel a partir do nome, usado como chave em `jogadores_futebol/{id}`. */
function gerarId(nome) {
  return nome
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

/** Formata a lista de anos de Copa como texto de pista ("2018 e 2022"). */
function listarAnos(anos) {
  if (anos.length === 1) return anos[0];
  return `${anos.slice(0, -1).join(', ')} e ${anos[anos.length - 1]}`;
}

/**
 * Monta as pistas candidatas em ordem de revelacao — da mais dificil (mais generica) para a
 * mais facil (mais reveladora), como exige o campo `pistas` da secao 7.
 * O texto gerado aqui e CANDIDATO: a curadoria humana pode reescrever qualquer pista.
 */
function montarPistas(bruto, posicao) {
  const copas = Array.isArray(bruto.copas_disputadas) ? bruto.copas_disputadas : [];
  const candidatas = [];

  if (posicao) candidatas.push(`Joga como ${posicao}.`);
  if (copas.length) {
    candidatas.push(
      copas.length === 1
        ? 'Foi convocado para uma Copa do Mundo.'
        : `Foi convocado para ${copas.length} Copas do Mundo.`,
    );
  }
  if (copas.length) candidatas.push(`Esteve na Copa de ${listarAnos(copas)}.`);
  if (typeof bruto.gols_brasileirao === 'number' && bruto.gols_brasileirao > 0) {
    candidatas.push(`Marcou ${bruto.gols_brasileirao} gols no último Brasileirão.`);
  }
  if (bruto.clube_atual) candidatas.push(`Hoje defende o ${bruto.clube_atual}.`);

  return candidatas;
}

/** Converte um registro bruto no formato de `jogadores_futebol/{id}` (secao 7). */
function converter(bruto) {
  const nomeExibicao = bruto.nome_desambiguado || bruto.nome;
  const posicao = normalizarPosicao(bruto.posicao);
  const motivos = [];

  if (bruto.revisao_manual) motivos.push('pipeline marcou revisao_manual: true');
  if (bruto.possivel_homonimo) motivos.push('possivel homonimo — checar se e a mesma pessoa');
  if (!posicao) {
    motivos.push(
      bruto.posicao
        ? `posicao "${bruto.posicao}" fora do enum da secao 7 e ambigua para mapear`
        : 'posicao ausente no dado de origem',
    );
  }
  if (nomeEhAbreviado(nomeExibicao)) {
    motivos.push(`nome_exibicao abreviado ("${nomeExibicao}") — expandir antes de publicar`);
  }

  const pistas = montarPistas(bruto, posicao);
  if (pistas.length < 3) motivos.push(`so foi possivel gerar ${pistas.length} pista(s); minimo 3`);

  return {
    id: gerarId(nomeExibicao),
    registro: {
      nome: bruto.nome,
      nome_exibicao: nomeExibicao,
      posicao: posicao ?? '',
      clube_atual: bruto.clube_atual ?? null,
      copas_disputadas: Array.isArray(bruto.copas_disputadas) ? bruto.copas_disputadas : [],
      nivel_dificuldade: bruto.nivel_dificuldade_sugerido ?? 'medio',
      pistas,
      imagem_url: '',
    },
    motivos,
  };
}

function build() {
  const brutos = loadRaw();
  const prontos = {};
  const pendencias = [];
  const idsVistos = new Map();

  for (const bruto of brutos) {
    const { id, registro, motivos } = converter(bruto);

    // Ids duplicados sao colisao de conteudo, nao de codigo: mandar para curadoria.
    if (idsVistos.has(id)) {
      pendencias.push({ id, nome: registro.nome, motivos: [...motivos, `id duplicado com "${idsVistos.get(id)}"`], registro });
      continue;
    }
    idsVistos.set(id, registro.nome_exibicao);

    if (motivos.length) pendencias.push({ id, nome: registro.nome, motivos, registro });
    else prontos[id] = registro;
  }

  writeFileSync('content/jogadores_futebol.json', `${JSON.stringify(prontos, null, 2)}\n`);
  writeFileSync('content/pendencias-curadoria.json', `${JSON.stringify(pendencias, null, 2)}\n`);

  const linhas = [
    '# Pendências de curadoria — `jogadores_futebol/`',
    '',
    'Gerado por `scripts/build-seed.mjs`. Cada item abaixo foi **barrado** da importação porque',
    'o Definition of Done (seção 26 do spec) proíbe publicar conteúdo sem curadoria manual.',
    '',
    `Prontos para importar: **${Object.keys(prontos).length}** · Pendentes: **${pendencias.length}**`,
    '',
    '| Jogador | Motivos |',
    '|---|---|',
    ...pendencias.map((p) => `| ${p.registro.nome_exibicao} | ${p.motivos.join('; ')} |`),
    '',
    '## Como resolver',
    '',
    '1. Corrija o registro em `content/pendencias-curadoria.json` (nome completo, posição do enum da seção 7, pistas).',
    '2. Mova o objeto `registro` para `content/jogadores_futebol.json` sob a chave do `id`.',
    '3. Rode `npm run seed:validar` para conferir o schema antes de importar.',
    '',
  ];
  writeFileSync('content/pendencias-curadoria.md', `${linhas.join('\n')}\n`);

  console.log(`jogadores_futebol prontos: ${Object.keys(prontos).length}`);
  console.log(`pendencias de curadoria:   ${pendencias.length}`);
}

function isMain() {
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return false;
  }
}

if (isMain()) build();

export { converter, normalizarPosicao, nomeEhAbreviado, montarPistas, gerarId, POSICOES_VALIDAS };
