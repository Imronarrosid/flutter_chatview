/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'dart:async';
import 'dart:io' show File, Platform, Directory;
import 'dart:math' as Math;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/models/config_models/audio_record_config.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../chatview.dart';
import '../utils/concate_audio.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';
import 'scale_transition_wrapper.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
    this.audioRecordConfig,
  }) : super(key: key);

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides focusNode for focusing text field.
  final FocusNode focusNode;

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  final AudioRecordConfig? audioRecordConfig;

  /// Provides playerwave style
  final PlayerWaveStyle playerWaveStyle = const PlayerWaveStyle(
    liveWaveColor: Colors.black,
    fixedWaveColor: Colors.black26,
    backgroundColor: Colors.white,
  );

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
  final double inputFieldHeight = 48.0;

  final ValueNotifier<String> _inputText = ValueNotifier('');
  final ValueNotifier<String> _recordingPath = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;
  AudioRecorder? _recorderController;
  PlayerController? _playerController;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  // Variables for hold-to-record feature
  ValueNotifier<bool> isHoldingRecord = ValueNotifier(false);
  ValueNotifier<double> horizontalDragOffset = ValueNotifier(0.0);
  ValueNotifier<double> verticalDragOffset = ValueNotifier(0.0);
  ValueNotifier<bool> isCancelling = ValueNotifier(false);
  ValueNotifier<bool> _isRecordingLocked = ValueNotifier(false);
  Timer? lockRecordingTimer;
  String? _audioSegment1;
  String? _audioSegment2;

  // Variables for recording time counter and blinking mic
  ValueNotifier<int> recordingDuration = ValueNotifier(0);
  ValueNotifier<bool> showMicIcon = ValueNotifier(true);

  Timer? blinkTimer;

  // Add new variables for lock indicator
  ValueNotifier<double> lockIndicatorOffset = ValueNotifier(0.0);
  bool wasSwipedUp = false;
  ValueNotifier<bool> isPaused = ValueNotifier(false);

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig => widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig => sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig => sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration => sendMessageConfig?.cancelRecordConfiguration;

  HoldToRecordConfiguration? get holdToRecordConfig => sendMessageConfig?.holdToRecordConfiguration;

  ValueNotifier<TypeWriterStatus> composingStatus = ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isRunning = ValueNotifier<bool>(false);
  Timer? _timer;

  bool lockAnimationEnd = false;
  @override
  void initState() {
    attachListeners();
    debouncer =
        Debouncer(sendMessageConfig?.textFieldConfig?.compositionThresholdTime ?? const Duration(seconds: 1));
    super.initState();

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      controller = RecorderController();
      _recorderController = AudioRecorder();
    }
  }

  double get _bottomPadding => (!kIsWeb && Platform.isIOS)
      ? (widget.focusNode.hasFocus
          ? bottomPadding1
          : View.of(context).viewPadding.bottom > 0
              ? bottomPadding2
              : bottomPadding3)
      : bottomPadding3;

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    isHoldingRecord.dispose();
    horizontalDragOffset.dispose();
    verticalDragOffset.dispose();
    isCancelling.dispose();
    recordingDuration.dispose();
    showMicIcon.dispose();
    lockRecordingTimer?.cancel();
    blinkTimer?.cancel();
    lockIndicatorOffset.dispose();
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping?.call(composingStatus.value);
    });
  }

  void _startTimer() {
    if (!_isRecordingLocked.value) {
      _resetTimer();
    }
    if (!_isRunning.value) {
      _isRunning.value = true;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _seconds.value++;
      });
    }
  }

  void _pauseTimer() {
    if (_isRunning.value && _timer != null) {
      _timer!.cancel();
      _isRunning.value = false;
    }
  }

  void _resumeTimer() {
    _startTimer();
  }

  void _resetTimer() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _seconds.value = 0;
    _isRunning.value = false;
  }

  // Format seconds to mm:ss
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: _isRecordingLocked,
        builder: (context, isRecordingLocked, child) {
          return StreamBuilder<RecordState>(
              stream: _recorderController?.onStateChanged(),
              builder: (context, recorderStateSnapshot) {
                final recorderState = recorderStateSnapshot.data ?? RecordState.stop;
                return ValueListenableBuilder<double>(
                    valueListenable: horizontalDragOffset,
                    builder: (context, snapshot, _) {
                      double padding = snapshot.isNegative ? snapshot.abs() : 0;
                      double finalPadding =
                          (recorderState == RecordState.stop || !snapshot.isNegative || isRecordingLocked)
                              ? 0
                              : padding > 60
                                  ? 60
                                  : padding;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: ValueListenableBuilder(
                                valueListenable: isRecording,
                                builder: (context, isRecordingValue, child) {
                                  return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 120),
                                      layoutBuilder: (_, __) {
                                        if (isRecordingValue &&
                                            recorderState == RecordState.record &&
                                            !isRecordingLocked) {
                                          return AnimatedOpacity(
                                            duration: const Duration(milliseconds: 120),
                                            opacity: horizontalDragOffset.value.isNegative ? 0.0 : 1.0,
                                            child: RepaintBoundary(
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 120),
                                                curve: Curves.linear,
                                                transform: Matrix4.translationValues(
                                                  0,
                                                  horizontalDragOffset.value.isNegative ? 60 : 0,
                                                  0,
                                                ),
                                                child: ValueListenableBuilder<double>(
                                                    valueListenable: verticalDragOffset,
                                                    builder: (context, verticalOffset, _) {
                                                      return Padding(
                                                        // duration: const Duration(milliseconds: 20),
                                                        // curve: Curves.easeInOut,
                                                        padding: EdgeInsets.only(
                                                            bottom: !verticalOffset.isNegative
                                                                ? 0
                                                                : (verticalOffset.abs())),
                                                        child: IconButton(
                                                          onPressed: () {},
                                                          style: IconButton.styleFrom(
                                                            backgroundColor: voiceRecordingConfig?.backgroundColor,
                                                          ),
                                                          icon: Icon(Icons.lock,
                                                              color: voiceRecordingConfig?.playIconColor ??
                                                                  Colors.black),
                                                        ),
                                                      );
                                                    }),
                                              ),
                                            ),
                                          );
                                        }
                                        if (recorderState == RecordState.record && isRecordingLocked) {
                                          return IconButton(
                                            onPressed: () {
                                              _pauseRecording();
                                            },
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  voiceRecordingConfig?.backgroundColor ?? Colors.white,
                                            ),
                                            icon: voiceRecordingConfig?.pauseIcon ??
                                                Icon(
                                                  Icons.pause,
                                                  color: voiceRecordingConfig?.pauseIconColor ?? Colors.black87,
                                                ),
                                          );
                                        }
                                        if (recorderState == RecordState.stop && isRecordingLocked) {
                                          return IconButton(
                                            onPressed: () {
                                              _startRecording();
                                            },
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  voiceRecordingConfig?.backgroundColor ?? Colors.white,
                                            ),
                                            icon: voiceRecordingConfig?.micIcon ??
                                                Icon(
                                                  Icons.mic,
                                                  color: voiceRecordingConfig?.micIconColor ?? Colors.black87,
                                                ),
                                          );
                                        }

                                        return const SizedBox.shrink();
                                      });
                                }),
                          ),
                          const SizedBox(
                            height: 50,
                          ),
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              bottomPadding4,
                              bottomPadding4,
                              bottomPadding4,
                              _bottomPadding,
                            ),
                            decoration: BoxDecoration(
                              color: recorderState == RecordState.record ||
                                      (recorderState == RecordState.stop && isRecordingLocked)
                                  ? sendMessageConfig?.textFieldBackgroundColor ?? Colors.white
                                  : null,
                            ),
                            child: ValueListenableBuilder<double>(
                                valueListenable: horizontalDragOffset,
                                builder: (context, snapshot, _) {
                                  double padding = snapshot.isNegative ? snapshot.abs() : 0;
                                  double finalPadding = (recorderState == RecordState.stop ||
                                          !snapshot.isNegative ||
                                          isRecordingLocked)
                                      ? 0
                                      : padding > 60
                                          ? 60
                                          : padding;
                                  return Stack(
                                    children: [
                                      // if (recorderState == RecordState.record)
                                      //   _recordingBackground(recorderState, snapshot, finalPadding),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        padding: EdgeInsets.only(
                                          right: finalPadding,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Stack(
                                                children: [
                                                  Visibility(
                                                    visible:
                                                        recorderState != RecordState.record && !isRecordingLocked,
                                                    maintainState: true,
                                                    child: TextFieldView(
                                                      inputText: _inputText,
                                                      textFieldConfig: textFieldConfig,
                                                      sendMessageConfig: sendMessageConfig,
                                                      focusNode: widget.focusNode,
                                                      textEditingController: widget.textEditingController,
                                                      onPressed: widget.onPressed,
                                                      onImageSelected: widget.onImageSelected,
                                                    ),
                                                  ),
                                                  ValueListenableBuilder<String>(
                                                      valueListenable: _recordingPath,
                                                      builder: (context, snapshot, _) {
                                                        return StreamBuilder<PlayerState>(
                                                            stream: _playerController?.onPlayerStateChanged,
                                                            builder: (_, pState) {
                                                              final PlayerState? playerState = pState.data;

                                                              int maxDuration =
                                                                  _playerController?.maxDuration ?? 0;

                                                              if (playerState != null &&
                                                                  // (playerState.isInitialised) &&
                                                                  // recorderState.isPaused &&
                                                                  _recorderController != null &&
                                                                  !kIsWeb &&
                                                                  _isRecordingLocked.value &&
                                                                  recorderState == RecordState.stop) {
                                                                return _pausedRecordView(
                                                                    playerState, snapshot, context, maxDuration);
                                                              } else if (_recorderController != null &&
                                                                  recorderState == RecordState.record) {
                                                                return _recordingView(
                                                                    recorderState, isRecordingLocked);
                                                              } else {
                                                                return const SizedBox.shrink();
                                                              }
                                                            });
                                                      }),
                                                ],
                                              ),
                                            ),
                                            ShowSendMessageButton(
                                              recorderState: recorderState,
                                              isRecordingLocked: isRecordingLocked,
                                              sendMessageConfig: sendMessageConfig,
                                              voiceRecordingConfig: voiceRecordingConfig,
                                              onFinishRecording: _stopRecording,
                                              onVerticalDragUpdate: _onVerticalDragUpdate,
                                              onHorizontalDragUpdate: _onHorizontalDragUpdate,
                                              inputText: _inputText,
                                              sendMessage: () {
                                                widget.onPressed();
                                                _inputText.value = '';
                                              },
                                              startRecording: _startRecording,
                                              stopRecording: _stopRecording,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                          ),
                        ],
                      );
                    });
              });
        });
  }

  void _onHorizontalDragUpdate(horizontalOffset) {
    horizontalDragOffset.value = horizontalOffset;
    if (horizontalOffset < -(holdToRecordConfig?.cancelSwipeThreshold ?? 50.0) && (isRecording.value)) {
      _cancelRecording();

      HapticFeedback.lightImpact();
    }
  }

  void _onVerticalDragUpdate(verticalOffset) {
    if (verticalOffset < -(holdToRecordConfig?.cancelSwipeThreshold ?? 75.0)) {
      _isRecordingLocked.value = true;
    } else {
      verticalDragOffset.value = verticalOffset;
      // _isRecordingLocked.value = false;
    }
  }

  Container _recordingBackground(RecordState recorderState, double snapshot, double finalPadding) {
    return Container(
      height: inputFieldHeight,
      margin:
          EdgeInsets.only(right: (recorderState == RecordState.stop || !snapshot.isNegative) ? 0 : finalPadding),
      padding: voiceRecordingConfig?.padding ??
          EdgeInsets.symmetric(
            horizontal: cancelRecordConfiguration == null ? 8 : 5,
          ),
      decoration: voiceRecordingConfig?.decoration ??
          BoxDecoration(
            color: voiceRecordingConfig?.backgroundColor,
            borderRadius: BorderRadius.circular(50.0),
          ),
    );
  }

  Container _recordingView(RecordState recorderState, bool isRecordingLocked) {
    return Container(
      height: inputFieldHeight,
      padding: voiceRecordingConfig?.padding ??
          EdgeInsets.symmetric(
            horizontal: cancelRecordConfiguration == null ? 8 : 5,
          ),
      margin: voiceRecordingConfig?.margin,
      decoration: voiceRecordingConfig?.decoration ??
          BoxDecoration(
            color: voiceRecordingConfig?.backgroundColor,
            borderRadius: BorderRadius.circular(50.0),
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Blinking mic icon
          ValueListenableBuilder<bool>(
              valueListenable: showMicIcon,
              builder: (context, isShowMic, _) {
                return Opacity(
                  opacity: isShowMic ? 1.0 : 0.3,
                  child: Icon(
                    Icons.mic,
                    color: voiceRecordingConfig?.recorderIconColor ?? Colors.red,
                    size: 24,
                  ),
                );
              }),
          const SizedBox(width: 12),
          // Time counter
          ValueListenableBuilder<int>(
            valueListenable: _seconds,
            builder: (context, duration, __) {
              return Text(
                _formatDuration(duration),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: voiceRecordingConfig?.recorderIconColor ?? Colors.black,
                ),
              );
            },
          ),
          if (recorderState == RecordState.record && !isRecordingLocked) ...[
            const Spacer(),
            const SizedBox(
              width: 166,
              child: SwipeLeftAnimation(
                curve: Curves.ease,
                duration: Duration(
                  milliseconds: 800,
                ),
                alignments: [
                  Alignment.centerLeft,
                  Alignment.centerRight,
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_left_rounded),
                    SizedBox(width: 4),
                    Text('swipe left to cancel'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12)
          ] else
            Padding(
              padding: const EdgeInsets.only(left: 85.0),
              child: TextButton(
                onPressed: () {
                  _cancelRecording();
                },
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  foregroundColor: voiceRecordingConfig?.deleteIconColor ?? Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                ),
                child: Text(
                  Platform.localeName == 'id_ID' ? 'BATAL' : 'CANCEL',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Row _pausedRecordView(PlayerState playerState, String snapshot, BuildContext context, int maxDuration) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            _cancelRecording();
          },
          icon: voiceRecordingConfig?.deleteIcon ??
              Icon(Icons.delete, color: voiceRecordingConfig?.deleteIconColor ?? Colors.red),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: voiceRecordingConfig?.playerWaveStyle.backgroundColor,
              borderRadius: BorderRadius.circular(50.0),
            ),
            child: Row(
              children: [
                BuildPlayButton(
                  voiceRecordingConfig: voiceRecordingConfig,
                  playerState: playerState,
                  playerController: _playerController,
                ),
                Expanded(
                  child: AudioFileWaveforms(
                    key: Key(snapshot),
                    backgroundColor: voiceRecordingConfig?.playerWaveStyle.backgroundColor,
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: voiceRecordingConfig?.playerWaveStyle ??
                        const PlayerWaveStyle(
                          fixedWaveColor: Colors.white38,
                          liveWaveColor: Colors.white,
                          backgroundColor: Color(0xffEE5366),
                          waveThickness: 4.0,
                          spacing: 6.0,
                        ),
                    // playerWaveStyle: widget.playerWaveStyle,
                    size: Size(MediaQuery.of(context).size.width * 0.4, 30),
                    playerController: _playerController!,
                    margin: voiceRecordingConfig?.margin,
                    padding: voiceRecordingConfig?.padding ?? const EdgeInsets.fromLTRB(0, 6, 10, 6),
                    decoration: voiceRecordingConfig?.decoration ??
                        BoxDecoration(
                          color: voiceRecordingConfig?.playerWaveStyle.backgroundColor,
                          borderRadius: BorderRadius.circular(50.0),
                        ),

                    // playerWaveStyle: voiceRecordingConfig?.waveStyle ??
                    //     WaveStyle(
                    //       extendWaveform: true,
                    //       showMiddleLine: false,
                    //       waveColor: voiceRecordingConfig?.waveStyle?.waveColor ?? Colors.black,
                    //     ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: StreamBuilder<int>(
                      initialData: 0,
                      stream: _playerController?.onCurrentDurationChanged,
                      builder: (context, duration) {
                        int currentDuration = duration.data ?? 0;
                        TextStyle timeStyle = const TextStyle(
                          color: Colors.white,
                        );
                        if (!playerState.isPlaying && currentDuration == 0) {
                          return Text(
                            _formatDuration((maxDuration / 1000).toInt()),
                            style: timeStyle,
                          );
                        }
                        return Text(
                          _formatDuration((currentDuration / 1000).toInt()),
                          style: timeStyle,
                        );
                      }),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Stop recording for hold-to-record feature
  Future<void> _stopRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    // Cancel all timers

    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    _resetTimer();

    // Reset timer variables

    blinkTimer = null;
    lockRecordingTimer = null;

    bool _isRecording = await _recorderController!.isRecording();

    if (!(_isRecording)) return;

    isHoldingRecord.value = false;

    // // If was swiped up, lock the recording
    // if (wasSwipedUp) {
    //   _isRecordingLocked.value = true;
    //   showLockIndicator.value = true; // Keep showing the pause button
    //   return;
    // }

    // // Check if we should cancel based on horizontal drag
    // if (isCancelling.value) {
    //   _cancelRecording();
    //   return;
    // }

    _isRecordingLocked.value = false;
    // final path = await controller?.stop();
    final Directory tempDir = await getTemporaryDirectory();

    // final path = await controller?.stop();
    final path = await _recorderController?.stop();
    if (path == null) return;
    if (_audioSegment1 == null) {
      _audioSegment1 = path;
    } else {
      _audioSegment2 = path;
      File result = await concatenateWavFiles([_audioSegment1!, _audioSegment2!],
          '${tempDir.path}/voice_messagect_${DateTime.now().millisecondsSinceEpoch}.m4a');
      _audioSegment1 = result.path;
      // _recordingPath.value = result.path;
    }
    isRecording.value = false;
    wasSwipedUp = false;
    isPaused.value = false;
    widget.onRecordingComplete(_audioSegment1);
  }

  // Stop recording for hold-to-record feature
  Future<void> _pauseRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    // Cancel all timers

    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    _pauseTimer();

    // Reset timer variables

    blinkTimer = null;
    lockRecordingTimer = null;

    bool _isRecording = await _recorderController!.isRecording();

    if (!(_isRecording) || !_isRecordingLocked.value) return;

    isHoldingRecord.value = false;

    // // If was swiped up, lock the recording
    // if (wasSwipedUp) {
    //   _isRecordingLocked.value = true;
    //   showLockIndicator.value = true; // Keep showing the pause button
    //   return;
    // }

    // // Check if we should cancel based on horizontal drag
    // if (isCancelling.value) {
    //   _cancelRecording();
    //   return;
    // }
    final Directory tempDir = await getTemporaryDirectory();

    // final path = await controller?.stop();
    final path = await _recorderController?.stop();
    if (path == null) return;
    if (_audioSegment1 == null) {
      _audioSegment1 = path;
    } else {
      _audioSegment2 = path;
      File result = await concatenateWavFiles([_audioSegment1!, _audioSegment2!],
          '${tempDir.path}/voice_messagect_${DateTime.now().millisecondsSinceEpoch}.m4a');
      _audioSegment1 = result.path;
      _recordingPath.value = result.path;
    }
    double screenWidth = !mounted ? 100 : MediaQuery.of(context).size.width;
    // _playerController = null;
    _playerController = PlayerController()
      ..preparePlayer(
              path: _audioSegment1!, noOfSamples: widget.playerWaveStyle.getSamplesForWidth(screenWidth * 0.4))
          .whenComplete(() {
        _playerController?.setFinishMode(
          finishMode: FinishMode.pause,
        );
      });
    isRecording.value = false;
    // _isRecordingLocked.value = true;
    wasSwipedUp = false;
    isPaused.value = false;
    // widget.onRecordingComplete(path);
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );

    // Cancel all timers

    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables

    blinkTimer = null;
    lockRecordingTimer = null;
    bool isRecord = await _recorderController!.isRecording();
    if (!isRecord && !_isRecordingLocked.value) return;
    await _recorderController?.cancel();

    // final path = await controller?.stop();
    isRecording.value = false;
    isHoldingRecord.value = false;
    _isRecordingLocked.value = false;
    isRecording.value = false;
    isPaused.value = false;
    _audioSegment1 = null;
    _audioSegment2 = null;
  }

  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      await controller?.record(
        sampleRate: voiceRecordingConfig?.sampleRate,
        bitRate: voiceRecordingConfig?.bitRate,
        androidEncoder: voiceRecordingConfig?.androidEncoder,
        iosEncoder: voiceRecordingConfig?.iosEncoder,
        androidOutputFormat: AndroidOutputFormat.mpeg4,
      );
      isRecording.value = true;
    } else {
      final path = await controller?.stop();
      isRecording.value = false;
      widget.onRecordingComplete(path);
    }
  }

  // Start recording for hold-to-record feature
  Future<void> _startRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (_recorderController == null) return;
    final bool hasPermission = await Permission.microphone.isGranted;

    if (!hasPermission) await Permission.microphone.request();
    if (!hasPermission) return;

    // Cancel any existing timers first

    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    final bool isStatusRecord = await _recorderController!.isRecording();
    _startTimer();

    if (isStatusRecord) return;
    if (!_isRecordingLocked.value && _audioSegment1 == null) {
      horizontalDragOffset.value = 0.0;
      verticalDragOffset.value = 0.0;
      _isRecordingLocked.value = false;
      isCancelling.value = false;
      isHoldingRecord.value = true;
      _isRecordingLocked.value = false;
      recordingDuration.value = 0;
      showMicIcon.value = true;
      wasSwipedUp = false;
      lockIndicatorOffset.value = 0.0;
      isPaused.value = false;
    }
    if (_playerController?.playerState.isPlaying ?? false) {
      _playerController?.dispose();
    }
    final Directory tempDir = await getTemporaryDirectory();

    String path = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorderController
        ?.start(const RecordConfig(encoder: AudioEncoder.wav, androidConfig: AndroidRecordConfig()), path: path);
    // await controller?.record(
    //   path: path,
    //   sampleRate: voiceRecordingConfig?.sampleRate,
    //   bitRate: voiceRecordingConfig?.bitRate,
    //   androidEncoder: voiceRecordingConfig?.androidEncoder,
    //   iosEncoder: voiceRecordingConfig?.iosEncoder,
    //   androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
    // );
    _recordingPath.value = path;
    isRecording.value = true;

    // Ensure timers are null before creating new ones

    blinkTimer = null;

    // Start blinking mic icon
    blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      showMicIcon.value = !showMicIcon.value;
    });

    // // Set up timer for locking recording if configured
    // lockRecordingTimer?.cancel();
    // if (holdToRecordConfig?.lockRecordingAfterDuration != null) {
    //   lockRecordingTimer = Timer(holdToRecordConfig!.lockRecordingAfterDuration!, () {
    //     _isRecordingLocked.value = true;
    //   });
    // }
  }

  AudioRecordConfig get audioRecordConfig => widget.audioRecordConfig ?? const AudioRecordConfig();
}

