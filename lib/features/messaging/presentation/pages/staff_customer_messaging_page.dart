import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _StaffMessagingScope { all, newRequests, inProgress, resolved }

class StaffCustomerMessagingPage extends StatefulWidget {
  const StaffCustomerMessagingPage({
    super.key,
    required this.user,
    required this.repository,
    this.embedded = false,
    this.initialConversationId,
  });

  final AppUser user;
  final CustomerMessagingRepository repository;
  final bool embedded;
  final String? initialConversationId;

  @override
  State<StaffCustomerMessagingPage> createState() =>
      _StaffCustomerMessagingPageState();
}

class _StaffCustomerMessagingPageState extends State<StaffCustomerMessagingPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  StreamSubscription<List<CustomerConversation>>? _inboxSubscription;
  StreamSubscription<List<CustomerMessage>>? _messageSubscription;

  List<CustomerConversation> _conversations = const <CustomerConversation>[];
  List<CustomerMessage> _messages = const <CustomerMessage>[];
  CustomerConversation? _selectedConversation;
  _StaffMessagingScope _scope = _StaffMessagingScope.all;
  String _query = '';
  String? _inboxError;
  String? _messageError;
  bool _loadingInbox = true;
  bool _loadingMessages = false;
  bool _taking = false;
  bool _sending = false;
  bool _resolving = false;
  bool _initialConversationOpened = false;

  bool get _managerMode => widget.user.isManager;
  bool get _adminMode => widget.user.role == UserRole.administrator;

  @override
  void initState() {
    super.initState();
    _subscribeInbox();
  }

  @override
  void dispose() {
    _inboxSubscription?.cancel();
    _messageSubscription?.cancel();
    _searchController.dispose();
    _replyController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _subscribeInbox() {
    _inboxSubscription?.cancel();
    _inboxSubscription = widget.repository.watchManagerInbox().listen(
      (List<CustomerConversation> conversations) {
        if (!mounted) return;
        final String? selectedId = _selectedConversation?.id;
        CustomerConversation? selected;
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
          _loadingInbox = false;
          _inboxError = null;
          if (selectedId != null && selected == null) {
            _messages = const <CustomerMessage>[];
            _messageError = null;
          }
        });

        if (selectedId != null && selected == null) {
          _messageSubscription?.cancel();
          _messageSubscription = null;
        }

        _openInitialConversationIfAvailable(conversations);
      },
      onError: (Object _, StackTrace _) {
        if (!mounted) return;
        setState(() {
          _loadingInbox = false;
          _inboxError =
              'La messagerie clients est momentanément indisponible.';
        });
      },
    );
  }

  void _openInitialConversationIfAvailable(
    List<CustomerConversation> conversations,
  ) {
    if (_initialConversationOpened) return;
    final String id = widget.initialConversationId?.trim() ?? '';
    if (id.isEmpty) {
      _initialConversationOpened = true;
      return;
    }

    CustomerConversation? target;
    for (final CustomerConversation conversation in conversations) {
      if (conversation.id == id) {
        target = conversation;
        break;
      }
    }
    if (target == null) return;

    _initialConversationOpened = true;
    final CustomerConversation resolved = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openConversation(resolved);
    });
  }

  Future<void> _refreshInboxOnce() async {
    try {
      final List<CustomerConversation> conversations =
          await widget.repository.watchManagerInbox().first;
      if (!mounted) return;
      final String? selectedId = _selectedConversation?.id;
      CustomerConversation? selected;
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
        _loadingInbox = false;
        _inboxError = null;
      });
    } catch (_) {
      // Le stream principal et son fallback restent la source de vérité.
    }
  }

  void _openConversation(CustomerConversation conversation) {
    _messageSubscription?.cancel();
    _replyController.clear();
    setState(() {
      _selectedConversation = conversation;
      _messages = const <CustomerMessage>[];
      _loadingMessages = true;
      _messageError = null;
    });
    _messageSubscription = widget.repository
        .watchMessages(conversationId: conversation.id)
        .listen(
          (List<CustomerMessage> messages) {
            if (!mounted || _selectedConversation?.id != conversation.id) {
              return;
            }
            setState(() {
              _messages = messages;
              _loadingMessages = false;
              _messageError = null;
            });
            _scrollMessagesToBottom();
          },
          onError: (Object _, StackTrace _) {
            if (!mounted || _selectedConversation?.id != conversation.id) {
              return;
            }
            setState(() {
              _loadingMessages = false;
              _messageError =
                  'Impossible de charger les messages pour le moment.';
            });
          },
        );
  }

  void _closeConversation() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _replyController.clear();
    setState(() {
      _selectedConversation = null;
      _messages = const <CustomerMessage>[];
      _loadingMessages = false;
      _messageError = null;
    });
  }

  Future<void> _refreshMessagesOnce(String conversationId) async {
    try {
      final List<CustomerMessage> messages = await widget.repository
          .watchMessages(conversationId: conversationId)
          .first;
      if (!mounted || _selectedConversation?.id != conversationId) return;
      setState(() {
        _messages = messages;
        _loadingMessages = false;
        _messageError = null;
      });
      _scrollMessagesToBottom();
    } catch (_) {
      // Realtime/fallback reprendra la lecture si cette relecture ponctuelle échoue.
    }
  }

  Future<void> _takeConversation() async {
    if (!_managerMode || _taking) return;
    final CustomerConversation? conversation = _selectedConversation;
    if (conversation == null || conversation.isAssigned || conversation.isClosed) {
      return;
    }

    setState(() => _taking = true);
    try {
      await widget.repository.takeConversation(
        conversationId: conversation.id,
      );
      await _refreshInboxOnce();
      await _refreshMessagesOnce(conversation.id);
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Conversation prise en charge.');
    } catch (_) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        'Cette conversation a peut-être déjà été prise en charge.',
      );
      await _refreshInboxOnce();
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  Future<void> _sendManagerMessage() async {
    if (!_managerMode || _sending) return;
    final CustomerConversation? conversation = _selectedConversation;
    final String body = _replyController.text.trim();
    if (conversation == null || body.isEmpty) return;
    if (!_isAssignedToCurrentManager(conversation) ||
        conversation.status != CustomerConversationStatus.inProgress) {
      IzyTelFeedback.error(
        context,
        'Prends d’abord en charge cette conversation.',
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.repository.sendManagerMessage(
        conversationId: conversation.id,
        message: body,
      );
      _replyController.clear();
      await _refreshMessagesOnce(conversation.id);
      await _refreshInboxOnce();
    } catch (_) {
      if (!mounted) return;
      IzyTelFeedback.error(context, 'Impossible d’envoyer la réponse.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _resolveConversation() async {
    if (!_managerMode || _resolving) return;
    final CustomerConversation? conversation = _selectedConversation;
    if (conversation == null ||
        !_isAssignedToCurrentManager(conversation) ||
        conversation.status != CustomerConversationStatus.inProgress) {
      return;
    }

    setState(() => _resolving = true);
    try {
      await widget.repository.resolveConversation(
        conversationId: conversation.id,
      );
      await _refreshInboxOnce();
      await _refreshMessagesOnce(conversation.id);
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Conversation marquée comme résolue.');
    } catch (_) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        'Impossible de résoudre la conversation pour le moment.',
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  bool _isAssignedToCurrentManager(CustomerConversation conversation) {
    return conversation.assignedManagerUid?.trim() == widget.user.id.trim();
  }

  List<CustomerConversation> get _visibleConversations {
    final String query = _query.trim().toLowerCase();
    return _conversations.where((CustomerConversation conversation) {
      final bool scopeMatches = switch (_scope) {
        _StaffMessagingScope.all => true,
        _StaffMessagingScope.newRequests =>
          conversation.status == CustomerConversationStatus.open,
        _StaffMessagingScope.inProgress =>
          conversation.status == CustomerConversationStatus.inProgress,
        _StaffMessagingScope.resolved =>
          conversation.status == CustomerConversationStatus.resolved,
      };
      if (!scopeMatches) return false;
      if (query.isEmpty) return true;
      return conversation.customerName.toLowerCase().contains(query) ||
          (conversation.orderReference ?? '').toLowerCase().contains(query) ||
          conversation.lastMessagePreview.toLowerCase().contains(query) ||
          (conversation.assignedManagerName ?? '').toLowerCase().contains(query) ||
          conversation.status.label.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  int _count(CustomerConversationStatus status) => _conversations
      .where((CustomerConversation conversation) => conversation.status == status)
      .length;

  void _scrollMessagesToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messageScrollController.hasClients) return;
      _messageScrollController.animateTo(
        _messageScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 940;
        final Widget body = _selectedConversation == null
            ? _emptyDetail()
            : _conversationDetail(wide: wide);
        if (!wide && _selectedConversation != null) return body;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: wide ? 390 : constraints.maxWidth,
              child: _inboxPane(),
            ),
            if (wide) ...<Widget>[
              const SizedBox(width: 18),
              Expanded(child: body),
            ],
          ],
        );
      },
    );

    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _embeddedHeader(),
            const SizedBox(height: 18),
            SizedBox(height: 720, child: content),
          ],
        ),
      );
    }

    return PopScope(
      canPop: _selectedConversation == null,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_selectedConversation != null) {
          _closeConversation();
        }
      },
      child: Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text('Messagerie clients'),
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: content,
        ),
      ),
    ),
    );
  }

  Widget _embeddedHeader() {
    return IzyTelPageHeader(
      title: 'Messagerie clients',
      subtitle: _managerMode
          ? 'Prends en charge les conversations clients et réponds depuis IzyTel.'
          : 'Supervise les conversations Client ↔ Manager en lecture seule.',
      actions: <Widget>[
        IconButton(
          tooltip: 'Actualiser',
          onPressed: _refreshInboxOnce,
          icon: const Icon(Symbols.refresh_rounded),
        ),
      ],
    );
  }

  Widget _inboxPane() {
    final List<CustomerConversation> visible = _visibleConversations;
    return IzyTelSurface(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _managerMode ? 'Boîte clients · votre zone' : 'Supervision',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _managerMode
                                ? 'Demandes clients routées vers votre périmètre territorial.'
                                : 'Lecture seule de tous les échanges clients.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: IzyTelColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualiser',
                      onPressed: _refreshInboxOnce,
                      icon: const Icon(Symbols.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('wc3c-staff-message-search'),
                  controller: _searchController,
                  onChanged: (String value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'Référence, statut ou message…',
                    prefixIcon: Icon(Symbols.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _scopeChip(_StaffMessagingScope.all, 'Toutes', _conversations.length),
                      const SizedBox(width: 8),
                      _scopeChip(
                        _StaffMessagingScope.newRequests,
                        'Nouvelles',
                        _count(CustomerConversationStatus.open),
                      ),
                      const SizedBox(width: 8),
                      _scopeChip(
                        _StaffMessagingScope.inProgress,
                        'En cours',
                        _count(CustomerConversationStatus.inProgress),
                      ),
                      const SizedBox(width: 8),
                      _scopeChip(
                        _StaffMessagingScope.resolved,
                        'Résolues',
                        _count(CustomerConversationStatus.resolved),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshInboxOnce,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  Widget state;
                  if (_loadingInbox) {
                    state = const Center(child: CircularProgressIndicator());
                  } else if (_inboxError != null) {
                    state = _errorState(_inboxError!, _subscribeInbox);
                  } else if (visible.isEmpty) {
                    state = const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Aucune conversation dans cette vue.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else {
                    state = Column(
                      children: visible
                          .map((CustomerConversation item) => Column(
                                children: <Widget>[
                                  _conversationTile(item),
                                  const Divider(height: 1),
                                ],
                              ))
                          .toList(growable: false),
                    );
                  }
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.hasBoundedHeight
                              ? constraints.maxHeight
                              : 420,
                        ),
                        child: state,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scopeChip(_StaffMessagingScope scope, String label, int count) {
    return ChoiceChip(
      selected: _scope == scope,
      onSelected: (_) => setState(() => _scope = scope),
      label: Text('$label · $count'),
    );
  }

  Widget _conversationTile(CustomerConversation conversation) {
    final bool selected = _selectedConversation?.id == conversation.id;
    final Color statusColor = _statusColor(conversation.status);
    return Material(
      color: selected ? IzyTelColors.primary.withAlpha(18) : Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('wc3c-conversation-${conversation.id}'),
        onTap: () => _openConversation(conversation),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: IzyTelColors.primary.withAlpha(18),
                child: const Icon(
                  Symbols.person_rounded,
                  color: IzyTelColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            conversation.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            conversation.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (conversation.orderReference != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        'Commande ${conversation.orderReference}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: IzyTelColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessagePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      conversation.assignedManagerName == null
                          ? 'En attente de prise en charge'
                          : 'Manager : ${conversation.assignedManagerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IzyTelColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyDetail() {
    return IzyTelSurface(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: IzyTelColors.primary.withAlpha(18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.forum_rounded,
                  color: IzyTelColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _managerMode
                    ? 'Sélectionne une conversation'
                    : 'Supervision des échanges',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _managerMode
                    ? 'Prends en charge une nouvelle demande, réponds au client puis marque-la comme résolue.'
                    : 'Ouvre une conversation pour consulter le fil Client ↔ Manager. L’Administrateur n’écrit pas à la place du Manager.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversationDetail({required bool wide}) {
    final CustomerConversation conversation = _selectedConversation!;
    final bool ownedByManager = _isAssignedToCurrentManager(conversation);
    final bool canReply = _managerMode &&
        ownedByManager &&
        conversation.status == CustomerConversationStatus.inProgress;
    final bool canTake = _managerMode &&
        !conversation.isAssigned &&
        !conversation.isClosed &&
        conversation.status == CustomerConversationStatus.open;

    return IzyTelSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: <Widget>[
                if (!wide)
                  IconButton(
                    key: const ValueKey<String>('wc3c-back-to-inbox'),
                    onPressed: _closeConversation,
                    icon: const Icon(Symbols.arrow_back_rounded),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        conversation.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (conversation.orderReference != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Commande ${conversation.orderReference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: IzyTelColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        conversation.assignedManagerName == null
                            ? 'En attente de prise en charge par un Manager'
                            : 'Prise en charge par ${conversation.assignedManagerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: IzyTelColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _statusBadge(conversation.status),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messageError != null
                ? _errorState(
                    _messageError!,
                    () => _openConversation(conversation),
                  )
                : RefreshIndicator(
                    onRefresh: () => _refreshMessagesOnce(conversation.id),
                    child: ListView.builder(
                      key: const ValueKey<String>('wc3c-message-list'),
                      controller: _messageScrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                      itemCount: _messages.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _messageBubble(_messages[index]);
                      },
                    ),
                  ),
          ),
          const Divider(height: 1),
          if (_adminMode)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Icon(Symbols.visibility_rounded, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supervision en lecture seule : les réponses restent réservées au Manager.',
                    ),
                  ),
                ],
              ),
            )
          else if (canTake)
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey<String>('wc3c-take-conversation'),
                  onPressed: _taking ? null : _takeConversation,
                  icon: _taking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.person_check_rounded),
                  label: Text(
                    _taking ? 'Prise en charge…' : 'Prendre en charge',
                  ),
                ),
              ),
            )
          else if (canReply)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const ValueKey<String>('wc3c-manager-reply'),
                          controller: _replyController,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            hintText: 'Répondre au client…',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _sendManagerMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        key: const ValueKey<String>('wc3c-send-manager-message'),
                        tooltip: 'Envoyer',
                        onPressed: _sending ? null : _sendManagerMessage,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Symbols.send_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey<String>('wc3c-resolve-conversation'),
                      onPressed: _resolving ? null : _resolveConversation,
                      icon: const Icon(Symbols.task_alt_rounded),
                      label: Text(
                        _resolving ? 'Résolution…' : 'Marquer comme résolue',
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                conversation.status == CustomerConversationStatus.resolved
                    ? 'Conversation résolue. Une réponse du client la rouvrira automatiquement.'
                    : conversation.isClosed
                    ? 'Cette conversation est fermée.'
                    : conversation.isAssigned && !ownedByManager
                    ? 'Cette conversation est prise en charge par un autre Manager.'
                    : 'La conversation doit être prise en charge avant de répondre.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IzyTelColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageBubble(CustomerMessage message) {
    final bool client = message.senderType == CustomerMessageSenderType.client;
    final bool manager = message.senderType == CustomerMessageSenderType.manager;
    if (message.isSystem || message.senderType == CustomerMessageSenderType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: IzyTelColors.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    final Alignment alignment = manager ? Alignment.centerRight : Alignment.centerLeft;
    final Color background = manager ? IzyTelColors.primary : Colors.white;
    final Color foreground = manager ? Colors.white : IzyTelColors.textPrimary;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: manager ? null : Border.all(color: IzyTelColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              client ? 'Client' : (message.senderName ?? 'Manager IzyTel'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground.withAlpha(manager ? 220 : 190),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeLabel(message.createdAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground.withAlpha(manager ? 190 : 150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(CustomerConversationStatus status) {
    final Color color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Color _statusColor(CustomerConversationStatus status) {
    return switch (status) {
      CustomerConversationStatus.open => IzyTelColors.warning,
      CustomerConversationStatus.inProgress => IzyTelColors.primary,
      CustomerConversationStatus.resolved => IzyTelColors.success,
      CustomerConversationStatus.closed => IzyTelColors.textMuted,
    };
  }

  Widget _errorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Symbols.cloud_off_rounded, size: 34),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final DateTime local = value.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
