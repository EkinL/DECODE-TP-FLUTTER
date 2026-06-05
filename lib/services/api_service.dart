import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../helpers/exceptions.dart';
import 'storage_service.dart';

enum HttpMethod { get, post, put, delete }

class ApiService {
  // Permet de créer un singleton
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  final client = http.Client();
  final baseUrl = 'https://decode-api-3f85320eb5b9.herokuapp.com/v1';

  Future<T> request<T>({
    required String uri,
    HttpMethod httpMethod = .get,
    String? id,
    Map<String, dynamic>? data,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? parser,
  }) async {
    Uri url = Uri.parse('$baseUrl/$uri');

    if (id != null) {
      url = Uri.parse('$baseUrl/$uri/$id');
    }

    if (queryParams != null) {
      url = url.replace(queryParameters: queryParams);
    }

    String? token = await StorageService.get(StorageKey.token);

    if (kDebugMode) {
      print('${httpMethod.name.toUpperCase()} : $url');
    }
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response response;

    String? body = data != null ? jsonEncode(data) : null;

    try {
      switch (httpMethod) {
        case HttpMethod.post:
          response = await client.post(
            url,
            body: body,
            headers: headers,
          );
          break;
        case HttpMethod.put:
          response = await client.put(
            url,
            body: body,
            headers: headers,
          );
          break;
        case HttpMethod.delete:
          response = await client.delete(url, headers: headers);
          break;
        default:
          response = await client.get(url, headers: headers);
          break;
      }
    } on http.ClientException catch (e) {
      throw ApiException(httpStatus: 0, message: 'Erreur réseau: $e');
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      throw ApiException(httpStatus: 0, message: 'Erreur inattendue: $e');
    }

    if (kDebugMode) {
      //print(response.body);
    }

    switch (response.statusCode) {
      case HttpStatus.created:
      case HttpStatus.ok:
        if (response.body.isEmpty) {
          return null as T;
        }

        if (parser != null) {
          return parser(jsonDecode(response.body));
        }

        return jsonDecode(response.body);
      case HttpStatus.unprocessableEntity:
        throw ApiFieldsException.fromJson(jsonDecode(response.body));
      case HttpStatus.noContent:
        return null as T;
      default:
        throw ApiException(
          httpStatus: response.statusCode,
          message: response.body,
        );
    }
  }
}
