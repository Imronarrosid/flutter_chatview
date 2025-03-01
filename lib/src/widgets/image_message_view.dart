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
import 'package:chatview/src/widgets/timed_and_receipt_message_widget.dart';
import 'package:flutter/material.dart';

import '../conditional/conditional.dart';
import 'reaction_widget.dart';
import 'share_icon.dart';

class ImageMessageView extends StatelessWidget {
  const ImageMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.imageMessageConfig,
    this.messageReactionConfig,
    this.highlightImage = false,
    this.highlightScale = 1.2,
    required this.imageListNotifier,
    required this.chatController,
    this.outgoingChatBubbleConfig,
    this.inComingChatBubbleConfig,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for image message appearance.
  final ImageMessageConfiguration? imageMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting image when user taps on replied image.
  final bool highlightImage;

  /// Provides scale of highlighted image when user taps on replied image.
  final double highlightScale;

  final ValueNotifier<List<PreviewImage>> imageListNotifier;

  final ChatController chatController;

  final ChatBubble? outgoingChatBubbleConfig;

  final ChatBubble? inComingChatBubbleConfig;

  String get imageUrl => message.message;

  Widget get iconButton => ShareIcon(
        shareIconConfig: imageMessageConfig?.shareIconConfig,
        imageUrl: imageUrl,
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (isMessageBySender && !(imageMessageConfig?.hideShareIcon ?? false))
          iconButton,
        Stack(
          children: [
            ValueListenableBuilder<List<PreviewImage>>(
                valueListenable: imageListNotifier,
                builder: (context, snapshot, _) {
                  return GestureDetector(
                    onTap: () {
                      imageMessageConfig?.onTap != null
                          ? imageMessageConfig?.onTap!(message)
                          : null;

                      final initialPage = snapshot.indexWhere(
                        (element) =>
                            element.id == message.id &&
                            element.uri == message.message,
                      );
                      // context.chatViewIW?.galleryInitialPage.value =
                      //     initialPage;

                      chatController.galleryPageController.value =
                          PageController(
                        initialPage: initialPage,
                      );

                      chatController.showGallery.value = true;
                    },
                    child: Transform.scale(
                      scale: highlightImage ? highlightScale : 1.0,
                      alignment: isMessageBySender
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: imageMessageConfig?.padding ?? EdgeInsets.zero,
                        margin: imageMessageConfig?.margin ??
                            EdgeInsets.only(
                              top: 6,
                              right: isMessageBySender ? 6 : 0,
                              left: isMessageBySender ? 0 : 6,
                              bottom: message.reaction.reactions.isNotEmpty
                                  ? 15
                                  : 0,
                            ),
                        height: imageMessageConfig?.height ?? 200,
                        width: imageMessageConfig?.width ?? 150,
                        child: ClipRRect(
                          borderRadius: imageMessageConfig?.borderRadius ??
                              BorderRadius.circular(14),
                          child: TimedAndReceiptMessageWidget(
                            chatController: chatController,
                            isMessageBySender: isMessageBySender,
                            message: message,
                            inComingChatBubbleConfig: inComingChatBubbleConfig,
                            outgoingChatBubbleConfig: outgoingChatBubbleConfig,
                            imageMessageConfiguration: imageMessageConfig,
                            padding: const EdgeInsets.only(
                              left: 20,
                              top: 20,
                              bottom: 4,
                              right: 6,
                            ),
                            decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(50)),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                      blurRadius: 16,
                                      offset: Offset(5, 10),
                                      color: Colors.black45),
                                ]),
                            child: Container(
                              // height: double.infinity,
                              color: imageMessageConfig?.unloadedColor ??
                                  Colors.red,
                              child: (() {
                                return Image(
                                  width: double.infinity,
                                  height: double.infinity,
                                  image: imageMessageConfig
                                              ?.imageProviderBuilder !=
                                          null
                                      ? imageMessageConfig!
                                          .imageProviderBuilder!(
                                          uri: message.message,
                                          imageHeaders:
                                              imageMessageConfig?.imageHeaders,
                                          conditional: Conditional(),
                                        )
                                      : Conditional().getProvider(
                                          message.message,
                                          headers:
                                              imageMessageConfig?.imageHeaders,
                                        ),
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                );
                                // } else if (imageUrl.fromMemory) {
                                //   return Image.memory(
                                //     base64Decode(imageUrl.substring(
                                //         imageUrl.indexOf('base64') + 7)),
                                //     fit: BoxFit.cover,
                                //   );
                                // } else {
                                //   return Image.file(
                                //     frameBuilder: (context, child, frame,
                                //         wasSynchronouslyLoaded) {
                                //       // If the image was loaded synchronously or the frame is not null (image loaded)
                                //       if (wasSynchronouslyLoaded ||
                                //           frame != null) {
                                //         return child; // Return the image directly
                                //       }

                                //       // While the image is loading, show a placeholder with a fade-in animation
                                //       return AnimatedOpacity(
                                //         opacity: frame != null ? 1.0 : 0.0,
                                //         duration:
                                //             const Duration(milliseconds: 300),
                                //         curve: Curves.easeOut,
                                //         child: child,
                                //       );
                                //     },
                                //     File(imageUrl),
                                //     fit: BoxFit.cover,
                                //   );
                                // }
                              }()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
            if (message.reaction.reactions.isNotEmpty)
              ReactionWidget(
                isMessageBySender: isMessageBySender,
                message: message,
                messageReactionConfig: messageReactionConfig,
              ),
          ],
        ),
        if (!isMessageBySender && !(imageMessageConfig?.hideShareIcon ?? false))
          iconButton,
      ],
    );
  }
}
