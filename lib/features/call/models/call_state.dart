enum CallState {
  incoming,
  connecting,
  connected,
  ended,
}

enum CallType {
  audio,
  video,
}

class CallData {
  final String callId;
  final String contactId;
  final String contactName;
  final String? contactAvatar;
  final CallType callType;
  final bool isIncoming;
  final DateTime startTime;
  final Duration? duration;
  final CallState state;

  const CallData({
    required this.callId,
    required this.contactId,
    required this.contactName,
    this.contactAvatar,
    required this.callType,
    required this.isIncoming,
    required this.startTime,
    this.duration,
    required this.state,
  });

  CallData copyWith({
    String? callId,
    String? contactId,
    String? contactName,
    String? contactAvatar,
    CallType? callType,
    bool? isIncoming,
    DateTime? startTime,
    Duration? duration,
    CallState? state,
  }) {
    return CallData(
      callId: callId ?? this.callId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactAvatar: contactAvatar ?? this.contactAvatar,
      callType: callType ?? this.callType,
      isIncoming: isIncoming ?? this.isIncoming,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'contactId': contactId,
      'contactName': contactName,
      'contactAvatar': contactAvatar,
      'callType': callType.name,
      'isIncoming': isIncoming,
      'startTime': startTime.toIso8601String(),
      'duration': duration?.inSeconds,
      'state': state.name,
    };
  }

  factory CallData.fromJson(Map<String, dynamic> json) {
    return CallData(
      callId: json['callId'],
      contactId: json['contactId'],
      contactName: json['contactName'],
      contactAvatar: json['contactAvatar'],
      callType: CallType.values.firstWhere(
        (e) => e.name == json['callType'],
        orElse: () => CallType.audio,
      ),
      isIncoming: json['isIncoming'],
      startTime: DateTime.parse(json['startTime']),
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration']) 
          : null,
      state: CallState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => CallState.ended,
      ),
    );
  }
}

class CallHistory {
  final String id;
  final String contactId;
  final String contactName;
  final String? contactAvatar;
  final CallType callType;
  final bool isIncoming;
  final bool wasAnswered;
  final DateTime timestamp;
  final Duration? duration;

  const CallHistory({
    required this.id,
    required this.contactId,
    required this.contactName,
    this.contactAvatar,
    required this.callType,
    required this.isIncoming,
    required this.wasAnswered,
    required this.timestamp,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'contactName': contactName,
      'contactAvatar': contactAvatar,
      'callType': callType.name,
      'isIncoming': isIncoming,
      'wasAnswered': wasAnswered,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration?.inSeconds,
    };
  }

  factory CallHistory.fromJson(Map<String, dynamic> json) {
    return CallHistory(
      id: json['id'],
      contactId: json['contactId'],
      contactName: json['contactName'],
      contactAvatar: json['contactAvatar'],
      callType: CallType.values.firstWhere(
        (e) => e.name == json['callType'],
        orElse: () => CallType.audio,
      ),
      isIncoming: json['isIncoming'],
      wasAnswered: json['wasAnswered'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: json['duration'] != null 
          ? Duration(seconds: json['duration']) 
          : null,
    );
  }

  String get formattedDuration {
    if (duration == null) return '';
    
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get callStatusText {
    if (!wasAnswered) {
      return isIncoming ? 'Appel manqué' : 'Appel non abouti';
    }
    
    if (duration != null && duration!.inSeconds > 0) {
      return formattedDuration;
    }
    
    return isIncoming ? 'Appel reçu' : 'Appel émis';
  }
}
