// Worker que entrega las sugerencias y reportes de error de Milantus a la
// casilla del proyecto.
//
// Existe por una sola razón: Cloudflare solo deja enviar correo gratis desde
// un Worker, y solo a direcciones verificadas en Email Routing. El
// destinatario es siempre esa casilla (el tester va en «Responder a»), así que
// entra justo en lo gratuito. Lo demás —quién escribe, el tope por cuenta, el
// armado del texto— lo resuelve el servidor de Milantus antes de llamar acá.
//
// Sin dependencias: el MIME (`mime.js`) se arma a mano con lo mínimo que un cliente de
// correo necesita para mostrar texto plano en UTF-8.
import { EmailMessage } from 'cloudflare:email';
import { buildMime } from './mime.js';

const MAX_TEXT_CHARS = 20000;

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'Método no permitido.' }, 405);
    }
    // El secreto compartido es lo único que separa este Worker de un relé
    // de spam hacia la casilla del proyecto.
    const auth = request.headers.get('authorization') ?? '';
    if (!env.FEEDBACK_SECRET || auth !== `Bearer ${env.FEEDBACK_SECRET}`) {
      return json({ error: 'No autorizado.' }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'Se esperaba JSON.' }, 400);
    }
    const { subject, text, replyTo } = body ?? {};
    if (typeof subject !== 'string' || typeof text !== 'string' || !text) {
      return json({ error: 'Faltan "subject" o "text".' }, 400);
    }
    if (text.length > MAX_TEXT_CHARS) {
      return json({ error: 'El mensaje es demasiado largo.' }, 413);
    }

    const raw = buildMime({
      from: env.FEEDBACK_FROM,
      to: env.FEEDBACK_TO,
      subject,
      text,
      replyTo: typeof replyTo === 'string' ? replyTo : undefined,
    });
    try {
      await env.EMAIL.send(new EmailMessage(env.FEEDBACK_FROM, env.FEEDBACK_TO, raw));
    } catch (error) {
      // El motivo (destino sin verificar, remitente fuera del dominio) queda
      // en los logs del Worker y en la respuesta al servidor, que lo loguea.
      return json({ error: `No se pudo enviar: ${error.message}` }, 502);
    }
    return json({ ok: true });
  },
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

