import 'package:cached_network_image/cached_network_image.dart';
import 'package:chatview/chatview.dart';
import 'package:example/data.dart';
import 'package:example/models/theme.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const Example());
}

class Example extends StatelessWidget {
  const Example({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chat UI Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xffEE5366),
        colorScheme:
            ColorScheme.fromSwatch(accentColor: const Color(0xffEE5366)),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AppTheme theme = LightTheme();
  bool isDarkTheme = false;
  final _chatController = ChatController(
    initialMessageList: Data.messageList,
    scrollController: ScrollController(),
    currentUser: ChatUser(
      id: '1',
      name: 'Flutter',
      profilePhoto: Data.profileImage,
    ),
    otherUsers: [
      ChatUser(
        id: '2',
        name: 'Simform',
        profilePhoto: Data.profileImage,
      ),
      ChatUser(
        id: '3',
        name: 'Jhon',
        profilePhoto: Data.profileImage,
      ),
      ChatUser(
        id: '4',
        name: 'Mike',
        profilePhoto: Data.profileImage,
      ),
      ChatUser(
        id: '5',
        name: 'Rich',
        profilePhoto: Data.profileImage,
      ),
    ],
  );

  void _showHideTypingIndicator() {
    _chatController.setTypingIndicator = !_chatController.showTypingIndicator;
  }

  void receiveMessage() async {
    await Future.delayed(const Duration(milliseconds: 300), () {
      _chatController.loadMoreData([
        ...List.generate(
          5, // Number of messages
          (index) {
            DateTime createdAt =
                DateTime.now().subtract(Duration(hours: 20 * index));
            return Message(
              id: createdAt.toString(), // More consistent ID
              mediaPath:
                  "https://miro.medium.com/max/1000/0*s7of7kWnf9fDg4XM.jpeg",
              createdAt: createdAt,
              sentBy: '2',
              messageType: MessageType.image,
            );
          },
        ).reversed.toList(),
      ]);
    });
    await Future.delayed(const Duration(milliseconds: 500));
    _chatController.addReplySuggestions([
      const SuggestionItemData(text: 'Thanks.'),
      const SuggestionItemData(text: 'Thank you very much.'),
      const SuggestionItemData(text: 'Great.')
    ]);
  }

  void _receiveMessage() async {
    DateTime createdAt = DateTime.now();
    _chatController.addMessage(Message(
      id: createdAt.toString(), // More consistent ID
      mediaPath: "https://picsum.photos/200/300",
      createdAt: createdAt,
      sentBy: '2',
      messageType: MessageType.image,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatView(
        chatController: _chatController,
        onSendTap: _onSendTap,
        loadMoreData: () async => receiveMessage(),
        loadMoreImages: () async {
          _chatController.loadMoreImages([
            ...List.generate(
              5, // Number of messages
              (index) {
                DateTime createdAt =
                    DateTime.now().subtract(Duration(hours: 20 * index));
                return Message(
                  id: createdAt.toString(), // More consistent ID
                  mediaPath:
                      "https://miro.medium.com/max/1000/0*s7of7kWnf9fDg4XM.jpeg",
                  createdAt: createdAt,
                  sentBy: '2',
                  messageType: MessageType.image,
                );
              },
            ).reversed.toList().fold([], (previouse, item) {
              return [
                ...previouse,
                PreviewImage(
                  id: item.id,
                  uri: item.mediaPath,
                  createdAt: item.createdAt.millisecondsSinceEpoch,
                )
              ];
            }),
          ]);
        },
        featureActiveConfig: const FeatureActiveConfig(
            lastSeenAgoBuilderVisibility: true,
            receiptsBuilderVisibility: true,
            enableScrollToBottomButton: true,
            enablePagination: true,
            enableChatSeparator: true,
            enableOtherUserProfileAvatar: true,
            enableOtherUserName: false),
        scrollToBottomButtonConfig: ScrollToBottomButtonConfig(
          backgroundColor: theme.textFieldBackgroundColor,
          border: Border.all(
            color: isDarkTheme ? Colors.transparent : Colors.grey,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.themeIconColor,
            weight: 10,
            size: 30,
          ),
        ),
        chatViewState: ChatViewState.hasMessages,
        chatViewStateConfig: ChatViewStateConfiguration(
          loadingWidgetConfig: ChatViewStateWidgetConfiguration(
            loadingIndicatorColor: theme.outgoingChatBubbleColor,
          ),
          onReloadButtonTap: () {},
        ),
        typeIndicatorConfig: TypeIndicatorConfiguration(
          flashingCircleBrightColor: theme.flashingCircleBrightColor,
          flashingCircleDarkColor: theme.flashingCircleDarkColor,
        ),
        appBar: ChatViewAppBar(
          elevation: theme.elevation,
          backGroundColor: theme.appBarColor,
          profilePicture: Data.profileImage,
          backArrowColor: theme.backArrowColor,
          chatTitle: "Chat view",
          chatTitleTextStyle: TextStyle(
            color: theme.appBarTitleTextStyle,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.25,
          ),
          userStatus: "online",
          imageProviderBuilder: (
              {required conditional, required imageHeaders, required uri}) {
            if (!uri.startsWith('http')) {
              return conditional.getProvider(uri);
            }
            return CachedNetworkImageProvider(
              uri,
              headers: imageHeaders,
            );
          },
          userStatusTextStyle: const TextStyle(color: Colors.grey),
          actions: [
            IconButton(
              onPressed: _onThemeIconTap,
              icon: Icon(
                isDarkTheme
                    ? Icons.brightness_4_outlined
                    : Icons.dark_mode_outlined,
                color: theme.themeIconColor,
              ),
            ),
            IconButton(
              tooltip: 'Toggle TypingIndicator',
              onPressed: _showHideTypingIndicator,
              icon: Icon(
                Icons.keyboard,
                color: theme.themeIconColor,
              ),
            ),
            IconButton(
              tooltip: 'Simulate Message receive',
              onPressed: receiveMessage,
              icon: Icon(
                Icons.supervised_user_circle,
                color: theme.themeIconColor,
              ),
            ),
            IconButton(
              tooltip: 'Simulate Message receive',
              onPressed: _receiveMessage,
              icon: Icon(
                Icons.supervised_user_circle,
                color: theme.themeIconColor,
              ),
            ),
          ],
        ),
        chatBackgroundConfig: ChatBackgroundConfiguration(
          messageTimeIconColor: theme.messageTimeIconColor,
          messageTimeTextStyle: TextStyle(color: theme.messageTimeTextColor),
          defaultGroupSeparatorConfig: DefaultGroupSeparatorConfiguration(
            textStyle: TextStyle(
              color: theme.chatHeaderColor,
              fontSize: 17,
            ),
          ),
          backgroundColor: theme.backgroundColor,
        ),
        mediaPreviewConfig: MediaPreviewConfig(
          defaultSendButtonColor: theme.outgoingChatBubbleColor,
        ),
        sendMessageConfig: SendMessageConfiguration(
          enableHoldToRecord: true,
          holdToRecordConfiguration: HoldToRecordConfiguration(
            lockRecordingAfterDuration: const Duration(seconds: 2),
          ),
          imagePickerIconsConfig: ImagePickerIconsConfiguration(
            cameraIconColor: theme.cameraIconColor,
            galleryIconColor: theme.galleryIconColor,
          ),
          defaultSendButtonColor: theme.
            sendButtonColor,
          replyMessageConfiguration: ReplyMessageViewConfiguration(
            replyMessageColor: theme.replyMessageColor,
            replyDialogColor: theme.replyDialogColor,
            replyTitleColor: theme.replyTitleColor,
            micIconColor: theme.replyMicIconColor,
            closeIconColor: theme.closeIconColor,
          ),
          textFieldBackgroundColor: theme.textFieldBackgroundColor,
          textFieldConfig: TextFieldConfiguration(
            onMessageTyping: (status) {
              /// Do with status
              debugPrint(status.toString());
            },
            compositionThresholdTime: const Duration(seconds: 1),
            textStyle: TextStyle(color: theme.textFieldTextColor),
          ),
          voiceRecordingConfiguration: VoiceRecordingConfiguration(
            backgroundColor: theme.waveformBackgroundColor,
            recorderIconColor: theme.recordIconColor,
            waveStyle: WaveStyle(
              showMiddleLine: false,
              waveColor: theme.waveColor ?? Colors.white,
              extendWaveform: true,
            ),
          ),
        ),
        chatBubbleConfig: ChatBubbleConfiguration(
          outgoingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              // proxyUrl: "https://proxy.corsfix.com/?",
              backgroundColor: theme.linkPreviewOutgoingChatColor,
              bodyStyle: theme.outgoingChatLinkBodyStyle,
              titleStyle: theme.outgoingChatLinkTitleStyle,
            ),
            padding: const EdgeInsets.all(8),
            receiptsWidgetConfig: ReceiptsWidgetConfig(
              showReceiptsIn: ShowReceiptsIn.all,
              receiptsBuilder: (status) {
                return const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                );
              },
            ),
            textStyle: TextStyle(color: Colors.white, fontSize: 14),
            color: theme.outgoingChatBubbleColor,
          ),
          inComingChatBubbleConfig: ChatBubble(
            linkPreviewConfig: LinkPreviewConfiguration(
              linkStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
                decoration: TextDecoration.underline,
              ),
              backgroundColor: theme.linkPreviewIncomingChatColor,
              bodyStyle: theme.incomingChatLinkBodyStyle,
              titleStyle: theme.incomingChatLinkTitleStyle,
            ),
            textStyle: TextStyle(color: theme.inComingChatBubbleTextColor),
            onMessageRead: (message) {
              /// send your message reciepts to the other client
              debugPrint('Message Read');
            },
            senderNameTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            color: theme.inComingChatBubbleColor,
          ),
        ),
        replyPopupConfig: ReplyPopupConfiguration(
          backgroundColor: theme.replyPopupColor,
          buttonTextStyle: TextStyle(color: theme.replyPopupButtonColor),
          topBorderColor: theme.replyPopupTopBorderColor,
        ),
        reactionPopupConfig: ReactionPopupConfiguration(
          shadow: BoxShadow(
            color: isDarkTheme ? Colors.black54 : Colors.grey.shade400,
            blurRadius: 20,
          ),
          backgroundColor: theme.reactionPopupColor,
        ),
        imageProviderBuilder: (
            {required conditional, required imageHeaders, required uri}) {
          if (!uri.startsWith('http')) {
            return conditional.getProvider(uri);
          }

          return CachedNetworkImageProvider(
            uri,
            headers: imageHeaders,
          );
        },
        messageConfig: MessageConfiguration(
          voiceMessageConfig: VoiceMessageConfiguration(),
          messageReactionConfig: MessageReactionConfiguration(
            backgroundColor: theme.messageReactionBackGroundColor,
            borderColor: theme.messageReactionBackGroundColor,
            reactedUserCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionCountTextStyle:
                TextStyle(color: theme.inComingChatBubbleTextColor),
            reactionsBottomSheetConfig: ReactionsBottomSheetConfiguration(
              backgroundColor: theme.backgroundColor,
              reactedUserTextStyle: TextStyle(
                color: theme.inComingChatBubbleTextColor,
              ),
              reactionWidgetDecoration: BoxDecoration(
                color: theme.inComingChatBubbleColor,
                boxShadow: [
                  BoxShadow(
                    color: isDarkTheme ? Colors.black12 : Colors.grey.shade200,
                    offset: const Offset(0, 20),
                    blurRadius: 40,
                  )
                ],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          imageMessageConfig: ImageMessageConfiguration(
            width: 200,
            height: 300,
            unloadedColor: Colors.black,
            hideShareIcon: true,
            imageProviderBuilder: (
                {required conditional, required imageHeaders, required uri}) {
              if (!uri.startsWith('http')) {
                return conditional.getProvider(uri);
              }
              return CachedNetworkImageProvider(
                uri,
                headers: imageHeaders,
              );
            },
            // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            shareIconConfig: ShareIconConfiguration(
              defaultIconBackgroundColor: theme.shareIconBackgroundColor,
              defaultIconColor: theme.shareIconColor,
            ),
          ),
        ),
        profileCircleConfig: const ProfileCircleConfiguration(
          profileImageUrl: Data.profileImage,
        ),
        repliedMessageConfig: RepliedMessageConfiguration(
          backgroundColor: theme.repliedMessageColor,
          verticalBarColor: theme.verticalBarColor,
          repliedMsgAutoScrollConfig: RepliedMsgAutoScrollConfig(
            enableHighlightRepliedMsg: true,
            highlightColor: Colors.pinkAccent.shade100,
            highlightScale: 1.1,
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.25,
          ),
          replyTitleTextStyle: TextStyle(color: theme.repliedTitleTextColor),
        ),
        swipeToReplyConfig: SwipeToReplyConfiguration(
          replyIconColor: theme.swipeToReplyIconColor,
        ),
        replySuggestionsConfig: ReplySuggestionsConfig(
          itemConfig: SuggestionItemConfig(
            decoration: BoxDecoration(
              color: theme.textFieldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.outgoingChatBubbleColor ?? Colors.white,
              ),
            ),
            textStyle: TextStyle(
              color: isDarkTheme ? Colors.white : Colors.black,
            ),
          ),
          onTap: (item) => _onSendTap(
              mediaPath: '',
              replyMessage: const ReplyMessage(),
              messageType: MessageType.text,
              text: item.text),
        ),
      ),
    );
  }

  void _onSendTap({
    required String mediaPath,
    required ReplyMessage replyMessage,
    required MessageType messageType,
    required String text,
  }) {
    final createdAt = DateTime.now();
    final id = createdAt.toString();

    if (messageType == MessageType.image) {
      _chatController.addMessage(
        Message(
          id: id,
          mediaPath: mediaPath,
          text: text,
          createdAt: createdAt,
          sentBy: _chatController.currentUser.id,
          messageType: messageType,
        ),
      );
    } else {
      _chatController.addMessage(
        Message(
          id: id,
          mediaPath: mediaPath,
          text: text,
          createdAt: createdAt,
          sentBy: _chatController.currentUser.id,
          messageType: messageType,
          replyMessage: replyMessage,
        ),
      );
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      _chatController.initialMessageList.last.setStatus =
          MessageStatus.undelivered;
    });
    Future.delayed(const Duration(seconds: 1), () {
      _chatController.initialMessageList.last.setStatus = MessageStatus.read;
    });
  }

  void _onThemeIconTap() {
    setState(() {
      if (isDarkTheme) {
        theme = LightTheme();
        isDarkTheme = false;
      } else {
        theme = DarkTheme();
        isDarkTheme = true;
      }
    });
  }
}
