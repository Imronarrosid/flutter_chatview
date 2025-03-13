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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../conditional/conditional.dart';
import 'highliight_link.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (isMessageBySender && !(imageMessageConfig?.hideShareIcon ?? false))
          iconButton,
        Stack(
          children: [
            Column(
              crossAxisAlignment: isMessageBySender
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
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
                          padding:
                              imageMessageConfig?.padding ?? EdgeInsets.zero,
                          margin: imageMessageConfig?.margin ??
                              EdgeInsets.only(
                                top: 6,
                                right: isMessageBySender ? 6 : 0,
                                left: isMessageBySender ? 0 : 6,
                                bottom: message.reaction.reactions.isNotEmpty
                                    ? 15
                                    : 0,
                              ),
                          child: Center(
                            child: Container(
                              width: imageMessageConfig?.width ?? 150,
                              alignment: isMessageBySender
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isMessageBySender
                                    ? outgoingChatBubbleConfig?.color
                                    : inComingChatBubbleConfig?.color,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius:
                                        imageMessageConfig?.borderRadius ??
                                            BorderRadius.circular(9),
                                    child: (message.caption?.isEmpty ?? true)
                                        ? TimedAndReceiptMessageWidget(
                                            chatController: chatController,
                                            isMessageBySender:
                                                isMessageBySender,
                                            message: message,
                                            inComingChatBubbleConfig:
                                                inComingChatBubbleConfig,
                                            outgoingChatBubbleConfig:
                                                outgoingChatBubbleConfig,
                                            imageMessageConfiguration:
                                                imageMessageConfig,
                                            padding: const EdgeInsets.only(
                                              left: 20,
                                              top: 20,
                                              bottom: 4,
                                              right: 6,
                                            ),
                                            decoration: const BoxDecoration(
                                                borderRadius: BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(50)),
                                                boxShadow: <BoxShadow>[
                                                  BoxShadow(
                                                      blurRadius: 16,
                                                      offset: Offset(5, 10),
                                                      color: Colors.black45),
                                                ]),
                                            child: Container(
                                              height:
                                                  imageMessageConfig?.height ??
                                                      200,
                                              width:
                                                  imageMessageConfig?.width ??
                                                      150,
                                              color: imageMessageConfig
                                                      ?.unloadedColor ??
                                                  Colors.red,
                                              child: Image(
                                                width: double.infinity,
                                                height: double.infinity,
                                                image: imageMessageConfig
                                                            ?.imageProviderBuilder !=
                                                        null
                                                    ? imageMessageConfig!
                                                        .imageProviderBuilder!(
                                                        uri: message.message,
                                                        imageHeaders:
                                                            imageMessageConfig
                                                                ?.imageHeaders,
                                                        conditional:
                                                            Conditional(),
                                                      )
                                                    : Conditional().getProvider(
                                                        message.message,
                                                        headers:
                                                            imageMessageConfig
                                                                ?.imageHeaders,
                                                      ),
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child,
                                                    loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
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
                                              ),
                                            ),
                                          )
                                        : Container(
                                            height:
                                                imageMessageConfig?.height ??
                                                    200,
                                            width: imageMessageConfig?.width ??
                                                150,
                                            color: imageMessageConfig
                                                    ?.unloadedColor ??
                                                Colors.red,
                                            child: Image(
                                              width: double.infinity,
                                              height: double.infinity,
                                              image: imageMessageConfig
                                                          ?.imageProviderBuilder !=
                                                      null
                                                  ? imageMessageConfig!
                                                      .imageProviderBuilder!(
                                                      uri: message.message,
                                                      imageHeaders:
                                                          imageMessageConfig
                                                              ?.imageHeaders,
                                                      conditional:
                                                          Conditional(),
                                                    )
                                                  : Conditional().getProvider(
                                                      message.message,
                                                      headers:
                                                          imageMessageConfig
                                                              ?.imageHeaders,
                                                    ),
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child:
                                                      CircularProgressIndicator(
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
                                            ),
                                          ),
                                  ),
                                  if (message.caption?.isNotEmpty ?? false)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8, right: 8),
                                      child: SizedBox(
                                        width: imageMessageConfig?.width ?? 150,
                                        child: LayoutBuilder(
                                            builder: (context, constraints) {
                                          double aditionalPadding =
                                              getLastLineWidth(
                                            message.caption ?? '',
                                            _textStyle ??
                                                textTheme.bodyMedium!.copyWith(
                                                    color: Colors.white,
                                                    fontSize: 16),
                                            constraints.maxWidth,
                                          );
                                          return TimedAndReceiptMessageWidget(
                                            chatController: chatController,
                                            isMessageBySender:
                                                isMessageBySender,
                                            message: message,
                                            inComingChatBubbleConfig:
                                                inComingChatBubbleConfig,
                                            outgoingChatBubbleConfig:
                                                outgoingChatBubbleConfig,
                                            padding: const EdgeInsets.only(
                                                bottom: 3),
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                bottom: aditionalPadding,
                                              ),
                                              child: HighlihtLink(
                                                showPreview: false,
                                                linkPreviewConfig:
                                                    _linkPreviewConfig,
                                                message: message.caption ?? '',
                                                messageStyle: _textStyle ??
                                                    textTheme.bodyMedium!
                                                        .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                    ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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

  double getLastLineWidth(String text, TextStyle style, double maxWidth) {
    // Create a TextSpan with your text and style
    final textSpan = TextSpan(
      text: text,
      style: style,
    );

    // Create a TextPainter
    final textPainter = TextPainter(
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

      // Extract the text of the last line
      debugPrint(text.substring(start.offset, end.offset));
    }
    if (lastLine.width > maxWidth - 70) {
      return 18;
    }
    return 4;
  }

  TextStyle? get _textStyle => isMessageBySender
      ? outgoingChatBubbleConfig?.textStyle
      : inComingChatBubbleConfig?.textStyle;

  LinkPreviewConfiguration? get _linkPreviewConfig => isMessageBySender
      ? outgoingChatBubbleConfig?.linkPreviewConfig
      : inComingChatBubbleConfig?.linkPreviewConfig;
}