class BuildPlayButton extends StatelessWidget {
  final PlayerState playerState;
  const BuildPlayButton({
    super.key,
    required PlayerController? playerController,
    required this.playerState,
    this.voiceRecordingConfig,
  }) : _playerController = playerController;

  final PlayerController? _playerController;
  final VoiceRecordingConfiguration? voiceRecordingConfig;

  @override
  Widget build(BuildContext context) {
    if (playerState.isPlaying) {
      return IconButton(
        onPressed: () {
          _playerController?.pausePlayer();
        },
        icon: voiceRecordingConfig?.pauseIcon ??
            Icon(
              Icons.pause,
              color: voiceRecordingConfig?.pauseIconColor ?? Colors.white,
            ),
      );
    }
    return IconButton(
      onPressed: () {
        _playerController?.startPlayer();
      },
      icon: voiceRecordingConfig?.playIcon ??
          Icon(
            Icons.play_arrow,
            color: voiceRecordingConfig?.playIconColor ?? Colors.white,
          ),
    );
  }
}

class TextFieldView extends StatefulWidget {
  const TextFieldView({
    super.key,
    this.textFieldConfig,
    this.sendMessageConfig,
    this.focusNode,
    this.textEditingController,
    required this.onPressed,
    required this.onImageSelected,
    required this.inputText,
  });
  final TextFieldConfiguration? textFieldConfig;
  final SendMessageConfiguration? sendMessageConfig;
  final FocusNode? focusNode;
  final TextEditingController? textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  final ValueNotifier<String> inputText;

