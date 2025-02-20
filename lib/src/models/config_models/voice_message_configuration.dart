import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

/// A configuration model class for voice message bubble.
class VoiceMessageConfiguration {
  const VoiceMessageConfiguration({
    this.playerWaveStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.margin,
    this.decoration,
    this.animationCurve,
    this.animationDuration,
    this.pauseIcon,
    this.playIcon,
    this.waveformMargin,
    this.waveformPadding,
    this.voiceIcon,
    this.waveColor,
    this.bgProgressColor,
    this.progressColor,
    this.downloadIcon,
    this.durationTextStyle,
    this.unDownoadedWaveColor,
    this.circularProgressIndicatorSize,
    this.enableSeekGesture = true,
  });

  /// Applies style to waveform.
  final PlayerWaveStyle? playerWaveStyle;

  /// Applies padding to message bubble.
  final EdgeInsets padding;

  /// Applies margin to message bubble.
  final EdgeInsets? margin;

  /// Applies padding to waveform.
  final EdgeInsets? waveformPadding;

  /// Applies padding to waveform.
  final EdgeInsets? waveformMargin;

  /// BoxDecoration for voice message bubble.
  final BoxDecoration? decoration;

  /// Duration for grow animation for waveform. Default to 500 ms.
  final Duration? animationDuration;

  /// Curve for for grow animation for waveform. Default to Curve.easeIn.
  final Curve? animationCurve;

  /// Icon for playing the audio.
  final Widget? playIcon;

  /// Icon for pausing audio
  final Widget? pauseIcon;

  /// Icon for voice message.
  final Widget? voiceIcon;

  /// Icon for download audio.
  final Widget? downloadIcon;

  /// Text duration style for voice message.

  final TextStyle? durationTextStyle;

  ///CircularProgrIndicatorSize
  final double? circularProgressIndicatorSize;

  ///color for wave
  final Color? waveColor;
  final Color? bgProgressColor;
  final Color? progressColor;
  final Color? unDownoadedWaveColor;

  /// Enable/disable seeking with gestures. Enabled by default.
  final bool enableSeekGesture;
}
