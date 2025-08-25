import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ytmusic/ytmusic.dart';

Box _box = Hive.box('SETTINGS');

addHistory(Map song) async {
  if (_box.get('PLAYBACK_HISTORY', defaultValue: true)) {
    await addLocalHistory(song);
  }
  if (_box.get('PERSONALISED_CONTENT', defaultValue: true) &&
      song['status'] != 'DOWNLOADED') {
    final vid = song['videoId'];
    if (vid is String && vid.isNotEmpty) {
      GetIt.I<YTMusic>().addYoutubeHistory(vid);
    }
  }
}

addLocalHistory(Map song) async {
  Box box = Hive.box('SONG_HISTORY');
  var key = song['videoId'];
  if (key is! String && key is! int) {
    key = key?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
  }
  Map? oldState = box.get(key);
  int timestamp = DateTime.now().millisecondsSinceEpoch;
  if (oldState != null) {
    await box.put(key,
        {...oldState, 'plays': oldState['plays'] + 1, 'updatedAt': timestamp});
  } else {
    await box.put(key,
        {...song, 'plays': 1, 'CreatedAt': timestamp, 'updatedAt': timestamp});
  }
}
