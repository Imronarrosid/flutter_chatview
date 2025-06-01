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
import 'package:chatview/src/conditional/conditional.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:chatview/src/widgets/suggestions/suggestion_list.dart';
import 'package:chatview/src/widgets/type_indicator_widget.dart';
import 'package:flutter/material.dart';

import 'chat_bubble_widget.dart';
import 'chat_group_header.dart';
import 'profile_circle.dart';

class ChatGroupedListWidget extends StatefulWidget {
  const ChatGroupedListWidget({
    Key? key,
    required this.showPopUp,
    required this.scrollController,
    required this.replyMessage,
    required this.assignReplyMessage,
    required this.onChatListTap,
    required this.onChatBubbleLongPress,
    required this.isEnableSwipeToSeeTime,
    this.chatViewRenderBox,
    required this.imageListNotifier,
    this.imageHeaders,
    this.imageProviderBuilder,
  }) : super(key: key);

  /// Allow user to swipe to see time while reaction pop is not open.
  final bool showPopUp;

  /// Pass scroll controller
  final ScrollController scrollController;

  /// Provides reply message if actual message is sent by replying any message.
  final ReplyMessage replyMessage;

  /// Provides callback for assigning reply message when user swipe on chat bubble.
  final MessageCallBack assignReplyMessage;

  /// Provides callback when user tap anywhere on whole chat.
  final VoidCallBack onChatListTap;

  /// Provides callback when user press chat bubble for certain time then usual.
  final void Function(double, double, Message) onChatBubbleLongPress;

  /// Provide flag for turn on/off to see message crated time view when user
  /// swipe whole chat.
  final bool isEnableSwipeToSeeTime;

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
  State<ChatGroupedListWidget> createState() => _ChatGroupedListWidgetState();
}

class _ChatGroupedListWidgetState extends State<ChatGroupedListWidget> with TickerProviderStateMixin {
  bool get showPopUp => widget.showPopUp;

  bool highlightMessage = false;
  final ValueNotifier<String?> _replyId = ValueNotifier(null);

  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;

  FeatureActiveConfig? featureActiveConfig;

  ChatController? chatController;

  bool get isEnableSwipeToSeeTime => widget.isEnableSwipeToSeeTime;

  ChatBackgroundConfiguration get chatBackgroundConfig => chatListConfig.chatBackgroundConfig;

  double chatTextFieldHeight = 0;

