/* J.A.R.V.I.S. Nova — Fase 10: simulador de circuitos elétricos de comando e força.
 *
 * Roda no WebView do Android, no Electron e no Node (testes) sem dependência
 * nova. É um simulador LÓGICO: fase e retorno por grafo, bobinas com atraso,
 * temporizador TON, motor em partida/regime e verificação (ERC). Não é MNA:
 * não calcula tensão nem corrente em cada carga, e diz isso em vez de fingir.
 *
 * O que este módulo NÃO faz, e declara:
 *  - não abre o `.cad` do CADe SIMU (formato proprietário, sem especificação);
 *  - não simula cargas em série (avisa W-SERIE e não inventa divisão de tensão);
 *  - não modela intertravamento mecânico: fecha por corrida e avisa W-RACE;
 *  - não executa nem depende de WebView extra: é JavaScript do próprio app.
 */
(function (raiz, fabrica) {
  var api = fabrica();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (raiz) raiz.Circuito = api;
})(typeof window !== 'undefined' ? window : null, function () {
  'use strict';

  var SCHEMA = 1;
  var COMANDO = 'comando';
  var POTENCIA = 'potencia';
  var PINS3P = ['L1', 'L2', 'L3', 'T1', 'T2', 'T3'];
  var PINS_MOTOR = ['U', 'V', 'W'];
  var TIPOS2P = {
    pushbutton_no: 1, pushbutton_nc: 1, contact_no: 1, contact_nc: 1,
    contact_ton_no: 1, contact_ton_nc: 1, coil: 1, lamp: 1, timer_ton: 1,
    fuse: 1, fonte_comando: 1
  };
  var CHAVES = {
    fuse: 1, overload: 1, contactor_power: 1, pushbutton_no: 1, pushbutton_nc: 1,
    contact_no: 1, contact_nc: 1, contact_ton_no: 1, contact_ton_nc: 1
  };
  var CARGAS = { coil: 1, lamp: 1, timer_ton: 1 };
  var TIPOS = {
    coil: 1, lamp: 1, timer_ton: 1, fuse: 1, fonte_comando: 1, motor3p: 1,
    overload: 1, contactor_power: 1, pushbutton_no: 1, pushbutton_nc: 1,
    contact_no: 1, contact_nc: 1, contact_ton_no: 1, contact_ton_nc: 1
  };
  var ROTACOES = [0, 90, 180, 270];
  var MAX_EVENTOS = 200;
  var MAX_COMPONENTES = 5000;
  var MAX_FIOS = 20000;
  var DT = 10;
  var PICKUP = 15;
  var DROPOUT = 8;
  var PARTIDA_MS = 1500;

  // --- utilidades ----------------------------------------------------------

  function clonar(v) { return v == null ? v : JSON.parse(JSON.stringify(v)); }

  function ordenar(v) {
    if (v && v.constructor === Array) return v.map(ordenar);
    if (v && typeof v === 'object') {
      var saida = {};
      Object.keys(v).sort().forEach(function (k) { saida[k] = ordenar(v[k]); });
      return saida;
    }
    return v;
  }

  /** Impressão de conteúdo: FNV-1a em duas passadas (16 dígitos) + tamanho.
   *  Serve para detectar mudança no documento; NÃO é assinatura criptográfica. */
  function impressao(texto) {
    var s = String(texto);
    function fnv(semente) {
      var h = semente >>> 0;
      for (var i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
      }
      return ('0000000' + h.toString(16)).slice(-8);
    }
    return fnv(0x811c9dc5) + fnv(0x01000193) + '-' + s.length.toString(16);
  }

  function impressaoDocumento(doc) {
    var conteudo = {};
    ['schema', 'meta', 'sheets', 'plc'].forEach(function (k) {
      if (doc && doc[k] !== undefined) conteudo[k] = doc[k];
    });
    return impressao(JSON.stringify(ordenar(conteudo)));
  }

  function chavePino(p) {
    var n = parseInt(p, 10);
    return isNaN(n) ? 10000 + p.charCodeAt(0) : n;
  }

  // --- documento -----------------------------------------------------------

  /** Documento normalizado. A conectividade vem SEMPRE dos terminais;
   *  o campo `net` do fio é rótulo de desenho. */
  function Doc(mapa) {
    if (!mapa || typeof mapa !== 'object') throw new Error('documento ausente');
    var sheets = mapa.sheets;
    if (!sheets || !sheets.length) throw new Error('documento sem folha');
    var folha = sheets[0];
    this.dados = mapa;
    this.meta = mapa.meta || {};
    this.alim = folha.alimentacao || {};
    this.comps = {};
    this.ordem = [];
    this.wires = (folha.wires || []).slice();
    this.termPins = {};
    this._pai = {};
    var self = this;
    (folha.components || []).forEach(function (c) {
      if (!c || !c.id) return;
      self.comps[c.id] = c;
      self.ordem.push(c.id);
      self._pai[c.id + ':'] = c.id + ':';
    });
    this.wires.forEach(function (w) {
      var a = w.from, b = w.to;
      self.uniao(a, b);
      [a, b].forEach(function (t) {
        var partes = String(t).split(':');
        if (!self.termPins[partes[0]]) self.termPins[partes[0]] = {};
        self.termPins[partes[0]][partes[1]] = 1;
      });
    });
    this.pins = {};
    this.ordem.forEach(function (cid) { self.pins[cid] = self._ordemPinos(cid); });
  }

  Doc.prototype._raiz = function (x) {
    if (this._pai[x] === undefined) this._pai[x] = x;
    while (this._pai[x] !== x) {
      this._pai[x] = this._pai[this._pai[x]];
      x = this._pai[x];
    }
    return x;
  };
  Doc.prototype.uniao = function (a, b) {
    if (this._pai[a] === undefined) this._pai[a] = a;
    if (this._pai[b] === undefined) this._pai[b] = b;
    var ra = this._raiz(a), rb = this._raiz(b);
    if (ra !== rb) this._pai[rb] = ra;
  };
  Doc.prototype.net = function (terminal) {
    if (this._pai[terminal] === undefined) this._pai[terminal] = terminal;
    return this._raiz(terminal);
  };

  Doc.prototype._ordemPinos = function (cid) {
    var c = this.comps[cid];
    var tipo = c.type;
    var ligados = Object.keys(this.termPins[cid] || {})
      .sort(function (a, b) { return chavePino(a) - chavePino(b); });
    if (tipo === 'overload' || tipo === 'contactor_power') return PINS3P.slice();
    if (tipo === 'motor3p') return PINS_MOTOR.slice();
    if (tipo === 'fuse') {
      var tripolar = ligados.some(function (p) { return PINS3P.indexOf(p) >= 0; });
      return tripolar ? PINS3P.slice() : ['L', 'T'];
    }
    if (tipo === 'fonte_comando') return ['L', 'N'];
    if (tipo === 'coil') return ['A1', 'A2'];
    return ligados;
  };

  Doc.prototype.pares = function (cid) {
    var tipo = this.comps[cid].type;
    var p = this.pins[cid] || [];
    if (tipo === 'overload' || tipo === 'contactor_power' ||
        (tipo === 'fuse' && p.length === 6)) {
      return [['L1', 'T1'], ['L2', 'T2'], ['L3', 'T3']];
    }
    if (p.length < 2) return [];
    return [[p[0], p[1]]];
  };

  Doc.prototype.camada = function (cid) {
    return this.comps[cid].camada || COMANDO;
  };
  Doc.prototype.params = function (cid) { return this.comps[cid].params || {}; };
  Doc.prototype.porRef = function (ref, tipo) {
    var self = this;
    return this.ordem.filter(function (cid) {
      var c = self.comps[cid];
      return c.ref === ref && (!tipo || c.type === tipo);
    });
  };
  Doc.prototype.dono = function (cid) {
    var c = this.comps[cid];
    var pai = this.params(cid).pai;
    if (typeof pai === 'string' && this.comps[pai]) return pai;
    var achados = this.porRef(c.ref).filter(function (x) {
      return ['coil', 'overload', 'timer_ton'].indexOf(this.comps[x].type) >= 0;
    }, this);
    return achados.length ? achados[0] : null;
  };

  // --- simulação -----------------------------------------------------------

  function Sim(doc) {
    this.doc = doc;
    this.agora = 0;
    this.seq = 0;
    this.eventos = [];
    this.pressionado = {};
    this.bobina = {};
    this.tripped = {};
    this.timer = {};
    this.motor = {};
    var self = this;
    doc.ordem.forEach(function (cid) {
      var tipo = doc.comps[cid].type;
      if (tipo === 'pushbutton_no' || tipo === 'pushbutton_nc') self.pressionado[cid] = false;
      if (tipo === 'coil') self.bobina[cid] = { fechada: false, acc: 0 };
      if (tipo === 'overload') self.tripped[cid] = false;
      if (tipo === 'timer_ton') self.timer[cid] = { vencido: false, acc: 0 };
      if (tipo === 'motor3p') self.motor[cid] = { estado: 'PARADO', t: 0 };
    });
  }

  Sim.prototype.registrar = function (texto) {
    this.seq++;
    this.eventos.push({ tempo: this.agora, seq: this.seq, texto: texto });
  };

  Sim.prototype._atuado = function (cid) {
    if (!cid || !this.doc.comps[cid]) return false;
    var tipo = this.doc.comps[cid].type;
    if (tipo === 'coil') return !!(this.bobina[cid] && this.bobina[cid].fechada);
    if (tipo === 'overload') return !!this.tripped[cid];
    if (tipo === 'timer_ton') return !!(this.timer[cid] && this.timer[cid].vencido);
    return false;
  };

  Sim.prototype.fechado = function (cid) {
    var tipo = this.doc.comps[cid].type;
    if (tipo === 'fuse') return true;
    if (tipo === 'overload') return !this.tripped[cid];
    if (tipo === 'contactor_power') return this._atuado(this.doc.dono(cid));
    if (tipo === 'pushbutton_no') return !!this.pressionado[cid];
    if (tipo === 'pushbutton_nc') return !this.pressionado[cid];
    if (tipo === 'contact_no' || tipo === 'contact_nc' ||
        tipo === 'contact_ton_no' || tipo === 'contact_ton_nc') {
      var na = tipo === 'contact_no' || tipo === 'contact_ton_no';
      var at = this._atuado(this.doc.dono(cid));
      return na ? at : !at;
    }
    return false;
  };

  Sim.prototype._vizinhos = function (camada) {
    var adj = {};
    var self = this;
    this.doc.ordem.forEach(function (cid) {
      if (self.doc.camada(cid) !== camada) return;
      if (!CHAVES[self.doc.comps[cid].type]) return;
      if (!self.fechado(cid)) return;
      self.doc.pares(cid).forEach(function (par) {
        var a = self.doc.net(cid + ':' + par[0]);
        var b = self.doc.net(cid + ':' + par[1]);
        (adj[a] = adj[a] || {})[b] = 1;
        (adj[b] = adj[b] || {})[a] = 1;
      });
    });
    return adj;
  };

  Sim.prototype._bfs = function (inicio, adj) {
    var vistos = {};
    vistos[inicio] = 1;
    var fila = [inicio];
    while (fila.length) {
      var n = fila.pop();
      var viz = adj[n] || {};
      for (var m in viz) {
        if (!vistos[m]) { vistos[m] = 1; fila.push(m); }
      }
    }
    return vistos;
  };

  Sim.prototype.resolver = function () {
    var self = this;
    var adjC = this._vizinhos(COMANDO);
    var adjP = this._vizinhos(POTENCIA);
    var alimC = this.doc.alim.comando || {};
    if (!alimC.fase || !alimC.neutro) {
      throw new Error('alimentacao.comando ausente: fase e neutro obrigatórios');
    }
    var nFase = this.doc.net(alimC.fase);
    var nNeutro = this.doc.net(alimC.neutro);
    var vivo = this._bfs(nFase, adjC);
    var ret = this._bfs(nNeutro, adjC);
    var curto = {};
    for (var n in vivo) if (ret[n]) curto[n] = 1;
    if (nFase === nNeutro) curto[nFase] = 1;

    var cargas = this.doc.ordem.filter(function (cid) {
      return CARGAS[self.doc.comps[cid].type] && self.doc.camada(cid) === COMANDO;
    }).sort();

    var energ = {};
    cargas.forEach(function (cid) {
      var pins = self.doc.pins[cid] || [];
      if (pins.length < 2) { energ[cid] = false; return; }
      var a = self.doc.net(cid + ':' + pins[0]);
      var b = self.doc.net(cid + ':' + pins[1]);
      energ[cid] = (vivo[a] && ret[b]) || (vivo[b] && ret[a]);
    });

    var serie = [];
    cargas.forEach(function (cid) {
      var pins = self.doc.pins[cid] || [];
      if (pins.length < 2 || energ[cid]) return;
      var a = self.doc.net(cid + ':' + pins[0]);
      var b = self.doc.net(cid + ':' + pins[1]);
      [[a, b], [b, a]].forEach(function (par) {
        var ponta = par[0], outro = par[1];
        if (!vivo[ponta] || ret[outro]) return;
        var alcanca = self._bfs(outro, adjC);
        cargas.forEach(function (outra) {
          if (outra === cid) return;
          var op = self.doc.pins[outra] || [];
          if (op.length < 2) return;
          var oa = self.doc.net(outra + ':' + op[0]);
          var ob = self.doc.net(outra + ':' + op[1]);
          var fecha = (alcanca[oa] && ret[ob]) || (alcanca[ob] && ret[oa]);
          if (fecha) {
            if (serie.indexOf(cid) < 0) serie.push(cid);
            if (serie.indexOf(outra) < 0) serie.push(outra);
          }
        });
      });
    });

    var pot = this.doc.alim.potencia || {};
    var fases = pot.fases || [];
    var motores = {};
    this.doc.ordem.forEach(function (cid) {
      if (self.doc.comps[cid].type !== 'motor3p') return;
      var pins = self.doc.pins[cid] || [];
      var ok = fases.length === 3 && pins.length >= 3;
      if (ok) {
        for (var i = 0; i < 3; i++) {
          if (!self._bfs(self.doc.net(fases[i]), adjP)[self.doc.net(cid + ':' + pins[i])]) {
            ok = false;
            break;
          }
        }
      }
      motores[cid] = ok;
    });

    this.ultimo = {
      vivo: vivo, retorno: ret, curto: curto, energizado: energ, serie: serie,
      motores: motores, adjC: adjC
    };
    return this.ultimo;
  };

  Sim.prototype.passo = function (dt) {
    dt = dt || DT;
    var self = this;
    this.agora += dt;
    var r = this.resolver();
    var virou = false;
    var fechando = [];
    Object.keys(this.bobina).sort().forEach(function (cid) {
      var b = self.bobina[cid];
      var cmd = !!r.energizado[cid];
      var p = self.doc.params(cid);
      var pickup = typeof p.pickupMs === 'number' ? p.pickupMs : PICKUP;
      var dropout = typeof p.dropoutMs === 'number' ? p.dropoutMs : DROPOUT;
      var ref = self.doc.comps[cid].ref;
      if (cmd && !b.fechada) {
        b.acc += dt;
        if (b.acc >= pickup) {
          b.fechada = true; b.acc = 0; virou = true; fechando.push(cid);
          self.registrar(ref + ' pickup');
        }
      } else if (!cmd && b.fechada) {
        b.acc += dt;
        if (b.acc >= dropout) {
          b.fechada = false; b.acc = 0; virou = true;
          self.registrar(ref + ' dropout');
        }
      } else {
        b.acc = 0;
      }
    });
    fechando.forEach(function (a, i) {
      fechando.slice(i + 1).forEach(function (b) {
        if (self._temNcDe(a, b) && self._temNcDe(b, a)) {
          self.registrar('W-RACE: fechamento simultâneo por corrida; ' +
            'intertravamento mecânico não modelado');
        }
      });
    });
    if (virou) r = this.resolver();

    Object.keys(this.timer).sort().forEach(function (cid) {
      var t = self.timer[cid];
      var cmd = !!r.energizado[cid];
      var preset = typeof self.doc.params(cid).presetMs === 'number'
        ? self.doc.params(cid).presetMs : 500;
      var ref = self.doc.comps[cid].ref;
      if (cmd) {
        t.acc += dt;
        if (!t.vencido && t.acc >= preset) {
          t.vencido = true;
          self.registrar(ref + ' TON atingiu ' + preset + ' ms');
        }
      } else {
        if (t.vencido) self.registrar(ref + ' TON reset');
        t.acc = 0; t.vencido = false;
      }
    });

    Object.keys(this.motor).sort().forEach(function (cid) {
      var m = self.motor[cid];
      var on = !!r.motores[cid];
      var ref = self.doc.comps[cid].ref;
      if (on) {
        if (m.estado === 'PARADO') { m.estado = 'PARTINDO'; m.t = 0; self.registrar(ref + ' partindo'); }
        else if (m.estado === 'PARTINDO') {
          m.t += dt;
          if (m.t >= PARTIDA_MS) { m.estado = 'NOMINAL'; self.registrar(ref + ' nominal'); }
        }
      } else if (m.estado !== 'PARADO') {
        m.estado = 'PARADO'; m.t = 0;
        self.registrar(ref + ' parado');
      }
    });
    return r;
  };

  Sim.prototype._temNcDe = function (bobina, outra) {
    var self = this;
    return this.doc.ordem.some(function (cid) {
      return self.doc.comps[cid].type === 'contact_nc' && self.doc.dono(cid) === bobina;
    });
  };

  Sim.prototype.correnteMotor = function (cid) {
    var p = this.doc.params(cid);
    var inn = typeof p.in === 'number' ? p.in : 10;
    var ip = typeof p.ipIn === 'number' ? p.ipIn : 7;
    var e = this.motor[cid].estado;
    if (e === 'PARTINDO') return Math.round(inn * ip * 100) / 100;
    if (e === 'NOMINAL') return Math.round(inn * 100) / 100;
    return 0;
  };

  Sim.prototype.relogio = function (ms) {
    var alvo = this.agora + ms;
    while (this.agora < alvo) {
      this.passo(Math.min(DT, alvo - this.agora));
    }
  };

  Sim.prototype.acionar = function (cid, valor) {
    this.pressionado[cid] = !!valor;
    var ref = this.doc.comps[cid].ref;
    this.registrar(ref + (valor ? ' pressionado' : ' solto'));
  };

  // --- verificação (ERC) ---------------------------------------------------

  function erc(doc, sim) {
    var saida = [];
    function add(codigo, severidade, mensagem, componentes) {
      saida.push({
        codigo: codigo, severidade: severidade, mensagem: mensagem,
        componentes: componentes || []
      });
    }
    var r = sim.resolver();

    if (Object.keys(r.curto).length) {
      var comps = doc.ordem.filter(function (cid) {
        var ligados = doc.termPins[cid] || {};
        return Object.keys(ligados).some(function (p) {
          return r.curto[doc.net(cid + ':' + p)];
        });
      }).sort();
      add('E001', 'erro', 'Curto: caminho só com chaves entre fase e neutro.', comps);
    }

    var alimC = doc.alim.comando || {};
    var pot = doc.alim.potencia || {};
    var pontos = [alimC.fase, alimC.neutro].concat(pot.fases || []);
    var netsAlim = {};
    pontos.forEach(function (p) { if (p) netsAlim[doc.net(p)] = 1; });

    doc.ordem.slice().sort().forEach(function (cid) {
      var pins = doc.pins[cid] || [];
      var ligados = doc.termPins[cid] || {};
      var faltando = pins.filter(function (p) {
        return !ligados[p] && !netsAlim[doc.net(cid + ':' + p)];
      });
      if (TIPOS2P[doc.comps[cid].type] && Object.keys(ligados).length < 2 && !faltando.length) {
        faltando = ['(2 terminais, ' + Object.keys(ligados).length + ' ligado)'];
      }
      if (faltando.length) {
        add('E002', 'erro', doc.comps[cid].ref + ' (' + cid + ') com terminal solto: ' +
          faltando.join(', ') + '.', [cid]);
      }
    });

    var porRef = {};
    doc.ordem.forEach(function (cid) {
      if (doc.comps[cid].type !== 'coil') return;
      var ref = doc.comps[cid].ref;
      (porRef[ref] = porRef[ref] || []).push(cid);
    });
    Object.keys(porRef).sort().forEach(function (ref) {
      if (porRef[ref].length > 1) {
        add('E004', 'erro', 'Bobina ' + ref + ' duplicada (' + porRef[ref].length +
          ' componentes).', porRef[ref]);
      }
    });

    // E005a: retenção em paralelo com a parada
    var paresNf = {};
    doc.ordem.forEach(function (cid) {
      if (doc.comps[cid].type !== 'pushbutton_nc') return;
      var pins = doc.pins[cid] || [];
      if (pins.length < 2) return;
      var a = doc.net(cid + ':' + pins[0]);
      var b = doc.net(cid + ':' + pins[1]);
      paresNf[a + '|' + b] = cid;
      paresNf[b + '|' + a] = cid;
    });
    doc.ordem.slice().sort().forEach(function (cid) {
      if (doc.comps[cid].type !== 'contact_no') return;
      var dono = doc.dono(cid);
      if (!dono || doc.comps[dono].type !== 'coil') return;
      var pins = doc.pins[cid] || [];
      if (pins.length < 2) return;
      var chave = doc.net(cid + ':' + pins[0]) + '|' + doc.net(cid + ':' + pins[1]);
      var nf = paresNf[chave];
      if (nf) {
        add('E005', 'erro', 'Selo impossível: retenção de ' + doc.comps[cid].ref +
          ' em paralelo com a parada ' + doc.comps[nf].ref + '; o circuito não retém.',
          [cid, nf, dono]);
      }
    });

    // E005b: pior caso com a parada pressionada
    var pressAntes = clonar(sim.pressionado);
    var bobAntes = {};
    Object.keys(sim.bobina).forEach(function (k) { bobAntes[k] = sim.bobina[k].fechada; });
    doc.ordem.forEach(function (cid) {
      var tipo = doc.comps[cid].type;
      if (tipo === 'pushbutton_nc') sim.pressionado[cid] = true;
      if (tipo === 'pushbutton_no') sim.pressionado[cid] = false;
    });
    Object.keys(sim.bobina).forEach(function (k) { sim.bobina[k].fechada = true; });
    var r2 = sim.resolver();
    sim.pressionado = pressAntes;
    Object.keys(sim.bobina).forEach(function (k) { sim.bobina[k].fechada = !!bobAntes[k]; });
    Object.keys(sim.bobina).sort().forEach(function (cid) {
      if (r2.energizado[cid]) {
        add('E005', 'erro', 'Selo impossível: ' + doc.comps[cid].ref +
          ' permanece energizada com a parada pressionada.',
          [cid].concat(doc.porRef(doc.comps[cid].ref)));
      }
    });

    // E008: contatores que alimentam o mesmo barramento sem NF do outro
    var forcas = doc.ordem.filter(function (cid) {
      return doc.comps[cid].type === 'contactor_power';
    }).sort();
    for (var i = 0; i < forcas.length; i++) {
      for (var j = i + 1; j < forcas.length; j++) {
        var ca = forcas[i], cb = forcas[j];
        var da = doc.dono(ca), db = doc.dono(cb);
        if (!da || !db || da === db) continue;
        var sa = {}, sb = {};
        (doc.pins[ca] || []).forEach(function (p) {
          if (p.charAt(0) === 'T') sa[doc.net(ca + ':' + p)] = 1;
        });
        (doc.pins[cb] || []).forEach(function (p) {
          if (p.charAt(0) === 'T') sb[doc.net(cb + ':' + p)] = 1;
        });
        var comum = Object.keys(sa).some(function (n) { return sb[n]; });
        if (!comum) continue;
        if (!temIntertravamento(doc, sim, da, db) || !temIntertravamento(doc, sim, db, da)) {
          add('E008', 'erro', 'Reversão sem intertravamento entre ' +
            doc.comps[da].ref + ' e ' + doc.comps[db].ref + '.', [ca, cb, da, db]);
        }
      }
    }

    var vCom = (doc.meta.tensaoComando || {}).valor;
    if (typeof vCom === 'number') {
      doc.ordem.slice().sort().forEach(function (cid) {
        if (doc.comps[cid].type !== 'coil') return;
        var v = doc.params(cid).tensao;
        if (typeof v === 'number' && v !== vCom) {
          add('E009', 'erro', 'Bobina ' + doc.comps[cid].ref + ' de ' + v +
            ' V em comando de ' + vCom + ' V.', [cid]);
        }
      });
    }

    if (r.serie.length) {
      add('W-SERIE', 'aviso',
        'Cargas em série no mesmo caminho: não simuladas no MVP (entrega 2).', r.serie);
    }
    return saida;
  }

  function temIntertravamento(doc, sim, bobina, outra) {
    var adj = sim._vizinhosTodos();
    doc.ordem.forEach(function (cid) {
      if (doc.comps[cid].type !== 'contact_nc' || doc.dono(cid) !== outra) return;
      var pins = doc.pins[cid] || [];
      if (pins.length < 2) return;
      var a = doc.net(cid + ':' + pins[0]);
      var b = doc.net(cid + ':' + pins[1]);
      if (adj[a]) delete adj[a][b];
      if (adj[b]) delete adj[b][a];
    });
    var fase = (doc.alim.comando || {}).fase;
    var alvo = doc.net(bobina + ':' + (doc.pins[bobina] || ['A1'])[0]);
    return !sim._bfs(doc.net(fase), adj)[alvo];
  }

  /** Adjacência do comando com TODAS as chaves fechadas (caminho candidato). */
  Sim.prototype._vizinhosTodos = function () {
    var adj = {};
    var self = this;
    this.doc.ordem.forEach(function (cid) {
      if (self.doc.camada(cid) !== COMANDO) return;
      if (!CHAVES[self.doc.comps[cid].type]) return;
      self.doc.pares(cid).forEach(function (par) {
        var a = self.doc.net(cid + ':' + par[0]);
        var b = self.doc.net(cid + ':' + par[1]);
        (adj[a] = adj[a] || {})[b] = 1;
        (adj[b] = adj[b] || {})[a] = 1;
      });
    });
    return adj;
  };

  // --- explicação e narração ----------------------------------------------

  var DESCARTE = {
    pushbutton_no: 'botoeira NA', pushbutton_nc: 'botoeira NF',
    contact_no: 'contato NA', contact_nc: 'contato NF',
    contact_ton_no: 'contato temporizado NA',
    contact_ton_nc: 'contato temporizado NF',
    fuse: 'fusível', overload: 'relé térmico', contactor_power: 'contator'
  };

  function caminhoComando(doc) {
    var adj = {};
    doc.ordem.forEach(function (cid) {
      if (doc.camada(cid) !== COMANDO) return;
      if (!CHAVES[doc.comps[cid].type]) return;
      doc.pares(cid).forEach(function (par) {
        var a = doc.net(cid + ':' + par[0]);
        var b = doc.net(cid + ':' + par[1]);
        (adj[a] = adj[a] || []).push([b, cid]);
        (adj[b] = adj[b] || []).push([a, cid]);
      });
    });
    return adj;
  }

  function menorCaminho(adj, origem, destino) {
    if (origem === destino) return [];
    var antes = {};
    antes[origem] = null;
    var fila = [origem];
    while (fila.length) {
      var n = fila.shift();
      var viz = adj[n] || [];
      for (var i = 0; i < viz.length; i++) {
        var m = viz[i][0], cid = viz[i][1];
        if (antes[m] !== undefined) continue;
        antes[m] = [n, cid];
        if (m === destino) {
          var cam = [];
          var atual = m;
          while (antes[atual]) {
            cam.unshift(antes[atual][1]);
            atual = antes[atual][0];
          }
          return cam;
        }
        fila.push(m);
      }
    }
    return null;
  }

  function explicar(doc, sim, alvo) {
    var r = sim.resolver();
    if (Object.keys(r.curto).length) {
      return {
        codigo: 'curto',
        texto: 'Há um caminho só com chaves entre fase e neutro: curto. ' +
          'A simulação não pode continuar com segurança.',
        suspeitos: [], componentes: []
      };
    }
    if (r.serie.length) {
      return {
        codigo: 'serie',
        texto: 'Há cargas em série no mesmo caminho. O simulador do MVP não ' +
          'divide tensão entre cargas; a leitura ficaria errada.',
        suspeitos: [], componentes: r.serie.slice()
      };
    }
    var cargas = Object.keys(sim.bobina).sort().filter(function (c) {
      return !alvo || c === alvo;
    });
    if (!cargas.length) {
      return { codigo: 'sem_carga', texto: 'Não há bobina neste circuito.', suspeitos: [], componentes: [] };
    }
    var cid = cargas[0];
    var ref = doc.comps[cid].ref;
    var pins = doc.pins[cid] || [];

    if (r.energizado[cid]) {
      var fechados = doc.ordem.filter(function (c) {
        return doc.dono(c) === cid && sim.fechado(c);
      }).sort();
      var extra = '';
      if (fechados.length) {
        var refs = {};
        fechados.forEach(function (c) {
          refs[doc.comps[c].ref + ' ' + (doc.pins[c] || []).join('-')] = 1;
        });
        extra = ' Os contatos de ' + ref + ' fecharam: ' +
          Object.keys(refs).sort().join(', ') + '.';
      }
      return {
        codigo: 'energizado',
        texto: ref + ' está energizada (' +
          (sim.bobina[cid].fechada ? 'fechada' : 'em pickup') + ').' + extra,
        suspeitos: [], componentes: [cid]
      };
    }

    var adj = caminhoComando(doc);
    var alimC = doc.alim.comando || {};
    var fase = doc.net(alimC.fase);
    var neutro = doc.net(alimC.neutro);
    var a = doc.net(cid + ':' + pins[0]);
    var b = doc.net(cid + ':' + pins[1]);

    for (var k = 0; k < 2; k++) {
      var ponta = k === 0 ? a : b;
      var cam = menorCaminho(adj, fase, ponta);
      if (!cam) continue;
      var abertos = cam.filter(function (c) { return !sim.fechado(c); });
      if (abertos.length) {
        return {
          codigo: 'fase_interrompida',
          texto: 'O caminho da fase até ' + ref + ' está interrompido por: ' +
            abertos.map(function (c) {
              return doc.comps[c].ref + ' (' + (DESCARTE[doc.comps[c].type] || doc.comps[c].type) + ')';
            }).filter(function (v, i, arr) { return arr.indexOf(v) === i; }).sort().join(', ') + '.',
          suspeitos: abertos, componentes: [cid].concat(abertos)
        };
      }
    }

    var camRet = menorCaminho(adj, neutro, b);
    if (!camRet) {
      return {
        codigo: 'sem_retorno',
        texto: ref + ' não tem caminho de retorno até o neutro. ' +
          'Verifique o fio do outro terminal da bobina.',
        suspeitos: [], componentes: [cid]
      };
    }
    var abertosRet = camRet.filter(function (c) { return !sim.fechado(c); });
    if (abertosRet.length) {
      return {
        codigo: 'retorno_interrompido',
        texto: 'O retorno está interrompido por: ' +
          abertosRet.map(function (c) {
            return doc.comps[c].ref + ' (' + (DESCARTE[doc.comps[c].type] || doc.comps[c].type) + ')';
          }).filter(function (v, i, arr) { return arr.indexOf(v) === i; }).sort().join(', ') + '.',
        suspeitos: abertosRet, componentes: [cid].concat(abertosRet)
      };
    }

    return {
      codigo: 'indefinido',
      texto: ref + ' não energiza, mas não encontrei interrupção óbvia no caminho.',
      suspeitos: [], componentes: [cid]
    };
  }

  function seg(ms) { return (ms / 1000).toFixed(2).replace('.', ',') + ' s'; }

  function narrar(doc, sim) {
    if (!sim.eventos.length) return 'Nada aconteceu ainda: nenhuma entrada foi acionada.';
    return sim.eventos.slice(-6).map(function (e) {
      return seg(e.tempo) + ' — ' + e.texto;
    }).join(' ');
  }

  // --- tela (controlador) --------------------------------------------------

  function Tela() {
    this.estado = 'SEM_PROJETO';
    this.doc = null;
    this.sim = null;
    this.mapa = null;
    this.eventos = [];
    this.truncado = false;
    this.hashInicial = null;
    this.rodouRoteiro = false;
    this.dt = DT;
  }

  Tela.prototype.abrir = function (entrada) {
    var mapa = typeof entrada === 'string' ? JSON.parse(entrada) : entrada;
    this.mapa = clonar(mapa);
    this.doc = new Doc(this.mapa);
    this.sim = new Sim(this.doc);
    this.eventos = [];
    this.truncado = false;
    this.hashInicial = impressaoDocumento(this.mapa);
    this.rodouRoteiro = false;
    this.estado = 'PRONTO';
    return this.estado;
  };
  Tela.prototype.play = function () {
    if (this.estado === 'PRONTO' || this.estado === 'PAUSADO') this.estado = 'RODANDO';
    return this.estado;
  };
  Tela.prototype.pause = function () {
    if (this.estado === 'RODANDO') this.estado = 'PAUSADO';
    return this.estado;
  };
  Tela.prototype.passo = function () {
    if (this.estado === 'PRONTO' || this.estado === 'PAUSADO') {
      this._avanca(1);
      this.estado = 'PAUSADO';
      this.rodouRoteiro = true;
    }
    return this.estado;
  };
  Tela.prototype.reset = function () {
    if (this.estado === 'SEM_PROJETO') return this.estado;
    this.sim = new Sim(this.sim.doc);
    this.eventos = [];
    this.truncado = false;
    this.rodouRoteiro = false;
    this.estado = 'PRONTO';
    return this.estado;
  };
  Tela.prototype.tique = function (ms) {
    ms = ms || 16;
    if (this.estado !== 'RODANDO') return;
    var passos = Math.max(1, Math.round(ms / this.dt));
    this._avanca(passos);
    this.rodouRoteiro = true;
  };
  Tela.prototype._avanca = function (passos) {
    for (var i = 0; i < passos; i++) {
      this.sim.passo(this.dt);
      this._coleta();
    }
  };
  Tela.prototype._coleta = function () {
    var novos = this.sim.eventos.slice(this.eventos.length);
    var self = this;
    novos.forEach(function (e) { self.eventos.push([self.sim.agora, e.texto]); });
    if (this.eventos.length > MAX_EVENTOS) {
      this.eventos = this.eventos.slice(this.eventos.length - MAX_EVENTOS);
      this.truncado = true;
    } else {
      this.truncado = false;
    }
  };
  Tela.prototype.acionar = function (cid, valor) {
    if (this.estado !== 'RODANDO' && this.estado !== 'PAUSADO') return false;
    this.sim.acionar(cid, valor);
    return true;
  };
  Tela.prototype.diario = function () { return formatarDiario(this.eventos); };
  Tela.prototype.botoes = function () {
    var e = this.estado;
    return [
      { id: 'play', rotulo: 'Reproduzir', habilitado: e === 'PRONTO' || e === 'PAUSADO', semantica: 'inicia a simulação' },
      { id: 'pause', rotulo: 'Pausar', habilitado: e === 'RODANDO', semantica: 'pausa a simulação' },
      { id: 'passo', rotulo: 'Avançar um passo', habilitado: e === 'PRONTO' || e === 'PAUSADO', semantica: 'avança 10 ms' },
      { id: 'reset', rotulo: 'Reiniciar', habilitado: e !== 'SEM_PROJETO', semantica: 'volta ao início' }
    ];
  };
  Tela.prototype.botoeiras = function () {
    if (!this.doc) return [];
    var self = this;
    return Object.keys(this.sim.pressionado).sort().map(function (cid) {
      var c = self.doc.comps[cid];
      var rotulo = self.doc.params(cid).rotulo || c.ref;
      return {
        id: cid,
        rotulo: c.ref + ' — ' + rotulo,
        acessivel: 'Segure para acionar ' + c.ref + ', ' + rotulo,
        habilitado: self.estado === 'RODANDO' || self.estado === 'PAUSADO',
        pressionado: !!self.sim.pressionado[cid]
      };
    });
  };
  Tela.prototype.motores = function () {
    if (!this.doc) return [];
    var self = this;
    return Object.keys(this.sim.motor).sort().map(function (cid) {
      var ref = self.doc.comps[cid].ref;
      var i = self.sim.correnteMotor(cid);
      var e = self.sim.motor[cid].estado;
      var amps = i.toFixed(1).replace('.', ',');
      var texto = e === 'PARTINDO' ? 'partindo (' + amps + ' A)'
        : e === 'NOMINAL' ? 'nominal (' + amps + ' A)' : 'parado';
      return { id: cid, texto: ref + ' — ' + texto, estado: e, corrente: i };
    });
  };
  Tela.prototype.selo = function () {
    if (!this.doc) return { estado: 'não verificado', motivo: 'nenhum projeto aberto' };
    if (impressaoDocumento(this.mapa) !== this.hashInicial) {
      return { estado: 'não verificado', motivo: 'o documento mudou desde a abertura' };
    }
    var erros = erc(this.doc, this.sim).filter(function (d) { return d.severidade === 'erro'; });
    if (erros.length) {
      return { estado: 'não verificado', motivo: erros.length + ' erro(s) de verificação' };
    }
    if (!this.rodouRoteiro) {
      return { estado: 'não verificado', motivo: 'a simulação ainda não rodou' };
    }
    return {
      estado: 'verificado',
      motivo: 'ERC limpo e roteiro rodado',
      solver: 'lógico (MVP)',
      hash: this.hashInicial
    };
  };

  function formatarDiario(eventos) {
    var blocos = [];
    var vistos = {};
    (eventos || []).forEach(function (par) {
      var t = par[0], texto = par[1];
      var chave = t + '|' + texto;
      if (vistos[chave]) return;
      vistos[chave] = 1;
      var s = Math.floor(t / 1000);
      if (!blocos.length || blocos[blocos.length - 1].segundo !== s) {
        blocos.push({ segundo: s, titulo: s + ' s', linhas: [] });
      }
      blocos[blocos.length - 1].linhas.push({ tempo: seg(t), texto: texto });
    });
    return blocos;
  }

  // --- geometria de símbolo e rota ----------------------------------------

  var MOLDES = {
    coil: [40, 60, { A1: [0, -30, 'up'], A2: [0, 30, 'down'] }],
    lamp: [40, 60, { A1: [0, -30, 'up'], A2: [0, 30, 'down'] }],
    timer_ton: [40, 60, { A1: [0, -30, 'up'], A2: [0, 30, 'down'] }],
    fuse: [40, 60, { L: [0, -30, 'up'], T: [0, 30, 'down'] }],
    fonte_comando: [40, 60, { L: [0, -30, 'up'], N: [0, 30, 'down'] }],
    motor3p: [60, 60, { U: [-20, -30, 'up'], V: [0, -30, 'up'], W: [20, -30, 'up'] }],
    contator_2p: [50, 60, { 13: [-25, 0, 'left'], 14: [25, 0, 'right'] }],
    contator_3p: [60, 60, {
      L1: [-20, -30, 'up'], L2: [0, -30, 'up'], L3: [20, -30, 'up'],
      T1: [-20, 30, 'down'], T2: [0, 30, 'down'], T3: [20, 30, 'down']
    }]
  };

  function molde(tipo) {
    if (tipo === 'overload' || tipo === 'contactor_power') return MOLDES.contator_3p;
    if (tipo === 'fuse') return MOLDES.fuse;
    return MOLDES[tipo] || MOLDES.contator_2p;
  }

  function girar(ponto, rot) {
    rot = ((rot || 0) % 360 + 360) % 360;
    var x = ponto[0], y = ponto[1];
    if (rot === 90) return [-y, x];
    if (rot === 180) return [-x, -y];
    if (rot === 270) return [y, -x];
    return [x, y];
  }
  function girarDir(dir, rot) {
    var ordem = ['up', 'right', 'down', 'left'];
    return ordem[(ordem.indexOf(dir) + ((rot || 0) % 360) / 90) % 4];
  }

  /** Geometria de pino do componente. O nome do terminal vem do DOCUMENTO;
   *  o desenho é o do molde. Se o documento usar outros nomes (11/12, A1/N,
   *  U/V/W), o molde é remapeado na ordem declarada em vez de sumir com o pino. */
  function pinsDoComponente(doc, cid) {
    var c = doc.comps[cid];
    var m = molde(c.type);
    var nomes = doc.pins[cid] || [];
    var base = m[2];
    if (c.type === 'fuse') base = nomes.length === 6 ? MOLDES.contator_3p[2] : MOLDES.fuse[2];
    var falta = nomes.some(function (n) { return !base[n]; });
    if (falta && nomes.length) {
      var geom = nomes.length >= 3 ? MOLDES.contator_3p[2] : MOLDES.contator_2p[2];
      var ordem = nomes.length >= 3 ? ['L1', 'L2', 'L3', 'T1', 'T2', 'T3'] : ['13', '14'];
      var mapa = {};
      nomes.forEach(function (n, i) {
        if (geom[ordem[i]]) mapa[n] = geom[ordem[i]];
      });
      return mapa;
    }
    return base;
  }

  function pinPos(doc, cid, pino) {
    var c = doc.comps[cid];
    var pinos = pinsDoComponente(doc, cid);
    var p = pinos[pino];
    if (!p) return null;
    var d = girar([p[0], p[1]], c.rot || 0);
    var pos = c.pos || { x: 0, y: 0 };
    return [pos.x + d[0], pos.y + d[1]];
  }

  function pinDir(doc, cid, pino) {
    var c = doc.comps[cid];
    var pinos = pinsDoComponente(doc, cid);
    var p = pinos[pino];
    return p ? girarDir(p[2], c.rot || 0) : null;
  }

  function gradear(v) { return Math.round(v / 10) * 10; }

  function limpar(pts) {
    var saida = [];
    pts.forEach(function (p) {
      var ultimo = saida[saida.length - 1];
      if (!ultimo || p[0] !== ultimo[0] || p[1] !== ultimo[1]) saida.push(p);
    });
    var i = 1;
    while (i < saida.length - 1) {
      var a = saida[i - 1], b = saida[i], c = saida[i + 1];
      if ((a[0] === b[0] && b[0] === c[0]) || (a[1] === b[1] && b[1] === c[1])) saida.splice(i, 1);
      else i++;
    }
    return saida;
  }

  function direcao(p, q) {
    if (q[0] === p[0]) return q[1] > p[1] ? 'down' : 'up';
    return q[0] > p[0] ? 'right' : 'left';
  }

  function avanca(a, p, d) {
    if (p[0] === a[0] && p[1] === a[1]) return false;
    if (d === 'left' || d === 'right') return d === 'right' ? p[0] > a[0] : p[0] < a[0];
    return d === 'down' ? p[1] > a[1] : p[1] < a[1];
  }

  /** Rota ortogonal do fio, grudada nos dois pinos. L por padrão, Z com dobra. */
  function rota(doc, wid) {
    var w = null;
    doc.wires.forEach(function (x) { if (x.id === wid) w = x; });
    if (!w) return null;
    var de = String(w.from).split(':');
    var para = String(w.to).split(':');
    var a = pinPos(doc, de[0], de[1]);
    var b = pinPos(doc, para[0], para[1]);
    if (!a || !b) return null;
    var da = pinDir(doc, de[0], de[1]);
    var db = pinDir(doc, para[0], para[1]);
    if (a[0] === b[0] && a[1] === b[1]) return [a];
    var modo = w.modo || 'L';
    var dobra = w.dobra || 0;

    if (modo === 'Z') {
      var horizontal = da === 'left' || da === 'right';
      if (horizontal && Math.abs(a[0] - b[0]) > 10) {
        var mx = gradear((a[0] + b[0]) / 2 + dobra);
        if (avanca(a, [mx, a[1]], da)) {
          var pz = limpar([a, [mx, a[1]], [mx, b[1]], b]);
          if (pz.length >= 3) return pz;
        }
      } else if (!horizontal && Math.abs(a[1] - b[1]) > 10) {
        var my = gradear((a[1] + b[1]) / 2 + dobra);
        if (avanca(a, [a[0], my], da)) {
          var pz2 = limpar([a, [a[0], my], [b[0], my], b]);
          if (pz2.length >= 3) return pz2;
        }
      }
    }
    if (a[0] === b[0] || a[1] === b[1]) return limpar([a, b]);

    var l1 = limpar([a, [b[0], a[1]], b]);
    var l2 = limpar([a, [a[0], b[1]], b]);
    function pontos(pts) {
      var s = 0;
      if (pts.length >= 2 && direcao(pts[0], pts[1]) === da) s += 2;
      if (pts.length >= 2 && direcao(pts[pts.length - 1], pts[pts.length - 2]) === db) s += 1;
      return s;
    }
    return pontos(l1) >= pontos(l2) ? l1 : l2;
  }

  function snap(doc, ponto, ignorar) {
    var melhor = null;
    doc.ordem.forEach(function (cid) {
      var pinos = pinsDoComponente(doc, cid);
      Object.keys(pinos).forEach(function (pino) {
        var t = cid + ':' + pino;
        if (t === ignorar) return;
        var p = pinPos(doc, cid, pino);
        var d2 = Math.round((p[0] - ponto[0]) * (p[0] - ponto[0]) + (p[1] - ponto[1]) * (p[1] - ponto[1]));
        if (d2 > 24 * 24) return;
        if (!melhor || d2 < melhor.d2 || (d2 === melhor.d2 && t < melhor.terminal)) {
          melhor = { d2: d2, terminal: t, ponto: p };
        }
      });
    });
    if (melhor) return { tipo: 'terminal', terminal: melhor.terminal, ponto: melhor.ponto };
    return { tipo: 'grade', terminal: null, ponto: [gradear(ponto[0]), gradear(ponto[1])] };
  }

  // --- leitura e escrita do projeto ---------------------------------------

  function problemasDocumento(doc) {
    var p = [];
    function add(codigo, caminho, mensagem, severidade) {
      p.push({ codigo: codigo, caminho: caminho, mensagem: mensagem, severidade: severidade || 'erro' });
    }
    if (!doc || typeof doc !== 'object') { add('SEM_DOCUMENTO', '', 'não há objeto'); return p; }
    if (doc.schema === undefined) add('SCHEMA_AUSENTE', 'schema', "o arquivo não declara 'schema'");
    else if (typeof doc.schema !== 'number') add('SCHEMA_INVALIDO', 'schema', 'schema precisa ser inteiro');
    else if (doc.schema > SCHEMA) add('SCHEMA_FUTURO', 'schema', 'projeto na versão ' + doc.schema + ', este app entende até ' + SCHEMA);
    if (!doc.meta || typeof doc.meta !== 'object') add('META_AUSENTE', 'meta', "bloco 'meta' obrigatório");
    if (!doc.sheets || !doc.sheets.length) { add('SHEETS_AUSENTE', 'sheets', 'precisa de ao menos uma folha'); return p; }

    var totalC = 0, totalF = 0;
    doc.sheets.forEach(function (s, i) {
      var base = 'sheets[' + i + ']';
      if (!s || !s.components) add('COMPONENTES_AUSENTE', base + '.components', 'lista obrigatória');
      if (!s || !s.wires) add('FIOS_AUSENTE', base + '.wires', 'lista obrigatória');
      var comps = (s && s.components) || [];
      var fios = (s && s.wires) || [];
      totalC += comps.length; totalF += fios.length;
      var ids = {};
      comps.forEach(function (c, j) {
        var cb = base + '.components[' + j + ']';
        if (!c || typeof c.id !== 'string' || !c.id) { add('ID_INVALIDO', cb + '.id', 'id obrigatório'); return; }
        if (ids[c.id]) add('ID_DUPLICADO', cb + '.id', "id '" + c.id + "' repetido");
        ids[c.id] = 1;
        if (!TIPOS[c.type]) add('TIPO_DESCONHECIDO', cb + '.type', "tipo '" + c.type + "' não simula", 'aviso');
        var pos = c.pos;
        if (!pos || typeof pos.x !== 'number' || typeof pos.y !== 'number') {
          add('POS_INVALIDA', cb + '.pos', 'pos.x e pos.y precisam ser números');
        }
        if (c.rot !== undefined && ROTACOES.indexOf(c.rot) < 0) {
          add('ROT_INVALIDA', cb + '.rot', 'rotação precisa ser 0/90/180/270');
        }
      });
      fios.forEach(function (w, j) {
        var wb = base + '.wires[' + j + ']';
        ['from', 'to'].forEach(function (lado) {
          var t = w && w[lado];
          if (typeof t !== 'string' || t.indexOf(':') < 0) {
            add('FIO_INVALIDO', wb + '.' + lado, "terminal no formato 'componente:pino'");
            return;
          }
          if (!ids[t.split(':')[0]]) add('FIO_ORFAO', wb + '.' + lado, 'aponta para componente inexistente');
        });
        if (w && w.from && w.from === w.to) add('FIO_REDUNDANTE', wb, 'fio liga o terminal a ele mesmo');
      });
    });
    if (totalC > MAX_COMPONENTES) add('LIMITE_COMPONENTES', 'sheets', totalC + ' componentes excedem ' + MAX_COMPONENTES);
    if (totalF > MAX_FIOS) add('LIMITE_FIOS', 'sheets', totalF + ' fios excedem ' + MAX_FIOS);
    return p;
  }

  /** Abre projeto vindo de texto ou objeto. Nunca "conserta" calado. */
  function abrir(entrada) {
    var doc = entrada;
    if (typeof entrada === 'string') {
      try { doc = JSON.parse(entrada.replace(/^\uFEFF/, '')); }
      catch (e) { return { ok: false, erro: 'JSON inválido: ' + e.message, problemas: [] }; }
    }
    var p = problemasDocumento(doc);
    var erros = p.filter(function (x) { return x.severidade === 'erro'; });
    if (erros.length) {
      return {
        ok: false,
        erro: erros.length + ' problema(s) impedem abrir: ' +
          erros.map(function (x) { return x.codigo + ' em ' + x.caminho; }).join('; '),
        problemas: p
      };
    }
    try {
      var norm = new Doc(clonar(doc));
      return {
        ok: true, doc: doc, normalizado: norm, problemas: p,
        hash: impressaoDocumento(doc), selo: seloVigente(doc)
      };
    } catch (e) {
      return { ok: false, erro: e.message, problemas: p };
    }
  }

  function serializar(doc) {
    return JSON.stringify(ordenar(clonar(doc)), null, 2) + '\n';
  }

  function seloVigente(doc) {
    var v = (doc && doc.verification) || {};
    if (!v.docHash) return { estado: 'não verificado', motivo: 'sem hash de verificação' };
    if (v.docHash !== impressaoDocumento(doc)) {
      return { estado: 'não verificado', motivo: 'o documento mudou desde a verificação' };
    }
    return { estado: v.estado || 'não verificado', motivo: 'hash confere' };
  }

  function marcarVerificado(doc, estado) {
    doc.verification = doc.verification || {};
    doc.verification.estado = estado || 'verificado';
    doc.verification.docHash = impressaoDocumento(doc);
    return doc.verification;
  }

  return {
    VERSAO: 1,
    SCHEMA: SCHEMA,
    Doc: Doc,
    Sim: Sim,
    Tela: Tela,
    erc: erc,
    explicar: explicar,
    narrar: narrar,
    abrir: abrir,
    serializar: serializar,
    problemas: problemasDocumento,
    impressao: impressao,
    impressaoDocumento: impressaoDocumento,
    seloVigente: seloVigente,
    marcarVerificado: marcarVerificado,
    formatarDiario: formatarDiario,
    rota: rota,
    snap: snap,
    pinPos: pinPos,
    pinDir: pinDir,
    molde: molde,
    girar: girar,
    PINS3P: PINS3P.slice(),
    LIMITES: { componentes: MAX_COMPONENTES, fios: MAX_FIOS, eventos: MAX_EVENTOS }
  };
});
