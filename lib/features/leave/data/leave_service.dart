import 'package:dio/dio.dart';

import '../../../core/config/api_routes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/network/api_responses.dart';
import '../../../core/storage/storage_service.dart';
import '../models/leave_status.dart';
import '../models/qr_scan_result.dart';

/// Estado de salida de la persona, escaneo de QR, motivos y confirmación de
/// la salida.
class LeaveService {
  final StorageService _storageService = StorageService();
  final LocationService _locationService;
  final ApiClient _apiClient = ApiClient();

  LeaveService({LocationService? locationService})
    : _locationService = locationService ?? LocationService();

  Dio get _dio => _apiClient.dio;

  //Obtiene los datos y el estado de salida del usuario autenticado
  //(el item se identifica por la sesión, no hace falta enviarlo)
  Future<LeaveStatus?> fetchLeaveStatus() async {
    final Response response;
    try {
      response = await _dio.get(
        ApiRoutes.leaveStatus,
        options: ApiResponses.acceptAnyStatus,
      );
    } catch (e) {
      return null;
    }
    ApiResponses.throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> responseData = response.data;

    // Sincroniza el nombre/token guardados localmente si cambiaron. Esto es
    // solo caché local: si el almacenamiento seguro falla por cualquier
    // motivo, no debe impedir que se muestre el estado de salida del usuario.
    try {
      final String? token = responseData['token'];
      final String? name = responseData['name'];
      final String? localToken = await _storageService.getToken();
      final String? localName = await _storageService.getName();
      if (token != null &&
          name != null &&
          (token != localToken || name != localName)) {
        await _storageService.updateData(token, name);
      }
    } catch (e) {
      // Se ignora: la información principal (isLeave, dateLeave, reason)
      // ya está disponible en responseData.
    }

    return LeaveStatus.fromJson(responseData);
  }

  //Envia el QR escaneado y devuelve la accion a realizar (mostrar motivos o retorno)
  //Lanza ApiRequestException con un mensaje claro si el servidor rechaza la
  //solicitud (QR vencido, sin cupo, etc.) o si falla la red.
  Future<QrScanResult> scanQr(String qrData) async {
    // Lanza LocationException si no hay una ubicación confiable.
    final location = await _locationService.capture();
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.qrScan,
        data: {'qrData': qrData, ...location.toJson()},
        options: ApiResponses.acceptAnyStatus,
      );
    } on DioException catch (e) {
      throw ApiResponses.networkError(e);
    }
    ApiResponses.throwIfUnauthorized(response);
    if (response.data is! Map<String, dynamic>) {
      throw ApiRequestException(
        'El servidor respondió de forma inesperada. Intenta nuevamente.',
      );
    }
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode != 200 || data['status'] == 1) {
      throw ApiResponses.responseError(
        response,
        'No se pudo procesar el código QR.',
      );
    }
    return QrScanResult.fromJson(data);
  }

  //Obtiene las razones de salida de un predio especifico
  Future<List<String>?> getReasons(String namePremise) async {
    final Response response;
    try {
      response = await _dio.get(
        ApiRoutes.premiseReasons(namePremise),
        options: ApiResponses.acceptAnyStatus,
      );
    } catch (e) {
      return null;
    }
    ApiResponses.throwIfUnauthorized(response);
    if (response.statusCode != 200) return null;
    return List<String>.from(response.data['reasons'] ?? []);
  }

  //Realiza la solicitud de salida del usuario. [leaveTicket] es el
  //comprobante que devuelve scanQr() al escanear (no el texto del QR).
  //Lanza ApiRequestException con el motivo exacto si falla (comprobante
  //vencido, límite de salidas alcanzado, error de red, etc.).
  Future<void> confirmLeave(
    String namePremise,
    String nameReason,
    String leaveTicket,
  ) async {
    final location = await _locationService.capture();
    final Response response;
    try {
      response = await _dio.post(
        ApiRoutes.leaves,
        data: {
          'leaveTicket': leaveTicket,
          'namePremise': namePremise,
          'nameReason': nameReason,
          ...location.toJson(),
        },
        options: ApiResponses.acceptAnyStatus,
      );
    } on DioException catch (e) {
      throw ApiResponses.networkError(e);
    }
    ApiResponses.throwIfUnauthorized(response);
    if (response.statusCode != 200) {
      throw ApiResponses.responseError(
        response,
        'No se pudo registrar la salida. Intenta nuevamente.',
      );
    }
  }
}
