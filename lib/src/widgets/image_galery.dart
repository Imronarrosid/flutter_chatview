import 'dart:io';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../conditional/conditional.dart';
import '../models/data_models/image_preview.dart';

class ImageGallery extends StatefulWidget {
  const ImageGallery({
    super.key,
    this.imageHeaders,
    this.imageProviderBuilder,
    required this.onClosePressed,
    this.options = const ImageGalleryOptions(),
    required this.pageController,
    this.loadMoreImages,
    required this.imageListNotifier,
  });

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

  /// Images to show in the gallery.
  final ValueNotifier<List<PreviewImage>> imageListNotifier;

  /// Triggered when the gallery is swiped down or closed via the icon.
  final VoidCallback onClosePressed;

  /// Customisation options for the gallery.
  final ImageGalleryOptions options;

  /// Page controller for the image pages.
  final PageController pageController;

  final void Function()? loadMoreImages;

  @override
  State<ImageGallery> createState() => ImageGalleryState();
}

class ImageGalleryState extends State<ImageGallery> {
  Widget _imageGalleryLoadingBuilder(ImageChunkEvent? event) => Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: event == null || event.expectedTotalBytes == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
      );

  @override
  void dispose() {
    widget.pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        child: Dismissible(
          key: const Key('photo_view_gallery'),
          direction: DismissDirection.down,
          onDismissed: (direction) => widget.onClosePressed(),
          child: Stack(
            children: [
              ValueListenableBuilder<List<PreviewImage>>(
                  valueListenable: widget.imageListNotifier,
                  builder: (context, listImages, _) {
                    return PhotoViewGallery.builder(
                      builder: (BuildContext context, int index) =>
                          PhotoViewGalleryPageOptions(
                        imageProvider: _getProvider(
                          index,
                          listImages,
                        ),
                        minScale: widget.options.minScale,
                        maxScale: widget.options.maxScale,
                      ),
                      itemCount: listImages.length,
                      loadingBuilder: (context, event) =>
                          _imageGalleryLoadingBuilder(event),
                      pageController: widget.pageController,
                      scrollPhysics: const ClampingScrollPhysics(),
                      onPageChanged: (index) {
                        if (0 == index && widget.loadMoreImages != null) {
                          widget.loadMoreImages!.call();
                        }
                        if (0 == index) {
                          kDebugMode ? debugPrint('Load more images') : null;
                        }
                      },
                    );
                  }),
              Positioned.directional(
                end: 16,
                textDirection: Directionality.of(context),
                top: 56,
                child: CloseButton(
                  color: Colors.white,
                  onPressed: widget.onClosePressed,
                ),
              ),
            ],
          ),
        ),
      );

  ImageProvider<Object> _getProvider(int index, List<PreviewImage> listImages) {
    if (listImages[index].uri.isUrl) {
      return widget.imageProviderBuilder != null
          ? widget.imageProviderBuilder!(
              uri: listImages[index].uri,
              imageHeaders: widget.imageHeaders,
              conditional: Conditional(),
            )
          : Conditional().getProvider(
              listImages[index].uri,
              headers: widget.imageHeaders,
            );
    } else {
      return FileImage(
        File(listImages[index].uri),
      );
    }
  }
}

class ImageGalleryOptions {
  const ImageGalleryOptions({
    this.maxScale,
    this.minScale,
  });

  /// See [PhotoViewGalleryPageOptions.maxScale].
  final dynamic maxScale;

  /// See [PhotoViewGalleryPageOptions.minScale].
  final dynamic minScale;
}

class GalleryNotifier extends ChangeNotifier {
  GalleryState _navbarState = GalleryState.show;

  GalleryState get navbarState => _navbarState;

  void chnageNavbarState(GalleryState isShowing) {
    _navbarState = isShowing;
    notifyListeners();
  }
}

enum GalleryState {
  show,
  hidden,
}
