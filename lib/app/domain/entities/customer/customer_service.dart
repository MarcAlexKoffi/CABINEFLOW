enum CustomerService { unitTransfer, internetSubscription, calls }

extension CustomerServicePresentation on CustomerService {
  String get label {
    switch (this) {
      case CustomerService.unitTransfer:
        return 'Transfert d’unités';
      case CustomerService.internetSubscription:
        return 'Souscription Internet';
      case CustomerService.calls:
        return 'Appels';
    }
  }

  String get description {
    switch (this) {
      case CustomerService.unitTransfer:
        return 'Envoyer des unités sur un numéro';
      case CustomerService.internetSubscription:
        return 'Acheter un forfait Internet';
      case CustomerService.calls:
        return 'Acheter un forfait d’appel';
    }
  }
}
