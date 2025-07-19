import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/order_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/help_screen.dart';
import 'screens/help_center_screen.dart';
import 'screens/admin/add_product_screen.dart';
import 'utils/app_theme.dart';
import 'models/product.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    runApp(const MyApp());
    
  } catch (e, stackTrace) {
    // Do not show any error UI if initialization fails
    runApp(const SizedBox.shrink());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => ThemeProvider()),
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProxyProvider<ProductProvider, CartProvider>(
          create: (ctx) => CartProvider(Provider.of<ProductProvider>(ctx, listen: false)),
          update: (ctx, productProvider, previous) {
            final cartProvider = previous ?? CartProvider(productProvider);
            return cartProvider;
          },
        ),
        ChangeNotifierProxyProvider<ProductProvider, WishlistProvider>(
          create: (ctx) => WishlistProvider(Provider.of<ProductProvider>(ctx, listen: false)),
          update: (ctx, productProvider, previous) => WishlistProvider(productProvider),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, CartProvider, OrderProvider>(
          create: (ctx) => OrderProvider(),
          update: (ctx, authProvider, cartProvider, previous) {
            final orderProvider = previous ?? OrderProvider();
            return orderProvider;
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (ctx, themeProvider, _) => MaterialApp(
          title: 'Electronics Store',
          theme: themeProvider.themeData,
          debugShowCheckedModeBanner: false,
          routes: {
            '/help': (ctx) => const HelpCenterScreen(),
            '/add-product': (ctx) => const AddProductScreen(),
          },
          home: Builder(
            builder: (context) => Consumer<AuthProvider>(
              builder: (ctx, auth, _) => FutureBuilder(
                future: Future.wait([
                  auth.tryAutoLogin(),
                  SharedPreferences.getInstance(),
                ]),
                builder: (ctx, snapshot) {
                  if (snapshot.hasError) {
                    return Scaffold(
                      body: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Internet Connection Error',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please connect to the internet at least once to initialize the app.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Restart app
                                  main();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Get SharedPreferences instance
                  final prefs = snapshot.data?[1] as SharedPreferences?;
                  final isFirstLaunch = prefs != null && !prefs.containsKey('has_launched');
                  
                  // If it's first launch, show splash screen
                  if (isFirstLaunch) {
                    // Mark as launched
                    prefs?.setBool('has_launched', true);
                    return const SplashScreen();
                  }
                  
                  // If still loading, show splash screen
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }
                  
                  // If user is authenticated, go to home screen
                  if (auth.isAuth) {
                    // Ensure fresh data from Supabase
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final productProvider = Provider.of<ProductProvider>(context, listen: false);
                      productProvider.ensureFreshData();
                    });
                    
                    return WillPopScope(
                      onWillPop: () async => false,
                      child: const HomeScreen(),
                    );
                  }
                  
                  // If not authenticated, go to welcome screen
                  return const WelcomeScreen();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
