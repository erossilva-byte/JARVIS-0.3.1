import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'ui_common.dart';

export 'catalog.dart';
export 'ui_common.dart' show jarvisKwsController, cyan, bg, panel, muted;

void main()=>runApp(const JarvisApp());

class JarvisApp extends StatelessWidget{
 const JarvisApp({super.key});
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'J.A.R.V.I.S. Nova',theme:ThemeData(brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:cyan,brightness:Brightness.dark),useMaterial3:true),home:const LegacyHomeScreen());
}
