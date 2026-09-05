/**
 * Limpeza das salas efemeras — implementa a "Estrategia de exclusao" da secao 7 do spec:
 * "uma rotina de limpeza remove salas com `estado: 'encerrada'` ha mais de 24h".
 *
 * O MVP roda no plano Spark do Firebase (secao 4), que nao tem Cloud Functions agendadas —
 * entao esta e a versao manual: rode de tempos em tempos, ou por um cron na maquina do Alexandre.
 * `jogadores_futebol/` NUNCA e tocado aqui: e conteudo permanente.
 *
 * Uso:
 *   node scripts/limpar-salas.mjs                 # so lista o que seria apagado
 *   node scripts/limpar-salas.mjs --apagar        # apaga de verdade
 *   node scripts/limpar-salas.mjs --horas 48      # muda a janela (padrao: 24h)
 */
import { execFileSync } from 'node:child_process';

const args = process.argv.slice(2);
const apagar = args.includes('--apagar');
const horas = Number(args[args.indexOf('--horas') + 1]) || 24;
const limite = Date.now() - horas * 60 * 60 * 1000;

/** Le ou escreve no Realtime Database pelo Firebase CLI, para nao exigir credencial extra. */
function firebase(...comando) {
  return execFileSync('npx', ['firebase', ...comando], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

const salas = JSON.parse(firebase('database:get', '/salas') || 'null') ?? {};
const alvos = Object.entries(salas).filter(([, sala]) =>
  sala?.estado === 'encerrada' && (sala.criado_em ?? 0) < limite);

if (!alvos.length) {
  console.log(`Nenhuma sala encerrada ha mais de ${horas}h.`);
  process.exit(0);
}

console.log(`${alvos.length} sala(s) encerrada(s) ha mais de ${horas}h:`);
for (const [codigo, sala] of alvos) {
  console.log(`  ${codigo} — criada em ${new Date(sala.criado_em ?? 0).toISOString()}`);
}

if (!apagar) {
  console.log('\nNada foi apagado. Rode de novo com --apagar para confirmar.');
  process.exit(0);
}

for (const [codigo] of alvos) {
  // O historico da sala tambem e efemero e some junto (secao 7).
  firebase('database:remove', `/salas/${codigo}`, '--force');
  firebase('database:remove', `/rodadas_historico/${codigo}`, '--force');
  console.log(`apagada: ${codigo}`);
}
