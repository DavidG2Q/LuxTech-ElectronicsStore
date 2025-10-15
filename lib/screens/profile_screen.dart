import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:electronic_store/providers/user_provider.dart';
import 'package:electronic_store/providers/wishlist_provider.dart';
import 'package:electronic_store/screens/orders_screen.dart';
import 'package:electronic_store/screens/wishlist_screen.dart';
import 'package:electronic_store/screens/help_screen.dart';
import 'package:electronic_store/services/voice_assistant_service.dart';
import 'package:electronic_store/widgets/voice_command_button.dart';
import 'home_screen.dart';
import 'cart_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final voiceService = Provider.of<VoiceAssistantService>(
        context,
        listen: false,
      );
      _initVoiceAssistant(voiceService);

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (!userProvider.isAuthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
        return;
      }

      userProvider.loadUserProfile().then((_) {
        if (mounted) {
          _announceScreenContent(voiceService);
        }
      });
    });
  }

  Future<void> _initVoiceAssistant(VoiceAssistantService voiceService) async {
    if (mounted) {
      voiceService.announceScreen("Profile Screen");
    }
  }

  Future<void> _announceScreenContent(
    VoiceAssistantService voiceService,
  ) async {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    String announcement = "You are on the Profile Screen. ";
    if (userProvider.userProfile != null) {
      announcement += "Hello ${userProvider.userProfile!.name}. ";
    }
    announcement +=
        "You can navigate to My Orders, Wishlist, or Help. You can also logout.";
    await voiceService.speak(announcement);
  }

  Future<void> _logout() async {
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    await voiceService.speak("Logging out.");
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final rememberMe = await userProvider.isRememberMeSelected();
    await userProvider.signOut();
    await userProvider.clearUserData(preserveEmail: rememberMe);
    await context.read<WishlistProvider>().clear();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (Route<dynamic> route) => false,
        );
      });
    }
  }

  void _handleVoiceCommand(VoiceCommand command) {
    final voiceService = Provider.of<VoiceAssistantService>(
      context,
      listen: false,
    );
    if (command.type == VoiceCommandType.navigation) {
      final destination = command.parameters['destination']?.toLowerCase();
      switch (destination) {
        case 'my orders':
        case 'orders':
          _navigateTo(
            const OrdersScreen(),
            "Navigating to My Orders.",
            voiceService,
          );
          break;
        case 'wishlist':
          _navigateTo(
            const WishlistScreen(),
            "Navigating to Wishlist.",
            voiceService,
          );
          break;
        case 'help':
          _navigateTo(
            const HelpScreen(),
            "Navigating to Help Screen.",
            voiceService,
          );
          break;
        case 'home':
          voiceService.speak("Navigating to Home Screen.");
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
          break;
        case 'cart':
          _navigateTo(
            const CartScreen(),
            "Navigating to Cart Screen.",
            voiceService,
          );
          break;
      }
    } else if (command.type == VoiceCommandType.buttonTap) {
      final actionName = command.parameters['actionName']?.toLowerCase();
      if (actionName == 'logout') {
        _logout();
      }
    }
    if (mounted) {
      voiceService.clearLastCommand();
    }
  }

  void _navigateTo(
    Widget screen,
    String announcement,
    VoiceAssistantService voiceService,
  ) {
    voiceService.speak(announcement);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      if (mounted) {
        voiceService.announceScreen("Profile Screen");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final voiceService = Provider.of<VoiceAssistantService>(context);

    if (voiceService.lastCommand != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && voiceService.lastCommand != null) {
          _handleVoiceCommand(voiceService.lastCommand!);
        }
      });
    }

    if (!userProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guest Profile')),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  const Text(
                    'Please log in to access your profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Login'),
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (Route<dynamic> route) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Back to Home'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const VoiceCommandButton(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (userProvider.isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  Center(
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          child: Icon(Icons.person, size: 50),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userProvider.userProfile?.name ?? 'User',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          userProvider.userProfile?.email ?? '',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildProfileOption(
                    context,
                    icon: Icons.list_alt,
                    title: 'My Orders',
                    onTap: () => _navigateTo(
                      const OrdersScreen(),
                      "Navigating to My Orders.",
                      Provider.of<VoiceAssistantService>(context, listen: false),
                    ),
                  ),
                  _buildProfileOption(
                    context,
                    icon: Icons.favorite_border,
                    title: 'Wishlist',
                    onTap: () => _navigateTo(
                      const WishlistScreen(),
                      "Navigating to Wishlist.",
                      Provider.of<VoiceAssistantService>(context, listen: false),
                    ),
                  ),
                  _buildProfileOption(
                    context,
                    icon: Icons.help_outline,
                    title: 'Help',
                    onTap: () => _navigateTo(
                      const HelpScreen(),
                      "Navigating to Help Screen.",
                      Provider.of<VoiceAssistantService>(context, listen: false),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
          const VoiceCommandButton(),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
