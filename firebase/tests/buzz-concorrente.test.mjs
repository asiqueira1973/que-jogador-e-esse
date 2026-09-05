/**
 * Prova o criterio de aceite mais critico do epico 8.3:
 * "Dois toques simultaneos (ou proximos) resolvem de forma deterministica para um unico vencedor
 *  — nunca dois jogadores 'ganham' a mesma pista."
 *
 * Usa o SDK real do Firebase contra o emulador, com as regras ligadas — ou seja, exercita
 * exatamente o mesmo caminho de codigo que a PWA do convidado usa (`runTransaction` em
 * `salas/{codigo}/buzz_atual`), incluindo a regra do servidor que proibe sobrescrever o buzz.
 *
 * Rode com:  npx firebase emulators:exec --only database "node --test firebase/tests/*.test.mjs"
 */
import { after, before, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase/app';
import { getDatabase, connectDatabaseEmulator, ref, set, get, remove, runTransaction } from 'firebase/database';

const CODIGO = 'B7QX';
const QUANTIDADE_DE_CONVIDADOS = 12;
const RODADAS = 8;

let app;
let db;

before(async () => {
  const [host, porta] = (process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000').split(':');
  app = initializeApp({ projectId: 'que-jogador-e-esse', databaseURL: `http://${host}:${porta}?ns=que-jogador-e-esse-default-rtdb` });
  db = getDatabase(app);
  connectDatabaseEmulator(db, host, Number(porta));

  await set(ref(db, `salas/${CODIGO}`), {
    estado: 'rodada_ativa',
    criado_em: Date.now(),
    pista_atual_index: 0,
    rodada_numero: 1,
    jogador_futebol_atual_id: 'neymar',
    jogadores: Object.fromEntries(
      Array.from({ length: QUANTIDADE_DE_CONVIDADOS }, (_, i) => [
        `j${i}`, { apelido: `Convidado ${i}`, pontos: 0, conectado_em: Date.now() + i, ativo: true },
      ]),
    ),
  });
});

after(async () => {
  await remove(ref(db, `salas/${CODIGO}`));
  await deleteApp(app);
});

/** Repete a mesma transacao que a PWA faz ao tocar "EU SEI!" (`comprarResposta` em app.js). */
async function comprar(jogadorId) {
  try {
    const resultado = await runTransaction(ref(db, `salas/${CODIGO}/buzz_atual`), (atual) => {
      if (atual !== null) return undefined;
      return { jogador_sala_id: jogadorId, timestamp: Date.now() };
    });
    return resultado.committed ? jogadorId : null;
  } catch {
    return null;
  }
}

describe('buzz-in concorrente — regra de empate da secao 11', () => {
  it(`${QUANTIDADE_DE_CONVIDADOS} toques simultaneos produzem exatamente um vencedor`, async () => {
    const ids = Array.from({ length: QUANTIDADE_DE_CONVIDADOS }, (_, i) => `j${i}`);
    const resultados = await Promise.all(ids.map(comprar));
    const vencedores = resultados.filter(Boolean);

    assert.equal(vencedores.length, 1, `esperava 1 vencedor, veio ${vencedores.length}: ${vencedores}`);

    const gravado = (await get(ref(db, `salas/${CODIGO}/buzz_atual`))).val();
    assert.equal(gravado.jogador_sala_id, vencedores[0], 'o banco guardou um vencedor diferente do que a transacao confirmou');
  });

  it(`o resultado se mantem unico ao longo de ${RODADAS} disputas seguidas`, async () => {
    for (let rodada = 0; rodada < RODADAS; rodada++) {
      await remove(ref(db, `salas/${CODIGO}/buzz_atual`));
      const ids = Array.from({ length: QUANTIDADE_DE_CONVIDADOS }, (_, i) => `j${i}`);
      const vencedores = (await Promise.all(ids.map(comprar))).filter(Boolean);
      assert.equal(vencedores.length, 1, `rodada ${rodada + 1}: ${vencedores.length} vencedores`);
    }
  });

  it('quem perdeu a corrida nao consegue sobrescrever o buzz nem por escrita direta', async () => {
    await remove(ref(db, `salas/${CODIGO}/buzz_atual`));
    await comprar('j0');

    await assert.rejects(
      () => set(ref(db, `salas/${CODIGO}/buzz_atual`), { jogador_sala_id: 'j5', timestamp: Date.now() }),
      /PERMISSION_DENIED/i,
      'a regra do servidor deveria barrar a sobrescrita do buzz',
    );

    const gravado = (await get(ref(db, `salas/${CODIGO}/buzz_atual`))).val();
    assert.equal(gravado.jogador_sala_id, 'j0');
  });
});
