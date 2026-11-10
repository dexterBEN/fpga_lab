import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/websocket_connection/websocket_connection_bloc.dart';
import '../../bloc/websocket_connection/websocket_connection_event.dart';
import '../../bloc/websocket_connection/websocket_connection_state.dart';

class ConnectionView extends StatelessWidget {
  const ConnectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WebSocketConnectionBloc, WebSocketConnectionState>(
      builder: (context, state) {
        final status = state.status;

        final connected = status == WebSocketConnectionStatus.connected;
        final busy =
            status == WebSocketConnectionStatus.connecting ||
            status == WebSocketConnectionStatus.disconnecting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      connected ? Icons.check_circle : Icons.link_off,
                      size: 40,
                      color: connected ? Colors.green : Colors.grey,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WebSocket connection'),
                        Text(
                          status.name.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    if (busy)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    else
                      FilledButton(
                        onPressed: () {
                          context.read<WebSocketConnectionBloc>().add(
                            connected
                                ? const WebSocketDisconnectRequested()
                                : const WebSocketConnectRequested(),
                          );
                        },
                        child: Text(connected ? 'Disconnect' : 'Connect'),
                      ),
                  ],
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
