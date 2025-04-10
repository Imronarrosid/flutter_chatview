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
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Message {
  /// Provides id
  final String id;

  /// Used for accessing widget's render box.
  final GlobalKey key;

  /// Provides actual message it will be image/audio file path.
  final String mediaPath;

  /// Provides text of messages.
  final String text;

  /// Provides message created date time.
  final DateTime createdAt;

  /// Provides id of sender of message.
  final String sentBy;

  /// Provides reply message if user triggers any reply on any message.
  final ReplyMessage replyMessage;

  /// Represents reaction on message.
  final ReactionNotifier _reaction;

  /// Provides message type.
  final MessageType messageType;

  /// Status of the message.
  final ValueNotifier<MessageStatus> _status;

  /// Provides max duration for recorded voice message.
  Duration? voiceMessageDuration;

  Message({
    this.id = '',
    this.mediaPath = '',
    this.text = '',
    required this.createdAt,
    required this.sentBy,
    this.replyMessage = const ReplyMessage(),
    Reaction? reaction,
    this.messageType = MessageType.text,
    this.voiceMessageDuration,
    MessageStatus status = MessageStatus.pending,
  })  : key = GlobalKey(),
        _status = ValueNotifier(status),
        _reaction = ReactionNotifier(
            reaction ?? Reaction(reactions: [], reactedUserIds: [])),
        assert(
          (messageType.isVoice
              ? ((defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.android))
              : true),
          "Voice messages are only supported with android and ios platform",
        );

  /// curret messageStatus
  MessageStatus get status => _status.value;
  Reaction get reaction => _reaction.reaction!;

  /// For [MessageStatus] ValueNotfier which is used to for rebuilds
  /// when state changes.
  /// Using ValueNotfier to avoid usage of setState((){}) in order
  /// rerender messages with new receipts.
  ValueNotifier<MessageStatus> get statusNotifier => _status;

  /// For [Reaction] ValueNotfier which is used to for rebuilds
  /// when state changes.
  /// Using ValueNotfier to avoid usage of setState((){}) in order
  /// rerender messages with new receipts.
  ReactionNotifier get reactionNotifier => _reaction;

  /// This setter can be used to update message receipts, after which the configured
  /// builders will be updated.
  set setStatus(MessageStatus messageStatus) {
    _status.value = messageStatus;
  }

  /// This setter can be used to update message receipts, after which the configured
  /// builders will be updated.
  set setReaction(Reaction messageReaction) {
    _reaction.value = messageReaction;
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        mediaPath: json['mediaPath']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
        sentBy: json['sentBy']?.toString() ?? '',
        replyMessage: json['reply_message'] is Map<String, dynamic>
            ? ReplyMessage.fromJson(json['reply_message'])
            : const ReplyMessage(),
        reaction: json['reaction'] is Map<String, dynamic>
            ? Reaction.fromJson(json['reaction'])
            : null,
        messageType: MessageType.tryParse(json['message_type']?.toString()) ??
            MessageType.text,
        voiceMessageDuration: Duration(
          microseconds:
              int.tryParse(json['voice_message_duration'].toString()) ?? 0,
        ),
        status: MessageStatus.tryParse(json['status']?.toString()) ??
            MessageStatus.pending,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mediaPath': mediaPath,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'sentBy': sentBy,
        'reply_message': replyMessage.toJson(),
        'reaction': _reaction.value.toJson(),
        'message_type': messageType.name,
        'voice_message_duration': voiceMessageDuration?.inMicroseconds,
        'status': status.name,
      };

  Message copyWith({
    String? id,
    GlobalKey? key,
    String? mediaPath,
    String? text,
    DateTime? createdAt,
    String? sentBy,
    ReplyMessage? replyMessage,
    Reaction? reaction,
    MessageType? messageType,
    Duration? voiceMessageDuration,
    MessageStatus? status,
    bool forceNullValue = false,
  }) {
    return Message(
      id: id ?? this.id,
      mediaPath: mediaPath ?? this.mediaPath,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      sentBy: sentBy ?? this.sentBy,
      messageType: messageType ?? this.messageType,
      voiceMessageDuration: forceNullValue
          ? voiceMessageDuration
          : voiceMessageDuration ?? this.voiceMessageDuration,
      reaction: reaction ?? this.reaction,
      replyMessage: replyMessage ?? this.replyMessage,
      status: status ?? this.status,
    );
  }
}
