import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';

class CheckoutPaymentCard extends StatefulWidget {
  const CheckoutPaymentCard({super.key});

  @override
  CheckoutPaymentCardState createState() => CheckoutPaymentCardState();
}

class CheckoutPaymentCardState extends State<CheckoutPaymentCard> {
  String _selectedPaymentMethod = 'cash_on_delivery';
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set the initial payment method in the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false)
          .setPaymentMethod(_selectedPaymentMethod);
    });
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  // Format card number with spaces
  String _formatCardNumber(String input) {
    if (input.isEmpty) return '';
    
    input = input.replaceAll(' ', '');
    final buffer = StringBuffer();
    
    for (int i = 0; i < input.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(input[i]);
    }
    
    return buffer.toString();
  }

  // Format expiry date with slash
  String _formatExpiryDate(String input) {
    if (input.isEmpty) return '';
    
    input = input.replaceAll('/', '');
    if (input.length > 2) {
      return '${input.substring(0, 2)}/${input.substring(2)}';
    }
    return input;
  }

  // Validate card number - simplified to just check for 16 digits
  bool _isValidCardNumber(String input) {
    input = input.replaceAll(' ', '');
    return input.length == 16;
  }

  // Add method to validate credit card fields
  bool validateCreditCardFields() {
    if (_selectedPaymentMethod != 'credit_card') return true;
    return _formKey.currentState?.validate() ?? false;
  }

  // Add getter for form key
  GlobalKey<FormState> get formKey => _formKey;

  // Add getter for selected payment method
  String get selectedPaymentMethod => _selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Payment method selection
            Column(
              children: [
                RadioListTile<String>(
                  title: Row(
                    children: [
                      Icon(
                        Icons.credit_card,
                        color: _selectedPaymentMethod == 'credit_card'
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Credit Card',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                        ),
                      ),
                    ],
                  ),
                  value: 'credit_card',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                      // Update the payment method in the provider
                      orderProvider.setPaymentMethod(value);
                      // If credit card is selected, also set card details
                      if (value == 'credit_card' && _cardNumberController.text.isNotEmpty) {
                        orderProvider.setCardDetails(
                          _formatCardNumber(_cardNumberController.text),
                          _cardHolderController.text,
                          _expiryDateController.text
                        );
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: _selectedPaymentMethod == 'bank_transfer'
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bank Transfer',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                        ),
                      ),
                    ],
                  ),
                  value: 'bank_transfer',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                      // Update the payment method in the provider
                      orderProvider.setPaymentMethod(value);
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: Row(
                    children: [
                      Icon(
                        Icons.money,
                        color: _selectedPaymentMethod == 'cash_on_delivery'
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cash On Delivery',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
                        ),
                      ),
                    ],
                  ),
                  value: 'cash_on_delivery',
                  groupValue: _selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                      // Update the payment method in the provider
                      orderProvider.setPaymentMethod(value);
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Credit card form
            if (_selectedPaymentMethod == 'credit_card') ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card number field
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Card Number',
                        hintText: 'XXXX XXXX XXXX XXXX',
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      onChanged: (value) {
                        final formatted = _formatCardNumber(value);
                        if (formatted != value) {
                          _cardNumberController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
                          );
                        }
                        
                        // Update card details in provider if valid
                        if (value.replaceAll(' ', '').length >= 16) {
                          orderProvider.setCardDetails(
                            formatted,
                            _cardHolderController.text,
                            _expiryDateController.text
                          );
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        if (!_isValidCardNumber(value)) {
                          return 'Invalid card number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Card holder name
                    TextFormField(
                      controller: _cardHolderController,
                      decoration: const InputDecoration(
                        labelText: 'Card Holder Name',
                        hintText: 'As written on card',
                        prefixIcon: Icon(Icons.person),
                      ),
                      onChanged: (value) {
                        // Update card details in provider
                        orderProvider.setCardDetails(
                          _formatCardNumber(_cardNumberController.text),
                          value,
                          _expiryDateController.text
                        );
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card holder name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Expiry date and CVV
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryDateController,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                              prefixIcon: Icon(Icons.date_range),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onChanged: (value) {
                              final formatted = _formatExpiryDate(value);
                              if (formatted != value) {
                                _expiryDateController.value = TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                              }
                              
                              // Update card details in provider
                              if (formatted.length >= 4) {
                                orderProvider.setCardDetails(
                                  _formatCardNumber(_cardNumberController.text),
                                  _cardHolderController.text,
                                  formatted
                                );
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter expiry date';
                              }
                              if (value.length < 5) {
                                return 'Invalid Date Format';
                              }
                              
                              // Check if date is valid
                              final parts = value.split('/');
                              if (parts.length != 2) return 'Invalid Date Format';
                              
                              final month = int.tryParse(parts[0]);
                              final year = int.tryParse('20${parts[1]}');
                              
                              if (month == null || year == null || month < 1 || month > 12) {
                                return 'Invalid Date Format';
                              }
                              
                              final now = DateTime.now();
                              final cardDate = DateTime(year, month);
                              if (cardDate.isBefore(now)) {
                                return 'Invalid Date Format';
                              }
                              
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            decoration: const InputDecoration(
                              labelText: 'CVV',
                              hintText: 'XXX',
                              prefixIcon: Icon(Icons.security),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CVV code';
                              }
                              if (value.length < 3) {
                                return 'Please enter CVV code';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (_selectedPaymentMethod == 'bank_transfer') ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bank account details  :',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Bank name: Banque Misr'),
                    Text('Luxe Tech for Trading and Technology'),
                    Text('Account number: EG1234567890283'),
                    SizedBox(height: 16),
                    Text(
                     'Please send a screenshot of the transfer to our email:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('payments@Luxetech.com'),
                  ],
                ),
              ),
            ] else if (_selectedPaymentMethod == 'cash_on_delivery') ...[
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash on Delivery:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Money will be collected upon delivery.'),
                    Text('Please make sure to have enough cash to cover the total amount.'),
                    SizedBox(height: 8),
                    Text('Note: The courier may not have change for large bills.'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
