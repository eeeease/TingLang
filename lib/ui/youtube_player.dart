import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Origin sent as Referer so YouTube can identify the embedder (a missing
/// Referer is the usual cause of IFrame error 153).
const youtubeEmbedOrigin = 'https://eeeease.github.io/';

/// State of an embedded YouTube clip. Playback only: the video is streamed
/// by YouTube's own player and never downloaded.
class YouTubeClipController extends ChangeNotifier {
  YouTubeClipController({required this.videoId, required this.startMs, required this.endMs});

  final String videoId;
  int startMs;
  int? endMs;
  bool ready = false, playing = false, loop = true;
  int positionMs = 0;
  double rate = 1;

  /// IFrame error (101/150: embedding disabled; 153: missing referrer…).
  int? errorCode;
  WebViewController? _web;
  bool _disposed = false;

  void _attach(WebViewController web) => _web = web;

  void _onMessage(String message) {
    final data = jsonDecode(message) as Map<String, Object?>;
    switch (data['t']) {
      case 'ready':
        ready = true;
      case 'time':
        positionMs = ((data['v']! as num) * 1000).round();
        playing = data['p'] == true;
      case 'error':
        errorCode = (data['v']! as num).toInt();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _js(String code) async {
    final web = _web;
    if (web != null && ready) await web.runJavaScript(code);
  }

  Future<void> toggle() => _js(playing ? 'player.pauseVideo()' : 'tinglang.play()');
  Future<void> pause() => _js('player.pauseVideo()');
  Future<void> seek(int ms) => _js('player.seekTo(${ms / 1000}, true)');
  Future<void> setRate(double value) async {
    rate = value;
    await _js('player.setPlaybackRate($value)');
    notifyListeners();
  }

  void setLoop(bool value) {
    loop = value;
    unawaited(_js('tinglang.loop = $value'));
    notifyListeners();
  }

  /// Plays [from]–[to] (absolute video ms), e.g. one subtitle cue.
  Future<void> playRange(int from, int? to) async {
    startMs = from;
    endMs = to;
    await _js(
      'tinglang.setRange(${from / 1000}, ${to == null ? 'null' : to / 1000}); tinglang.play()',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String _playerHtml(YouTubeClipController c) {
  final start = c.startMs / 1000, end = c.endMs == null ? 'null' : '${c.endMs! / 1000}';
  return '''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<style>html,body{margin:0;height:100%;background:#000}#p{width:100%;height:100%}</style></head>
<body><div id="p"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
var player;
var tinglang = {
  start: $start, end: $end, loop: ${c.loop},
  send: function (m) { Tinglang.postMessage(JSON.stringify(m)); },
  setRange: function (s, e) { this.start = s; this.end = e; },
  play: function () {
    var t = player.getCurrentTime();
    if (t < this.start - 0.25 || (this.end !== null && t >= this.end - 0.1)) player.seekTo(this.start, true);
    player.playVideo();
  }
};
function onYouTubeIframeAPIReady() {
  player = new YT.Player('p', {
    videoId: '${c.videoId}',
    playerVars: { start: Math.floor($start), playsinline: 1, rel: 0, modestbranding: 1, cc_load_policy: 0, iv_load_policy: 3, origin: '${youtubeEmbedOrigin.substring(0, youtubeEmbedOrigin.length - 1)}' },
    events: {
      onReady: function () {
        try { player.unloadModule('captions'); player.setOption('captions', 'track', {}); } catch (e) {}
        player.seekTo(tinglang.start, true); player.pauseVideo(); tinglang.send({t: 'ready'});
      },
      // Captions stay hidden: the course reveals text only after listening.
      onApiChange: function () { try { player.unloadModule('captions'); } catch (e) {} },
      onError: function (e) { tinglang.send({t: 'error', v: e.data}); }
    }
  });
  setInterval(function () {
    if (!player || !player.getCurrentTime) return;
    var t = player.getCurrentTime(), playing = player.getPlayerState() === 1;
    if (playing && tinglang.end !== null && t >= tinglang.end) {
      if (tinglang.loop) player.seekTo(tinglang.start, true); else player.pauseVideo();
    }
    tinglang.send({t: 'time', v: t, p: playing});
  }, 200);
}
</script></body></html>''';
}

/// The official YouTube IFrame player in a WKWebView. Nothing is drawn on top
/// of it (YouTube's embed rules); captions belong below the player.
class YouTubeClipPlayer extends StatefulWidget {
  const YouTubeClipPlayer({super.key, required this.controller});
  final YouTubeClipController controller;
  @override
  State<YouTubeClipPlayer> createState() => _YouTubeClipPlayerState();
}

class _YouTubeClipPlayerState extends State<YouTubeClipPlayer> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel(
      'Tinglang',
      onMessageReceived: (m) => widget.controller._onMessage(m.message),
    )
    ..setNavigationDelegate(
      NavigationDelegate(
        // Stay on the player page; links (e.g. "Watch on YouTube") are refused.
        onNavigationRequest: (r) =>
            r.url.startsWith(youtubeEmbedOrigin) || r.url.contains('youtube.com/embed/')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ),
    )
    ..loadHtmlString(_playerHtml(widget.controller), baseUrl: youtubeEmbedOrigin);

  @override
  void initState() {
    super.initState();
    widget.controller._attach(_web);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
