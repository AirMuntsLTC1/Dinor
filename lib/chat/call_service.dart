import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CallService {
  static final supabase = Supabase.instance.client;
  
  static RTCPeerConnection? _peerConnection;
  static MediaStream? _localStream;
  static RealtimeChannel? _signalChannel;
  static String? _currentCallId;

  // 1. Start a call
  static Future<void> startCall(String receiverId, String conversationId) async {
    final myId = supabase.auth.currentUser!.id;
    
    // Create the call in the database
    final callData = await supabase.from('calls').insert({
      'caller_id': myId,
      'receiver_id': receiverId,
      'conversation_id': conversationId,
      'status': 'ringing',
    }).select('id').single();
    
    _currentCallId = callData['id'];
    await _initWebRTC(true);
    await _createOffer();
    _listenToSignals(isCaller: true);
  }

  // 2. Accept a call
  static Future<void> acceptCall(String callId) async {
    _currentCallId = callId;
    await _initWebRTC(false);
    
    // Get the offer from the database
    final callData = await supabase.from('calls').select('offer').eq('id', callId).single();
    final offer = callData['offer'];
    
    if (offer != null) {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(offer['sdp'], offer['type']));
      await _createAnswer();
      _listenToSignals(isCaller: false);
    }
  }

  // 3. Initialize WebRTC
  static Future<void> _initWebRTC(bool isCaller) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    _peerConnection = await createPeerConnection(config);
    _peerConnection!.addStream(_localStream!);

    _peerConnection!.onIceCandidate = (candidate) {
      _sendSignal('ice', {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      }, isCaller);
    };

    _peerConnection!.onAddStream = (stream) {
      // Here you would play the audio using an RTCVideoRenderer or audio player
      // For audio only, WebRTC handles playing through the system speaker.
    };
  }

  // 4. Create Offer
  static Future<void> _createOffer() async {
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    await supabase.from('calls').update({
      'offer': {'sdp': offer.sdp, 'type': offer.type}
    }).eq('id', _currentCallId!);
  }

  // 5. Create Answer
  static Future<void> _createAnswer() async {
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    
    await supabase.from('calls').update({
      'answer': {'sdp': answer.sdp, 'type': answer.type}
    }).eq('id', _currentCallId!);
  }

  // 6. Listen to Supabase signals (ICE and SDP)
  static void _listenToSignals({required bool isCaller}) {
    _signalChannel = supabase.channel('call:$_currentCallId')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'calls',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: _currentCallId!,
        ),
        callback: (payload) async {
          final newRecord = payload.newRecord;
          
          // If we are the caller and the receiver answered
          if (isCaller && newRecord['answer'] != null) {
            final answer = newRecord['answer'];
            await _peerConnection!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));
          }
          
          // ICE candidates
          final remoteIce = isCaller ? newRecord['receiver_ice'] : newRecord['caller_ice'];
          if (remoteIce != null && remoteIce is List) {
             for (var ice in remoteIce) {
               await _peerConnection!.addCandidate(RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']));
             }
          }
        }
      ).subscribe();
  }

  // 7. Send ICE Signal to DB
  static Future<void> _sendSignal(String type, Map<String, dynamic> data, bool isCaller) async {
    if (type == 'ice') {
      // Get current ICE list and append
      final callData = await supabase.from('calls').select(isCaller ? 'caller_ice' : 'receiver_ice').eq('id', _currentCallId!).single();
      final List currentIce = (callData[isCaller ? 'caller_ice' : 'receiver_ice'] as List?) ?? [];
      currentIce.add(data);
      
      await supabase.from('calls').update({
        isCaller ? 'caller_ice' : 'receiver_ice': currentIce
      }).eq('id', _currentCallId!);
    }
  }

  // 8. End Call
  static Future<void> endCall() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _signalChannel?.unsubscribe();
    
    if (_currentCallId != null) {
      await supabase.from('calls').update({'status': 'ended'}).eq('id', _currentCallId!);
      _currentCallId = null;
    }
  }
}
