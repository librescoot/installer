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
