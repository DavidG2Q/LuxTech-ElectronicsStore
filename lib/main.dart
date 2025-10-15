import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/voice_assistant_service.dart';
import 'services/product_service.dart';
import 'theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'providers/cart_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/user_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

// Add this function to fetch config from Gist
Future<Map<String, String>> fetchSupabaseConfig() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    // Try remote fetch
    final response = await http.get(
      Uri.parse('https://api.github.com/gists/69508f28abff5f5c93f92a73a0534732'),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode == 200) {
      final gistData = json.decode(response.body);
      final configContent = gistData['files']['config.json']['content'];
      // Try to parse as JSON first
      try {
        final configJson = json.decode(configContent);
        final url = configJson['url'] ?? configJson['supabaseUrl'];
        final anonKey = configJson['anonKey'] ?? configJson['supabaseAnonKey'];
        if (url != null && anonKey != null) {
          await prefs.setString('supabase_url', url);
          await prefs.setString('supabase_anon_key', anonKey);
          print('Fetched and cached Supabase config from remote (JSON).');
          return {'url': url, 'anonKey': anonKey};
        }
      } catch (_) {
        // Fallback to line-based parsing
        final lines = configContent.split('\n');
        String? url;
        String? anonKey;
        for (var line in lines) {
          if (line.contains('url:')) url = line.split("'")[1].trim();
          if (line.contains('anonKey:')) anonKey = line.split("'")[1].trim();
        }
        if (url != null && anonKey != null) {
          await prefs.setString('supabase_url', url);
          await prefs.setString('supabase_anon_key', anonKey);
          print('Fetched and cached Supabase config from remote (lines).');
          return {'url': url, 'anonKey': anonKey};
        }
      }
    }
    throw Exception('Could not fetch remote config');
  } catch (e) {
    print('Error fetching config: $e');
    // Try to load from cache
    final url = prefs.getString('supabase_url');
    final anonKey = prefs.getString('supabase_anon_key');
    if (url != null && anonKey != null) {
      print('Loaded Supabase config from cache.');
      return {'url': url, 'anonKey': anonKey};
    }
    // If not found, show a user-friendly error
    throw Exception(
      'Supabase credentials not found. Please connect to the internet at least once to initialize the app.'
    );
  }
}

void main() async {
  try {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();
    print('Starting app initialization...');
    // Fetch config from Gist
    print('Fetching Supabase config...');
    final config = await fetchSupabaseConfig();
    // Initialize Supabase with fetched credentials
    print('Initializing Supabase...');
    await Supabase.initialize(
      url: config['url']!,
      anonKey: config['anonKey']!,
    );
    print('Supabase initialized successfully');
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('Running app...');
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProxyProvider<CartProvider, ProductService>(
            create: (_) => ProductService(),
            update: (_, cartProvider, previousService) {
              final service = previousService ?? ProductService();
              service.setCartProvider(cartProvider);
              return service;
            },
          ),
          ChangeNotifierProvider(create: (_) => VoiceAssistantService()),
          ChangeNotifierProvider(create: (_) => WishlistProvider()),
          ChangeNotifierProvider(create: (_) => OrdersProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const ElectronicsStoreApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Do not show any error UI if initialization fails
    runApp(const SizedBox.shrink());
  }
}

class ElectronicsStoreApp extends StatelessWidget {
  const ElectronicsStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Electronics Store for Visually Impaired',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      builder: (context, child) {
        final voiceService = Provider.of<VoiceAssistantService>(
          context,
          listen: false,
        );
        final productService = Provider.of<ProductService>(
          context,
          listen: false,
        );

        // Listen to error streams
        voiceService.errorStream.listen((error) {
          _showErrorSnackBar(context, error);
        });

        productService.errorStream.listen((error) {
          _showErrorSnackBar(context, error);
        });

        // Wrap the child with error boundary
        return ErrorBoundary(child: child!);
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Error? _error;

  @override
  void initState() {
    super.initState();
    // Set up error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      setState(() {
        _error = details.exception as Error?;
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'An error occurred',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                      });
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
