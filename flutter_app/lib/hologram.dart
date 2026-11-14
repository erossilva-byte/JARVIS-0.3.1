import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ui_common.dart';

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
