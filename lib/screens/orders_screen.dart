import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/orders_provider.dart';
import '../services/voice_assistant_service.dart';
import '../widgets/voice_command_button.dart';
import 'home_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  Map<String, String> _lastStatuses = {};

  @override
  void initState() {
    super.initState();
    _initTts();
    _readOrders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersProvider = context.read<OrdersProvider>();
      final orders = ordersProvider.orders;
      for (var order in orders) {
        _lastStatuses[order.id] = order.status;
        if (order.status != 'Delivered') {
          // Start progression for each non-delivered order
          ordersProvider.startOrderStatusProgression(order.id);
        }
      }
    });
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _readOrders() async {
    final orders = context.read<OrdersProvider>().orders;
    if (orders.isEmpty) {
      await _flutterTts.speak("You have no orders yet");
      return;
    }

    String ordersText = "Your orders: ";
    for (var order in orders) {
      ordersText +=
          "Order ${order.id}, total: ${order.totalAmount} EGP, status: ${order.status}. ";
    }
    await _flutterTts.speak(ordersText);
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceAssistantService>(context);
    final ordersProvider = Provider.of<OrdersProvider>(context);

    if (voiceService.lastCommand != null) {
      final command = voiceService.lastCommand!;

      if (command.type == VoiceCommandType.navigation) {
        final destination = command.parameters['destination'] as String?;

        if (destination == 'home') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          });
        }
      }
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: Stack(
          children: [
            Consumer<OrdersProvider>(
              builder: (context, orders, child) {
                // Announce status changes
                for (var order in orders.orders) {
                  final prevStatus = _lastStatuses[order.id];
                  if (prevStatus != null && prevStatus != order.status) {
                    _flutterTts.speak(
                      "Order ${order.id} status changed to ${order.status}",
                    );
                    _lastStatuses[order.id] = order.status;
                  } else if (prevStatus == null) {
                    _lastStatuses[order.id] = order.status;
                  }
                }

                if (orders.orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders yet',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your order history will appear here',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.orders.length,
                  itemBuilder: (context, index) {
                    final order = orders.orders[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        title: Text('Order #${order.id}'),
                        subtitle: Text(
                          'Total: ${order.totalAmount} EGP\nStatus: ${order.status}',
                        ),
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: order.items.length,
                            itemBuilder: (context, itemIndex) {
                              final item = order.items[itemIndex];
                              return ListTile(
                                leading: const Icon(Icons.shopping_bag),
                                title: Text(item.name),
                                subtitle: Text(
                                  'Quantity: ${item.quantity}\nPrice: ${item.price} EGP',
                                ),
                                trailing: Text(
                                  '${item.totalPrice} EGP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order Date: ${order.date}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Text(
                                  'Total: ${order.totalAmount} EGP',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            const VoiceCommandButton(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
