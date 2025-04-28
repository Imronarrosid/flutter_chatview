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

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../chatview.dart';
import '../utils/concate_audio.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
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

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
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
  Timer? recordingTimer;
  Timer? blinkTimer;

  // Add new variables for lock indicator
  ValueNotifier<bool> showLockIndicator = ValueNotifier(false);
  ValueNotifier<double> lockIndicatorOffset = ValueNotifier(0.0);
  bool wasSwipedUp = false;
  ValueNotifier<bool> isPaused = ValueNotifier(false);

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
      controller = RecorderController();
      _recorderController = AudioRecorder();
    }
  }

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
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    showLockIndicator.dispose();
    lockIndicatorOffset.dispose();
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping?.call(composingStatus.value);
    });
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
                print('recordsts $recorderState');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder(
                        valueListenable: isRecording,
                        builder: (context, isRecordingValue, child) {
                          if (recorderState == RecordState.record && !isRecordingLocked) {
                            return IconButton(
                                onPressed: () {
                                  _finishRecording();
                                },
                                icon: const Icon(Icons.lock, color: Colors.red));
                          }
                          if (recorderState == RecordState.record && isRecordingLocked) {
                            return IconButton(
                                onPressed: () {
                                  _pauseRecording();
                                },
                                style: IconButton.styleFrom(backgroundColor: Colors.blue),
                                icon: const Icon(Icons.pause, color: Colors.white));
                          }
                          if (recorderState == RecordState.stop && isRecordingLocked) {
                            return IconButton(
                                onPressed: () {
                                  _startRecording();
                                },
                                style: IconButton.styleFrom(backgroundColor: Colors.blue),
                                icon: const Icon(Icons.mic, color: Colors.white));
                          }

                          return const SizedBox.shrink();
                        }),
                    StreamBuilder<PlayerState>(
                        stream: _playerController?.onPlayerStateChanged,
                        builder: (_, pState) {
                          if ((pState.data?.isInitialised ?? false) &&
                              // recorderState.isPaused &&
                              controller != null &&
                              !kIsWeb &&
                              _isRecordingLocked.value &&
                              recorderState == RecordState.stop) {
                            return Row(
                              children: [
                                Expanded(
                                  child: AudioFileWaveforms(
                                    playerWaveStyle: PlayerWaveStyle(
                                        liveWaveColor: Colors.black,
                                        fixedWaveColor: Colors.black,
                                        backgroundColor: Colors.lightBlue),
                                    size: const Size(double.maxFinite, 50),
                                    playerController: _playerController!,
                                    margin: voiceRecordingConfig?.margin,
                                    padding: voiceRecordingConfig?.padding ??
                                        EdgeInsets.symmetric(
                                          horizontal: cancelRecordConfiguration == null ? 8 : 5,
                                        ),
                                    decoration: voiceRecordingConfig?.decoration ??
                                        BoxDecoration(
                                          color: voiceRecordingConfig?.backgroundColor,
                                          borderRadius: BorderRadius.circular(12.0),
                                        ),

                                    // playerWaveStyle: voiceRecordingConfig?.waveStyle ??
                                    //     WaveStyle(
                                    //       extendWaveform: true,
                                    //       showMiddleLine: false,
                                    //       waveColor: voiceRecordingConfig?.waveStyle?.waveColor ?? Colors.black,
                                    //     ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    _finishRecording();
                                  },
                                  icon: const Icon(Icons.send, color: Colors.purple),
                                ),
                              ],
                            );
                          } else {
                            return TextFieldView(
                              recordingDuration: recordingDuration,
                              recorderController: _recorderController,
                              recorderState: recorderState,
                              isRecordingLocked: _isRecordingLocked,
                              controller: controller,
                              textFieldConfig: textFieldConfig,
                              sendMessageConfig: sendMessageConfig,
                              voiceRecordingConfig: voiceRecordingConfig,
                              cancelRecordConfiguration: cancelRecordConfiguration,
                              focusNode: widget.focusNode,
                              textEditingController: widget.textEditingController,
                              onPressed: widget.onPressed,
                              onImageSelected: widget.onImageSelected,
                              onRecordingComplete: widget.onRecordingComplete,
                              onCancelRecording: _cancelRecording,
                              onStoprecording: _stopRecording,
                              onLongPressStart: _startRecording,
                              onLongPressEnd: _stopRecording,
                            );
                          }
                        })
                  ],
                );
              });
        });
  }

  // Stop recording for hold-to-record feature
  Future<void> _stopRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    // Cancel all timers
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables
    recordingTimer = null;
    blinkTimer = null;
    lockRecordingTimer = null;

    showLockIndicator.value = false;

    bool _isRecording = await _recorderController!.isRecording();

    if (!(_isRecording) || _isRecordingLocked.value) return;

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

    // final path = await controller?.stop();
    final path = await _recorderController?.stop();

    isRecording.value = false;
    _isRecordingLocked.value = false;
    wasSwipedUp = false;
    showLockIndicator.value = false;
    isPaused.value = false;
    widget.onRecordingComplete(path);
  }

  // Stop recording for hold-to-record feature
  Future<void> _pauseRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    // Cancel all timers
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables
    recordingTimer = null;
    blinkTimer = null;
    lockRecordingTimer = null;

    showLockIndicator.value = false;

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
    debugPrint('Paused recording at path: ${tempDir.listSync()}');
    _playerController = PlayerController()
      ..preparePlayer(
        path: _audioSegment1!,
        // noOfSamples: widget.config?.playerWaveStyle
        //         ?.getSamplesForWidth(widget.screenWidth * 0.5) ??
        //     playerWaveStyle.getSamplesForWidth(widget.screenWidth * 0.5),
      ).whenComplete(() {
        _playerController?.setFinishMode(
          finishMode: FinishMode.pause,
        );
      });
    isRecording.value = false;
    // _isRecordingLocked.value = true;
    wasSwipedUp = false;
    showLockIndicator.value = false;
    isPaused.value = false;
    // widget.onRecordingComplete(path);
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );

    // Cancel all timers
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables
    recordingTimer = null;
    blinkTimer = null;
    lockRecordingTimer = null;
    bool isRecord = await _recorderController!.isRecording();
    if (!isRecord) return;
    await _recorderController?.cancel();

    // final path = await controller?.stop();
    isRecording.value = false;
    isHoldingRecord.value = false;
    _isRecordingLocked.value = false;
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
    // Cancel any existing timers first
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();
    bool _isRecording = await _recorderController!.isRecording();

    if (_isRecording) return;
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
      showLockIndicator.value = true;
      lockIndicatorOffset.value = 0.0;
      isPaused.value = false;
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
    recordingTimer = null;
    blinkTimer = null;

    // Start recording timer
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value++;
    });

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

  // Finish recording and send the voice message
  Future<void> _finishRecording() async {
    bool _isRecording = await _recorderController!.isRecording();

    if ((!_isRecording) && _isRecordingLocked.value) {
      // Cancel all timers
      recordingTimer?.cancel();
      blinkTimer?.cancel();
      lockRecordingTimer?.cancel();

      // Reset timer variables
      recordingTimer = null;
      blinkTimer = null;
      lockRecordingTimer = null;

      // final path = await controller?.stop();
      isRecording.value = false;
      isHoldingRecord.value = false;
      _isRecordingLocked.value = false;
      isPaused.value = false;
      widget.onRecordingComplete(_audioSegment1);
      _audioSegment1 = null;
      _audioSegment2 = null;
      return;
    }

    if (!isRecording.value) return;

    // Cancel all timers
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables
    recordingTimer = null;
    blinkTimer = null;
    lockRecordingTimer = null;

    final path = await controller?.stop();
    isRecording.value = false;
    isHoldingRecord.value = false;
    _isRecordingLocked.value = false;
    isPaused.value = false;
    widget.onRecordingComplete(path);
  }

  // Add pause/resume recording function
  Future<void> _togglePauseRecording() async {
    debugPrint('Toggling pause recording: ${isPaused.value}');
    if (isPaused.value) {
      // Cancel existing timers before creating new ones
      recordingTimer?.cancel();
      blinkTimer?.cancel();

      await controller?.record(
        sampleRate: voiceRecordingConfig?.sampleRate,
        bitRate: voiceRecordingConfig?.bitRate,
        androidEncoder: voiceRecordingConfig?.androidEncoder,
        iosEncoder: voiceRecordingConfig?.iosEncoder,
        androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
      );

      // Create new timers
      recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordingDuration.value++;
      });
      blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        showMicIcon.value = !showMicIcon.value;
      });
    } else {
      await controller?.pause();
      // Cancel timers when pausing
      recordingTimer?.cancel();
      blinkTimer?.cancel();
    }
    isPaused.value = !isPaused.value;
  }
}

