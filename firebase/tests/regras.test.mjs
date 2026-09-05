/**
 * Testes das regras de seguranca do Realtime Database (secao 6 do spec).
 *
 * Cobrem o Definition of Done (secao 26): "regras implementadas conforme secao 6, testadas
 * contra escrita nao autorizada fora do escopo da sala".
 *
 * Rode com:  npx firebase emulators:exec --only database "node --test firebase/tests/"
 */
import { after, before, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { ref, set, get, remove } from 'firebase/database';

const CODIGO = 'A4K7';
let testEnv;
let db;

/** Escreve direto no banco ignorando as regras — usado so para montar cenario de teste. */
async function comRegrasDesligadas(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => fn(ctx.database()));
}

/** Monta uma sala valida com um convidado dentro, para os testes que precisam de estado previo. */
async function montarSalaComConvidado(jogadorId = 'j1') {
  await comRegrasDesligadas(async (adminDb) => {
    await set(ref(adminDb, `salas/${CODIGO}`), {
      estado: 'rodada_ativa',
      criado_em: 1000,
      pista_atual_index: 0,
      rodada_numero: 1,
      jogador_futebol_atual_id: 'neymar',
      jogadores: {
        [jogadorId]: { apelido: 'Duda', pontos: 0, conectado_em: 1000, ativo: true },
      },
    });
  });
}

before(async () => {
  const [host, port] = (process.env.FIREBASE_DATABASE_EMULATOR_HOST ?? '127.0.0.1:9000').split(':');
  testEnv = await initializeTestEnvironment({
    projectId: 'que-jogador-e-esse',
    database: {
      rules: readFileSync('firebase/database.rules.json', 'utf8'),
      host,
      port: Number(port),
    },
  });
  db = testEnv.unauthenticatedContext().database();
});

after(async () => {
  await testEnv?.cleanup();
});

describe('banco de conteudo jogadores_futebol/', () => {
  it('e legivel por qualquer cliente (a PWA e a TV precisam ler)', async () => {
    await assertSucceeds(get(ref(db, 'jogadores_futebol/neymar')));
  });

  it('nao e gravavel por cliente — conteudo entra so via Firebase CLI (secao 7)', async () => {
    await assertFails(set(ref(db, 'jogadores_futebol/invasor'), { nome: 'Fake' }));
  });
});

describe('escrita fora do escopo da sala', () => {
  it('nega escrita na raiz', async () => {
    await assertFails(set(ref(db, 'qualquer_coisa'), { x: 1 }));
  });

  it('nega escrita em um no irmao inventado', async () => {
    await assertFails(set(ref(db, 'configuracoes_secretas'), { admin: true }));
  });

  it('nega escrita direto no no salas/ (sem codigo)', async () => {
    await assertFails(set(ref(db, 'salas'), { HACK: { estado: 'aguardando', criado_em: 1 } }));
  });

  it('nega leitura do no salas/ inteiro — so a sala com codigo conhecido e legivel', async () => {
    await assertFails(get(ref(db, 'salas')));
  });
});

describe('criacao de sala', () => {
  it('aceita codigo de 4 caracteres maiusculos', async () => {
    await assertSucceeds(
      set(ref(db, `salas/${CODIGO}`), { estado: 'aguardando', criado_em: 1000, pista_atual_index: 0, rodada_numero: 0 }),
    );
  });

  it('recusa codigo minusculo (formato fora do combinado na secao 6)', async () => {
    await assertFails(set(ref(db, 'salas/a4k7'), { estado: 'aguardando', criado_em: 1000 }));
  });

  it('recusa codigo longo demais', async () => {
    await assertFails(set(ref(db, 'salas/A4K7Q9Z'), { estado: 'aguardando', criado_em: 1000 }));
  });

  it('recusa estado fora do enum da secao 7', async () => {
    await assertFails(set(ref(db, `salas/${CODIGO}/estado`), 'jogando'));
  });

  it('recusa campo inventado dentro da sala', async () => {
    await assertFails(set(ref(db, `salas/${CODIGO}/campo_invasor`), 'x'));
  });
});

