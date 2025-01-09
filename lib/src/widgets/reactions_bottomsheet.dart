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

          String elementToMove = widget.chatController.currentUser.id;

          // Check if the element exists in the list
          if (reaction.reactedUserIds.contains(elementToMove)) {
            int elementToMoveIndex =
                reaction.reactedUserIds.indexOf(elementToMove);
            String reactionToMove =
                reaction.reactions.elementAt(elementToMoveIndex);
            // Remove the element from its current position
            reaction.reactedUserIds.remove(elementToMove);
            reaction.reactions.removeAt(elementToMoveIndex);

            // Insert the element at the first index
            reaction.reactedUserIds.insert(0, elementToMove);
            reaction.reactions.insert(0, reactionToMove);
          }

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

                    _removeCurrentUserReaction(reactedUser);
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
                              if (widget.chatController.currentUser.id ==
                                  reactedUser.id)
                                Text(
                                  widget.reactionsBottomSheetConfig?.subtitle ??
                                      'Tap to remove',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: widget.reactionsBottomSheetConfig
                                          ?.subtitleTextStyle ??
                                      TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.4),
                                      ),
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

  /// Remove current user reaction from [ReactionsBottomSheet].
  void _removeCurrentUserReaction(ChatUser reactedUser) {
    List<String> reactedUserIds = widget.message.reaction.reactedUserIds;
    List<String> reactions = widget.message.reaction.reactions;

    final ChatUser currentUser = widget.chatController.currentUser;

    widget.reactionsBottomSheetConfig?.removeReactedCurrentUserCallback?.call(
      currentUser,
      widget.message,
    );

    if (reactedUser.id == widget.chatController.currentUser.id) {
      widget.chatController.setReaction(
        emoji: widget.message.reaction.reactions[
            widget.message.reaction.reactedUserIds.indexOf(currentUser.id)],
        messageId: widget.message.id,
        userId: widget.chatController.currentUser.id,
      );

      Reaction reactionResult =
          Reaction(reactedUserIds: reactedUserIds, reactions: reactions);
      widget.chatController.updateReactionBottomSheet(
        reactionResult,
      );
    }
  }

  @override
  void dispose() {
    widget.chatController.onCloseReactionBottomSheet();
    super.dispose();
  }
}
