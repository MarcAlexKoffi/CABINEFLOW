import 'dart:async';

import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';

class CustomerMessagingPage extends StatefulWidget {
  const CustomerMessagingPage({
    super.key,
    required this.repository,
    required this.orders,
    required this.orderContext,
    this.customerName,
    required this.onBack,
    required this.onOpenHome,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenHelp,
    this.onInnerViewChanged,
    this.resetInnerViewToken = 0,
  });

  final CustomerMessagingRepository repository;
  final List<CustomerOrderReceipt> orders;
  final CustomerOrderContextDraft orderContext;
  final String? customerName;
  final VoidCallback onBack;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;
  final ValueChanged<bool>? onInnerViewChanged;
  final int resetInnerViewToken;

  @override
  State<CustomerMessagingPage> createState() => _CustomerMessagingPageState();
}

class _CustomerMessagingPageState extends State<CustomerMessagingPage> {
  final TextEditingController _newMessageController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  final ValueNotifier<int> _mobileInnerRevision = ValueNotifier<int>(0);

  StreamSubscription<List<CustomerConversation>>? _conversationSubscription;
  StreamSubscription<List<CustomerMessage>>? _messageSubscription;

  List<CustomerConversation> _conversations = const <CustomerConversation>[];
  List<CustomerMessage> _messages = const <CustomerMessage>[];
  CustomerConversation? _selectedConversation;
  CustomerOrderReceipt? _selectedOrder;

  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isCreating = false;
  bool _isSending = false;
  bool _showComposer = false;
  String? _conversationError;
  String? _messageError;

  @override
  void initState() {
    super.initState();
    _subscribeConversations();
  }

