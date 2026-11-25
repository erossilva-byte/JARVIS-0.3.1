/* Status de um aparelho — celular ou PC — com a mesma formatação nos dois lados.
 *
 * Espelho de `flutter_app/lib/core/status_plataforma.dart`: o painel do PC e o
 * do celular usam esta peça em vez de cada um formatar memória e disco do seu
 * jeito. Regra de honestidade: campo ausente não vira zero — a linha some e
 * `semDados` avisa que aquele lado não respondeu.
 */
(() => {
  'use strict';

  function gigabytes(bytes) {
    const valor = Number(bytes) / 1024 / 1024 / 1024;
    if (!Number.isFinite(valor)) return '—';
    // Valor redondo sai sem decimal: “8 GB”, não “8,0 GB”.
    const texto = valor >= 100 || Number.isInteger(valor)
      ? String(Math.round(valor))
      : valor.toFixed(1).replace('.', ',');
    return texto + ' GB';
  }

  function memoria(total, livre) {
    const t = Number(total);
    if (!Number.isFinite(t) || t <= 0) return null;
    if (livre === null || livre === undefined || livre === '') {
      return gigabytes(t) + ' no total';
    }
    const l = Number(livre);
    if (!Number.isFinite(l)) return gigabytes(t) + ' no total';
    const usados = t - l;
    const percentual = Math.round(usados / t * 100);
    return gigabytes(usados) + ' de ' + gigabytes(t) + ' em uso (' + percentual + '%)';
  }

  function uptimeDeMinutos(minutos) {
    if (minutos < 60) return minutos + ' min';
    const horas = Math.floor(minutos / 60);
    if (horas < 24) return horas + ' h';
    const dias = Math.floor(horas / 24);
    const resto = horas % 24;
    return resto === 0 ? dias + ' dia(s)' : dias + ' dia(s) e ' + resto + ' h';
  }

  function numero(valor) {
    return Number.isInteger(valor)
      ? String(valor)
      : valor.toFixed(1).replace('.', ',');
  }

  function inteiro(valor) {
    if (valor === null || valor === undefined || valor === '') return null;
    const n = Number(valor);
    return Number.isFinite(n) ? Math.round(n) : null;
  }

  function texto(valor) {
    return typeof valor === 'string' ? valor.trim() : '';
  }

  function deMapa(dados, origem) {
    if (!dados || typeof dados !== 'object' || !Object.keys(dados).length) return null;
    const minutos = inteiro(dados.uptimeMin);
    const uptime = texto(dados.uptime) || (minutos === null ? '' : uptimeDeMinutos(minutos));
    const temperatura = Number.isFinite(Number(dados.temperatura))
      ? Number(dados.temperatura)
      : null;
    const status = {
      origem: origem === 'pc' ? 'pc' : 'celular',
      cpu: inteiro(dados.cpu),
      ramTotal: inteiro(dados.ramTotal),
      ramLivre: inteiro(dados.ramLivre),
      discoTotal: inteiro(dados.discoTotal),
      discoLivre: inteiro(dados.discoLivre),
      uptimeTexto: uptime,
      bateria: inteiro(dados.bateria),
      carregando: typeof dados.carregando === 'boolean' ? dados.carregando : null,
      temperatura: temperatura,
      sistema: texto(dados.sistema) || texto(dados.modelo) || texto(dados.aparelho),
      conexao: texto(dados.conexao)
    };
    status.titulo = status.origem === 'pc' ? 'Status do PC' : 'Status do celular';
    status.semDados = status.cpu === null && status.ramTotal === null &&
      status.discoTotal === null && !status.uptimeTexto && status.bateria === null &&
      !status.sistema && !status.conexao;
    status.linhas = [];
    const add = (rotulo, valor) => status.linhas.push({ rotulo: rotulo, valor: valor });
    if (status.cpu !== null) add('Processador', status.cpu + '% de uso');
    const ram = memoria(status.ramTotal, status.ramLivre);
    if (ram) add('Memória', ram);
    const disco = memoria(status.discoTotal, status.discoLivre);
    if (disco) add('Disco', disco);
    if (status.uptimeTexto) add('Ligado há', status.uptimeTexto);
    if (status.bateria !== null) {
      add('Bateria', status.bateria + '%' + (status.carregando === true ? ' (carregando)' : ''));
    }
    if (status.temperatura !== null) add('Temperatura', numero(status.temperatura) + ' °C');
    if (status.conexao) add('Rede', status.conexao);
    if (status.sistema) add('Sistema', status.sistema);
    return status;
  }

  window.StatusPlataforma = { deMapa: deMapa, gigabytes: gigabytes, memoria: memoria };
})();
