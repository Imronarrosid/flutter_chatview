import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';

class AudioRecordConfig {
  final PlayerWaveStyle playerWaveStyle;
  final Color? playIconColor;
  final Color? pauseIconColor;
  final Color? deleteIconColor;
  final Color? sendIconColor;
  final Widget? playIcon;
  final Widget? pauseIcon;
  final Widget? deleteIcon;
  final Widget? sendIcon;

  const AudioRecordConfig({
    this.playerWaveStyle = const PlayerWaveStyle(
      fixedWaveColor: Colors.white38,
      liveWaveColor: Colors.white,
      backgroundColor: Color(0xffEE5366),
      waveThickness: 4.0,
      spacing:6.5, 
    ),
    this.playIconColor,
    this.pauseIconColor,
    this.deleteIconColor,
    this.sendIconColor,
    this.playIcon,
    this.pauseIcon,
    this.deleteIcon,
    this.sendIcon,
  });
}
