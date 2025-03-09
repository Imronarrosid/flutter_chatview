import 'dart:io';

import 'package:chatview/chatview.dart';
import 'package:chatview/src/conditional/conditional.dart';
import 'package:chatview/src/utils/package_strings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageSharingPage extends StatefulWidget {
  const ImageSharingPage({
    Key? key,
    this.imageProviderBuilder,
    this.imageHeaders,
    required this.imageUri,
    required this.chatBackgroundConfig,
    this.textFieldConfig,
    this.sendMessageConfiguration,
    required this.otherUser,
    required this.onSend,
  }) : super(key: key);
  final String imageUri;
  final ChatUser otherUser;
  final Function(String imagePath, String caption) onSend;

  final TextFieldConfiguration? textFieldConfig;
  final Map<String, String>? imageHeaders;

  final ChatBackgroundConfiguration? chatBackgroundConfig;
  final SendMessageConfiguration? sendMessageConfiguration;

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
  State<ImageSharingPage> createState() => _ImageSharingPageState();
}

class _ImageSharingPageState extends State<ImageSharingPage> {
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
            child: Container(
              // margin: const EdgeInsets.symmetric(vertical: 20.0),
              decoration: BoxDecoration(),
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
                    _buildCircularButton(Icons.close, onTap: () {
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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: widget.sendMessageConfiguration
                            ?.imagePickerIconsConfig?.galleryImagePickerIcon ??
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
                      scrollPadding: EdgeInsets.all(0),
                      style: widget.textFieldConfig?.textStyle ??
                          const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          fillColor: Colors.grey[900],
                          hintStyle: widget.textFieldConfig?.hintStyle ??
                              const TextStyle(color: Colors.white60),
                          contentPadding: EdgeInsets.zero,
                          hintText: widget.textFieldConfig?.hintText ??
                              PackageStrings.message,
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(30),
                          )),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1DB954), // Spotify green color
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.navigate_next,
                      color: Colors.black,
                      size: 30,
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

  Widget _buildCircularButton(IconData icon, {required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

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
