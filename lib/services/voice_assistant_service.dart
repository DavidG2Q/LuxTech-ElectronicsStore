import 'dart:developer';
import 'package:electronic_store/providers/cart_provider.dart';
import 'package:electronic_store/providers/orders_provider.dart';
import 'package:electronic_store/providers/user_provider.dart';
import 'package:electronic_store/screens/cart_screen.dart';
import 'package:electronic_store/screens/checkout_screen.dart';
import 'package:electronic_store/screens/wishlist_screen.dart';
import 'package:electronic_store/services/product_service.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart'
    as stt
    show SpeechRecognitionResult;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

// Global navigator key to access context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

enum VoiceCommandType {
  navigation,
  search,
  selectCategory,
  selectProduct,
  setQuantity,
  addToCart,
  addToWishlist,
  removeFromCart,
  editQuantity,
  checkout,
  readDetails,
  readAgain,
  back,
  help,
  confirm,
  deny,
  unknown,
  textFieldUpdate,
  buttonTap,
}

class VoiceCommand {
  final VoiceCommandType type;
  final String rawText;
  final Map<String, dynamic> parameters;

  const VoiceCommand({
    required this.type,
    required this.rawText,
    this.parameters = const {},
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceCommand &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          rawText == other.rawText &&
          mapEquals(parameters, other.parameters);

  @override
  int get hashCode => Object.hash(type, rawText, parameters);
}

class ShoppingState {
  String? selectedCategory;
  String? selectedProduct;
  int quantity;
  bool waitingForQuantity;
  bool waitingForMoreProducts;
  bool isReadingDescription;
  bool waitingForProductSelection;

  ShoppingState({
    this.selectedCategory,
    this.selectedProduct,
    this.quantity = 1,
    this.waitingForQuantity = false,
    this.waitingForMoreProducts = false,
    this.isReadingDescription = false,
    this.waitingForProductSelection = false,
  });

  ShoppingState copyWith({
    String? selectedCategory,
    String? selectedProduct,
    int? quantity,
    bool? waitingForQuantity,
    bool? waitingForMoreProducts,
    bool? isReadingDescription,
    bool? waitingForProductSelection,
  }) {
    return ShoppingState(
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      quantity: quantity ?? this.quantity,
      waitingForQuantity: waitingForQuantity ?? this.waitingForQuantity,
      waitingForMoreProducts:
          waitingForMoreProducts ?? this.waitingForMoreProducts,
      isReadingDescription: isReadingDescription ?? this.isReadingDescription,
      waitingForProductSelection:
          waitingForProductSelection ?? this.waitingForProductSelection,
    );
  }

  ShoppingState reset() {
    return ShoppingState();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingState &&
          runtimeType == other.runtimeType &&
          selectedCategory == other.selectedCategory &&
          selectedProduct == other.selectedProduct &&
          quantity == other.quantity &&
          waitingForQuantity == other.waitingForQuantity &&
          waitingForMoreProducts == other.waitingForMoreProducts &&
          isReadingDescription == other.isReadingDescription &&
          waitingForProductSelection == other.waitingForProductSelection;

  @override
  int get hashCode => Object.hash(
    selectedCategory,
    selectedProduct,
    quantity,
    waitingForQuantity,
    waitingForMoreProducts,
    isReadingDescription,
    waitingForProductSelection,
  );
}

class VoiceAssistantService extends ChangeNotifier {
  static const String idleMessage = "Are you still there? How can I assist you?";
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final _commandController = StreamController<VoiceCommand>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastWords = '';
  VoiceCommand? _lastCommand;
  ShoppingState _shoppingState = ShoppingState();
  Timer? _speechTimeoutTimer;
  Timer? _speakDelayTimer;
  String _lastSpokenPhrase = '';
  int _commandCount = 0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get lastWords => _lastWords;
  VoiceCommand? get lastCommand => _lastCommand;
  ShoppingState get shoppingState => _shoppingState;
  Stream<VoiceCommand> get commandStream => _commandController.stream;
  Stream<String> get errorStream => _errorController.stream;

  VoiceAssistantService() {
    _initSpeech();
    _initTts();
  }

  @override
  void dispose() {
    _speechTimeoutTimer?.cancel();
    _speakDelayTimer?.cancel();
    _commandController.close();
    _errorController.close();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _isInitialized = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: (error) => _handleSpeechError(error.errorMsg),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize speech recognition: $e');
    }
  }

  void _handleSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      _speechTimeoutTimer?.cancel();
      notifyListeners();
    }
  }

  void _handleSpeechError(String error) {
    _isListening = false;
    // Only log the error, don't show it to the user
    debugPrint('Speech recognition error: $error');
    notifyListeners();
  }

