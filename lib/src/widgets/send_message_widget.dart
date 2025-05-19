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
import 'dart:io' if (kIsWeb) 'dart:html';

import 'package:chatview/chatview.dart';
import 'package:chatview/src/conditional/conditional.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/widgets/chatui_textfield.dart';
import 'package:chatview/src/widgets/preview_media_screen.dart';
import 'package:chatview/src/widgets/scroll_to_bottom_button.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class SendMessageWidget extends StatefulWidget {
  const SendMessageWidget({
    Key? key,
    required this.onSendTap,
    this.sendMessageConfig,
    this.sendMessageBuilder,
    this.onReplyCallback,
    this.onReplyCloseCallback,
    this.messageConfig,
    this.replyMessageBuilder,
    this.imageHeaders,
    this.imageProviderBuilder,
    this.chatBackgroundConfig,
    this.mediaPreviewSendMessageConfig,
  }) : super(key: key);

  /// Provides call back when user tap on send button on text field.
  final StringMessageCallBack onSendTap;

  /// Provides configuration for text field appearance.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides configuration for text field appearance on MediaPreview.
  final MediaPreviewConfig? mediaPreviewSendMessageConfig;

  /// Allow user to set custom text field.
  final ReplyMessageWithReturnWidget? sendMessageBuilder;

  /// Provides callback when user swipes chat bubble for reply.
  final ReplyMessageCallBack? onReplyCallback;

  /// Provides call when user tap on close button which is showed in reply pop-up.
  final VoidCallBack? onReplyCloseCallback;

  /// Provides configuration of all types of messages.
  final MessageConfiguration? messageConfig;

  /// Provides a callback for the view when replying to message
  final CustomViewForReplyMessage? replyMessageBuilder;

  final ChatBackgroundConfiguration? chatBackgroundConfig;

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
  State<SendMessageWidget> createState() => SendMessageWidgetState();
}

class SendMessageWidgetState extends State<SendMessageWidget> {
  final _textEditingController = TextEditingController();
  final ValueNotifier<ReplyMessage> _replyMessage = ValueNotifier(const ReplyMessage());

  ReplyMessage get replyMessage => _replyMessage.value;
  final _focusNode = FocusNode();

  ChatUser? get repliedUser =>
      replyMessage.replyTo.isNotEmpty ? chatViewIW?.chatController.getUserFromId(replyMessage.replyTo) : null;

  ChatUser? currentUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      currentUser = chatViewIW!.chatController.currentUser;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollToBottomButtonConfig = chatListConfig.scrollToBottomButtonConfig;
    return Align(
      alignment: Alignment.bottomCenter,
      child: widget.sendMessageBuilder != null
          ? widget.sendMessageBuilder!(replyMessage)
          : SizedBox(
              width: MediaQuery.of(context).size.width,
              child: Stack(
                children: [
                  // This has been added to prevent messages from being
                  // displayed below the text field
                  // when the user scrolls the message list.
                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Container(
                      height: MediaQuery.of(context).size.height / ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                      color: chatListConfig.chatBackgroundConfig.backgroundColor ?? Colors.white,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    left: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (chatViewIW?.featureActiveConfig.enableScrollToBottomButton ?? true)
                          Align(
                            alignment: scrollToBottomButtonConfig?.alignment?.alignment ?? Alignment.bottomCenter,
                            child: Padding(
                              padding: scrollToBottomButtonConfig?.padding ?? EdgeInsets.zero,
                              child: const ScrollToBottomButton(),
                            ),
                          ),
                        Padding(
                          key: chatViewIW?.chatTextFieldViewKey,
                          padding: EdgeInsets.zero,
                          // padding: EdgeInsets.fromLTRB(
                          //   bottomPadding4,
                          //   bottomPadding4,
                          //   bottomPadding4,
                          //   _bottomPadding,
                          // ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              ChatUITextField(
                                focusNode: _focusNode,
                                textEditingController: _textEditingController,
                                onPressed: _onPressed,
                                sendMessageConfig: widget.sendMessageConfig,
                                onRecordingComplete: _onRecordingComplete,
                                onImageSelected: _onImageSelected,
                                onCloseReplyMessage: onCloseTap,
                                replyMessage: _replyMessage,
                                messageConfig: widget.messageConfig,
                                replyMessageBuilder: widget.replyMessageBuilder,
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _onRecordingComplete(String? path) {
    if (path != null) {
      widget.onSendTap.call(
        mediaPath: path,
        replyMessage: replyMessage,
        messageType: MessageType.voice,
        text: '',
      );
      _assignRepliedMessage();
    }
  }

  void _onImageSelected(String imagePath, String error) {
    debugPrint('Call in Send Message Widget');
    if (imagePath.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => MediaPreviewScreen(
            mediaPreviewConfig: widget.mediaPreviewSendMessageConfig,
            chatBackgroundConfig: widget.chatBackgroundConfig,
            imageUri: imagePath,
            imageHeaders: widget.imageHeaders,
            imageProviderBuilder: widget.imageProviderBuilder,
            otherUser: chatViewIW!.chatController.otherUsers.first,
            onSend: (imagePath, caption) {
              widget.onSendTap.call(
                mediaPath: imagePath,
                replyMessage: replyMessage,
                messageType: MessageType.image,
                text: caption.isNotEmpty ? caption : '',
              );
            },
          ),
        ),
      );
    }
  }

  void _assignRepliedMessage() {
    if (replyMessage.text.isNotEmpty ||
        (replyMessage.messageType == MessageType.image && replyMessage.mediaPath.isNotEmpty)) {
      _replyMessage.value = const ReplyMessage();
    }
  }

  void _onPressed() {
    final messageText = _textEditingController.text.trim();
    _textEditingController.clear();
    if (messageText.isEmpty) return;

    widget.onSendTap.call(
      mediaPath: '',
      replyMessage: replyMessage,
      messageType: MessageType.text,
      text: messageText,
    );
    _assignRepliedMessage();
  }

  void assignReplyMessage(Message message) {
    if (currentUser != null) {
      _replyMessage.value = ReplyMessage(
        mediaPath: message.mediaPath,
        text: message.text,
        replyBy: currentUser!.id,
        replyTo: message.sentBy,
        messageType: message.messageType,
        messageId: message.id,
        voiceMessageDuration: message.voiceMessageDuration,
      );
    }
    FocusScope.of(context).requestFocus(_focusNode);
    if (widget.onReplyCallback != null) widget.onReplyCallback!(replyMessage);
  }

  void onCloseTap() {
    _replyMessage.value = const ReplyMessage();
    if (widget.onReplyCloseCallback != null) widget.onReplyCloseCallback!();
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _focusNode.dispose();
    _replyMessage.dispose();
    super.dispose();
  }
}
