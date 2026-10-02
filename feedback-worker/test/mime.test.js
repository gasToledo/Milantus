// `npm test` (o `node --test test/mime.test.js`) — sin dependencias. Solo el armado del
// MIME: el envío depende del binding de Cloudflare y se prueba desplegado.
import { test } from 'node:test';
import assert from 'node:assert/strict';

// `mime.js` y no `index.js`: `cloudflare:email` no existe fuera de Workers.
import { buildMime } from '../src/mime.js';

const decode = (b64) => new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)));

test('arma cabeceras y cuerpo legibles con tildes', () => {
  const raw = buildMime({
    from: 'feedback@milantus.com.ar',
    to: 'casilla@example.org',
    subject: '[Milantus] Error · Ada',
    text: 'La ficha no guardó.\n\nVersión: 0.20.0',
    replyTo: 'ada@example.org',
    now: new Date('2026-10-02T12:00:00Z'),
    id: 'abc',
  });
  const [head, body] = raw.split('\r\n\r\n');

  assert.match(head, /^From: feedback@milantus\.com\.ar\r\n/);
  assert.match(head, /\r\nTo: casilla@example\.org\r\n/);
  assert.match(head, /\r\nReply-To: ada@example\.org\r\n/);
  assert.match(head, /\r\nMessage-ID: <abc@milantus\.com\.ar>\r\n/);
  const subject = head.match(/Subject: =\?UTF-8\?B\?(.+)\?=/)[1];
  assert.equal(decode(subject), '[Milantus] Error · Ada');
  assert.equal(decode(body.replace(/\r\n/g, '')), 'La ficha no guardó.\n\nVersión: 0.20.0');
});

test('un salto de línea no puede agregar cabeceras', () => {
  const raw = buildMime({
    from: 'feedback@milantus.com.ar',
    to: 'casilla@example.org',
    subject: 'x',
    text: 'y',
    replyTo: 'ada@example.org\r\nBcc: otro@example.org',
  });
  const head = raw.split('\r\n\r\n')[0];

  assert.doesNotMatch(head, /\r\nBcc:/);
});

test('sin responder-a no hay cabecera vacía', () => {
  const raw = buildMime({ from: 'a@b.c', to: 'd@e.f', subject: 's', text: 't' });

  assert.doesNotMatch(raw, /Reply-To/);
});
