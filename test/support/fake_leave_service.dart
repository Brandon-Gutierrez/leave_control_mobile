import 'package:control_input_output/core/network/api_exceptions.dart';
import 'package:control_input_output/features/leave/data/leave_service.dart';
import 'package:control_input_output/features/leave/models/leave_reason.dart';
import 'package:control_input_output/features/leave/models/leave_status.dart';
import 'package:control_input_output/features/leave/models/qr_scan_result.dart';
import 'package:flutter/material.dart';

/// [LeaveService] de prueba: no toca la red ni el almacenamiento seguro,
/// así las pantallas se pueden probar de forma instantánea y determinista.
class FakeLeaveService implements LeaveService {
  Map<String, dynamic>? leaveStatusResponse;
  List<LeaveReasonOption>? reasonsResponse;

  FakeLeaveService({this.leaveStatusResponse, this.reasonsResponse});

  @override
  Future<LeaveStatus?> fetchLeaveStatus() async => leaveStatusResponse == null
      ? null
      : LeaveStatus.fromJson(leaveStatusResponse!);

  /// Último rango consultado y resultado que devuelve el fake.
  DateTimeRange? requestedRange;
  LeaveStat? rangeResponse = const LeaveStat(3, 45);

  @override
  Future<LeaveStat?> fetchRangeStats(DateTime from, DateTime to) async {
    requestedRange = DateTimeRange(start: from, end: to);
    return rangeResponse;
  }

  /// Detalle de salidas que devuelve el fake (por defecto, ninguna).
  List<LeaveDetail>? detailsResponse = const [];

  @override
  Future<List<LeaveDetail>?> fetchLeaveDetails(
    DateTime from,
    DateTime to,
  ) async => detailsResponse;

  @override
  Future<List<LeaveReasonOption>?> getReasons(String namePremise) async =>
      reasonsResponse;

  /// Motivo con el que se pidió registrar la salida, y error a simular.
  String? confirmedReason;
  ApiRequestException? confirmError;

  @override
  Future<void> confirmLeave(
    String namePremise,
    String nameReason,
    String qrData,
  ) async {
    confirmedReason = nameReason;
    if (confirmError != null) throw confirmError!;
  }

  @override
  Future<QrScanResult> scanQr(String qrData) async => const QrScanResult(
    message: '',
    action: null,
    leaveTicket: null,
    leaveTicketExpiresAt: null,
  );
}
