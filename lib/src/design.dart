import 'package:flutter/material.dart';

/// Light (Mint colors) or dark. Both use the same flat metric-grid layout and
/// pages; only the colors change.
enum AppDesign {
  light('Light'),
  dark('Dark');

  const AppDesign(this.label);

  final String label;

  AppDesign get other => this == light ? dark : light;

  /// Matches the device's current light/dark setting.
  static AppDesign fromSystem() =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      ? dark
      : light;
}

class DesignController extends ValueNotifier<AppDesign> {
  DesignController([super.value = AppDesign.light]);

  void toggle() => value = value.other;
}

class DesignScope extends InheritedNotifier<DesignController> {
  const DesignScope({
    super.key,
    required DesignController controller,
    required super.child,
  }) : super(notifier: controller);

  static DesignController controllerOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignScope>()!.notifier!;

  /// The active design; defaults to light outside a scope (e.g. tests).
  static AppDesign of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DesignScope>()
          ?.notifier
          ?.value ??
      AppDesign.light;
}

/// Button that switches between light (Mint) and dark mode.
class DesignSwitchButton extends StatelessWidget {
  const DesignSwitchButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DesignScope.controllerOf(context);
    final toDark = controller.value == AppDesign.light;
    return IconButton(
      tooltip: 'Switch to ${controller.value.other.label.toLowerCase()} mode',
      onPressed: controller.toggle,
      icon: Icon(toDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
    );
  }
}
