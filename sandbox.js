/* Sandbox de JavaScript isolado para o J.A.R.V.I.S.
 * Executa em Web Worker dentro de iframe sandbox sem same-origin.
 * Sem Node, arquivos, rede, armazenamento ou acesso ao DOM do aplicativo.
 */
(function (raiz, fabrica) {
  var api = fabrica(raiz);
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.JarvisSandbox = api;
})(typeof window !== 'undefined' ? window : null, function (raiz) {
  'use strict';

  var MAX_CODIGO = 20000;
  var MAX_ENTRADA = 10000;
  var MAX_SAIDA = 16000;

  function validar(codigo, entrada, timeoutMs) {
    var code = String(codigo == null ? '' : codigo);
    if (!code.trim()) return { ok: false, erro: 'Informe o código JavaScript.' };
    if (code.length > MAX_CODIGO) return { ok: false, erro: 'O código ultrapassa 20.000 caracteres.' };
    var input;
    try {
      input = typeof entrada === 'string' ? JSON.parse(entrada || 'null') : (entrada == null ? null : entrada);
    } catch (e) {
      input = String(entrada).slice(0, MAX_ENTRADA);
    }
    var inputText;
    try { inputText = JSON.stringify(input); }
    catch (e) { return { ok: false, erro: 'A entrada precisa ser serializável em JSON.' }; }
    if (inputText && inputText.length > MAX_ENTRADA) return { ok: false, erro: 'A entrada ultrapassa 10.000 caracteres.' };
    var timeout = Math.max(500, Math.min(10000, Math.round(Number(timeoutMs) || 3000)));
    return { ok: true, codigo: code, entrada: input, timeoutMs: timeout };
  }

  function executar(codigo, entrada, timeoutMs) {
    var dados = validar(codigo, entrada, timeoutMs);
    if (!dados.ok) return Promise.resolve(dados);
    if (!raiz || !raiz.document || !raiz.document.createElement) {
      return Promise.resolve({ ok: false, erro: 'O sandbox precisa ser executado dentro do aplicativo.' });
    }
    return new Promise(function (resolve) {
      var doc = raiz.document;
      var iframe = doc.createElement('iframe');
      var token = 'jv-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
      var encerrado = false;
      var inicio = Date.now();
      var timer = null;

      function finalizar(resultado) {
        if (encerrado) return;
        encerrado = true;
        if (timer) clearTimeout(timer);
        raiz.removeEventListener('message', receber);
        try {
          if (iframe.contentWindow) iframe.contentWindow.postMessage({ kind: 'cancel', token: token }, '*');
        } catch (e) { /* frame pode já ter sido destruído */ }
        if (iframe.parentNode) iframe.parentNode.removeChild(iframe);
        resultado = resultado || { ok: false, erro: 'O sandbox foi encerrado sem resultado.' };
        resultado.ms = Date.now() - inicio;
        resolve(resultado);
      }

      function receber(evento) {
        if (evento.source !== iframe.contentWindow) return;
        var r = evento.data || {};
        if (r.kind !== 'jarvis-result' || r.token !== token) return;
        finalizar({
          ok: r.ok === true,
          saida: String(r.saida || '').slice(0, MAX_SAIDA),
          logs: Array.isArray(r.logs) ? r.logs.slice(0, 100) : [],
          erro: r.ok === true ? '' : String(r.erro || 'Falha no código executado.')
        });
      }

      iframe.setAttribute('sandbox', 'allow-scripts');
      iframe.setAttribute('aria-hidden', 'true');
      iframe.setAttribute('tabindex', '-1');
      iframe.referrerPolicy = 'no-referrer';
      iframe.style.cssText = 'position:fixed;left:-10000px;top:0;width:1px;height:1px;border:0;opacity:0;pointer-events:none;';
      var linhas = [
        '<!doctype html><meta charset="utf-8">',
        '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; script-src \'unsafe-inline\' \'unsafe-eval\' blob:; worker-src blob:; connect-src \'none\'; img-src \'none\'; media-src \'none\'; object-src \'none\'; frame-src \'none\'; form-action \'none\'; base-uri \'none\'; navigate-to \'none\';">',
        '<script>',
        '(function(){',
        'var worker=null, blobUrl="";',
        'function enviar(d){ parent.postMessage(d,"*"); }',
        'window.addEventListener("message",function(ev){',
        'if(ev.source!==parent) return;',
        'var d=ev.data||{};',
        'if(d.kind==="cancel"){ if(worker){worker.terminate();worker=null;} if(blobUrl){URL.revokeObjectURL(blobUrl);blobUrl="";} return; }',
        'if(d.kind!=="jarvis-run" || worker) return;',
        'var source=[',
        '"self.onmessage = async function(e) {",',
        '"  var token=e.data.token, send=self.postMessage.bind(self), logs=[];",',
        '"  var safeConsole={log:function(){logs.push(Array.prototype.map.call(arguments,String).join(\\" \\"));},info:function(){logs.push(Array.prototype.map.call(arguments,String).join(\\" \\"));},warn:function(){logs.push(Array.prototype.map.call(arguments,String).join(\\" \\"));},error:function(){logs.push(Array.prototype.map.call(arguments,String).join(\\" \\"));}};",',
        '"  try {",',
        '"    self.fetch=undefined; self.XMLHttpRequest=undefined; self.WebSocket=undefined; self.EventSource=undefined; self.importScripts=undefined; self.Worker=undefined; self.SharedWorker=undefined; self.indexedDB=undefined; self.caches=undefined; self.close=undefined; self.postMessage=function(){throw new Error(\\"postMessage externo bloqueado\\");}; self.console=safeConsole;",',
        '"    try { if(self.navigator && self.navigator.sendBeacon) Object.defineProperty(self.navigator,\\"sendBeacon\\",{value:undefined}); } catch(ignore) {}",',
        '"    var AsyncFunction=Object.getPrototypeOf(async function(){}).constructor;",',
        '"    var run=new AsyncFunction(\"input\",\"console\",String(e.data.code||\"\"));",',
        '"    var value=await run(e.data.input,safeConsole);",',
        '"    var output=value===undefined ? \\"undefined\\" : (typeof value===\\"string\\" ? value : JSON.stringify(value,null,2));",',
        '"    if(output===undefined) output=String(value);",',
        '"    send({__jarvis_result:true,token:token,ok:true,saida:String(output).slice(0,16000),logs:logs.slice(0,100).map(function(x){return String(x).slice(0,500);})});",',
        '"  } catch(err) { send({__jarvis_result:true,token:token,ok:false,erro:String(err && err.message || err).slice(0,1200),logs:logs.slice(0,100)}); }",',
        '"};"',
        '].join("\\n");',
        'var blob=new Blob([source],{type:"application/javascript"}); blobUrl=URL.createObjectURL(blob);',
        'try { worker=new Worker(blobUrl); } catch(err) { enviar({kind:"jarvis-result",token:d.token,ok:false,erro:"O navegador bloqueou a criação do Worker isolado: "+String(err.message||err)}); return; }',
        'worker.onmessage=function(ev){var r=ev.data||{};if(!r.__jarvis_result||r.token!==d.token)return;worker.terminate();worker=null;if(blobUrl){URL.revokeObjectURL(blobUrl);blobUrl="";}enviar({kind:"jarvis-result",token:d.token,ok:r.ok,saida:r.saida||"",erro:r.erro||"",logs:r.logs||[]});};',
        'worker.onerror=function(ev){if(worker){worker.terminate();worker=null;}if(blobUrl){URL.revokeObjectURL(blobUrl);blobUrl="";}enviar({kind:"jarvis-result",token:d.token,ok:false,erro:"Erro no Worker: "+String(ev.message||"falha de execução")});};',
        'worker.postMessage({token:d.token,code:d.codigo,input:d.entrada});',
        '});',
        '})();',
        '<\/script>'
      ];
      iframe.srcdoc = linhas.join('');
      raiz.addEventListener('message', receber);
      iframe.onload = function () {
        try {
          iframe.contentWindow.postMessage({
            kind: 'jarvis-run', token: token, codigo: dados.codigo, entrada: dados.entrada
          }, '*');
        } catch (e) { finalizar({ ok: false, erro: 'Não consegui iniciar o Worker isolado: ' + String(e.message || e) }); }
      };
      iframe.onerror = function () { finalizar({ ok: false, erro: 'O navegador não conseguiu abrir o frame isolado.' }); };
      timer = setTimeout(function () {
        finalizar({ ok: false, erro: 'Tempo limite de ' + dados.timeoutMs + ' ms excedido. O Worker foi encerrado.' });
      }, dados.timeoutMs);
      (doc.body || doc.documentElement).appendChild(iframe);
    });
  }

  function iniciar() {
    if (!raiz || !raiz.document) return;
    var botao = raiz.document.getElementById('sandbox-executar');
    if (!botao || botao.dataset.jarvisLigado === '1') return;
    botao.dataset.jarvisLigado = '1';
    botao.addEventListener('click', async function () {
      var codigo = raiz.document.getElementById('sandbox-codigo');
      var entrada = raiz.document.getElementById('sandbox-entrada');
      var status = raiz.document.getElementById('sandbox-status');
      var saida = raiz.document.getElementById('sandbox-saida');
      if (!codigo || !status || !saida) return;
      if (!raiz.confirm('Executar este JavaScript em um Worker isolado? O código não terá acesso a arquivos, rede ou funções do aparelho.')) return;
      botao.disabled = true;
      status.textContent = 'Executando em ambiente isolado…';
      saida.textContent = '';
      try {
        var r = await executar(codigo.value, entrada ? entrada.value : '', 3000);
        status.textContent = r.ok ? 'Concluído em ' + r.ms + ' ms.' : 'Execução bloqueada ou falhou em ' + r.ms + ' ms.';
        saida.textContent = (r.logs && r.logs.length ? 'Console:\n' + r.logs.join('\n') + '\n\n' : '') +
          (r.ok ? 'Resultado:\n' + (r.saida || 'undefined') : 'Erro:\n' + (r.erro || 'Falha desconhecida.'));
      } catch (e) {
        status.textContent = 'Falha ao iniciar o sandbox.';
        saida.textContent = String(e && e.message || e);
      } finally { botao.disabled = false; }
    });
  }

  if (raiz && raiz.document) {
    if (raiz.document.readyState === 'loading') raiz.document.addEventListener('DOMContentLoaded', iniciar);
    else iniciar();
  }
  return { validar: validar, executar: executar, iniciar: iniciar, limites: { codigo: MAX_CODIGO, entrada: MAX_ENTRADA, saida: MAX_SAIDA } };
});
