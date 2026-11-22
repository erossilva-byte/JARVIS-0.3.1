/* J.A.R.V.I.S. Nova — Cultura local (1.43.0)
 * Receitas, bebidas, nutrição, treinos, piadas, curiosidades e sugestões de lazer.
 * Dados curados e embarcados: funcionam offline e não fingem ser uma API externa.
 */
(function (raiz) {
  'use strict';
  const C = {};

  const RECEITAS = [
    { nome: 'Omelete de queijo', tempo: 10, porcoes: 1, ingredientes: ['2 ovos', '2 fatias de queijo', '1 colher de manteiga', 'sal e pimenta'], modo: ['Bata os ovos com sal e pimenta.', 'Derreta a manteiga na frigideira em fogo baixo.', 'Despeje os ovos, espalhe o queijo e dobre ao meio.', 'Deixe 1 minuto tampado e sirva.'] },
    { nome: 'Macarrão alho e óleo', tempo: 20, porcoes: 2, ingredientes: ['200 g de espaguete', '3 dentes de alho', '4 colheres de azeite', 'salsinha e sal'], modo: ['Cozinhe o macarrão conforme a embalagem.', 'Doure o alho fatiado no azeite, sem queimar.', 'Misture o macarrão escorrido, a salsinha e ajuste o sal.'] },
    { nome: 'Arroz soltinho', tempo: 25, porcoes: 3, ingredientes: ['1 xícara de arroz', '2 xícaras de água quente', '1 dente de alho', '1 colher de óleo', 'sal'], modo: ['Refogue o alho no óleo.', 'Acrescente o arroz e toste por 1 minuto.', 'Adicione a água quente e o sal, tampe e cozinhe em fogo baixo por 15 minutos.', 'Desligue e deixe descansar tampado por 5 minutos.'] },
    { nome: 'Frango grelhado com limão', tempo: 25, porcoes: 1, ingredientes: ['1 filé de frango', 'suco de 1/2 limão', '1 dente de alho', 'azeite, sal e pimenta'], modo: ['Tempere o frango com limão, alho, sal e pimenta.', 'Aqueça a frigideira com azeite.', 'Grelhe 5 minutos de cada lado, até dourar e cozinhar por dentro.'] },
    { nome: 'Vitamina de banana', tempo: 5, porcoes: 1, ingredientes: ['1 banana', '200 ml de leite', '1 colher de aveia', 'canela'], modo: ['Bata tudo no liquidificador.', 'Sirva gelado com canela por cima.'] },
    { nome: 'Salada de grão-de-bico', tempo: 15, porcoes: 2, ingredientes: ['1 lata de grão-de-bico', '1 tomate', '1/2 cebola', 'salsinha', 'azeite e limão'], modo: ['Escorra e lave o grão-de-bico.', 'Pique o tomate, a cebola e a salsinha.', 'Misture tudo com azeite, limão e sal.'] },
    { nome: 'Panqueca simples', tempo: 15, porcoes: 2, ingredientes: ['1 xícara de farinha', '1 ovo', '1 xícara de leite', '1 pitada de sal'], modo: ['Bata os ingredientes até ficar homogêneo.', 'Despeje pequenas porções na frigideira quente.', 'Doure dos dois lados e recheie a gosto.'] },
    { nome: 'Sopa de legumes', tempo: 30, porcoes: 3, ingredientes: ['2 batatas', '1 cenoura', '1 abobrinha', '1 cebola', '1 litro de água', 'sal e cheiro-verde'], modo: ['Refogue a cebola.', 'Junte os legumes picados e a água.', 'Cozinhe por 20 minutos, ajuste o sal e finalize com cheiro-verde.'] },
  ];

  const BEBIDAS = [
    { nome: 'Limão suíço', ingredientes: ['suco de 1 limão', '200 ml de água', '1 colher de açúcar', 'gelo'], modo: 'Bata tudo no liquidificador e coe. Sirva imediatamente.' },
    { nome: 'Chá gelado de hibisco', ingredientes: ['1 colher de hibisco seco', '300 ml de água quente', 'gelo', 'mel'], modo: 'Infusione por 5 minutos, coe, adoce e leve à geladeira.' },
    { nome: 'Café gelado', ingredientes: ['1 dose de café coado', '150 ml de leite gelado', 'gelo', 'açúcar'], modo: 'Misture o café frio com o leite e o gelo.' },
    { nome: 'Batida de morango sem álcool', ingredientes: ['1 xícara de morangos', '200 ml de leite', '1 colher de leite condensado', 'gelo'], modo: 'Bata tudo e sirva na hora.' },
    { nome: 'Mojito sem álcool', ingredientes: ['folhas de hortelã', 'suco de 1 limão', 'água com gás', 'açúcar e gelo'], modo: 'Macere a hortelã com o açúcar, junte limão, gelo e complete com água com gás.' },
  ];

  const FRUTAS = [
    { nome: 'banana', kcal: 89, porcao: '100 g', fibras: 2.6, destaque: 'potássio e energia rápida' },
    { nome: 'maçã', kcal: 52, porcao: '100 g', fibras: 2.4, destaque: 'fibras e saciedade' },
    { nome: 'laranja', kcal: 47, porcao: '100 g', fibras: 2.4, destaque: 'vitamina C' },
    { nome: 'mamão', kcal: 43, porcao: '100 g', fibras: 1.7, destaque: 'vitamina A e digestão' },
    { nome: 'abacate', kcal: 160, porcao: '100 g', fibras: 6.7, destaque: 'gorduras boas' },
    { nome: 'morango', kcal: 32, porcao: '100 g', fibras: 2, destaque: 'antioxidantes' },
    { nome: 'uva', kcal: 69, porcao: '100 g', fibras: 0.9, destaque: 'antocianinas' },
    { nome: 'melancia', kcal: 30, porcao: '100 g', fibras: 0.4, destaque: 'hidratação' },
  ];

  const TREINOS = [
    { nome: 'Treino em casa sem equipamento', nivel: 'iniciante', duracao: 20, exercicios: ['20 agachamentos', '30 s de prancha', '15 flexões (joelho se precisar)', '20 avanços alternados', '2 voltas com 1 min de descanso'] },
    { nome: 'Caminhada ativa', nivel: 'iniciante', duracao: 30, exercicios: ['5 min de aquecimento leve', '20 min de caminhada em ritmo constante', '5 min de alongamento'] },
    { nome: 'Core curto', nivel: 'intermediário', duracao: 12, exercicios: ['30 s de prancha', '15 abdominais', '20 s de prancha lateral para cada lado', '2 voltas'] },
    { nome: 'Mobilidade matinal', nivel: 'iniciante', duracao: 8, exercicios: ['rotação de pescoço 30 s', 'círculos de ombro 30 s', 'alongamento de gato-vaca 1 min', 'alongamento de posterior 1 min'] },
    { nome: 'Circuito metabólico', nivel: 'avançado', duracao: 25, exercicios: ['40 s de polichinelo', '40 s de agachamento', '40 s de flexão', '40 s de prancha', '20 s de descanso entre blocos, 4 voltas'] },
  ];

  const PIADAS = [
    'Por que o computador foi ao médico? Porque estava com um vírus.',
    'O que o pato disse para a pata? Vem quá.',
    'Qual é o cúmulo do programador? Documentar o próprio código.',
    'Por que o livro de matemática estava triste? Tinha muitos problemas.',
    'O que o zero disse para o oito? Bonito cinto.',
    'Como o elétron se despede? Até a próxima voltagem.',
    'Qual é o animal mais antigo? A zebra, porque está em preto e branco.',
    'Por que a planta não usou o celular? Porque já tinha raízes.',
    'O que o oceano falou para a praia? Nada, ele só acenou.',
    'Meu Wi-Fi é tão ruim que o vizinho perguntou se eu estava usando pombo correio.',
    'Por que o esqueleto não brigou? Porque não tinha estômago para isso.',
    'Qual é o cúmulo da paciência? Esperar o Windows atualizar sem reiniciar.',
  ];

  const CURIOSIDADES = [
    'Um raio pode atingir a mesma região várias vezes; o que muda é a probabilidade.',
    'O mel pode durar milhares de anos se ficar bem vedado e sem umidade.',
    'O coração de uma baleia-azul pode ser maior que um carro pequeno.',
    'A luz do Sol leva cerca de 8 minutos e 20 segundos para chegar à Terra.',
    'O polvo tem três corações e sangue azulado.',
    'O som não se propaga no vácuo; no espaço, naves não fariam barulho.',
    'O primeiro mouse de computador era de madeira.',
    'O corpo humano tem cerca de 37 trilhões de células.',
    'As impressões digitais são únicas, mas os koalas também têm padrões parecidos nas patas.',
    'O monte Everest cresce alguns milímetros por ano por causa do movimento das placas.',
    'A Lua se afasta da Terra cerca de 3,8 cm por ano.',
    'O cérebro consome cerca de 20% da energia do corpo, mesmo em repouso.',
  ];

  const FILMES = [
    { titulo: 'Interestelar', genero: 'ficção científica', dica: 'para pensar em tempo, espaço e escolhas' },
    { titulo: 'Matrix', genero: 'ficção científica', dica: 'clássico sobre realidade e liberdade' },
    { titulo: 'O Auto da Compadecida', genero: 'comédia nacional', dica: 'humor brasileiro com texto afiado' },
    { titulo: 'Cidade de Deus', genero: 'drama', dica: 'retrato forte e premiado do Brasil' },
    { titulo: 'Divertida Mente', genero: 'animação', dica: 'leve e inteligente sobre emoções' },
    { titulo: 'Whiplash', genero: 'drama musical', dica: 'para quem gosta de intensidade e música' },
    { titulo: 'Parasita', genero: 'suspense', dica: 'crítica social com reviravoltas' },
    { titulo: 'Duna', genero: 'ficção científica', dica: 'visual grandioso e política' },
  ];
  const SERIES = [
    { titulo: 'Breaking Bad', genero: 'drama', dica: 'transformação e consequências' },
    { titulo: 'Dark', genero: 'ficção científica', dica: 'viagem no tempo em camadas' },
    { titulo: 'The Office', genero: 'comédia', dica: 'humor de escritório para maratonar' },
    { titulo: 'Chernobyl', genero: 'drama histórico', dica: 'tensão e responsabilidade' },
    { titulo: 'Arcane', genero: 'animação', dica: 'visual impecável e conflito de irmãs' },
    { titulo: 'Severance', genero: 'suspense', dica: 'trabalho, memória e identidade' },
    { titulo: 'Modern Family', genero: 'comédia', dica: 'episódios curtos e leves' },
    { titulo: 'Black Mirror', genero: 'antologia', dica: 'tecnologia e seus limites' },
  ];
  const MUSICAS = [
    { genero: 'foco', dica: 'instrumental, lo-fi ou trilhas de filmes, sem letra para não competir com a leitura' },
    { genero: 'treino', dica: 'batidas entre 120 e 140 BPM, playlists de hiit e funk/rock animado' },
    { genero: 'relaxar', dica: 'jazz, bossa nova ou piano lento em volume baixo' },
    { genero: 'faxina', dica: 'clássicos dos anos 80/90 e pop dançante' },
    { genero: 'dormir', dica: 'ruído marrom, chuva ou ambient sem picos de volume' },
  ];
  const ATIVIDADES = [
    'Escreva três coisas que você quer terminar esta semana.',
    'Faça uma caminhada de 15 minutos sem celular.',
    'Organize uma gaveta ou uma pasta de arquivos.',
    'Ligue para alguém que você não fala há tempo.',
    'Prepare uma receita nova com o que já tem em casa.',
    'Leia 10 páginas de um livro parado.',
  ];

  C.receitas = () => RECEITAS.map((r) => r.nome);
  C.receita = (nome) => {
    const t = String(nome || '').toLowerCase().trim();
    if (!t) return RECEITAS;
    return RECEITAS.find((r) => r.nome.toLowerCase().includes(t)) || null;
  };
  C.bebidas = () => BEBIDAS.slice();
  C.fruta = (nome) => {
    const t = String(nome || '').toLowerCase().trim();
    return FRUTAS.find((f) => f.nome.includes(t) || t.includes(f.nome)) || null;
  };
  C.treino = (nivel) => {
    const n = String(nivel || '').toLowerCase().trim();
    if (!n) return TREINOS.slice();
    return TREINOS.filter((t) => t.nivel === n);
  };
  C.piada = (indice) => PIADAS[Math.abs(Number(indice) || 0) % PIADAS.length];
  C.curiosidade = (indice) => CURIOSIDADES[Math.abs(Number(indice) || 0) % CURIOSIDADES.length];
  C.sugestao = (tipo) => {
    const t = String(tipo || '').toLowerCase();
    if (/filme|cinema/.test(t)) return FILMES.slice();
    if (/serie|série/.test(t)) return SERIES.slice();
    if (/musica|música|playlist|som/.test(t)) return MUSICAS.slice();
    if (/tedio|tédio|fazer|atividade/.test(t)) return ATIVIDADES.slice();
    return { filmes: FILMES.slice(), series: SERIES.slice(), musicas: MUSICAS.slice(), atividades: ATIVIDADES.slice() };
  };
  C.buscar = (termo) => {
    const t = String(termo || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    if (!t) return [];
    const itens = [];
    const add = (tipo, nome, extra) => itens.push({ tipo, nome, extra });
    RECEITAS.forEach((r) => { if ((r.nome + ' ' + r.ingredientes.join(' ')).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').includes(t)) add('receita', r.nome, r.tempo + ' min'); });
    BEBIDAS.forEach((b) => { if ((b.nome + ' ' + b.ingredientes.join(' ')).toLowerCase().includes(t)) add('bebida', b.nome, 'sem álcool'); });
    FRUTAS.forEach((f) => { if ((f.nome + ' ' + f.destaque).includes(t)) add('fruta', f.nome, f.kcal + ' kcal/100 g'); });
    TREINOS.forEach((x) => { if ((x.nome + ' ' + x.nivel).toLowerCase().includes(t)) add('treino', x.nome, x.duracao + ' min'); });
    return itens;
  };

  raiz.CulturaJarvis = C;
  if (typeof module !== 'undefined' && module.exports) module.exports = C;
})(typeof window !== 'undefined' ? window : globalThis);
