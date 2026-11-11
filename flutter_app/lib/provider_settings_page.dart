import 'package:flutter/material.dart';
import 'services/provider_service.dart';
import 'ui_common.dart';

class ProviderSettingsPage extends StatefulWidget{
 const ProviderSettingsPage({super.key});
 @override State<ProviderSettingsPage> createState()=>_ProviderSettingsPageState();
}
class _ProviderSettingsPageState extends State<ProviderSettingsPage>{
 late final ProviderService service=ProviderService(secrets:PlatformSecretStore());
 final Map<String,TextEditingController> fields={};
 final Map<String,bool> configured={};
 final Map<String,String> messages={};
 final Set<String> busy={};
 @override void initState(){super.initState();for(final p in aiProviders){fields[p.id]=TextEditingController();} _load();}
 Future<void> _load() async{
  for(final p in aiProviders){
   try{final value=await service.isConfigured(p.id);if (mounted) { setState(() => configured[p.id] = value); }}
   catch(_){if (mounted) { setState(() => messages[p.id] = 'Armazenamento seguro indisponível nesta plataforma.'); }}
  }
 }
 Future<void> _save(AiProvider p) async{
  final value=fields[p.id]!.text;
  if(value.trim().isEmpty){setState(()=>messages[p.id]='Informe a chave antes de salvar.');return;}
  setState(()=>busy.add(p.id));
  try{
   await service.saveKey(p.id,value);
   fields[p.id]!.clear();
   if (mounted) { setState(() { configured[p.id] = true; messages[p.id] = 'Chave armazenada no cofre seguro. Teste a conexão para validar o acesso.'; }); }
  }catch(e){
   if (mounted) { setState(() => messages[p.id] = e.toString().replaceFirst('Invalid argument(s): ', '')); }
  }finally{if (mounted) { setState(() => busy.remove(p.id)); }}
 }
 Future<void> _test(AiProvider p) async{
  setState((){busy.add(p.id);messages[p.id]='Testando conexão…';});
  try{
   final result=await service.testConnection(p.id);
   if (mounted) { setState(() => messages[p.id] = result.ok ? 'Conexão confirmada. Modelo: ${result.model}' : result.message); }
  }finally{if (mounted) { setState(() => busy.remove(p.id)); }}
 }
 Future<void> _remove(AiProvider p) async{
  setState(()=>busy.add(p.id));
  try{
   await service.removeKey(p.id);
   if (mounted) { setState(() { configured[p.id] = false; messages[p.id] = 'Chave removida do cofre seguro.'; }); }
  }catch(_){if (mounted) { setState(() => messages[p.id] = 'Não foi possível remover a chave do armazenamento seguro.'); }}
  finally{if (mounted) { setState(() => busy.remove(p.id)); }}
 }
 @override void dispose(){for(final field in fields.values){field.dispose();}service.close();super.dispose();}
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('Provedores de IA',style:TextStyle(fontSize:15))),
  body:ListView(padding:const EdgeInsets.all(16),children:[
   const Eyebrow('PRIORIDADE DE ROTEAMENTO'),const SizedBox(height:7),
   const Text('Groq é o provedor principal. Os demais ficam disponíveis como alternativas configuradas individualmente.',style:TextStyle(color:muted,fontSize:11,height:1.5)),
   const SizedBox(height:14),
   for(final provider in aiProviders)...[
    Container(padding:const EdgeInsets.all(14),margin:const EdgeInsets.only(bottom:11),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(15),border:Border.all(color:provider.id=='groq'?cyan.withValues(alpha:.4):Colors.white12)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[Expanded(child:Text(provider.name,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700))),Text(configured[provider.id]==true?'CONFIGURADO':'SEM CHAVE',style:TextStyle(fontSize:8,letterSpacing:1,color:configured[provider.id]==true?const Color(0xFF64E6B1):muted))]),
     const SizedBox(height:4),Text('Modelo de teste: ${provider.model}',style:const TextStyle(fontSize:9,color:muted)),
     const SizedBox(height:10),
     TextField(controller:fields[provider.id],obscureText:true,autocorrect:false,enableSuggestions:false,decoration:InputDecoration(hintText:'Cole a chave de API',hintStyle:const TextStyle(fontSize:11),filled:true,fillColor:bg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:11))),
     const SizedBox(height:10),
     Wrap(spacing:8,runSpacing:6,children:[
      FilledButton.tonal(onPressed:busy.contains(provider.id)?null:()=>_save(provider),child:const Text('Salvar chave')),
      OutlinedButton(onPressed:busy.contains(provider.id)||configured[provider.id]!=true?null:()=>_test(provider),child:const Text('Testar conexão')),
      TextButton(onPressed:busy.contains(provider.id)||configured[provider.id]!=true?null:()=>_remove(provider),child:const Text('Remover')),
     ]),
     if(messages[provider.id]!=null)...[const SizedBox(height:7),Text(messages[provider.id]!,style:TextStyle(fontSize:10,height:1.4,color:messages[provider.id]!.contains('confirmada')||messages[provider.id]!.contains('armazenada')||messages[provider.id]!.contains('removida')?const Color(0xFF64E6B1):const Color(0xFFFFC66D)))],
    ])),
   ],
   const FootnoteText('As chaves nunca são exibidas novamente nem incluídas em logs. O teste envia uma solicitação mínima ao provedor selecionado e pode gerar cobrança de tokens.'),
  ]),
 );
}
