import 'package:flutter/material.dart';
import 'catalog.dart';
import 'services/kws_controller.dart';

/// Cores oficiais da interface.
const cyan=Color(0xFF55DFFF),bg=Color(0xFF050A12),panel=Color(0xFF0B1725),muted=Color(0xFF8CA5B9);

/// Controlador único do detector local, compartilhado por todas as telas.
final jarvisKwsController = KwsController();

class BrandMark extends StatelessWidget{const BrandMark();@override Widget build(BuildContext c)=>Container(width:31,height:31,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:cyan.withValues(alpha: .7)),boxShadow:[BoxShadow(color:cyan.withValues(alpha: .18),blurRadius:13)]),child:const Icon(Icons.all_inclusive_rounded,color:cyan,size:19));}
class Eyebrow extends StatelessWidget{const Eyebrow(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:const TextStyle(color:cyan,letterSpacing:2,fontSize:9,fontWeight:FontWeight.w700));}
class ModuleTile extends StatelessWidget{
 const ModuleTile({required this.module,required this.onTap});final JarvisModule module;final VoidCallback onTap;
 @override Widget build(BuildContext c)=>Material(color:panel,borderRadius:BorderRadius.circular(14),child:InkWell(borderRadius:BorderRadius.circular(14),onTap:onTap,child:Padding(padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),child:Row(children:[
  Container(width:39,height:39,decoration:BoxDecoration(color:cyan.withValues(alpha: .09),borderRadius:BorderRadius.circular(12)),child:Icon(module.icon,color:cyan,size:20)),
  const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(module.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:3),Text(module.description,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,color:muted))])),
  const SizedBox(width:8),const Icon(Icons.arrow_forward_ios_rounded,size:12,color:muted),
 ]))));
}
class SettingCard extends StatelessWidget{
 const SettingCard({required this.icon,required this.title,required this.detail});final IconData icon;final String title,detail;
 @override Widget build(BuildContext c)=>Container(margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(14)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Icon(icon,color:cyan,size:21),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),const SizedBox(height:5),Text(detail,style:const TextStyle(color:muted,fontSize:10,height:1.45))])),
 ]));
}
class FootnoteText extends StatelessWidget{const FootnoteText(this.text);final String text;@override Widget build(BuildContext c)=>Text(text,style:const TextStyle(color:Color(0xFF63798B),fontSize:9,height:1.5));}
