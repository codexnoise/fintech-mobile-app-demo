/*
 * Viaja Seguro — micro-app de un "equipo independiente" integrada en Nexo.
 *
 * Contrato del bridge (v1), mensajes JSON:
 *   micro-app -> app : { v:1, type:'ready' }
 *   app -> micro-app : window.nexo.receive({ v:1, type:'context', nonce, token, apiBase })
 *   micro-app -> app : { v:1, type:'quote_accepted', nonce, payload:{...} }
 *   micro-app -> app : { v:1, type:'close', nonce }
 *
 * Seguridad:
 * - Nunca recibe el token de sesión del banco: solo un token de contexto de
 *   5 min con claims mínimos, que valida contra el BFF (introspección).
 * - Todo mensaje hacia la app lleva el nonce entregado por la app.
 * - CSP estricta (sin scripts inline, connect-src acotado) definida en Hosting.
 */
(function () {
  'use strict';

  const PRICES = { south_america: 150, north_america: 290, europe: 260, world: 340 }; // centavos por día/viajero (básico)
  const PLAN_MULTIPLIER = { basic: 1, plus: 1.8 };

  const state = { nonce: null, segment: null, firstName: null };
  const $ = (id) => document.getElementById(id);

  function post(message) {
    const payload = JSON.stringify(Object.assign({ v: 1, nonce: state.nonce }, message));
    if (window.NexoBridge && typeof window.NexoBridge.postMessage === 'function') {
      window.NexoBridge.postMessage(payload);
    } else {
      console.info('[bridge:demo]', payload);
    }
  }

  function setStatus(text, tone) {
    const el = $('status');
    el.textContent = text;
    el.dataset.tone = tone || 'info';
    el.hidden = !text;
  }

  function quote() {
    const destination = $('destination').value;
    const days = clamp(parseInt($('days').value, 10) || 1, 1, 60);
    const travelers = clamp(parseInt($('travelers').value, 10) || 1, 1, 6);
    const plan = document.querySelector('input[name="plan"]:checked').value;
    let cents = Math.round(PRICES[destination] * days * travelers * PLAN_MULTIPLIER[plan]);
    const premium = state.segment === 'premium';
    if (premium) cents = Math.round(cents * 0.9); // personalización por segmento
    $('price').textContent = formatUsd(cents);
    $('discount').hidden = !premium;
    return { destination, days, travelers, plan, priceCents: cents, discountApplied: premium };
  }

  function clamp(n, min, max) {
    return Math.min(max, Math.max(min, n));
  }

  function formatUsd(cents) {
    const major = Math.floor(cents / 100).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return '$' + major + '.' + String(cents % 100).padStart(2, '0');
  }

  async function onContext(message) {
    if (!message || message.v !== 1 || message.type !== 'context' || !message.nonce) return;
    state.nonce = message.nonce;
    setStatus('Validando tu sesión con Nexo…');
    try {
      const res = await fetch(message.apiBase.replace(/\/$/, '') + '/micro-apps/introspect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: message.token, appId: 'travel_insurance' }),
      });
      const body = await res.json();
      if (!res.ok || !body.active) throw new Error('inactive');
      state.firstName = body.firstName;
      state.segment = body.segment;
      $('greeting').textContent = 'Hola, ' + body.firstName + '. Tus datos no salen de Nexo: solo recibimos tu nombre.';
      setStatus('');
      $('quote-form').hidden = false;
      quote();
    } catch (e) {
      setStatus('No pudimos validar tu sesión. Vuelve a abrir el cotizador desde Nexo.', 'error');
      post({ type: 'error', payload: { code: 'context_invalid' } });
    }
  }

  window.nexo = Object.freeze({ receive: onContext });

  ['destination', 'days', 'travelers'].forEach((id) => $(id).addEventListener('input', quote));
  document.querySelectorAll('input[name="plan"]').forEach((el) => el.addEventListener('change', quote));

  $('quote-form').addEventListener('submit', (event) => {
    event.preventDefault();
    const q = quote();
    const quoteId = 'q_' + Date.now().toString(36);
    $('accept').disabled = true;
    setStatus('¡Listo! Tu seguro ' + (q.plan === 'plus' ? 'Plus' : 'Básico') + ' quedó reservado.', 'success');
    post({ type: 'quote_accepted', payload: Object.assign({ quoteId: quoteId }, q) });
  });

  $('close').addEventListener('click', () => post({ type: 'close' }));

  // Fuera de la app (navegador): modo demostración.
  if (!window.NexoBridge) {
    setTimeout(() => {
      if (!state.nonce) {
        setStatus('Modo demostración: abre esta experiencia desde la app Nexo para usar tu sesión.', 'info');
        $('quote-form').hidden = false;
        quote();
      }
    }, 1200);
  }

  post({ type: 'ready' });
})();
