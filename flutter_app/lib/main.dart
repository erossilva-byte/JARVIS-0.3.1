import 'dart:math' as math;
import 'package:flutter/material.dart';

void main()=>runApp(const JarvisApp());
const cyan=Color(0xFF55DFFF),bg=Color(0xFF050A12),panel=Color(0xFF0B1725),muted=Color(0xFF8CA5B9);

class JarvisApp extends StatelessWidget{
 const JarvisApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'J.A.R.V.I.S. Nova',theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:cyan,brightness:Brightness.dark),useMaterial3:true),home:const HomeScreen());
}
class JarvisModule{
 const JarvisModule(this.name,this.group,this.icon,this.description);
 final String name,group,description;final IconData icon;
}
const modules=<JarvisModule>[
 JarvisModule('Hermes Agent','Inteligência',Icons.hub_rounded,'Orquestração e execução de agentes.'),
 JarvisModule('Provedores de IA','Inteligência',Icons.psychology_rounded,'Groq, Gemini, Cerebras, Mistral e OpenRouter.'),
 JarvisModule('Modelos locais','Inteligência',Icons.memory_rounded,'Modelos locais e operação offline.'),
 JarvisModule('Agentes especializados','Inteligência',Icons.smart_toy_rounded,'Agentes por domínio e ferramentas.'),
 JarvisModule('Memória semântica','Conhecimento',Icons.account_tree_rounded,'Contexto e recuperação de informações.'),
 JarvisModule('Obsidian','Conhecimento',Icons.auto_stories_rounded,'Vínculo e sincronização com cofre Obsidian.'),
 JarvisModule('Voz e KWS','Interação',Icons.graphic_eq_rounded,'Voz, palavra de ativação local e síntese.'),
 JarvisModule('Visão e OCR','Interação',Icons.visibility_rounded,'Câmera, tela, imagens e documentos.'),
 JarvisModule('Arquivos','Produtividade',Icons.folder_copy_rounded,'Leitura, criação, conversão e organização.'),
 JarvisModule('Programação e sandbox','Produtividade',Icons.terminal_rounded,'Assistência de código e execução isolada.'),
 JarvisModule('CADeSIMU e elétrica','Engenharia',Icons.electrical_services_rounded,'Projetos, circuitos e validação elétrica.'),
 JarvisModule('Avatar 3D','Interface',Icons.view_in_ar_rounded,'Avatar e representação visual do assistente.'),
 JarvisModule('Pessoas e contexto','Contexto',Icons.people_alt_rounded,'Perfis e contexto configurável.'),
 JarvisModule('Tarefas e rotinas','Produtividade',Icons.checklist_rounded,'Tarefas persistentes e automações.'),
 JarvisModule('Segurança e privacidade','Sistema',Icons.shield_rounded,'PIN, biometria e permissões suportadas.'),
 JarvisModule('Android e dispositivos','Sistema',Icons.phone_android_rounded,'Estado do dispositivo e recursos Android.'),
 JarvisModule('Pareamento Windows','Conectividade',Icons.devices_rounded,'Vínculo seguro entre celular e computador.'),
 JarvisModule('Controle do Windows','Conectividade',Icons.desktop_windows_rounded,'Ações autorizadas no computador.'),
 JarvisModule('ESP32 e Home Assistant','Conectividade',Icons.sensors_rounded,'Integração residencial e dispositivos.'),
 JarvisModule('Backup e restauração','Sistema',Icons.backup_rounded,'Cópia e recuperação dos dados.'),
 JarvisModule('Atualizações','Sistema',Icons.system_update_alt_rounded,'Versões, integridade e atualização.'),
];

