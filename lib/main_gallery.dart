// lib/main_gallery.dart
//
// Standalone launcher for the Lab Console component gallery — used for
// visual QA across the 8 themes. Run with:
//   flutter run -t lib/main_gallery.dart -d macos   (or -d windows)
// Not part of the production app; main.dart is unchanged.

import 'package:flutter/material.dart';
import 'ui/lab/lab_gallery.dart';

void main() => runApp(
      const MaterialApp(
        title: 'Lab Gallery',
        debugShowCheckedModeBanner: false,
        home: LabGallery(),
      ),
    );
