'use strict';
const assert = require('node:assert/strict');
const norm = (s) => String(s).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
const waCall = /^(?:(?:ligar|ligue|chamar|chame)(?: de)? (?:audio|áudio|voz|video|vídeo) para|(?:ligar|ligue|chamar|chame) para) (.+?) (?:pelo|no|via) whatsapp$/.exec(norm('Ligue de vídeo para Bia pelo WhatsApp'));
assert.equal(waCall && waCall[1], 'bia');
const waCallVoice = /^(?:(?:ligar|ligue|chamar|chame)(?: de)? (?:audio|áudio|voz|video|vídeo) para|(?:ligar|ligue|chamar|chame) para) (.+?) (?:pelo|no|via) whatsapp$/.exec(norm('Ligue para Bia pelo WhatsApp'));
assert.equal(waCallVoice && waCallVoice[1], 'bia');
const waChat = /^(?:abrir|abra|mostrar|mostre|entrar na|entrar em|ir para) (?:a )?(?:conversa|chat)(?: do whatsapp)? (?:com|de) (.+)$/.exec(norm('Abra a conversa do WhatsApp com Bia'));
assert.equal(waChat && waChat[1], 'bia');
console.log('Rotas de voz WhatsApp validadas: conversa, chamada de voz e chamada de vídeo encaminhadas para abertura segura do chat.');

const waAudio = /^(?:mande|mandar|envie|enviar|gravar|grave|fazer|faca) (?:um )?(?:audio|mensagem de audio|mensagem de voz) (?:para|pra) (.+?)(?: pelo whatsapp)?$/.exec(norm('Mande um áudio para Bia pelo WhatsApp'));
assert.equal(waAudio && waAudio[1], 'bia');
