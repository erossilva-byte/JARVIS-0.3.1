import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'services/provider_service.dart';
import 'services/kws_settings_page.dart';
import 'services/kws_controller.dart';
import 'services/kws_bridge.dart';
import 'services/voice_conversation_page.dart';

final jarvisKwsController = KwsController();

void main()=>runApp(const JarvisApp());
const cyan=Color(0xFF55DFFF),bg=Color(0xFF050A12),panel=Color(0xFF0B1725),muted=Color(0xFF8CA5B9);

class JarvisApp extends StatelessWidget{
 const JarvisApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'J.A.R.V.I.S. Nova',theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:cyan,brightness:Brightness.dark),useMaterial3:true),home:const LegacyHomeScreen());
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
