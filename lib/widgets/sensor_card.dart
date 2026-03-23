import 'package:flutter/material.dart';

class SensorCard extends StatelessWidget {

  final String title;
  final String value;
  final IconData icon;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon
  });

  @override
  Widget build(BuildContext context){

    return Card(

      elevation:4,

      child: Container(

        width:150,
        padding: EdgeInsets.all(16),

        child: Column(

          children:[

            Icon(icon,size:30),

            SizedBox(height:10),

            Text(
              title,
              style: TextStyle(fontWeight:FontWeight.bold)
            ),

            SizedBox(height:6),

            Text(
              value,
              style: TextStyle(fontSize:20)
            )

          ]

        )

      )

    );

  }

}