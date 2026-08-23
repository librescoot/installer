import 'package:flutter/material.dart';

import '../theme.dart';

/// Which way an action moves the user through the installer.
enum ActionSide {
  /// Carries on along the install path: continue, skip, retry, proceed
  /// despite a failed check. Sits on the right.
  forward,

  /// Leaves the path: back, cancel, abort. Sits on the left.
  back,
}

/// One action in a phase's bottom bar.
///
/// Screens describe what the action is, not how it should look. Every screen
/// used to pick its own widget, so "continue" was a filled button on one
/// screen and the same weight as body text on another, and the secondary
/// choices ended up as bare grey labels that did not read as buttons at all.
class PhaseAction {
  const PhaseAction({
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = false,
    this.danger = false,
    this.side = ActionSide.forward,
    this.style,
  }) : child = null;

  /// For the screen whose action does not fit the defaults: a checkbox, a
  /// dropdown, a button with its own colours. The layout still decides where
  /// it sits and how it is spaced, so a custom action does not also have to
  /// re-invent the bar.
  const PhaseAction.custom({
    required Widget this.child,
    this.primary = false,
    this.side = ActionSide.forward,
  })  : label = '',
        onPressed = null,
        icon = null,
        danger = false,
        style = null;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Overrides the default styling for this one action.
  final ButtonStyle? style;

  /// Set by [PhaseAction.custom]; when present it is rendered as-is.
  final Widget? child;

  /// Whether this action continues along the install path or leaves it.
  /// Position follows meaning: a skip is still forward motion, so it sits
  /// with Continue rather than next to Cancel.
  final ActionSide side;

  /// Draws it as the filled button. The emphasised choice on the screen,
  /// independent of which side it is on.
  final bool primary;

  /// Destructive or risk-accepting, e.g. continuing past a failed check.
  final bool danger;

  Widget build(BuildContext context) {
    if (child != null) return child!;
    final label = Text(this.label);
    if (primary) {
      return icon == null
          ? FilledButton(onPressed: onPressed, style: style, child: label)
          : FilledButton.icon(
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 18),
              label: label);
    }
    final fallback = OutlinedButton.styleFrom(
      foregroundColor: danger ? Colors.orangeAccent : null,
      side: BorderSide(
        color: danger
            ? Colors.orangeAccent.withValues(alpha: 0.7)
            : kAccent.withValues(alpha: 0.5),
      ),
    );
    final effective = style ?? fallback;
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: effective, child: label)
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: effective,
            icon: Icon(icon, size: 18),
            label: label);
  }
}

/// The shared shape of every installer phase: a title that stays put, a body
/// that scrolls, and the actions pinned to the bottom.
///
/// Before this, each phase returned its own column and the whole thing lived
/// in one scroll view, so on a short window the buttons scrolled off the
/// bottom of a screen whose text the user had just been told to read. The
/// plan screen had already been special-cased in the parent for exactly that
/// reason; this generalises the fix instead of repeating it.
class PhaseLayout extends StatelessWidget {
  const PhaseLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.backLabel,
    this.maxWidth = 720,
    this.scrollable = true,
    this.centerContent = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Rendered left to right. The primary action is pulled to the right edge
  /// wherever it appears in the list, so screens do not have to remember the
  /// ordering convention.
  final List<PhaseAction> actions;

  /// Goes one step back in the flow. Only for phases where back is honest:
  /// once anything has been written to a board, the earlier screen no longer
  /// describes the scooter's state and returning to it would be a lie.
  /// Sits at the far left, before any skip or retry.
  final VoidCallback? onBack;

  /// Label for the back button. The app has its own translation for this, so
  /// falling back to Flutter's would read as English inside a German flow.
  final String? backLabel;

  final double maxWidth;

  /// False for a body that scrolls internally and needs the full height, such
  /// as a list with its own scroll view.
  final bool scrollable;

  /// Vertically centre a body shorter than the space available. Long bodies
  /// start at the top either way.
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    // Left is leaving, right is carrying on. Within the right-hand group the
    // primary action goes last, so it lands at the outside edge where the
    // pointer expects it.
    final leaving = actions.where((a) => a.side == ActionSide.back).toList();
    final onward = [
      ...actions.where((a) => a.side == ActionSide.forward && !a.primary),
      ...actions.where((a) => a.side == ActionSide.forward && a.primary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kAccent),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!,
                        style: TextStyle(color: Colors.grey.shade400)),
                  ],
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: _body(context)),
        if (actions.isNotEmpty || onBack != null)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  children: [
                    if (onBack != null) ...[
                      TextButton.icon(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(backLabel ??
                            MaterialLocalizations.of(context)
                                .backButtonTooltip),
                      ),
                      const SizedBox(width: 8),
                    ],
                    for (final a in leaving) ...[
                      a.build(context),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    for (final a in onward) ...[
                      const SizedBox(width: 8),
                      a.build(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final constrained = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
    if (!scrollable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
        child: constrained,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
          child: ConstrainedBox(
            constraints: centerContent
                ? BoxConstraints(minHeight: constraints.maxHeight - 40)
                : const BoxConstraints(),
            child: centerContent
                ? Center(child: constrained)
                : constrained,
          ),
        ),
      ),
    );
  }
}
