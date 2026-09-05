/**
 * Converte o arquivo bruto `content/raw/jogadores.rtf` (saida do pipeline n8n da secao 27,
 * salva como RTF pelo TextEdit) de volta para JSON puro.
 *
 * Nao aplica nenhuma regra de negocio da secao 11 — e apenas desempacotamento de formato.
 * A normalizacao para o schema de `jogadores_futebol/` (secao 7) acontece em build-seed.mjs.
 */
import { readFileSync } from 'node:fs';

const CP1252_EXTRA = {
  0x80: '€', 0x82: '‚', 0x83: 'ƒ', 0x84: '„', 0x85: '…',
  0x86: '†', 0x87: '‡', 0x88: 'ˆ', 0x89: '‰', 0x8a: 'Š',
  0x8b: '‹', 0x8c: 'Œ', 0x8e: 'Ž', 0x91: '‘', 0x92: '’',
  0x93: '“', 0x94: '”', 0x95: '•', 0x96: '–', 0x97: '—',
  0x98: '˜', 0x99: '™', 0x9a: 'š', 0x9b: '›', 0x9c: 'œ',
  0x9e: 'ž', 0x9f: 'Ÿ',
};

/** Traduz um byte cp1252 (notacao \'hh do RTF) para o caractere Unicode correspondente. */
function cp1252(byte) {
  return CP1252_EXTRA[byte] ?? String.fromCharCode(byte);
}

/** Remove a marcacao RTF e devolve apenas o texto util (o JSON original). */
export function rtfToText(rtf) {
  let out = '';
  let i = 0;
  let depth = 0;
  while (i < rtf.length) {
    const ch = rtf[i];
    if (ch === '\\') {
      const next = rtf[i + 1];
      if (next === "'") {
        out += cp1252(parseInt(rtf.slice(i + 2, i + 4), 16));
        i += 4;
        continue;
      }
      if (next === '\\' || next === '{' || next === '}') {
        out += next;
        i += 2;
        continue;
      }
      if (next === '\n' || next === '\r') { out += '\n'; i += 2; continue; }
      // palavra de controle: \word[-]?[0-9]* seguida de um espaco opcional
      const m = /^\\([a-zA-Z]+)(-?\d+)? ?/.exec(rtf.slice(i));
      if (m) {
        if (m[1] === 'par' || m[1] === 'line') out += '\n';
        i += m[0].length;
        continue;
      }
      i += 2;
      continue;
    }
    if (ch === '{') { depth++; i++; continue; }
    if (ch === '}') { depth--; i++; continue; }
    out += ch;
    i++;
  }
  return out;
}

/** Extrai o primeiro array JSON completo encontrado no texto. */
export function extractJsonArray(text) {
  const start = text.indexOf('[');
  if (start < 0) throw new Error('Nenhum array JSON encontrado no arquivo bruto.');
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (inString) {
      if (escaped) escaped = false;
      else if (c === '\\') escaped = true;
      else if (c === '"') inString = false;
      continue;
    }
    if (c === '"') inString = true;
    else if (c === '[') depth++;
    else if (c === ']') {
      depth--;
      if (depth === 0) return JSON.parse(text.slice(start, i + 1));
    }
  }
  throw new Error('Array JSON incompleto no arquivo bruto.');
}

export function loadRaw(path = 'content/raw/jogadores.rtf') {
  return extractJsonArray(rtfToText(readFileSync(path, 'utf8')));
}

import { realpathSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

/** Detecta execucao direta pelo terminal (caminho com espacos/acentos exige comparar paths reais). */
function isMain() {
  try {
    return realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1]);
  } catch {
    return false;
  }
}

if (isMain()) {
  const data = loadRaw(process.argv[2]);
  process.stdout.write(JSON.stringify(data, null, 2));
}
