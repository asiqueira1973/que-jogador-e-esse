/**
 * Captura as telas da PWA do convidado como PNG, dirigindo o Chrome pelo protocolo de depuracao.
 *
 * Um screenshot simples de linha de comando nao serve aqui: as telas da PWA so existem depois de
 * entrar numa sala (digitar apelido, enviar o formulario) e conforme o estado da partida muda no
 * Firebase. Entao o script abre o Chrome, interage de verdade com a pagina e fotografa cada etapa.
 *
 * Uso: node scripts/capturar-pwa.mjs <pasta-de-saida> [--emulador]
 */
import { spawn } from 'node:child_process';
import { writeFileSync, mkdirSync } from 'node:fs';

const SAIDA = process.argv[2] ?? 'docs/telas';
const LOCAL = process.argv.includes('--emulador');
const SITE = LOCAL ? 'http://127.0.0.1:5055' : 'https://que-jogador-e-esse.web.app';
const BANCO = LOCAL
  ? 'http://127.0.0.1:9000/salas/%s.json?ns=que-jogador-e-esse-default-rtdb'
  : 'https://que-jogador-e-esse-default-rtdb.firebaseio.com/salas/%s.json';
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PORTA = 9333;
const SALA = 'PRNT';

mkdirSync(SAIDA, { recursive: true });
const noBanco = (sufixo = '') => BANCO.replace('%s', SALA).replace('.json', `${sufixo}.json`);

/** Fala com o Chrome pelo DevTools Protocol; o Node 22 ja traz WebSocket nativo. */
class Navegador {
  #ws; #id = 0; #pendentes = new Map();

  async abrir() {
    this.processo = spawn(CHROME, [
      '--headless', '--disable-gpu', '--hide-scrollbars',
      `--remote-debugging-port=${PORTA}`, '--user-data-dir=/tmp/qjee-chrome',
      '--window-size=390,844', 'about:blank',
    ], { stdio: 'ignore' });

    // O Chrome demora um instante para abrir a porta de depuracao.
    for (let i = 0; i < 40; i++) {
      try {
        const alvos = await (await fetch(`http://127.0.0.1:${PORTA}/json/list`)).json();
        const pagina = alvos.find((a) => a.type === 'page');
        if (pagina?.webSocketDebuggerUrl) {
          this.#ws = new WebSocket(pagina.webSocketDebuggerUrl);
          await new Promise((ok) => { this.#ws.onopen = ok; });
          this.#ws.onmessage = (e) => {
            const m = JSON.parse(e.data);
            const p = this.#pendentes.get(m.id);
            if (p) { this.#pendentes.delete(m.id); p(m.result); }
          };
          return;
        }
      } catch { /* ainda subindo */ }
      await new Promise((r) => setTimeout(r, 250));
    }
    throw new Error('o Chrome nao abriu a porta de depuracao');
  }

  cmd(method, params = {}) {
    const id = ++this.#id;
    this.#ws.send(JSON.stringify({ id, method, params }));
    return new Promise((ok) => this.#pendentes.set(id, ok));
  }

  async ir(url) {
    await this.cmd('Page.navigate', { url });
    await new Promise((r) => setTimeout(r, 2500));
  }

  async js(expressao) {
    const r = await this.cmd('Runtime.evaluate', { expression: expressao, awaitPromise: true, returnByValue: true });
    return r?.result?.value;
  }

  async foto(arquivo) {
    const r = await this.cmd('Page.captureScreenshot', { format: 'png' });
    writeFileSync(`${SAIDA}/${arquivo}`, Buffer.from(r.data, 'base64'));
    console.log(`  ${arquivo}`);
  }

  fechar() { this.processo.kill(); }
}

const nav = new Navegador();
await nav.abrir();
await nav.cmd('Page.enable');
await nav.cmd('Runtime.enable');
// Emula um celular: sem isso o Chrome renderiza como desktop estreito, e o layout muda.
await nav.cmd('Emulation.setDeviceMetricsOverride', {
  width: 390, height: 844, deviceScaleFactor: 3, mobile: true,
});

// Sala de vitrine, criada e apagada por este script.
await fetch(noBanco(), { method: 'PUT', body: JSON.stringify({
  estado: 'aguardando', criado_em: Date.now(), pista_atual_index: 0, rodada_numero: 0 }) });
for (const [id, nome, t] of [['j-a', 'Marina', 1], ['j-b', 'Tio Beto', 2], ['j-c', 'Vovó Lúcia', 3]]) {
  await fetch(noBanco(`/jogadores/${id}`), { method: 'PUT', body: JSON.stringify({
    apelido: nome, pontos: 0, conectado_em: 1757000000000 + t * 1000, ativo: true }) });
}

await nav.ir(`${SITE}/?sala=${SALA}`);
await nav.js(`localStorage.clear()`);
await nav.ir(`${SITE}/?sala=${SALA}`);
await nav.foto('celular-01-entrada.png');

// Erro de codigo invalido (canvas 1i)
await nav.js(`document.getElementById('campo-codigo').value='4K7X';
  document.getElementById('campo-apelido').value='Duda';
  document.getElementById('form-entrada').dispatchEvent(new Event('submit',{cancelable:true,bubbles:true}));`);
await new Promise((r) => setTimeout(r, 2000));
await nav.foto('celular-02-codigo-invalido.png');

// Entrada de verdade
await nav.js(`document.getElementById('campo-codigo').value='${SALA}';
  document.getElementById('form-entrada').dispatchEvent(new Event('submit',{cancelable:true,bubbles:true}));`);
await new Promise((r) => setTimeout(r, 3000));
await nav.foto('celular-03-espera.png');

const meuId = await nav.js(`JSON.parse(localStorage.getItem('quejogador.sessao')).jogadorId`);
await fetch(noBanco(`/jogadores/${meuId}/pontos`), { method: 'PUT', body: '160' });

// Rodada ativa: botao liberado
await fetch(noBanco(), { method: 'PATCH', body: JSON.stringify({
  estado: 'rodada_ativa', jogador_futebol_atual_id: 'neymar', pista_atual_index: 1, rodada_numero: 3 }) });
await new Promise((r) => setTimeout(r, 2500));
await nav.foto('celular-04-botao-ativo.png');

// Outro convidado compra primeiro: botao bloqueado
await fetch(noBanco('/buzz_atual'), { method: 'PUT', body: JSON.stringify({
  jogador_sala_id: 'j-a', timestamp: Date.now() }) });
await new Promise((r) => setTimeout(r, 2500));
await nav.foto('celular-05-bloqueado.png');

// Fim de jogo
await fetch(noBanco('/estado'), { method: 'PUT', body: '"encerrada"' });
await new Promise((r) => setTimeout(r, 2500));
await nav.foto('celular-06-fim-de-jogo.png');

await fetch(noBanco(), { method: 'DELETE' });
nav.fechar();
console.log(`\ntelas do celular em ${SAIDA}`);