class HomeScreen extends StatefulWidget{
 const HomeScreen({super.key});
 @override State<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin{
 late final AnimationController motion=AnimationController(vsync:this,duration:const Duration(seconds:20))..repeat();
 late final AnimationController intro=AnimationController(vsync:this,duration:const Duration(milliseconds:700))..forward();
 final search=TextEditingController();
 int tab=0;String filter='Todos',query='';Offset tilt=Offset.zero;
 static const groups=['Todos','Inteligência','Conhecimento','Interação','Produtividade','Engenharia','Interface','Contexto','Sistema','Conectividade'];
 @override void dispose(){motion.dispose();intro.dispose();search.dispose();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(backgroundColor:bg,titleSpacing:18,title:const Row(children:[
   _Brand(),SizedBox(width:10),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('J.A.R.V.I.S. NOVA',style:TextStyle(fontSize:13,letterSpacing:2,fontWeight:FontWeight.w700)),
    Text('PERSONAL AI SYSTEM',style:TextStyle(fontSize:8,letterSpacing:2,color:muted)),
   ]),
  ]),actions:[IconButton(tooltip:'Configurações',onPressed:settings,icon:const Icon(Icons.tune_rounded,color:cyan)),const SizedBox(width:8)]),
  body:SafeArea(child:AnimatedSwitcher(duration:const Duration(milliseconds:300),switchInCurve:Curves.easeOutCubic,child:tab==0?homeView(key:const ValueKey('home')):catalog(key:const ValueKey('catalog')))),
  bottomNavigationBar:NavigationBar(height:68,backgroundColor:const Color(0xFF08121E),indicatorColor:cyan.withValues(alpha: .13),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
   NavigationDestination(icon:Icon(Icons.blur_circular_rounded),selectedIcon:Icon(Icons.blur_on_rounded,color:cyan),label:'Núcleo'),
   NavigationDestination(icon:Icon(Icons.grid_view_rounded),selectedIcon:Icon(Icons.grid_view_rounded,color:cyan),label:'Sistemas'),
  ]),
 );
 Widget homeView({Key? key})=>AnimatedBuilder(animation:intro,builder:(_,child)=>Opacity(opacity:intro.value,child:Transform.translate(offset:Offset(0,14*(1-intro.value)),child:child)),child:ListView(key:key,padding:const EdgeInsets.fromLTRB(20,18,20,28),children:[
  const _Eyebrow('SISTEMA DE INTELIGÊNCIA'),const SizedBox(height:8),
  const Text('À sua disposição.',style:TextStyle(fontSize:30,fontWeight:FontWeight.w300)),
  const SizedBox(height:5),const Text('Uma interface em evolução.',style:TextStyle(color:muted,fontSize:12)),
  Center(child:AnimatedBuilder(animation:motion,builder:(_,__)=>GestureDetector(
   onTap:coreInfo,
   onPanUpdate:(d)=>tilt=Offset((tilt.dx+d.delta.dx/500).clamp(-.35,.35),(tilt.dy+d.delta.dy/500).clamp(-.35,.35)),
   onPanEnd:(_)=>tilt=Offset.zero,
   child:SizedBox(width:330,height:330,child:CustomPaint(painter:HologramPainter(motion.value,tilt),child:const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(Icons.all_inclusive_rounded,color:cyan,size:48),SizedBox(height:8),
    Text('J.A.R.V.I.S.',style:TextStyle(letterSpacing:3.5,fontSize:16)),SizedBox(height:5),
    Text('NÚCLEO HOLOGRÁFICO',style:TextStyle(color:cyan,fontSize:8,letterSpacing:2)),SizedBox(height:12),
    Icon(Icons.touch_app_rounded,size:15,color:muted),
   ])))),
  ))),
  const _Heading('VISÃO GERAL','ESTADO DA INTERFACE'),const SizedBox(height:10),
  const _Status(icon:Icons.blur_circular_rounded,title:'Núcleo visual',detail:'Animação vetorial Flutter em execução',state:'ATIVO',color:Color(0xFF64E6B1)),
  const SizedBox(height:8),const _Status(icon:Icons.hub_rounded,title:'Serviços inteligentes',detail:'Pontes nativas ainda em migração',state:'PENDENTE',color:Color(0xFFFFC66D)),
  const SizedBox(height:8),const _Status(icon:Icons.widgets_rounded,title:'Módulos catalogados',detail:'21 áreas identificadas; integração não presumida',state:'CATÁLOGO',color:cyan),
  const SizedBox(height:18),const _Heading('ACESSO RÁPIDO','EXPLORAR'),const SizedBox(height:10),
  Row(children:[
   Expanded(child:_Quick(icon:Icons.grid_view_rounded,title:'Sistemas',subtitle:'Todos os módulos',onTap:()=>setState(()=>tab=1))),
   const SizedBox(width:10),Expanded(child:_Quick(icon:Icons.tune_rounded,title:'Ajustes',subtitle:'Preferências',onTap:settings)),
  ]),
  const SizedBox(height:16),const _Footnote('Os indicadores descrevem a interface Flutter. Não afirmam que os serviços externos já estejam conectados.'),
 ]));
 Widget catalog({Key? key}){
  final visible=modules.where((m)=>(filter=='Todos'||m.group==filter)&&'${m.name} ${m.group} ${m.description}'.toLowerCase().contains(query.toLowerCase())).toList();
  return ListView(key:key,padding:const EdgeInsets.fromLTRB(18,18,18,28),children:[
   const _Eyebrow('CENTRAL DE SISTEMAS'),const SizedBox(height:7),
   const Text('Capacidades do J.A.R.V.I.S.',style:TextStyle(fontSize:26,fontWeight:FontWeight.w300)),
   const SizedBox(height:6),const Text('Explore os módulos identificados no projeto.',style:TextStyle(color:muted,fontSize:12)),
   const SizedBox(height:16),TextField(controller:search,onChanged:(v)=>setState(()=>query=v),decoration:InputDecoration(
    hintText:'Buscar sistema ou função...',prefixIcon:const Icon(Icons.search_rounded,color:cyan),
    suffixIcon:query.isEmpty?null:IconButton(onPressed:(){search.clear();setState(()=>query='');},icon:const Icon(Icons.close)),
    filled:true,fillColor:panel,border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none),
   )),
   const SizedBox(height:12),SizedBox(height:38,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:groups.length,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(context,i){
    final g=groups[i],selected=g==filter;
    return ChoiceChip(label:Text(g),selected:selected,onSelected:(_)=>setState(()=>filter=g),labelStyle:TextStyle(fontSize:11,color:selected?cyan:muted),backgroundColor:panel,selectedColor:cyan.withValues(alpha: .12),side:BorderSide(color:selected?cyan.withValues(alpha: .45):Colors.white12),showCheckmark:false);
   })),
   const SizedBox(height:14),Row(children:[const _Eyebrow('MÓDULOS'),const Spacer(),Text('${visible.length} encontrados',style:const TextStyle(color:muted,fontSize:10))]),
   const SizedBox(height:10),
   if(visible.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Center(child:Text('Nenhum módulo encontrado.',style:TextStyle(color:muted)))),
   for(final m in visible)...[_ModuleTile(module:m,onTap:()=>openModule(m)),const SizedBox(height:8)],
   const _Footnote('Cada módulo será marcado como funcional somente após conexão com o serviço real e testes correspondentes.'),
  ]);
 }
 void coreInfo()=>showModalBottomSheet<void>(context:context,backgroundColor:panel,showDragHandle:true,builder:(_)=>const Padding(padding:EdgeInsets.fromLTRB(24,8,24,28),child:Column(mainAxisSize:MainAxisSize.min,children:[
  Icon(Icons.blur_circular_rounded,color:cyan,size:36),SizedBox(height:12),Text('Núcleo holográfico',style:TextStyle(fontSize:19)),
  SizedBox(height:8),Text('A animação responde ao toque e ao arraste. Captura de voz e execução de comandos dependem dos serviços nativos, ainda não conectados nesta tela.',textAlign:TextAlign.center,style:TextStyle(color:muted,height:1.5)),
 ])));
 void openModule(JarvisModule m)=>Navigator.push(context,PageRouteBuilder<void>(transitionDuration:const Duration(milliseconds:280),pageBuilder:(_,a,__)=>FadeTransition(opacity:a,child:ModulePage(module:m))));
 void settings()=>Navigator.push(context,PageRouteBuilder<void>(transitionDuration:const Duration(milliseconds:260),pageBuilder:(_,a,__)=>FadeTransition(opacity:a,child:const SettingsPage())));
}

