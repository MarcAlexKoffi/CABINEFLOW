import 'dart:async';

import 'package:cabine_flow/core/navigation/customer_web_history.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/customer_order/data/acquisition/customer_acquisition_source.dart';
import 'package:cabine_flow/features/customer_order/data/geolocation/customer_geolocation.dart';
import 'package:cabine_flow/features/customer_order/data/local/customer_location_consent_store.dart';
import 'package:cabine_flow/features/customer_order/data/local/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/supabase_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/firestore_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/operational_customer_order_context_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_location_consent_store.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_order_session_store.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_beneficiary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_catalog_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_confirmation_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_home_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_identification_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_network_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_offer_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_history_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_order_recovery_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_payment_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_service_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/pages/customer_summary_page.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_location_consent_dialog.dart';
import 'package:cabine_flow/features/messaging/data/repositories/operational_customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/domain/models/customer_conversation.dart';
import 'package:cabine_flow/features/messaging/domain/repositories/customer_messaging_repository.dart';
import 'package:cabine_flow/features/messaging/presentation/pages/customer_messaging_page.dart';
import 'package:cabine_flow/features/support/data/repositories/operational_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/pages/customer_help_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';

enum _CustomerSurface { home, order, catalog, history, help, messaging, recovery }

class CustomerOrderFlowPage extends StatefulWidget {
  const CustomerOrderFlowPage({super.key, this.offerRepository});

  final CustomerOfferRepository? offerRepository;

  @override
  State<CustomerOrderFlowPage> createState() => _CustomerOrderFlowPageState();
}

class _CustomerOrderFlowPageState extends State<CustomerOrderFlowPage> {
  late final CustomerOrderViewModel _viewModel;
  late final CustomerOfferRepository _offerRepository;
  late final SupportRequestRepository _supportRequestRepository;
  late final CustomerMessagingRepository _messagingRepository;
  late final CustomerWebHistoryController _webHistory;
  late final CustomerGeolocationService _geolocationService;
  late final CustomerLocationConsentStore _locationConsentStore;

  late final CustomerOrderRepository _orderRepository;
  final CustomerOrderSessionStore _sessionStore =
      BrowserCustomerOrderSessionStore();
  final List<CustomerWebHistoryEntry> _navigationStack =
      <CustomerWebHistoryEntry>[];

  _CustomerSurface _surface = _CustomerSurface.home;
  int _lastObservedStep = 1;
  bool _suppressHistoryRecording = false;
  bool _initialLocationPromptShown = false;
  bool _messagingRouteActive = false;
  bool _recoveryRouteActive = false;
  bool _messagingInnerActive = false;
  int _messagingInnerResetToken = 0;
  CustomerWebHistoryEntry? _messagingReturnEntry;
  StreamSubscription<List<CustomerConversation>>? _customerMessagingAlertsSub;
  final Map<String, DateTime> _customerConversationLastMessageAt =
      <String, DateTime>{};
  bool _customerMessagingAlertsSeeded = false;

  static const int _messagingListHistoryStep = 0;
  static const int _messagingInnerHistoryStep = 1;

  @override
  void initState() {
    super.initState();
    _offerRepository =
        widget.offerRepository ??
        (Firebase.apps.isNotEmpty
            ? SupabaseBootstrap.isInitialized
                  ? SupabaseCustomerOfferRepository()
                  : FirestoreCustomerOfferRepository()
            : const FakeCustomerOfferRepository());
    _supportRequestRepository = createOperationalSupportRequestRepository();
    _messagingRepository = createOperationalCustomerMessagingRepository();
    _geolocationService = createCustomerGeolocationService();
    _locationConsentStore = createCustomerLocationConsentStore();
    _orderRepository = FirestoreCustomerOrderRepository();
    final String? acquisitionSourceCode = resolveCustomerAcquisitionSourceCode();
    _viewModel = CustomerOrderViewModel(
      orderRepository: _orderRepository,
      sessionStore: _sessionStore,
      orderContextRepository: createOperationalCustomerOrderContextRepository(),
      orderContext: CustomerOrderContextDraft(
        sourceCode: acquisitionSourceCode,
      ),
    );
    _lastObservedStep = _viewModel.currentStep;
    _viewModel.addListener(_handleViewModelNavigationChanged);

    _webHistory = createCustomerWebHistory(onPop: _handleBrowserHistoryPop);
    final CustomerWebHistoryEntry initialEntry = _entryFor(
      _CustomerSurface.home,
    );
    _navigationStack.add(initialEntry);
    _webHistory.replace(initialEntry);

    unawaited(_initializeCustomerExperience());
  }