  @override
  void didUpdateWidget(covariant CustomerMessagingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetInnerViewToken != widget.resetInnerViewToken &&
        (_showComposer || _selectedConversation != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _closeInnerView(notifyParent: false);
      });
    }
  }

  @override
  void dispose() {
    _conversationSubscription?.cancel();
    _messageSubscription?.cancel();
    _newMessageController.dispose();
    _replyController.dispose();
    _messageScrollController.dispose();
    _mobileInnerRevision.dispose();
    super.dispose();
  }

  void _notifyMobileInnerRoute() {
    if (!mounted) return;
    _mobileInnerRevision.value += 1;
  }

  void _subscribeConversations() {
    _conversationSubscription?.cancel();
    _conversationSubscription = widget.repository
        .watchCustomerConversations()
        .listen(
          (List<CustomerConversation> conversations) {
            if (!mounted) return;
            CustomerConversation? selected = _selectedConversation;
            final String? selectedId = selected?.id;
            if (selectedId != null) {
              for (final CustomerConversation conversation in conversations) {
                if (conversation.id == selectedId) {
                  selected = conversation;
                  break;
                }
              }
            }
            setState(() {
              _conversations = conversations;
              _selectedConversation = selected;
              _isLoadingConversations = false;
              _conversationError = null;
            });
            _notifyMobileInnerRoute();
          },
          onError: (Object _, StackTrace _) {
            if (!mounted) return;
            setState(() {
              _isLoadingConversations = false;
              _conversationError =
                  'La messagerie est momentanément indisponible. Réessayez.';
            });
          },
        );
  }

  Future<void> _refreshConversationsOnce() async {
    try {
      final List<CustomerConversation> conversations =
          await widget.repository.watchCustomerConversations().first;
      if (!mounted) return;
      CustomerConversation? selected = _selectedConversation;
      final String? selectedId = selected?.id;
      if (selectedId != null) {
        for (final CustomerConversation conversation in conversations) {
          if (conversation.id == selectedId) {
            selected = conversation;
            break;
          }
        }
      }
      setState(() {
        _conversations = conversations;
        _selectedConversation = selected;
        _isLoadingConversations = false;
        _conversationError = null;
      });
      _notifyMobileInnerRoute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingConversations = false;
        _conversationError =
            'La messagerie est momentanément indisponible. Réessayez.';
      });
    }
  }

  Future<void> _refreshMessagesOnce(String conversationId) async {
    try {
      final List<CustomerMessage> messages = await widget.repository
          .watchMessages(conversationId: conversationId)
          .first;
      if (!mounted || _selectedConversation?.id != conversationId) return;
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
        _messageError = null;
      });
      _notifyMobileInnerRoute();
      _scrollMessagesToBottom();
    } catch (_) {
      if (!mounted || _selectedConversation?.id != conversationId) return;
      setState(() {
        _messageError = 'Impossible de charger les messages pour le moment.';
        _isLoadingMessages = false;
      });
    }
  }

  void _openConversation(CustomerConversation conversation) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;
    final bool replaceComposerRoute = !desktop && _showComposer;

    setState(() {
      _selectedConversation = conversation;
      _showComposer = false;
      _messages = const <CustomerMessage>[];
      _messageError = null;
      _isLoadingMessages = true;
    });
    if (desktop) widget.onInnerViewChanged?.call(true);

    _messageSubscription?.cancel();
    _messageSubscription = widget.repository
        .watchMessages(conversationId: conversation.id)
        .listen(
          (List<CustomerMessage> messages) {
            if (!mounted) return;
            setState(() {
              _messages = messages;
              _isLoadingMessages = false;
              _messageError = null;
            });
            _notifyMobileInnerRoute();
            _scrollMessagesToBottom();
          },
          onError: (Object _, StackTrace _) {
            if (!mounted) return;
            setState(() {
              _isLoadingMessages = false;
              _messageError =
                  'Impossible de charger les messages pour le moment.';
            });
            _notifyMobileInnerRoute();
          },
        );

    if (!desktop) {
      unawaited(
        _pushMobileConversationRoute(
          conversationId: conversation.id,
          replaceCurrentRoute: replaceComposerRoute,
        ),
      );
    }
  }

  void _openNewConversation({CustomerOrderReceipt? order}) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;
    _messageSubscription?.cancel();
    _newMessageController.clear();
    setState(() {
      _selectedConversation = null;
      _selectedOrder = order;
      _messages = const <CustomerMessage>[];
      _messageError = null;
      _showComposer = true;
    });
    if (desktop) {
      widget.onInnerViewChanged?.call(true);
    } else {
      unawaited(_pushMobileComposerRoute());
    }
  }

  void _closeInnerView({bool notifyParent = true}) {
    _messageSubscription?.cancel();
    setState(() {
      _selectedConversation = null;
      _selectedOrder = null;
      _messages = const <CustomerMessage>[];
      _messageError = null;
      _showComposer = false;
    });
    if (notifyParent) widget.onInnerViewChanged?.call(false);
  }

  Future<void> _pushMobileComposerRoute() async {
    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/customer/messaging/new'),
        builder: (BuildContext routeContext) => ValueListenableBuilder<int>(
          valueListenable: _mobileInnerRevision,
          builder: (_, _, _) {
            return _buildMobileInnerShell(
              routeContext: routeContext,
              child: _buildNewConversation(compact: true),
            );
          },
        ),
      ),
    );
    if (!mounted || !_showComposer) return;
    _closeInnerView(notifyParent: false);
  }

  Future<void> _pushMobileConversationRoute({
    required String conversationId,
    required bool replaceCurrentRoute,
  }) async {
    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    final MaterialPageRoute<void> route = MaterialPageRoute<void>(
      settings: RouteSettings(
        name: '/customer/messaging/conversation/$conversationId',
      ),
      builder: (BuildContext routeContext) => ValueListenableBuilder<int>(
        valueListenable: _mobileInnerRevision,
        builder: (_, _, _) {
          return _buildMobileInnerShell(
            routeContext: routeContext,
            child: _buildConversationDetail(compact: true),
          );
        },
      ),
    );

    if (replaceCurrentRoute) {
      await navigator.pushReplacement<void, void>(route);
    } else {
      await navigator.push<void>(route);
    }

    if (!mounted || _selectedConversation?.id != conversationId) return;
    _closeInnerView(notifyParent: false);
  }

  Widget _buildMobileInnerShell({
    required BuildContext routeContext,
    required Widget child,
  }) {
    void leaveMessaging(VoidCallback destination) {
      Navigator.of(routeContext).pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        destination();
      });
    }

    return IzyTelShell(
      title: 'Messagerie IzyTel',
      onBack: () => Navigator.of(routeContext).maybePop(),
      maxContentWidth: 1180,
      bottomNavigationBar: IzyTelBottomNavigation(
        current: IzyTelCustomerDestination.help,
        onHome: () => leaveMessaging(widget.onOpenHome),
        onOffers: () => leaveMessaging(widget.onOpenOffers),
        onHistory: () => leaveMessaging(widget.onOpenHistory),
        onHelp: () => leaveMessaging(widget.onOpenHelp),
      ),
      child: child,
    );
  }

  Future<void> _createConversation() async {
    if (_isCreating) return;
    final String message = _newMessageController.text.trim();
    if (message.isEmpty) {
      IzyTelFeedback.error(context, 'Écrivez un message avant de l’envoyer.');
      return;
    }

    setState(() => _isCreating = true);
    _notifyMobileInnerRoute();
    try {
      final CustomerOrderReceipt? order = _selectedOrder;
      final CustomerConversation conversation = await widget.repository
          .createConversation(
            orderId: order?.id,
            orderReference: order?.reference,
            customerName: widget.customerName,
            locationStatus: widget.orderContext.locationStatus.name,
            latitude: widget.orderContext.latitude,
            longitude: widget.orderContext.longitude,
            message: message,
          );
      if (!mounted) return;
      _newMessageController.clear();
      IzyTelFeedback.success(context, 'Conversation envoyée à IzyTel.');
      _openConversation(conversation);
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerMessaging.createConversation',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        'Impossible d’envoyer la conversation pour le moment.',
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
        _notifyMobileInnerRoute();
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    final CustomerConversation? conversation = _selectedConversation;
    final String message = _replyController.text.trim();
    if (conversation == null || message.isEmpty) return;
    if (conversation.isClosed) {
      IzyTelFeedback.error(context, 'Cette conversation est fermée.');
      return;
    }

    setState(() => _isSending = true);
    _notifyMobileInnerRoute();
    try {
      await widget.repository.sendClientMessage(
        conversationId: conversation.id,
        message: message,
      );
      if (!mounted) return;

      // Le RPC a confirmé l'écriture serveur : on ne dépend pas de Realtime
      // pour afficher le message du client. Une lecture REST canonique est
      // demandée immédiatement ; le stream Realtime reste ensuite l'accélérateur.
      _replyController.clear();
      try {
        final List<CustomerMessage> refreshedMessages = await widget.repository
            .watchMessages(conversationId: conversation.id)
            .first;
        if (!mounted || _selectedConversation?.id != conversation.id) return;
        setState(() {
          _messages = refreshedMessages;
          _isLoadingMessages = false;
          _messageError = null;
        });
        _notifyMobileInnerRoute();
      } catch (_) {
        // Le message est déjà enregistré côté serveur. Si la relecture REST
        // ponctuelle échoue, le stream courant ou son fallback le récupérera.
      }
      _scrollMessagesToBottom();
    } catch (error, stackTrace) {
      IzyTelLog.backendError(
        'CustomerMessaging.sendClientMessage',
        error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      IzyTelFeedback.error(context, 'Impossible d’envoyer le message.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _notifyMobileInnerRoute();
      }
    }
  }

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleShellBack() {
    // Sur desktop le fil/composer reste dans le split-view. Sur mobile ces
    // ecrans sont de vraies routes et ne passent donc jamais par ce callback.
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;
    if (desktop && (_showComposer || _selectedConversation != null)) {
      _closeInnerView();
      return;
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;
    final Widget shell = IzyTelShell(
      title: 'Messagerie IzyTel',
      onBack: _handleShellBack,
      maxContentWidth: 1180,
      actions: desktop
          ? <Widget>[
              TextButton(
                onPressed: widget.onOpenHome,
                child: const Text('Accueil'),
              ),
              TextButton(
                onPressed: widget.onOpenOffers,
                child: const Text('Offres'),
              ),
              TextButton(
                onPressed: widget.onOpenHistory,
                child: const Text('Historique'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: TextButton(
                  onPressed: widget.onOpenHelp,
                  child: const Text('Aide'),
                ),
              ),
            ]
          : null,
      bottomNavigationBar: desktop
          ? null
          : IzyTelBottomNavigation(
              current: IzyTelCustomerDestination.help,
              onHome: widget.onOpenHome,
              onOffers: widget.onOpenOffers,
              onHistory: widget.onOpenHistory,
              onHelp: widget.onOpenHelp,
            ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          if (wide) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(26, 24, 26, 30),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(width: 350, child: _buildConversationList()),
                  const SizedBox(width: 18),
                  Expanded(child: _buildDesktopDetail()),
                ],
              ),
            );
          }

          // Mobile: la liste reste la route de base. Le composer et le fil
          // sont de vraies routes Flutter poussees au-dessus de celle-ci.
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
            child: _buildConversationList(),
          );
        },
      ),
    );

    return shell;
  }

  Widget _buildDesktopDetail() {
    if (_showComposer) {
      return _buildNewConversation(compact: false);
    }
    if (_selectedConversation != null) {
      return _buildConversationDetail(compact: false);
    }
    return IzyTelCard(
      showShadow: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 38,
                  color: CustomerAppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Échangez avec IzyTel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Vos demandes sont prises en charge par un Manager IzyTel. Les Agents chargés d’exécuter les commandes ne participent pas aux conversations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CustomerAppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openNewConversation,
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text('Nouvelle conversation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Colors.white, CustomerAppColors.primarySoft],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CustomerAppColors.primaryContainer),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: CustomerAppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Assistance IzyTel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Un Manager de votre zone vous répond directement dans IzyTel.',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PremiumNewConversationButton(
                onPressed: _openNewConversation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(child: _buildConversationListBody()),
      ],
    );
  }

  Widget _buildConversationListBody() {
    Widget state;
    if (_isLoadingConversations) {
      state = const Center(child: CircularProgressIndicator());
    } else if (_conversationError != null) {
      state = _MessagingState(
        icon: Icons.cloud_off_rounded,
        title: 'Messagerie indisponible',
        message: _conversationError!,
        actionLabel: 'Réessayer',
        onAction: _subscribeConversations,
      );
    } else if (_conversations.isEmpty) {
      state = _MessagingState(
        icon: Icons.mark_chat_unread_outlined,
        title: 'Aucune conversation',
        message:
            'Vous pouvez écrire à IzyTel pour une question générale ou lier votre message à une commande.',
        actionLabel: 'Écrire à IzyTel',
        actionIcon: Icons.add_rounded,
        filledAction: true,
        onAction: _openNewConversation,
      );
    } else {
      state = Column(
        children: _conversations
            .map(
              (CustomerConversation conversation) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ConversationCard(
                  conversation: conversation,
                  selected: conversation.id == _selectedConversation?.id,
                  onTap: () => _openConversation(conversation),
                ),
              ),
            )
            .toList(growable: false),
      );
    }

    // Toujours scrollable, y compris à vide : le pull-to-refresh fonctionne
    // dans tous les états de la messagerie.
    return RefreshIndicator(
      onRefresh: _refreshConversationsOnce,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 360,
                ),
                child: state,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNewConversation({required bool compact}) {
    final List<CustomerOrderReceipt> visibleOrders = widget.orders
        .take(12)
        .toList(growable: false);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 22,
        compact ? 22 : 20,
        compact ? 18 : 22,
        34,
      ),
      children: <Widget>[
        if (!compact)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _closeInnerView,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Conversations'),
            ),
          ),
        Text(
          'Nouvelle conversation',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        const Text(
          'Votre message sera adressé à l’équipe IzyTel et traité par un Manager.',
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        IzyTelCard(
          showShadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Commande concernée',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Facultatif. Lier une commande permet au Manager de retrouver immédiatement le bon dossier.',
                style: TextStyle(
                  color: CustomerAppColors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 13),
              _OrderLinkSelector(
                orders: visibleOrders,
                selectedOrder: _selectedOrder,
                onSelected: (CustomerOrderReceipt? order) {
                  setState(() => _selectedOrder = order);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        IzyTelCard(
          showShadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Votre message',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey<String>('wc3b-new-message-field'),
                controller: _newMessageController,
                minLines: 5,
                maxLines: 9,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Expliquez votre demande avec les informations utiles…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              FilledButton.icon(
                key: const ValueKey<String>('wc3b-create-conversation'),
                onPressed: _isCreating ? null : _createConversation,
                icon: _isCreating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isCreating ? 'Envoi…' : 'Envoyer à IzyTel'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _ManagerRoutingNotice(),
      ],
    );
  }

  Widget _buildConversationDetail({required bool compact}) {
    final CustomerConversation conversation = _selectedConversation!;
    return Column(
      children: <Widget>[
        Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 22,
            16,
            compact ? 18 : 22,
            14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Colors.white, CustomerAppColors.primarySoft],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border(
              bottom: BorderSide(color: CustomerAppColors.outlineSoft),
            ),
          ),
          child: Row(
            children: <Widget>[
              if (!compact) ...<Widget>[
                IconButton(
                  tooltip: 'Conversations',
                  onPressed: _closeInnerView,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: CustomerAppColors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'IzyTel',
                      style: TextStyle(
                        color: CustomerAppColors.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.assignedManagerName?.trim().isNotEmpty == true
                          ? 'Pris en charge par ${conversation.assignedManagerName}'
                          : 'En attente de prise en charge par un Manager',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ConversationStatusBadge(status: conversation.status),
            ],
          ),
        ),
        if (conversation.isOrderLinked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            color: CustomerAppColors.primarySoft,
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 17,
                  color: CustomerAppColors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Commande ${conversation.orderReference}',
                    style: const TextStyle(
                      color: CustomerAppColors.primaryDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: _buildMessages(conversation)),
        _ReplyComposer(
          controller: _replyController,
          isSending: _isSending,
          isClosed: conversation.isClosed,
          isResolved: conversation.isResolved,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  Widget _buildMessages(CustomerConversation conversation) {
    Widget state;
    if (_isLoadingMessages) {
      state = const Center(child: CircularProgressIndicator());
    } else if (_messageError != null) {
      state = _MessagingState(
        icon: Icons.cloud_off_rounded,
        title: 'Messages indisponibles',
        message: _messageError!,
        actionLabel: 'Réessayer',
        onAction: () => _openConversation(conversation),
      );
    } else {
      state = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _messages
            .map((CustomerMessage message) => _MessageBubble(message: message))
            .toList(growable: false),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshMessagesOnce(conversation.id),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ListView(
            key: ValueKey<String>('wc3b-thread-${conversation.id}'),
            controller: _messageScrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: <Widget>[
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 360,
                ),
                child: state,
              ),
            ],
          );
        },
      ),
    );
  }

}

class _PremiumNewConversationButton extends StatelessWidget {
  const _PremiumNewConversationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nouvelle conversation',
      child: Tooltip(
        message: 'Nouvelle conversation',
        child: Material(
          color: CustomerAppColors.primary,
          borderRadius: BorderRadius.circular(15),
          elevation: 0,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1F1D4ED8),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final CustomerConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      onTap: onTap,
      isSelected: selected,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 17,
                  color: CustomerAppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conversation.isOrderLinked
                      ? 'Commande ${conversation.orderReference}'
                      : 'Conversation IzyTel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: CustomerAppColors.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _ConversationStatusBadge(status: conversation.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            conversation.lastMessagePreview.isEmpty
                ? 'Ouvrir la conversation'
                : conversation.lastMessagePreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Icon(
                _senderIcon(conversation.lastSenderType),
                size: 14,
                color: CustomerAppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _senderLabel(conversation.lastSenderType),
                  style: const TextStyle(
                    color: CustomerAppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                _formatRelativeDate(conversation.lastMessageAt),
                style: const TextStyle(
                  color: CustomerAppColors.muted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConversationStatusBadge extends StatelessWidget {
  const _ConversationStatusBadge({required this.status});

  final CustomerConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (status) {
      CustomerConversationStatus.open => (
        CustomerAppColors.warningContainer,
        CustomerAppColors.warning,
      ),
      CustomerConversationStatus.inProgress => (
        CustomerAppColors.primaryContainer,
        CustomerAppColors.primary,
      ),
      CustomerConversationStatus.resolved => (
        CustomerAppColors.successContainer,
        CustomerAppColors.success,
      ),
      CustomerConversationStatus.closed => (
        CustomerAppColors.surfaceContainer,
        CustomerAppColors.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final CustomerMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem ||
        message.senderType == CustomerMessageSenderType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CustomerAppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: CustomerAppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CustomerAppColors.onSurfaceVariant,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bool fromClient = message.isFromClient;
    return Align(
      alignment: fromClient ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 8),
        decoration: BoxDecoration(
          color: fromClient
              ? CustomerAppColors.primary
              : CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromClient ? 16 : 4),
            bottomRight: Radius.circular(fromClient ? 4 : 16),
          ),
          border: fromClient
              ? null
              : Border.all(color: CustomerAppColors.outlineSoft),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fromClient ? 'Vous' : 'Manager IzyTel',
              style: TextStyle(
                color: fromClient
                    ? Colors.white.withValues(alpha: 0.82)
                    : CustomerAppColors.primary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.body,
              style: TextStyle(
                color: fromClient ? Colors.white : CustomerAppColors.onSurface,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatClock(message.createdAt),
              style: TextStyle(
                color: fromClient
                    ? Colors.white.withValues(alpha: 0.7)
                    : CustomerAppColors.muted,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({
    required this.controller,
    required this.isSending,
    required this.isClosed,
    required this.isResolved,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final bool isClosed;
  final bool isResolved;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: CustomerAppColors.outlineSoft),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (isResolved)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Cette conversation est résolue. Envoyer un nouveau message la rouvrira.',
                    style: TextStyle(
                      color: CustomerAppColors.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isClosed)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Cette conversation est fermée. Créez une nouvelle conversation si vous avez encore besoin d’aide.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CustomerAppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('wc3b-reply-field'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message…',
                          counterText: '',
                        ),
                        onSubmitted: (_) => onSend(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey<String>('wc3b-send-message'),
                      tooltip: 'Envoyer',
                      onPressed: isSending ? null : onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: CustomerAppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            CustomerAppColors.primaryContainer,
                        disabledForegroundColor:
                            CustomerAppColors.onSurfaceVariant,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: isSending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderLinkSelector extends StatelessWidget {
  const _OrderLinkSelector({
    required this.orders,
    required this.selectedOrder,
    required this.onSelected,
  });

  final List<CustomerOrderReceipt> orders;
  final CustomerOrderReceipt? selectedOrder;
  final ValueChanged<CustomerOrderReceipt?> onSelected;

  @override
  Widget build(BuildContext context) {
    final String label = selectedOrder == null
        ? 'Aucune commande liée'
        : '${selectedOrder!.reference} · ${selectedOrder!.draft.network?.customerLabel ?? ''}';

    return PopupMenuButton<String>(
      tooltip: 'Choisir une commande',
      onSelected: (String value) {
        if (value == '_none') {
          onSelected(null);
          return;
        }
        for (final CustomerOrderReceipt order in orders) {
          if (order.id == value) {
            onSelected(order);
            return;
          }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: '_none',
          child: Text('Aucune commande liée'),
        ),
        ...orders.map(
          (CustomerOrderReceipt order) => PopupMenuItem<String>(
            value: order.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  order.reference,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${order.draft.network?.customerLabel ?? 'Réseau'} · ${order.draft.beneficiaryNumber?.displayValue ?? ''}',
                  style: const TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CustomerAppColors.outlineSoft),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.receipt_long_outlined,
              color: CustomerAppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CustomerAppColors.onSurface,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: CustomerAppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerRoutingNotice extends StatelessWidget {
  const _ManagerRoutingNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerAppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CustomerAppColors.primaryContainer),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.verified_user_outlined,
            size: 20,
            color: CustomerAppColors.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre demande est transmise à un Manager IzyTel. L’Agent qui exécute une commande n’échange pas directement avec le client.',
              style: TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagingState extends StatelessWidget {
  const _MessagingState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.filledAction = false,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool filledAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CustomerAppColors.primarySoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: CustomerAppColors.primaryContainer),
              ),
              child: Icon(icon, size: 34, color: CustomerAppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 16),
              if (filledAction)
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.arrow_forward_rounded),
                  label: Text(actionLabel!),
                )
              else
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon ?? Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _senderLabel(CustomerMessageSenderType senderType) {
  switch (senderType) {
    case CustomerMessageSenderType.client:
      return 'Vous';
    case CustomerMessageSenderType.manager:
      return 'Manager IzyTel';
    case CustomerMessageSenderType.system:
      return 'IzyTel';
  }
}

IconData _senderIcon(CustomerMessageSenderType senderType) {
  switch (senderType) {
    case CustomerMessageSenderType.client:
      return Icons.person_outline_rounded;
    case CustomerMessageSenderType.manager:
      return Icons.support_agent_rounded;
    case CustomerMessageSenderType.system:
      return Icons.info_outline_rounded;
  }
}

String _formatClock(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _formatRelativeDate(DateTime value) {
  final DateTime local = value.toLocal();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime date = DateTime(local.year, local.month, local.day);
  if (date == today) return _formatClock(local);
  if (date == today.subtract(const Duration(days: 1))) return 'Hier';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}
