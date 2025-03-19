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
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:flutter/material.dart';

import '../../chatview.dart';
import '../conditional/conditional.dart';
import 'message_time_widget.dart';
import 'message_view.dart';
import 'reply_message_widget.dart';
import 'swipe_to_reply.dart';

class ChatBubbleWidget extends StatefulWidget {
  const ChatBubbleWidget({
    required GlobalKey key,
    required this.message,
    required this.onLongPress,
    required this.slideAnimation,
    required this.onSwipe,
    this.onReplyTap,
    this.shouldHighlight = false,
    this.chatViewRenderBox,
    required this.imageListNotifier,
    this.imageHeaders,
    this.imageProviderBuilder,
  }) : super(key: key);

  /// Represent current instance of message.
  final Message message;

  /// Give callback once user long press on chat bubble.
  final DoubleCallBack onLongPress;

  /// Provides callback of when user swipe chat bubble for reply.
  final MessageCallBack onSwipe;

  /// Provides slide animation when user swipe whole chat.
  final Animation<Offset>? slideAnimation;

  /// Provides callback when user tap on replied message upon chat bubble.
  final Function(String)? onReplyTap;

  /// Flag for when user tap on replied message and highlight actual message.
  final bool shouldHighlight;

  final RenderBox? chatViewRenderBox;

  final ValueNotifier<List<PreviewImage>> imageListNotifier;

  // final TextFieldConfiguration? textFieldConfig;
  final Map<String, String>? imageHeaders;

  /// This feature allows you to use a custom image provider.
  /// This is useful if you want to manage image loading yourself, or if you need to cache images.
  /// You can also use the `cached_network_image` feature, but when it comes to caching, you might want to decide on a per-message basis.
  /// Plus, by using this provider, you can choose whether or not to send specific headers based on the URL.
  final ImageProvider Function({
    required String uri,
    required Map<String, String>? imageHeaders,
    required Conditional conditional,
  })? imageProviderBuilder;

  @override
  State<ChatBubbleWidget> createState() => _ChatBubbleWidgetState();
}

class _ChatBubbleWidgetState extends State<ChatBubbleWidget> {
  String get replyMessage =>
      widget.message.replyMessage.messageType == MessageType.image
          ? widget.message.replyMessage.mediaPath
          : widget.message.replyMessage.text;

  bool get isMessageBySender => widget.message.sentBy == currentUser?.id;

  bool get isLastMessage =>
      chatController?.initialMessageList.last.id == widget.message.id;

