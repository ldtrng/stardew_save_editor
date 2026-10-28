import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// Ad surface colour: the page background nudged towards the panel colour, so
/// ads read as a slightly lifted area without a frame. Shared by native and
/// banner ads.
Color adSurface(FarmPalette p) => Color.lerp(p.background, p.panel, 0.6)!;
