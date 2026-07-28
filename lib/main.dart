import 'package:flutter/material.dart';

void main() {
  runApp(const CabineFlowApp());
}

class CabineFlowApp extends StatelessWidget {
  const CabineFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF173B57);

    return MaterialApp(
      title: 'CabineFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    size: 44,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'CabineFlow',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vos commandes,\nsimplement organisées.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF627D98),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Le projet Flutter CabineFlow est correctement initialisé.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('CabineFlow est prêt à être développé.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Commencer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Version d’apprentissage - MVP 1',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFF829AB1)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
