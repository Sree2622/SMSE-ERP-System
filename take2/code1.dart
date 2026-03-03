import 'package:flutter/material.dart';
void main()
{
 runApp(DCE());
}

class DCE extends StatelessWidget 
{  
 const DCE({super.key});
 @override
 Widget build(BuildContext context) 
 {
  return MaterialApp
	(
 	home :Scaffold
	  	(
 	    	body:    BoundedBox( children: [
						GridView.count (
						crossAxisCount :2,
						children : [Text('Reddit'),Text('twitter'),Text('Instagram'),Text('Youtube')]
						),
						Align (
						alignment: Alignment.center,
      						child: Text('Prime Video')
						)				
					
				]	    )
				
			
		)
	);

 }	

}

