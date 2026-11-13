import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

void main() {
  runApp(const TokiProApp());
}

class TokiProApp extends StatelessWidget {
  const TokiProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toki',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF4B39EF),
        scaffoldBackgroundColor: const Color(0xFF0E0B1F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4B39EF),
          secondary: Color(0xFFFF4081),
        ),
      ),
      home: const LobbyScreen(),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _appIdController =
      TextEditingController(text: '7d9fb3e0517840d38e246fbb98315d22');
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _roomController =
      TextEditingController(text: 'toki_party_1');
  final TextEditingController _nameController =
      TextEditingController(text: 'Pravin');

  void _enterRoom() {
    if (_appIdController.text.trim().isEmpty ||
        _roomController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App ID और Room Name डालना ज़रूरी है!')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRoomScreen(
          appId: _appIdController.text.trim(),
          token: _tokenController.text.trim(),
          channelName: _roomController.text.trim(),
          userName: _nameController.text.trim().isEmpty
              ? 'User'
              : _nameController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toki • Real Voice & Party'),
        backgroundColor: const Color(0xFF4B39EF),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B39EF), Color(0xFF8338EC)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(Icons.headset_mic, size: 50, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Toki Live Multi-User Voice Room',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'दो फ़ोनों से एक ही Room Name डालें — असली लाइव आवाज़, असली लाइव चैट, गिफ्ट्स और पार्टी गेम्स!',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'आपका नाम (Your Name)',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: 'Room Name (दोनों फ़ोन में एक ही रखें)',
                prefixIcon: const Icon(Icons.meeting_room),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _appIdController,
              decoration: InputDecoration(
                labelText: 'Agora App ID',
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Temp Token (वैकल्पिक — यदि App Certificate चालू हो)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _enterRoom,
              icon: const Icon(Icons.mic),
              label: const Text(
                'रूम में जुड़ें (Join Live Room)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4B39EF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveRoomScreen extends StatefulWidget {
  final String appId;
  final String token;
  final String channelName;
  final String userName;

  const LiveRoomScreen({
    super.key,
    required this.appId,
    required this.token,
    required this.channelName,
    required this.userName,
  });

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  late final RtcEngine _engine;
  int? _streamId;
  bool _isJoined = false;
  bool _isMuted = false;
  int _localUid = 0;
  int _coins = 5000;
  String? _bannerText;
  Timer? _bannerTimer;

  final List?> _seats = List.filled(9, null);
  final Set<int> _speakingUids = {};
  final List> _messages = [];
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupAgora();
  }

  Future<void> _setupAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: widget.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    await _engine.enableAudio();
    await _engine.enableAudioVolumeIndication(
      interval: 250,
      smooth: 3,
      reportVad: true,
    );

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          setState(() {
            _isJoined = true;
            _localUid = connection.localUid ?? 0;
            _messages.add({
              'sender': 'Toki',
              'text': '✅ आप लाइव रूम "${widget.channelName}" में जुड़ गए हैं!'
            });
          });
          _streamId = await _engine.createDataStream(
            const DataStreamConfig(syncWithAudio: false, ordered: true),
          );
          final emptyIdx = _seats.indexWhere((s) => s == null);
          if (emptyIdx != -1) _takeSeat(emptyIdx);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          setState(() {
            _messages.add({
              'sender': 'Toki',
              'text': '🎉 नया दोस्त (ID: $remoteUid) रूम में आया!'
            });
          });
          _broadcast({'type': 'sync_seats', 'seats': _seats});
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          setState(() {
            for (int i = 0; i < 9; i++) {
              if (_seats[i] != null && _seats[i]!['uid'] == remoteUid) {
                _seats[i] = null;
              }
            }
          });
        },
        onAudioVolumeIndication: (RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume) {
          final active = <int>{};
          for (final s in speakers) {
            if ((s.volume ?? 0) > 15) {
              active.add(s.uid == 0 ? _localUid : (s.uid ?? 0));
            }
          }
          if (mounted) {
            setState(() {
              _speakingUids
                ..clear()
                ..addAll(active);
            });
          }
        },
        onStreamMessage: (RtcConnection connection, int remoteUid, int streamId,
            Uint8List data, int length, int sentTs) {
          try {
            final map = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
            _onRemoteData(map);
          } catch (_) {}
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.joinChannel(
      token: widget.token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  Future<void> _broadcast(Map<String, dynamic> data) async {
    if (_streamId == null || !_isJoined) return;
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    await _engine.sendStreamMessage(
      streamId: _streamId!,
      data: bytes,
      length: bytes.length,
    );
  }

  void _onRemoteData(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      switch (data['type']) {
        case 'chat':
          _messages.add({
            'sender': data['sender'] ?? 'User',
            'text': data['text'] ?? '',
          });
          break;
        case 'seat':
          _seats[data['index'] as int] = data['user'];
          break;
        case 'sync_seats':
          final list = data['seats'] as List<dynamic>;
          for (int i = 0; i < 9 && i < list.length; i++) {
            if (list[i] != null && _seats[i] == null) {
              _seats[i] = Map<String, dynamic>.from(list[i]);
            }
          }
          break;
        case 'gift':
          final msg = '${data['sender']} ने ${data['gift']} भेजा!';
          _messages.add({'sender': '🎁 Gift', 'text': msg});
          _showBanner(msg);
          break;
        case 'game':
          final msg = '${data['sender']}: ${data['result']}';
          _messages.add({'sender': '🎲 Party Game', 'text': msg});
          _showBanner(msg);
          break;
      }
    });
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _bannerText = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  void _takeSeat(int index) {
    for (int i = 0; i < 9; i++) {
      if (_seats[i] != null && _seats[i]!['uid'] == _localUid) {
        _seats[i] = null;
        _broadcast({'type': 'seat', 'index': i, 'user': null});
      }
    }
    final userObj = {'uid': _localUid, 'name': widget.userName};
    setState(() => _seats[index] = userObj);
    _broadcast({'type': 'seat', 'index': index, 'user': userObj});
  }

  void _leaveSeat(int index) {
    setState(() => _seats[index] = null);
    _broadcast({'type': 'seat', 'index': index, 'user': null});
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() => _messages.add({'sender': widget.userName, 'text': text}));
    _broadcast({'type': 'chat', 'sender': widget.userName, 'text': text});
  }

  void _sendGift(String gift, int cost) {
    if (_coins < cost) return;
    setState(() {
      _coins -= cost;
      _messages.add({
        'sender': '🎁 Gift',
        'text': '${widget.userName} ने $gift भेजा!',
      });
    });
    _showBanner('${widget.userName} ने $gift भेजा!');
    _broadcast({'type': 'gift', 'sender': widget.userName, 'gift': gift});
    Navigator.pop(context);
  }

  void _playDiceOrTruth() {
    final dice = Random().nextInt(6) + 1;
    final result = '🎲 Ludo Dice में $dice आया!';
    setState(() {
      _messages.add({
        'sender': '🎲 Party Game',
        'text': '${widget.userName}: $result',
      });
    });
    _showBanner('${widget.userName}: $result');
    _broadcast({'type': 'game', 'sender': widget.userName, 'result': result});
  }

  void _openGifts() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1533),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Gifts भेजें',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('🪙 $_coins Coins',
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _giftButton('🌹 Rose', 10),
                _giftButton('👑 Crown', 100),
                _giftButton('🏎️ Car', 500),
                _giftButton('🚀 Rocket', 1000),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _giftButton(String label, int cost) {
    return GestureDetector(
      onTap: () => _sendGift(label, cost),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF28204D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF4B39EF)),
        ),
        child: Column(
          children: [
            Text(label.split(' ').first, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(label.split(' ').last, style: const TextStyle(fontSize: 12)),
            Text('🪙 $cost',
                style: const TextStyle(fontSize: 11, color: Colors.amber)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    await _engine.muteLocalAudioStream(_isMuted);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF4B39EF),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channelName, style: const TextStyle(fontSize: 16)),
            Text(
              _isJoined ? '🟢 Real Multi-User Sync Active' : '🟡 Connecting...',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _playDiceOrTruth,
            icon: const Icon(Icons.casino),
            tooltip: 'Roll Live Dice',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('🪙 $_coins',
                  style: const TextStyle(
                      color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_bannerText != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF4081), Color(0xFF4B39EF)],
                ),
              ),
              child: Text(
                '✨ $_bannerText ✨',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.05,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final occupant = _seats[index];
                final isOccupied = occupant != null;
                final uid = isOccupied ? occupant['uid'] : null;
                final isSpeaking = uid != null && _speakingUids.contains(uid);
                final isMe = uid == _localUid;

                return GestureDetector(
                  onTap: () {
                    if (!isOccupied) {
                      _takeSeat(index);
                    } else if (isMe) {
                      _leaveSeat(index);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1533),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSpeaking
                            ? Colors.greenAccent
                            : (isOccupied
                                ? const Color(0xFF4B39EF)
                                : Colors.white12),
                        width: isSpeaking ? 2.5 : 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isOccupied
                              ? const Color(0xFF4B39EF)
                              : Colors.white10,
                          child: Icon(
                            isOccupied ? Icons.person : Icons.mic_none,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOccupied
                              ? occupant['name'].toString()
                              : 'Seat ${index + 1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isOccupied
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isOccupied ? Colors.white : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
      
