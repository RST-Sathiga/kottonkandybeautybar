import 'package:flutter/material.dart';
import 'screens/auth/register.dart';


void main() {
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: "Kotton Kandy",

      theme: ThemeData(
        fontFamily: "Poppins",
      ),


      home: const Register(),

    );

  }
}