class TextFieldView extends StatefulWidget {
  const TextFieldView({
    super.key,
    required this.recorderState,
    this.controller,
    this.textFieldConfig,
    this.sendMessageConfig,
    this.voiceRecordingConfig,
    this.cancelRecordConfiguration,
    required this.isRecordingLocked,
    this.focusNode,
    this.textEditingController,
    required this.onPressed,
    required this.onImageSelected,
    required this.onRecordingComplete,
    required this.onCancelRecording,
    required this.onStoprecording,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    this.recorderController,
    required this.recordingDuration,
  });
  final RecordState recorderState;
  final RecorderController? controller;
  final AudioRecorder? recorderController;
  final TextFieldConfiguration? textFieldConfig;
  final SendMessageConfiguration? sendMessageConfig;
  final VoiceRecordingConfiguration? voiceRecordingConfig;
  final CancelRecordConfiguration? cancelRecordConfiguration;
  final ValueNotifier isRecordingLocked;
  final FocusNode? focusNode;
  final TextEditingController? textEditingController;
  final ValueListenable<int> recordingDuration;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  ///Provides callback when user cancel recording.
  /// This callback is used to cancel the recording when the user swipes left.
  final Function() onCancelRecording;

  final Function() onStoprecording;

  ///Provides calback when user long pres mic icon
  final Function() onLongPressStart;

