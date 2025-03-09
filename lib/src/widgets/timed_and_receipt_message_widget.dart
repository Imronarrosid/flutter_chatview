import 'package:chatview/chatview.dart';
import 'package:chatview/src/inherited_widgets/configurations_inherited_widgets.dart';
import 'package:chatview/src/utils/constants/constants.dart';
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

  final EdgeInsetsGeometry? padding;

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
    this.padding,
    this.decoration,
    this.imageMessageConfiguration,
  });

  @override
  State<TimedAndReceiptMessageWidget> createState() =>
      _TimedAndReceiptMessageWidgetState();
}

class _TimedAndReceiptMessageWidgetState
    extends State<TimedAndReceiptMessageWidget> {
  @override
  Widget build(BuildContext context) {
    bool is24HoursFormat = MediaQuery.of(context).alwaysUse24HourFormat;

    return Stack(
      children: [
        widget.child,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: widget.padding ?? const EdgeInsets.only(left: 20, top: 20),
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
                                    (widget.message.caption?.trim().isEmpty ??
                                        true)
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
}
