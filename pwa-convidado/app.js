/**
 * PWA do convidado — o "controle" do jogo (secao 4 do spec: zero instalacao, Principio 1).
 *
 * Telas: entrada (1h/1i), espera (1j), jogo ativo (1k), jogo bloqueado (1l) e fim de jogo.
 * Escreve em `salas/{codigo}/jogadores/{id}` e `salas/{codigo}/buzz_atual`; le a sala inteira.
 *
 * Convencao da secao 18: codigo em ingles, comentarios em portugues, e as chaves do banco
 * (`apelido`, `pontos`, `buzz_atual`, ...) em portugues snake_case, como manda a secao 7.
 */
import {
  initializeApp, getDatabase, ref, set, get, onValue, runTransaction,
  onDisconnect, connectDatabaseEmulator,
} from './vendor/firebase.js';
import { config, databaseURL } from './config.js';

// ---------------------------------------------------------------------------
// Infraestrutura
// ---------------------------------------------------------------------------

const app = initializeApp({
  apiKey: config.firebase.apiKey,
  databaseURL: databaseURL(),
  projectId: config.firebase.projectId,
});

const db = getDatabase(app);
if (config.useEmulator) {
  const [host, port] = config.emulator.host.split(':');
  connectDatabaseEmulator(db, host, Number(port));
}

const SESSION_KEY = 'quejogador.sessao';
const SCREENS = ['tela-entrada', 'tela-espera', 'tela-jogo', 'tela-fim'];
const $ = (id) => document.getElementById(id);

/** Estado local da aba. `room` e sempre o ultimo snapshot vindo do Realtime Database. */
const state = {
  code: null,
  myId: null,
  myNickname: null,
  room: null,
  unsubscribe: null,
  buzzing: false,
};

// ---------------------------------------------------------------------------
// Sessao do convidado
// ---------------------------------------------------------------------------

/**
 * Guarda quem e este convidado no proprio navegador.
 *
 * Decisao do Alexandre sobre a pergunta aberta 25.2 do spec: em vez de o convidado virar um
 * jogador novo (e perder os pontos) quando a aba recarrega ou a conexao cai, ele volta ao mesmo
 * `jogador_sala_id`. Isso nao muda o modelo de dados da secao 7 — so a PWA.
 */
function saveSession() {
  localStorage.setItem(SESSION_KEY, JSON.stringify({
    codigo: state.code,
    jogadorId: state.myId,
    apelido: state.myNickname,
  }));
}

function readSession() {
  try {
    return JSON.parse(localStorage.getItem(SESSION_KEY) ?? 'null');
  } catch {
    return null;
  }
}

function clearSession() {
  localStorage.removeItem(SESSION_KEY);
}

/** Gera o `jogador_sala_id` no cliente, como define a secao 7 ("ID gerado pelo cliente ao entrar"). */
function newRoomPlayerId() {
  return `j-${crypto.randomUUID?.() ?? Math.random().toString(36).slice(2)}`;
}

// ---------------------------------------------------------------------------
// Navegacao entre telas
// ---------------------------------------------------------------------------

function showScreen(id) {
  for (const screen of SCREENS) $(screen).toggleAttribute('data-ativa', screen === id);
}

// ---------------------------------------------------------------------------
// Entrada na sala (epico 8.2)
// ---------------------------------------------------------------------------

function showFieldError(field, message) {
  $(`campo-${field}`).closest('.campo').setAttribute('data-invalido', '');
  $(`erro-${field}-texto`).textContent = message;
  $(`erro-${field}`).hidden = false;
  // Canvas 1i: no estado de erro o botao vira "TENTAR DE NOVO".
  $('botao-entrar').textContent = 'TENTAR DE NOVO';
}

function clearFieldErrors() {
  for (const field of ['codigo', 'apelido']) {
    $(`campo-${field}`).closest('.campo').removeAttribute('data-invalido');
    $(`erro-${field}`).hidden = true;
  }
}

const ROOM_NOT_FOUND = 'Não achamos essa sala. Confira o código na TV — são 4 caracteres.';