  ///Provides calback when user long pres mic icon end
  final Function() onLongPressEnd;

  @override
  State<TextFieldView> createState() => _TextFieldViewState();
}

class _TextFieldViewState extends State<TextFieldView> {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  // Variables for hold-to-record feature
  ValueNotifier<bool> isHoldingRecord = ValueNotifier(false);
  ValueNotifier<double> horizontalDragOffset = ValueNotifier(0.0);
  ValueNotifier<double> verticalDragOffset = ValueNotifier(0.0);
  ValueNotifier<bool> isCancelling = ValueNotifier(false);
  ValueNotifier<bool> _isRecordingLocked = ValueNotifier(false);
  Timer? lockRecordingTimer;

  // Variables for recording time counter and blinking mic
  ValueNotifier<int> recordingDuration = ValueNotifier(0);
  ValueNotifier<bool> showMicIcon = ValueNotifier(true);
  Timer? recordingTimer;
  Timer? blinkTimer;

  // Add new variables for lock indicator
  ValueNotifier<bool> showLockIndicator = ValueNotifier(false);
  ValueNotifier<double> lockIndicatorOffset = ValueNotifier(0.0);
  bool wasSwipedUp = false;
  ValueNotifier<bool> isPaused = ValueNotifier(false);

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
      controller = RecorderController();
    }
  }

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
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    showLockIndicator.dispose();
    lockIndicatorOffset.dispose();
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
    return Container(
      padding: widget.textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
      margin: widget.textFieldConfig?.margin,
      decoration: BoxDecoration(
        borderRadius: widget.textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
        color: widget.sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      ),
      child: Row(
        children: [
          if (widget.recorderState == RecordState.record && widget.controller != null && !kIsWeb)
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 50,
                    padding: widget.voiceRecordingConfig?.padding ??
                        EdgeInsets.symmetric(
                          horizontal: widget.cancelRecordConfiguration == null ? 8 : 5,
                        ),
                    margin: widget.voiceRecordingConfig?.margin,
                    decoration: widget.voiceRecordingConfig?.decoration ??
                        BoxDecoration(
                          color: widget.voiceRecordingConfig?.backgroundColor,
                          borderRadius: BorderRadius.circular(12.0),
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
                                  color: widget.voiceRecordingConfig?.recorderIconColor ?? Colors.red,
                                  size: 24,
                                ),
                              );
                            }),
                        const SizedBox(width: 12),
                        // Time counter
                        ValueListenableBuilder<int>(
                          valueListenable: widget.recordingDuration,
                          builder: (context, duration, _) {
                            return Text(
                              _formatDuration(duration),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.voiceRecordingConfig?.recorderIconColor ?? Colors.black,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (isHoldingRecord.value && holdToRecordConfig?.showRecordingText == true)
                    ValueListenableBuilder<double>(
                      valueListenable: horizontalDragOffset,
                      builder: (context, offset, _) {
                        final isCancellingValue = offset <= -(holdToRecordConfig?.cancelSwipeThreshold ?? 50.0);
                        if (isCancellingValue != isCancelling.value) {
                          isCancelling.value = isCancellingValue;
                        }
                        final bool showSwipeUpMessage = !widget.isRecordingLocked.value &&
                            !isCancellingValue &&
                            verticalDragOffset.value > -(holdToRecordConfig?.lockSwipeThreshold ?? 50.0);

                        final bool showLockedMessage = widget.isRecordingLocked.value;

                        return Positioned(
                          left: 0,
                          right: 0,
                          bottom: 5,
                          child: Center(
                            child: Text(
                              isCancellingValue
                                  ? holdToRecordConfig?.releaseText ?? 'Release to cancel'
                                  : showLockedMessage
                                      ? holdToRecordConfig?.lockedText ?? 'Recording locked'
                                      : showSwipeUpMessage
                                          ? holdToRecordConfig?.swipeUpText ?? 'Swipe up to lock'
                                          : holdToRecordConfig?.cancelText ?? 'Slide left to cancel',
                              style: holdToRecordConfig?.textStyle ??
                                  TextStyle(
                                    fontSize: 12,
                                    color: isCancellingValue
                                        ? holdToRecordConfig?.cancelTextColor ?? Colors.red
                                        : showLockedMessage
                                            ? holdToRecordConfig?.lockedTextColor ?? Colors.green
                                            : holdToRecordConfig?.recordingTextColor ?? Colors.grey[600],
                                  ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            )
          else
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
          ValueListenableBuilder<String>(
            valueListenable: _inputText,
            builder: (_, inputTextValue, child) {
              if (inputTextValue.isNotEmpty) {
                return IconButton(
                  color: widget.sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                  onPressed: (widget.textFieldConfig?.enabled ?? true)
                      ? () {
                          widget.onPressed();
                          _inputText.value = '';
                        }
                      : null,
                  icon: widget.sendMessageConfig?.sendButtonIcon ?? const Icon(Icons.send),
                );
              } else {
                return Row(
                  children: [
                    if (!(widget.recorderState == RecordState.record)) ...[
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
                    if ((widget.sendMessageConfig?.allowRecordingVoice ?? false) &&
                        !kIsWeb &&
                        (Platform.isIOS || Platform.isAndroid))
                      widget.sendMessageConfig?.enableHoldToRecord == true
                          ? Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Lock/Pause indicator
                                ValueListenableBuilder<bool>(
                                  valueListenable: showLockIndicator,
                                  builder: (context, showLock, _) {
                                    if (!showLock) {
                                      return const SizedBox.shrink();
                                    }

                                    return ValueListenableBuilder<bool>(
                                      valueListenable: _isRecordingLocked,
                                      builder: (context, locked, _) {
                                        return SizedBox.shrink();
                                        // return Positioned(
                                        //   top: -45, // Changed from -35 to -45 to move it higher
                                        //   left: 0,
                                        //   right: 0,
                                        //   child: GestureDetector(
                                        //     onTap: _togglePauseRecording,
                                        //     child: Container(
                                        //       padding: const EdgeInsets.all(8),
                                        //       decoration: BoxDecoration(
                                        //         color: holdToRecordConfig?.recordingFeedbackColor ?? Colors.purple,
                                        //         shape: BoxShape.circle,
                                        //       ),
                                        //       child: InkWell(
                                        //         onTap: () {
                                        //           debugPrint('Tapped on lock/pause button');
                                        //         },
                                        //         child: Icon(
                                        //           locked
                                        //               ? (isPausedValue ? Icons.play_arrow : Icons.pause)
                                        //               : Icons.lock,
                                        //           size: 20,
                                        //           color: Colors.white,
                                        //         ),
                                        //       ),
                                        //     ),
                                        //   ),
                                        // );
                                      },
                                    );
                                  },
                                ),
                                // Mic button with gesture detector
                                GestureDetector(
                                  onLongPressStart: (_) async {
                                    await HapticFeedback.mediumImpact();
                                    widget.onLongPressStart.call();
                                    blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
                                      showMicIcon.value = !showMicIcon.value;
                                    });
                                    SystemSound.play(SystemSoundType.alert);
                                  },
                                  onLongPressEnd: (_) {
                                    if (widget.isRecordingLocked.value) return;
                                    widget.onLongPressEnd.call();
                                    _stopRecording();
                                    blinkTimer?.cancel();
                                  },
                                  onLongPressMoveUpdate: (details) {
                                    horizontalDragOffset.value = details.offsetFromOrigin.dx;
                                    verticalDragOffset.value = details.offsetFromOrigin.dy;
                                    debugPrint(
                                        'positionX: ${details.offsetFromOrigin.dx} positionY: ${details.offsetFromOrigin.dy}');

                                    if (details.offsetFromOrigin.dy <
                                        -(holdToRecordConfig?.cancelSwipeThreshold ?? 50.0)) {
                                      widget.isRecordingLocked.value = true;
                                    } else {
                                      // _isRecordingLocked.value = false;
                                    }
                                    if (details.offsetFromOrigin.dx <
                                        -(holdToRecordConfig?.cancelSwipeThreshold ?? 50.0)) {
                                      HapticFeedback.mediumImpact();

                                      widget.onCancelRecording.call();
                                    } else {
                                      // _isRecordingLocked.value = false;
                                    }

                                    if (!widget.isRecordingLocked.value) {
                                      lockIndicatorOffset.value = verticalDragOffset.value;

                                      double swipeThreshold = holdToRecordConfig?.lockSwipeThreshold ?? 50.0;

                                      // Check for initial swipe up
                                      if (verticalDragOffset.value <= -swipeThreshold) {
                                        wasSwipedUp = true;
                                      }

                                      // // If swiped up and then down without releasing, cancel recording
                                      // if (wasSwipedUp &&
                                      //     !isRecordingLocked &&
                                      //     verticalDragOffset.value >
                                      //         -20) {
                                      //   _cancelRecording();
                                      //   return;
                                      // }
                                    }
                                  },
                                  // onLongPressCancel: () {
                                  //   if (!widget.isRecordingLocked.value) {
                                  //     showLockIndicator.value = false;
                                  //     widget.onCancelRecording.call();
                                  //   }
                                  // },
                                  child: IconButton(
                                    onPressed: null,
                                    icon: holdToRecordConfig?.holdToRecordIcon ??
                                        Icon(
                                          Icons.mic,
                                          color: holdToRecordConfig?.holdToRecordIconColor ??
                                              widget.voiceRecordingConfig?.recorderIconColor,
                                        ),
                                  ),
                                ),
                              ],
                            )
                          : IconButton(
                              onPressed:
                                  (widget.textFieldConfig?.enabled ?? true) ? widget.onStoprecording.call() : null,
                              icon: (widget.recorderState == RecordState.record
                                      ? widget.voiceRecordingConfig?.stopIcon
                                      : widget.voiceRecordingConfig?.micIcon) ??
                                  Icon(
                                    widget.recorderState == RecordState.record ? Icons.stop : Icons.mic,
                                    color: widget.voiceRecordingConfig?.recorderIconColor,
                                  ),
                            ),
                    if (widget.recorderState == RecordState.record && widget.cancelRecordConfiguration != null)
                      IconButton(
                        onPressed: () {
                          widget.cancelRecordConfiguration?.onCancel?.call();
                          widget.onCancelRecording.call();
                        },
                        icon: widget.cancelRecordConfiguration?.icon ?? const Icon(Icons.cancel_outlined),
                        color: widget.cancelRecordConfiguration?.iconColor ??
                            widget.voiceRecordingConfig?.recorderIconColor,
                      ),
                  ],
                );
              }
            },
          ),
        ],
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
    _inputText.value = inputText;
  }

  // Start recording for hold-to-record feature
  Future<void> _startRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );

    if (isRecording.value) return;

    // Cancel any existing timers first
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    horizontalDragOffset.value = 0.0;
    verticalDragOffset.value = 0.0;
    _isRecordingLocked.value = false;
    isCancelling.value = false;
    isHoldingRecord.value = true;
    _isRecordingLocked.value = false;
    recordingDuration.value = 0;
    showMicIcon.value = true;
    wasSwipedUp = false;
    showLockIndicator.value = true;
    lockIndicatorOffset.value = 0.0;
    isPaused.value = false;

    await controller?.record(
      sampleRate: voiceRecordingConfig?.sampleRate,
      bitRate: voiceRecordingConfig?.bitRate,
      androidEncoder: voiceRecordingConfig?.androidEncoder,
      iosEncoder: voiceRecordingConfig?.iosEncoder,
      androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
    );
    isRecording.value = true;

    // Ensure timers are null before creating new ones
    recordingTimer = null;
    blinkTimer = null;

    // Start recording timer
    recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordingDuration.value++;
    });

    // Start blinking mic icon
    blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      showMicIcon.value = !showMicIcon.value;
    });

    // Set up timer for locking recording if configured
    lockRecordingTimer?.cancel();
    // if (holdToRecordConfig?.lockRecordingAfterDuration != null) {
    //   lockRecordingTimer = Timer(holdToRecordConfig!.lockRecordingAfterDuration!, () {
    //     _isRecordingLocked.value = true;
    //   });
    // }
  }

  // Stop recording for hold-to-record feature
  Future<void> _stopRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    // Cancel all timers
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    // Reset timer variables
    recordingTimer = null;
    blinkTimer = null;
    lockRecordingTimer = null;

    showLockIndicator.value = false;

    if (!isRecording.value || !isHoldingRecord.value) return;

    isHoldingRecord.value = false;

    // If was swiped up, lock the recording
    if (wasSwipedUp) {
      _isRecordingLocked.value = true;
      showLockIndicator.value = true; // Keep showing the pause button
      return;
    }

    // Check if we should cancel based on horizontal drag
    if (isCancelling.value) {
      widget.onCancelRecording.call();
      return;
    }

    final state = await controller?.onRecorderStateChanged.first as RecorderState;
    final path = await controller?.stop();
    isRecording.value = false;
    _isRecordingLocked.value = false;
    wasSwipedUp = false;
    showLockIndicator.value = false;
    isPaused.value = false;
    widget.onRecordingComplete(path);
  }

  // Format seconds to mm:ss
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
