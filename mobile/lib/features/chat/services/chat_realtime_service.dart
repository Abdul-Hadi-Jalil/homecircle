import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class ChatRealtimeService {
  Future<void> connect(
    String household,
    String user,
    void Function(Map<String, dynamic>) event,
    void Function(bool) state,
  );
  Future<void> disconnect();
}

class SupabaseChatRealtime implements ChatRealtimeService {
  SupabaseChatRealtime(this.client);
  final SupabaseClient? client;
  RealtimeChannel? channel;
  int generation = 0;
  @override
  Future<void> connect(
    String household,
    String user,
    void Function(Map<String, dynamic>) event,
    void Function(bool) state,
  ) async {
    final request = ++generation, c = client, previous = channel;
    channel = null;
    if (previous != null) await c?.removeChannel(previous);
    if (request != generation) return;
    if (c == null) {
      state(false);
      return;
    }
    await c.realtime.setAuth(c.auth.currentSession?.accessToken);
    if (request != generation) return;
    channel = c.channel(
      'chat:$household:$user',
      opts: const RealtimeChannelConfig(private: true),
    );
    channel!
        .onBroadcast(
          event: 'chat_changed',
          callback: (raw) {
            if (request != generation) return;
            final payload = raw['payload'] is Map
                ? Map<String, dynamic>.from(raw['payload'] as Map)
                : raw;
            if (payload['household_id'] == household &&
                payload['event_id'] is String) {
              event(payload);
            }
          },
        )
        .subscribe((status, error) {
          if (request == generation) {
            state(status == RealtimeSubscribeStatus.subscribed);
          }
        });
  }

  @override
  Future<void> disconnect() async {
    generation++;
    final previous = channel;
    channel = null;
    if (previous != null) await client?.removeChannel(previous);
  }
}
