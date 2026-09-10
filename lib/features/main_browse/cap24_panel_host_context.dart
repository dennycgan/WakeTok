import 'package:flutter/material.dart';

/// Browse [BuildContext] captured before the Cap 24 more modal sheet opens.
///
/// Used for root-overlay toasts that must paint above the half-sheet.
class Cap24PanelHostContext extends InheritedWidget {
  const Cap24PanelHostContext({
    super.key,
    required this.hostContext,
    required super.child,
  });

  final BuildContext hostContext;

  static BuildContext of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<Cap24PanelHostContext>();
    assert(
      scope != null,
      'Cap24PanelHostContext not found above panel widgets',
    );
    return scope!.hostContext;
  }

  @override
  bool updateShouldNotify(Cap24PanelHostContext oldWidget) =>
      hostContext != oldWidget.hostContext;
}
