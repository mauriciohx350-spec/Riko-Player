import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'features/playback/logic/playback_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await PlaybackRuntime.initialize();
  runApp(RikoPlayerApp(runtime: runtime));
}
