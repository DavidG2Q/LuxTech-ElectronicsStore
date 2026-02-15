import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_assistant_service.dart';
import '../services/product_service.dart';
import '../widgets/voice_command_button.dart';
import '../models/product.dart';
import 'category_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'orders_screen.dart';
import '../providers/user_provider.dart';
import '../widgets/idle_timer_mixin.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with IdleTimerMixin {
  int _currentIndex = 0;

  void _readCategories() {
    if (!mounted) return;
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    final productService = Provider.of<ProductService>(context, listen: false);

    // Read available categories
    List<String> categoryNames =
        productService.categories.map((c) => c.name).toList();
    voiceService.readCategoriesList(categoryNames);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );
      final productService = Provider.of<ProductService>(
        context,
        listen: false,
      );

      // Check if user is valid
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isAuthenticated) {
        userProvider.loadUserProfile().then((_) {
          if (userProvider.userDeleted && mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (Route<dynamic> route) => false,
            );
            return;
          }

          if (mounted) {
            // First announce the microphone button location immediately with extra slow speech
            voiceService.announceMicrophoneLocationSlowly();
            // Then announce the screen and other information with longer delays to ensure clarity
            voiceService.speakAfterDelay('Welcome to the Home screen.', delay: const Duration(milliseconds: 3500));
            voiceService.speakAfterDelay('You can tap the microphone button to give voice commands.', delay: const Duration(milliseconds: 6000));
            // Read available categories after other announcements with even more delay
            Future.delayed(const Duration(milliseconds: 8000), () {
              if (mounted) _readCategories();
            });
          }
        });
      } else {
        // If not authenticated, still prioritize microphone button location
        if (mounted) {
          // First announce the microphone button location immediately with extra slow speech
          voiceService.announceMicrophoneLocationSlowly();
          // Then announce the screen and other information with longer delays to ensure clarity
          voiceService.speakAfterDelay('Welcome to the Home screen.', delay: const Duration(milliseconds: 3500));
          voiceService.speakAfterDelay('You can tap the microphone button to give voice commands.', delay: const Duration(milliseconds: 6000));
          // Read available categories after other announcements with even more delay
          Future.delayed(const Duration(milliseconds: 8000), () {
            if (mounted) _readCategories();
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final productService = Provider.of<ProductService>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.navigation) {
        final destination = command.parameters['destination'] as String?;

        if (destination == 'home') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // When navigating to home, prioritize microphone button location with slow speech
            voiceService.announceMicrophoneLocationSlowly();
            voiceService.speakAfterDelay('You are now on the Home screen.', delay: const Duration(milliseconds: 3500));
            Future.delayed(const Duration(milliseconds: 5500), () {
              if (mounted) _readCategories();
            });
            voiceService.clearLastCommand();
          });
        } else if (destination == 'categories') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CategoryScreen()),
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'cart') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'profile') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            voiceService.clearLastCommand();
          });
        } else if (destination == 'orders') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const OrdersScreen()),
            );
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.selectCategory) {
        final categoryName = command.parameters['categoryName'] as String?;
        final categoryIndex = command.parameters['categoryIndex'] as int?;

        Category? categoryToOpen;

        // Find category by name or index
        if (categoryName != null && categoryName.isNotEmpty) {
          // Find the category by partial name match
          try {
            categoryToOpen = productService.categories.firstWhere(
              (cat) =>
                  cat.name.toLowerCase().contains(categoryName.toLowerCase()),
              orElse: () => productService.categories.first,
            );
          } catch (e) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              voiceService.speakAfterDelay(
                "Category not found. Please try again.",
              );
              voiceService.clearLastCommand();
            });
          }
        } else if (categoryIndex != null &&
            categoryIndex >= 0 &&
            categoryIndex < productService.categories.length) {
          categoryToOpen = productService.categories[categoryIndex];
        }

        if (categoryToOpen != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        CategoryScreen(initialCategory: categoryToOpen),
              ),
            );
            voiceService.clearLastCommand();
          });
        }
      } else if (command.type == VoiceCommandType.help) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceService.speak(voiceService.getHelpText());
          voiceService.clearLastCommand();
        });
      }
    }

    return withIdleTimer(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Electronics Store'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                ).then((_) {
                  voiceService.announceScreen('Home');
                });
              },
              tooltip: 'Go to cart',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Electronics Store',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Voice-assisted shopping for assistive technology',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.white.withOpacity(0.9)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              voiceService.speak(voiceService.getHelpText());
                            },
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Voice Command Help'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Categories',
                      style: Theme.of(context).textTheme.headlineMedium,
                      semanticsLabel: 'Browse Categories',
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: productService.categories.length,
                      itemBuilder: (context, index) {
                        final category = productService.categories[index];
                        return Semantics(
                          label: 'Category: ${category.name}',
                          hint: 'Double tap to browse ${category.name}',
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => CategoryScreen(
                                          initialCategory: category,
                                        ),
                                  ),
                                ).then((_) {
                                  voiceService.announceScreen('Home');
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      category.imageUrl,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 160,
                                          width: double.infinity,
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              size: 50,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category.name,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          category.description,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (context) =>
                                                            CategoryScreen(
                                                              initialCategory:
                                                                  category,
                                                            ),
                                                  ),
                                                ).then((_) {
                                                  voiceService.announceScreen(
                                                    'Home',
                                                  );
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.arrow_forward,
                                              ),
                                              label: const Text('Browse'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            const VoiceCommandButton(),
            if (voiceService.isListening)
              Container(
                color: Colors.black.withOpacity(0.5),
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Listening...',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          voiceService.lastWords.isEmpty
                              ? 'Say a command'
                              : voiceService.lastWords,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (!mounted) return;
            final voiceService = Provider.of<VoiceAssistantService>(
              context,
              listen: false,
            );
            String screenName = "";

            if (index == 0) {
              screenName = "Home";
              if (_currentIndex == index) {
                // Even when already on home, announce microphone location with slow speech
                voiceService.announceMicrophoneLocationSlowly();
                voiceService.speakAfterDelay("You are already on the Home screen.", delay: const Duration(milliseconds: 3500));
                Future.delayed(const Duration(milliseconds: 5500), () {
                  if (mounted) _readCategories();
                });
                return;
              }
            } else if (index == 1) {
              screenName = "Cart";
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              ).then((_) {
                if (mounted) {
                  setState(() => _currentIndex = 0);
                  voiceService.announceScreen('Home');
                }
              });
              return;
            } else if (index == 2) {
              screenName = "Profile";
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              ).then((_) {
                if (mounted) {
                  setState(() => _currentIndex = 0);
                  voiceService.announceScreen('Home');
                }
              });
              return;
            }

            setState(() => _currentIndex = index);
            voiceService.speak(screenName);

            if (index == 0) {
              // Read categories when tab is switched to Home
              _readCategories();
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}