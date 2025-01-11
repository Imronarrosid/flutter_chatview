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
import 'package:any_link_preview/any_link_preview.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/config_models/link_preview_configuration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants/constants.dart';

class LinkPreview extends StatelessWidget {
  const LinkPreview({
    Key? key,
    required this.message,
    this.linkPreviewConfig,
    this.messageStyle,
  }) : super(key: key);

  /// Provides string message.
  final String message;

  /// Provides configuration of chat bubble appearance when link/URL is passed
  /// in message.
  final LinkPreviewConfiguration? linkPreviewConfig;

  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: linkPreviewConfig?.padding ??
          const EdgeInsets.symmetric(horizontal: 6, vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: verticalPadding),
            child: getUrl().isImageUrl
                ? InkWell(
                    onTap: _onLinkTap,
                    child: Image.network(
                      getUrl(),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                    ),
                  )
                : AnyLinkPreview(
                    link: getUrl(),
                    removeElevation: true,
                    errorBody: linkPreviewConfig?.errorBody,
                    proxyUrl: linkPreviewConfig?.proxyUrl,
                    onTap: _onLinkTap,
                    placeholderWidget: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.25,
                      width: double.infinity,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: linkPreviewConfig?.loadingColor,
                        ),
                      ),
                    ),
                    backgroundColor: linkPreviewConfig?.backgroundColor ??
                        Colors.grey.shade200,
                    borderRadius: linkPreviewConfig?.borderRadius,
                    bodyStyle: linkPreviewConfig?.bodyStyle ??
                        const TextStyle(color: Colors.black),
                    titleStyle: linkPreviewConfig?.titleStyle,
                  ),
          ),
          const SizedBox(height: verticalPadding),
          Linkify(
            text: message,
            style: messageStyle ??
                textTheme.bodyMedium!.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
            linkStyle: linkPreviewConfig?.linkStyle ??
                const TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                ),
            options: const LinkifyOptions(
              humanize: false,
            ),
            onOpen: (link) {
              if (linkPreviewConfig?.onUrlDetect != null) {
                linkPreviewConfig?.onUrlDetect!(message);
              } else {
                _launchUrl(link.url);
              }
            },
          ),
        ],
      ),
    );
  }

  void _onLinkTap() {
    final RegExp urlRegex =
        RegExp(r'^(.*?)((?:https?:\/\/|www\.)[^\s/$.?#].[^\s]*)');
    final url = urlRegex.firstMatch(message);
    if (linkPreviewConfig?.onUrlDetect != null) {
      linkPreviewConfig?.onUrlDetect!(url?[0] ?? '');
    } else {
      _launchURL();
    }
  }

  String getUrl() {
    final RegExp urlRegex =
        RegExp(r'^(.*?)((?:https?:\/\/|www\.)[^\s/$.?#].[^\s]*)');
    return urlRegex.firstMatch(message)?[0] ?? '';
  }

  void _launchURL() async {
    final parsedUrl = Uri.parse(message);
    await canLaunchUrl(parsedUrl)
        ? await launchUrl(parsedUrl)
        : throw couldNotLunch;
  }

  void _launchUrl(String urlString) async {
    final parsedUrl = Uri.parse(urlString);
    await canLaunchUrl(parsedUrl)
        ? await launchUrl(parsedUrl)
        : throw couldNotLunch;
  }
}