  @override
  State<TextFieldView> createState() => _TextFieldViewState();
}

class _TextFieldViewState extends State<TextFieldView> {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  // RecorderController? controller;

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig => widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig => sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig => sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration => sendMessageConfig?.cancelRecordConfiguration;

  HoldToRecordConfiguration? get holdToRecordConfig => sendMessageConfig?.holdToRecordConfiguration;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: widget.sendMessageConfig?.textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus = ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;

  @override
  void initState() {
    attachListeners();
    debouncer =
        Debouncer(sendMessageConfig?.textFieldConfig?.compositionThresholdTime ?? const Duration(seconds: 1));
    super.initState();

    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      // controller = RecorderController();
    }
  }

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    _inputText.dispose();
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping?.call(composingStatus.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder outlineBorder = _outLineBorder;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Container(
        padding: widget.textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
        margin: widget.textFieldConfig?.margin,
        decoration: BoxDecoration(
          borderRadius: widget.textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
          color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.textEditingController,
                style: widget.textFieldConfig?.textStyle ?? const TextStyle(color: Colors.white),
                maxLines: widget.textFieldConfig?.maxLines ?? 5,
                minLines: widget.textFieldConfig?.minLines ?? 1,
                keyboardType: widget.textFieldConfig?.textInputType,
                inputFormatters: widget.textFieldConfig?.inputFormatters,
                onChanged: _onChanged,
                enabled: widget.textFieldConfig?.enabled,
                textCapitalization: widget.textFieldConfig?.textCapitalization ?? TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: widget.textFieldConfig?.hintText ?? PackageStrings.message,
                  fillColor: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                  filled: true,
                  hintStyle: widget.textFieldConfig?.hintStyle ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.25,
                      ),
                  contentPadding:
                      widget.textFieldConfig?.contentPadding ?? const EdgeInsets.symmetric(horizontal: 6),
                  border: outlineBorder,
                  focusedBorder: outlineBorder,
                  enabledBorder: outlineBorder,
                  disabledBorder: outlineBorder,
                ),
              ),
            ),
            if (widget.sendMessageConfig?.enableCameraImagePicker ?? true)
              IconButton(
                constraints: const BoxConstraints(),
                onPressed: (widget.textFieldConfig?.enabled ?? true)
                    ? () => _onIconPressed(
                          ImageSource.camera,
                          config: widget.sendMessageConfig?.imagePickerConfiguration,
                        )
                    : null,
                icon: imagePickerIconsConfig?.cameraImagePickerIcon ??
                    Icon(
                      Icons.camera_alt_outlined,
                      color: imagePickerIconsConfig?.cameraIconColor,
                    ),
              ),
            if (widget.sendMessageConfig?.enableGalleryImagePicker ?? true)
              IconButton(
                constraints: const BoxConstraints(),
                onPressed: (widget.textFieldConfig?.enabled ?? true)
                    ? () => _onIconPressed(
                          ImageSource.gallery,
                          config: widget.sendMessageConfig?.imagePickerConfiguration,
                        )
                    : null,
                icon: imagePickerIconsConfig?.galleryImagePickerIcon ??
                    Icon(
                      Icons.image,
                      color: imagePickerIconsConfig?.galleryIconColor,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        maxHeight: config?.maxHeight,
        maxWidth: config?.maxWidth,
        imageQuality: config?.imageQuality,
        preferredCameraDevice: config?.preferredCameraDevice ?? CameraDevice.rear,
      );
      String? imagePath = image?.path;
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }
      widget.onImageSelected(imagePath ?? '', '');
    } catch (e) {
      widget.onImageSelected('', e.toString());
    }
  }

  void _onChanged(String inputText) {
    debouncer.run(() {
      composingStatus.value = TypeWriterStatus.typed;
    }, () {
      composingStatus.value = TypeWriterStatus.typing;
    });
    widget.inputText.value = inputText;
  }
}

