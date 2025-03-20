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

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/conditional/conditional.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/package_strings.dart';
import '../values/enumeration.dart';
import '../values/typedefs.dart';
import 'image_provider_widget.dart';

class ReplyMessageView extends StatelessWidget {
  const ReplyMessageView({
    super.key,
    required this.message,
    this.customMessageReplyViewBuilder,
    this.sendMessageConfig,
    this.imageHeaders,
    this.imageProviderBuilder,
  });

  final ReplyMessage message;

  final CustomMessageReplyViewBuilder? customMessageReplyViewBuilder;
  final SendMessageConfiguration? sendMessageConfig;

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
  Widget build(BuildContext context) {
    return switch (message.messageType) {
      MessageType.voice => Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
              child: Row(
                children: [
                  sendMessageConfig?.replyMessageConfiguration?.micIcon ??
                      Icon(
                        Icons.mic,
                        color: sendMessageConfig
                            ?.replyMessageConfiguration?.micIconColor,
                      ),
                  const SizedBox(width: 4),
                  if (message.voiceMessageDuration != null)
                    Text(
                      message.voiceMessageDuration!.toHHMMSS(),
                      style: TextStyle(
                        fontSize: 12,
                        color: sendMessageConfig?.replyMessageConfiguration
                                ?.replyMessageColor ??
                            Colors.black,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      MessageType.image => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6.0, bottom: 6.0),
              child: sendMessageConfig?.replyMessageConfiguration?.imageIcon ??
                  Icon(
                    Icons.photo,
                    size: 20,
                    color: sendMessageConfig
                            ?.replyMessageConfiguration?.replyMessageColor ??
                        Colors.grey.shade700,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                PackageStrings.photo,
                style: TextStyle(
                  color: sendMessageConfig
                          ?.replyMessageConfiguration?.replyMessageColor ??
                      Colors.black,
                ),
              ),
            ),
            const Spacer(),

            ImageProviderWidget(
              width: 40,
              height: 55,
              fit: BoxFit.cover,
              imageUri: message.mediaPath,
              imageHeaders: imageHeaders,
              imageProviderBuilder: imageProviderBuilder,
            ),
            // Image.file(
            //   File(message.mediaPath),
            //   width: 40,
            //   height: 55,
            //   fit: BoxFit.cover,
            // )
          ],
        ),
      MessageType.custom when customMessageReplyViewBuilder != null =>
        customMessageReplyViewBuilder!(message),
      MessageType.custom || MessageType.text => Padding(
          padding: const EdgeInsets.all(6.0),
          child: Text(
            message.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: sendMessageConfig
                      ?.replyMessageConfiguration?.replyMessageColor ??
                  Colors.black,
            ),
          ),
        ),
    };
  }
}
