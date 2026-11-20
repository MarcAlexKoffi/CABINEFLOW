# Correctif du masque de numéro — 20 novembre 2026

La fonction de pagination publiée contenait des caractères corrompus à la place des puces. Le fichier SQL local était en UTF-8, mais sa lecture PowerShell sans encodage explicite a transmis des caractères Windows-1252 à la base. Le contrôle précédent vérifiait le masquage du numéro complet sans vérifier l'encodage exact du texte affiché.

La migration `20261120012200_shared_queue_mask_unicode.sql` remplace uniquement `private.izytel_shared_available_page(integer,timestamptz,text)`. Le masque est désormais construit à partir de `chr(8226)` ; le SQL déployé ne contient que des caractères ASCII. Les migrations sont lues avec un encodage UTF-8 explicite.

- Résultat vérifié en production : `•• •• •• 0000`.
- Octets UTF-8 : `e280a2e280a220e280a2e280a220e280a2e280a22030303030`.
- 14 contrôles PostgreSQL locaux réussis, dont reproduction de la corruption, correction exacte, parcours paginé et absence de numéro complet dans les réponses.
- Propriétaire, ACL et configuration de recherche du lecteur conservés.
- La commande présente a conservé son empreinte avant/après : `d38276165cfd5c4cb9b1aca903b7e6bc`.
- Aucun changement de code Flutter ni d'APK : le correctif s'applique à la version 1.0.12 installée dès l'actualisation de la file.

Sauvegarde locale ignorée par Git : `.izytel_backups/mask_unicode_schema_before.json`. Retour arrière de la seule fonction : `shared_queue_mask_unicode_rollback.sql` ; il rétablit également le défaut d'affichage de la version précédente.

Suivi : [issue #13](https://github.com/MarcAlexKoffi/CABINEFLOW/issues/13).
