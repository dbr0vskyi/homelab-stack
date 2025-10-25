// Preload patch for n8n: relax inbound server timeouts AND outbound fetch (undici) timeouts.
(function () {
  const toNum = (v, d) => {
    const n = Number(v);
    return Number.isFinite(n) ? n : d;
  };

  // Inbound: Node HTTP(S) server timeouts (affects browser -> n8n)
  const inboundRequestTimeout = toNum(process.env.N8N_HTTP_REQUEST_TIMEOUT, 0); // 0 = disable per-request timeout
  const inboundHeadersTimeout = toNum(
    process.env.N8N_HTTP_HEADERS_TIMEOUT,
    120_000
  ); // must be > keepAlive
  const inboundKeepAliveTimeout = toNum(
    process.env.N8N_HTTP_KEEPALIVE_TIMEOUT,
    65_000
  );

  function patchServer(modName) {
    try {
      const mod = require(modName);
      if (!mod || typeof mod.createServer !== "function") return;
      const orig = mod.createServer;
      mod.createServer = function patchedCreateServer(...args) {
        const srv = orig.apply(this, args);
        try {
          // requestTimeout: time after which the socket is destroyed (Node 18+)
          srv.requestTimeout = inboundRequestTimeout;
          // Ensure headersTimeout > keepAliveTimeout by at least 1000ms
          srv.keepAliveTimeout = inboundKeepAliveTimeout;
          srv.headersTimeout = Math.max(
            inboundHeadersTimeout,
            inboundKeepAliveTimeout + 1000
          );
          console.log(
            `[patch] ${modName} server timeouts: request=${srv.requestTimeout}ms, headers=${srv.headersTimeout}ms, keepAlive=${srv.keepAliveTimeout}ms`
          );
        } catch (e) {
          console.warn(
            "[patch] failed to set server timeouts on",
            modName,
            e?.message || e
          );
        }
        return srv;
      };
    } catch (e) {
      console.warn("[patch] failed to patch module", modName, e?.message || e);
    }
  }

  patchServer("http");
  patchServer("https");

  // Patch axios if available (used by LangChain components)
  try {
    const axios = require('axios');
    if (axios && axios.defaults) {
      axios.defaults.timeout = toNum(process.env.FETCH_BODY_TIMEOUT, 12000000);
      console.log(`[patch] axios timeout set to ${axios.defaults.timeout}ms`);
    }
  } catch (e) {
    console.log('[patch] axios not available, skipping');
  }

  // Patch global fetch timeout (for LangChain Ollama nodes)
  if (typeof globalThis.fetch !== 'undefined') {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = function (url, options = {}) {
      // Disable or extend signal timeout for Ollama requests
      if (url && typeof url === 'string' && url.includes('ollama')) {
        console.log('[patch] Extending timeout for Ollama fetch request');
        // Remove any existing timeout signal
        delete options.signal;

        // Create a new AbortSignal with extended timeout
        const controller = new AbortController();
        const timeoutId = setTimeout(
          () => controller.abort(),
          toNum(process.env.FETCH_BODY_TIMEOUT, 12000000)
        );

        options.signal = controller.signal;

        return originalFetch.call(this, url, options).finally(() => {
          clearTimeout(timeoutId);
        });
      }
      return originalFetch.call(this, url, options);
    };
    console.log('[patch] Global fetch patched for Ollama requests');
  }

  // Outbound: undici (Node fetch) timeouts (affects n8n -> LLM/API)
  // If your model/API takes >headers timeout to send first byte, default undici will throw "Headers Timeout Error".
  try {
    const { Agent, setGlobalDispatcher } = require("undici");

    const headersTimeout = toNum(process.env.FETCH_HEADERS_TIMEOUT, 180_000); // default 3 min for first byte/headers
    const bodyTimeout = toNum(process.env.FETCH_BODY_TIMEOUT, 1_200_000); // default 20 min for full body/stream
    const connectTimeout = toNum(process.env.FETCH_CONNECT_TIMEOUT, 60_000); // 60s TCP/TLS connect
    const keepAliveTimeout = toNum(process.env.FETCH_KEEPALIVE_TIMEOUT, 65_000);

    const dispatcher = new Agent({
      headersTimeout,
      bodyTimeout,
      connectTimeout,
      keepAliveTimeout,
      // keepAliveMaxTimeout can be set if your Node/undici version supports it; keep defaults otherwise.
    });

    setGlobalDispatcher(dispatcher);

    console.log(
      `[patch] undici dispatcher set: headersTimeout=${headersTimeout}ms, bodyTimeout=${bodyTimeout}ms, connectTimeout=${connectTimeout}ms, keepAliveTimeout=${keepAliveTimeout}ms`
    );
  } catch (e) {
    console.warn(
      "[patch] undici not available or failed to set dispatcher",
      e?.message || e
    );
  }
})();
