/**
 * Valida `content/jogadores_futebol.json` contra o schema da secao 7 do spec antes de importar.
 *
 * Nao implementa regra da secao 11 — e um portao de qualidade de conteudo, exigido pelo
 * Definition of Done (secao 26). Sai com codigo 1 se qualquer registro estiver invalido.
 */
import { readFileSync, realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { POSICOES_VALIDAS, nomeEhAbreviado } from './build-seed.mjs';

const DIFICULDADES = ['facil', 'medio', 'dificil'];
const MIN_PISTAS = 3;

/** Confere um unico registro de jogador_futebol e devolve a lista de erros encontrados. */
export function validarRegistro(id, r) {
  const erros = [];
  const exigirTexto = (campo) => {
    if (typeof r[campo] !== 'string' || !r[campo].trim()) erros.push(`${campo} vazio ou nao-texto`);
  };

  exigirTexto('nome');
  exigirTexto('nome_exibicao');
  if (typeof r.nome_exibicao === 'string' && nomeEhAbreviado(r.nome_exibicao)) {
    erros.push(`nome_exibicao abreviado ("${r.nome_exibicao}") — risco da secao 23`);
  }
  if (!POSICOES_VALIDAS.includes(r.posicao)) erros.push(`posicao "${r.posicao}" fora do enum da secao 7`);
  if (r.clube_atual !== null && typeof r.clube_atual !== 'string') erros.push('clube_atual deve ser texto ou null');
  if (!Array.isArray(r.copas_disputadas) || r.copas_disputadas.some((a) => !/^\d{4}$/.test(a))) {
    erros.push('copas_disputadas deve ser lista de anos com 4 digitos');
  }
  if (!DIFICULDADES.includes(r.nivel_dificuldade)) erros.push(`nivel_dificuldade "${r.nivel_dificuldade}" invalido`);
  if (!Array.isArray(r.pistas) || r.pistas.length < MIN_PISTAS) {
    erros.push(`pistas precisa ter ao menos ${MIN_PISTAS} itens`);
  } else if (r.pistas.some((p) => typeof p !== 'string' || !p.trim())) {
    erros.push('ha pista vazia ou nao-texto');
  }
  if (typeof r.imagem_url !== 'string') erros.push('imagem_url deve ser texto (pode ser vazio no MVP)');

  return erros.map((e) => `${id}: ${e}`);
}

function main() {
  const caminho = process.argv[2] ?? 'content/jogadores_futebol.json';
  const dados = JSON.parse(readFileSync(caminho, 'utf8'));
  const ids = Object.keys(dados);
  const erros = ids.flatMap((id) => validarRegistro(id, dados[id]));
  const semImagem = ids.filter((id) => !dados[id].imagem_url).length;

  if (erros.length) {
    console.error(`${erros.length} problema(s) em ${caminho}:`);
    for (const e of erros.slice(0, 40)) console.error(`  - ${e}`);
    if (erros.length > 40) console.error(`  ... e mais ${erros.length - 40}`);
    process.exit(1);
  }

  console.log(`OK: ${ids.length} jogadores validos em ${caminho}`);
  if (semImagem) {
    console.log(`Aviso: ${semImagem} sem imagem_url — passo operacional 27.3 (ilustracoes) ainda pendente.`);
  }
}

function isMain() {
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return false;
  }
}

if (isMain()) main();