describe('entrada de convidado (salas/{codigo}/jogadores/{id})', () => {
  before(async () => {
    await comRegrasDesligadas(async (adminDb) => remove(ref(adminDb, `salas/${CODIGO}`)));
    await montarSalaComConvidado();
  });

  it('permite que quem conhece o codigo se cadastre — trade-off consciente da secao 6', async () => {
    await assertSucceeds(
      set(ref(db, `salas/${CODIGO}/jogadores/j2`), {
        apelido: 'Marina', pontos: 0, conectado_em: 2000, ativo: true,
      }),
    );
  });

  it('recusa apelido vazio', async () => {
    await assertFails(
      set(ref(db, `salas/${CODIGO}/jogadores/j3`), {
        apelido: '', pontos: 0, conectado_em: 2000, ativo: true,
      }),
    );
  });

  it('recusa apelido longo demais', async () => {
    await assertFails(
      set(ref(db, `salas/${CODIGO}/jogadores/j4`), {
        apelido: 'x'.repeat(25), pontos: 0, conectado_em: 2000, ativo: true,
      }),
    );
  });

  it('recusa registro sem os campos obrigatorios da secao 7', async () => {
    await assertFails(set(ref(db, `salas/${CODIGO}/jogadores/j5`), { apelido: 'Rafa' }));
  });

  it('recusa campo extra no registro do convidado', async () => {
    await assertFails(
      set(ref(db, `salas/${CODIGO}/jogadores/j6`), {
        apelido: 'Rafa', pontos: 0, conectado_em: 2000, ativo: true, admin: true,
      }),
    );
  });

  it('recusa pontuacao negativa', async () => {
    await assertFails(set(ref(db, `salas/${CODIGO}/jogadores/j1/pontos`), -50));
  });
});

describe('buzz_atual — regra de empate da secao 11', () => {
  before(async () => {
    await comRegrasDesligadas(async (adminDb) => remove(ref(adminDb, `salas/${CODIGO}`)));
    await montarSalaComConvidado('j1');
    await comRegrasDesligadas(async (adminDb) => {
      await set(ref(adminDb, `salas/${CODIGO}/jogadores/j2`), {
        apelido: 'Marina', pontos: 0, conectado_em: 1100, ativo: true,
      });
    });
  });

  it('aceita a primeira compra quando o no esta vazio', async () => {
    await assertSucceeds(
      set(ref(db, `salas/${CODIGO}/buzz_atual`), { jogador_sala_id: 'j1', timestamp: 5000 }),
    );
  });

  it('recusa a segunda compra — quem chegou depois nao sobrescreve o vencedor', async () => {
    await assertFails(
      set(ref(db, `salas/${CODIGO}/buzz_atual`), { jogador_sala_id: 'j2', timestamp: 5001 }),
    );
  });

  it('permite limpar o buzz (a TV libera a proxima pista)', async () => {
    await assertSucceeds(remove(ref(db, `salas/${CODIGO}/buzz_atual`)));
  });

  it('recusa buzz de um jogador que nao esta na sala', async () => {
    await assertFails(
      set(ref(db, `salas/${CODIGO}/buzz_atual`), { jogador_sala_id: 'fantasma', timestamp: 6000 }),
    );
  });
});

describe('tentativas_bloqueadas — regra da secao 11', () => {
  before(async () => {
    await comRegrasDesligadas(async (adminDb) => remove(ref(adminDb, `salas/${CODIGO}`)));
    await montarSalaComConvidado('j1');
  });

  it('aceita marcar um jogador como bloqueado', async () => {
    await assertSucceeds(set(ref(db, `salas/${CODIGO}/tentativas_bloqueadas/j1`), true));
  });

  it('recusa valor que nao seja true (o no e um conjunto, nao um contador)', async () => {
    await assertFails(set(ref(db, `salas/${CODIGO}/tentativas_bloqueadas/j1`), 3));
  });

  it('permite limpar o conjunto inteiro no sorteio do proximo jogador', async () => {
    await assertSucceeds(remove(ref(db, `salas/${CODIGO}/tentativas_bloqueadas`)));
  });
});

describe('rodadas_historico/', () => {
  it('aceita uma rodada completa', async () => {
    await assertSucceeds(
      set(ref(db, `rodadas_historico/${CODIGO}/r1`), {
        jogador_futebol_id: 'neymar',
        pistas_reveladas: 3,
        vencedor_jogador_sala_id: 'j1',
        pontos_ganhos: 60,
        encerrada_em: 9000,
      }),
    );
  });

  it('recusa rodada sem os campos obrigatorios', async () => {
    await assertFails(set(ref(db, `rodadas_historico/${CODIGO}/r2`), { jogador_futebol_id: 'neymar' }));
  });

  it('recusa pontuacao acima do maximo possivel da secao 11', async () => {
    await assertFails(
      set(ref(db, `rodadas_historico/${CODIGO}/r3`), {
        jogador_futebol_id: 'neymar',
        pistas_reveladas: 1,
        pontos_ganhos: 5000,
        encerrada_em: 9000,
      }),
    );
  });
});
