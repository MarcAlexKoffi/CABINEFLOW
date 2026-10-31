import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,dirname} from 'node:path';
const root=process.cwd(), base=resolve(root,'scratch/ussd_20261031');
const edits={
 'lib/features/orders/domain/models/queue_order.dart':[
  ['    this.customerAuthUid,','    this.customerAuthUid,\n    this.offerId,'],
  ['  final String? customerAuthUid;','  final String? customerAuthUid;\n  /// Stable catalogue key. Never reconstructed from a commercial label.\n  final String? offerId;'],
  ['      customerAuthUid: customerAuthUid,','      customerAuthUid: customerAuthUid,\n      offerId: offerId,']],
 'lib/features/orders/data/mappers/firestore_order_mapper.dart':[
  ["      customerAuthUid: _readNullableString(data['customerAuthUid']),","      customerAuthUid: _readNullableString(data['customerAuthUid']),\n      offerId: _readNullableString(data['offerId']),"]],
 'lib/features/orders/data/repositories/firestore_orders_repository.dart':[
  ['      offerLabel: request.offerLabel.trim(),','      offerLabel: request.offerLabel.trim(),\n      offerId: request.isCustomOffer ? null : request.offerId,']],
 'lib/features/orders/data/repositories/fake_orders_repository.dart':[
  ['      offerLabel: request.offerLabel.trim(),','      offerLabel: request.offerLabel.trim(),\n      offerId: request.isCustomOffer ? null : request.offerId,']],
 'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart':[
  ["import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';","import 'package:cabine_flow/core/supabase/supabase_realtime_refetch.dart';\nimport 'package:cabine_flow/core/diagnostics/izytel_log.dart';"],
  ['    this.zoneId,','    this.zoneId,\n    this.offerId,'],
  ['  final String offerLabel;','  final String offerLabel;\n  final String? offerId;'],
  ['      offerLabel: offerLabel,','      offerLabel: offerLabel,\n      offerId: offerId ?? legacy?.offerId,'],
  ['    return _requireSnapshot(raw);',`    final snapshot = _requireSnapshot(raw);
    // Optional USSD metadata is independent of assignment/payment transitions.
    // Older servers remain fully usable before the USSD migration is applied.
    if (order.offerId != null) {
      try {
        await _client.rpc('izytel_ussd_register_order_context', params: {
          'p_order_id': order.id, 'p_offer_id': order.offerId,
        }).timeout(const Duration(seconds: 3));
      } catch (error) {
        IzyTelLog.backendError('USSD.order-context', error);
      }
    }
    return snapshot;`]],
 'lib/features/orders/presentation/pages/agent_order_detail_view.dart':[
  ["import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';","import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';\nimport 'package:cabine_flow/features/ussd/presentation/ussd_quick_processing_card.dart';"],
  ['              _ReferenceProgress(order: order),\n              SizedBox(height: 18 * referenceScale),',`              _ReferenceProgress(order: order),
              SizedBox(height: 18 * referenceScale),
              UssdQuickProcessingCard(
                key: ValueKey('ussd-\${order.id}'),
                orderId: order.id, network: order.network.name,
                offerLabel: order.offerLabel, beneficiary: order.beneficiaryPhone,
                amount: order.amount,
                processable: order.status == QueueOrderStatus.inProgress &&
                    order.assignedAgentId == widget.user.id && order.isFundedForProcessing,
              ),
              SizedBox(height: 18 * referenceScale),`]],
 'lib/features/partners/presentation/pages/partner_shell_page.dart':[
  ["import 'dart:async';","import 'dart:async';\nimport 'package:cabine_flow/features/ussd/presentation/ussd_quick_processing_card.dart';"],
  ['                  _PartnerReferenceProgress(order: order),\n                  SizedBox(height: 18 * referenceScale),',`                  _PartnerReferenceProgress(order: order),
                  SizedBox(height: 18 * referenceScale),
                  UssdQuickProcessingCard(
                    key: ValueKey('ussd-\${order.orderId}'),
                    orderId: order.orderId, network: order.network,
                    offerLabel: order.offerLabel, beneficiary: order.beneficiaryPhone,
                    amount: order.amount,
                    processable: order.isAccepted && order.isInProgress && order.isFundedForProcessing,
                  ),
                  SizedBox(height: 18 * referenceScale),`]],
 'lib/backoffice/presentation/pages/backoffice_shell_page.dart':[
  ["import 'dart:async';","import 'dart:async';\nimport 'package:cabine_flow/features/ussd/presentation/backoffice_ussd_page.dart';"],
  ['  offers,','  offers,\n  ussd,'],
  ["      case BackofficeDestination.offers:\n        return 'Offres & tarifs';","      case BackofficeDestination.offers:\n        return 'Offres & tarifs';\n      case BackofficeDestination.ussd:\n        return 'Raccourcis USSD';"],
  ['      case BackofficeDestination.offers:\n        return Symbols.local_offer_rounded;','      case BackofficeDestination.offers:\n        return Symbols.local_offer_rounded;\n      case BackofficeDestination.ussd:\n        return Icons.dialpad;'],
  ['      case BackofficeDestination.offers:\n        return _BackofficeSection.catalog;','      case BackofficeDestination.offers:\n      case BackofficeDestination.ussd:\n        return _BackofficeSection.catalog;'],
  ['      case BackofficeDestination.offers:\n        return permissions.canManageOffers;','      case BackofficeDestination.offers:\n        return permissions.canManageOffers;\n      case BackofficeDestination.ussd:\n        return user.role == UserRole.administrator || user.isManager;'],
  ['      case BackofficeDestination.finances:\n        return _financeContent(BackofficeFinanceModule.overview);','      case BackofficeDestination.ussd:\n        return BackofficeUssdPage(user: widget.user);\n      case BackofficeDestination.finances:\n        return _financeContent(BackofficeFinanceModule.overview);']],
 'lib/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart':[
  ["import 'dart:async';","import 'dart:async';\nimport 'package:cabine_flow/features/ussd/presentation/ussd_activity_page.dart';"],
  ['                _scopeBanner(data),',`                _scopeBanner(data),
                Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                  icon: const Icon(Icons.dialpad),
                  label: const Text('Signalements USSD · Agents et Cabinistes'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => UssdActivityPage(user: widget.user, reports: true))),
                )),`]],
};
const normalize=s=>s.replace(/^\uFEFF/,'').replaceAll('\r\n','\n');
if(process.argv.includes('--restore')) {
  for(const path of Object.keys(edits)) {
    const current=await readFile(resolve(root,path),'utf8');
    const formatted=await readFile(resolve(base,'formatted',path),'utf8');
    if(normalize(current)!==normalize(formatted)) throw new Error(`Unrecognized concurrent change: ${path}; nothing restored for this file`);
    const candidate=await readFile(resolve(base,'minimal',path));
    await writeFile(resolve(root,path),candidate);
    console.log(`Minimal integration preserved: ${path}`);
  }
} else {
  for(const [path,replacements] of Object.entries(edits)) {
    const original=await readFile(resolve(base,'original',path),'utf8');
    let content=normalize(original);
    for(const [before,after] of replacements) {
      if(!content.includes(before))throw new Error(`Missing context: ${path} ${before}`);
      content=content.replace(before,after);
    }
    if(original.includes('\r\n'))content=content.replaceAll('\n','\r\n');
    for(const dir of ['minimal','formatted']) {
      const target=resolve(base,dir,path);await mkdir(dirname(target),{recursive:true});await writeFile(target,content);
    }
  }
}
