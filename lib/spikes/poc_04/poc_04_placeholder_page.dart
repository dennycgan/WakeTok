import 'package:flutter/material.dart';
import 'package:waketok/spikes/poc_04/poc_04_entry.dart';

/// POC-04 Phase 2.1: spike scaffold placeholder (no Photos / Pigeon yet).
class Poc04PlaceholderPage extends StatelessWidget {
  const Poc04PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POC-04 spike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'POC-04 · Phase 2.1',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Spike scaffold only. Photos authorization and asset listing '
              'arrive in phase 2.2.',
            ),
            if (!canPop && kPoc04SpikeAsHome) ...[
              const SizedBox(height: 8),
              Text(
                'Opened as home via POC04_SPIKE=true (no back). '
                'Re-run without the define to use Demo home + POC-04 button.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
