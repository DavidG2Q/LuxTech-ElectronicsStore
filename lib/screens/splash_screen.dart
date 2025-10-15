import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:electronic_store/providers/user_provider.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      // Increased delay slightly for smoother transition
      if (!mounted) return;
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (userProvider.isAuthenticated) {
        // If user is authenticated, try to load profile, then navigate
        userProvider
            .loadUserProfile()
            .then((_) {
              if (!mounted) return;

              // Check if user was deleted or profile couldn't be loaded
              if (userProvider.userDeleted ||
                  userProvider.userProfile == null) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            })
            .catchError((_) {
              // If loading profile fails, navigate to welcome screen
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                );
              }
            });
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).colorScheme.primary,
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.devices, size: 100, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  'Electronics Store',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  semanticsLabel: 'Electronics Store for the Visually Impaired',
                ),
                const SizedBox(height: 8),
                Text(
                  'Voice Assisted Shopping',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
