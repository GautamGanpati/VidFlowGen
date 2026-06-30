import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vidflow/app.dart';
import 'package:vidflow/core/config/env.dart';
import 'package:vidflow/providers/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await FlutterGemma.initialize(
    huggingFaceToken: Env.huggingFaceIsConfigured ? Env.huggingFaceToken : null,
    inferenceEngines: const [LiteRtLmEngine()],
  );

  final container = ProviderContainer();
  final supabase = container.read(supabaseServiceProvider);
  final turso = container.read(tursoServiceProvider);

  await supabase.initialize();
  await turso.initializeSchema();

  runApp(
    UncontrolledProviderScope(container: container, child: const VidflowApp()),
  );
}
