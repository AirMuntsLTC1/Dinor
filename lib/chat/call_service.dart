import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lifecycle of the one active call on this device.
enum CallPhase { idle, calling, connecting, connected }

class IncomingCall {
  final String callId;
  final String callerId;
  final String conversationId;
  final String callerName;
  const IncomingCall({
    required this.callId,
    required this.callerId,
    required this.conversationId,
    required this.callerName,
  });
}

/// WebRTC audio calls signaled through the `calls` table.
///
/// * Incoming calls ring (native ringtone + vibration) and show a prompt.
/// * The prompt closes if the caller hangs up before it is answered.
/// * The answerer waits for the caller's offer instead of failing on a race.
/// * Hang-up releases the microphone at once (peer closed, tracks stopped).
class CallService {
  CallService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static const Duration _ringTimeout = Duration(seconds: 45);
  static const MethodChannel _ringChannel = MethodChannel('dinor/ring');
  static const Map<String, dynamic> _rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
  };

  // Observed by the UI.
  static final ValueNotifier<CallPhase> phase = ValueNotifier(CallPhase.idle);
  static final ValueNotifier<int?> connectedAtMs = ValueNotifier(null);
  static final ValueNotifier<IncomingCall?> incoming = ValueNotifier(null);

  /// Why the last call ended: 'ended', 'missed', 'declined', 'failed', or null.
  static String? lastEndReason;

  /// Human-readable reason for the last failure (shown on the call screen).
  static String? lastErrorMessage;

  static RTCPeerConnection? _pc;
  static MediaStream? _localStream;
  static RealtimeChannel? _callChannel;
  static RealtimeChannel? _incomingChannel;
  static String? _callId;
  static bool _isCaller = false;

  static bool _remoteDescSet = false;
  static bool _answerApplied = false;
  static int _remoteIceApplied = 0;
  static final List<RTCIceCandidate> _pendingRemoteIce = [];

  static Future<void> _iceWriteChain = Future.value();
  static Timer? _ringTimer;

  static String? get currentCallId => _callId;

  // ---------------------------------------------------------------------------
  // Ringing (native ringtone + vibration; silently skipped where unavailable)
  // ---------------------------------------------------------------------------

  static Future<void> _ring(bool on) async {
    try {
      await _ringChannel.invokeMethod(on ? 'start' : 'stop');
    } catch (_) {
      // Not available on this platform: the on-screen prompt still shows.
    }
  }

  // ---------------------------------------------------------------------------
  // Incoming calls
  // ---------------------------------------------------------------------------

  /// Listens for calls addressed to this user. Call after login.
  static void startIncomingListener() {
    final me = _db.auth.currentUser?.id;
    if (me == null) return;
    _incomingChannel?.unsubscribe();
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'receiver_id',
      value: me,
    );
    _incomingChannel = _db
        .channel('incoming_calls:$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'calls',
          filter: filter,
          callback: (payload) => _onIncomingRow(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: filter,
          callback: (payload) => _onIncomingUpdate(payload.newRecord),
        )
        .subscribe();
  }

  static void stopIncomingListener() {
    _incomingChannel?.unsubscribe();
    _incomingChannel = null;
    _clearIncoming();
  }

  static void _clearIncoming() {
    incoming.value = null;
    _ring(false);
  }

  static Future<void> _onIncomingRow(Map<String, dynamic> row) async {
    if (row['status'] != 'ringing') return;
    if (phase.value != CallPhase.idle) {
      // Already on a call: decline so the caller does not ring forever.
      await _declineRow(row['id'].toString());
      return;
    }
    _ring(true);

    String name = 'Unknown';
    try {
      final profile = await _db
          .from('profiles')
          .select('username')
          .eq('id', row['caller_id'])
          .maybeSingle();
      name = (profile?['username'] as String?) ?? name;
    } catch (_) {}

    // The caller may have hung up while we looked up the name.
    if (phase.value != CallPhase.idle) return;
    incoming.value = IncomingCall(
      callId: row['id'].toString(),
      callerId: row['caller_id'].toString(),
      conversationId: row['conversation_id'].toString(),
      callerName: name,
    );
  }

  /// Closes the prompt when the caller cancels or the call is answered elsewhere.
  static void _onIncomingUpdate(Map<String, dynamic> row) {
    final current = incoming.value;
    if (current == null || current.callId != row['id'].toString()) return;
    if (row['status'] != 'ringing') _clearIncoming();
  }

  static Future<void> declineCall(String callId) async {
    _clearIncoming();
    await _declineRow(callId);
  }

  static Future<void> _declineRow(String callId) async {
    try {
      await _db.from('calls').update({'status': 'declined'}).eq('id', callId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Caller
  // ---------------------------------------------------------------------------

  static Future<void> startCall(String receiverId, String conversationId) async {
    if (phase.value != CallPhase.idle) return;
    final me = _db.auth.currentUser!.id;
    _isCaller = true;
    lastErrorMessage = null;
    lastEndReason = null;
    phase.value = CallPhase.calling;

    try {
      final row = await _db.from('calls').insert({
        'caller_id': me,
        'receiver_id': receiverId,
        'conversation_id': conversationId,
        'status': 'ringing',
      }).select('id').single();
      _callId = row['id'].toString();

      await _openMedia();
      await _createPeer();

      final offer = await _pc!.createOffer({'offerToReceiveAudio': 1});
      await _pc!.setLocalDescription(offer);
      await _db.from('calls').update({
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      }).eq('id', _callId!);

      _subscribe();
      // Catch an answer that was written before the subscription went live.
      final current = await _db.from('calls').select().eq('id', _callId!).single();
      await _applyRow(current);

      _ringTimer = Timer(_ringTimeout, () {
        if (phase.value == CallPhase.calling) endCall(reason: 'missed');
      });
    } catch (e) {
      debugPrint('startCall failed: $e');
      lastErrorMessage = _friendly(e);
      await _fail();
    }
  }

  // ---------------------------------------------------------------------------
  // Receiver
  // ---------------------------------------------------------------------------

  static Future<void> acceptCall(String callId) async {
    if (phase.value != CallPhase.idle) return;
    _clearIncoming(); // stops the ringtone
    _isCaller = false;
    _callId = callId;
    lastErrorMessage = null;
    lastEndReason = null;
    phase.value = CallPhase.connecting;

    try {
      var row = await _db.from('calls').select().eq('id', callId).single();

      // The caller writes the offer just after creating the row, so wait briefly.
      for (var i = 0; row['offer'] == null && i < 30; i++) {
        if (row['status'] == 'ended' || row['status'] == 'declined') {
          throw StateError('The caller hung up.');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        row = await _db.from('calls').select().eq('id', callId).single();
      }
      final offer = row['offer'];
      if (offer == null) throw StateError('The call did not start. Ask them to call again.');

      await _openMedia();
      await _createPeer();

      await _pc!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
      );
      _remoteDescSet = true;
      await _flushPendingIce();

      final answer = await _pc!.createAnswer({'offerToReceiveAudio': 1});
      await _pc!.setLocalDescription(answer);
      await _db.from('calls').update({
        'answer': {'sdp': answer.sdp, 'type': answer.type},
        'status': 'active',
      }).eq('id', callId);

      _subscribe();
      await _applyRow(row);
    } catch (e) {
      debugPrint('acceptCall failed: $e');
      lastErrorMessage = _friendly(e);
      await _fail();
    }
  }

  // ---------------------------------------------------------------------------
  // Shared plumbing
  // ---------------------------------------------------------------------------

  static Future<void> _openMedia() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      throw StateError('Microphone permission is off. Allow it for Dinor in Android Settings.');
    }
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
  }

  static Future<void> _createPeer() async {
    final pc = await createPeerConnection(_rtcConfig);
    _pc = pc;

    for (final track in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _queueIce({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _ringTimer?.cancel();
          phase.value = CallPhase.connected;
          connectedAtMs.value ??= DateTime.now().millisecondsSinceEpoch;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          lastErrorMessage = 'Could not connect to the other phone. Your network may block direct calls.';
          _fail();
          break;
        default:
          break;
      }
    };
  }

  /// Serializes ICE writes so concurrent candidates are never lost.
  static void _queueIce(Map<String, dynamic> candidate) {
    _iceWriteChain = _iceWriteChain.then((_) async {
      final id = _callId;
      if (id == null) return;
      final column = _isCaller ? 'caller_ice' : 'receiver_ice';
      try {
        final current = await _db.from('calls').select(column).eq('id', id).single();
        final list = List<dynamic>.from((current[column] as List?) ?? const []);
        list.add(candidate);
        await _db.from('calls').update({column: list}).eq('id', id);
      } catch (e) {
        debugPrint('ICE write failed: $e');
      }
    });
  }

  static void _subscribe() {
    final id = _callId;
    if (id == null) return;
    _callChannel?.unsubscribe();
    _callChannel = _db
        .channel('call:$id')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: id,
          ),
          callback: (payload) => _applyRow(payload.newRecord),
        )
        .subscribe();
  }

  /// Applies remote signaling from a call row. Safe to call repeatedly.
  static Future<void> _applyRow(Map<String, dynamic> row) async {
    final pc = _pc;
    if (pc == null) return;

    final status = row['status'];
    if (status == 'ended' || status == 'declined') {
      await endCall(reason: status as String, notifyRemote: false);
      return;
    }

    // Caller: apply the answer once.
    if (_isCaller && !_answerApplied && row['answer'] != null) {
      final answer = row['answer'] as Map;
      _answerApplied = true;
      await pc.setRemoteDescription(
        RTCSessionDescription(answer['sdp'] as String, answer['type'] as String),
      );
      _remoteDescSet = true;
      await _flushPendingIce();
    }

    // Remote ICE: only process entries we have not applied yet.
    final remoteColumn = _isCaller ? 'receiver_ice' : 'caller_ice';
    final remote = row[remoteColumn];
    if (remote is List && remote.length > _remoteIceApplied) {
      for (final raw in remote.sublist(_remoteIceApplied)) {
        final ice = raw as Map;
        final candidate = RTCIceCandidate(
          ice['candidate'] as String?,
          ice['sdpMid'] as String?,
          ice['sdpMLineIndex'] as int?,
        );
        if (_remoteDescSet) {
          await pc.addCandidate(candidate);
        } else {
          _pendingRemoteIce.add(candidate);
        }
      }
      _remoteIceApplied = remote.length;
    }
  }

  static Future<void> _flushPendingIce() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List<RTCIceCandidate>.from(_pendingRemoteIce)) {
      await pc.addCandidate(c);
    }
    _pendingRemoteIce.clear();
  }

  static Future<void> _fail() => endCall(reason: 'failed');

  static String _friendly(Object e) {
    final text = e.toString().replaceFirst(RegExp(r'^[A-Za-z]*(Error|Exception): '), '');
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  /// Ends the call. The UI returns to idle at once; media and network cleanup follow.
  static Future<void> endCall({String reason = 'ended', bool notifyRemote = true}) async {
    if (phase.value == CallPhase.idle && _callId == null && _pc == null && _localStream == null) return;
    lastEndReason = reason;
    _ringTimer?.cancel();
    _ringTimer = null;

    // Take ownership of everything first, so a second call cannot touch it.
    final id = _callId;
    final wasActive = phase.value != CallPhase.idle;
    final pc = _pc;
    final stream = _localStream;
    final channel = _callChannel;

    _pc = null;
    _localStream = null;
    _callChannel = null;
    _callId = null;
    _remoteDescSet = false;
    _answerApplied = false;
    _remoteIceApplied = 0;
    _pendingRemoteIce.clear();
    _iceWriteChain = Future.value();
    connectedAtMs.value = null;

    // Back to idle now, so the screen closes without waiting on the network.
    phase.value = CallPhase.idle;

    await _releaseMedia(pc, stream, channel);

    if (notifyRemote && id != null && wasActive) {
      unawaited(_db
          .from('calls')
          .update({'status': 'ended'})
          .eq('id', id)
          .timeout(const Duration(seconds: 5))
          .catchError((_) {}));
    }
  }

  /// Closes the connection and stops the microphone (clears the green mic dot).
  static Future<void> _releaseMedia(
    RTCPeerConnection? pc,
    MediaStream? stream,
    RealtimeChannel? channel,
  ) async {
    try {
      await channel?.unsubscribe();
    } catch (_) {}
    try {
      await pc?.close();
    } catch (_) {}
    for (final track in stream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream?.dispose();
    } catch (_) {}
  }
}
