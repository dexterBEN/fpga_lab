import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/register_system/register_bloc.dart';
import 'bloc/websocket_connection/websocket_connection_bloc.dart';
import 'repository/register_repository.dart';
import 'repository/websocket_register_repository.dart';
import 'ui/views/register_system_view.dart';

void main() {
  final repository = WebSocketRegisterRepository(
    url: const String.fromEnvironment(
      'WS_URL',
      defaultValue: 'ws://127.0.0.1:8765',
    ),
    token: const String.fromEnvironment('WS_TOKEN'),
  );

  runApp(RegisterApp(repository: repository));
}

class RegisterApp extends StatelessWidget {
  /// Takes ownership of [repository] and disposes it when the app is unmounted.
  const RegisterApp({required this.repository, super.key});

  final RegisterRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<RegisterRepository>(
      create: (_) => repository,
      dispose: (repository) => unawaited(repository.dispose()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                WebSocketConnectionBloc(context.read<RegisterRepository>()),
          ),
          BlocProvider(
            create: (context) =>
                RegisterBloc(context.read<RegisterRepository>()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff1677ff),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xff080f1a),
          ),
          home: const RegisterSystemView(),
        ),
      ),
    );
  }
}
