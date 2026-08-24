import 'package:flutter/material.dart';

/// Brand palette. Mirrors the librescoot.org website tokens:
///   --bg-primary   #0A0A0A
///   --text-primary #F0F0F0
///   --accent       #3DD8E8
///   --on-accent    #0A0A0A
const Color kBgPrimary = Color(0xFF0A0A0A);
// A step off the page rather than a shade of it: #111 against #0A0A0A was
// seven points and read as one flat surface. The blue bias is what keeps the
// lift from looking like a rendering artefact.
const Color kBgSidebar = Color(0xFF151C20);

/// The edge between the sidebar and the page it sits against.
const Color kSidebarEdge = Color(0xFF243036);
const Color kTextPrimary = Color(0xFFF0F0F0);
const Color kAccent = Color(0xFF3DD8E8);
const Color kOnAccent = Color(0xFF0A0A0A);

/// Surfaces, in the order Material 3 stacks them. The seed algorithm derives
/// these from the accent, which on this ground puts them within a few points
/// of the page colour: that is why an unstyled menu had no visible edge and
/// no visible end. They are named here instead.
const Color kSurfaceLowest = Color(0xFF060809);
const Color kSurfaceLow = Color(0xFF0F1417);
const Color kSurface = Color(0xFF151C20);
const Color kSurfaceHigh = Color(0xFF1B2429);
const Color kSurfaceHighest = Color(0xFF212C32);

/// Borders. The strong one separates a floating surface from the page; the
/// quiet one divides content inside one.
const Color kOutline = Color(0xFF35454C);
const Color kOutlineQuiet = Color(0xFF212C32);

const Color kTextMuted = Color(0xFFA6B4BA);
const Color kDanger = Color(0xFFFF6B5E);
const Color kOnDanger = Color(0xFF1A0603);

/// The app's colours as Material 3 roles.
///
/// Every M3 component paints itself from these, so naming them is what makes
/// a dialog, a menu or a card land on the same palette as the parts of the UI
/// that were drawn by hand.
const ColorScheme kColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: kAccent,
  onPrimary: kOnAccent,
  primaryContainer: Color(0xFF12363C),
  onPrimaryContainer: kAccent,
  secondary: kAccent,
  onSecondary: kOnAccent,
  secondaryContainer: Color(0xFF12363C),
  onSecondaryContainer: kAccent,
  tertiary: kAccent,
  onTertiary: kOnAccent,
  error: kDanger,
  onError: kOnDanger,
  errorContainer: Color(0xFF3A1512),
  onErrorContainer: kDanger,
  surface: kBgPrimary,
  onSurface: kTextPrimary,
  onSurfaceVariant: kTextMuted,
  surfaceContainerLowest: kSurfaceLowest,
  surfaceContainerLow: kSurfaceLow,
  surfaceContainer: kSurface,
  surfaceContainerHigh: kSurfaceHigh,
  surfaceContainerHighest: kSurfaceHighest,
  surfaceTint: Colors.transparent,
  outline: kOutline,
  outlineVariant: kOutlineQuiet,
  shadow: Colors.black,
  scrim: Colors.black,
  inverseSurface: kTextPrimary,
  onInverseSurface: kBgPrimary,
  inversePrimary: Color(0xFF00363C),
);

/// The app's theme.
///
/// Components are configured here rather than at each call site. Every field,
/// menu and dialog used to carry its own copy of the same decoration, which
/// is how they drifted apart in the first place.
ThemeData librescootTheme() {
  final borderRadius = BorderRadius.circular(8);
  OutlineInputBorder border(Color colour, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: colour, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: kColorScheme,
    scaffoldBackgroundColor: kBgPrimary,
    // Material 3 washes a rising surface with the seed colour. Every surface
    // here is already chosen, so the wash is only ever a tint on top of a
    // decision that was made.
    canvasColor: kBgPrimary,
    dividerColor: kOutlineQuiet,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurface,
      enabledBorder: border(kOutline),
      border: border(kOutline),
      focusedBorder: border(kAccent, 2),
      errorBorder: border(kDanger),
      focusedErrorBorder: border(kDanger, 2),
      hintStyle: const TextStyle(color: kTextMuted),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(kSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(12),
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: kOutline),
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kOutline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kOutline),
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurfaceLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: kOutlineQuiet),
      ),
    ),
    expansionTileTheme: ExpansionTileThemeData(
      // The dividers an ExpansionTile draws above and below itself are the
      // reason every use of one carried a Theme wrapper to hide them.
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      iconColor: kAccent,
      collapsedIconColor: kAccent,
      textColor: kAccent,
      collapsedTextColor: kAccent,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAccent,
      linearTrackColor: kSurfaceHigh,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kSurfaceHigh,
        borderRadius: BorderRadius.circular(6),
        border: const Border.fromBorderSide(BorderSide(color: kOutline)),
      ),
      textStyle: const TextStyle(fontSize: 12, color: kTextPrimary),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurfaceHigh,
      contentTextStyle: TextStyle(color: kTextPrimary),
    ),
  );
}