class _Brand extends StatelessWidget{const _Brand();@override Widget build(BuildContext c)=>Container(width:31,height:31,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:cyan.withValues(alpha: .7)),boxShadow:[BoxShadow(color:cyan.withValues(alpha: .18),blurRadius:13)]),child:const Icon(Icons.all_inclusive_rounded,color:cyan,size:19));}
class _Eyebrow extends StatelessWidget{const _Eyebrow(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:const TextStyle(color:cyan,letterSpacing:2,fontSize:9,fontWeight:FontWeight.w700));}
class _Heading extends StatelessWidget{const _Heading(this.title,this.trailing);final String title,trailing;@override Widget build(BuildContext c)=>Row(children:[Text(title,style:const TextStyle(fontSize:10,letterSpacing:1.6,fontWeight:FontWeight.w700)),const Spacer(),Text(trailing,style:const TextStyle(fontSize:8,letterSpacing:1.2,color:muted))]);}
class _Status extends StatelessWidget{
 const _Status({required this.icon,required this.title,required this.detail,required this.state,required this.color});
 final IconData icon;final String title,detail,state;final Color color;
 @override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(13),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(15),border:Border.all(color:Colors.white.withValues(alpha: .055))),child:Row(children:[
  Container(width:37,height:37,decoration:BoxDecoration(color:color.withValues(alpha: .1),borderRadius:BorderRadius.circular(11)),child:Icon(icon,color:color,size:19)),
  const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(detail,style:const TextStyle(fontSize:10,color:muted))])),
  const SizedBox(width:7),Text(state,style:TextStyle(color:color,fontSize:8,letterSpacing:.8,fontWeight:FontWeight.w700)),
 ]));
}
class _Quick extends StatelessWidget{
 const _Quick({required this.icon,required this.title,required this.subtitle,required this.onTap});
 final IconData icon;final String title,subtitle;final VoidCallback onTap;
 @override Widget build(BuildContext c)=>Material(color:panel,borderRadius:BorderRadius.circular(15),child:InkWell(borderRadius:BorderRadius.circular(15),onTap:onTap,child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
  Icon(icon,color:cyan,size:22),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:muted,fontSize:9))])),
  const Icon(Icons.chevron_right_rounded,color:muted,size:18),
 ]))));
}
class _ModuleTile extends StatelessWidget{
 const _ModuleTile({required this.module,required this.onTap});final JarvisModule module;final VoidCallback onTap;
 @override Widget build(BuildContext c)=>Material(color:panel,borderRadius:BorderRadius.circular(14),child:InkWell(borderRadius:BorderRadius.circular(14),onTap:onTap,child:Padding(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),child:Row(children:[
  Container(width:39,height:39,decoration:BoxDecoration(color:cyan.withValues(alpha: .09),borderRadius:BorderRadius.circular(12)),child:Icon(module.icon,color:cyan,size:20)),
  const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(module.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(module.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:muted))])),
  const SizedBox(width:8),const Icon(Icons.arrow_forward_ios_rounded,size:12,color:muted),
 ]))));
}
class ModulePage extends StatelessWidget{
 const ModulePage({super.key,required this.module});final JarvisModule module;
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(module.name,style:const TextStyle(fontSize:15))),body:ListView(padding:const EdgeInsets.all(22),children:[
  Container(height:145,decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[cyan.withValues(alpha: .15),const Color(0xFF368BFF).withValues(alpha: .06),panel]),border:Border.all(color:cyan.withValues(alpha: .18))),child:Icon(module.icon,color:cyan,size:58)),
  const SizedBox(height:22),_Eyebrow(module.group.toUpperCase()),const SizedBox(height:7),Text(module.name,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w300)),
  const SizedBox(height:9),Text(module.description,style:const TextStyle(color:muted,height:1.5)),const SizedBox(height:22),
  Container(padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:const Color(0xFF211A10),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFFFC66D).withValues(alpha: .22))),child:const Row(children:[
   Icon(Icons.pending_outlined,color:Color(0xFFFFC66D)),SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Integração em auditoria',style:TextStyle(color:Color(0xFFFFC66D),fontWeight:FontWeight.w600)),SizedBox(height:4),
    Text('A presença no catálogo não comprova que o serviço esteja conectado ou operacional nesta interface.',style:TextStyle(color:muted,fontSize:11,height:1.4)),
   ])),
  ])),
 ]));
}
class SettingsPage extends StatelessWidget{
 const SettingsPage({super.key});
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Configurações',style:TextStyle(fontSize:15))),body:ListView(padding:const EdgeInsets.all(20),children:[
  const _Eyebrow('PREFERÊNCIAS DO SISTEMA'),const SizedBox(height:8),const Text('Central de ajustes',style:TextStyle(fontSize:27,fontWeight:FontWeight.w300)),
  const SizedBox(height:7),const Text('A tela nativa está sendo preparada. Nenhum controle simula gravação de configuração.',style:TextStyle(color:muted,fontSize:11,height:1.5)),
  const SizedBox(height:18),
  const _Setting(icon:Icons.key_rounded,title:'Credenciais e provedores',detail:'Ponte segura com Android Keystore e armazenamento protegido no Windows pendente.'),
  const _Setting(icon:Icons.graphic_eq_rounded,title:'Voz e palavra de ativação',detail:'Integração KWS local ainda precisa ser ligada. Picovoice não será utilizado.'),
  const _Setting(icon:Icons.memory_rounded,title:'Memória e Obsidian',detail:'Seleção do cofre, sincronização e memória semântica pendentes.'),
  const _Setting(icon:Icons.shield_outlined,title:'Privacidade e permissões',detail:'Permissões conforme as APIs e o sistema operacional.'),
  const _Setting(icon:Icons.devices_rounded,title:'Dispositivos conectados',detail:'Pareamento Android–Windows, ESP32 e Home Assistant pendentes.'),
 ]));
}
class _Setting extends StatelessWidget{
 const _Setting({required this.icon,required this.title,required this.detail});final IconData icon;final String title,detail;
 @override Widget build(BuildContext c)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(14)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Icon(icon,color:cyan,size:21),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:muted,fontSize:10,height:1.45))])),
 ]));
}
class _Footnote extends StatelessWidget{const _Footnote(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:const TextStyle(color:Color(0xFF63798B),fontSize:9,height:1.5));}

