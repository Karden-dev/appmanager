// lib/screens/orders_today_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/order_service.dart';
import '../models/order.dart';
import '../utils/app_theme.dart';
import 'order_details_screen.dart';
import 'chat_screen.dart';

class OrdersTodayScreen extends StatefulWidget {
  const OrdersTodayScreen({super.key});

  @override
  State<OrdersTodayScreen> createState() => _OrdersTodayScreenState();
}

class _OrdersTodayScreenState extends State<OrdersTodayScreen> {
  late Future<List<Order>> _ordersFuture;
  bool _isPerformingAction = false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Order>> _fetchOrders() async {
    // Vérification initiale
    if (!mounted) return []; 
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService == null) {
      // Gérer le cas où le service n'est pas encore prêt
      await Future.delayed(const Duration(milliseconds: 100)); 
      if (!mounted) return []; // Re-vérifier
      final orderServiceRetry = Provider.of<OrderService?>(context, listen: false);
       if (orderServiceRetry == null) {
          throw Exception("Service de commandes non disponible.");
       }
       // On invalide le cache pour s'assurer d'avoir les données fraîches
       orderServiceRetry.invalidateOrderCache(); 
       return orderServiceRetry.fetchRiderOrders(
          statuses: ['all'], 
          startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Date du jour
          endDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),   // Date du jour
       );
    }
    // On invalide le cache pour s'assurer d'avoir les données fraîches
    orderService.invalidateOrderCache(); 
    return orderService.fetchRiderOrders(
      statuses: ['all'], 
      startDate: DateFormat('yyyy-MM-dd').format(DateTime.now()), // Date du jour
      endDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),   // Date du jour
    );
  }

  Future<void> _refreshOrders() async {
    if (!mounted) return;
    setState(() {
      _ordersFuture = _fetchOrders();
    });
  }

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.danger : Colors.green,
      ),
    );
  }

  Future<void> _performApiAction(Future<void> Function() action, String successMessage) async {
    if (_isPerformingAction) return;
    if (!mounted) return;
    setState(() => _isPerformingAction = true);
    try {
      await action();
      if (!mounted) return;
      _showFeedback(successMessage);
      _refreshOrders();
    } catch (e) {
      if (!mounted) return;
      _showFeedback(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isPerformingAction = false);
      }
    }
  }

  Future<void> _handleConfirmPickup(BuildContext ctx, Order order) async {
    // CORRECTION: Capture du context avant l'await
    final currentContext = context;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: currentContext, // Utilise le contexte capturé
      builder: (BuildContext dialogContext) {
          return AlertDialog(
          title: const Text('Confirmation'),
          content: Text('Confirmez-vous avoir récupéré le colis #${order.id} ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Confirmer'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (!mounted) return; // Check après await

    if (confirm == true) {
      final orderService = Provider.of<OrderService?>(currentContext, listen: false);
      if (orderService != null) {
        _performApiAction(
          () => orderService.confirmPickup(order.id),
          'Récupération colis #${order.id} confirmée !',
        );
      } else {
         _showFeedback('Service non disponible.', isError: true);
      }
    }
  }

  Future<void> _handleStartDelivery(BuildContext ctx, Order order) async {
    if (!mounted) return;
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService != null) {
      _performApiAction(
        () => orderService.startDelivery(order.id),
        'Course #${order.id} démarrée !',
      );
    } else {
       _showFeedback('Service non disponible.', isError: true);
    }
  }

  Future<void> _handleDeclareReturn(BuildContext ctx, Order order) async {
    // CORRECTION: Capture du context avant l'await
    final currentContext = context;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: currentContext, // Utilise le contexte capturé
      builder: (BuildContext dialogContext) {
         return AlertDialog(
          title: const Text('Déclarer un Retour'),
          content: Text('Voulez-vous déclarer le colis #${order.id} comme retourné ?'),
          actions: <Widget>[
            TextButton(child: const Text('Annuler'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(child: const Text('Déclarer'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (!mounted) return; // Check après await

    if (confirm == true) {
      final orderService = Provider.of<OrderService?>(currentContext, listen: false);
      if (orderService != null) {
        _performApiAction(
          () => orderService.declareReturn(order.id),
          'Retour #${order.id} déclaré. En attente de réception au Hub.',
        );
      } else {
         _showFeedback('Service non disponible.', isError: true);
      }
    }
  }

  Future<void> _handleStatusUpdate(BuildContext ctx, Order order) async {
    // CORRECTION: Capture du context avant l'await
    final currentContext = context;
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: currentContext, // Utilise le contexte capturé
      builder: (BuildContext sheetContext) {
        // Options basées sur rider-common.js status-action-btn
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text('Livrée'), onTap: () => Navigator.pop(sheetContext, {'status': 'delivered'})),
              ListTile(leading: const Icon(Icons.error_outline, color: Colors.orange), title: const Text('Ratée'), onTap: () => Navigator.pop(sheetContext, {'status': 'failed_delivery'})),
              ListTile(leading: const Icon(Icons.report_problem_outlined, color: Colors.purple), title: const Text('À relancer'), onTap: () => Navigator.pop(sheetContext, {'status': 'reported'})),
              ListTile(leading: const Icon(Icons.cancel_outlined, color: AppTheme.danger), title: const Text('Annulée'), onTap: () => Navigator.pop(sheetContext, {'status': 'cancelled'})),
              const Divider(),
              ListTile(leading: const Icon(Icons.close), title: const Text('Fermer'), onTap: () => Navigator.pop(sheetContext)),
            ],
          ),
        );
      },
    );

    if (!mounted) return; // Check après await

    if (result != null && result['status'] != null) {
      final String status = result['status'];
       final orderService = Provider.of<OrderService?>(currentContext, listen: false);
       if (orderService == null) {
         _showFeedback('Service non disponible.', isError: true); return;
       }

      if (status == 'delivered') {
        _handleDeliveredPayment(currentContext, order); // Ouvre la modale de paiement
      } else if (status == 'failed_delivery') {
        _handleFailedDelivery(currentContext, order); // Ouvre la modale de montant reçu
      } else if (status == 'cancelled') {
        // Confirmation avant annulation
        final confirmCancel = await showDialog<bool>(
          context: currentContext, // Utilise le contexte capturé
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirmation'),
            content: Text('Voulez-vous vraiment annuler la commande #${order.id} ?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Non')),
              TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('Oui, Annuler')),
            ],
          ),
        );
        if (!mounted) return; // Check après await
        if (confirmCancel == true) {
          _performApiAction(
            () => orderService.updateOrderStatus(orderId: order.id, status: 'cancelled', paymentStatus: 'cancelled'),
            'Commande #${order.id} annulée.',
          );
        }
      } else if (status == 'reported') {
         _performApiAction(
          () => orderService.updateOrderStatus(orderId: order.id, status: 'reported', paymentStatus: 'pending'), // Remettre en pending payment pour la relance
          'Commande #${order.id} marquée à relancer.',
        );
      }
    }
  }

  // Modale pour choisir le mode de paiement si 'Livrée'
  Future<void> _handleDeliveredPayment(BuildContext ctx, Order order) async {
    // CORRECTION: Capture du context avant l'await
    final currentContext = context;
    if (!mounted) return;

    final paymentMethod = await showModalBottomSheet<String>(
      context: currentContext, // Utilise le contexte capturé
      builder: (BuildContext sheetContext) {
         return SafeArea(child: Wrap(children: <Widget>[
           ListTile(leading: const Icon(Icons.money, color: Colors.green), title: const Text('Espèces'), onTap: () => Navigator.pop(sheetContext, 'cash')),
           ListTile(leading: const Icon(Icons.phone_android, color: Colors.blue), title: const Text('Mobile Money'), onTap: () => Navigator.pop(sheetContext, 'paid_to_supplier')),
           ListTile(leading: const Icon(Icons.close), title: const Text('Annuler'), onTap: () => Navigator.pop(sheetContext)),
         ]));
      },
    );
    if (!mounted) return; // Check après await
    if (paymentMethod != null) {
       final orderService = Provider.of<OrderService?>(currentContext, listen: false);
       if (orderService != null) {
          _performApiAction(
            () => orderService.updateOrderStatus(orderId: order.id, status: 'delivered', paymentStatus: paymentMethod),
            'Commande #${order.id} marquée comme livrée (${paymentMethod == "cash" ? "Espèces" : "Mobile Money"}).',
          );
       } else {
         _showFeedback('Service non disponible.', isError: true);
       }
    }
  }

  // Modale pour entrer le montant si 'Ratée'
  Future<void> _handleFailedDelivery(BuildContext ctx, Order order) async {
     // CORRECTION: Capture du context avant l'await
     final currentContext = context;
     if (!mounted) return;

     double? amountReceived;
     final TextEditingController amountController = TextEditingController();

     final confirm = await showDialog<bool>(
        context: currentContext, // Utilise le contexte capturé
        builder: (BuildContext dialogContext) {
           return AlertDialog(
              title: Text('Livraison Ratée #${order.id}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Text('Montant perçu du client (si paiement partiel) :'),
                   TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: const InputDecoration(hintText: '0 FCFA', suffixText: 'FCFA'),
                   ),
                ],
              ),
              actions: [
                 TextButton(child: const Text('Annuler'), onPressed: () => Navigator.pop(dialogContext, false)),
                 TextButton(child: const Text('Confirmer Ratée'), onPressed: () {
                    amountReceived = double.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
                    Navigator.pop(dialogContext, true);
                 }),
              ],
           );
        },
     );
     amountController.dispose();

     if (!mounted) return; // Check après await

     if (confirm == true) {
        final orderService = Provider.of<OrderService?>(currentContext, listen: false);
        if (orderService != null) {
           _performApiAction(
             () => orderService.updateOrderStatus(orderId: order.id, status: 'failed_delivery', amountReceived: amountReceived),
             'Commande #${order.id} marquée comme ratée${amountReceived != null && amountReceived! > 0 ? " (montant reçu: ${formatAmount(amountReceived)})" : ""}.',
           );
        } else {
          _showFeedback('Service non disponible.', isError: true);
        }
     }
  }

  // **IMPLÉMENTATION APPEL TÉLÉPHONIQUE**
  Future<void> _handleCallClient(BuildContext ctx, Order order) async {
     if (!mounted) return;
     final String cleanedPhone = order.customerPhone.replaceAll(RegExp(r'\s+'), '');
     final Uri launchUri = Uri(scheme: 'tel', path: cleanedPhone);
     try {
       bool canLaunch = await canLaunchUrl(launchUri);
       if (!mounted) return;
       if (canLaunch) {
         await launchUrl(launchUri);
         if (!mounted) return;
       } else {
         _showFeedback('Impossible de lancer l\'application téléphone pour $cleanedPhone.', isError: true);
       }
     } catch (e) {
       if (!mounted) return;
       _showFeedback('Erreur lors de la tentative d\'appel: $e', isError: true);
     }
  }

  // *** ACTION SMS (SUPPRIMÉE COMME DEMANDÉ) ***
  // Future<void> _handleSmsClient(BuildContext ctx, Order order) async { ... }

  // *** LOGIQUE WHATSAPP AMÉLIORÉE ***
  Future<void> _handleWhatsAppClient(BuildContext ctx, Order order) async {
    if (!mounted) return;

    // 1. Nettoyer tous les caractères non numériques
    String cleanedPhone = order.customerPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // 2. Logique de formatage robuste pour le Cameroun (237)
    if (cleanedPhone.startsWith('00237') && cleanedPhone.length == 14) {
      // Cas: 0023769...
      cleanedPhone = cleanedPhone.substring(5); // Résultat: 69... (9 chiffres)
    } else if (cleanedPhone.startsWith('237') && cleanedPhone.length == 12) {
      // Cas: 23769...
      cleanedPhone = cleanedPhone.substring(3); // Résultat: 69... (9 chiffres)
    } else if (cleanedPhone.length == 10 && cleanedPhone.startsWith('06')) {
       // Cas: 069...
       cleanedPhone = cleanedPhone.substring(1); // Résultat: 69... (9 chiffres)
    } else if (cleanedPhone.length == 9 && (cleanedPhone.startsWith('6') || cleanedPhone.startsWith('2'))) {
      // Cas: 69... (Format local correct)
      // Ne rien faire
    } else {
      // Format non reconnu
      _showFeedback('Numéro ($cleanedPhone) non reconnu pour WhatsApp.', isError: true);
      return;
    }
    
    // 3. À ce stade, cleanedPhone devrait avoir 9 chiffres (ex: 69...)
    // On ajoute le préfixe pays SANS le '+'
    final String whatsappNumber = '237$cleanedPhone';
    final Uri launchUri = Uri.parse('https://wa.me/$whatsappNumber');

    try {
      bool canLaunch = await canLaunchUrl(launchUri);
      if (!mounted) return;

      if (canLaunch) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
      } else {
        _showFeedback('Impossible d\'ouvrir WhatsApp pour $whatsappNumber.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showFeedback('Erreur lors de la tentative d\'ouverture de WhatsApp: $e', isError: true);
    }
  }
  // *******************************


  // **IMPLÉMENTATION OUVERTURE CHAT**
  void _openChat(BuildContext ctx, Order order) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (context) => ChatScreen(order: order),
    ));
  }

  // Helper local formatAmount
  String formatAmount(double? amount) {
    if (amount == null) return '0 FCFA';
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: FutureBuilder<List<Order>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Text(
                     'Erreur: ${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                     style: const TextStyle(color: Colors.red),
                     textAlign: TextAlign.center,
                   ),
                 ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return LayoutBuilder(
                 builder: (ctx, constraints) => SingleChildScrollView(
                   physics: const AlwaysScrollableScrollPhysics(),
                   child: Container(
                     height: constraints.maxHeight,
                     alignment: Alignment.center,
                     child: const Text(
                       'Aucune commande pour aujourd\'hui.',
                       style: TextStyle(color: Colors.grey),
                     ),
                   ),
                 ),
               );
            }

            final orders = snapshot.data!;
            orders.sort((a, b) => a.compareToForToday(b));

            return ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                return OrderCard(
                  order: orders[index],
                  onConfirmPickup: () => _handleConfirmPickup(context, orders[index]),
                  onStartDelivery: () => _handleStartDelivery(context, orders[index]),
                  onDeclareReturn: () => _handleDeclareReturn(context, orders[index]),
                  onStatusUpdate: () => _handleStatusUpdate(context, orders[index]),
                  onCallClient: () => _handleCallClient(context, orders[index]),
                  // onSmsClient: null, // Action SMS retirée
                  onWhatsAppClient: () => _handleWhatsAppClient(context, orders[index]),
                  onOpenChat: () => _openChat(context, orders[index]),
                  isActionInProgress: _isPerformingAction,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// --- WIDGET POUR AFFICHER UNE CARTE DE COMMANDE ---
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onConfirmPickup;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onDeclareReturn;
  final VoidCallback? onStatusUpdate;
  final VoidCallback? onCallClient;
  final VoidCallback? onSmsClient; // Conservé pour la compatibilité (mais non utilisé)
  final VoidCallback? onWhatsAppClient;
  final VoidCallback? onOpenChat;
  final bool isActionInProgress;

  const OrderCard({
    super.key,
    required this.order,
    this.onConfirmPickup,
    this.onStartDelivery,
    this.onDeclareReturn,
    this.onStatusUpdate,
    this.onCallClient,
    this.onSmsClient, // Conservé
    this.onWhatsAppClient,
    this.onOpenChat,
    this.isActionInProgress = false,
  });

  // (Helpers _getStatusColor, _getStatusIcon, paymentTranslations, etc. - INCHANGÉS)
  Color _getStatusColor(String status) {
     switch (status) {
      case 'delivered': return Colors.green.shade700;
      case 'cancelled': case 'failed_delivery': case 'return_declared': case 'returned': return AppTheme.danger;
      case 'pending': return Colors.orange.shade700;
      case 'in_progress': case 'ready_for_pickup': return Colors.blue.shade700;
      case 'en_route': return AppTheme.primaryColor;
      case 'reported': return Colors.purple.shade700;
      default: return Colors.grey.shade700;
    }
   }
  IconData _getStatusIcon(String status) {
      switch (status) {
      case 'delivered': return Icons.check_circle_outline;
      case 'cancelled': return Icons.cancel_outlined;
      case 'failed_delivery': return Icons.error_outline;
      case 'return_declared': case 'returned': return Icons.assignment_return_outlined;
      case 'pending': return Icons.pending_outlined;
      case 'in_progress': return Icons.assignment_ind_outlined;
      case 'ready_for_pickup': return Icons.inventory_2_outlined;
      case 'en_route': return Icons.local_shipping_outlined;
      case 'reported': return Icons.report_problem_outlined;
      default: return Icons.help_outline;
    }
  }
   static const Map<String, String> paymentTranslations = {
     'pending': 'En attente',
    'cash': 'En espèces',
    'paid_to_supplier': 'Mobile Money',
    'cancelled': 'Annulé'
   };
  Color _getPaymentColor(String paymentStatus) {
     switch (paymentStatus) {
        case 'pending': return Colors.orange.shade700;
        case 'cash': return Colors.green.shade700;
        case 'paid_to_supplier': return Colors.blue.shade700;
        case 'cancelled': return AppTheme.danger;
        default: return Colors.grey.shade700;
      }
   }
  IconData _getPaymentIcon(String paymentStatus) {
     switch (paymentStatus) {
        case 'pending': return Icons.hourglass_empty;
        case 'cash': return Icons.money;
        case 'paid_to_supplier': return Icons.phone_android;
        case 'cancelled': return Icons.money_off;
        default: return Icons.help_outline;
      }
   }

  // *** SUPPRESSION DE _buildPrimaryAction ***

  @override
  Widget build(BuildContext context) {
    final orderService = Provider.of<OrderService?>(context, listen: false);
    final statusText = orderService?.statusTranslations[order.status] ?? order.status;
    final paymentText = paymentTranslations[order.paymentStatus] ?? order.paymentStatus;
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final paymentColor = _getPaymentColor(order.paymentStatus);
    final paymentIcon = _getPaymentIcon(order.paymentStatus);
    final amountToCollectFormatted = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(order.amountToCollect);
    
    // *** CORRECTION: Logique des actions déplacée ici ***
    final bool canPickup = order.status == 'ready_for_pickup' && !order.isPickedUp;
    final bool canStartDelivery = order.status == 'ready_for_pickup' && order.isPickedUp;
    final bool canUpdateStatus = ['en_route', 'reported'].contains(order.status);
    final bool canDeclareReturn = ['en_route', 'failed_delivery', 'cancelled', 'reported'].contains(order.status);
    // ***************************************************


    return GestureDetector(
       onTap: () {
         Navigator.of(context).push(MaterialPageRoute(
           builder: (context) => OrderDetailsScreen(order: order),
         ));
       },
       child: Card(
         elevation: 3,
         margin: const EdgeInsets.only(bottom: 12.0),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12.0),
           side: order.isUrgent ? const BorderSide(color: AppTheme.danger, width: 2) : BorderSide.none,
         ),
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Expanded(
                     child: Text(
                       'Commande #${order.id}',
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   // *** CORRECTION: Retour aux 3 boutons icônes ***
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // 1. Bouton Chat
                       IconButton(
                         icon: Badge(
                           label: Text(order.unreadCount.toString()),
                           isLabelVisible: order.unreadCount > 0,
                           child: const Icon(Icons.chat_bubble_outline),
                         ),
                         color: AppTheme.secondaryColor,
                         tooltip: 'Discussion',
                         onPressed: isActionInProgress ? null : onOpenChat,
                       ),
                       // 2. Bouton Actions (Statuer, Retourner, Confirmer, Démarrer)
                       PopupMenuButton<String>(
                         icon: const Icon(Icons.settings_outlined, color: AppTheme.secondaryColor), // Icône "Gear"
                         tooltip: 'Actions',
                         enabled: !isActionInProgress,
                         onSelected: (String result) {
                           if (result == 'pickup') { onConfirmPickup?.call(); }
                           else if (result == 'start_delivery') { onStartDelivery?.call(); }
                           else if (result == 'status') { onStatusUpdate?.call(); }
                           else if (result == 'return') { onDeclareReturn?.call(); }
                         },
                         itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                           if (canPickup)
                             const PopupMenuItem<String>(value: 'pickup', child: ListTile(leading: Icon(Icons.inventory, color: Colors.orange), title: Text('Confirmer Récupération'))),
                           if (canStartDelivery)
                             const PopupMenuItem<String>(value: 'start_delivery', child: ListTile(leading: Icon(Icons.play_circle_outline, color: Colors.green), title: Text('Démarrer Course'))),
                           if (canUpdateStatus)
                             const PopupMenuItem<String>(value: 'status', child: ListTile(leading: Icon(Icons.rule, color: AppTheme.primaryColor), title: Text('Statuer la commande'))),
                           if (canDeclareReturn)
                             const PopupMenuItem<String>(value: 'return', child: ListTile(leading: Icon(Icons.assignment_return, color: AppTheme.danger), title: Text('Déclarer un retour'))),
                           
                           // CORRECTION: Ajout du Divider (height: 1)
                           if ((canPickup || canStartDelivery || canUpdateStatus || canDeclareReturn))
                             const PopupMenuDivider(height: 1), // <-- CORRECTION DU BUG
                           
                           // Message si aucune action n'est dispo
                           if (!canPickup && !canStartDelivery && !canUpdateStatus && !canDeclareReturn)
                             const PopupMenuItem<String>(
                               value: 'none',
                               enabled: false,
                               child: ListTile(title: Text('Aucune action disponible', style: TextStyle(color: Colors.grey))),
                             ),
                         ],
                       ),
                       // 3. Bouton Contact (Appel, WhatsApp)
                       PopupMenuButton<String>(
                         icon: const Icon(Icons.call_outlined, color: AppTheme.primaryColor), // Icône "Téléphone"
                         tooltip: 'Contacter Client',
                         enabled: !isActionInProgress,
                         onSelected: (String result) {
                            if (result == 'call_client') { onCallClient?.call(); }
                            else if (result == 'whatsapp_client') { onWhatsAppClient?.call(); }
                         },
                         itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                           const PopupMenuItem<String>(value: 'call_client', child: ListTile(leading: Icon(Icons.call), title: Text('Appeler Client'))),
                           // *** CORRECTION: SMS retiré ***
                           const PopupMenuItem<String>(value: 'whatsapp_client', child: ListTile(leading: Icon(Icons.message /* Icône WhatsApp */), title: Text('WhatsApp Client'))),
                         ],
                       ),
                     ],
                   ),
                   // ***********************************************
                 ],
               ),
               if (order.isUrgent)
                   const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Chip(
                         label: Text('URGENT'),
                         backgroundColor: AppTheme.danger,
                         labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                   ),
               const Divider(height: 16),
               _buildDetailRow(Icons.storefront, 'Marchand', order.shopName),
               _buildDetailRow(Icons.person_outline, 'Client', order.customerName ?? order.customerPhone),
               _buildDetailRow(Icons.location_on_outlined, 'Adresse', order.deliveryLocation),
               _buildDetailRow(Icons.list_alt, 'Articles', order.itemsList ?? 'Non spécifié', maxLines: 2),
               const SizedBox(height: 8),
                Row(
                   children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      Icon(paymentIcon, color: paymentColor, size: 16),
                      const SizedBox(width: 6),
                      Text(paymentText, style: TextStyle(color: paymentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     const Text('À encaisser: ', style: TextStyle(fontSize: 14)),
                     Text(
                       amountToCollectFormatted,
                       style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                     ),
                   ],
                 ),
                 
                 // *** SUPPRESSION du _buildPrimaryAction(context) ***
                 
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Créée le ${DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(order.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ),
                ),
             ],
           ),
         ),
       ),
    );
  }

  // Widget helper pour afficher une ligne de détail (inchangé)
  Widget _buildDetailRow(IconData icon, String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(
             '$label: ',
             style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
             overflow: TextOverflow.ellipsis,
             maxLines: 1,
           ),
           Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              overflow: TextOverflow.ellipsis,
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }
}