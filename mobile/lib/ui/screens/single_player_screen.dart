import 'package:flutter/material.dart';

import '../../state/table_client.dart';
import 'table_screen.dart';

/// You against three bots, entirely on this device.
class SinglePlayerScreen extends StatefulWidget {
  const SinglePlayerScreen({super.key, this.createClient});

  /// For tests: supply the client instead of a fresh [LocalTableClient].
  final TableClient Function()? createClient;

  @override
  State<SinglePlayerScreen> createState() => _SinglePlayerScreenState();
}

class _SinglePlayerScreenState extends State<SinglePlayerScreen> {
  late final TableClient _client =
      widget.createClient?.call() ?? LocalTableClient();

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TableScreen(client: _client);
}
