import 'package:chatview/chatview.dart';
import 'package:chatview/src/inherited_widgets/configurations_inherited_widgets.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
              decoration: widget.decoration ?? const BoxDecoration(),
              child: Row(
                children: [
                  widget.imageMessageConfiguration?.messageTimeBuilder?.call(
                        widget.message.createdAt,
                      ) ??
                      _bubbleConfig?.messageTimeBuilder?.call(
                        widget.message.createdAt,
                      ) ??
                      Text(
                        intl.DateFormat('hh:mm${(is24HoursFormat) ? ' a' : ''}')
                            .format(widget.message.createdAt),
                        style: TextStyle(
                          color:
                              widget.message.messageType == MessageType.image &&
                                      (widget.message.text.trim().isEmpty)
                                  ? Colors.white
                                  : Colors.black45,
                          fontSize: 13.5,
                        ),
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

  Widget getReceipt() {
    final showReceipts = chatListConfig.chatBubbleConfig
            ?.outgoingChatBubbleConfig?.receiptsWidgetConfig?.showReceiptsIn ??
        ShowReceiptsIn.lastMessage;
    if (showReceipts == ShowReceiptsIn.all) {
      return ValueListenableBuilder(
        valueListenable: widget.message.statusNotifier,
        builder: (context, value, child) {
          if (ChatViewInheritedWidget.of(context)
                  ?.featureActiveConfig
                  .receiptsBuilderVisibility ??
              true) {
            return chatListConfig.chatBubbleConfig?.outgoingChatBubbleConfig
                    ?.receiptsWidgetConfig?.receiptsBuilder
                    ?.call(value) ??
                sendMessageAnimationBuilder(value);
          }
          return const SizedBox();
        },
      );
    } else if (showReceipts == ShowReceiptsIn.lastMessage && isLastMessage) {
      return ValueListenableBuilder(
          valueListenable:
              widget.chatController.initialMessageList.last.statusNotifier,
          builder: (context, value, child) {
            if (ChatViewInheritedWidget.of(context)
                    ?.featureActiveConfig
                    .receiptsBuilderVisibility ??
                true) {
              return chatListConfig.chatBubbleConfig?.outgoingChatBubbleConfig
                      ?.receiptsWidgetConfig?.receiptsBuilder
                      ?.call(value) ??
                  sendMessageAnimationBuilder(value);
            }
            return sendMessageAnimationBuilder(value);
          });
    }
    return const SizedBox();
  }

  void _getAdditionalPadding(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty &&
        (widget.message.messageType.isImage ||
            widget.message.messageType.isVoice)) {
      return;
    }
    // Create a TextSpan with your text and style
    final textSpan = TextSpan(
      text: text,
      style: style,
      // style: style.merge(
      //     TextTheme.of(context).bodyMedium!.copyWith(fontSize: style.fontSize)),
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

    // Get the last line's width
    final lastLine = lineMetrics.last;

    if (kDebugMode) {
      final start = textPainter.getPositionForOffset(
        Offset(0, lastLine.baseline - lastLine.height),
      );

      // Get the position where the last line ends
      final end = textPainter.getPositionForOffset(
        Offset(lastLine.width, lastLine.baseline),
      );

      // Extract and print the text of the last line
      final lastLineText = text.substring(start.offset, end.offset);
      print('fulltext $text ${text.split('\n').length} ');
      print(
          'n ${text.contains('\n')}\n lines ${lineMetrics.length}\n style: ${style.fontSize}\n Last line width: ${lastLine.width}\n text: $lastLineText \n mxw $maxWidth \n\n');
    }

    double rightPadding = 0;
    double bottomPadding = 0;
    bottomPadding =
        lastLine.width >= maxWidth - 80 || lastLine.width >= 130 ? 8 : 0;
    for (var line in lineMetrics) {
      if (line.width <= 130) {
        rightPadding = 65;
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
