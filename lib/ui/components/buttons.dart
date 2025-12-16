import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.onPressed, required this.label, this.icon});
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    return icon == null
        ? FilledButton(onPressed: onPressed, child: child)
        : FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.onPressed, required this.label, this.icon});
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    return icon == null
        ? OutlinedButton(onPressed: onPressed, child: child)
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
  }
}

class GhostIconButton extends StatelessWidget {
  const GhostIconButton({super.key, required this.icon, this.tooltip, this.onPressed});
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final btn = IconButton(onPressed: onPressed, icon: Icon(icon));
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
