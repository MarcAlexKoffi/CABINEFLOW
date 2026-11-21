# Publication des sources — 21 novembre 2026

Cette livraison regroupe les modifications locales du catalogue commercial,
des campagnes bonus, des raccourcis USSD/Max it du back-office et des parcours
d'affectation et de traitement des commandes.

Les résultats de validation déjà obtenus sont décrits dans `validation.html`
et `ussd_visibility_fix.json`. Ils ne constituent pas une validation sur un
téléphone avec un opérateur réel.

Le signalement du bouton « Lancer l’opération » grisé dans l’application
Android reste à reproduire et à confirmer sur la version installée. Ne pas
présenter cette publication GitHub comme une résolution vérifiée de ce
signalement. Aucun nouvel APK n'a été compilé : Windows bloque actuellement
l'exécution de Dart pendant l'initialisation ou la mise à jour du SDK.

Les changements navigateur préparés pendant le diagnostic ont été retirés.

Cette publication concerne le code source uniquement. Elle ne demande aucun
déploiement Firebase ou Supabase. Ne pas déployer le Web client ni modifier
`izytel.ci` sans une nouvelle autorisation explicite de l'utilisateur.
Les trois migrations de cette livraison ont déjà été appliquées au serveur
pendant les travaux précédents ; ne pas les appliquer une seconde fois.
