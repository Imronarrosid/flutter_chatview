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
import 'dart:async';

import 'package:chatview/src/models/data_models/reation_bottom_sheet.dart';
import 'package:chatview/src/values/enumeration.dart';
import 'package:chatview/src/widgets/suggestions/suggestion_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

class ChatController {
  /// Represents initial message list in chat which can be add by user.
  List<Message> initialMessageList;

  List<PreviewImage> imageList = <PreviewImage>[];

  ScrollController scrollController;

  /// Allow user to show typing indicator defaults to false.
  final ValueNotifier<bool> _showTypingIndicator = ValueNotifier(false);

  /// TypingIndicator as [ValueNotifier] for [GroupedChatList] widget's typingIndicator [ValueListenableBuilder].
  ///  Use this for listening typing indicators
  ///   ```dart
  ///    chatcontroller.typingIndicatorNotifier.addListener((){});
  ///  ```
  /// For more functionalities see [ValueNotifier].
  ValueListenable<bool> get typingIndicatorNotifier => _showTypingIndicator;

  /// Allow user to add reply suggestions defaults to empty.
  final ValueNotifier<List<SuggestionItemData>> _replySuggestion =
      ValueNotifier([]);

  /// newSuggestions as [ValueNotifier] for [SuggestionList] widget's [ValueListenableBuilder].
  ///  Use this to listen when suggestion gets added
  ///   ```dart
  ///    chatcontroller.newSuggestions.addListener((){});
  ///  ```
  /// For more functionalities see [ValueNotifier].
  ValueListenable<List<SuggestionItemData>> get newSuggestions =>
      _replySuggestion;

  final ReationBottomSheet _reactionBottomSheetNotifier = ReationBottomSheet();

  final ValueNotifier<List<Message>> _messageListNotifier =
      ValueNotifier<List<Message>>([]);

  final ValueNotifier<List<PreviewImage>> _imageListNotifier =
      ValueNotifier<List<PreviewImage>>([]);

  final ValueNotifier<PageController> _galleryPageController =
      ValueNotifier<PageController>(PageController());

  final ValueNotifier<PreviewImage?> _currentIndexGalery =
      ValueNotifier<PreviewImage?>(null);

  final ValueNotifier<bool> _showGallery = ValueNotifier(false);

  final ValueNotifier<bool> _isLoadMore = ValueNotifier<bool>(false);

  final ValueNotifier<bool> _isLoadMoreImage = ValueNotifier<bool>(false);

  /// Initial [Reaction] value is null
  /// assing previous [Reaction] value first before using it.
  ReationBottomSheet get reactionBottomSheetNotifier =>
      _reactionBottomSheetNotifier;

  ValueNotifier<List<Message>> get messageListNotifier {
    if (_messageListNotifier.value.isEmpty) {
      _messageListNotifier.value = initialMessageList;
    }
    return _messageListNotifier;
  }

  ValueNotifier<List<PreviewImage>> get imageListNotifier => _imageListNotifier;
  ValueNotifier<PageController> get galleryPageController =>
      _galleryPageController;
  ValueNotifier<PreviewImage?> get currentIndexGalery => _currentIndexGalery;

  ValueNotifier<bool> get showGallery => _showGallery;

  /// Getter for typingIndicator value instead of accessing [_showTypingIndicator.value]
  /// for better accessibility.
  bool get showTypingIndicator => _showTypingIndicator.value;

  ValueNotifier<bool> get isLoadMore => _isLoadMore;

  ValueNotifier<bool> get isLoadMoreImage => _isLoadMoreImage;

  set setIsLoadMore(bool value) => _isLoadMore.value = value;

  /// Setter for changing values of typingIndicator
  /// ```dart
  ///  chatContoller.setTypingIndicator = true; // for showing indicator
  ///  chatContoller.setTypingIndicator = false; // for hiding indicator
  ///  ````
  set setTypingIndicator(bool value) => _showTypingIndicator.value = value;

  /// Represents list of chat users
  List<ChatUser> otherUsers;

  /// Provides current user which is sending messages.
  final ChatUser currentUser;

  ChatController({
    required this.initialMessageList,
    required this.scrollController,
    required this.otherUsers,
    required this.currentUser,
  });

  /// Represents message stream of chat
  StreamController<List<Message>> messageStreamController = StreamController();

