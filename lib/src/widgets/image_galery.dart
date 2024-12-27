import 'package:flutter/material.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../conditional/conditional.dart';
import '../models/data_models/image_preview.dart';

class ImageGallery extends StatefulWidget {
  const ImageGallery({
    super.key,
    this.imageHeaders,
    this.imageProviderBuilder,
    required this.images,
    required this.onClosePressed,
    this.options = const ImageGalleryOptions(),
    required this.pageController,
    this.loadMoreImages,
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
  final List<PreviewImage> images;

  /// Triggered when the gallery is swiped down or closed via the icon.
  final VoidCallback onClosePressed;

  /// Customisation options for the gallery.
  final ImageGalleryOptions options;

  /// Page controller for the image pages.
  final PageController pageController;

  final List<PreviewImage> Function()? loadMoreImages;

  @override
  State<ImageGallery> createState() => ImageGalleryState();
}

class ImageGalleryState extends State<ImageGallery> {
  late final List<PreviewImage> listImages;

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
  void initState() {
    listImages = widget.images;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        child: Dismissible(
          key: const Key('photo_view_gallery'),
          direction: DismissDirection.down,
          onDismissed: (direction) => widget.onClosePressed(),
          child: Stack(
            children: [
              PhotoViewGallery.builder(
                builder: (BuildContext context, int index) =>
                    PhotoViewGalleryPageOptions(
                  imageProvider: widget.imageProviderBuilder != null
                      ? widget.imageProviderBuilder!(
                          uri: listImages[index].uri,
                          imageHeaders: widget.imageHeaders,
                          conditional: Conditional(),
                        )
                      : Conditional().getProvider(
                          listImages[index].uri,
                          headers: widget.imageHeaders,
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
                  if (listImages.length == index + 1 &&
                      widget.loadMoreImages != null) {
                    setState(() {
                      listImages.addAll(widget.loadMoreImages!.call());
                    });
                  }
                },
              ),
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