  FeatureActiveConfig? featureActiveConfig;
  ChatController? chatController;
  ChatUser? currentUser;
  int? maxDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      featureActiveConfig = chatViewIW!.featureActiveConfig;
      chatController = chatViewIW!.chatController;
      currentUser = chatController?.currentUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get user from id.
    final messagedUser = chatController?.getUserFromId(widget.message.sentBy);
    return Stack(
      children: [
        if (featureActiveConfig?.enableSwipeToSeeTime ?? true) ...[
          Visibility(
            visible: widget.slideAnimation?.value.dx == 0.0 ? false : true,
            child: Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: MessageTimeWidget(
                  messageTime: widget.message.createdAt,
                  isCurrentUser: isMessageBySender,
                ),
              ),
            ),
          ),
          SlideTransition(
            position: widget.slideAnimation!,
            child: _chatBubbleWidget(messagedUser),
          ),
        ] else
          _chatBubbleWidget(messagedUser),
      ],
    );
  }

  Widget _chatBubbleWidget(ChatUser? messagedUser) {
    final chatBubbleConfig = chatListConfig.chatBubbleConfig;
    return Container(
      padding: chatBubbleConfig?.padding ?? const EdgeInsets.only(left: 0),
      margin: chatBubbleConfig?.margin ?? const EdgeInsets.only(bottom: 10),
      alignment:
          isMessageBySender ? Alignment.centerRight : Alignment.centerLeft,
      child: _messagesWidgetColumn(messagedUser),
    );
  }

  void onRightSwipe() {
    if (maxDuration != null) {
      widget.message.voiceMessageDuration =
          Duration(milliseconds: maxDuration!);
    }
    if (chatListConfig.swipeToReplyConfig?.onRightSwipe != null) {
      chatListConfig.swipeToReplyConfig?.onRightSwipe!(
          widget.message.mediaPath, widget.message.sentBy);
    }
    widget.onSwipe(widget.message);
  }

  void onLeftSwipe() {
    if (maxDuration != null) {
      widget.message.voiceMessageDuration =
          Duration(milliseconds: maxDuration!);
    }
    if (chatListConfig.swipeToReplyConfig?.onLeftSwipe != null) {
      chatListConfig.swipeToReplyConfig?.onLeftSwipe!(
          widget.message.mediaPath, widget.message.sentBy);
    }
    widget.onSwipe(widget.message);
  }

  Widget _messagesWidgetColumn(ChatUser? messagedUser) {
    return Column(
      crossAxisAlignment:
          isMessageBySender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if ((chatController?.otherUsers.isNotEmpty ?? false) &&
            !isMessageBySender &&
            (featureActiveConfig?.enableOtherUserName ?? true))
          Padding(
            padding: chatListConfig
                    .chatBubbleConfig?.inComingChatBubbleConfig?.padding ??
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              messagedUser?.name ?? '',
              style: chatListConfig.chatBubbleConfig?.inComingChatBubbleConfig
                  ?.senderNameTextStyle,
            ),
          ),
        if (replyMessage.isNotEmpty)
          chatListConfig.repliedMessageConfig?.repliedMessageWidgetBuilder !=
                  null
              ? chatListConfig.repliedMessageConfig!
                  .repliedMessageWidgetBuilder!(widget.message.replyMessage)
              : ReplyMessageWidget(
                  imageHeaders: widget.imageHeaders,
                  imageProviderBuilder: widget.imageProviderBuilder,
                  message: widget.message,
                  repliedMessageConfig: chatListConfig.repliedMessageConfig,
                  onTap: () => widget.onReplyTap
                      ?.call(widget.message.replyMessage.messageId),
                ),
        SwipeToReply(
          isMessageByCurrentUser: isMessageBySender,
          onSwipe: isMessageBySender ? onLeftSwipe : onRightSwipe,
          child: MessageView(
            chatViewRenderBox: widget.chatViewRenderBox,
            imageListNotifier: widget.imageListNotifier,
            outgoingChatBubbleConfig:
                chatListConfig.chatBubbleConfig?.outgoingChatBubbleConfig,
            isLongPressEnable:
                (featureActiveConfig?.enableReactionPopup ?? true) ||
                    (featureActiveConfig?.enableReplySnackBar ?? true),
            inComingChatBubbleConfig:
                chatListConfig.chatBubbleConfig?.inComingChatBubbleConfig,
            message: widget.message,
            isMessageBySender: isMessageBySender,
            messageConfig: chatListConfig.messageConfig,
            onLongPress: widget.onLongPress,
            chatBubbleMaxWidth: chatListConfig.chatBubbleConfig?.maxWidth,
            longPressAnimationDuration:
                chatListConfig.chatBubbleConfig?.longPressAnimationDuration,
            onDoubleTap: featureActiveConfig?.enableDoubleTapToLike ?? false
                ? chatListConfig.chatBubbleConfig?.onDoubleTap ??
                    (message) => currentUser != null
                        ? chatController?.setReaction(
                            emoji: heart,
                            messageId: message.id,
                            userId: currentUser!.id,
                          )
                        : null
                : null,
            shouldHighlight: widget.shouldHighlight,
            controller: chatController,
            highlightColor: chatListConfig.repliedMessageConfig
                    ?.repliedMsgAutoScrollConfig.highlightColor ??
                Colors.grey,
            highlightScale: chatListConfig.repliedMessageConfig
                    ?.repliedMsgAutoScrollConfig.highlightScale ??
                1.1,
            onMaxDuration: _onMaxDuration,
          ),
        ),
      ],
    );
  }

  void _onMaxDuration(int duration) => maxDuration = duration;
}