  /// Used to dispose ValueNotifiers and Streams.
  void dispose() {
    _showTypingIndicator.dispose();
    _replySuggestion.dispose();
    _reactionBottomSheetNotifier.dispose();
    scrollController.dispose();
    _messageListNotifier.dispose();
    _isLoadMore.dispose();
    messageStreamController.close();
  }

  /// Used to add message in message list.
  void addMessage(Message message) {
    initialMessageList.add(message);

    _messageListNotifier.value = [...initialMessageList];

    if (message.messageType == MessageType.image) {
      imageList.add(
        PreviewImage(
          id: message.id,
          uri: message.message,
          createdAt: message.createdAt.millisecondsSinceEpoch,
        ),
      );
      _imageListNotifier.value = [...imageList];
    }
  }

  /// Used to add an image message to the image list.
  void addImageMessage(PreviewImage image) {
    imageList.add(image);
    _imageListNotifier.value = [...imageList];
  }

  /// Used to add reply suggestions.
  void addReplySuggestions(List<SuggestionItemData> suggestions) {
    _replySuggestion.value = suggestions;
  }

  /// Used to remove reply suggestions.
  void removeReplySuggestions() {
    _replySuggestion.value = [];
  }

  /// Function for setting reaction on specific chat bubble
  void setReaction({
    required String emoji,
    required String messageId,
    required String userId,
  }) {
    final message =
        initialMessageList.firstWhere((element) => element.id == messageId);
    final reactedUserIds = message.reaction.reactedUserIds;
    final indexOfMessage = initialMessageList.indexOf(message);
    final userIndex = reactedUserIds.indexOf(userId);
    if (userIndex != -1) {
      if (message.reaction.reactions[userIndex] == emoji) {
        message.reaction.reactions.removeAt(userIndex);
        message.reaction.reactedUserIds.removeAt(userIndex);
      } else {
        message.reaction.reactions[userIndex] = emoji;
      }
    } else {
      message.reaction.reactions.add(emoji);
      message.reaction.reactedUserIds.add(userId);
    }
    initialMessageList[indexOfMessage] = Message(
      id: messageId,
      message: message.message,
      createdAt: message.createdAt,
      sentBy: message.sentBy,
      replyMessage: message.replyMessage,
      reaction: message.reaction,
      messageType: message.messageType,
      status: message.status,
    );
      _messageListNotifier.value = [...initialMessageList];
    if (!messageStreamController.isClosed) {
      messageStreamController.sink.add(initialMessageList);
    }
  }

  /// Funtion to update when reaction data is chaged.
  void updateReactionBottomSheet(Reaction reaction) {
    _reactionBottomSheetNotifier.value = reaction;
  }

  /// Funtion to reset [_bottomSheetReaction.value] onCloseReactionBottomSheet.
  void onCloseReactionBottomSheet() {
    _reactionBottomSheetNotifier.value = null;
  }

  /// Function to scroll to last messages in chat view
  void scrollToLastMessage() => Timer(
        const Duration(milliseconds: 300),
        () {
          if (!scrollController.hasClients) return;
          scrollController.animateTo(
            scrollController.positions.last.minScrollExtent,
            curve: Curves.easeIn,
            duration: const Duration(milliseconds: 300),
          );
        },
      );

  /// Function for loading data while pagination.
  void loadMoreData(List<Message> messageList) {
    /// Here, we have passed 0 index as we need to add data before first data
    _isLoadMore.value = true;
    initialMessageList.insertAll(0, messageList);
    _messageListNotifier.value = [
      ...initialMessageList,
    ];

    imageList.insertAll(
      0,
      messageList
          .where((element) => element.messageType == MessageType.image)
          .toList()
          .fold([], (previousValue, element) {
        return [
          ...previousValue,
          PreviewImage(
            id: element.id,
            uri: element.message,
            createdAt: element.createdAt.millisecondsSinceEpoch,
          ),
        ];
      }),
    );
    _imageListNotifier.value = [...imageList];

    _isLoadMore.value = false;
  }

  void loadMoreImages(List<PreviewImage> newImageList) {
    imageList.insertAll(0, newImageList);

    int initialPage = imageList.indexOf(_currentIndexGalery.value!);

    _imageListNotifier.value = [...imageList];
    _galleryPageController.value = PageController(initialPage: initialPage);
    _isLoadMoreImage.value = false;
  }

  /// Function for getting ChatUser object from user id
  ChatUser getUserFromId(String userId) => userId == currentUser.id
      ? currentUser
      : otherUsers.firstWhere((element) => element.id == userId);
}
