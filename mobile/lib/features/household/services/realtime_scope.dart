import 'package:supabase_flutter/supabase_flutter.dart';

/// Owns household channels. Registration is deferred until private policies exist.
class RealtimeScope {
  RealtimeScope(this.client);
  final SupabaseClient? client;
  final List<RealtimeChannel> _channels = [];
  int _revision = 0;
  String? householdId;

  RealtimeChannel privateChannel() {
    final household = householdId;
    if (household == null || client == null) {
      throw StateError('A validated household scope is required');
    }
    if (_channels.isNotEmpty) return _channels.first;
    final channel = client!.channel(
      'household:$household',
      opts: const RealtimeChannelConfig(private: true),
    );
    _channels.add(channel);
    return channel;
  }

  Future<void> switchTo(String? next) async {
    final revision = ++_revision;
    final old = List<RealtimeChannel>.of(_channels);
    _channels.clear();
    householdId = null;
    for (final channel in old) {
      await client?.removeChannel(channel);
    }
    if (revision == _revision) householdId = next;
    // No subscriptions in M0: future adapters must use private household topics.
  }
}