/**
 * Epico 8.2: dois campos, erro de codigo invalido sem recarregar a pagina, e nada mais e pedido.
 * A sala so aceita a entrada se `salas/{codigo}` existir e nao estiver encerrada.
 */
async function joinRoom(event) {
  event.preventDefault();
  clearFieldErrors();

  const code = $('campo-codigo').value.trim().toUpperCase();
  const nickname = $('campo-apelido').value.trim();
  const button = $('botao-entrar');

  if (!/^[A-Z0-9]{4,5}$/.test(code)) {
    showFieldError('codigo', ROOM_NOT_FOUND);
    return;
  }
  if (!nickname) {
    showFieldError('apelido', 'Escolha um apelido para aparecer na TV.');
    return;
  }

  button.disabled = true;
  button.textContent = 'ENTRANDO…';
  try {
    const snapshot = await get(ref(db, `salas/${code}`));
    if (!snapshot.exists()) {
      showFieldError('codigo', ROOM_NOT_FOUND);
      return;
    }
    if (snapshot.val().estado === 'encerrada') {
      showFieldError('codigo', 'Essa sala já foi encerrada. Peça o código novo na TV.');
      return;
    }

    const myId = newRoomPlayerId();
    // Secao 11: nao ha teto de jogadores por sala (decisao do Alexandre na pergunta aberta 25.3).
    await set(ref(db, `salas/${code}/jogadores/${myId}`), {
      apelido: nickname,
      pontos: 0,
      conectado_em: Date.now(),
      ativo: true,
    });

    state.code = code;
    state.myId = myId;
    state.myNickname = nickname;
    saveSession();
    watchRoom();
  } catch (error) {
    showFieldError('codigo', `Não deu para entrar agora. Tente de novo. (${error.code ?? error.message})`);
  } finally {
    button.disabled = false;
    if (button.textContent === 'ENTRANDO…') button.textContent = 'ENTRAR';
  }
}

/**
 * Retoma a sessao guardada no navegador quando a aba recarrega (pergunta aberta 25.2).
 * Se a sala sumiu ou o registro do jogador nao existe mais, cai na tela de entrada normalmente.
 */
