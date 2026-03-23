import 'package:flutter/material.dart';

class MotorAvatar extends StatefulWidget {

  final bool overheating;
  final bool vibrating;

  const MotorAvatar({
    super.key,
    required this.overheating,
    required this.vibrating
  });

  @override
  State<MotorAvatar> createState() => _MotorAvatarState();

}

class _MotorAvatarState extends State<MotorAvatar>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState(){

    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds:200)
    );

    controller.repeat(reverse:true);

  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context){

    double shake = widget.vibrating ? 6 : 0;

    Color color =
        widget.overheating ? Colors.red : Colors.blue;

    return AnimatedBuilder(

      animation: controller,

      builder:(context,child){

        double dx =
            widget.vibrating
            ? (controller.value - 0.5) * shake
            : 0;

        return Transform.translate(

          offset: Offset(dx,0),

          child: Container(

            height:160,
            width:160,

            decoration: BoxDecoration(

              shape: BoxShape.circle,

              border: Border.all(
                color: color,
                width:4
              ),

            ),

            child: Icon(
              Icons.settings,
              size:80,
              color: color
            ),

          ),

        );

      },

    );

  }

}
