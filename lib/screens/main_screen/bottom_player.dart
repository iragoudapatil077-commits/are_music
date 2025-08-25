import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/media_player.dart';
import '../../utils/enhanced_image.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<dynamic>(
      valueListenable: GetIt.I<MediaPlayer>().currentSongNotifier,
      builder: (context, currentSong, child) {
        if (currentSong == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: SizedBox(
            height: 65,
            child: Stack(
              children: [
                // Glass effect layer
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.05),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Content and controls
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => context.push('/player'),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Dismissible(
                            key: Key('bottomplayer${currentSong.id}'),
                            direction: DismissDirection.down,
                            confirmDismiss: (direction) async {
                              await GetIt.I<MediaPlayer>().stop();
                              return true;
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  // Album art
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: currentSong.extras?['offline'] ==
                                                true &&
                                            !currentSong.artUri
                                                .toString()
                                                .startsWith('https')
                                        ? Image.file(
                                            File.fromUri(currentSong.artUri!),
                                            height: 40,
                                            width: 40,
                                            fit: BoxFit.cover,
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: getEnhancedImage(
                                              (currentSong.extras != null &&
                                                      currentSong.extras![
                                                              'thumbnails']
                                                          is List &&
                                                      (currentSong.extras![
                                                                  'thumbnails']
                                                              as List)
                                                          .isNotEmpty)
                                                  ? (currentSong.extras![
                                                          'thumbnails'] as List)
                                                      .first['url']
                                                  : '',
                                              dp: MediaQuery.of(context)
                                                  .devicePixelRatio,
                                              width: 40,
                                            ),
                                            height: 40,
                                            width: 40,
                                            fit: BoxFit.cover,
                                            errorWidget: (context, url, error) {
                                              return Container(
                                                color: Colors.grey[900],
                                                child: const Icon(
                                                    Icons.music_note,
                                                    color: Colors.white),
                                              );
                                            },
                                          ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Song info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          currentSong.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (currentSong.artist != null ||
                                            currentSong.extras!['subtitle'] !=
                                                null)
                                          Text(
                                            currentSong.artist ??
                                                currentSong.extras!['subtitle'],
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Controls
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (context
                                          .watch<MediaPlayer>()
                                          .player
                                          .hasPrevious)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.skip_previous,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            GetIt.I<MediaPlayer>()
                                                .player
                                                .seekToPrevious();
                                          },
                                        ),
                                      const SizedBox(width: 4),
                                      ValueListenableBuilder(
                                        valueListenable:
                                            GetIt.I<MediaPlayer>().buttonState,
                                        builder: (context, buttonState, child) {
                                          return Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                            ),
                                            child: buttonState ==
                                                    ButtonState.loading
                                                ? const Center(
                                                    child: SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : IconButton(
                                                    padding: EdgeInsets.zero,
                                                    icon: Icon(
                                                      buttonState ==
                                                              ButtonState
                                                                  .playing
                                                          ? Icons.pause
                                                          : Icons.play_arrow,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    onPressed: () {
                                                      GetIt.I<MediaPlayer>()
                                                              .player
                                                              .playing
                                                          ? GetIt.I<
                                                                  MediaPlayer>()
                                                              .player
                                                              .pause()
                                                          : GetIt.I<
                                                                  MediaPlayer>()
                                                              .player
                                                              .play();
                                                    },
                                                  ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      if (context
                                          .watch<MediaPlayer>()
                                          .player
                                          .hasNext)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.skip_next,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            GetIt.I<MediaPlayer>()
                                                .player
                                                .seekToNext();
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
