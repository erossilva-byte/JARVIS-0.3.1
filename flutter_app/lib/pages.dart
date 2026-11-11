import 'package:flutter/material.dart';
import 'catalog.dart';
import 'provider_settings_page.dart';
import 'services/kws_controller.dart';
import 'services/kws_settings_page.dart';
import 'ui_common.dart';

class ModulePage extends StatelessWidget{
 const ModulePage({super.key,required this.module});final JarvisModule module;
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(module.name,style:const TextStyle(fontSize:15))),body:ListView(padding:const EdgeInsets.all(22),children:[
  Container(height:145,decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[cyan.withValues(alpha: .15),const Color(0xFF368BFF).withValues(alpha: .06),panel]),border:Border.all(color:cyan.withValues(alpha: .18))),child:Icon(module.icon,color:cyan,size:58)),
  const SizedBox(height:22),Eyebrow(module.group.toUpperCase()),const SizedBox(height:7),Text(module.name,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w300)),
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
 const SettingsPage({super.key,this.controller});
 final KwsController? controller;
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Configurações',style:TextStyle(fontSize:15))),body:ListView(padding:const EdgeInsets.all(20),children:[
  const Eyebrow('PREFERÊNCIAS DO SISTEMA'),const SizedBox(height:8),const Text('Central de ajustes',style:TextStyle(fontSize:27,fontWeight:FontWeight.w300)),
  const SizedBox(height:7),const Text('Credenciais dos provedores são protegidas pelo armazenamento seguro da plataforma. Outros serviços serão habilitados quando suas pontes nativas estiverem validadas.',style:TextStyle(color:muted,fontSize:11,height:1.5)),
  const SizedBox(height:18),
  Material(color:panel,borderRadius:BorderRadius.circular(14),child:ListTile(
   leading:const Icon(Icons.key_rounded,color:cyan),title:const Text('Provedores de IA',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
   subtitle:const Text('Cadastrar, testar e remover chaves com armazenamento seguro',style:TextStyle(color:muted,fontSize:10)),
   trailing:const Icon(Icons.chevron_right_rounded,color:muted),
   onTap:()=>Navigator.of(c).push(MaterialPageRoute<void>(builder:(_)=>const ProviderSettingsPage())),
  )),
  const SizedBox(height:9),
  Material(color:panel,borderRadius:BorderRadius.circular(14),child:ListTile(
   leading:const Icon(Icons.graphic_eq_rounded,color:cyan),
   title:const Text('Voz e palavra de ativação',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
   subtitle:const Text('Controlar KWS sherpa-onnx local, testar e consultar diagnóstico',style:TextStyle(color:muted,fontSize:10)),
   trailing:const Icon(Icons.chevron_right_rounded,color:muted),
   onTap:()=>Navigator.of(c).push(MaterialPageRoute<void>(builder:(_)=>KwsSettingsPage(controller:controller))),
  )),
  const SettingCard(icon:Icons.memory_rounded,title:'Memória semântica e Obsidian',detail:'A migração precisa preservar notas e IDs, integrar busca vetorial multilíngue e sincronização bidirecional sem duplicações.'),
  const SettingCard(icon:Icons.shield_outlined,title:'Privacidade e permissões',detail:'As permissões serão solicitadas somente quando uma função real precisar delas.'),
  const SettingCard(icon:Icons.devices_rounded,title:'Dispositivos conectados',detail:'O pareamento QR Android–Windows precisa de autenticação mútua, criptografia, expiração, escopos e revogação. ESP32 fica fora desta sequência.'),
 ]));
}