async function resumeSession() {
  const session = readSession();
  if (!session?.codigo || !session?.jogadorId) return false;

  try {
    const player = await get(ref(db, `salas/${session.codigo}/jogadores/${session.jogadorId}`));
    const roomState = await get(ref(db, `salas/${session.codigo}/estado`));
    if (!player.exists() || !roomState.exists() || roomState.val() === 'encerrada') {
      clearSession();
      return false;
    }

    state.code = session.codigo;
    state.myId = session.jogadorId;
    state.myNickname = player.val().apelido;
    await set(ref(db, `salas/${state.code}/jogadores/${state.myId}/ativo`), true);
    watchRoom();
    return true;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Acompanhamento da sala
// ---------------------------------------------------------------------------

/**
 * Assina `salas/{codigo}` inteiro. E esta assinatura que garante o criterio de aceite da secao 8.3:
 * o botao "EU SEI!" desabilita para todos os outros em ate 500ms depois de alguem comprar.
 *
 * Caminho de excecao da secao 9: ao perder a conexao, o `onDisconnect` marca `ativo: false`
 * em vez de apagar o registro, para nao zerar os pontos ja ganhos.
 */
function watchRoom() {
  state.unsubscribe?.();
  const myActiveFlag = ref(db, `salas/${state.code}/jogadores/${state.myId}/ativo`);
  onDisconnect(myActiveFlag).set(false).catch(() => {});

  state.unsubscribe = onValue(ref(db, `salas/${state.code}`), (snapshot) => {
    if (!snapshot.exists()) {
      clearSession();
      showScreen('tela-entrada');
      return;
    }
    state.room = snapshot.val();
    render();
  });
}

function guests() {
  const raw = state.room?.jogadores ?? {};
  return Object.entries(raw)
    .map(([id, data]) => ({ id, ...data }))
    .sort((a, b) => (a.conectado_em ?? 0) - (b.conectado_em ?? 0));
}

function me() {
  return guests().find((guest) => guest.id === state.myId) ?? null;
}

// Mesma paleta ciclica de avatares do app tvOS (DesignSystem.swift).
const AVATAR_COLORS = ['#FFD84D', '#7C5CFF', '#34D399', '#FF4D5E', '#FFFFFF'];
const AVATAR_INKS = ['#10112A', '#FFFFFF', '#08221A', '#FFFFFF', '#10112A'];

function paintAvatar(element, nickname, index) {
  element.textContent = (nickname ?? '?').slice(0, 1).toUpperCase();
  element.style.background = AVATAR_COLORS[index % AVATAR_COLORS.length];
  element.style.color = AVATAR_INKS[index % AVATAR_INKS.length];
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

/** Mapeia `salas/{codigo}/estado` (secao 7) para a tela que o convidado deve estar vendo. */
function render() {
  const room = state.room;
  if (!room) return;

  switch (room.estado) {
    case 'aguardando':
      renderWaitingRoom();
      showScreen('tela-espera');
      break;
    case 'rodada_ativa':
    case 'revelado':
      renderGame();
      showScreen('tela-jogo');
      break;
    case 'encerrada':
      $('fim-pontos').textContent = me()?.pontos ?? 0;
      showScreen('tela-fim');
      break;
  }
}

function renderWaitingRoom() {
  $('espera-codigo').textContent = state.code;
  const list = guests();
  const online = list.filter((guest) => guest.ativo).length;
  $('espera-contador').textContent = online === 1 ? '1 conectado' : `${online} conectados`;

  $('espera-lista').replaceChildren(...list.map((guest, index) => {
    const item = document.createElement('li');
    if (guest.id === state.myId) item.setAttribute('data-eu', '');
    if (!guest.ativo) item.setAttribute('data-inativo', '');

    const avatar = document.createElement('span');
    avatar.className = 'avatar';
    paintAvatar(avatar, guest.apelido, index);

    const name = document.createElement('span');
    name.textContent = guest.apelido;

    item.append(avatar, name);
    if (guest.id === state.myId) {
      const badge = document.createElement('span');
      badge.className = 'marcador-eu';
      badge.textContent = 'VOCÊ';
      item.append(badge);
    }
    return item;
  }));
}

/**
 * Decide o estado do botao "EU SEI!" — canvas 1k (ativo) e 1l (bloqueado).
 *
 * Sao tres motivos distintos de bloqueio, e a copy precisa dizer qual e:
 *  1. outro convidado comprou a pista (criterio de aceite da secao 8.3);
 *  2. o proprio convidado comprou e esta respondendo;
 *  3. o convidado ja errou este jogador — regra de `tentativas_bloqueadas` da secao 11.
 */
function blockReason() {
  const room = state.room;
  if (room.estado === 'revelado') {
    return { text: 'Rodada encerrada. Olhe para a TV.', badge: 'AGUARDE', tone: 'neutro' };
  }
  if (room.tentativas_bloqueadas?.[state.myId]) {
    return { text: 'Você já tentou nesta rodada. Espere o próximo jogador.', badge: 'BLOQUEADO', tone: 'erro' };
  }
  const buzz = room.buzz_atual;
  if (buzz?.jogador_sala_id === state.myId) {
    return { text: 'É com você! Fale a resposta em voz alta.', badge: 'RESPONDENDO', tone: 'acerto' };
  }
  if (buzz?.jogador_sala_id) {
    const who = guests().find((guest) => guest.id === buzz.jogador_sala_id);
    return { text: `${who?.apelido ?? 'Alguém'} respondeu primeiro!`, badge: 'BLOQUEADO', tone: 'erro' };
  }
  return null;
}

function renderGame() {
  const room = state.room;
  const myRecord = me();
  const index = guests().findIndex((guest) => guest.id === state.myId);

  paintAvatar($('jogo-avatar'), myRecord?.apelido ?? state.myNickname, Math.max(index, 0));
  $('jogo-apelido').textContent = myRecord?.apelido ?? state.myNickname ?? '';
  $('jogo-pontos').textContent = myRecord?.pontos ?? 0;

  const clueNumber = (room.pista_atual_index ?? 0) + 1;
  $('jogo-rodada').textContent = `Rodada ${room.rodada_numero ?? 1} · Pista ${clueNumber}`;
  $('jogo-valor').textContent = `Vale ${pointsForClue(room.pista_atual_index ?? 0)}`;

  const blocked = blockReason();
  const button = $('botao-buzz');
  const alert = $('jogo-alerta');

  button.disabled = Boolean(blocked) || state.buzzing;
  $('buzz-legenda').textContent = blocked?.badge ?? 'TOQUE PARA COMPRAR';
  $('tela-jogo').toggleAttribute('data-bloqueada', blocked?.tone === 'erro');

  if (blocked) {
    alert.hidden = false;
    alert.textContent = blocked.text;
    alert.setAttribute('data-tom', blocked.tone);
  } else {
    alert.hidden = true;
  }

  $('jogo-dica').textContent = blocked
    ? 'Espere a próxima pista.'
    : 'A pista está na TV. Quem tocar primeiro responde.';
}

/**
 * Espelha a tabela de pontos da secao 11 (100/80/60/40/20) apenas para EXIBIR o valor da pista.
 * Quem calcula e atribui pontos de verdade e o app tvOS (secao 7: a logica vive no anfitriao).
 */
function pointsForClue(index) {
  const table = [100, 80, 60, 40];
  return index < table.length ? table[index] : 20;
}

// ---------------------------------------------------------------------------
// Buzz-in (epico 8.3)
// ---------------------------------------------------------------------------

/**
 * Regra de empate da secao 11: "resolvido pela primeira escrita aceita na transacao do Realtime
 * Database — sem logica adicional de desempate por app".
 *
 * A transacao aborta (retornando undefined) se `buzz_atual` ja existir, entao dois toques
 * simultaneos sempre resolvem para um unico vencedor. As regras do banco reforcam isso no
 * servidor: `buzz_atual/jogador_sala_id` so aceita escrita se ainda nao existir.
 */
async function buzzIn() {
  if (state.buzzing || !state.room || state.room.estado !== 'rodada_ativa') return;

  state.buzzing = true;
  $('botao-buzz').disabled = true;
  try {
    await runTransaction(ref(db, `salas/${state.code}/buzz_atual`), (current) => {
      if (current !== null) return undefined;   // alguem chegou primeiro: aborta
      return { jogador_sala_id: state.myId, timestamp: Date.now() };
    });
  } catch {
    // Perder a corrida nao e erro do usuario — o render mostra quem comprou.
  } finally {
    state.buzzing = false;
    render();
  }
}

// ---------------------------------------------------------------------------
// Inicializacao
// ---------------------------------------------------------------------------

$('form-entrada').addEventListener('submit', joinRoom);
$('botao-buzz').addEventListener('click', buzzIn);
$('campo-codigo').addEventListener('input', (event) => {
  event.target.value = event.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
});
$('botao-nova-sala').addEventListener('click', () => {
  state.unsubscribe?.();
  clearSession();
  Object.assign(state, { code: null, myId: null, myNickname: null, room: null });
  $('form-entrada').reset();
  clearFieldErrors();
  $('botao-entrar').textContent = 'ENTRAR';
  showScreen('tela-entrada');
});

// Volta do segundo plano: garante que este convidado conste como ativo de novo.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && state.code && state.myId) {
    set(ref(db, `salas/${state.code}/jogadores/${state.myId}/ativo`), true).catch(() => {});
  }
});

// Pre-preenche o codigo quando ele vem na URL (ex.: quejogador.app/entrar?sala=4K7Q).
const codeFromURL = new URLSearchParams(location.search).get('sala');
if (codeFromURL) $('campo-codigo').value = codeFromURL.toUpperCase();

resumeSession();
