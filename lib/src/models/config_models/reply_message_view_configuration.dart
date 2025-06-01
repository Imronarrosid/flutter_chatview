import 'package:flutter/material.dart';

/// Configuration class for customizing the reply message view appearance
class ReplyMessageViewConfiguration {
  /// Used to give reply dialog color.
  final Color? replyDialogColor;

  /// Used to give color to title of reply pop-up.
  final Color? replyTitleColor;

  /// Used to give color to reply message.
  final Color? replyMessageColor;

  /// Used to give text style to reply message.
  final TextStyle? replyMessageStyle;

  /// Used to give color to image icon in reply pop-up.
  /// This color will be used when [imageIcon] is not provided.
  final Color? imageIconColor;

  /// Custom widget to replace the default image icon.
  /// If not provided, a default image icon will be used.
  final Widget? imageIcon;

  /// Size of the image icon in reply message.
  /// Defaults to 24.0 if not specified.
  final double? imageIconSize;

  /// Used to give padding to reply message container.
  final EdgeInsetsGeometry? replyMessagePadding;

  /// Used to give decoration to reply message container.
  final BoxDecoration? replyMessageDecoration;

  /// Used to give color to close icon in reply pop-up.
  final Color? closeIconColor;

  /// Used to give color to close icon in reply pop-up.
  final Color? closeIconBackgroundColor;

  /// Used to give color to mic icon in reply pop-up.
  /// This color will be used when [micIcon] is not provided.
  final Color? micIconColor;

  /// Custom widget to replace the default mic icon.
  /// If not provided, a default mic icon will be used.
  final Widget? micIcon;

  /// Custom widget to replace the default close icon.
  final Widget? closeIcon;

  /// Creates a configuration for reply message view customization.
  const ReplyMessageViewConfiguration({
    this.replyDialogColor,
    this.closeIconBackgroundColor,
    this.replyTitleColor,
    this.replyMessageColor,
    this.replyMessageStyle,
    this.imageIconColor,
    this.imageIcon,
    this.imageIconSize,
    this.replyMessagePadding,
    this.replyMessageDecoration,
    this.closeIconColor,
    this.micIconColor,
    this.closeIcon,
    this.micIcon,
  });

  /// Creates a copy of this configuration with the given fields replaced with new values.
  ReplyMessageViewConfiguration copyWith({
    Color? replyDialogColor,
    Color? replyTitleColor,
    Color? replyMessageColor,
    TextStyle? replyMessageStyle,
    Color? imageIconColor,
    Widget? imageIcon,
    double? imageIconSize,
    EdgeInsetsGeometry? replyMessagePadding,
    BoxDecoration? replyMessageDecoration,
    Color? closeIconColor,
    Color? micIconColor,
    Widget? closeIcon,
    Widget? micIcon,
  }) {
    return ReplyMessageViewConfiguration(
      replyDialogColor: replyDialogColor ?? this.replyDialogColor,
      replyTitleColor: replyTitleColor ?? this.replyTitleColor,
      replyMessageColor: replyMessageColor ?? this.replyMessageColor,
      replyMessageStyle: replyMessageStyle ?? this.replyMessageStyle,
      imageIconColor: imageIconColor ?? this.imageIconColor,
      imageIcon: imageIcon ?? this.imageIcon,
      imageIconSize: imageIconSize ?? this.imageIconSize,
      replyMessagePadding: replyMessagePadding ?? this.replyMessagePadding,
      replyMessageDecoration: replyMessageDecoration ?? this.replyMessageDecoration,
      closeIconColor: closeIconColor ?? this.closeIconColor,
      micIconColor: micIconColor ?? this.micIconColor,
      closeIcon: closeIcon ?? this.closeIcon,
      micIcon: micIcon ?? this.micIcon,
    );
  }
}
