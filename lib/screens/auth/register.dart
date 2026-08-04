import 'package:flutter/material.dart';

class Register extends StatelessWidget {
  const Register({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffE8E6ED),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),

            child: Column(
              children: [

                const SizedBox(height: 40),

                // Title
                const Text(
                  "REGISTER",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 35),


                // Profile Icon
                Container(
                  height: 90,
                  width: 90,

                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      )
                    ],
                  ),

                  child: const Icon(
                    Icons.person,
                    size: 45,
                    color: Color(0xff8E44AD),
                  ),
                ),


                const SizedBox(height: 45),


                // Name
                inputField(
                  hint: "Name:",
                  icon: Icons.person_outline,
                ),


                const SizedBox(height: 18),


                // Email
                inputField(
                  hint: "Email:",
                  icon: Icons.email_outlined,
                ),


                const SizedBox(height: 18),


                // Cell Number
                inputField(
                  hint: "Cell no.",
                  icon: Icons.phone_outlined,
                ),


                const SizedBox(height: 18),


                // Password
                inputField(
                  hint: "Password:",
                  icon: Icons.lock_outline,
                  obscure: true,
                ),


                const SizedBox(height: 18),


                // Confirm Password
                inputField(
                  hint: "Confirm Password:",
                  icon: Icons.lock_outline,
                  obscure: true,
                ),


                const SizedBox(height: 45),


                // Register Button
                Container(
                  height: 45,
                  width: 150,

                  decoration: BoxDecoration(
                    color: const Color(0xffC2185B),

                    borderRadius: BorderRadius.circular(30),

                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      )
                    ],
                  ),


                  child: TextButton(
                    onPressed: () {

                    },

                    child: const Text(
                      "REGISTER",

                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),


                const SizedBox(height: 40),


                // Login navigation
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },

                  child: const Text(
                    "Already have an account? LOGIN",

                    style: TextStyle(
                      color: Colors.black87,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }


  // Reusable Input Field
  static Widget inputField({
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Container(

      height: 55,

      decoration: BoxDecoration(

        color: const Color(0xffD96BB5),

        borderRadius: BorderRadius.circular(30),

      ),


      child: TextField(

        obscureText: obscure,


        decoration: InputDecoration(

          hintText: hint,


          hintStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),


          prefixIcon: Icon(
            icon,
            color: Colors.black87,
          ),


          border: InputBorder.none,


          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
          ),

        ),

      ),

    );
  }
}