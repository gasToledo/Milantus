// El armado del correo, aparte de `index.js` para poder probarlo con
// `node --test` sin el runtime de Workers (`cloudflare:email` solo existe ahí).

// Un correo de texto plano. El asunto va en RFC 2047 y el cuerpo en base64
// porque los dos llevan tildes; sin eso, cada cliente adivina la codificación.
export function buildMime({ from, to, subject, text, replyTo, now = new Date(), id = crypto.randomUUID() }) {
  const domain = from.split('@')[1];
  const headers = [
    `From: ${from}`,
    `To: ${to}`,
    // Un salto de línea en una dirección o en el asunto agregaría
    // cabeceras: se aplanan antes de escribirlas.
    ...(replyTo ? [`Reply-To: ${oneLine(replyTo)}`] : []),
    `Subject: =?UTF-8?B?${base64(oneLine(subject))}?=`,
    `Date: ${now.toUTCString()}`,
    `Message-ID: <${id}@${domain}>`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
  ];
  const encoded = base64(text).replace(/.{1,76}/g, '$&\r\n');
  return `${headers.join('\r\n')}\r\n\r\n${encoded}`;
}

function oneLine(value) {
  return value.replace(/[\r\n]+/g, ' ');
}

function base64(value) {
  let binary = '';
  for (const byte of new TextEncoder().encode(value)) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}
