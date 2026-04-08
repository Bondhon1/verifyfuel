import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VerifyFuelApp());
}

const String _apiBaseUrlFromEnvironment = String.fromEnvironment(
  'API_BASE_URL',
);

String get apiBaseUrl {
  if (_apiBaseUrlFromEnvironment.isNotEmpty) {
    return _apiBaseUrlFromEnvironment;
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  // Android emulators reach the host machine via 10.0.2.2 instead of localhost.
  return 'http://10.0.2.2:8000';
}

class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String role;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      role: json['role'] as String,
    );
  }
}

class VehicleModel {
  final int id;
  final String plateNumber;
  final String? vehicleType;
  final String? make;
  final String? model;
  final int? year;

  const VehicleModel({
    required this.id,
    required this.plateNumber,
    this.vehicleType,
    this.make,
    this.model,
    this.year,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      plateNumber: json['plate_number'] as String,
      vehicleType: json['vehicle_type'] as String?,
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: json['year'] as int?,
    );
  }
}

class EligibilityModel {
  final bool isEligible;
  final String message;
  final String plateNumber;
  final int? hoursRemaining;
  final DateTime? nextSlotStart;
  final DateTime? nextSlotEnd;

  const EligibilityModel({
    required this.isEligible,
    required this.message,
    required this.plateNumber,
    this.hoursRemaining,
    this.nextSlotStart,
    this.nextSlotEnd,
  });

  factory EligibilityModel.fromJson(Map<String, dynamic> json) {
    return EligibilityModel(
      isEligible: json['is_eligible'] as bool,
      message: json['message'] as String,
      plateNumber: json['plate_number'] as String,
      hoursRemaining: json['hours_remaining'] as int?,
      nextSlotStart: json['next_slot_start'] != null
          ? DateTime.parse(json['next_slot_start'] as String)
          : null,
      nextSlotEnd: json['next_slot_end'] != null
          ? DateTime.parse(json['next_slot_end'] as String)
          : null,
    );
  }
}

class DashboardSummaryModel {
  final int totalVehicles;
  final int totalUsers;
  final int totalFuelEntries;
  final int todayFuelEntries;
  final int eligibleVehicles;
  final int deniedVehicles;

  const DashboardSummaryModel({
    required this.totalVehicles,
    required this.totalUsers,
    required this.totalFuelEntries,
    required this.todayFuelEntries,
    required this.eligibleVehicles,
    required this.deniedVehicles,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      totalVehicles: json['total_vehicles'] as int,
      totalUsers: json['total_users'] as int,
      totalFuelEntries: json['total_fuel_entries'] as int,
      todayFuelEntries: json['today_fuel_entries'] as int,
      eligibleVehicles: json['eligible_vehicles'] as int,
      deniedVehicles: json['denied_vehicles'] as int,
    );
  }
}

class FuelEntryModel {
  final int id;
  final int vehicleId;
  final int operatorId;
  final int amountLiters;
  final String fuelType;
  final DateTime entryDateTime;
  final DateTime nextSlotStart;
  final DateTime nextSlotEnd;

  const FuelEntryModel({
    required this.id,
    required this.vehicleId,
    required this.operatorId,
    required this.amountLiters,
    required this.fuelType,
    required this.entryDateTime,
    required this.nextSlotStart,
    required this.nextSlotEnd,
  });

  factory FuelEntryModel.fromJson(Map<String, dynamic> json) {
    return FuelEntryModel(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      operatorId: json['operator_id'] as int,
      amountLiters: json['amount_liters'] as int,
      fuelType: json['fuel_type'] as String,
      entryDateTime: DateTime.parse(json['entry_datetime'] as String),
      nextSlotStart: DateTime.parse(json['next_slot_start'] as String),
      nextSlotEnd: DateTime.parse(json['next_slot_end'] as String),
    );
  }
}

class OcrScanResult {
  final String plateNumber;
  final String rawText;
  final String provider;

  const OcrScanResult({
    required this.plateNumber,
    required this.rawText,
    required this.provider,
  });

  factory OcrScanResult.fromJson(Map<String, dynamic> json) {
    return OcrScanResult(
      plateNumber: (json['plate_number'] as String?) ?? '',
      rawText: (json['raw_text'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? 'unknown',
    );
  }
}

class ApiClient {
  final String? token;

  const ApiClient({this.token});

  Map<String, String> _jsonHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Never _throwApiError(http.Response response) {
    final decoded = _decodeBody(response);
    final detail = decoded is Map<String, dynamic>
        ? (decoded['detail']?.toString() ?? 'Unknown API error')
        : 'Unknown API error';
    throw Exception(detail);
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    final decoded = _decodeBody(response) as Map<String, dynamic>;
    return decoded['access_token'] as String;
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: _jsonHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'phone': phone,
        'full_name': fullName,
        'role': role,
      }),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
  }