class HologramPainter extends CustomPainter{
 HologramPainter(this.t,this.pointer);final double t;final Offset pointer;
 @override void paint(Canvas canvas,Size size){
  final c=Offset(size.width/2+pointer.dx*22,size.height/2+pointer.dy*18);
  final r=size.shortestSide*.37,spin=t*math.pi*2;
  final glow=Paint()..shader=RadialGradient(colors:[cyan.withValues(alpha: .13),const Color(0xFF368BFF).withValues(alpha: .035),Colors.transparent]).createShader(Rect.fromCircle(center:c,radius:r*1.2));
  canvas.drawCircle(c,r*1.2,glow);
  // Anéis em coordenadas 3D projetadas em perspectiva no Canvas.
  // A rotação em X/Y e a profundidade variam com o tempo e com o arraste.
  const ringScale=<double>[.57,.75,.93,1.08];
  for(var ring=0;ring<ringScale.length;ring++){
   final path=Path();
   final p=Paint()..style=PaintingStyle.stroke..strokeWidth=(ring==0?2.0:1.0)..color=cyan.withValues(alpha:.88-ring*.16)..strokeCap=StrokeCap.round;
   final radius=r*ringScale[ring];
   final ay=spin*(ring.isEven ? .18 : -.14)+pointer.dx*.8+ring*.45;
   final ax=.62+pointer.dy*.65+ring*.17;
   final cy=math.cos(ay),sy=math.sin(ay),cx=math.cos(ax),sx=math.sin(ax);
   for(var step=0;step<=96;step++){
    final a=step*math.pi*2/96;
    final x=math.cos(a)*radius;
    final y=math.sin(a)*radius;
    final z=math.sin(a*2+ring)*radius*.19;
    final x1=x*cy+z*sy;
    final z1=-x*sy+z*cy;
    final y1=y*cx-z1*sx;
    final z2=y*sx+z1*cx;
    final perspective=(r*3.8)/(r*3.8+z2);
    final point=Offset(c.dx+x1*perspective,c.dy+y1*perspective);
    if(step==0){path.moveTo(point.dx,point.dy);}else{path.lineTo(point.dx,point.dy);}
   }
   canvas.drawPath(path,p);
  }
  // Pontos orbitais também recebem profundidade e escala de perspectiva.
  final dots=Paint()..color=cyan.withValues(alpha:.9);
  for(var i=0;i<48;i++){
   final a=i*math.pi*2/48+spin*.28;
   final x=math.cos(a)*r*.88;
   final y=math.sin(a)*r*.88;
   final z=math.sin(a*2+spin)*r*.2;
   final depth=(r*3.8)/(r*3.8+z);
   final point=Offset(c.dx+x*depth,c.dy+y*.82*depth);
   canvas.drawCircle(point,(i%4==0?2.2:1.1)*depth,dots);
  }
  final core=Paint()..shader=RadialGradient(colors:[cyan.withValues(alpha: .24),const Color(0xFF368BFF).withValues(alpha: .09),Colors.transparent]).createShader(Rect.fromCircle(center:c,radius:r*.46));
  canvas.drawCircle(c,r*.46,core);
  final inner=Paint()..style=PaintingStyle.stroke..strokeWidth=1.2..color=cyan.withValues(alpha: .55);canvas.drawCircle(c,r*(.29+.012*math.sin(spin*2)),inner);
  final scan=Paint()..color=cyan.withValues(alpha: .12)..strokeWidth=1;
  for(var i=-4;i<=4;i++){final y=c.dy+i*13+math.sin(spin+i)*2;canvas.drawLine(Offset(c.dx-r*.3,y),Offset(c.dx+r*.3,y),scan);}
  final marks=Paint()..color=cyan.withValues(alpha: .3)..strokeWidth=.8;
  canvas.drawLine(Offset(c.dx-r*1.12,c.dy),Offset(c.dx-r*.98,c.dy),marks);canvas.drawLine(Offset(c.dx+r*.98,c.dy),Offset(c.dx+r*1.12,c.dy),marks);
  canvas.drawLine(Offset(c.dx,c.dy-r*1.12),Offset(c.dx,c.dy-r*.98),marks);canvas.drawLine(Offset(c.dx,c.dy+r*.98),Offset(c.dx,c.dy+r*1.12),marks);
 }
 @override bool shouldRepaint(covariant HologramPainter old)=>old.t!=t||old.pointer!=pointer;
}