  ChatUser? currentUser;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    updateChatTextFieldHeight();
  }

  @override
  void didUpdateWidget(covariant ChatGroupedListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    updateChatTextFieldHeight();
  }

  void updateChatTextFieldHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        chatTextFieldHeight = chatViewIW?.chatTextFieldViewKey.currentContext?.size?.height ?? 10;
      });
    });
  }

  void _initializeAnimation() {
    // When this flag is on at that time only animation controllers will be
    // initialized.
    if (isEnableSwipeToSeeTime) {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
      );
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.0),
        end: const Offset(0.0, 0.0),
      ).animate(
        CurvedAnimation(
          curve: Curves.decelerate,
          parent: _animationController!,
        ),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (chatViewIW != null) {
      featureActiveConfig = chatViewIW!.featureActiveConfig;
      chatController = chatViewIW!.chatController;

      currentUser = chatController?.currentUser;
    }
    _initializeAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return
        // SingleChildScrollView(
        //   reverse: true,
        //   // When reaction popup is being appeared at that user should not scroll.
        //   physics: showPopUp ? const NeverScrollableScrollPhysics() : null,
        //   controller: widget.scrollController,
        //   child: Column(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        GestureDetector(
      onHorizontalDragUpdate: (details) =>
          isEnableSwipeToSeeTime && !showPopUp ? _onHorizontalDrag(details) : null,
      onHorizontalDragEnd: (details) =>
          isEnableSwipeToSeeTime && !showPopUp ? _animationController?.reverse() : null,
      onTap: widget.onChatListTap,
      child: _animationController != null
          ? AnimatedBuilder(
              animation: _animationController!,
              builder: (context, child) {
                return _chatStreamBuilder;
              },
            )
          : _chatStreamBuilder,
    );
    //     if (chatController != null)
    //       ValueListenableBuilder(
    //         valueListenable: chatController!.typingIndicatorNotifier,
    //         builder: (context, value, child) => TypingIndicator(
    //           typeIndicatorConfig: chatListConfig.typeIndicatorConfig,
    //           chatBubbleConfig:
    //               chatListConfig.chatBubbleConfig?.inComingChatBubbleConfig,
    //           showIndicator: value,
    //         ),
    //       ),
    //     if (chatController != null)
    //       Flexible(
    //         child: Align(
    //           alignment: suggestionsListConfig.axisAlignment.alignment,
    //           child: const SuggestionList(),
    //         ),
    //       ),

    //     // Adds bottom space to the message list, ensuring it is displayed
    //     // above the message text field.
    //     SizedBox(
    //       height: chatTextFieldHeight,
    //     ),
    //   ],
    // ),
    // );
  }

  Future<void> _onReplyTap(String id, List<Message>? messages) async {
    // Finds the replied message if exists
    final repliedMessages = messages?.firstWhere((message) => id == message.id);
    final repliedMsgAutoScrollConfig = chatListConfig.repliedMessageConfig?.repliedMsgAutoScrollConfig;
    final highlightDuration = repliedMsgAutoScrollConfig?.highlightDuration ?? const Duration(milliseconds: 300);
    // Scrolls to replied message and highlights
    if (repliedMessages != null && repliedMessages.key.currentState != null) {
      await Scrollable.ensureVisible(
        repliedMessages.key.currentState!.context,
        // This value will make widget to be in center when auto scrolled.
        alignment: 0.5,
        curve: repliedMsgAutoScrollConfig?.highlightScrollCurve ?? Curves.easeIn,
        duration: highlightDuration,
      );
      if (repliedMsgAutoScrollConfig?.enableHighlightRepliedMsg ?? false) {
        _replyId.value = id;

        Future.delayed(highlightDuration, () {
          _replyId.value = null;
        });
      }
    }
  }

  /// When user swipe at that time only animation is assigned with value.
  void _onHorizontalDrag(DragUpdateDetails details) {
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(-0.2, 0.0),
    ).animate(
      CurvedAnimation(
        curve: chatBackgroundConfig.messageTimeAnimationCurve,
        parent: _animationController!,
      ),
    );

    details.delta.dx > 1 ? _animationController?.reverse() : _animationController?.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _replyId.dispose();
    super.dispose();
  }

  Widget get _chatStreamBuilder {
    final suggestionsListConfig = suggestionsConfig?.listConfig ?? const SuggestionListConfig();
    return ValueListenableBuilder<List<Message>>(
      valueListenable: chatController!.messageListNotifier,
      builder: (context, value, _) {
        if (value.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else {
          final messages = chatBackgroundConfig.sortEnable ? sortMessage(value) : value;

          return ListView.custom(
            controller: widget.scrollController,
            reverse: true,

            childrenDelegate: SliverChildBuilderDelegate(
              childCount: messages.length + 3,
              (context, index) {
                int newIndex = messages.length + 2 - index;
                if (chatController != null) {
                  if (newIndex == messages.length) {
                    return ValueListenableBuilder(
                      key: const ValueKey('typingIndicator'),
                      valueListenable: chatController!.typingIndicatorNotifier,
                      builder: (context, value, child) => TypingIndicator(
                        typeIndicatorConfig: chatListConfig.typeIndicatorConfig,
                        chatBubbleConfig: chatListConfig.chatBubbleConfig?.inComingChatBubbleConfig,
                        showIndicator: value,
                      ),
                    );
                  }

                  if (newIndex == messages.length + 1) {
                    return Container(
                      key: const ValueKey('suggestionsList'),
                      alignment: suggestionsListConfig.axisAlignment.alignment,
                      child: const SuggestionList(),
                    );
                  }

                  if (newIndex == messages.length + 2) {
                    return SizedBox(key: const ValueKey('chatTextFieldHeight'), height: chatTextFieldHeight);
                  }
                }
                return ValueListenableBuilder<String?>(
                  key: ValueKey(messages[newIndex].id),
                  valueListenable: _replyId,
                  builder: (context, state, child) {
                    final message = messages[newIndex];
                    final enableScrollToRepliedMsg =
                        chatListConfig.repliedMessageConfig?.repliedMsgAutoScrollConfig.enableScrollToRepliedMsg ??
                            false;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        buildAvatarWidget(newIndex, messages, chatController!),
                        Expanded(
                          child: Column(
                            children: [
                              if (newIndex == 0)
                                ValueListenableBuilder(
                                    valueListenable: chatController!.isLoadMore,
                                    builder: (context, value, _) {
                                      if (value) {
                                        return Center(
                                          child: chatBackgroundConfig.loadingWidget ??
                                              const CircularProgressIndicator(),
                                        );
                                      } else {
                                        return const SizedBox.shrink();
                                      }
                                    }),
                              buildGroupSeparator(newIndex, messages),
                              ChatBubbleWidget(
                                key: message.key,
                                imageListNotifier: widget.imageListNotifier,
                                chatViewRenderBox: widget.chatViewRenderBox,
                                message: message,
                                slideAnimation: _slideAnimation,
                                onLongPress: (yCoordinate, xCoordinate) => widget.onChatBubbleLongPress(
                                  yCoordinate,
                                  xCoordinate,
                                  message,
                                ),
                                imageHeaders: widget.imageHeaders,
                                imageProviderBuilder: widget.imageProviderBuilder,
                                onSwipe: widget.assignReplyMessage,
                                shouldHighlight: state == message.id,
                                onReplyTap:
                                    enableScrollToRepliedMsg ? (replyId) => _onReplyTap(replyId, value) : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              findChildIndexCallback: (key) {
                if (key == const ValueKey('typingIndicator')) {
                  return 2;
                } else if (key == const ValueKey('suggestionsList')) {
                  return 1;
                } else if (key == const ValueKey('chatTextFieldHeight')) {
                  return 0;
                }
                final valueKey = key as ValueKey<dynamic>;

                final Map<String, int> messageMap = {for (int i = 0; i < messages.length; i++) messages[i].id: i};

                return messageMap.length + 2 - messageMap[valueKey.value]!;
              },
            ),
            key: widget.key,
            // physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            shrinkWrap: true,
          );
        }
      },
    );
  }

  List<Message> sortMessage(List<Message> messages) {
    final elements = [...messages];
    elements.sort(
      chatBackgroundConfig.messageSorter ?? (a, b) => a.createdAt.compareTo(b.createdAt),
    );
    if (chatBackgroundConfig.groupedListOrder.isAsc) {
      return elements.toList();
    } else {
      return elements.reversed.toList();
    }
  }

  Widget buildGroupSeparator(int newIndex, List<Message> messages) {
    // Check if it's the first message or if the day is different from the previous message
    final isFirstMessage = newIndex == 0;
    final isDifferentDay =
        !isFirstMessage && messages[newIndex].createdAt.day != messages[newIndex - 1].createdAt.day;

    // Show the date separator if it's the first message or a different day
    if (isFirstMessage || isDifferentDay) {
      return _groupSeparator(messages[newIndex].createdAt);
    } else {
      return const SizedBox.shrink();
    }
  }

// Helper function to safely get the next message
  Message? getNextMessage(List<Message> messages, int currentIndex) {
    final nextIndex = currentIndex + 1;
    if (nextIndex < messages.length) {
      return messages[nextIndex];
    }
    return null;
  }

// Actual widget rendering
  Widget buildAvatarWidget(int newIndex, List<Message> messages, ChatController chatController) {
    final messagedUser = chatController.getUserFromId(messages[newIndex].sentBy);
    bool isMessageBySender = messages[newIndex].sentBy == currentUser?.id;

    final currentMessage = messages[newIndex];
    final nextMessage = getNextMessage(messages, newIndex);
    final isLastMessage = newIndex == messages.length - 1;
    final isNotCurrentUser = chatController.currentUser.id != currentMessage.sentBy;

    final profileCircleConfig = chatListConfig.profileCircleConfig;

    final radius = (profileCircleConfig?.circleRadius ?? 16) * 2;

    // Check if we should show the avatar container
    bool shouldShowAvatar = false;

    if (isNotCurrentUser) {
      if (isLastMessage) {
        shouldShowAvatar = true;
      } else if (nextMessage != null) {
        final isDifferentSender = currentMessage.sentBy != nextMessage.sentBy;
        final isDifferentDay = currentMessage.createdAt.day != nextMessage.createdAt.day;

        if (isDifferentSender || (isDifferentDay && isNotCurrentUser)) {
          shouldShowAvatar = true;
        }
      }
    }

    return shouldShowAvatar
        ? Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 10),
            child: (!isMessageBySender && (featureActiveConfig?.enableOtherUserProfileAvatar ?? true))
                ? profileCircle(messagedUser, messages[newIndex])
                : const SizedBox.shrink(),
          )
        : SizedBox(
            width: (!isMessageBySender && (featureActiveConfig?.enableOtherUserProfileAvatar ?? true))
                ? radius + 6
                : 0,
          );
  }
  // /// return DateTime by checking lastMatchedDate and message created DateTime
  // DateTime _groupBy(
  //   Message message,
  //   DateTime lastMatchedDate,
  // ) {
  //   /// If the conversation is ongoing on the same date,
  //   /// return the same date [lastMatchedDate].

  //   /// When the conversation starts on a new date,
  //   /// we are returning new date [message.createdAt].
  //   return lastMatchedDate.getDateFromDateTime ==
  //           message.createdAt.getDateFromDateTime
  //       ? lastMatchedDate
  //       : message.createdAt;
  // }
  ProfileCircle profileCircle(ChatUser? messagedUser, Message message) {
    final profileCircleConfig = chatListConfig.profileCircleConfig;
    return ProfileCircle(
      imageProviderBuilder: widget.imageProviderBuilder,
      imageHeaders: widget.imageHeaders,
      bottomPadding: message.reaction.reactions.isNotEmpty
          ? profileCircleConfig?.bottomPadding ?? 15
          : profileCircleConfig?.bottomPadding ?? 2,
      profileCirclePadding: profileCircleConfig?.padding,
      imageUrl: messagedUser?.profilePhoto,
      imageType: messagedUser?.imageType,
      defaultAvatarImage: messagedUser?.defaultAvatarImage ?? profileImage,
      networkImageProgressIndicatorBuilder: messagedUser?.networkImageProgressIndicatorBuilder,
      assetImageErrorBuilder: messagedUser?.assetImageErrorBuilder,
      networkImageErrorBuilder: messagedUser?.networkImageErrorBuilder,
      circleRadius: profileCircleConfig?.circleRadius,
      onTap: () => _onAvatarTap(messagedUser),
      onLongPress: () => _onAvatarLongPress(messagedUser),
    );
  }

  Widget _groupSeparator(DateTime createdAt) {
    return featureActiveConfig?.enableChatSeparator ?? false
        ? _GroupSeparatorBuilder(
            separator: createdAt,
            defaultGroupSeparatorConfig: chatBackgroundConfig.defaultGroupSeparatorConfig,
            groupSeparatorBuilder: chatBackgroundConfig.groupSeparatorBuilder,
          )
        : SizedBox.shrink(
            key: ValueKey(createdAt.toString()),
          );
  }

  // GetMessageSeparator _getMessageSeparator(
  //   List<Message> messages,
  //   DateTime lastDate,
  // ) {
  //   final messageSeparator = <int, DateTime>{};
  //   final allKeys = <int, dynamic>{};

  //   var lastMatchedDate = lastDate;
  //   var counter = 0;
  //   var allKeysCounter = 0;

  //   /// Holds index and separator mapping to display in chat
  //   for (var i = 0; i < messages.length; i++) {
  //     if (messageSeparator.isEmpty) {
  //       /// Separator for initial message
  //       messageSeparator[0] = messages[0].createdAt;

  //       allKeysCounter++;
  //       allKeys[0] = messages[0].createdAt;
  //       allKeys[0 + allKeysCounter] = messages[0].id;
  //       continue;
  //     }

  //     lastMatchedDate = _groupBy(
  //       messages[i],
  //       lastMatchedDate,
  //     );
  //     var previousDate = _groupBy(
  //       messages[i - 1],
  //       lastMatchedDate,
  //     );

  //     if (previousDate != lastMatchedDate) {
  //       /// Group separator when previous message and
  //       /// current message time differ
  //       counter++;
  //       allKeysCounter++;

  //       messageSeparator[i + counter] = messages[i].createdAt;

  //       if (allKeys.isEmpty) {
  //         allKeys[0] = messages[0].createdAt;
  //         allKeys[i] = messages[i].id;
  //       } else {
  //         allKeys[i] = messages[i].createdAt;
  //         allKeys[i + 1] = messages[i].id;
  //       }
  //     } else if (allKeys.isEmpty) {
  //       allKeys[0] = messages[0].id;
  //       allKeys[1] = messages[1].id;
  //     } else {
  //       allKeys[i + allKeysCounter] = messages[i].id;
  //     }
  //   }

  //   return (messageSeparator, lastMatchedDate);
  // }

  // void _updateFloatingDate(List<Message> messages) {
  //   for (int i = 0; i < messages.length; i++) {
  //     final RenderObject? renderObject = context.findRenderObject();
  //     if (renderObject is RenderBox) {
  //       final position = renderObject.localToGlobal(Offset.zero);
  //       if (position.dy >= 0) {
  //         _floatingDate.value = messages[i].createdAt;
  //         break;
  //       }
  //     }
  //   }
  // }

  void _onAvatarTap(ChatUser? user) {
    if (chatListConfig.profileCircleConfig?.onAvatarTap != null && user != null) {
      chatListConfig.profileCircleConfig?.onAvatarTap!(user);
    }
  }

  void _onAvatarLongPress(ChatUser? user) {
    if (chatListConfig.profileCircleConfig?.onAvatarLongPress != null && user != null) {
      chatListConfig.profileCircleConfig?.onAvatarLongPress!(user);
    }
  }
}

class _GroupSeparatorBuilder extends StatelessWidget {
  const _GroupSeparatorBuilder({
    Key? key,
    required this.separator,
    this.groupSeparatorBuilder,
    this.defaultGroupSeparatorConfig,
  }) : super(key: key);
  final DateTime separator;
  final StringWithReturnWidget? groupSeparatorBuilder;
  final DefaultGroupSeparatorConfiguration? defaultGroupSeparatorConfig;

  @override
  Widget build(BuildContext context) {
    return groupSeparatorBuilder != null
        ? groupSeparatorBuilder!(separator.toString())
        : ChatGroupHeader(
            day: separator,
            groupSeparatorConfig: defaultGroupSeparatorConfig,
          );
  }
}
