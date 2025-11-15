import 'package:flutter/material.dart';

class ImageBackground extends StatefulWidget {
  int imageType =1;
  Widget child;
  String image = "";
   ImageBackground({super.key, this.imageType = 1, required this.child, this.image = ""});

  @override
  State<ImageBackground> createState() => _ImageBackgroundState();
}

class _ImageBackgroundState extends State<ImageBackground> {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: double.infinity,
        width: double.infinity,
        
        decoration: BoxDecoration(
         // color: Colors.yellow.withOpacity(1),
          
          image: DecorationImage(
            opacity: 0.5,
            image:
            widget.imageType == 1?
             AssetImage(widget.image.length >10?widget.image: "assets/images/bg_4.jpg")
             :
            AssetImage("assets/images/bg_4.jpg")

             ,
            fit: BoxFit.fill
            ),
            
            
        ),
        child:widget.child
        );
  }
}