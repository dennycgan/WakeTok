import 'package:flutter/material.dart';

/// Browse [BuildContext] captured before the Cap 19 modal sheet opens.
///
/// Used for root-overlay toasts that must paint above the half-sheet.
class Cap19PanelHostContext extends InheritedWidget {
  const Cap19PanelHostContext({
    super.key,
    required this.hostContext,
    required super.child,
  });

  final BuildContext hostContext;

  static BuildContext of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<Cap19PanelHostContext>();
    assert(
      scope != null,
      'Cap19PanelHostContext not found above panel widgets',
    );
    return scope!.hostContext;
  }

  @override
  bool updateShouldNotify(Cap19PanelHostContext oldWidget) =>
      hostContext != oldWidget.hostContext;
}
