/**
 * Configuracao de ambiente da PWA do convidado.
 *
 * A secao 18 do spec define FIREBASE_API_KEY e FIREBASE_DATABASE_URL como variaveis publicas —
 * a seguranca vem das regras do Realtime Database (secao 20), nao do sigilo destas chaves.
 * Verificado em producao: o Realtime Database sem autenticacao nao usa a apiKey, so o databaseURL.
 */

/**
 * Decide o ambiente pelo endereco de onde a pagina foi servida, em vez de exigir editar o arquivo
 * antes de cada deploy — que e o tipo de passo manual que um dia sobe quebrado para producao.
 * Servida de localhost ou de um IP da rede local (testar no celular de casa), fala com o emulador;
 * servida de qualquer outro lugar, fala com o Firebase real.
 */
function ehAmbienteLocal() {
  const host = location.hostname;
  return host === 'localhost'
    || host === '127.0.0.1'
    || /^192\.168\./.test(host)
    || /^10\./.test(host)
    || /^172\.(1[6-9]|2\d|3[01])\./.test(host);
}

export const config = {
  useEmulator: ehAmbienteLocal(),
  emulator: {
    host: `${location.hostname}:9000`,
    namespace: 'que-jogador-e-esse-default-rtdb',
  },
  firebase: {
    // Nao e usada pelo Realtime Database sem autenticacao; fica aqui para o dia em que houver Auth.
    apiKey: 'PREENCHER_SE_UM_DIA_HOUVER_AUTH',
    databaseURL: 'https://que-jogador-e-esse-default-rtdb.firebaseio.com',
    projectId: 'que-jogador-e-esse',
  },
};

/** URL do Realtime Database conforme o ambiente — emulador local ou projeto real. */
export function databaseURL() {
  return config.useEmulator
    ? `http://${config.emulator.host}?ns=${config.emulator.namespace}`
    : config.firebase.databaseURL;
}
