import 'package:freezed_annotation/freezed_annotation.dart';

part 'health_status.freezed.dart';

/// Snapshot of `sys/health`.
@freezed
abstract class HealthStatus with _$HealthStatus {
  const factory HealthStatus({
    required bool initialized,
    required bool sealed,
    required bool standby,
    required String version,
    @Default('') String clusterName,
    @Default('') String clusterId,
    DateTime? serverTime,
  }) = _HealthStatus;

  factory HealthStatus.fromData(Map<String, dynamic> json) => HealthStatus(
    initialized: json['initialized'] as bool? ?? false,
    sealed: json['sealed'] as bool? ?? true,
    standby: json['standby'] as bool? ?? false,
    version: json['version'] as String? ?? 'unknown',
    clusterName: json['cluster_name'] as String? ?? '',
    clusterId: json['cluster_id'] as String? ?? '',
    serverTime: json['server_time_utc'] is num
        ? DateTime.fromMillisecondsSinceEpoch(
            (json['server_time_utc'] as num).toInt() * 1000,
            isUtc: true,
          )
        : null,
  );
}
