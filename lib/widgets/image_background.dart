import 'package:flutter/material.dart';

class ImageBackground extends StatefulWidget {
  int imageType =1;
  Widget child;
   ImageBackground({super.key, this.imageType = 1, required this.child});

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
          
          image: DecorationImage(
            opacity: 0.5,
            image:
            widget.imageType == 1?
             NetworkImage("https://mir-s3-cdn-cf.behance.net/projects/404/94f82a183274935.653c9e234b628.jpg")
             :
            NetworkImage("https://mir-s3-cdn-cf.behance.net/projects/404/94f82a183274935.653c9e234b628.jpg")

             ,
            fit: BoxFit.fill
            ),
            
            
        ),
        child:widget.child
        );
  }
}