  Future<UserProfile> getMe() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/me'),
      headers: _jsonHeaders(),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    return UserProfile.fromJson(_decodeBody(response) as Map<String, dynamic>);
  }

  Future<List<VehicleModel>> listVehicles() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/vehicles'),
      headers: _jsonHeaders(),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    final decoded = _decodeBody(response) as List<dynamic>;
    return decoded
        .map((item) => VehicleModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> addVehicle({
    required String plateNumber,
    String? vehicleType,
    String? make,
    String? model,
    int? year,
    int? ownerId,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/vehicles/'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'plate_number': plateNumber,
        'vehicle_type': vehicleType,
        'make': make,
        'model': model,
        'year': year,
        'owner_id': ownerId,
      }),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
  }

  Future<EligibilityModel> checkEligibility(String plateNumber) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/fuel/check-eligibility/${plateNumber.trim()}'),
      headers: _jsonHeaders(),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    return EligibilityModel.fromJson(
      _decodeBody(response) as Map<String, dynamic>,
    );
  }

  Future<void> scanAndRecordFuel({
    required String plateNumber,
    required int amountLiters,
    required String fuelType,
    String? stationName,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/fuel/scan-and-record'),
      headers: _jsonHeaders(),
      body: jsonEncode({
        'plate_number': plateNumber,
        'amount_liters': amountLiters,
        'fuel_type': fuelType,
        'station_name': stationName,
        'notes': notes,
      }),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
  }

  Future<OcrScanResult> scanPlateWithCloudOcr(Uint8List imageBytes) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/fuel/ocr/scan-plate'),
      headers: _jsonHeaders(),
      body: jsonEncode({'image_base64': base64Encode(imageBytes)}),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    return OcrScanResult.fromJson(
      _decodeBody(response) as Map<String, dynamic>,
    );
  }

  Future<DashboardSummaryModel> getDashboardSummary() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/fuel/dashboard/summary'),
      headers: _jsonHeaders(),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    return DashboardSummaryModel.fromJson(
      _decodeBody(response) as Map<String, dynamic>,
    );
  }

  Future<List<FuelEntryModel>> getFuelEntries() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/fuel/entries'),
      headers: _jsonHeaders(),
    );
    if (response.statusCode != 200) {
      _throwApiError(response);
    }
    final decoded = _decodeBody(response) as List<dynamic>;
    return decoded
        .map((item) => FuelEntryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class AppState {
  final bool isLoading;
  final String? token;
  final UserProfile? user;
  final String? error;

  const AppState({
    required this.isLoading,
    required this.token,
    required this.user,
    required this.error,
  });

  const AppState.initial()
    : isLoading = false,
      token = null,
      user = null,
      error = null;

  AppState copyWith({
    bool? isLoading,
    String? token,
    UserProfile? user,
    String? error,
    bool clearError = false,
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      user: user ?? this.user,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AppController extends ChangeNotifier {
  AppState _state = const AppState.initial();

  AppState get state => _state;

  AppController() {
    init();
  }

  static const _tokenKey = 'verifyfuel_token';

  void _update(AppState next) {
    _state = next;
    notifyListeners();
  }

  Future<void> init() async {
    _update(_state.copyWith(isLoading: true, clearError: true));
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    if (storedToken == null) {
      _update(_state.copyWith(isLoading: false, token: null, user: null));
      return;
    }

    final api = ApiClient(token: storedToken);
    try {
      final user = await api.getMe();
      _update(
        _state.copyWith(isLoading: false, token: storedToken, user: user),
      );
    } catch (_) {
      await prefs.remove(_tokenKey);
      _update(_state.copyWith(isLoading: false, token: null, user: null));
    }
  }

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    _update(_state.copyWith(isLoading: true, clearError: true));
    try {
      final token = await const ApiClient().login(
        username: username,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      final user = await ApiClient(token: token).getMe();
      _update(_state.copyWith(isLoading: false, token: token, user: user));
    } catch (e) {
      _update(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signUpAndSignIn({
    required String username,
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    _update(_state.copyWith(isLoading: true, clearError: true));
    try {
      await const ApiClient().register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        phone: phone,
      );
      await signIn(username: username, password: password);
    } catch (e) {
      _update(_state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _update(const AppState.initial());
  }

  void clearError() {
    _update(_state.copyWith(clearError: true));
  }
}

class VerifyFuelApp extends StatefulWidget {
  const VerifyFuelApp({super.key});

  @override
  State<VerifyFuelApp> createState() => _VerifyFuelAppState();
}

class _VerifyFuelAppState extends State<VerifyFuelApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;

        final seed = const Color(0xFF0E7A6A);
        final lightScheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          tertiary: const Color(0xFFF79B2E),
        );

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ভেরিফাইফুয়েল',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: lightScheme,
            textTheme: GoogleFonts.soraTextTheme(),
            scaffoldBackgroundColor: const Color(0xFFF2F6F8),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              color: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          home: state.isLoading
              ? const SplashView()
              : state.user == null
              ? AuthView(controller: _controller, state: state)
              : HomeShell(
                  user: state.user!,
                  token: state.token!,
                  controller: _controller,
                ),
        );
      },
    );
  }
}

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E7A6A), Color(0xFF2DAA9E), Color(0xFF8BD3CC)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_gas_station_rounded,
                size: 64,
                color: Colors.white,
              ),
              SizedBox(height: 14),
              Text(
                'VerifyFuel',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
              ),
              SizedBox(height: 12),
              CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthView extends StatefulWidget {
  final AppController controller;
  final AppState state;

  const AuthView({super.key, required this.controller, required this.state});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _loginUserController = TextEditingController();
  final _loginPassController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regUserController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPassController = TextEditingController();
  String _role = 'owner';
  bool _isSignInMode = true;

  @override
  void dispose() {
    _loginUserController.dispose();
    _loginPassController.dispose();
    _regNameController.dispose();
    _regUserController.dispose();
    _regEmailController.dispose();
    _regPhoneController.dispose();
    _regPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E7A6A), Color(0xFF2DAA9E), Color(0xFFE8F9F7)],
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Header
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_gas_station_rounded,
                            size: 56,
                            color: Color(0xFF0E7A6A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'VerifyFuel',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'স্বয়ংক্রিয় জ্বালানি ব্যবস্থাপনা সিস্টেম',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // Error Message
                    if (state.error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE8E6),
                          border: Border.all(
                            color: const Color(0xFFFF6B54),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFF6B54),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: const TextStyle(
                                  color: Color(0xFF7D3C27),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Show either Sign In or Sign Up page
                    _isSignInMode
                        ? _buildSignInPage(state, controller)
                        : _buildSignUpPage(state, controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPage(AppState state, AppController controller) {
    return _buildLoginCard(state, controller);
  }

  Widget _buildSignUpPage(AppState state, AppController controller) {
    return _buildRegisterCard(state, controller);
  }

  Widget _buildLoginCard(AppState state, AppController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F4F1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.login_rounded,
              color: Color(0xFF0E7A6A),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'লগইন',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'আপনার অ্যাকাউন্টে প্রবেশ করুন',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _loginUserController,
            decoration: InputDecoration(
              labelText: 'ব্যবহারকারীর নাম',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loginPassController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () => controller.signIn(
                      username: _loginUserController.text.trim(),
                      password: _loginPassController.text,
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0E7A6A),
                disabledBackgroundColor: Colors.blueGrey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'লগইন',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Link to Create Account
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _isSignInMode = false);
              },
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'অ্যাকাউন্ট নেই? ',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    TextSpan(
                      text: 'অ্যাকাউন্ট তৈরি করুন',
                      style: TextStyle(
                        color: Color(0xFF0E7A6A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterCard(AppState state, AppController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.app_registration_rounded,
              color: Color(0xFFF79B2E),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'অ্যাকাউন্ট তৈরি',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'জ্বালানি ব্যবস্থাপনা সিস্টেমে যোগ দিন',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blueGrey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _regNameController,
            decoration: InputDecoration(
              labelText: 'পূর্ণ নাম',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regUserController,
            decoration: InputDecoration(
              labelText: 'ব্যবহারকারীর নাম',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'ইমেইল',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'ফোন (ঐচ্ছিক)',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _regPassController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'পাসওয়ার্ড',
              labelStyle: const TextStyle(
                color: Color(0xFF0E7A6A),
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF5FFFE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blueGrey.shade200),
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: Colors.blueGrey.shade500,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5FFFE),
              border: Border.all(color: Colors.blueGrey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButton<String>(
              value: _role,
              items: const [
                DropdownMenuItem(
                  value: 'owner',
                  child: Text('🚗 গাড়ির মালিক'),
                ),
                DropdownMenuItem(
                  value: 'operator',
                  child: Text('⛽ পাম্প অপারেটর'),
                ),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'owner'),
              underline: const SizedBox(),
              isExpanded: true,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w600,
              ),
              dropdownColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: state.isLoading
                  ? null
                  : () => controller.signUpAndSignIn(
                      username: _regUserController.text.trim(),
                      email: _regEmailController.text.trim(),
                      password: _regPassController.text,
                      fullName: _regNameController.text.trim(),
                      role: _role,
                      phone: _regPhoneController.text.trim().isEmpty
                          ? null
                          : _regPhoneController.text.trim(),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF79B2E),
                disabledBackgroundColor: Colors.amber.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : const Text(
                      'অ্যাকাউন্ট তৈরি ও লগইন',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Link to Sign In
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() => _isSignInMode = true);
              },
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'আগে থেকেই অ্যাকাউন্ট আছে? ',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    TextSpan(
                      text: 'লগইন',
                      style: TextStyle(
                        color: Color(0xFFF79B2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final UserProfile user;
  final String token;
  final AppController controller;

  const HomeShell({
    super.key,
    required this.user,
    required this.token,
    required this.controller,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final int _index = 0;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(token: widget.token);
    final role = widget.user.role;
    final tabs = <Widget>[
      if (role == 'operator')
        OperatorDashboard(api: api, onSignOut: widget.controller.signOut),
      if (role == 'owner')
        OperatorDashboard(api: api, onSignOut: widget.controller.signOut),
      if (role == 'admin') AdminDashboard(api: api),
    ];

    final showAppBar = role == 'admin';

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('ভেরিফাইফুয়েল'),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Text(
                      '${widget.user.username} (${widget.user.role.toUpperCase()})',
                      style: TextStyle(color: Colors.blueGrey.shade700),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: widget.controller.signOut,
                ),
              ],
            )
          : null,
      body: tabs[_index],
    );
  }
}

class OperatorDashboard extends StatefulWidget {
  final ApiClient api;
  final VoidCallback? onSignOut;

  const OperatorDashboard({
    super.key,
    required this.api,
    this.onSignOut,
  });

  @override
  State<OperatorDashboard> createState() => _OperatorDashboardState();
}

class _OperatorDashboardState extends State<OperatorDashboard> {
  final _imagePicker = ImagePicker();
  final _plateCtrl = TextEditingController();
  final _litersCtrl = TextEditingController(text: '20');
  final _stationCtrl = TextEditingController(text: 'Main Pump');
  String _fuelType = 'Petrol';
  EligibilityModel? _eligibility;
  bool _loading = false;
  bool _scanning = false;

  bool get _busy => _loading || _scanning;

  @override
  void dispose() {
    _plateCtrl.dispose();
    _litersCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _plateCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _checkEligibility() async {
    setState(() => _loading = true);
    try {
      final result = await widget.api.checkEligibility(_plateCtrl.text.trim());
      setState(() => _eligibility = result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('যোগ্যতা যাচাই ব্যর্থ: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _recordFuel() async {
    setState(() => _loading = true);
    try {
      await widget.api.scanAndRecordFuel(
        plateNumber: _plateCtrl.text.trim(),
        amountLiters: int.tryParse(_litersCtrl.text.trim()) ?? 0,
        fuelType: _fuelType,
        stationName: _stationCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('জ্বালানি এন্ট্রি সংরক্ষিত হয়েছে এবং পরবর্তী সময়সূচি নির্ধারিত হয়েছে।'),
        ),
      );
      _checkEligibility();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('এন্ট্রি সংরক্ষণ ব্যর্থ: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _scanPlateFromCamera() async {
    setState(() => _scanning = true);
    try {
      final imageSource = kIsWeb ? ImageSource.gallery : ImageSource.camera;
      final pickedImage = await _imagePicker.pickImage(
        source: imageSource,
        imageQuality: 90,
        maxWidth: 1600,
        maxHeight: 1200,
      );

      if (pickedImage == null) {
        return;
      }

      await _processScannedImage(
        await pickedImage.readAsBytes(),
        sourceLabel: kIsWeb ? 'selected image' : 'camera image',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('স্ক্যান ব্যর্থ: $e। আপনি প্লেট নম্বর হাতে লিখতে পারেন।'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _processScannedImage(
    Uint8List imageBytes, {
    required String sourceLabel,
  }) async {
    String recognizedText = '';
    String plateText = '';
    var ocrSource = 'Google Vision';
    var usedLocalFallback = false;

    try {
      final cloudResult = await widget.api.scanPlateWithCloudOcr(imageBytes);
      recognizedText = cloudResult.rawText;
      plateText = cloudResult.plateNumber;
      ocrSource = 'Google Vision';
    } catch (_) {
      if (kIsWeb) {
        throw Exception('ব্যাকএন্ড থেকে Google Vision OCR পাওয়া যাচ্ছে না');
      }
      // Fall back to local OCR to keep scanning usable when cloud OCR is unavailable.
      recognizedText = await _recognizeTextFromImageBytes(imageBytes);
      plateText = _extractPlateText(recognizedText);
      ocrSource = 'Local OCR fallback';
      usedLocalFallback = true;
    }

    if (plateText.isEmpty && !usedLocalFallback && !kIsWeb) {
      final localRecognized = await _recognizeTextFromImageBytes(imageBytes);
      final localPlate = _extractPlateText(localRecognized);
      if (localPlate.isNotEmpty) {
        recognizedText = localRecognized;
        plateText = localPlate;
        ocrSource = 'Local OCR fallback';
      }
    }

    if (!mounted) return;

    if (plateText.isNotEmpty) {
      final previewText = recognizedText.replaceAll('\n', ' ');
      final preview = previewText.substring(
        0,
        previewText.length > 50 ? 50 : previewText.length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$sourceLabel ($ocrSource) থেকে শনাক্ত: $plateText\nটেক্সট: $preview...',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (plateText.isEmpty) {
      final previewText = recognizedText.replaceAll('\n', ' ');
      final preview = previewText.substring(
        0,
        previewText.length > 100 ? 100 : previewText.length,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$sourceLabel ($ocrSource)-এ কোনো প্লেট নম্বর পাওয়া যায়নি। টেক্সট: $preview',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _plateCtrl.text = plateText;
      _eligibility = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'প্লেট স্ক্যান হয়েছে: $plateText - প্রয়োজন হলে যাচাই করে সম্পাদনা করুন',
        ),
      ),
    );
  }

  Future<String> _recognizeTextFromImageBytes(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final width = image.width;
    final height = image.height;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    codec.dispose();

    if (byteData == null) {
      throw Exception('Could not decode the selected image.');
    }

    final inputImage = InputImage.fromBitmap(
      bitmap: byteData.buffer.asUint8List(),
      width: width,
      height: height,
    );

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      recognizer.close();
    }
  }

  /// Convert Bengali numerals to English numerals
  String _convertBengaliToEnglish(String text) {
    const bengaliToEnglish = {
      '০': '0',
      '১': '1',
      '২': '2',
      '৩': '3',
      '৪': '4',
      '৫': '5',
      '৬': '6',
      '৭': '7',
      '৮': '8',
      '৯': '9',
    };

    String result = text;
    bengaliToEnglish.forEach((bengali, english) {
      result = result.replaceAll(bengali, english);
    });
    return result;
  }

  /// Extract license plate number from OCR text
  /// Looks for pattern: XX-XXXX or XX-XXX (digits-digits)
  /// Converts Bengali numerals to English and filters out city/metro text
  String _extractPlateText(String rawText) {
    if (rawText.isEmpty) return '';

    // Convert Bengali numerals to English
    final converted = _convertBengaliToEnglish(rawText);

    // Split into lines to process separately
    final lines = converted.split('\n');

    // Look for line matching plate number pattern: 2-3 digits, hyphen, 3-4 digits
    final strictPattern = RegExp(r'\b(\d{2,3}[-]\d{3,4})\b');

    for (final line in lines) {
      final match = strictPattern.firstMatch(line);
      if (match != null) {
        return match.group(1)!.trim().toUpperCase();
      }
    }

    // Fallback 1: Look for any sequence with digits and hyphen (more lenient)
    final lenientPattern = RegExp(r'(\d+[-]\d+)');
    for (final line in lines) {
      final match = lenientPattern.firstMatch(line);
      if (match != null) {
        final candidate = match.group(1)!;
        // Validate it's reasonable length (at least 4 chars: XX-X)
        if (candidate.length >= 4) {
          return candidate.trim().toUpperCase();
        }
      }
    }

    // Fallback 2: Try to extract just digits and hyphens from any line with both
    for (final line in lines) {
      if (line.contains('-') && RegExp(r'\d').hasMatch(line)) {
        final digitsAndHyphen = line.replaceAll(RegExp(r'[^\d-]'), '');
        if (digitsAndHyphen.isNotEmpty &&
            digitsAndHyphen.contains('-') &&
            digitsAndHyphen.length >= 4) {
          return digitsAndHyphen.trim().toUpperCase();
        }
      }
    }

    // Fallback 3: Look for any numeric sequence (digits only, no hyphen required)
    final digitsOnly = RegExp(r'\d{4,}');
    for (final line in lines) {
      final match = digitsOnly.firstMatch(line);
      if (match != null) {
        final digits = match.group(0)!;
        // Try to format as XX-XXX or XX-XXXX if we have enough digits
        if (digits.length >= 5) {
          return '${digits.substring(0, 2)}-${digits.substring(2)}'
              .toUpperCase();
        }
      }
    }

    // Last resort: return cleaned text with Bengali converted (for manual correction)
    return converted.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final plateText = _plateCtrl.text.trim();

    return SafeArea(
      child: ColoredBox(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'VerifyFuel',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF404040),
                                letterSpacing: -0.7,
                                fontSize: 28,
                              ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'অ্যাকাউন্ট নাম',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF4E4E4E),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                          ),
                          Text(
                            'অপারেটর',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFF4E4E4E),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: const Color(0xFF5AB4A7),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: 'লগআউট',
                          onPressed: widget.onSignOut,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ScannerHeroCard(onScanPressed: _busy ? null : _scanPlateFromCamera),
                  const SizedBox(height: 18),
                  _DashboardPillField(
                    controller: _plateCtrl,
                    hintText: 'যানবাহনের প্লেট নম্বর লিখুন',
                    textColor: const Color(0xFF1F1F1F),
                    hintColor: const Color(0xFF2F2F2F),
                  ),
                  const SizedBox(height: 18),
                  _DashboardPillButton(
                    label: 'যোগ্যতা যাচাই',
                    onPressed: plateText.isEmpty || _loading ? null : _checkEligibility,
                  ),
                  const SizedBox(height: 56),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'পরিমাণ (লিটার)',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF9A9A9A),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _DashboardPillField(
                              controller: _litersCtrl,
                              hintText: '২০ লিটার',
                              textColor: const Color(0xFF1F1F1F),
                              hintColor: const Color(0xFF2F2F2F),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'জ্বালানির ধরন',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF9A9A9A),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            _DashboardPillDropdown(
                              value: _fuelType,
                              onChanged: (value) => setState(() => _fuelType = value ?? 'Petrol'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'স্টেশন নাম',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFC0C0C0),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _DashboardPillField(
                    controller: _stationCtrl,
                    hintText: 'মেইন পাম্প',
                    textColor: const Color(0xFF1F1F1F),
                    hintColor: const Color(0xFF2F2F2F),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _DashboardPillButton(
                      label: 'এন্ট্রি সংরক্ষণ',
                      onPressed: _loading ? null : _recordFuel,
                      width: 148,
                    ),
                  ),
                  if (_eligibility != null) ...[
                    const SizedBox(height: 20),
                    _EligibilityBanner(
                      eligibility: _eligibility!,
                      formatter: formatter,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerHeroCard extends StatelessWidget {
  final VoidCallback? onScanPressed;

  const _ScannerHeroCard({required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF5AB4A7),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onScanPressed,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white,
                  width: 1.6,
                ),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'অপারেটর স্ক্যানার',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'স্ক্যান করে প্লেট নম্বর ধরুন\nযোগ্যতা যাচাই করে এন্ট্রি দিন',
                  style: TextStyle(
                    color: Color(0xFFF4FFFD),
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPillField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color textColor;
  final Color hintColor;

  const _DashboardPillField({
    required this.controller,
    required this.hintText,
    required this.textColor,
    required this.hintColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5AB4A7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: hintColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _DashboardPillDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _DashboardPillDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF5AB4A7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        onChanged: onChanged,
        dropdownColor: const Color(0xFF5AB4A7),
        iconEnabledColor: const Color(0xFF1F1F1F),
        style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: const [
          DropdownMenuItem(value: 'Petrol', child: Text('পেট্রোল')),
          DropdownMenuItem(value: 'Diesel', child: Text('ডিজেল')),
          DropdownMenuItem(value: 'Octane', child: Text('অকটেন')),
        ],
      ),
    );
  }
}

class _DashboardPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;

  const _DashboardPillButton({
    required this.label,
    required this.onPressed,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF5AB4A7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );

    if (width == null) {
      return SizedBox(width: double.infinity, child: button);
    }

    return SizedBox(width: width, child: button);
  }
}

class _EligibilityBanner extends StatelessWidget {
  final EligibilityModel eligibility;
  final DateFormat formatter;

  const _EligibilityBanner({
    required this.eligibility,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final background = eligibility.isEligible
        ? const Color(0xFFE7F8F3)
        : const Color(0xFFFFF1E4);
    final accent = eligibility.isEligible
        ? const Color(0xFF11835A)
        : const Color(0xFFB85B1D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eligibility.isEligible ? 'যোগ্য' : 'অযোগ্য',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(eligibility.message),
          if (eligibility.hoursRemaining != null) ...[
            const SizedBox(height: 4),
            Text('বাকি সময়: ${eligibility.hoursRemaining} ঘণ্টা'),
          ],
          if (eligibility.nextSlotStart != null && eligibility.nextSlotEnd != null) ...[
            const SizedBox(height: 4),
            Text(
              'পরবর্তী স্লট: ${formatter.format(eligibility.nextSlotStart!.toLocal())} - ${formatter.format(eligibility.nextSlotEnd!.toLocal())}',
            ),
          ],
        ],
      ),
    );
  }
}

class OwnerDashboard extends StatefulWidget {
  final ApiClient api;

  const OwnerDashboard({super.key, required this.api});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final _plateCtrl = TextEditingController();
  final _typeCtrl = TextEditingController(text: 'Car');
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  Future<List<VehicleModel>>? _vehiclesFuture;
  EligibilityModel? _status;

  @override
  void initState() {
    super.initState();
    _reloadVehicles();
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _typeCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _reloadVehicles() {
    setState(() {
      _vehiclesFuture = widget.api.listVehicles();
    });
  }

  Future<void> _addVehicle() async {
    try {
      await widget.api.addVehicle(
        plateNumber: _plateCtrl.text.trim(),
        vehicleType: _typeCtrl.text.trim(),
        make: _makeCtrl.text.trim().isEmpty ? null : _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
        year: int.tryParse(_yearCtrl.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('যানবাহন সফলভাবে যোগ হয়েছে।')),
      );
      _reloadVehicles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('যানবাহন যোগ ব্যর্থ: $e')));
    }
  }

  Future<void> _checkStatus(String plateNumber) async {
    try {
      final result = await widget.api.checkEligibility(plateNumber);
      setState(() => _status = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('স্ট্যাটাস যাচাই ব্যর্থ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM, hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0E7A6A), Color(0xFF13A38E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E7A6A).withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.document_scanner_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'স্ক্যানার মোড',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'প্লেট স্ক্যান করে স্ট্যাটাস দেখুন এবং জ্বালানি অনুমতি পরিচালনা করুন।',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF0E7A6A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'যানবাহন মালিক কনসোল',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'যানবাহন যোগ করুন, প্লেট স্ক্যান করুন এবং রিয়েল-টাইমে যোগ্যতা দেখুন।',
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _plateCtrl,
                    decoration: InputDecoration(
                      labelText: 'প্লেট নম্বর',
                      prefixIcon: const Icon(Icons.pin_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'প্লেট স্ক্যান',
                        onPressed: () async {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'ক্যামেরা OCR-এর জন্য অপারেটর কনসোলের স্ক্যানার বোতাম ব্যবহার করুন।',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.document_scanner_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _typeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'যানবাহনের ধরন',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _yearCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'বছর'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _makeCtrl,
                          decoration: const InputDecoration(labelText: 'ব্র্যান্ড'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _modelCtrl,
                          decoration: const InputDecoration(labelText: 'মডেল'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _addVehicle,
                        icon: const Icon(Icons.add_road_rounded),
                        label: const Text('যানবাহন যোগ করুন'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _plateCtrl.text.trim().isEmpty
                            ? null
                            : () => _checkStatus(_plateCtrl.text.trim()),
                        icon: const Icon(Icons.query_stats_rounded),
                        label: const Text('স্ট্যাটাস দেখুন'),
                      ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _status!.isEligible
                            ? const Color(0xFFE8FAF5)
                            : const Color(0xFFFFF3E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_status!.message),
                          if (_status!.hoursRemaining != null)
                            Text(
                              'গণনা: ${_status!.hoursRemaining} ঘণ্টা বাকি',
                            ),
                          if (_status!.nextSlotStart != null &&
                              _status!.nextSlotEnd != null)
                            Text(
                              'পরবর্তী স্লট: ${formatter.format(_status!.nextSlotStart!.toLocal())} - ${formatter.format(_status!.nextSlotEnd!.toLocal())}',
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text(
                    'আমার যানবাহন',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<VehicleModel>>(
                    future: _vehiclesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'যানবাহন লোড ব্যর্থ: ${snapshot.error}',
                        );
                      }
                      final vehicles = snapshot.data ?? [];
                      if (vehicles.isEmpty) {
                        return const Text(
                          'এখনও কোনো যানবাহন নেই। উপরে প্রথমটি যোগ করুন।',
                        );
                      }
                      return Column(
                        children: vehicles
                            .map(
                              (vehicle) => Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.directions_car_filled_rounded,
                                    ),
                                  ),
                                  title: Text(vehicle.plateNumber),
                                  subtitle: Text(
                                    '${vehicle.vehicleType ?? 'যানবাহন'} • ${vehicle.make ?? ''} ${vehicle.model ?? ''}'
                                        .trim(),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
                                    onPressed: () =>
                                        _checkStatus(vehicle.plateNumber),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final ApiClient api;

  const AdminDashboard({super.key, required this.api});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<DashboardSummaryModel> _summaryFuture;
  late Future<List<FuelEntryModel>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _summaryFuture = widget.api.getDashboardSummary();
    _entriesFuture = widget.api.getFuelEntries();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM, hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          FutureBuilder<DashboardSummaryModel>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('ড্যাশবোর্ড লোড ব্যর্থ: ${snapshot.error}'),
                  ),
                );
              }
              final summary = snapshot.data!;
              return _KpiStrip(
                items: [
                  _KpiData(
                    title: 'যানবাহন',
                    value: '${summary.totalVehicles}',
                    icon: Icons.directions_car_filled_rounded,
                  ),
                  _KpiData(
                    title: 'ব্যবহারকারী',
                    value: '${summary.totalUsers}',
                    icon: Icons.group_rounded,
                  ),
                  _KpiData(
                    title: 'আজকের জ্বালানি',
                    value: '${summary.todayFuelEntries}',
                    icon: Icons.local_gas_station_rounded,
                  ),
                  _KpiData(
                    title: 'যোগ্য',
                    value: '${summary.eligibleVehicles}',
                    icon: Icons.verified_rounded,
                  ),
                  _KpiData(
                    title: 'অযোগ্য',
                    value: '${summary.deniedVehicles}',
                    icon: Icons.gpp_bad_rounded,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'অ্যাডমিন মনিটরিং',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () {
                          setState(_refresh);
                        },
                      ),
                    ],
                  ),
                  Text(
                    'দৈনিক জ্বালানি কার্যক্রমের কেন্দ্রীভূত পর্যবেক্ষণ।',
                    style: TextStyle(color: Colors.blueGrey.shade700),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<FuelEntryModel>>(
                    future: _entriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'এন্ট্রি লোড ব্যর্থ: ${snapshot.error}',
                        );
                      }
                      final entries = snapshot.data ?? [];
                      if (entries.isEmpty) {
                        return const Text('এখনও কোনো জ্বালানি এন্ট্রি নেই।');
                      }
                      return Column(
                        children: entries.take(20).map((entry) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE7F4F1),
                              child: Text('${entry.vehicleId}'),
                            ),
                            title: Text(
                              'যানবাহন আইডি ${entry.vehicleId} • ${entry.amountLiters}L ${entry.fuelType}',
                            ),
                            subtitle: Text(
                              'এন্ট্রি ${formatter.format(entry.entryDateTime.toLocal())}',
                            ),
                            trailing: Text(
                              formatter.format(entry.nextSlotStart.toLocal()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;

  const _KpiData({
    required this.title,
    required this.value,
    required this.icon,
  });
}

class _KpiStrip extends StatelessWidget {
  final List<_KpiData> items;

  const _KpiStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = width > 860
            ? (width - ((items.length - 1) * 10)) / items.length
            : (width - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => Container(
                  width: cardWidth,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE7F4F1),
                        child: Icon(item.icon, color: const Color(0xFF0E7A6A)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.value,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item.title,
                              style: TextStyle(color: Colors.blueGrey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
