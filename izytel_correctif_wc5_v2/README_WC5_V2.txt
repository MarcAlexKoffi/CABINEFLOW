IZYTEL - CORRECTIF WC5 V2
========================

Ce correctif corrige les echecs observes apres le premier package WC5 :

1. Import manquant de formatIvorianPhone dans backoffice_refunds_page.dart.
2. Suppression du helper _showMessage devenu inutilise.
3. La boite Manager affiche explicitement "Commande <reference>".
4. Le contrat BO-3C suit les nouvelles RPC territoriales WC5.
5. customer_confirmation_page.dart est REMPLACE par la version IzyTel sans WhatsApp.
6. Les anciens fichiers exclusivement WhatsApp sont supprimes automatiquement.

IMPORTANT
---------
Le premier package indiquait par erreur customer_confirmation_page.dart dans la
liste des fichiers a supprimer. Il ne faut plus la supprimer : WC5 V2 fournit sa
nouvelle version, necessaire au parcours de suivi client.

APPLICATION
-----------
1. Extraire ce ZIP dans un dossier temporaire.
2. Ouvrir PowerShell dans :
   C:\Users\koffi\Documents\PROJETS FLUTTER\cabine_flow
3. Lancer le script en lui donnant son chemin, par exemple :
   & "C:\chemin\vers\izytel_correctif_wc5_v2\APPLIQUER_CORRECTIF_WC5_V2.ps1"

TESTS
-----
flutter analyze --no-pub

flutter test .\test\regressions\customer_web_v2_wc5_messaging_contacts_territory_contract_test.dart --no-pub
flutter test .\test\features\customer_order\presentation\view_models\customer_frequent_beneficiary_test.dart --no-pub
flutter test .\test\features\messaging\presentation\customer_messaging_page_test.dart --no-pub
flutter test .\test\features\messaging\presentation\staff_customer_messaging_page_test.dart --no-pub
flutter test .\test\regressions\customer_web_v2_wc3c_manager_inbox_contract_test.dart --no-pub
flutter test .\test\regressions\backoffice_bo3c_territory_contract_test.dart --no-pub
flutter test .\test\regressions\supabase_phase4_assignment_contract_test.dart --no-pub
flutter test .\test\regressions\cabiniste_processing_parity_contract_test.dart --no-pub
flutter test .\test\regressions\backoffice_bo3a_support_refund_contract_test.dart --no-pub
flutter test .\test\regressions\customer_web_v2_wc4b_location_consent_contract_test.dart --no-pub

Ne redeploie pas le Web avant que cette campagne soit verte.
