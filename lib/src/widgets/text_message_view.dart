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
import 'package:chatview/chatview.dart';
import 'package:chatview/src/inherited_widgets/configurations_inherited_widgets.dart';
import 'package:chatview/src/widgets/timed_and_receipt_message_widget.dart';
import 'package:flutter/material.dart';

import '../utils/constants/constants.dart';
import 'chat_view_inherited_widget.dart';
import 'highliight_link.dart';
import 'reaction_widget.dart';

class TextMessageView extends StatefulWidget {
  const TextMessageView({
    Key? key,
    required this.isMessageBySender,
    required this.message,
    this.chatBubbleMaxWidth,
    this.inComingChatBubbleConfig,
    this.outgoingChatBubbleConfig,
    this.messageReactionConfig,
    this.highlightMessage = false,
    this.highlightColor,
    this.chatViewRenderBox,
    required this.chatController,
  }) : super(key: key);

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides message instance of chat.
  final Message message;

  /// Allow users to give max width of chat bubble.
  final double? chatBubbleMaxWidth;

  /// Provides configuration of chat bubble appearance from other user of chat.
  final ChatBubble? inComingChatBubbleConfig;

  /// Provides configuration of chat bubble appearance from current user of chat.
  final ChatBubble? outgoingChatBubbleConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents message should highlight.
  final bool highlightMessage;

  /// Allow user to set color of highlighted message.
  final Color? highlightColor;

  final RenderBox? chatViewRenderBox;

  final ChatController chatController;

  @override
  State<TextMessageView> createState() => _TextMessageViewState();
}

class _TextMessageViewState extends State<TextMessageView> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textMessage = widget.message.text;
    return ListenableBuilder(
        listenable: widget.message.reactionNotifier,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(
                    maxWidth: widget.chatBubbleMaxWidth ??
                        (widget.chatViewRenderBox?.size.width ??
                                MediaQuery.of(context).size.width) *
                            0.75),
                margin: _margin ??
                    EdgeInsets.fromLTRB(5, 0, 6,
                        widget.message.reaction.reactions.isNotEmpty ? 15 : 0),
                decoration: BoxDecoration(
                  color:
                      widget.highlightMessage ? widget.highlightColor : _color,
                  borderRadius: _borderRadius(textMessage),
                ),
                child: TimedAndReceiptMessageWidget(
                  chatController: widget.chatController,
                  isMessageBySender: widget.isMessageBySender,
                  message: widget.message,
                  inComingChatBubbleConfig: widget.inComingChatBubbleConfig,
                  outgoingChatBubbleConfig: widget.outgoingChatBubbleConfig,
                  messagePadding: _padding ??
                      const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        top: 8,
                        bottom: 8,
                      ),
                  child: HighlihtLink(
                      linkPreviewConfig: _linkPreviewConfig,
                      message: textMessage,
                      messageStyle: _textStyle ?? textTheme.bodyMedium),
                ),
              ),
              if (widget.message.reaction.reactions.isNotEmpty)
                ReactionWidget(
                  key: widget.key,
                  isMessageBySender: widget.isMessageBySender,
                  message: widget.message,
                  messageReactionConfig: widget.messageReactionConfig,
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

  EdgeInsetsGeometry? get _padding => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.padding
      : widget.inComingChatBubbleConfig?.padding;

  EdgeInsetsGeometry? get _margin => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.margin
      : widget.inComingChatBubbleConfig?.margin;

  LinkPreviewConfiguration? get _linkPreviewConfig => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.linkPreviewConfig
      : widget.inComingChatBubbleConfig?.linkPreviewConfig;

  TextStyle? get _textStyle => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.textStyle
      : widget.inComingChatBubbleConfig?.textStyle;

  BorderRadiusGeometry _borderRadius(String message) => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.borderRadius ??
          (message.length < 37
              ? BorderRadius.circular(12)
              : BorderRadius.circular(12))
      : widget.inComingChatBubbleConfig?.borderRadius ??
          (message.length < 29
              ? BorderRadius.circular(12)
              : BorderRadius.circular(12));

  Color get _color => widget.isMessageBySender
      ? widget.outgoingChatBubbleConfig?.color ?? Colors.purple
      : widget.inComingChatBubbleConfig?.color ?? Colors.grey.shade500;

  bool get isLastMessage =>
      widget.chatController.initialMessageList.last.id == widget.message.id;

  ConfigurationsInheritedWidget get chatListConfig =>
      context.mounted && ConfigurationsInheritedWidget.of(context) != null
          ? ConfigurationsInheritedWidget.of(context)!
          : const ConfigurationsInheritedWidget(
              chatBackgroundConfig: ChatBackgroundConfiguration(),
              child: SizedBox.shrink(),
            );
}
