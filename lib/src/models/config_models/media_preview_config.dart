import 'package:flutter/material.dart';

import 'send_message_configuration.dart';

class MediaPreviewConfig extends SendMessageConfiguration {
  final Widget? receiverNameWidget;
  final Widget? closeIcon;
  final Color? closeIconColor;

  MediaPreviewConfig({
    this.closeIcon,
    this.closeIconColor,
    super.textFieldConfig,
    super.textFieldBackgroundColor,
    super.imagePickerIconsConfig,
    super.imagePickerConfiguration,
    super.defaultSendButtonColor,
    super.sendButtonIcon,
    super.allowRecordingVoice,
    super.enableCameraImagePicker,
    super.enableGalleryImagePicker,
    super.voiceRecordingConfiguration,
    super.cancelRecordConfiguration,
    super.replyMessageConfiguration,
    this.receiverNameWidget,
  });
}
