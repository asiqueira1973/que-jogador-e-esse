/**
 * Baixa o banco de conteudo `jogadores_futebol/` do projeto Firebase REAL e grava um snapshot
 * local, para dar para testar o app com o conteudo de verdade (pistas e ilustracoes) sem escrever
 * nada em producao.
 *
 * Nao implementa regra da secao 11 — e ferramenta de desenvolvimento. O conteudo continua sendo
 * produzido fora do app (secao 7: "importado via Firebase CLI ou console antes do lancamento").
 *
 * Uso:
 *   node scripts/baixar-conteudo.mjs                 # baixa e relata o estado do conteudo
 *   node scripts/baixar-conteudo.mjs --emulador      # baixa e carrega no emulador local
 */
import { writeFileSync } from 'node:fs';

const BANCO_PRODUCAO = 'https://que-jogador-e-esse-default-rtdb.firebaseio.com';
const EMULADOR = 'http://127.0.0.1:9000';
const NAMESPACE = 'que-jogador-e-esse-default-rtdb';
const DESTINO = 'content/jogadores_futebol.producao.json';

const carregarNoEmulador = process.argv.includes('--emulador');

/** Descreve o quanto do conteudo esta pronto para o jogo rodar, campo a campo da secao 7. */
function diagnosticar(jogadores) {
  const ids = Object.keys(jogadores);
  const jogaveis = ids.filter((id) => Array.isArray(jogadores[id]?.pistas) && jogadores[id].pistas.length >= 3);
  return {
    total: ids.length,
    // O app so consegue sortear quem tem pistas — sem isso o jogo nao roda (modelo da secao 7).
    jogaveis: jogaveis.length,
    semPistas: ids.length - jogaveis.length,
    comImagem: ids.filter((id) => jogadores[id]?.imagem_url).length,
    semPosicao: ids.filter((id) => !jogadores[id]?.posicao).length,
    posicaoInferida: ids.filter((id) => jogadores[id]?.posicao_inferida).length,
    revisaoManual: ids.filter((id) => jogadores[id]?.revisao_manual === true).length,
    nomeAbreviado: ids.filter((id) => /(^|\s)[A-ZÀ-Ý]\.(\s|$)/.test(jogadores[id]?.nome_exibicao ?? '')).length,
    pistasPorJogador: [...new Set(jogaveis.map((id) => jogadores[id].pistas.length))].sort(),
  };
}

const resposta = await fetch(`${BANCO_PRODUCAO}/jogadores_futebol.json`);
if (!resposta.ok) {
  console.error(`Não consegui ler o banco de produção (HTTP ${resposta.status}).`);
  process.exit(1);
}

const jogadores = await resposta.json();
writeFileSync(DESTINO, `${JSON.stringify(jogadores, null, 2)}\n`);

const d = diagnosticar(jogadores);
console.log(`Snapshot salvo em ${DESTINO}`);
console.log(`  total no banco:        ${d.total}`);
console.log(`  jogáveis (com pistas): ${d.jogaveis}${d.jogaveis ? ` — ${d.pistasPorJogador.join('/')} pistas por jogador` : ''}`);
console.log(`  SEM pistas:            ${d.semPistas}  <- o app não consegue sortear estes`);
console.log(`  com ilustração:        ${d.comImagem}`);
console.log(`  sem posição:           ${d.semPosicao} (inferida em ${d.posicaoInferida})`);
console.log(`  revisão manual:        ${d.revisaoManual}`);
console.log(`  nome abreviado:        ${d.nomeAbreviado}  <- revelação sai estranha (risco da seção 23)`);

if (!carregarNoEmulador) process.exit(0);

const envio = await fetch(`${EMULADOR}/jogadores_futebol.json?ns=${NAMESPACE}`, {
  method: 'PUT',
  headers: { Authorization: 'Bearer owner' },   // conteudo entra como admin (regras da secao 6)
  body: JSON.stringify(jogadores),
});
console.log(envio.ok
  ? `Carregado no emulador: ${d.total} jogadores.`
  : `Falha ao carregar no emulador (HTTP ${envio.status}). O emulador está rodando?`);
