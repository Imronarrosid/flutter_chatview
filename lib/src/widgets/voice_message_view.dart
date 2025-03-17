import 'dart:async';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/chatview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/mixins/loading_state_mixin.dart';
import 'package:chatview/src/widgets/reaction_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/download_audio.dart';
import 'timed_and_receipt_message_widget.dart';

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
    required this.chatController,
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

  final ChatController chatController;

  @override
  State<VoiceMessageView> createState() => _VoiceMessageViewState();
}

class _VoiceMessageViewState extends State<VoiceMessageView>
    with AutomaticKeepAliveClientMixin {
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

    if (!widget.message.mediaPath.startsWith('https')) {
      // downloadFile(widget.message.message, widget.message.message);
      controller = PlayerController()
        ..preparePlayer(
          path: widget.message.mediaPath,
          noOfSamples: widget.config?.playerWaveStyle
                  ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
              playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
        ).whenComplete(() {
          widget.onMaxDuration?.call(controller.maxDuration);
          controller.setFinishMode(
            finishMode: FinishMode.pause,
          );
        });
      playerStateSubscription = controller.onPlayerStateChanged
          .listen((state) => _playerState.value = state);

      _isFileExist.value = true;
    } else {
      isFileDownloaded(widget.message.id).then((value) {
        bool isDownloaded = value.$1;
        String? path = value.$2;
        if (isDownloaded) {
          controller = PlayerController()
            ..preparePlayer(
              path: path,
              noOfSamples: widget.config?.playerWaveStyle
                      ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
                  playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
            ).whenComplete(() {
              _isFileExist.value = isDownloaded;
              controller.setFinishMode(
                finishMode: FinishMode.stop,
              );
              widget.onMaxDuration?.call(controller.maxDuration);
            });
          playerStateSubscription = controller.onPlayerStateChanged
              .listen((state) => _playerState.value = state);
        }
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    if (_isFileExist.value) {
      playerStateSubscription.cancel();
      controller.dispose();
      _playerState.dispose();
      _downloadProgress.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ValueListenableBuilder<bool>(
        valueListenable: _isFileExist,
        builder: (context, isFileExsit, child) {
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
                // padding: widget.config?.padding ??
                //     const EdgeInsets.symmetric(horizontal: 8),
                margin: widget.config?.margin ??
                    EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical:
                          widget.message.reaction.reactions.isNotEmpty ? 15 : 0,
                    ),
                child: TimedAndReceiptMessageWidget(
                  chatController: widget.chatController,
                  isMessageBySender: widget.isMessageBySender,
                  message: widget.message,
                  inComingChatBubbleConfig: widget.inComingChatBubbleConfig,
                  outgoingChatBubbleConfig: widget.outgoingChatBubbleConfig,
                  messagePadding:
                      widget.config?.waveformPadding ?? const EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isFileExsit)
                        DownloadProgressWidget(
                          progress: _downloadProgress,
                          onPressed: _downloadFile,
                          config: widget.config,
                        )
                      else
                        ValueListenableBuilder<PlayerState>(
                          builder: (context, state, child) {
                            return IconButton(
                              onPressed: _playOrPause,
                              icon: state.isStopped ||
                                      state.isPaused ||
                                      state.isInitialised
                                  ? widget.config?.playIcon ??
                                      Icon(
                                        Icons.play_arrow,
                                        color: widget.config?.waveColor ??
                                            Colors.white,
                                      )
                                  : widget.config?.pauseIcon ??
                                      Icon(
                                        Icons.stop,
                                        color: widget.config?.waveColor ??
                                            Colors.white,
                                      ),
                            );
                          },
                          valueListenable: _playerState,
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWave(isFileExsit),
                          Padding(
                            padding: const EdgeInsets.only(top: 3, bottom: 6),
                            child: Text(
                              (widget.message.voiceMessageDuration ??
                                      Duration.zero)
                                  .toMMSS(),
                              style: widget.config?.durationTextStyle ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: null,
                        icon: Column(
                          children: [
                            widget.config?.voiceIcon ??
                                Icon(Icons.mic_rounded,
                                    color: widget.config?.waveColor ??
                                        Colors.white),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildWave(bool isFileExsit) {
    if (isFileExsit) {
      return AudioFileWaveforms(
        size: Size(widget.screenWidth * 0.30, 35),
        playerController: controller,
        waveformType: WaveformType.fitWidth,
        playerWaveStyle: widget.config?.playerWaveStyle ?? playerWaveStyle,
        margin: widget.config?.waveformMargin,
        animationCurve: widget.config?.animationCurve ?? Curves.easeIn,
        animationDuration: widget.config?.animationDuration ??
            const Duration(milliseconds: 500),
        enableSeekGesture: widget.config?.enableSeekGesture ?? true,
      );
    } else {
      return SizedBox(
        width: widget.screenWidth * 0.30,
        height: 35,
        child: UnconstrainedBox(
          child: SizedBox.fromSize(
            size: Size(widget.screenWidth * 0.30, 2),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 4,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.config?.unDownoadedWaveColor ?? Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _downloadFile() async {
    String? path = await downloadFile(widget.message.mediaPath, widget.message.id,
        (received, total) {
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

class DownloadProgressWidget extends StatefulWidget {
  final ValueListenable<double> progress; // Progress value from 0.0 to 1.0
  final VoiceMessageConfiguration? config;
  final Future<void> Function() onPressed;

  const DownloadProgressWidget({
    Key? key,
    required this.progress,
    this.config,
    required this.onPressed,
  }) : super(key: key);

  @override
  State<DownloadProgressWidget> createState() => _DownloadProgressWidgetState();
}

class _DownloadProgressWidgetState extends State<DownloadProgressWidget>
    with LoadingStateMixin {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
        valueListenable: widget.progress,
        builder: (context, downloadProgress, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.config?.circularProgressIndicatorSize,
                height: widget.config?.circularProgressIndicatorSize,
                child: CircularProgressIndicator(
                  value: widget.progress.value / 100,
                  strokeWidth: 1,
                  backgroundColor:
                      widget.config?.bgProgressColor ?? Colors.grey.shade100,
                  color: widget.config?.progressColor ?? Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  withLoading(widget.onPressed);
                },
                icon: widget.config?.downloadIcon ??
                    Icon(
                      Icons.download,
                      color: widget.config?.waveColor ?? Colors.white,
                      size: 20,
                    ),
              ),
            ],
          );
        });
  }
}
