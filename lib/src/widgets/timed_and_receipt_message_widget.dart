import 'package:chatview/chatview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/inherited_widgets/configurations_inherited_widgets.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'chat_view_inherited_widget.dart';

import 'package:intl/intl.dart' as intl;

class TimedAndReceiptMessageWidget extends StatefulWidget {
  final Widget child;
  final Message message;

  final ChatController chatController;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  final ChatBubble? outgoingChatBubbleConfig;

  final ChatBubble? inComingChatBubbleConfig;

  final EdgeInsetsGeometry? messagePadding;

  final BoxDecoration? decoration;

  final ImageMessageConfiguration? imageMessageConfiguration;

  const TimedAndReceiptMessageWidget({
    super.key,
    required this.child,
    required this.message,
    this.outgoingChatBubbleConfig,
    this.inComingChatBubbleConfig,
    required this.isMessageBySender,
    required this.chatController,
    this.messagePadding,
    this.decoration,
    this.imageMessageConfiguration,
  });

  @override
  State<TimedAndReceiptMessageWidget> createState() =>
      _TimedAndReceiptMessageWidgetState();
}

class _TimedAndReceiptMessageWidgetState
    extends State<TimedAndReceiptMessageWidget> {
  late final AdditionalPadding additionalPadding = AdditionalPadding();

  final GlobalKey _timestampsKey = GlobalKey();

  double timestampsWidth = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        setState(() {
          RenderBox renderBox =
              _timestampsKey.currentContext!.findRenderObject() as RenderBox;

          timestampsWidth = renderBox.size.width;

          print('timestamps $timestampsWidth ${renderBox.size.height}');
        });
      },
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    bool is24HoursFormat = MediaQuery.of(context).alwaysUse24HourFormat;

    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, constraints) {
      final EdgeInsets padding = _padding as EdgeInsets;
      final String caption2 = widget.message.text;
      _getAdditionalPadding(
        caption2,
        (_textStyle ?? textTheme.bodyMedium!.copyWith(fontSize: 14))
            .merge(DefaultTextStyle.of(context).style),
        constraints.maxWidth - (padding.left + padding.right),
        is24HoursFormat,
      );

      return Stack(
        children: [
          Padding(
            padding: _calculateFinalPadding(padding, caption2),
            child: Container(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: widget.child),
          ),
          Positioned(
            bottom: 0,
            right: 4,
            child: Container(
              key: _timestampsKey,
              decoration: widget.decoration ?? const BoxDecoration(),
              child: Row(
                children: [
                  Text(
                    is24HoursFormat
                        ? widget.message.createdAt.getTimeFromDateTime
                        : widget.message.createdAt.getTimeFromDateTime12hr,
                    style: _messageTimeStyle,
                  ),
                  if (widget.isMessageBySender) getReceipt(),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  TextStyle get _messageTimeStyle =>
      widget.imageMessageConfiguration?.messageTimeTextStyle ??
      _bubbleConfig?.messageTimeTextStyle ??
      TextStyle(
        color: widget.message.messageType == MessageType.image &&
                (widget.message.text.trim().isEmpty)
            ? Colors.white
            : Colors.black45,
        fontSize: 13.5,
      );

  ReceiptsWidgetConfig? get receiptWidgetConfig => widget.isMessageBySender
      ? chatListConfig
          .chatBubbleConfig?.outgoingChatBubbleConfig?.receiptsWidgetConfig
      : chatListConfig
          .chatBubbleConfig?.inComingChatBubbleConfig?.receiptsWidgetConfig;

  bool get showReceipts =>
      ChatViewInheritedWidget.of(context)
          ?.featureActiveConfig
          .receiptsBuilderVisibility ??
      true;

  Widget getReceipt() {
    final showReceiptsIn =
        receiptWidgetConfig?.showReceiptsIn ?? ShowReceiptsIn.lastMessage;
    if (!showReceipts) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: receiptWidgetConfig?.width ?? 16,
      height: receiptWidgetConfig?.height ?? 16,
      child: Builder(
        builder: (context) {
          if (showReceiptsIn == ShowReceiptsIn.all) {
            return ValueListenableBuilder(
              valueListenable: widget.message.statusNotifier,
              builder: (context, value, child) {
                if (showReceipts) {
                  return receiptWidgetConfig?.receiptsBuilder?.call(value) ??
                      sendMessageAnimationBuilder(value);
                }
                return const SizedBox();
              },
            );
          } else if (showReceiptsIn == ShowReceiptsIn.lastMessage &&
              isLastMessage) {
            return ValueListenableBuilder(
                valueListenable: widget
                    .chatController.initialMessageList.last.statusNotifier,
                builder: (context, value, child) {
                  if (showReceipts) {
                    return receiptWidgetConfig?.receiptsBuilder?.call(value) ??
                        sendMessageAnimationBuilder(value);
                  }
                  return sendMessageAnimationBuilder(value);
                });
          }
          return const SizedBox();
        },
      ),
    );
  }

  double _calculateMessageTimeWidth(double maxWidth) {
    bool is24HoursFormat = MediaQuery.of(context).alwaysUse24HourFormat;
    final messageTimeTextSpan = TextSpan(
      text: is24HoursFormat
          ? widget.message.createdAt.getTimeFromDateTime
          : widget.message.createdAt.getTimeFromDateTime12hr,
      style: _messageTimeStyle.merge(Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontSize: _messageTimeStyle.fontSize)),
    );

    final messageTimeTextPainter = TextPainter(
      textWidthBasis: TextWidthBasis.parent,
      textAlign: TextAlign.left,
      strutStyle: StrutStyle(fontSize: _messageTimeStyle.fontSize),
      text: messageTimeTextSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    messageTimeTextPainter.layout(maxWidth: maxWidth);
    return (widget.isMessageBySender
            ? receiptWidgetConfig?.width ?? receiptWidth
            : 0) +
        messageTimeTextPainter.width;
  }

  void _getAdditionalPadding(
      String text, TextStyle style, double maxWidth, bool is24HoursFormat) {
    if (text.isEmpty &&
        (widget.message.messageType.isImage ||
            widget.message.messageType.isVoice)) {
      return;
    }
    // Create a TextSpan with your text and style
    final textSpan = TextSpan(
      text: text,
      style: style,
    );

    // Create a TextPainter
    final textPainter = TextPainter(
      textWidthBasis: TextWidthBasis.parent,
      textAlign: TextAlign.left,
      strutStyle: StrutStyle(fontSize: style.fontSize),
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null, // Allow unlimited lines
    );

    // Layout the text with the given constraints
    textPainter.layout(maxWidth: maxWidth);

    // Get the number of lines
    final lineMetrics = textPainter.computeLineMetrics();
    // If there are no lines (empty text), return 0
    if (lineMetrics.isEmpty) {
      return;
    }

    // Get the last line
    final lastLine = lineMetrics.last;

    double rightPadding = 0;
    double bottomPadding = 0;

    double timestampsWidth = _calculateMessageTimeWidth(maxWidth) + 6;
    bottomPadding = lastLine.width >= maxWidth - (timestampsWidth + 6) ||
            lastLine.width >= 130
        ? 8
        : 0;
    for (var line in lineMetrics) {
      if (line.width <= 130) {
        rightPadding = timestampsWidth;
      } else {
        rightPadding = 0;
        break;
      }
    }
    additionalPadding.update(rightPadding, bottomPadding);
  }

  TextStyle? get _textStyle => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.textStyle
      : widget.inComingChatBubbleConfig?.textStyle;

  bool get isLastMessage =>
      widget.chatController.initialMessageList.last.id == widget.message.id;

  ConfigurationsInheritedWidget get chatListConfig =>
      context.mounted && ConfigurationsInheritedWidget.of(context) != null
          ? ConfigurationsInheritedWidget.of(context)!
          : const ConfigurationsInheritedWidget(
              chatBackgroundConfig: ChatBackgroundConfiguration(),
              child: SizedBox.shrink(),
            );

  ChatBubble? get _bubbleConfig => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig
      : widget.inComingChatBubbleConfig;

  EdgeInsetsGeometry get _padding =>
      widget.messagePadding ?? const EdgeInsets.all(0);

  EdgeInsets _calculateFinalPadding(EdgeInsets padding, String caption) {
    final bool isImageWithoutCaption =
        caption.isEmpty && widget.message.messageType.isImage;

    final bool isVoiceMessage = widget.message.messageType.isVoice;

    return EdgeInsets.only(
      right: padding.right +
          (isImageWithoutCaption || isVoiceMessage
              ? 0
              : additionalPadding.right),
      bottom: padding.bottom +
          (isImageWithoutCaption || isVoiceMessage
              ? 0
              : additionalPadding.bottom),
      left: padding.left,
      top: padding.top,
    );
  }
}

/// Represents additional padding values for the chat bubble
class AdditionalPadding {
  double _right = 0;
  double _bottom = 0;

  double get right => _right;
  double get bottom => _bottom;

  void update(double right, double bottom) {
    _right = right;
    _bottom = bottom;
  }
}
