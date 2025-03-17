import 'dart:io';

import 'package:chatview/chatview.dart';
import 'package:chatview/src/conditional/conditional.dart';
import 'package:chatview/src/utils/package_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class MediaPreviewScreen extends StatefulWidget {
  const MediaPreviewScreen({
    Key? key,
    this.imageProviderBuilder,
    this.imageHeaders,
    required this.imageUri,
    required this.chatBackgroundConfig,
    this.mediaPreviewConfig,
    required this.otherUser,
    required this.onSend,
  }) : super(key: key);
  final String imageUri;
  final ChatUser otherUser;
  final Function(String imagePath, String caption) onSend;

  // final TextFieldConfiguration? textFieldConfig;
  final Map<String, String>? imageHeaders;

  final ChatBackgroundConfiguration? chatBackgroundConfig;
  final MediaPreviewConfig? mediaPreviewConfig;

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
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          // Image container - takes most of the screen
          GestureDetector(
            onVerticalDragEnd: (_) {},
            child: Center(
              child: Image(
                width: double.infinity,
                height: double.infinity,
                image: widget.imageProviderBuilder != null
                    ? widget.imageProviderBuilder!(
                        uri: widget.imageUri,
                        imageHeaders: widget.imageHeaders,
                        conditional: Conditional(),
                      )
                    : Conditional().getProvider(
                        widget.imageUri,
                        headers: widget.imageHeaders,
                      ),
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top action bar
              Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildCircularButton(
                        widget.mediaPreviewConfig?.closeIcon ??
                            const Icon(
                              Icons.close,
                              color: Colors.white,
                            ), onTap: () {
                      Navigator.pop(context);
                    }),
                    // const SizedBox(width: 20),
                    // _buildFeatureButton("HD"),
                    // _buildCircularButton(Icons.refresh, onTap: () {}),
                    // _buildCircularButton(Icons.emoji_emotions, onTap: () {}),
                    // _buildCircularButton(Icons.text_fields, onTap: () {}),
                    // _buildCircularButton(Icons.edit, onTap: () {}),
                  ],
                ),
              ),
            ],
          ),

          // Bottom caption input
          Positioned(
            bottom: 90,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: widget.mediaPreviewConfig?.textFieldBackgroundColor ??
                    Colors.grey[900],
                borderRadius:
                    widget.mediaPreviewConfig?.textFieldConfig?.borderRadius ??
                        BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: widget.mediaPreviewConfig?.imagePickerIconsConfig
                            ?.galleryImagePickerIcon ??
                        const Icon(
                          Icons.photo,
                          size: 24,
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height /
                          ((!kIsWeb && Platform.isIOS) ? 24 : 28),
                    ),
                    // margin: widget.textFieldConfig?.margin,
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      style: widget
                              .mediaPreviewConfig?.textFieldConfig?.textStyle ??
                          const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintStyle: widget.mediaPreviewConfig?.textFieldConfig
                                ?.hintStyle ??
                            const TextStyle(color: Colors.white60),
                        contentPadding: EdgeInsets.zero,
                        hintText: widget.mediaPreviewConfig?.textFieldConfig
                                ?.hintText ??
                            PackageStrings.message,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  )),
                  // const Expanded(
                  //   child: Text(

                  //     style: TextStyle(
                  //       color: Colors.grey,
                  //       fontSize: 16,
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),

          // User and send button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                widget.mediaPreviewConfig?.receiverNameWidget ??
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.otherUser.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.mediaPreviewConfig?.defaultSendButtonColor ??
                        Theme.of(context).colorScheme.primary,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: widget.mediaPreviewConfig?.sendButtonIcon ??
                        const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 24,
                        ),
                    onPressed: () {
                      widget.onSend(widget.imageUri, _controller.text.trim());
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(Widget icon, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: IconButton(
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              widget.mediaPreviewConfig?.closeIconColor ?? Colors.grey[900],
        ),
        icon: icon,
        onPressed: onTap,
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFeatureButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
