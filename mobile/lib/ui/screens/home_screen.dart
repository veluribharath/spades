import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '♠',
                  style: TextStyle(fontSize: 96, color: AppColors.gold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Spades',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Classic partnership spades',
                  style: TextStyle(color: AppColors.cream),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TableScreen()),
                    );
                  },
                  child: const Text('New game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
