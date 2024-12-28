import 'package:chatview/src/extensions/extensions.dart';
import 'package:flutter/material.dart';

import '../controller/chat_controller.dart';
import '../models/models.dart';
import 'profile_image_widget.dart';

class ReactionsBottomSheet {
  Future<void> show({
    required BuildContext context,

    /// Provides instance of message.
    required Message message,

    /// Provides controller for accessing few function for running chat.
    required ChatController chatController,

    /// Provides configuration of reaction bottom sheet appearance.
    required ReactionsBottomSheetConfiguration? reactionsBottomSheetConfig,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return BottomSheetreactionView(
          message: message,
          chatController: chatController,
          reactionsBottomSheetConfig: reactionsBottomSheetConfig,
        );
      },
    );
  }
}

class BottomSheetreactionView extends StatefulWidget {
  const BottomSheetreactionView({
    super.key,
    required this.message,
    required this.chatController,
    this.reactionsBottomSheetConfig,
  });

  /// Provides instance of message.

  final Message message;

  /// Provides controller for accessing few function for running chat.
  final ChatController chatController;

  /// Provides configuration of reaction bottom sheet appearance.
  final ReactionsBottomSheetConfiguration? reactionsBottomSheetConfig;

  @override
  State<BottomSheetreactionView> createState() =>
      _BottomSheetreactionViewState();
}

class _BottomSheetreactionViewState extends State<BottomSheetreactionView> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.chatController.reactionBottomSheetNotifier,
        builder: (context, child) {
          Reaction reaction =
              widget.chatController.reactionBottomSheetNotifier.reaction ??
                  widget.message.reaction;
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            color: widget.reactionsBottomSheetConfig?.backgroundColor,
            child: ListView.builder(
              padding: widget.reactionsBottomSheetConfig?.bottomSheetPadding ??
                  const EdgeInsets.only(
                    right: 12,
                    left: 12,
                    top: 18,
                  ),
              itemCount: reaction.reactedUserIds.length,
              itemBuilder: (_, index) {
                final reactedUser = widget.chatController
                    .getUserFromId(reaction.reactedUserIds[index]);
                return GestureDetector(
                  onTap: () {
                    widget.reactionsBottomSheetConfig?.reactedUserCallback
                        ?.call(reactedUser, widget.message);
                    widget.chatController.updateReactionBottomSheet(
                      widget.chatController.initialMessageList
                          .firstWhere(
                              (element) => element.id == widget.message.id)
                          .reaction,
                    );
                    // reactions.value = chatController.initialMessageList
                    //     .firstWhere((element) => element.id == message.id)
                    //     .reaction;
                  },
                  child: Container(
                    margin: widget
                            .reactionsBottomSheetConfig?.reactionWidgetMargin ??
                        const EdgeInsets.only(bottom: 8),
                    padding: widget.reactionsBottomSheetConfig
                            ?.reactionWidgetPadding ??
                        const EdgeInsets.all(8),
                    decoration: widget.reactionsBottomSheetConfig
                            ?.reactionWidgetDecoration ??
                        BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              offset: const Offset(0, 20),
                              blurRadius: 40,
                            )
                          ],
                          borderRadius: const BorderRadius.all(
                            Radius.circular(
                              10,
                            ),
                          ),
                        ),
                    child: Row(
                      children: [
                        ProfileImageWidget(
                          circleRadius: widget.reactionsBottomSheetConfig
                                  ?.profileCircleRadius ??
                              16,
                          imageUrl: reactedUser.profilePhoto,
                          imageType: reactedUser.imageType,
                          defaultAvatarImage: reactedUser.defaultAvatarImage,
                          assetImageErrorBuilder:
                              reactedUser.assetImageErrorBuilder,
                          networkImageErrorBuilder:
                              reactedUser.networkImageErrorBuilder,
                          networkImageProgressIndicatorBuilder:
                              reactedUser.networkImageProgressIndicatorBuilder,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reactedUser.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: widget.reactionsBottomSheetConfig
                                    ?.reactedUserTextStyle,
                              ),
                              if (widget.reactionsBottomSheetConfig?.subtitle !=
                                      null &&
                                  context.chatViewIW!.chatController.currentUser
                                          .id ==
                                      reactedUser.id)
                                Text(
                                  widget.reactionsBottomSheetConfig!.subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: widget.reactionsBottomSheetConfig
                                      ?.subtitleTextStyle,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          widget.message.reaction.reactions[index],
                          style: TextStyle(
                            fontSize: widget
                                    .reactionsBottomSheetConfig?.reactionSize ??
                                14,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        });
  }

  @override
  void dispose() {
    widget.chatController.onCloseReactionBottomSheet();
    super.dispose();
  }
}
