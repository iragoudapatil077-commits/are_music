import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:are_music/services/yt_audio_stream.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../utils/add_history.dart';
import '../ytmusic/ytmusic.dart';
import 'settings_manager.dart';

class MediaPlayer extends ChangeNotifier {
  late AudioPlayer _player;
  ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);

  // Android-only audio effect instances. Keep them dynamic and only
  // instantiate / register when running on Android so Windows builds
  // don't attempt to initialize platform-specific audio classes.
  dynamic _loudnessEnhancer;
  dynamic _equalizer;
  dynamic _equalizerParams;

  List<IndexedAudioSource>? _songList = [];
  // MediaItem? _currentSong;
  final ValueNotifier<MediaItem?> _currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<int?> _currentIndex = ValueNotifier(null);
  final ValueNotifier<ButtonState> _buttonState =
      ValueNotifier(ButtonState.loading);
  Timer? _timer;
  final ValueNotifier<Duration?> _timerDuration = ValueNotifier(null);

  final ValueNotifier<LoopMode> _loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<ProgressBarState> _progressBarState =
      ValueNotifier(ProgressBarState());

  bool _shuffleModeEnabled = false;

  MediaPlayer() {
    // Instantiate Android-only effects only on Android.
    if (Platform.isAndroid) {
      _equalizer = AndroidEqualizer();
      _loudnessEnhancer = AndroidLoudnessEnhancer();
    }

    final AudioPipeline pipeline = AudioPipeline(
      androidAudioEffects:
          Platform.isAndroid ? [_equalizer, _loudnessEnhancer] : [],
    );

    _player = AudioPlayer(audioPipeline: pipeline);

    // Register platform singletons only on Android.
    if (Platform.isAndroid) {
      GetIt.I.registerSingleton<AndroidLoudnessEnhancer>(_loudnessEnhancer);
      GetIt.I.registerSingleton<AndroidEqualizer>(_equalizer);
    }

    _init();
  }
  AudioPlayer get player => _player;
  ConcatenatingAudioSource get playlist => _playlist;
  List<IndexedAudioSource>? get songList => _songList;
  ValueNotifier<MediaItem?> get currentSongNotifier => _currentSongNotifier;
  ValueNotifier<int?> get currentIndex => _currentIndex;
  ValueNotifier<ButtonState> get buttonState => _buttonState;

  ValueNotifier<ProgressBarState> get progressBarState => _progressBarState;
  bool get shuffleModeEnabled => _shuffleModeEnabled;
  ValueNotifier<LoopMode> get loopMode => _loopMode;
  ValueNotifier<Duration?> get timerDuration => _timerDuration;
  _init() async {
    await _loadLoudnessEnhancer();
    await _loadEqualizer();
    await _player.setAudioSource(_playlist);
    _listenToChangesInPlaylist();
    _listenToPlaybackState();
    _listenToCurrentPosition();
    _listenToBufferedPosition();
    _listenToTotalDuration();
    _listenToChangesInSong();
    _listenToShuffle();
    Timer.periodic(const Duration(seconds: 10), (timer) {
      if (currentSongNotifier.value != null && _player.playing) {
        GetIt.I<YTMusic>()
            .addPlayingStats(currentSongNotifier.value!.id, _player.position);
      }
    });
  }

  _loadLoudnessEnhancer() async {
    if (Platform.isAndroid && _loudnessEnhancer != null) {
      await _loudnessEnhancer
          .setEnabled(GetIt.I<SettingsManager>().loudnessEnabled);

      await _loudnessEnhancer
          .setTargetGain(GetIt.I<SettingsManager>().loudnessTargetGain);
    }
  }

  _loadEqualizer() async {
    if (!Platform.isAndroid) return;
    await _equalizer!.setEnabled(GetIt.I<SettingsManager>().equalizerEnabled);
    _equalizer!.parameters.then((value) async {
      _equalizerParams ??= value;
      final List<AndroidEqualizerBand> bands = _equalizerParams!.bands;
      if (GetIt.I<SettingsManager>().equalizerBandsGain.isEmpty) {
        GetIt.I<SettingsManager>().equalizerBandsGain =
            List.generate(bands.length, (index) => 0.0);
      }

      List<double> equalizerBandsGain =
          GetIt.I<SettingsManager>().equalizerBandsGain;
      for (var e in bands) {
        final gain =
            equalizerBandsGain.isNotEmpty ? equalizerBandsGain[e.index] : 0.0;
        _equalizerParams!.bands[e.index].setGain(gain);
      }
    });
  }

  Future<void> setLoudnessEnabled(bool value) async {
    if (Platform.isAndroid && _loudnessEnhancer != null) {
      await _loudnessEnhancer.setEnabled(value);
    }
    GetIt.I<SettingsManager>().loudnessEnabled = value;
  }

  Future<void> setEqualizerEnabled(bool value) async {
    await _equalizer?.setEnabled(value);
    GetIt.I<SettingsManager>().equalizerEnabled = value;
  }

  // Returns a Map representation of equalizer parameters for UI use.
  Future<Map?> getEqualizerParameters() async {
    if (!Platform.isAndroid || _equalizer == null) return null;
    final params = await _equalizer.parameters;
    _equalizerParams ??= params;
    final bands = _equalizerParams!.bands;
    final List<Map> bandList = bands
        .map((e) => {
              'centerFrequency': e.centerFrequency,
              'gain': e.gain,
              'index': e.index,
            })
        .toList();
    return {
      'maxDecibels': _equalizerParams!.maxDecibels,
      'minDecibels': _equalizerParams!.minDecibels,
      'bands': bandList
    };
  }

  Future<void> setEqualizerBandGain(int bandIndex, double gain) async {
    if (!Platform.isAndroid || _equalizer == null) return;
    await GetIt.I<SettingsManager>().setEqualizerBandsGain(bandIndex, gain);
    final params = await _equalizer.parameters;
    await params.bands[bandIndex].setGain(gain);
  }

  Future<void> setLoudnessTargetGain(double value) async {
    if (Platform.isAndroid && _loudnessEnhancer != null) {
      await _loudnessEnhancer.setTargetGain(value);
    }
    GetIt.I<SettingsManager>().loudnessTargetGain = value;
  }

  void _listenToChangesInPlaylist() async {
    _player.sequenceStream.listen((playlist) {
      if (playlist == _songList) return;
      bool shouldAdd = false;
      if ((_songList == null || _songList!.isEmpty) &&
          playlist != null &&
          playlist.isNotEmpty) {
        shouldAdd = true;
      }
      if (playlist == null || playlist.isEmpty) {
        _currentSongNotifier.value = null;
        _currentIndex.value == null;
        _songList = [];
      } else {
        _currentIndex.value ??= 0;
        _songList = playlist;

        _currentSongNotifier.value ??=
            (_songList!.length > _currentIndex.value!)
                ? _songList![_currentIndex.value!].tag
                : null;
      }
      if (shouldAdd == true && _currentSongNotifier.value != null) {
        addHistory(_currentSongNotifier.value!.extras!);
      }
      notifyListeners();
    });
  }

  void _listenToPlaybackState() {
    _player.playerStateStream.listen((event) {
      final isPlaying = event.playing;
      final processingState = event.processingState;
      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        _buttonState.value = ButtonState.loading;
      } else if (!isPlaying || processingState == ProcessingState.idle) {
        _buttonState.value = ButtonState.paused;
      } else if (processingState != ProcessingState.completed) {
        _buttonState.value = ButtonState.playing;
      } else {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  void _listenToCurrentPosition() {
    _player.positionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.current != position) {
        _progressBarState.value = ProgressBarState(
          current: position,
          buffered: oldState.buffered,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToBufferedPosition() async {
    _player.bufferedPositionStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.buffered != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: position,
          total: oldState.total,
        );
      }
    });
  }

  void _listenToTotalDuration() async {
    _player.durationStream.listen((position) {
      final oldState = _progressBarState.value;
      if (oldState.total != position) {
        _progressBarState.value = ProgressBarState(
          current: oldState.current,
          buffered: oldState.buffered,
          total: position ?? Duration.zero,
        );
      }
    });
  }

  void _listenToShuffle() {
    _player.shuffleModeEnabledStream.listen((data) {
      _shuffleModeEnabled = data;
      notifyListeners();
    });
  }

  void _listenToChangesInSong() async {
    _player.currentIndexStream.listen((index) {
      if (_songList != null && _currentIndex.value != index) {
        _currentIndex.value = index;
        _currentSongNotifier.value = index != null &&
                songList!.isNotEmpty &&
                _songList?.elementAt(index) != null
            ? _songList![index].tag
            : null;
        if (_songList!.isNotEmpty && _currentIndex.value != null) {
          MediaItem item = _songList![_currentIndex.value!].tag;
          addHistory(item.extras!);
        }
      }
    });
  }

  changeLoopMode() {
    switch (_loopMode.value) {
      case LoopMode.off:
        _loopMode.value = LoopMode.all;

        break;
      case LoopMode.all:
        _loopMode.value = LoopMode.one;
        break;
      default:
        _loopMode.value = LoopMode.off;
        break;
    }
    _player.setLoopMode(_loopMode.value);
  }

  Future<void> skipSilence(bool value) async {
    await _player.setSkipSilenceEnabled(value);
    GetIt.I<SettingsManager>().skipSilence = value;
  }

  Future<AudioSource> _getAudioSource(Map<String, dynamic> song) async {
    MediaItem tag = MediaItem(
      id: song['videoId'],
      title: song['title'] ?? 'Title',
      album: song['album']?['name'],
      artUri: Uri.parse(
          song['thumbnails']?.first['url'].replaceAll('w60-h60', 'w225-h225')),
      artist: song['artists']?.map((artist) => artist['name']).join(','),
      extras: song,
    );
    AudioSource audioSource;
    bool isDownloaded = song['status'] == 'DOWNLOADED' &&
        song['path'] != null &&
        (await File(song['path']).exists());
    if (isDownloaded) {
      audioSource = AudioSource.file(song['path'], tag: tag);
    } else {
      // audioSource = AudioSource.uri(
      //   Uri.parse(
      //       'https://invidious.nerdvpn.de/latest_version?id=${song['videoId']}'),
      //   tag: tag,
      // );

      audioSource = YouTubeAudioSource(
        videoId: song['videoId'],
        quality: GetIt.I<SettingsManager>().streamingQuality.name.toLowerCase(),
        tag: tag,
      );
    }
    return audioSource;
  }

  // void download() async {
  //   List<String> qualVidOptions = ['480p', '720p', '1080p', '2K', '4K'];
  //   List<String> qualAudOptions = ['64k', '128k', '192k', '256k', '320k'];

  //   String command =
  //       'yt-dlp -f \'bestvideo[height<=${qualVid.replaceAll('p', '')}]'
  //       '+bestaudio/best[height<=${qualVid.replaceAll('p', '')}]\' $ytUrl';
  //   if (dlAud) command += ' -x --audio-format mp3 --audio-quality ${qualAud}';
  //   if (dlThumb) command += ' --write-thumbnail';
  //   if (timeStart != null && timeEnd != null) {
  //     command +=
  //         ' --postprocessor-args "-ss ${timeStart!.format(context)} -to ${timeEnd!.format(context)}"';
  //   }
  //   Shell shell = Shell();
  //   if (kDebugMode) {
  //     print("Running command: ==================================== ");
  //     print(command);
  //   }
  //   await shell.run(command);
  // }

  Future<void> playSong(Map<String, dynamic> song,
      {bool autoFetch = true}) async {
    if (song['videoId'] != null) {
      // Always fully reset the player and playlist before playing online songs
      await _player.stop();
      _playlist.clear();
      _songList = [];
      // Re-initialize playlist to avoid null errors
      _playlist = ConcatenatingAudioSource(children: []);
      await _player.setAudioSource(_playlist);
      final source = await _getAudioSource(song);
      await _playlist.add(source);
      await _player.load();
      _player.play();
      if (autoFetch == true && song['status'] != 'DOWNLOADED') {
        List nextSongs =
            await GetIt.I<YTMusic>().getNextSongList(videoId: song['videoId']);
        nextSongs.removeAt(0);
        await _addSongListToQueue(nextSongs);
      }
    }
  }

  Future<void> playNext(Map<String, dynamic> song) async {
    if (song['videoId'] != null) {
      AudioSource audioSource = await _getAudioSource(song);
      int insertIndex = (_player.currentIndex ?? -1) + 1;
      // Clamp index to valid range
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > _playlist.length) insertIndex = _playlist.length;
      if (_playlist.length > 0) {
        await _playlist.insert(insertIndex, audioSource);
      } else {
        await _playlist.add(audioSource);
      }
    } else if (song['playlistId'] != null) {
      List songs =
          await GetIt.I<YTMusic>().getPlaylistSongs(song['playlistId']);
      await _addSongListToQueue(songs, isNext: true);
    }
    if (!_player.playing) {
      await _player.load();
      _player.play();
    }
  }

  playAll(List songs, {index = 0}) async {
    await _playlist.clear();
    await _addSongListToQueue(songs);
    await _player.seek(Duration.zero, index: index);
    if (!(_player.playing)) {
      _player.play();
    }
  }

  Future<void> addToQueue(Map<String, dynamic> song) async {
    if (song['videoId'] != null) {
      await _playlist.add(await _getAudioSource(song));
    } else if (song['playlistId'] != null) {
      List songs =
          await GetIt.I<YTMusic>().getPlaylistSongs(song['playlistId']);
      await _addSongListToQueue(songs, isNext: false);
    }
  }

  Future<void> startRelated(Map<String, dynamic> song,
      {bool radio = false, bool shuffle = false, bool isArtist = false}) async {
    await _playlist.clear();
    if (!isArtist) {
      await addToQueue(song);
    }
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        videoId: song['videoId'],
        playlistId: song['playlistId'],
        radio: radio,
        shuffle: shuffle);
    songs.removeAt(0);
    await _addSongListToQueue(songs, isNext: false);
    await _player.load();
    _player.play();
  }

  Future<void> startPlaylistSongs(Map endpoint) async {
    await playlist.clear();
    List songs = await GetIt.I<YTMusic>().getNextSongList(
        playlistId: endpoint['playlistId'], params: endpoint['params']);
    await _addSongListToQueue(songs);
    await _player.load();
    _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    await _playlist.clear();
    await _player.seek(Duration.zero, index: 0);
    _currentIndex.value = null;
    _currentSongNotifier.value = null;
    notifyListeners();
  }

  _addSongListToQueue(List songs, {bool isNext = false}) async {
    int index = _playlist.length;
    if (isNext) {
      index = _player.sequence == null || _player.sequence!.isEmpty
          ? 0
          : (currentIndex.value ?? -1) + 1;
    }
    // Clamp index to valid range
    if (index < 0) index = 0;
    if (index > _playlist.length) index = _playlist.length;
    await Future.forEach(songs, (song) async {
      Map<String, dynamic> mapSong = Map.from(song);
      await _playlist.insert(index, await _getAudioSource(mapSong));
      index++;
    });
  }

  setTimer(Duration duration) {
    int seconds = duration.inSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      _timerDuration.value = Duration(seconds: seconds);
      if (seconds == 0) {
        cancelTimer();
        _player.pause();
      }
      notifyListeners();
    });
  }

  cancelTimer() {
    _timerDuration.value = null;
    _timer?.cancel();
    notifyListeners();
  }
}

enum ButtonState { loading, paused, playing }

enum LoopState { off, all, one }

class ProgressBarState {
  Duration current;
  Duration buffered;
  Duration total;
  ProgressBarState(
      {this.current = Duration.zero,
      this.buffered = Duration.zero,
      this.total = Duration.zero});
}
