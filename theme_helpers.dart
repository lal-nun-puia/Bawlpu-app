import 'package:flutter/material.dart';

// ─── COLORS ──────────────────────────────────────────────────────────────────
const kPrimary    = Color(0xFF1A6BB5);
const kAccent     = Color(0xFF3B9EE8);
const kBg         = Color(0xFFF0F5FB);
const kBgDark     = Color(0xFF0F1624);
const kCard       = Colors.white;
const kCardDark   = Color(0xFF1A2235);
const kText       = Color(0xFF1A2340);
const kTextDark   = Color(0xFFE8ECFF);
const kSub        = Color(0xFF6B7A9B);
const kSubDark    = Color(0xFF8B9CC5);
const kBorder     = Color(0xFFE0E6FF);
const kBorderDark = Color(0xFF2A3550);

// ─── HELPERS ──────────────────────────────────────────────────────────────────
bool  isDark(BuildContext ctx)     => Theme.of(ctx).brightness == Brightness.dark;
Color bgColor(BuildContext ctx)    => isDark(ctx) ? kBgDark   : kBg;
Color cardColor(BuildContext ctx)  => isDark(ctx) ? kCardDark : Colors.white;
Color textColor(BuildContext ctx)  => isDark(ctx) ? kTextDark : kText;
Color subColor(BuildContext ctx)   => isDark(ctx) ? kSubDark  : kSub;
Color borderColor(BuildContext ctx)=> isDark(ctx) ? kBorderDark : kBorder;
Color inputFill(BuildContext ctx)  => isDark(ctx) ? const Color(0xFF0F1624) : kBg;

// ─── REUSABLE APPBAR ─────────────────────────────────────────────────────────
PreferredSizeWidget themedAppBar(BuildContext ctx, String title, {List<Widget>? actions}) {
  final dark = isDark(ctx);
  return AppBar(
    backgroundColor: dark ? kCardDark : Colors.white,
    elevation: 1,
    title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17,
        color: dark ? kTextDark : kText)),
    iconTheme: IconThemeData(color: dark ? kTextDark : kText),
    actionsIconTheme: IconThemeData(color: dark ? kTextDark : kText),
    actions: actions,
  );
}

// ─── CARD DECORATION ─────────────────────────────────────────────────────────
BoxDecoration cardDeco(BuildContext ctx, {double radius = 14}) {
  final dark = isDark(ctx);
  return BoxDecoration(
    color: dark ? kCardDark : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [BoxShadow(
        color: Colors.black.withOpacity(dark ? 0.25 : 0.06),
        blurRadius: 10, offset: const Offset(0, 4))],
  );
}

// ─── INPUT DECORATION ────────────────────────────────────────────────────────
InputDecoration themedInput(BuildContext ctx, String hint, {IconData? icon, Widget? suffix}) {
  final dark = isDark(ctx);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: dark ? kSubDark : kSub, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: dark ? kSubDark : kSub, size: 18) : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: dark ? const Color(0xFF0F1624) : kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? kBorderDark : kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red)),
  );
}