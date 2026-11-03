import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/mux_demux/bloc/mux_demux_cubit.dart';
import '../features/mux_demux/data/mux_demux_repository.dart';
import '../features/mux_demux/data/websocket_mux_demux_repository.dart';
import '../features/mux_demux/view/mux_demux_page.dart';

const mint = Color(0xFF55E0C2);
const panel = Color(0xFF171C24);
const muted = Color(0xFFAEB8C7);

class MuxDemuxApp extends StatelessWidget {
  const MuxDemuxApp({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MuxDemuxCubit(
      LocalMuxDemuxRepository(),
      websocketRepository: WebSocketMuxDemuxRepository(
        url: const String.fromEnvironment(
          'WEBSOCKET_URL',
          defaultValue: 'ws://127.0.0.1:8765',
        ),
      ),
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MUX / DEMUX Visualizer',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1319),
        colorScheme: ColorScheme.fromSeed(
          seedColor: mint,
          brightness: Brightness.dark,
          primary: mint,
          surface: panel,
        ),
        dividerColor: const Color(0xFF303B49),
      ),
      home: const MuxDemuxPage(),
    ),
  );
}
