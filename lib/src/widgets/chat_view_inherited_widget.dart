import 'package:chatview/src/widgets/image_galery.dart';
import 'package:chatview/src/widgets/reaction_popup.dart';
import 'package:flutter/material.dart';
import 'package:chatview/chatview.dart';

/// This widget for alternative of excessive amount of passing arguments
/// over widgets.
class ChatViewInheritedWidget extends InheritedWidget {
  ChatViewInheritedWidget({
    Key? key,
    required Widget child,
    required this.featureActiveConfig,
    required this.chatController,
    this.profileCircleConfiguration,
  }) : super(key: key, child: child);
  final FeatureActiveConfig featureActiveConfig;
  final ProfileCircleConfiguration? profileCircleConfiguration;
  final ChatController chatController;
  final GlobalKey chatTextFieldViewKey = GlobalKey();
  final ValueNotifier<bool> showPopUp = ValueNotifier(false);
  final GlobalKey<ReactionPopupState> reactionPopupKey = GlobalKey();
  final GlobalKey<ImageGalleryState> galleryKey = GlobalKey();
  static ChatViewInheritedWidget? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatViewInheritedWidget>();

  @override
  bool updateShouldNotify(covariant ChatViewInheritedWidget oldWidget) =>
      oldWidget.featureActiveConfig != featureActiveConfig;
}
