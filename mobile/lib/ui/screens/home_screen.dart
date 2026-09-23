import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/suit_glyph.dart';
import 'table_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: feltTableDecoration(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const SpadeMonogram(size: 112),
                    const SizedBox(height: 28),
                    Text('Spades', style: AppText.display(size: 64)),
                    const SizedBox(height: 12),
                    Text(
                      'One card to thirteen',
                      style: AppText.display(
                        size: 20,
                        weight: FontWeight.w500,
                        color: AppColors.sage,
                        style: FontStyle.italic,
                      ),
                    ),
                    const Spacer(flex: 4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TableScreen(),
                            ),
                          );
                        },
                        child: const Text('New game'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'YOU & NORTH  ·  VS  ·  WEST & EAST',
                      style: AppText.label(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
