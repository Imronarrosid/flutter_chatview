import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/chatview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/widgets/reaction_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/download_audio.dart';

class VoiceMessageView extends StatefulWidget {
  const VoiceMessageView({
    Key? key,
    required this.screenWidth,
    required this.message,
    required this.isMessageBySender,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.onMaxDuration,
    this.messageReactionConfig,
    this.config,
  }) : super(key: key);

  /// Provides configuration related to voice message.
  final VoiceMessageConfiguration? config;

  /// Allow user to set width of chat bubble.
  final double screenWidth;

  /// Provides message instance of chat.
  final Message message;
  final Function(int)? onMaxDuration;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  @override
  State<VoiceMessageView> createState() => _VoiceMessageViewState();
}

class _VoiceMessageViewState extends State<VoiceMessageView> {
  late PlayerController controller;
  late StreamSubscription<PlayerState> playerStateSubscription;

  final ValueNotifier<PlayerState> _playerState =
      ValueNotifier(PlayerState.stopped);

  PlayerState get playerState => _playerState.value;

  PlayerWaveStyle playerWaveStyle = const PlayerWaveStyle(scaleFactor: 70);

  final ValueNotifier<bool> _isFileExist = ValueNotifier(false);
  final ValueNotifier<double> _downloadProgress = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    controller = PlayerController()
      ..preparePlayer(
        path: widget.message.message,
        noOfSamples: widget.config?.playerWaveStyle
                ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
            playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
      ).whenComplete(() => widget.onMaxDuration?.call(controller.maxDuration));
    playerStateSubscription = controller.onPlayerStateChanged
        .listen((state) => _playerState.value = state);
    if (!widget.message.message.startsWith('https')) {
      // downloadFile(widget.message.message, widget.message.message);
      _isFileExist.value = true;
    }
  }

  @override
  void dispose() {
    playerStateSubscription.cancel();
    controller.dispose();
    _playerState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
        valueListenable: _isFileExist,
        builder: (context, value, child) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: widget.config?.decoration ??
                    BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: widget.isMessageBySender
                          ? widget.outgoingChatBubbleConfig?.color
                          : widget.inComingChatBubbleConfig?.color,
                    ),
                padding: widget.config?.padding ??
                    const EdgeInsets.symmetric(horizontal: 8),
                margin: widget.config?.margin ??
                    EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical:
                          widget.message.reaction.reactions.isNotEmpty ? 15 : 0,
                    ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<PlayerState>(
                      builder: (context, state, child) {
                        return IconButton(
                          onPressed: !value ? _dowloadFile : _playOrPause,
                          icon: !value
                              ? ValueListenableBuilder<double>(
                                  valueListenable: _downloadProgress,
                                  builder: (context, downloadProgress, _) {
                                    return DownloadProgressWidget(
                                      progress: downloadProgress / 100,
                                    );
                                  })
                              : state.isStopped ||
                                      state.isPaused ||
                                      state.isInitialised
                                  ? widget.config?.playIcon ??
                                      const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                      )
                                  : widget.config?.pauseIcon ??
                                      const Icon(
                                        Icons.stop,
                                        color: Colors.white,
                                      ),
                        );
                      },
                      valueListenable: _playerState,
                    ),
                    AudioFileWaveforms(
                      size: Size(widget.screenWidth * 0.50, 60),
                      playerController: controller,
                      waveformType: WaveformType.fitWidth,
                      playerWaveStyle:
                          widget.config?.playerWaveStyle ?? playerWaveStyle,
                      padding: widget.config?.waveformPadding ??
                          const EdgeInsets.only(right: 10),
                      margin: widget.config?.waveformMargin,
                      animationCurve:
                          widget.config?.animationCurve ?? Curves.easeIn,
                      animationDuration: widget.config?.animationDuration ??
                          const Duration(milliseconds: 500),
                      enableSeekGesture:
                          widget.config?.enableSeekGesture ?? true,
                    ),
                  ],
                ),
              ),
              if (widget.message.reaction.reactions.isNotEmpty)
                ReactionWidget(
                  isMessageBySender: widget.isMessageBySender,
                  message: widget.message,
                  messageReactionConfig: widget.messageReactionConfig,
                ),
            ],
          );
        });
  }

  void _dowloadFile() async {
    String? path = await downloadFile(
        widget.message.message, widget.message.message, (received, total) {
      _downloadProgress.value = (received / total * 100);
    });
    if (path != null) {
      controller = PlayerController()
        ..preparePlayer(
          path: path,
          noOfSamples: widget.config?.playerWaveStyle
                  ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
              playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
        ).whenComplete(
            () => widget.onMaxDuration?.call(controller.maxDuration));
      playerStateSubscription = controller.onPlayerStateChanged
          .listen((state) => _playerState.value = state);

      _isFileExist.value = true;
      _playOrPause();
    }
  }

  void _playOrPause() {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (playerState.isInitialised ||
        playerState.isPaused ||
        playerState.isStopped) {
      controller.startPlayer();
    } else {
      controller.pausePlayer();
    }
  }
}

class DownloadProgressWidget extends StatelessWidget {
  final double progress; // Progress value from 0.0 to 1.0

  const DownloadProgressWidget({
    Key? key,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            backgroundColor: Colors.grey.shade300,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
        const Icon(
          Icons.download,
          color: Colors.white,
          size: 24,
        ),
      ],
    );
  }
}
