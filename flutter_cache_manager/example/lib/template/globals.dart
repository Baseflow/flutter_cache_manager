import 'dart:core';

import 'package:flutter/material.dart';

import '../plugin_example/cache_manager_page.dart';
import 'info_page.dart';

/// The name of the plugin, which will be displayed throughout the example App.
const String pluginName = 'Flutter Cache Manager';

/// Returns Github URL, which is shown in the [InfoPage].
const String githubURL = 'https://github.com/Baseflow/flutter_cache_manager';

/// Returns Baseflow URL, which is shown in the [InfoPage].
const String baseflowURL = 'https://baseflow.com';

/// Returns pub.dev URL, which is shown in the [InfoPage].
const String pubDevURL = 'https://pub.dev/packages/flutter_cache_manager';

/// [EdgeInsets] to define horizontal padding throughout the application.
const EdgeInsets defaultHorizontalPadding =
    EdgeInsets.symmetric(horizontal: 24);

/// [EdgeInsets] to define vertical padding throughout the application.
const EdgeInsets defaultVerticalPadding = EdgeInsets.symmetric(vertical: 24);

/// Returns a [List] with [IconData] to show in the [AppHome] [AppBar].
final List<IconData> icons = [
  Icons.save_alt,
  Icons.info_outline,
];

/// Returns a [List] with [Widget]s to construct pages in the [AppBar].
final List<Widget> pages = [
  CacheManagerPage(),
  InfoPage(),
];
