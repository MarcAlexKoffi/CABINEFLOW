# IzyTel — correction Agent/Manager et déploiement autorisé

**État ultérieur :** activation et publication des trois commandes autorisées puis exécutées ; job minute observé avec succès, six notifications acceptées par FCM. Voir [ACTIVATION_RECEIPT_20261106.json](ACTIVATION_RECEIPT_20261106.json). Les mentions « désactivée » de cette note décrivent l'étape de déploiement antérieure.

6 novembre 2026. Cette note est l'état courant après le retour utilisateur illustré par trois captures Android. Elle complète la livraison initiale ; aucune nouvelle revue générale du projet n'a été engagée.

## Serveur : opérations autorisées effectuées

- Migration `shared_agent_queue_and_sla` appliquée au projet `zrxeztxaxnzxevjuhzcc`, version distante `20261106105111`, à partir du fichier préparé `20261106004036_shared_agent_queue_and_sla.sql`. Empreinte source inchangée ; délais locaux de verrou 5 s et de requête 60 s ajoutés à la transaction d'application.
- Fonction `izytel-notification-dispatch` déployée en **version 4 ACTIVE**, avec `verify_jwt=false` et `deno.json` conservés. Source distante relue identique à celle envoyée ; aucun secret modifié.
- Contrôle après déploiement : **enabled=false**, `activated_at=null`, zéro commande partagée, **zéro job SLA**. Le job historique de retry reste actif.
- RLS activée sur les trois nouvelles tables ; RPC de contrôle de destinataire exécutable par `service_role`, refusée à `anon/authenticated`.
- Le conseiller de sécurité a été consulté. Son information « RLS enabled, no policy » sur les paramètres privés correspond à leur fermeture intentionnelle aux clients ; les accès métier passent par les fonctions contrôlées. Les autres modules n'ont pas été modifiés.
- Aucun compte, paiement ou ordre télécom n'a été créé pour tester. Aucune notification de recette réelle n'a été envoyée.

Preuve : [reçu de déploiement](DEPLOYMENT_RECEIPT_20261106.json). Le timestamp distant est attribué par le MCP ; ne pas relancer aveuglément le fichier local différemment daté avec un `db push` global.

## Correction bornée de présentation

La capture « Mes commandes » montrait le nouveau bloc IzyTel/Espace Agent, puis les onglets, puis l'en-tête Agent historique. Le conteneur était responsable du doublon. Les erreurs de lecture pouvaient aussi être accompagnées d'un état vide présenté comme certain.

Trois fichiers applicatifs seulement ont été corrigés pour ce retour :

| Fichier | Correction |
|---|---|
| `agent_orders_page.dart` | L'en-tête existant reste unique et accueille les deux rubriques. Le profil, la disponibilité, le menu et les filtres personnels sont conservés. La disponibilité accepte le texte agrandi. |
| `shared_agent_orders_page.dart` | Suppression du second en-tête et du texte promotionnel. Même surface, rayons, logos opérateur, badge et bandeau bénéficiaire/montant que les cartes existantes. Défilement unique et retour en haut après le détail. États erreur, vide et file désactivée distingués ; pas de fausse confirmation « Tout est à jour ». |
| `order_supervision_page.dart` | Titres alignés sur les tailles existantes, cartes et filtres du design system, retrait des explications techniques dans l'écran. Un échec de chargement n'affiche plus de fausse liste vide. |

Aucun repository, modèle métier, permission, calcul financier, raccourci USSD ou parcours de finalisation n'a été modifié pour ce correctif visuel. La migration et le dispatch sont exactement ceux de la candidate testée précédemment, maintenant appliqués avec l'autorisation explicite.

## Contrôles ciblés

- **19 tests réussis** : 14 tests de file/supervision, une capture des widgets et quatre tests de retour Android. Quatre nouveaux scénarios vérifient l'en-tête unique sur les deux rubriques, l'erreur sans faux vide et sa reprise, la file désactivée avec accès aux commandes personnelles, et l'erreur Manager sans faux état vide.
- Cas 320/390 px, texte à 200 %, acceptation sans démarrage implicite, réponse perdue, conflit, notification vers la bonne rubrique et alertes persistantes conservés.
- Analyse ciblée des trois écrans et du test : aucune anomalie.
- Captures des widgets avec Manrope régénérées, notamment [À prendre](visual_qa/agent-390.png), [Mes commandes](visual_qa/agent-personal-390.png), [vide](visual_qa/agent-empty-390.png), [suivi Manager](visual_qa/manager-390.png) et [alertes](visual_qa/manager-alerts-390.png).
- Builds de l'APK et du Back-office réussis. Livrables : [APK corrigé](../../build/app/outputs/flutter-apk/app-release.apk) et [Back-office corrigé](../../build/shared_queue/izytel-backoffice-correctif-20261106.zip). Les traces sont `scratch/shared_queue_harmony_final_tests.log`, `scratch/shared_queue_harmony_analyze.log`, `scratch/shared_queue_harmony_apk_build.log` et `scratch/shared_queue_harmony_web_build.log`.
- La suite complète de 1 113 tests et les deux scénarios physiques de la livraison précédente n'ont pas été relancés pour cette correction bornée. Ils ne sont pas présentés comme une nouvelle recette du binaire corrigé.

Le remplacement de l'en-tête et l'harmonisation sont explicitement demandés par l'utilisateur ; le prototype R1 historique demeure inchangé. Les rendus sont présentés avec la correction, sans attribuer une nouvelle validation humaine à des captures que l'utilisateur n'a pas encore examinées.

## État de sortie

Migration et dispatch : **déployés, file désactivée**. Correctif des écrans : **implémenté et vérifié localement**. Aucune activation globale ni publication de l'application n'est effectuée. L'APK corrigé reste à installer sur les postes concernés avant toute activation autorisée ; la réception FCM réelle reste un contrôle opérationnel distinct.
