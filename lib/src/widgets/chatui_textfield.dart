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
import 'dart:io' show File, Platform;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../chatview.dart';
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

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  // Variables for hold-to-record feature
  ValueNotifier<bool> isHoldingRecord = ValueNotifier(false);
  ValueNotifier<double> horizontalDragOffset = ValueNotifier(0.0);
  ValueNotifier<double> verticalDragOffset = ValueNotifier(0.0);
  ValueNotifier<bool> isCancelling = ValueNotifier(false);
  Timer? lockRecordingTimer;
  bool isRecordingLocked = false;

  // Variables for recording time counter and blinking mic
  ValueNotifier<int> recordingDuration = ValueNotifier(0);
  ValueNotifier<bool> showMicIcon = ValueNotifier(true);
  Timer? recordingTimer;
  Timer? blinkTimer;

  // Add new variables for lock indicator
  ValueNotifier<bool> showLockIndicator = ValueNotifier(false);
  ValueNotifier<double> lockIndicatorOffset = ValueNotifier(0.0);
  bool wasSwipedUp = false;
  bool isPaused = false;

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig =>
      widget.sendMessageConfig?.voiceRecordingConfiguration;

  ImagePickerIconsConfiguration? get imagePickerIconsConfig =>
      sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig =>
      sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration =>
      sendMessageConfig?.cancelRecordConfiguration;

  HoldToRecordConfiguration? get holdToRecordConfig =>
      sendMessageConfig?.holdToRecordConfiguration;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: widget.sendMessageConfig?.textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus =
      ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;

  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
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
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping
          ?.call(composingStatus.value);
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
    final outlineBorder = _outLineBorder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ValueListenableBuilder(
            valueListenable: isRecording,
            builder: (context, isRecordingValue, child) {
              if (!isRecordingValue) {
                return const SizedBox.shrink();
              }
              if (isRecordingValue && isRecordingLocked) {
                return IconButton(
                    onPressed: () {
                      _finishRecording();
                    },
                    icon: const Icon(Icons.stop_circle, color: Colors.red));
              }

              return const SizedBox.shrink();
            }),
        Container(
          padding: textFieldConfig?.padding ??
              const EdgeInsets.symmetric(horizontal: 6),
          margin: textFieldConfig?.margin,
          decoration: BoxDecoration(
            borderRadius: textFieldConfig?.borderRadius ??
                BorderRadius.circular(textFieldBorderRadius),
            color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: isRecording,
            builder: (_, isRecordingValue, child) {
              return Row(
                children: [
                  if (isRecordingValue && controller != null && !kIsWeb)
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 50,
                            padding: voiceRecordingConfig?.padding ??
                                EdgeInsets.symmetric(
                                  horizontal:
                                      cancelRecordConfiguration == null ? 8 : 5,
                                ),
                            margin: voiceRecordingConfig?.margin,
                            decoration: voiceRecordingConfig?.decoration ??
                                BoxDecoration(
                                  color: voiceRecordingConfig?.backgroundColor,
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // Blinking mic icon
                                ValueListenableBuilder<bool>(
                                  valueListenable: showMicIcon,
                                  builder: (context, visible, _) {
                                    return Opacity(
                                      opacity: visible ? 1.0 : 0.3,
                                      child: Icon(
                                        Icons.mic,
                                        color: voiceRecordingConfig
                                                ?.recorderIconColor ??
                                            Colors.red,
                                        size: 24,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                // Time counter
                                ValueListenableBuilder<int>(
                                  valueListenable: recordingDuration,
                                  builder: (context, duration, _) {
                                    return Text(
                                      _formatDuration(duration),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: voiceRecordingConfig
                                                ?.recorderIconColor ??
                                            Colors.black,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (isHoldingRecord.value &&
                              holdToRecordConfig?.showRecordingText == true)
                            ValueListenableBuilder<double>(
                              valueListenable: horizontalDragOffset,
                              builder: (context, offset, _) {
                                final isCancellingValue = offset <=
                                    -(holdToRecordConfig
                                            ?.cancelSwipeThreshold ??
                                        50.0);
                                if (isCancellingValue != isCancelling.value) {
                                  isCancelling.value = isCancellingValue;
                                }
                                final bool showSwipeUpMessage = 
                                    !isRecordingLocked && 
                                    !isCancellingValue && 
                                    verticalDragOffset.value > -(holdToRecordConfig?.lockSwipeThreshold ?? 50.0);
                                    
                                final bool showLockedMessage = isRecordingLocked;
                                
                                return Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 5,
                                  child: Center(
                                    child: Text(
                                      isCancellingValue
                                          ? holdToRecordConfig?.releaseText ??
                                              'Release to cancel'
                                          : showLockedMessage
                                              ? holdToRecordConfig?.lockedText ??
                                                  'Recording locked'
                                              : showSwipeUpMessage
                                                  ? holdToRecordConfig?.swipeUpText ??
                                                      'Swipe up to lock'
                                                  : holdToRecordConfig?.cancelText ??
                                                      'Slide left to cancel',
                                      style: holdToRecordConfig?.textStyle ??
                                          TextStyle(
                                            fontSize: 12,
                                            color: isCancellingValue
                                                ? holdToRecordConfig
                                                        ?.cancelTextColor ??
                                                    Colors.red
                                                : showLockedMessage
                                                    ? holdToRecordConfig
                                                            ?.lockedTextColor ??
                                                        Colors.green
                                                    : holdToRecordConfig
                                                            ?.recordingTextColor ??
                                                        Colors.grey[600],
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
                        style: textFieldConfig?.textStyle ??
                            const TextStyle(color: Colors.white),
                        maxLines: textFieldConfig?.maxLines ?? 5,
                        minLines: textFieldConfig?.minLines ?? 1,
                        keyboardType: textFieldConfig?.textInputType,
                        inputFormatters: textFieldConfig?.inputFormatters,
                        onChanged: _onChanged,
                        enabled: textFieldConfig?.enabled,
                        textCapitalization:
                            textFieldConfig?.textCapitalization ??
                                TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: textFieldConfig?.hintText ??
                              PackageStrings.message,
                          fillColor:
                              sendMessageConfig?.textFieldBackgroundColor ??
                                  Colors.white,
                          filled: true,
                          hintStyle: textFieldConfig?.hintStyle ??
                              TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.25,
                              ),
                          contentPadding: textFieldConfig?.contentPadding ??
                              const EdgeInsets.symmetric(horizontal: 6),
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
                          color: sendMessageConfig?.defaultSendButtonColor ??
                              Colors.green,
                          onPressed: (textFieldConfig?.enabled ?? true)
                              ? () {
                                  widget.onPressed();
                                  _inputText.value = '';
                                }
                              : null,
                          icon: sendMessageConfig?.sendButtonIcon ??
                              const Icon(Icons.send),
                        );
                      } else {
                        return Row(
                          children: [
                            if (!isRecordingValue) ...[
                              if (sendMessageConfig?.enableCameraImagePicker ??
                                  true)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  onPressed: (textFieldConfig?.enabled ?? true)
                                      ? () => _onIconPressed(
                                            ImageSource.camera,
                                            config: sendMessageConfig
                                                ?.imagePickerConfiguration,
                                          )
                                      : null,
                                  icon: imagePickerIconsConfig
                                          ?.cameraImagePickerIcon ??
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        color: imagePickerIconsConfig
                                            ?.cameraIconColor,
                                      ),
                                ),
                              if (sendMessageConfig?.enableGalleryImagePicker ??
                                  true)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  onPressed: (textFieldConfig?.enabled ?? true)
                                      ? () => _onIconPressed(
                                            ImageSource.gallery,
                                            config: sendMessageConfig
                                                ?.imagePickerConfiguration,
                                          )
                                      : null,
                                  icon: imagePickerIconsConfig
                                          ?.galleryImagePickerIcon ??
                                      Icon(
                                        Icons.image,
                                        color: imagePickerIconsConfig
                                            ?.galleryIconColor,
                                      ),
                                ),
                            ],
                            if ((sendMessageConfig?.allowRecordingVoice ??
                                    false) &&
                                !kIsWeb &&
                                (Platform.isIOS || Platform.isAndroid))
                              sendMessageConfig?.enableHoldToRecord == true
                                  ? Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        // Lock/Pause indicator
                                        ValueListenableBuilder<bool>(
                                          valueListenable: showLockIndicator,
                                          builder: (context, showLock, _) {
                                            return ValueListenableBuilder<double>(
                                              valueListenable: lockIndicatorOffset,
                                              builder: (context, offset, _) {
                                                return showLock
                                                  ? Positioned(
                                                      top: -45, // Changed from -35 to -45 to move it higher
                                                      left: 0,
                                                      right: 0,
                                                      child: GestureDetector(
                                                        onTap: isRecordingLocked ? _togglePauseRecording : null,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: holdToRecordConfig?.recordingFeedbackColor ?? Colors.blue,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: Icon(
                                                            wasSwipedUp || isRecordingLocked 
                                                              ? (isPaused ? Icons.play_arrow : Icons.pause)
                                                              : Icons.lock,
                                                            size: 20,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : const SizedBox.shrink();
                                              },
                                            );
                                          },
                                        ),
                                        // Mic button with gesture detector
                                        GestureDetector(
                                          onLongPressStart: (_) {
                                            _startRecording();
                                          },
                                          onLongPressEnd: (_) => _stopRecording(),
                                          onLongPressMoveUpdate: (details) {
                                            horizontalDragOffset.value = details.offsetFromOrigin.dx;
                                            verticalDragOffset.value = details.offsetFromOrigin.dy;
                                            
                                            if (!isRecordingLocked) {
                                              lockIndicatorOffset.value = verticalDragOffset.value;
                                              
                                              double swipeThreshold = holdToRecordConfig?.lockSwipeThreshold ?? 50.0;
                                              
                                              // Check for initial swipe up
                                              if (verticalDragOffset.value <= -swipeThreshold) {
                                                wasSwipedUp = true;
                                              }
                                              
                                              // If swiped up and then down without releasing, cancel recording
                                              if (wasSwipedUp && !isRecordingLocked && verticalDragOffset.value > -20) {
                                                _cancelRecording();
                                                return;
                                              }
                                            }
                                          },
                                          onLongPressCancel: () {
                                            if (!isRecordingLocked) {
                                              showLockIndicator.value = false;
                                              _cancelRecording();
                                            }
                                          },
                                          child: IconButton(
                                            onPressed: null,
                                            icon: holdToRecordConfig?.holdToRecordIcon ??
                                                Icon(
                                                  Icons.mic,
                                                  color: holdToRecordConfig?.holdToRecordIconColor ??
                                                      voiceRecordingConfig?.recorderIconColor,
                                                ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : IconButton(
                                      onPressed:
                                          (textFieldConfig?.enabled ?? true)
                                              ? _recordOrStop
                                              : null,
                                      icon: (isRecordingValue
                                              ? voiceRecordingConfig?.stopIcon
                                              : voiceRecordingConfig
                                                  ?.micIcon) ??
                                          Icon(
                                            isRecordingValue
                                                ? Icons.stop
                                                : Icons.mic,
                                            color: voiceRecordingConfig
                                                ?.recorderIconColor,
                                          ),
                                    ),
                            if (isRecordingValue &&
                                cancelRecordConfiguration != null)
                              IconButton(
                                onPressed: () {
                                  cancelRecordConfiguration?.onCancel?.call();
                                  _cancelRecording();
                                },
                                icon: cancelRecordConfiguration?.icon ??
                                    const Icon(Icons.cancel_outlined),
                                color: cancelRecordConfiguration?.iconColor ??
                                    voiceRecordingConfig?.recorderIconColor,
                              ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
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

    if (!isRecording.value) return;
    final path = await controller?.stop();
    if (path == null) {
      isRecording.value = false;
      isHoldingRecord.value = false;
      isRecordingLocked = false;
      return;
    }
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    isRecording.value = false;
    isHoldingRecord.value = false;
    isRecordingLocked = false;
  }

  Future<void> _recordOrStop() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) {
      await controller?.record(
        sampleRate: voiceRecordingConfig?.sampleRate,
        bitRate: voiceRecordingConfig?.bitRate,
        androidEncoder: voiceRecordingConfig?.androidEncoder,
        iosEncoder: voiceRecordingConfig?.iosEncoder,
        androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
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
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );

    if (isRecording.value) return;

    // Cancel any existing timers first
    recordingTimer?.cancel();
    blinkTimer?.cancel();
    lockRecordingTimer?.cancel();

    horizontalDragOffset.value = 0.0;
    verticalDragOffset.value = 0.0;
    isCancelling.value = false;
    isHoldingRecord.value = true;
    isRecordingLocked = false;
    recordingDuration.value = 0;
    showMicIcon.value = true;
    wasSwipedUp = false;
    showLockIndicator.value = true;
    lockIndicatorOffset.value = 0.0;
    isPaused = false;

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
    if (holdToRecordConfig?.lockRecordingAfterDuration != null) {
      lockRecordingTimer = Timer(holdToRecordConfig!.lockRecordingAfterDuration!, () {
        isRecordingLocked = true;
      });
    }
  }

  // Stop recording for hold-to-record feature
  Future<void> _stopRecording() async {
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
      isRecordingLocked = true;
      showLockIndicator.value = true; // Keep showing the pause button
      return;
    }

    // Check if we should cancel based on horizontal drag
    if (isCancelling.value) {
      _cancelRecording();
      return;
    }

    final path = await controller?.stop();
    isRecording.value = false;
    isRecordingLocked = false;
    wasSwipedUp = false;
    showLockIndicator.value = false;
    isPaused = false;
    widget.onRecordingComplete(path);
  }

  // Finish recording and send the voice message
  Future<void> _finishRecording() async {
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
    isRecordingLocked = false;
    isPaused = false;
    widget.onRecordingComplete(path);
  }

  // Add pause/resume recording function
  Future<void> _togglePauseRecording() async {
    if (isPaused) {
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
    isPaused = !isPaused;
    setState(() {});
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
        preferredCameraDevice:
            config?.preferredCameraDevice ?? CameraDevice.rear,
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
}