  void _handleError(String error) {
    // Only log errors, don't show them to the user
    debugPrint(error);
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.3); // Changed from 0.5 to 0.3 for slower, clearer speech
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        notifyListeners();
      });
    } catch (e) {
      _handleError('Failed to initialize text-to-speech: $e');
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      await _initSpeech();
    }

    if (_isInitialized && !_isListening) {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('Microphone permission is required for voice commands');
        return;
      }

      _lastWords = '';
      _lastCommand = null;

      if (_isSpeaking) {
        await stopSpeaking();
      }

      try {
        bool? result = await _speech.listen(
          onResult: _handleSpeechResult,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
          cancelOnError: false,
          partialResults: true,
        );

        _isListening = result ?? false;

        if (_isListening) {
          _speechTimeoutTimer?.cancel();
          _speechTimeoutTimer = Timer(const Duration(seconds: 10), () {
            if (_isListening) {
              stopListening();
            }
          });
        }

        notifyListeners();
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('Failed to start listening: $e');
        _isListening = false;
        notifyListeners();
      }
    }
  }

  void _handleSpeechResult(stt.SpeechRecognitionResult result) {
    _lastWords = result.recognizedWords;
    if (result.finalResult) {
      _parseCommand(_lastWords);
    }
    notifyListeners();
  }

  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
        _isListening = false;
        _speechTimeoutTimer?.cancel();
        notifyListeners();
        HapticFeedback.mediumImpact();
      } catch (e) {
        _handleError('Failed to stop listening: $e');
      }
    }
  }

  Future<void> speakAfterDelay(
    String text, {
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    _speakDelayTimer?.cancel();
    _speakDelayTimer = Timer(delay, () {
      speak(text);
      log("Speaking after delay: $text");
    });
  }

  Future<void> speak(String text) async {
    if (_isListening) {
      await stopListening();
    }

    try {
      _lastSpokenPhrase = text;
      _isSpeaking = true;
      notifyListeners();
      await _flutterTts.speak(text);
    } catch (e) {
      _handleError('Failed to speak: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  // Method to speak product details and store them for "read again"
  Future<void> speakProductDetails(String productDetails) async {
    _lastSpokenPhrase = productDetails;
    await speak(productDetails);
  }

  // Method to update the last spoken phrase for "read again" functionality
  void updateLastSpokenPhrase(String phrase) {
    _lastSpokenPhrase = phrase;
  }

  // Enhanced method for reading product details sequentially
  Future<void> readProductDetailsSequentially({
    required String productName,
    required double price,
    required String description,
    List<String> features = const [],
  }) async {
    // Stop any current speech
    if (_isSpeaking) {
      await stopSpeaking();
    }

    // Prepare complete details for reading
    List<String> detailSegments = [
      'Product details:',
      productName,
      'Price: ${price.toStringAsFixed(2)} Egyptian Pounds',
      'Description: $description',
    ];

    // Add features if available
    if (features.isNotEmpty) {
      detailSegments.add('Features:');
      for (int i = 0; i < features.length; i++) {
        detailSegments.add('Feature ${i + 1}: ${features[i]}');
      }
    }

    // Add instruction about "read again" command
    detailSegments.add('Say "read again" to repeat this information.');

    // Store complete details for "read again" functionality
    String completeDetails = detailSegments.join(' ');
    await speakProductDetails(completeDetails);
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      _handleError('Failed to stop speaking: $e');
    }
  }

  BuildContext? get _safeContext {
    if (navigatorKey.currentContext != null) {
      return navigatorKey.currentContext!;
    } else if (navigatorKey.currentState?.context != null) {
      return navigatorKey.currentState!.context;
    }
    return null;
  }

  // Navigate to cart method
  void navigateToCart() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) => CartScreen()),
      );
      speakAfterDelay("Opening your cart");
    } else {
      final context = _safeContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => CartScreen()));
        speakAfterDelay("Opening your cart");
      } else {
        speakAfterDelay(
          "I couldn't open the cart right now. Please try again.",
        );
        _handleError('Failed to navigate to cart: Navigator key not available');
      }
    }
  }

  // Navigate to checkout method
  void navigateToCheckout() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) => const CheckoutScreen()),
      );
      speakAfterDelay("Opening checkout");
    } else {
      final context = _safeContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const CheckoutScreen()));
        speakAfterDelay("Opening checkout");
      } else {
        speakAfterDelay(
          "I couldn't open checkout right now. Please try again.",
        );
        _handleError('Failed to navigate to checkout: Navigator key not available');
      }
    }
  }

  void navigateToWishlist() {
    if (navigatorKey.currentState != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) => const WishlistScreen()),
      );
      speakAfterDelay("Opening your wishlist");
    } else {
      final context = _safeContext;
      if (context != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const WishlistScreen()));
        speakAfterDelay("Opening your wishlist");
      } else {
        speakAfterDelay(
          "I couldn't open the wishlist right now. Please try again.",
        );
        _handleError(
          'Failed to navigate to wishlist: Navigator key not available',
        );
      }
    }
  }

  bool _isCurrentlyOnCartPage() {
    final context = _safeContext;
    if (context == null) return false;

    // Check if the current route is the cart screen
    bool isCartPage = false;
    Navigator.of(context).popUntil((route) {
      isCartPage =
          route.settings.name == '/cart' ||
          route.settings.name == 'cart_screen' ||
          route is MaterialPageRoute && route.builder(context) is CartScreen;
      return true; // Don't actually pop any routes
    });

    return isCartPage;
  }

  void _completeCheckout() {
    final context = _safeContext;
    if (context == null) {
      speakAfterDelay("I couldn't complete your order. Please try again.");
      return;
    }

    try {
      // Access the cart, orders and user providers
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // If the cart is empty, inform the user
      if (cartProvider.items.isEmpty) {
        speakAfterDelay("Your cart is empty. Please add items before checking out.");
        return;
      }

      // Get user profile address
      final userProfile = userProvider.userProfile;
      if (userProfile == null) {
        speakAfterDelay("Could not find your delivery address. Please update your profile first.");
        return;
      }

      // Construct full address from profile
      final deliveryAddress = '${userProfile.street}, ${userProfile.building}, ${userProfile.city}';

      // Add order to OrdersProvider with user's address
      ordersProvider.addOrder(
        cartProvider.items
            .map((item) => OrderItem(
                  id: item.id,
                  name: item.name,
                  price: item.price,
                  quantity: item.quantity,
                ))
            .toList(),
        cartProvider.totalAmount,
        deliveryAddress,
      );

      // Clear the cart after adding to orders
      cartProvider.clear();

      // Provide confirmation to the user
      speakAfterDelay("Order completed successfully. Thank you for shopping with us!");

      // Navigate back to home after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } catch (e) {
      _handleError('Failed to complete checkout: $e');
      speakAfterDelay("There was a problem completing your order. Please try again.");
    }
  }

  void _parseCommand(String text) {
    final lowerText = text.toLowerCase().trim();
    debugPrint("Voice Command Received: '$lowerText'");

    // Handle "again" or "repeat" command first
    if (lowerText == 'again' || lowerText == 'repeat') {
      if (_lastSpokenPhrase.isNotEmpty) {
        speak(_lastSpokenPhrase);
      } else {
        speak("I haven't said anything yet to repeat.");
      }
      _lastCommand = VoiceCommand(
        type: VoiceCommandType.unknown,
        rawText: text,
        parameters: {'action': 'repeat'},
      );
      _commandController.add(_lastCommand!);
      notifyListeners();
      return;
    }

    // Handle "read again" command for product details
    if (lowerText == 'read again' || lowerText == 'read details again' || 
        lowerText == 'repeat details' || lowerText == 'repeat product details') {
      if (_lastSpokenPhrase.isNotEmpty) {
        speak(_lastSpokenPhrase);
        _lastCommand = VoiceCommand(
          type: VoiceCommandType.readAgain,
          rawText: text,
          parameters: {'action': 'read_product_details_again'},
        );
        _commandController.add(_lastCommand!);
        notifyListeners();
        return;
      } else {
        speak("No details to repeat.");
        return;
      }
    }

    // Handle "checkout" command - navigate to checkout screen
    if (lowerText == 'checkout' || lowerText == 'go to checkout' || 
        lowerText == 'proceed to checkout' || lowerText == 'check out') {
      debugPrint("Checkout command detected: '$lowerText'");
      _lastCommand = VoiceCommand(
        type: VoiceCommandType.checkout,
        rawText: text,
        parameters: {'action': 'navigate_to_checkout'},
      );
      _commandController.add(_lastCommand!);
      notifyListeners();
      return;
    }

    // Handle "confirm" command
    if (lowerText == 'confirm' || lowerText == 'confirm order' || 
        lowerText == 'place order') {
      _lastCommand = VoiceCommand(
        type: VoiceCommandType.confirm,
        rawText: text,
        parameters: {'action': 'confirm_order'},
      );
      _commandController.add(_lastCommand!);
      notifyListeners();
      return;
    }

    // Handle "delete product X" command
    final deleteProductMatch = RegExp(
      r'^delete\s+product\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)$',
    ).firstMatch(lowerText);
    if (deleteProductMatch != null) {
      String numberStr = deleteProductMatch.group(1)?.toLowerCase() ?? '';
      int? productNumber;

      if (RegExp(r'^\d+$').hasMatch(numberStr)) {
        productNumber = int.tryParse(numberStr);
      } else {
        productNumber = _convertWordToNumber(numberStr);
      }

      if (productNumber != null && productNumber > 0) {
        _lastCommand = VoiceCommand(
          type: VoiceCommandType.removeFromCart,
          rawText: text,
          parameters: {
            'productIndex': productNumber - 1,
            'byNumber': true,
          },
        );
        _commandController.add(_lastCommand!);
        notifyListeners();
        return;
      }
    }

    final context = _safeContext;
    if (context != null) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute == '/home') {
        final productService = Provider.of<ProductService>(
          context,
          listen: false,
        );
        _shoppingState.reset();
        readCategoriesList(
          productService.categories.map((category) => category.name).toList(),
        );
      }
    }

    if (lowerText == 'cart') {
      try {
        navigateToCart();
        _lastCommand = VoiceCommand(
          type: VoiceCommandType.navigation,
          rawText: text,
          parameters: {'destination': 'cart'},
        );
        _commandController.add(_lastCommand!);
        notifyListeners();
        return;
      } catch (e) {
        _handleError('Error handling cart command: $e');
      }
    }

    // Fast path for payment command
    if (lowerText == 'pay' ||
        lowerText == 'pay now' ||
        lowerText == 'complete order') {
      // Only process if we're on the cart page
      if (_isCurrentlyOnCartPage()) {
        _completeCheckout();
        _lastCommand = VoiceCommand(
          type: VoiceCommandType.checkout,
          rawText: text,
          parameters: {'action': 'complete'},
        );
        _commandController.add(_lastCommand!);
        notifyListeners();
        return;
      } else {
        // If not on cart, guide the user
        speakAfterDelay(
          "Please go to your cart first by saying 'cart', then say 'pay' to complete your order.",
        );
      }
    }

    // Fast path for "add product X" patterns
    final addProductMatch = RegExp(
      r'^add\s+product\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)$',
    ).firstMatch(lowerText);
    if (addProductMatch != null) {
      String numberStr = addProductMatch.group(1)?.toLowerCase() ?? '';
      int? productNumber;

      if (RegExp(r'^\d+$').hasMatch(numberStr)) {
        productNumber = int.tryParse(numberStr);
      } else {
        productNumber = _convertWordToNumber(numberStr);
      }

      if (productNumber != null && productNumber > 0) {
        debugPrint("Fast path: Adding product $productNumber");
        _processProductSelection(productNumber - 1, text);
        _commandController.add(_lastCommand!);
        notifyListeners();
        return;
      }
    }

    final command = _createCommand(lowerText, text);
    if (command != null) {
      _lastCommand = command;
      _commandController.add(command);
      notifyListeners();

      // Increment command count and reset after 5 commands
      _commandCount++;
      if (_commandCount >= 5) {
        // Save the current command before resetting state
        final savedCommand = command;

        // Reset the shopping state
        updateShoppingState(_shoppingState.reset());
        _commandCount = 0;
        debugPrint("Assistant state reset after 5 commands.");

        // Re-process the command after reset to ensure it's executed
        _lastCommand = savedCommand;
        _commandController.add(savedCommand);
        notifyListeners();

        // Note: Not clearing the last command so it can be processed
      }
    }
  }

  VoiceCommand? _createCommand(String lowerText, String originalText) {
    if (lowerText.contains('help') || lowerText.contains('what can i say')) {
      return VoiceCommand(type: VoiceCommandType.help, rawText: originalText);
    }

    if (lowerText.contains('back') ||
        lowerText.contains('go back') ||
        lowerText.contains('return')) {
      updateShoppingState(_shoppingState.reset());
      speakAfterDelay("Going back.");
      return VoiceCommand(type: VoiceCommandType.back, rawText: originalText);
    }
    if (lowerText.contains('select category') ||
        lowerText.contains('choose category') ||
        lowerText.contains('pick category') ||
        lowerText.contains('open category')) {
      // First try to extract category by name
      final categoryName = _extractCategoryName(lowerText);
      if (categoryName.isNotEmpty) {
        return VoiceCommand(
          type: VoiceCommandType.selectCategory,
          rawText: originalText,
          parameters: {'categoryName': categoryName},
        );
      }

      // If no name was found, try to extract category by number
      final categoryIndexMatch = RegExp(
        r'(?:select|choose|pick|open)\s+category\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)',
      ).firstMatch(lowerText);

      if (categoryIndexMatch != null) {
        String numberStr = categoryIndexMatch.group(1)?.toLowerCase() ?? '';
        int? categoryNumber;

        if (RegExp(r'^\d+$').hasMatch(numberStr)) {
          categoryNumber = int.tryParse(numberStr);
        } else {
          categoryNumber = _convertWordToNumber(numberStr);
        }

        if (categoryNumber != null && categoryNumber > 0) {
          // Get the context to access product service
          final context = _safeContext;
          if (context != null) {
            try {
              final productService = Provider.of<ProductService>(
                context,
                listen: false,
              );

              // Validate category index
              if (categoryNumber <= productService.categories.length) {
                // Get category name from index (converted to 0-based)
                final selectedCategory =
                    productService.categories[categoryNumber - 1].id;

                // Update shopping state with selected category
                updateShoppingState(
                  _shoppingState.copyWith(selectedCategory: selectedCategory),
                );

                // Speak confirmation
                speakAfterDelay(
                  "Opening ${productService.categories[categoryNumber - 1].name} category",
                );

                return VoiceCommand(
                  type: VoiceCommandType.selectCategory,
                  rawText: originalText,
                  parameters: {
                    'categoryIndex': categoryNumber - 1,
                    'byNumber': true,
                    'categoryId': selectedCategory,
                  },
                );
              } else {
                speakAfterDelay(
                  "Category $categoryNumber doesn't exist. Please try another category.",
                );
              }
            } catch (e) {
              _handleError('Error processing category selection: $e');
              speakAfterDelay(
                "I couldn't find that category. Please try again.",
              );
            }
          } else {
            speakAfterDelay(
              "I couldn't access the categories at the moment. Please try again.",
            );
          }
        }
      }
    }

    if (lowerText.contains('my profile') ||
        lowerText.contains('open profile') ||
        lowerText == 'profile') {
      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'profile'},
      );
    }

    if (lowerText.contains('my wishlist') ||
        lowerText.contains('view wishlist') ||
        lowerText.contains('show wishlist') ||
        lowerText.contains('open wishlist') ||
        lowerText.contains('my useless') ||
        lowerText == 'wishlist') {
      navigateToWishlist();
      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'wishlist'},
      );
    }

    if (lowerText.contains('my orders') ||
        lowerText.contains('view orders') ||
        lowerText.contains('show orders') ||
        lowerText.contains('open orders') ||
        lowerText == 'orders') {
      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'orders'},
      );
    }

    final productIndexMatch = RegExp(
      r'product\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)',
    ).firstMatch(lowerText);
    if (productIndexMatch != null && _shoppingState.selectedCategory != null) {
      String numberStr = productIndexMatch.group(1)?.toLowerCase() ?? '';
      int? productNumber;
      if (RegExp(r'^\d+$').hasMatch(numberStr)) {
        productNumber = int.tryParse(numberStr);
      } else {
        productNumber = _convertWordToNumber(numberStr);
      }
      if (productNumber != null && productNumber > 0) {
        return VoiceCommand(
          type: VoiceCommandType.selectProduct,
          rawText: originalText,
          parameters: {
            'productIndex': productNumber - 1,
            'byNumber': true,
            'openDetails': true,
          },
        );
      }
    }

    final openProductMatch = RegExp(
      r'^(open|view|show)\s+product\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten)$',
    ).firstMatch(lowerText);

    if (openProductMatch != null) {
      String numberStr = openProductMatch.group(2)?.toLowerCase() ?? '';
      int? productNumber;

      if (RegExp(r'^\d+$').hasMatch(numberStr)) {
        productNumber = int.tryParse(numberStr);
      } else {
        productNumber = _convertWordToNumber(numberStr);
      }

      if (productNumber != null && productNumber > 0) {
        return VoiceCommand(
          type: VoiceCommandType.selectProduct,
          rawText: originalText,
          parameters: {
            'productIndex': productNumber - 1,
            'byNumber': true,
            'openDetails': true,
          },
        );
      }
    }

    if (_isButtonTapCommand(lowerText)) {
      final actionName = _extractActionName(lowerText);
      if (actionName.isNotEmpty) {
        return VoiceCommand(
          type: VoiceCommandType.buttonTap,
          rawText: originalText,
          parameters: {'actionName': actionName},
        );
      }
    }

    if (lowerText.contains('go to home') ||
        lowerText.contains('go home') ||
        lowerText.contains('home')) {
      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'home'},
      );
    }

    if (lowerText.contains('go to categories') ||
        lowerText.contains('show categories') ||
        lowerText.contains('categories')) {
      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'categories'},
      );
    }

    if (lowerText.contains('go to cart') ||
        lowerText.contains('show cart') ||
        lowerText.contains('view cart') ||
        lowerText.contains('open cart') ||
        lowerText.contains('see cart') ||
        lowerText == 'cart' || // Exact match for just "cart"
        (lowerText.contains('cart') && lowerText.split(' ').length <= 2)) {
      try {
        navigateToCart();
      } catch (e) {
        _handleError('Error navigating to cart: $e');
      }

      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'cart'},
      );
    }

    // Remove the old checkout handling from here since it's now handled in _parseCommand

    if (lowerText.contains('my cart') ||
        lowerText.contains('my court') ||
        lowerText.contains('michael') ||
        lowerText.contains('my god')||lowerText.contains('my kart') || lowerText.contains('my card')
        )  {
      try {
        navigateToCart();
        speakAfterDelay("Opening your cart");
      } catch (e) {
        _handleError('Error navigating to cart: $e');
      }

      return VoiceCommand(
        type: VoiceCommandType.navigation,
        rawText: originalText,
        parameters: {'destination': 'cart'},
      );
    }

    if (lowerText.contains('pay') ||
        lowerText.contains('complete order') ||
        lowerText.contains('finish order') ||
        lowerText.contains('place order') ||
        lowerText.contains('confirm order')) {
      if (_isCurrentlyOnCartPage()) {
        _completeCheckout();
        return VoiceCommand(
          type: VoiceCommandType.checkout,
          rawText: originalText,
          parameters: {'action': 'complete'},
        );
      } else {
        // If not on cart page, navigate first
        try {
          navigateToCart();
          speakAfterDelay(
            "Opening your cart. Say 'pay' again when you're ready to complete your order.",
          );
        } catch (e) {
          _handleError('Error navigating to cart for payment: $e');
        }

        return VoiceCommand(
          type: VoiceCommandType.navigation,
          rawText: originalText,
          parameters: {'destination': 'cart', 'forPayment': true},
        );
      }
    }

    if (lowerText.contains('add to wishlist') ||
        lowerText.contains('save to wishlist') ||
        lowerText.contains('add to wish list') ||
        lowerText.contains('save to wish list') ||
        (lowerText.contains('add') &&
            (lowerText.contains('wishlist') ||
                lowerText.contains('wish list'))) ||
        lowerText.contains('add this to wishlist') ||
        lowerText.contains('add this to wish list') ||
        lowerText.contains('add toothless') ||
        lowerText.contains('add this to wish list')) {
      return VoiceCommand(
        type: VoiceCommandType.addToWishlist,
        rawText: originalText,
        parameters: {
          'productName': _shoppingState.selectedProduct ?? 'current product',
        },
      );
    }

    // Enhancing add to cart command to detect quantity
    if (lowerText.contains('add to cart') ||
        lowerText.contains('save to cart') ||
        (lowerText.contains('add') &&
            (lowerText.contains('cart') || lowerText.contains('court'))) ||
        lowerText.contains('add this to cart')) {
      // Extract quantity if mentioned
      int quantity = 1; // Default quantity

      // Match patterns like "add 3 to cart" or "add 5 products to cart"
      final quantityMatch =
          RegExp(r'add\s+(\d+)(?:\s+\w+)?\s+to\s+cart').firstMatch(lowerText) ??
          RegExp(r'add\s+(\d+)').firstMatch(lowerText) ??
          RegExp(r'(\d+)(?:\s+\w+)?\s+to\s+cart').firstMatch(lowerText);

      if (quantityMatch != null) {
        final extractedQuantity = int.tryParse(quantityMatch.group(1) ?? '');
        if (extractedQuantity != null && extractedQuantity > 0) {
          quantity = extractedQuantity;
          debugPrint("Quantity extracted from command: $quantity");
        }
      } else {
        // Try to find quantity words (one, two, three...)
        final words = lowerText.split(' ');
        for (final word in words) {
          final wordNumber = _convertWordToNumber(word);
          if (wordNumber > 0) {
            quantity = wordNumber;
            debugPrint("Quantity extracted from word: $quantity");
            break;
          }
        }
      }

      return VoiceCommand(
        type: VoiceCommandType.addToCart,
        rawText: originalText,
        parameters: {
          'productName': _shoppingState.selectedProduct ?? 'current product',
          'quantity': quantity,
        },
      );
    }

    // Enhanced detection for product name with quantity
    final productNameMatch = RegExp(
      r'add\s+(.*?)\s+to\s+cart',
    ).firstMatch(lowerText);
    if (productNameMatch != null) {
      final productName = productNameMatch.group(1);
      int quantity = 1;

      if (productName != null && productName.isNotEmpty) {
        // Check if the product name contains a number (e.g., "add 3 headphones to cart")
        final quantityInNameMatch = RegExp(
          r'(\d+)\s+(.*)',
        ).firstMatch(productName);
        if (quantityInNameMatch != null) {
          final extractedQuantity = int.tryParse(
            quantityInNameMatch.group(1) ?? '',
          );
          final extractedProductName = quantityInNameMatch.group(2);

          if (extractedQuantity != null &&
              extractedQuantity > 0 &&
              extractedProductName != null &&
              extractedProductName.isNotEmpty) {
            quantity = extractedQuantity;
            return VoiceCommand(
              type: VoiceCommandType.addToCart,
              rawText: originalText,
              parameters: {
                'productName': extractedProductName,
                'quantity': quantity,
                'directAdd': true,
              },
            );
          }
        }

        // Also check for word numbers (e.g., "add two headphones to cart")
        final words = productName.split(' ');
        if (words.isNotEmpty) {
          final firstWordNumber = _convertWordToNumber(words.first);
          if (firstWordNumber > 0 && words.length > 1) {
            quantity = firstWordNumber;
            final extractedProductName = words.sublist(1).join(' ');
            return VoiceCommand(
              type: VoiceCommandType.addToCart,
              rawText: originalText,
              parameters: {
                'productName': extractedProductName,
                'quantity': quantity,
                'directAdd': true,
              },
            );
          }
        }

        // If no quantity found, return default
        return VoiceCommand(
          type: VoiceCommandType.addToCart,
          rawText: originalText,
          parameters: {
            'productName': productName,
            'quantity': 1,
            'directAdd': true,
          },
        );
      }
    }

    speakAfterDelay(
      "I didn't understand that command. Say 'help' to hear what I can do.",
    );
    return VoiceCommand(type: VoiceCommandType.unknown, rawText: originalText);
  }

  void _processProductSelection(int index, String originalText) {
    final selectedProduct = "product_${index + 1}";
    updateShoppingState(
      _shoppingState.copyWith(selectedProduct: selectedProduct),
    );

    _lastCommand = VoiceCommand(
      type: VoiceCommandType.addToCart,
      rawText: originalText,
      parameters: {
        'productIndex': index,
        'byNumber': true,
        'quantity': 1,
        'directAdd': true,
      },
    );

    final productService = Provider.of<ProductService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final currentCategory = _shoppingState.selectedCategory;

    if (currentCategory == null) {
      speakAfterDelay("Please select a category first.");
      return;
    }

    try {
      final products = productService.getProductsByCategory(currentCategory);

      if (index >= 0 && index < products.length) {
        productService.addToCart(products[index]);
        speakAfterDelay("Added ${products[index].name} to cart.");
      } else {
        speakAfterDelay("Product ${index + 1} not found in this category.");
      }
    } catch (e) {
      speakAfterDelay("Couldn't add product to cart. Please try again.");
    }

    _commandController.add(_lastCommand!);
    notifyListeners();
  }

  void setCurrentCategory(String categoryId) {
    updateShoppingState(_shoppingState.copyWith(selectedCategory: categoryId));
    notifyListeners();
  }

  int _convertWordToNumber(String word) {
    final cleanWord = word.trim().toLowerCase();

    switch (cleanWord) {
      case "one":
      case "1":
        return 1;
      case "two":
      case "too":
      case "2":
        return 2;
      case "three":
      case "3":
        return 3;
      case "four":
      case "for":
      case "4":
        return 4;
      case "five":
      case "5":
        return 5;
      case "six":
      case "6":
        return 6;
      case "seven":
      case "7":
        return 7;
      case "eight":
      case "8":
        return 8;
      case "nine":
      case "9":
        return 9;
      case "ten":
      case "10":
        return 10;
      default:
        return 0;
    }
  }

  bool _isButtonTapCommand(String text) {
    return text.contains('press') ||
        text.contains('click') ||
        text.contains('tap') ||
        text.contains('submit') ||
        text.contains('login') ||
        text.contains('sign up') ||
        text.contains('sign in') ||
        text.contains('switch to') ||
        text.contains('register');
  }

  String _extractActionName(String text) {
    if (text.contains('login') || text.contains('sign in')) {
      return 'login';
    } else if (text.contains('sign up') || text.contains('register')) {
      return 'sign up';
    } else if (text.contains('switch to login')) {
      return 'switch to login';
    } else if (text.contains('switch to sign up') ||
        text.contains('switch to signup') ||
        text.contains('switch to register')) {
      return 'switch to sign up';
    }

    final commonVerbs = ['press', 'click', 'tap', 'submit'];
    for (final verb in commonVerbs) {
      if (text.contains(verb)) {
        final parts = text.split(verb);
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          return parts[1].trim();
        }
      }
    }

    return '';
  }

  void updateShoppingState(ShoppingState newState) {
    _shoppingState = newState;
    notifyListeners();
  }

  void _handleQuantityInput(String text) {
    updateShoppingState(
      _shoppingState.copyWith(quantity: 1, waitingForQuantity: false),
    );

    _lastCommand = VoiceCommand(
      type: VoiceCommandType.setQuantity,
      rawText: text,
      parameters: {
        'quantity': 1,
        'productName': _shoppingState.selectedProduct,
      },
    );

    notifyListeners();
  }

  String _extractCategoryName(String text) {
    if (text.contains('reading') ||
        text.contains('recognition') ||
        text.contains('devices')) {
      return 'Reading & Recognition Devices';
    } else if (text.contains('daily') ||
        text.contains('living') ||
        text.contains('tools')) {
      return 'Daily Living Tools';
    } else if (text.contains('navigation') || text.contains('aids')) {
      return 'Navigation Aids';
    }
    return '';
  }

  int? _extractProductIndex(String text) {
    final regex = RegExp(r'product\s+(\d+)');
    final match = regex.firstMatch(text);
    return match?.group(1) != null ? int.tryParse(match!.group(1)!) : null;
  }

  void announceScreen(String screenName, {String? additionalInfo}) {
    if (screenName.toLowerCase() == 'home') {
      // For home screen, always start with microphone location using extra slow speech
      announceMicrophoneLocationSlowly();
      speakAfterDelay('You are now on the $screenName screen.', delay: const Duration(milliseconds: 3500));
      if (additionalInfo != null) {
        speakAfterDelay(additionalInfo, delay: const Duration(milliseconds: 5500));
      }
    } else {
      final message = additionalInfo != null ? '$screenName. $additionalInfo' : screenName;
      speakAfterDelay(message);
    }
  }

  void announceAction(String action) {
    speakAfterDelay(action);
  }

  void readProductsList(List<String> productNames, List<double> prices) {
    final productsText = productNames
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final name = entry.value;
          final price = prices[index];
          return "Product ${index + 1}: $name, Price: ${price.toStringAsFixed(2)} EGP";
        })
        .join(". ");

    speakAfterDelay("Available products: $productsText");
  }

  void readCategoriesList(List<String> categoryNames) {
    final categoriesText = categoryNames
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final name = entry.value;
          return "Category ${index + 1}: $name";
        })
        .join(". ");

    speakAfterDelay(
      "Available categories: $categoriesText. Say 'Open' followed by a category name to browse products.",
    );
  }

  void readCartItems(
    List<String> productNames,
    List<int> quantities,
    List<double> prices,
  ) {
    final cartText = productNames
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final name = entry.value;
          final quantity = quantities[index];
          final price = prices[index];
          final totalPrice = price * quantity;
          return "Product ${index + 1}: $name, Quantity: $quantity, Price: ${totalPrice.toStringAsFixed(2)} EGP";
        })
        .join(". ");

    final totalPrice = prices.asMap().entries.fold(
      0.0,
      (sum, entry) => sum + (entry.value * quantities[entry.key]),
    );

    speakAfterDelay(
      "$cartText. Total price: ${totalPrice.toStringAsFixed(2)} EGP",
    );
  }

  String getHelpText() {
    return '''
    Here are some commands you can use:
    
    Navigation:
    - "Home" to go to home screen
    - "Categories" to browse categories
    - "My Cart" to view your cart
    - "Profile" to view your profile
    - "My Orders" to view your order history
    - "My Wishlist" to view your wishlist
    - "Back" to return to previous screen
    
    Category Selection:
    - "Open [category name]" to browse a specific category
    - "Browse [category name]" to select a category
    - "Open category 1" to select the first category
    - "Open category 2" to select the second category

    Product Selection:
    - "Open product 1" to view product details
    - "View product 1" to open product details page
    - "Add product 1" to add directly to cart
    
    Shopping:
    - "Add to cart" to add current product to cart
    - "Add to wishlist" or "Add to wish list" to save product
    - Say a number for quantity
    - "Yes" or "No" when asked to add more products
    - "Edit product 1" to change quantity
    - "Delete product 1" to remove from cart
    - "Checkout" to proceed to checkout from cart
    - "Confirm" to place order in checkout
    - "Pay" to complete your purchase when in cart

    - "Help" to hear these commands again (works anywhere)
    ''';
  }

  void clearLastCommand() {
    if (_lastCommand != null) {
      _lastCommand = null;
      notifyListeners();
    }
  }

  void startProductSelection() {
    updateShoppingState(
      _shoppingState.copyWith(waitingForProductSelection: true),
    );
    speakAfterDelay("Please select a product by saying its number or name.");
  }

  Future<void> speakIdleMessage() async {
    await speak(idleMessage);
  }

  void announceMicrophoneLocation() {
    speak('The microphone button is located at the bottom right corner of the screen.');
  }

  Future<void> announceMicrophoneLocationSlowly() async {
    // Temporarily set even slower speech rate for this critical message
    await _flutterTts.setSpeechRate(0.25);
    await speak('The microphone button is located at the bottom right corner of the screen.');
    // Reset to normal slow rate
    await _flutterTts.setSpeechRate(0.3);
  }
}