class SendMessageButton extends IconButton {
  const SendMessageButton({
    super.key,
    required super.onPressed,
    required super.icon,
    super.padding = const EdgeInsets.all(10),
    super.constraints,
    super.style,
    super.tooltip,
    super.color,
    super.iconSize,
    super.focusNode,
    super.autofocus,
    super.mouseCursor,
    super.highlightColor,
    super.hoverColor,
    super.focusColor,
  });
}

class SwipeLeftAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final List<Alignment> alignments;
  final Curve curve;

  const SwipeLeftAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    required this.alignments,
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<SwipeLeftAnimation> createState() => _SwipeLeftAnimationState();
}

class _SwipeLeftAnimationState extends State<SwipeLeftAnimation> {
  late int _currentIndex;
  late Alignment _currentAlignment;
  late Cubic _currentCurve;

  List<Cubic> curves = [
    Curves.easeInOut,
    Curves.easeIn,
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _currentAlignment = widget.alignments[_currentIndex];
    _currentCurve = curves[_currentIndex];
    _startAnimation();
  }

  void _startAnimation() {
    Future.delayed(widget.duration, () {
      if (!mounted) return;

      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.alignments.length;
        _currentAlignment = widget.alignments[_currentIndex];
        _currentCurve = curves[_currentIndex];
      });

      _startAnimation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      alignment: _currentAlignment,
      duration: widget.duration,
      curve: widget.curve,
      child: widget.child,
    );
  }
}

