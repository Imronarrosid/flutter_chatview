import 'package:flutter/material.dart';

import 'send_message_configuration.dart';

class MediaPreviewConfig extends SendMessageConfiguration {
  final Widget? receiverNameWidget;
  final Widget? closeIcon;

  MediaPreviewConfig({
    this.closeIcon,
    super.textFieldConfig,
    super.textFieldBackgroundColor,
    super.imagePickerIconsConfig,
    super.imagePickerConfiguration,
    super.defaultSendButtonColor,
    super.sendButtonIcon,
    super.replyDialogColor,
    super.replyTitleColor,
    super.replyMessageColor,
    super.closeIconColor,
    super.allowRecordingVoice,
    super.enableCameraImagePicker,
    super.enableGalleryImagePicker,
    super.voiceRecordingConfiguration,
    super.micIconColor,
    super.cancelRecordConfiguration,
    this.receiverNameWidget,
  });
}