  Future<void> _initializeCustomerExperience() async {
    await _viewModel.initialize();
    if (!mounted) return;

    _startCustomerMessagingAlerts();

    if (!kIsWeb) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showInitialLocationPrompt());
      }
    });
  }

  void _startCustomerMessagingAlerts() {
    _customerMessagingAlertsSub?.cancel();
    _customerMessagingAlertsSub = _messagingRepository
        .watchCustomerConversations()
        .listen(
          (List<CustomerConversation> conversations) {
            if (!mounted) return;

            if (!_customerMessagingAlertsSeeded) {
              _customerConversationLastMessageAt
                ..clear()
                ..addEntries(
                  conversations.map(
                    (CustomerConversation conversation) => MapEntry<String, DateTime>(
                      conversation.id,
                      conversation.lastMessageAt,
                    ),
                  ),
                );
              _customerMessagingAlertsSeeded = true;
              return;
            }

            for (final CustomerConversation conversation in conversations) {
              final DateTime? previous =
                  _customerConversationLastMessageAt[conversation.id];
              _customerConversationLastMessageAt[conversation.id] =
                  conversation.lastMessageAt;

              if (previous == null ||
                  !conversation.lastMessageAt.isAfter(previous) ||
                  conversation.lastSenderType !=
                      CustomerMessageSenderType.manager) {
                continue;
              }

              final String preview = conversation.lastMessagePreview.trim();
              IzyTelFeedback.show(
                context,
                preview.isEmpty
                    ? 'IzyTel vous a répondu dans la messagerie.'
                    : 'IzyTel : $preview',
                duration: const Duration(seconds: 5),
              );
            }
          },
          onError: (Object _, StackTrace _) {
            // La notification in-app est un confort. La messagerie garde son
            // propre stream/fallback et ne doit jamais etre bloquee ici.
          },
        );
  }

  Future<void> _showInitialLocationPrompt() async {
    if (_initialLocationPromptShown || _viewModel.orderContext.hasLocation) {
      return;
    }

    _initialLocationPromptShown = true;

    if (_locationConsentStore.hasGrantedConsent) {
      final CustomerLocationCapture silentCapture =
          await _geolocationService.requestCurrentLocation();

      if (!mounted) {
        return;
      }

      if (silentCapture.isGranted) {
        await _viewModel.applyOrderContext(
          silentCapture.applyTo(_viewModel.orderContext),
        );
        return;
      }

      if (silentCapture.status == CustomerLocationStatus.denied) {
        _locationConsentStore.clearGrantedConsent();
      } else {
        // A temporary browser/GPS failure must not make the consent popup
        // reappear for a customer who already granted location access.
        return;
      }
    }

    final CustomerLocationCapture? capture =
        await showCustomerLocationConsentDialog(
          context: context,
          moment: CustomerLocationPromptMoment.firstVisit,
          geolocationService: _geolocationService,
        );

    if (!mounted || capture == null) {
      return;
    }

    if (capture.isGranted) {
      _locationConsentStore.markGrantedConsent();
    }

    await _viewModel.applyOrderContext(
      capture.applyTo(_viewModel.orderContext),
    );
  }

  @override
  void dispose() {
    _customerMessagingAlertsSub?.cancel();
    _webHistory.dispose();
    _viewModel.removeListener(_handleViewModelNavigationChanged);
    _viewModel.dispose();
    super.dispose();
  }

  CustomerWebHistoryEntry _entryFor(
    _CustomerSurface surface, {
    int? step,
  }) {
    final int resolvedStep = step ??
        (surface == _CustomerSurface.messaging
            ? _messagingListHistoryStep
            : _viewModel.currentStep);
    return CustomerWebHistoryEntry(
      location: surface.name,
      step: resolvedStep,
    );
  }

  _CustomerSurface _surfaceFromLocation(String location) {
    for (final _CustomerSurface item in _CustomerSurface.values) {
      if (item.name == location) {
        return item;
      }
    }
    return _CustomerSurface.home;
  }

  void _runWithoutHistory(VoidCallback action) {
    _suppressHistoryRecording = true;
    try {
      action();
    } finally {
      _lastObservedStep = _viewModel.currentStep;
      _suppressHistoryRecording = false;
    }
  }

  void _pushHistoryEntry(CustomerWebHistoryEntry entry) {
    if (_navigationStack.isNotEmpty &&
        _navigationStack.last.matches(entry)) {
      return;
    }
    _navigationStack.add(entry);
    _webHistory.push(entry);
  }

  void _navigateTo(_CustomerSurface surface) {
    if (_surface == _CustomerSurface.messaging &&
        surface != _CustomerSurface.messaging &&
        _messagingInnerActive) {
      _collapseMessagingInnerHistory();
    }

    if (surface != _CustomerSurface.messaging) {
      _messagingInnerActive = false;
      if (_surface == _CustomerSurface.messaging) {
        _messagingReturnEntry = null;
      }
    }
    final CustomerWebHistoryEntry entry = _entryFor(surface);
    if (_surface != surface) {
      setState(() => _surface = surface);
    }
    _pushHistoryEntry(entry);
  }

  void _collapseMessagingInnerHistory() {
    _messagingInnerActive = false;
    _messagingInnerResetToken += 1;
    final CustomerWebHistoryEntry listEntry = _entryFor(
      _CustomerSurface.messaging,
      step: _messagingListHistoryStep,
    );
    if (_navigationStack.isNotEmpty &&
        _navigationStack.last.location == _CustomerSurface.messaging.name) {
      _navigationStack[_navigationStack.length - 1] = listEntry;
    }
    _webHistory.replace(listEntry);
  }

  void _openHome() => _navigateTo(_CustomerSurface.home);

  void _startOrder() {
    _runWithoutHistory(_viewModel.restart);
    _navigateTo(_CustomerSurface.order);
  }

  void _startServiceOrder(CustomerService service) {
    _runWithoutHistory(() {
      _viewModel.restart();
      _viewModel.selectService(service);
    });
    _navigateTo(_CustomerSurface.order);
  }

  void _startOfferOrder(CustomerOffer offer) {
    _runWithoutHistory(() {
      _viewModel.restart();
      final CustomerService service = offer.type == CustomerOfferType.internet
          ? CustomerService.internetSubscription
          : CustomerService.calls;
      _viewModel.selectService(service);
      _viewModel.selectNetwork(offer.network);
      _viewModel.selectOffer(offer);
    });
    _navigateTo(_CustomerSurface.order);
  }

  void _openHistory() => _navigateTo(_CustomerSurface.history);

  void _openHelp() => _navigateTo(_CustomerSurface.help);

  void _openMessaging() {
    // WC8: la messagerie n'est plus un simple etat dans l'AnimatedSwitcher.
    // Elle est poussee comme une vraie route Flutter au-dessus de l'ecran
    // courant. Le bouton Retour Android/Chrome remonte donc naturellement
    // conversation -> liste -> ecran d'origine (Aide, identification, etc.).
    unawaited(_pushMessagingRoute());
  }

  Future<void> _pushMessagingRoute() async {
    if (!mounted || _messagingRouteActive) return;

    _messagingRouteActive = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/customer/messaging'),
          builder: (BuildContext routeContext) {
            void leaveTo(_CustomerSurface target) {
              Navigator.of(routeContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _navigateTo(target);
              });
            }

            return CustomerMessagingPage(
              repository: _messagingRepository,
              orders: _viewModel.customerOrders,
              orderContext: _viewModel.orderContext,
              customerName: _viewModel.draft.identity?.name,
              onBack: () => Navigator.of(routeContext).maybePop(),
              onOpenHome: () => leaveTo(_CustomerSurface.home),
              onOpenOffers: () => leaveTo(_CustomerSurface.catalog),
              onOpenHistory: () => leaveTo(_CustomerSurface.history),
              onOpenHelp: () => leaveTo(_CustomerSurface.help),
            );
          },
        ),
      );
    } finally {
      // Le popstate produit par la route Messagerie doit etre laisse a Flutter
      // pendant tout le depilage. On ne reactive l'historique metier qu'apres
      // le frame qui a restaure l'ecran d'origine.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messagingRouteActive = false;
      });
    }
  }

  void _openRecovery() {
    _viewModel.clearRecoveryError();
    unawaited(_pushRecoveryRoute());
  }

  Future<void> _pushRecoveryRoute() async {
    if (!mounted || _recoveryRouteActive) return;

    _recoveryRouteActive = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/customer/recovery'),
          builder: (BuildContext routeContext) {
            void leaveTo(_CustomerSurface target) {
              Navigator.of(routeContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _navigateTo(target);
              });
            }

            void showRecoveredOrder() {
              Navigator.of(routeContext).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _showRecoveredOrder();
              });
            }

            return CustomerOrderRecoveryPage(
              viewModel: _viewModel,
              onBack: () => Navigator.of(routeContext).maybePop(),
              onRecovered: showRecoveredOrder,
              onOpenHome: () => leaveTo(_CustomerSurface.home),
              onOpenOffers: () => leaveTo(_CustomerSurface.catalog),
              onOpenHistory: () => leaveTo(_CustomerSurface.history),
              onOpenHelp: () => leaveTo(_CustomerSurface.help),
            );
          },
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _recoveryRouteActive = false;
      });
    }
  }

  void _openCatalog() => _navigateTo(_CustomerSurface.catalog);

  void _showRecoveredOrder() => _navigateTo(_CustomerSurface.order);

  void _openOrder(CustomerOrderReceipt order) {
    _runWithoutHistory(() => _viewModel.resumeOrder(order));
    _navigateTo(_CustomerSurface.order);
  }

  CustomerWebHistoryEntry? _resolveBackTarget() {
    if (_navigationStack.length <= 1) {
      return null;
    }

    // La confirmation est terminale : un Retour ne doit jamais rouvrir
    // le paiement ou un formulaire deja valide. On revient a la derniere
    // surface principale qui precedait le parcours de commande.
    if (_surface == _CustomerSurface.order &&
        _viewModel.currentStep == CustomerOrderViewModel.totalSteps) {
      for (int index = _navigationStack.length - 2; index >= 0; index--) {
        final CustomerWebHistoryEntry candidate = _navigationStack[index];
        if (candidate.location != _CustomerSurface.order.name) {
          return candidate;
        }
      }
    }

    return _navigationStack[_navigationStack.length - 2];
  }

  int _findNavigationEntryIndex(CustomerWebHistoryEntry entry) {
    for (int index = _navigationStack.length - 1; index >= 0; index--) {
      if (_navigationStack[index].matches(entry)) {
        return index;
      }
    }
    return -1;
  }

  void _requestBack() {
    final CustomerWebHistoryEntry? previous = _resolveBackTarget();
    if (previous == null) {
      if (_surface != _CustomerSurface.home) {
        _replaceWithHome();
      }
      return;
    }

    // Un bouton Retour de l'interface doit etre deterministe et immediat.
    // Il ne depend plus de window.history.back(), qui peut sauter plusieurs
    // entrees sur Chrome Android/PWA lorsque Flutter et l'History API ont
    // manipule la meme URL. Le brouillon reste intact : seule l'etape visible
    // est restauree.
    _restoreHistoryEntry(previous);

    if (_webHistory.supported) {
      // On aligne l'entree navigateur courante sur l'ecran visible. Le
      // gestionnaire popstate ci-dessous sait ignorer un eventuel doublon
      // lors du prochain Retour navigateur/Android.
      _webHistory.replace(previous);
    }
  }

  void _replaceWithHome() {
    final CustomerWebHistoryEntry home = _entryFor(_CustomerSurface.home);
    _navigationStack
      ..clear()
      ..add(home);
    _webHistory.replace(home);
    if (_surface != _CustomerSurface.home) {
      setState(() => _surface = _CustomerSurface.home);
    }
  }

  void _handleViewModelNavigationChanged() {
    final int currentStep = _viewModel.currentStep;
    final int previousStep = _lastObservedStep;
    _lastObservedStep = currentStep;

    if (_suppressHistoryRecording ||
        _surface != _CustomerSurface.order ||
        currentStep == previousStep) {
      return;
    }

    if (currentStep > previousStep) {
      _pushHistoryEntry(
        _entryFor(_CustomerSurface.order, step: currentStep),
      );
      return;
    }

    // Safety net for a legacy page that might still call viewModel.goBack()
    // directly. Keep browser history and the visible step aligned.
    if (_navigationStack.length > 1) {
      final CustomerWebHistoryEntry previous =
          _navigationStack[_navigationStack.length - 2];
      if (previous.location == _CustomerSurface.order.name &&
          previous.step == currentStep) {
        if (_webHistory.supported) {
          _webHistory.back();
        } else {
          _restoreHistoryEntry(previous);
        }
        return;
      }
    }

    final CustomerWebHistoryEntry current = _entryFor(
      _CustomerSurface.order,
      step: currentStep,
    );
    if (_navigationStack.isNotEmpty) {
      _navigationStack[_navigationStack.length - 1] = current;
    }
    _webHistory.replace(current);
  }

  void _handleMessagingInnerViewChanged(bool active) {
    if (active) {
      if (_messagingInnerActive) return;
      _messagingInnerActive = true;
      _pushHistoryEntry(
        _entryFor(
          _CustomerSurface.messaging,
          step: _messagingInnerHistoryStep,
        ),
      );
      return;
    }

    _messagingInnerActive = false;
  }

  void _handleBrowserHistoryPop(CustomerWebHistoryEntry? entry) {
    if (!mounted) return;

    // Messagerie et recuperation sont de vraies routes Flutter. Pendant leur
    // depilage, le Navigator est l'unique consommateur du geste Retour.
    if (_messagingRouteActive || _recoveryRouteActive) return;

    // Compatibilite avec l'ancienne surface Messagerie si elle est restauree
    // depuis un historique deja existant.
    if (_surface == _CustomerSurface.messaging) {
      if (_messagingInnerActive) {
        final CustomerWebHistoryEntry listEntry = _entryFor(
          _CustomerSurface.messaging,
          step: _messagingListHistoryStep,
        );
        _webHistory.replace(listEntry);
        _restoreHistoryEntry(listEntry);
        return;
      }

      final CustomerWebHistoryEntry? origin = _messagingReturnEntry;
      if (origin != null) {
        _webHistory.replace(origin);
        _restoreHistoryEntry(origin);
        _messagingReturnEntry = null;
        return;
      }
    }

    final CustomerWebHistoryEntry? current = _navigationStack.isEmpty
        ? null
        : _navigationStack.last;
    final CustomerWebHistoryEntry? expectedPrevious = _resolveBackTarget();

    if (entry == null) {
      // Certaines versions de Chrome/PWA peuvent renvoyer un state nul.
      // Le retour reste alors base sur notre pile applicative, une seule
      // etape a la fois, puis on repare l'historique navigateur.
      if (expectedPrevious != null) {
        _restoreHistoryEntry(expectedPrevious);
        _webHistory.push(expectedPrevious);
      }
      return;
    }

    // Une commande confirmee est terminale. Le Retour navigateur peut traverser
    // les anciennes entrees de commande, mais elles ne sont jamais reaffichees.
    if (current != null &&
        current.location == _CustomerSurface.order.name &&
        current.step == CustomerOrderViewModel.totalSteps &&
        entry.location == _CustomerSurface.order.name &&
        entry.step < CustomerOrderViewModel.totalSteps) {
      _webHistory.back();
      return;
    }

    // Un Retour explicite de l'interface utilise replaceState pour afficher
    // immediatement l'etape precedente. Il peut donc laisser deux entrees
    // navigateur consecutives qui decrivent le meme ecran. On saute ce doublon
    // sans faire reculer une seconde fois la pile IzyTel.
    if (current != null && entry.matches(current)) {
      if (expectedPrevious != null) {
        _webHistory.back();
      }
      return;
    }

    if (expectedPrevious != null && entry.matches(expectedPrevious)) {
      _restoreHistoryEntry(expectedPrevious);
      return;
    }

    final int entryIndex = _findNavigationEntryIndex(entry);
    if (entryIndex < 0) {
      // L'entree n'est plus dans la pile courante : c'est typiquement un
      // Retour avant suivi d'un Avancer navigateur. On restaure cette entree
      // plutot que de la confondre avec un nouveau Retour.
      _restoreHistoryEntry(entry);
      return;
    }

    if (expectedPrevious != null) {
      // Le navigateur a saute plusieurs entrees (symptome observe sur Chrome
      // Android). IzyTel ne suit pas ce saut : il recule exactement d'un niveau
      // et recree une entree coherente pour le prochain geste Retour.
      _restoreHistoryEntry(expectedPrevious);
      _webHistory.push(expectedPrevious);
      return;
    }

    _restoreHistoryEntry(entry);
  }

  void _restoreHistoryEntry(CustomerWebHistoryEntry entry) {
    final _CustomerSurface target = _surfaceFromLocation(entry.location);

    int matchingIndex = -1;
    for (int index = _navigationStack.length - 1; index >= 0; index--) {
      if (_navigationStack[index].matches(entry)) {
        matchingIndex = index;
        break;
      }
    }
    if (matchingIndex >= 0) {
      _navigationStack.removeRange(matchingIndex + 1, _navigationStack.length);
    } else {
      _navigationStack.add(entry);
    }

    _suppressHistoryRecording = true;
    try {
      bool messagingListRestored = false;
      if (target == _CustomerSurface.order) {
        _viewModel.restoreNavigationStep(entry.step);
      } else if (target == _CustomerSurface.messaging &&
          entry.step == _messagingListHistoryStep) {
        _messagingInnerActive = false;
        _messagingInnerResetToken += 1;
        messagingListRestored = true;
      }
      _lastObservedStep = _viewModel.currentStep;
      if (mounted && (_surface != target || messagingListRestored)) {
        setState(() => _surface = target);
      }
    } finally {
      _suppressHistoryRecording = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: switch (_surface) {
            _CustomerSurface.recovery => CustomerOrderRecoveryPage(
              key: const ValueKey<String>('customer-recovery'),
              viewModel: _viewModel,
              onBack: _requestBack,
              onRecovered: _showRecoveredOrder,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
            ),
            _CustomerSurface.help => CustomerHelpPage(
              key: const ValueKey<String>('customer-help'),
              onBack: _requestBack,
              onOpenRecovery: _openRecovery,
              onOpenMessaging: _openMessaging,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
            ),
            _CustomerSurface.messaging => CustomerMessagingPage(
              key: const ValueKey<String>('customer-messaging'),
              repository: _messagingRepository,
              orders: _viewModel.customerOrders,
              orderContext: _viewModel.orderContext,
              customerName: _viewModel.draft.identity?.name,
              onBack: _requestBack,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
              onInnerViewChanged: _handleMessagingInnerViewChanged,
              resetInnerViewToken: _messagingInnerResetToken,
            ),
            _CustomerSurface.history => CustomerOrderHistoryPage(
              key: const ValueKey<String>('customer-history'),
              viewModel: _viewModel,
              onBack: _requestBack,
              onOpenOrder: _openOrder,
              onOpenHome: _openHome,
              onOpenOffers: _openCatalog,
              onOpenHelp: _openHelp,
            ),
            _CustomerSurface.catalog => CustomerCatalogPage(
              key: const ValueKey<String>('customer-catalog'),
              offerRepository: _offerRepository,
              onBack: _requestBack,
              onChooseOffer: _startOfferOrder,
              onStartOrder: _startOrder,
              onStartDirectTransfer: () =>
                  _startServiceOrder(CustomerService.unitTransfer),
              onOpenHome: _openHome,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
            ),
            _CustomerSurface.home => CustomerHomePage(
              key: const ValueKey<String>('customer-home'),
              offerRepository: _offerRepository,
              onStartOrder: _startOrder,
              onStartService: _startServiceOrder,
              onChooseOffer: _startOfferOrder,
              onOpenOffers: _openCatalog,
              onOpenHistory: _openHistory,
              onOpenHelp: _openHelp,
              onOpenRecovery: _openRecovery,
            ),
            _CustomerSurface.order => _buildCurrentStep(),
          },
        );
      },
    );
  }

  Widget _buildCurrentStep() {
    switch (_viewModel.currentStep) {
      case 1:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onOpenRecovery: _openRecovery,
          onOpenMessaging: _openMessaging,
          onResumeOrder: _openOrder,
          onBackToHome: _requestBack,
        );
      case 2:
        return CustomerServicePage(
          key: const ValueKey<int>(2),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 3:
        return CustomerNetworkPage(
          key: const ValueKey<int>(3),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 4:
        return CustomerOfferPage(
          key: const ValueKey<int>(4),
          viewModel: _viewModel,
          offerRepository: _offerRepository,
          onBack: _requestBack,
        );
      case 5:
        return CustomerBeneficiaryPage(
          key: const ValueKey<int>(5),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 6:
        return CustomerSummaryPage(
          key: const ValueKey<int>(6),
          viewModel: _viewModel,
          onBack: _requestBack,
          geolocationService: _geolocationService,
          locationConsentStore: _locationConsentStore,
        );
      case 7:
        return CustomerPaymentPage(
          key: const ValueKey<int>(7),
          viewModel: _viewModel,
          onBack: _requestBack,
        );
      case 8:
        return CustomerConfirmationPage(
          key: const ValueKey<int>(8),
          viewModel: _viewModel,
          onOpenHome: _openHome,
          onOpenOffers: _openCatalog,
          onOpenHistory: _openHistory,
          onOpenHelp: _openHelp,
          supportRequestRepository: _supportRequestRepository,
        );
      default:
        return CustomerIdentificationPage(
          key: const ValueKey<int>(1),
          viewModel: _viewModel,
          onOpenHistory: _openHistory,
          onOpenRecovery: _openRecovery,
          onOpenMessaging: _openMessaging,
          onResumeOrder: _openOrder,
          onBackToHome: _requestBack,
        );
    }
  }
}
