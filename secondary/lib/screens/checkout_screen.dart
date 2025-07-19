import 'package:flutter/material.dart';
import '../widgets/checkout_address_card.dart';
import '../widgets/checkout_payment_card.dart';
import '../widgets/checkout_summary_card.dart';
import '../screens/order_confirmation_screen.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;
  final _steps = ['address', 'payment', 'review'];
  final _paymentCardKey = GlobalKey<CheckoutPaymentCardState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        elevation: 0,
        title:  Text(
          'payment',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.bodyLarge!.color),

          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCurrentStepContent(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Theme.of(context).cardColor,
      child: Row(
        children: List.generate(
          _steps.length * 2 - 1,
          (index) {
            if (index.isEven) {
              final stepIndex = index ~/ 2;
              final isActive = stepIndex <= _currentStep;
              final isCompleted = stepIndex < _currentStep;
              final isCurrentStep = stepIndex == _currentStep;
              
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Text(
                                '${stepIndex + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _steps[stepIndex],
                      style: TextStyle(
                        color: isCurrentStep ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium!.color,
                        fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              final isActive = index ~/ 2 < _currentStep;
              return Expanded(
                child: Container(
                  height: 2,
                  color: isActive ? Theme.of(context).primaryColor : Theme.of(context).dividerColor,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return const CheckoutAddressCard();
      case 1:
        return CheckoutPaymentCard(key: _paymentCardKey);
      case 2:
        return const CheckoutSummaryCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Theme.of(context).primaryColor),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                // Check if profile is complete before proceeding
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (_currentStep == 0) { // Address step
                  if (authProvider.address == null || authProvider.address!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete your profile information first'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  if (authProvider.phone == null || authProvider.phone!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please add your phone number in your profile'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                // Validate credit card fields if credit card is selected
                if (_currentStep == 1) { // Payment step
                  final paymentCardState = _paymentCardKey.currentState;
                  if (paymentCardState != null && !paymentCardState.validateCreditCardFields()) {
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all credit card details correctly'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                if (_currentStep < _steps.length - 1) {
                  setState(() {
                    _currentStep++;
                  });
                } else {
                  // Complete the order
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const OrderConfirmationScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep < _steps.length - 1 ? 'Continue' : 'Confirm Order',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

