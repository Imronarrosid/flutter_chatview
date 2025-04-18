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
import 'dart:io';

import 'package:chatview/chatview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/inherited_widgets/configurations_inherited_widgets.dart';
import 'package:chatview/src/widgets/chat_list_widget.dart';
import 'package:chatview/src/widgets/chat_view_inherited_widget.dart';
import 'package:chatview/src/widgets/chatview_state_widget.dart';
import 'package:chatview/src/widgets/reaction_popup.dart';
import 'package:chatview/src/widgets/suggestions/suggestions_config_inherited_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart';
import '../conditional/conditional.dart';
import '../values/custom_time_messages.dart';
import 'image_galery.dart';
import 'send_message_widget.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    Key? key,
    required this.chatController,
    this.onSendTap,
    this.profileCircleConfig,
    this.chatBubbleConfig,
    this.repliedMessageConfig,
    this.swipeToReplyConfig,
    this.replyPopupConfig,
    this.reactionPopupConfig,
    this.loadMoreData,
    this.loadMoreImages,
    this.loadingWidget,
    this.messageConfig,
    this.isLastPage,
    this.appBar,
    ChatBackgroundConfiguration? chatBackgroundConfig,
    this.typeIndicatorConfig,
    this.sendMessageBuilder,
    this.sendMessageConfig,
    this.onChatListTap,
    required this.chatViewState,
    ChatViewStateConfiguration? chatViewStateConfig,
    this.featureActiveConfig = const FeatureActiveConfig(),
    this.emojiPickerSheetConfig,
    this.replyMessageBuilder,
    this.replySuggestionsConfig,
    this.scrollToBottomButtonConfig,
    this.imageProviderBuilder,
    this.mediaPreviewConfig,
    this.imageHeaders,
  })  : chatBackgroundConfig =
            chatBackgroundConfig ?? const ChatBackgroundConfiguration(),
        chatViewStateConfig =
            chatViewStateConfig ?? const ChatViewStateConfiguration(),
        super(key: key);

  /// Provides configuration related to user profile circle avatar.
  final ProfileCircleConfiguration? profileCircleConfig;

  /// Provides configurations related to chat bubble such as padding, margin, max
  /// width etc.
  final ChatBubbleConfiguration? chatBubbleConfig;

  /// Allow user to giving customisation different types
  /// messages.
  final MessageConfiguration? messageConfig;

  /// Provides configuration for replied message view which is located upon chat
  /// bubble.
  final RepliedMessageConfiguration? repliedMessageConfig;

  /// Provides configurations related to swipe chat bubble which triggers
  /// when user swipe chat bubble.
  final SwipeToReplyConfiguration? swipeToReplyConfig;

  /// Provides configuration for reply snack bar's appearance and options.
  final ReplyPopupConfiguration? replyPopupConfig;

  /// Provides configuration for reaction pop up appearance.
  final ReactionPopupConfiguration? reactionPopupConfig;

  /// Allow user to give customisation to background of chat
  final ChatBackgroundConfiguration chatBackgroundConfig;

  /// Provides callback when user actions reaches to top and needs to load more
  /// chat
  final VoidCallBackWithFuture? loadMoreData;

  final VoidCallBackWithFuture? loadMoreImages;

  /// Provides widget for loading view while pagination is enabled.
  final Widget? loadingWidget;

  /// Provides flag if there is no more next data left in list.
  final bool? isLastPage;

  /// Provides call back when user tap on send button in text field. It returns
  /// message, reply message and message type.
  final StringMessageCallBack? onSendTap;

  /// Provides builder which helps you to make custom text field and functionality.
  final ReplyMessageWithReturnWidget? sendMessageBuilder;

  /// Allow user to giving customisation typing indicator.
  final TypeIndicatorConfiguration? typeIndicatorConfig;

  /// Provides controller for accessing few function for running chat.
  final ChatController chatController;

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides configuration of default text field in MediaPreview.
  final MediaPreviewConfig? mediaPreviewConfig;

  /// Provides current state of chat.
  final ChatViewState chatViewState;

  /// Provides configuration for chat view state appearance and functionality.
  final ChatViewStateConfiguration? chatViewStateConfig;

  /// Provides configuration for turn on/off specific features.
  final FeatureActiveConfig featureActiveConfig;

  /// Provides parameter so user can assign ChatViewAppbar.
  final Widget? appBar;

  /// Provides callback when user tap on chat list.
  final VoidCallBack? onChatListTap;

  /// Configuration for emoji picker sheet
  final Config? emojiPickerSheetConfig;

  /// Suggestion Item Config
  final ReplySuggestionsConfig? replySuggestionsConfig;

  /// Provides a callback for the view when replying to message
  final CustomViewForReplyMessage? replyMessageBuilder;

  /// Provides a configuration for scroll to bottom button config
  final ScrollToBottomButtonConfig? scrollToBottomButtonConfig;

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

  static void closeReplyMessageView(BuildContext context) {
    final state = context.findAncestorStateOfType<_ChatViewState>();
    if (state == null) return;

    state.replyMessageViewClose();
  }

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView>
    with SingleTickerProviderStateMixin {
  final GlobalKey<SendMessageWidgetState> _sendMessageKey = GlobalKey();
  ValueNotifier<ReplyMessage> replyMessage =
      ValueNotifier(const ReplyMessage());

  ChatController get chatController => widget.chatController;

  ChatBackgroundConfiguration get chatBackgroundConfig =>
      widget.chatBackgroundConfig;

  ChatViewState get chatViewState => widget.chatViewState;

  ChatViewStateConfiguration? get chatViewStateConfig =>
      widget.chatViewStateConfig;

  FeatureActiveConfig get featureActiveConfig => widget.featureActiveConfig;

  RenderBox? chatViewRenderBox;

  PageController? _galleryPageController;
  @override
  void initState() {
    super.initState();
    setLocaleMessages('en', ReceiptsCustomMessages());
    _galleryPageController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    // Scroll to last message on in hasMessages state.
    if (widget.chatController.showTypingIndicator &&
        chatViewState.hasMessages) {
      chatController.scrollToLastMessage();
    }
    return ChatViewInheritedWidget(
      chatController: chatController,
      featureActiveConfig: featureActiveConfig,
      profileCircleConfiguration: widget.profileCircleConfig,
      child: SuggestionsConfigIW(
        suggestionsConfig: widget.replySuggestionsConfig,
        child: Builder(builder: (chatViewContext) {
          WidgetsBinding.instance.addPostFrameCallback((duration) {
            if (chatViewRenderBox == null) {
              setState(() {
                chatViewRenderBox =
                    chatViewContext.findRenderObject() as RenderBox?;
              });
            }
          });
          return ConfigurationsInheritedWidget(
            chatBackgroundConfig: widget.chatBackgroundConfig,
            reactionPopupConfig: widget.reactionPopupConfig,
            typeIndicatorConfig: widget.typeIndicatorConfig,
            chatBubbleConfig: widget.chatBubbleConfig,
            replyPopupConfig: widget.replyPopupConfig,
            messageConfig: widget.messageConfig,
            profileCircleConfig: widget.profileCircleConfig,
            repliedMessageConfig: widget.repliedMessageConfig,
            swipeToReplyConfig: widget.swipeToReplyConfig,
            emojiPickerSheetConfig: widget.emojiPickerSheetConfig,
            scrollToBottomButtonConfig: widget.scrollToBottomButtonConfig,
            child: Stack(
              children: [
                ValueListenableBuilder<bool>(
                    valueListenable: chatController.showGallery,
                    builder: (context, isGalleryShown, _) {
                      return PopScope(
                        canPop: !isGalleryShown,
                        child: Container(
                          height: chatBackgroundConfig.height ??
                              MediaQuery.of(chatViewContext).size.height,
                          width: chatBackgroundConfig.width ??
                              MediaQuery.of(chatViewContext).size.width,
                          decoration: BoxDecoration(
                            color: chatBackgroundConfig.backgroundColor ??
                                Colors.white,
                            image: chatBackgroundConfig.backgroundImage != null
                                ? DecorationImage(
                                    fit: BoxFit.fill,
                                    image: NetworkImage(
                                        chatBackgroundConfig.backgroundImage!),
                                  )
                                : null,
                          ),
                          padding: chatBackgroundConfig.padding,
                          margin: chatBackgroundConfig.margin,
                          child: Column(
                            children: [
                              if (widget.appBar != null) widget.appBar!,
                              Expanded(
                                child: Stack(
                                  children: [
                                    if (chatViewState.isLoading)
                                      ChatViewStateWidget(
                                        chatViewStateWidgetConfig:
                                            chatViewStateConfig
                                                ?.loadingWidgetConfig,
                                        chatViewState: chatViewState,
                                      )
                                    else if (chatViewState.noMessages)
                                      ChatViewStateWidget(
                                        chatViewStateWidgetConfig:
                                            chatViewStateConfig
                                                ?.noMessageWidgetConfig,
                                        chatViewState: chatViewState,
                                        onReloadButtonTap: chatViewStateConfig
                                            ?.onReloadButtonTap,
                                      )
                                    else if (chatViewState.isError)
                                      ChatViewStateWidget(
                                        chatViewStateWidgetConfig:
                                            chatViewStateConfig
                                                ?.errorWidgetConfig,
                                        chatViewState: chatViewState,
                                        onReloadButtonTap: chatViewStateConfig
                                            ?.onReloadButtonTap,
                                      )
                                    else if (chatViewState.hasMessages)
                                      ValueListenableBuilder<ReplyMessage>(
                                        valueListenable: replyMessage,
                                        builder: (_, state, child) {
                                          return ChatListWidget(
                                            imageHeaders: widget.imageHeaders,
                                            imageProviderBuilder:
                                                widget.imageProviderBuilder,
                                            chatViewRenderBox:
                                                chatViewRenderBox,
                                            replyMessage: state,
                                            chatController:
                                                widget.chatController,
                                            loadMoreData: widget.loadMoreData,
                                            isLastPage: widget.isLastPage,
                                            loadingWidget: widget.loadingWidget,
                                            onChatListTap: widget.onChatListTap,
                                            assignReplyMessage: (message) =>
                                                _sendMessageKey.currentState
                                                    ?.assignReplyMessage(
                                                        message),
                                          );
                                        },
                                      ),
                                    if (featureActiveConfig.enableTextField)
                                      SendMessageWidget(
                                        key: _sendMessageKey,
                                        sendMessageBuilder:
                                            widget.sendMessageBuilder,
                                        sendMessageConfig:
                                            widget.sendMessageConfig,
                                        mediaPreviewSendMessageConfig:
                                            widget.mediaPreviewConfig,
                                        onSendTap: (
                                            {required String mediaPath,
                                            required ReplyMessage replyMessage,
                                            required MessageType messageType,
                                            required String text}) {
                                          if (chatViewContext.suggestionsConfig
                                                  ?.autoDismissOnSelection ??
                                              true) {
                                            chatController
                                                .removeReplySuggestions();
                                          }
                                          _onSendTap(
                                            mediaPath: mediaPath,
                                            replyMessage: replyMessage,
                                            messageType: messageType,
                                            text: text,
                                          );
                                        },
                                        onReplyCallback: (reply) =>
                                            replyMessage.value = reply,
                                        onReplyCloseCallback: () => replyMessage
                                            .value = const ReplyMessage(),
                                        messageConfig: widget.messageConfig,
                                        replyMessageBuilder:
                                            widget.replyMessageBuilder,
                                        chatBackgroundConfig:
                                            widget.chatBackgroundConfig,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                if (featureActiveConfig.enableReactionPopup)
                  ValueListenableBuilder<bool>(
                    valueListenable: chatViewContext.chatViewIW!.showPopUp,
                    builder: (_, showPopupValue, child) {
                      return ReactionPopup(
                        chatViewRenderBox: chatViewRenderBox,
                        key: chatViewContext.chatViewIW!.reactionPopupKey,
                        onTap: () => _onChatListTap(chatViewContext),
                        showPopUp: showPopupValue,
                      );
                    },
                  ),
                ValueListenableBuilder<bool>(
                    key: chatViewContext.chatViewIW!.galleryKey,
                    valueListenable: chatController.showGallery,
                    builder: (_, showGallery, child) {
                      if (showGallery) {
                        return ImageGallery(
                          chatContoller: chatController,
                          loadMoreImages: widget.loadMoreImages,
                          imageListNotifier: chatController.imageListNotifier,
                          imageProviderBuilder: widget.imageProviderBuilder,
                          onClosePressed: () =>
                              _onCloseGalleryPressed(chatViewContext),
                          options: widget.messageConfig?.imageMessageConfig
                                  ?.imageGalleryOptions ??
                              const ImageGalleryOptions(),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    }),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _onCloseGalleryPressed(BuildContext context) {
    chatController.showGallery.value = false;
    _galleryPageController?.dispose();
    _galleryPageController = null;
    _galleryPageController = PageController();
  }

  void _onChatListTap(BuildContext context) {
    widget.onChatListTap?.call();
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      FocusScope.of(context).unfocus();
    }
    context.chatViewIW?.showPopUp.value = false;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _onSendTap({
    required String mediaPath,
    required ReplyMessage replyMessage,
    required MessageType messageType,
    required String text,
  }) {
    if (widget.sendMessageBuilder == null) {
      if (widget.onSendTap != null) {
        widget.onSendTap!(
            mediaPath: mediaPath,
            replyMessage: replyMessage,
            messageType: messageType,
            text: text);
      }
      _assignReplyMessage();
    }
    chatController.scrollToLastMessage();
  }

  void replyMessageViewClose() => _sendMessageKey.currentState?.onCloseTap();

  void _assignReplyMessage() {
    if (replyMessage.value.mediaPath.isNotEmpty) {
      replyMessage.value = const ReplyMessage();
    }
  }

  @override
  void dispose() {
    replyMessage.dispose();
    chatViewIW?.showPopUp.dispose();
    super.dispose();
  }
}
