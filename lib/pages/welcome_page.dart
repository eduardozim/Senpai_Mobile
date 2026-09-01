import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'menu_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Marca d'água repetida preenchendo o fundo
          Opacity(
            opacity: 0.03, // Ainda mais sutil por ser repetido
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/mon-bunbukan.png'),
                  repeat: ImageRepeat.repeat,
                  scale: 4.0, // Ajuste o tamanho da repetição aqui
                ),
              ),
            ),
          ),
          // Conteúdo da tela
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Kanji "Senpai"
                Text(
                  '先輩',
                  style: GoogleFonts.notoSerifJp(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    shadows: [
                      Shadow(
                        blurRadius: 2,
                        color: Colors.grey.shade400,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'SenpAI Mobile',
                  style: GoogleFonts.notoSans(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const MenuPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                        side: BorderSide(color: Colors.black, width: 1),
                      ),
                    ),
                    child: const Text(
                      'ENTRAR',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
