import 'package:flutter/material.dart';

class AdaptiveForm extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool saving;
  const AdaptiveForm({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.saving = false,
  });
  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).width < 700;
    final content = PopScope(
      canPop: !saving,
      child: SafeArea(
        child: Column(
          mainAxisSize: small ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.centerRight,
                child: OverflowBar(
                  spacing: 12,
                  overflowSpacing: 8,
                  children: actions,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return small
        ? Dialog.fullscreen(child: content)
        : Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
              child: content,
            ),
          );
  }
}