class ShowSendMessageButton extends StatelessWidget {
  final RecordState recorderState;
  final bool isRecordingLocked;
  final SendMessageConfiguration? sendMessageConfig;
  final VoiceRecordingConfiguration? voiceRecordingConfig;
  final void Function() onFinishRecording;
  final void Function() sendMessage;
  final void Function() startRecording;
  final void Function() stopRecording;
  final HoldToRecordConfiguration? holdToRecordConfig;
  final ValueNotifier<String> inputText;
  final void Function(double verticalOffset) onVerticalDragUpdate;
  final void Function(double horizontalOffset) onHorizontalDragUpdate;
  const ShowSendMessageButton({
    super.key,
    required this.recorderState,
    required this.isRecordingLocked,
    this.sendMessageConfig,
    this.voiceRecordingConfig,
    required this.onFinishRecording,
    required this.inputText,
    required this.sendMessage,
    required this.startRecording,
    required this.stopRecording,
    this.holdToRecordConfig,
    required this.onVerticalDragUpdate,
    required this.onHorizontalDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: inputText,
        builder: (_, inputTextValue, child) {
          if (inputTextValue.isNotEmpty) {
            return SendMessageButton(
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
              ),
              onPressed: (sendMessageConfig?.textFieldConfig?.enabled ?? true) ? sendMessage : null,
              icon: sendMessageConfig?.sendButtonIcon ?? const Icon(Icons.send),
            );
          } else if ((recorderState == RecordState.record || recorderState == RecordState.stop) &&
              isRecordingLocked) {
            return ScaleTransitionWrapper(
              // autoStart: false,
              beginScale: recorderState == RecordState.record ? 2.2 : 1.0,
              endScale: recorderState == RecordState.record ? 2.2 : 1.0,
              curve: Curves.bounceInOut,
              child: SendMessageButton(
                onPressed: () => onFinishRecording.call(),
                style: IconButton.styleFrom(
                  backgroundColor: sendMessageConfig?.defaultSendButtonColor,
                ),
                icon: voiceRecordingConfig?.sendIcon ??
                    Icon(
                      Icons.send,
                      color: sendMessageConfig?.sendButtonIconColor ?? Colors.black,
                    ),
              ),
            );
          } else if (!isRecordingLocked) {
            return GestureDetector(
              onLongPressStart: (_) async {
                await HapticFeedback.mediumImpact();
                startRecording();
                // blinkTimer =
                //     Timer.periodic(const Duration(milliseconds: 500), (timer) {
                //   showMicIcon.value = !showMicIcon.value;
                // });
                SystemSound.play(SystemSoundType.alert);
              },
              onLongPressEnd: (_) {
                if (isRecordingLocked) return;
                stopRecording();
                // blinkTimer?.cancel();
              },
              onLongPressMoveUpdate: (details) {
                onHorizontalDragUpdate(details.localPosition.dx);
                onVerticalDragUpdate(details.localPosition.dy);

                //  else {
                //   // _isRecordingLocked.value = false;
                // }
              },
              // onLongPressCancel: () {
              //   if (!widget.isRecordingLocked.value) {
              //     showLockIndicator.value = false;
              //     widget.onCancelRecording.call();
              //   }
              // },
              child: Tooltip(
                message: 'hold to record audio',
                enableFeedback: true,
                triggerMode: TooltipTriggerMode.tap,
                child: ScaleTransitionWrapper(
                  key: recorderState == RecordState.record ? const Key('mic') : UniqueKey(),
                  autoStart: recorderState == RecordState.record,
                  beginScale: recorderState == RecordState.record && isRecordingLocked ? 2.3 : 1.0,
                  endScale: 2.3,
                  curve: Curves.elasticInOut,
                  duration: const Duration(milliseconds: 300),
                  child: SendMessageButton(
                    onPressed: null,
                    style: IconButton.styleFrom(
                      disabledBackgroundColor: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                    ),
                    icon: sendMessageConfig?.voiceRecordingConfiguration?.micIcon ??
                        Icon(
                          Icons.mic,
                          color: voiceRecordingConfig?.recorderIconColor,
                        ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        });
  }
}
