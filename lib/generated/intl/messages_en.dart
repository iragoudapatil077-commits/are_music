// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.
// @dart=2.12
// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = MessageLookup();

typedef String? MessageIfAbsent(
    String? messageStr, List<Object>? args);

class MessageLookup extends MessageLookupByLibrary {
  @override
  String get localeName => 'en';

  static m0(count) => "${Intl.plural(count, zero: 'No Songs', one: '1 Song', other: '${count} Songs')}";

  @override
  final Map<String, dynamic> messages = _notInlinedMessages(_notInlinedMessages);

  static Map<String, dynamic> _notInlinedMessages(_) => {
      'Albums': MessageLookupByLibrary.simpleMessage('Albums'),
    'Artists': MessageLookupByLibrary.simpleMessage('Artists'),
    'Battery_Optimisation_message': MessageLookupByLibrary.simpleMessage('Click here disable battery optimisation for ARE Music to work properly'),
    'Battery_Optimisation_title': MessageLookupByLibrary.simpleMessage('Battery Optimisation Detected'),
    'Buy_Me_A_Coffee': MessageLookupByLibrary.simpleMessage('Buy me a Coffee'),
    'Donate': MessageLookupByLibrary.simpleMessage('Donate'),
    'Donate_Message': MessageLookupByLibrary.simpleMessage('Support the development of ARE Music'),
    'Downloads': MessageLookupByLibrary.simpleMessage('Downloads'),
    'Favourites': MessageLookupByLibrary.simpleMessage('Favourites'),
    'Gyawun': MessageLookupByLibrary.simpleMessage('ARE Music'),
    'History': MessageLookupByLibrary.simpleMessage('History'),
    'Home': MessageLookupByLibrary.simpleMessage('Home'),
    'Next_Up': MessageLookupByLibrary.simpleMessage('Next Up'),
    'Pay_With_UPI': MessageLookupByLibrary.simpleMessage('Pay with UPI'),
    'Payment_Methods': MessageLookupByLibrary.simpleMessage('Payment Methods'),
    'Playlists': MessageLookupByLibrary.simpleMessage('Playlists'),
    'Saved': MessageLookupByLibrary.simpleMessage('Saved'),
    'Search_Gyawun': MessageLookupByLibrary.simpleMessage('Search ARE Music'),
    'Search_Settings': MessageLookupByLibrary.simpleMessage('Search Settings'),
    'Settings': MessageLookupByLibrary.simpleMessage('Settings'),
    'Shuffle': MessageLookupByLibrary.simpleMessage('Shuffle'),
    'Songs': MessageLookupByLibrary.simpleMessage('Songs'),
    'Subscriptions': MessageLookupByLibrary.simpleMessage('Subscriptions'),
    'Support_Me_On_Kofi': MessageLookupByLibrary.simpleMessage('Support me on Ko-fi'),
    'YTMusic': MessageLookupByLibrary.simpleMessage('YTMusic'),
    'nSongs': m0
  };
}
