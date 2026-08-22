import 'package:flutter/material.dart';

/// The root widget.
///
/// A placeholder for now: EPIC-02 attaches the Daybreak theme, EPIC-03 the
/// localization delegates, and EPIC-06 replaces this with `MaterialApp.router`.
class NearlyStopApp extends StatelessWidget {
  /// Creates the root widget.
  const NearlyStopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'NearlyStop',
      home: Scaffold(body: Center(child: Text('NearlyStop'))),
    );
  }
}
