# Photographie distante de l’identité — 1 novembre 2026

Lecture seule des connecteurs Firebase et Supabase, projet Firebase `cabineflow-4bca7`, Supabase `zrxeztxaxnzxevjuhzcc`. Aucune correction ni migration distante. Les identifiants sont abrégés et les contacts omis dans ce rapport versionné.

Firebase Auth : 98 comptes retournés (limite 500), dont 9 avec email et 89 sans email dans la réponse. Ces derniers correspondent potentiellement aux parcours clients anonymes : absence de profil Staff ≠ compte orphelin. Aucun compte Auth désactivé ni custom claim retourné. Firestore `users` : 7 documents, sans pagination supplémentaire retournée. SQL : 3 entrées d’accès Staff, 4 capacités Agent, 1 partenaire, 7 profils communs. Ces lectures successives ne sont pas une transaction entre les deux services.

| Utilisateur | Auth | Firestore | Supabase | Rôle résolu | État | Zones SQL | Contrôle |
|---|---|---|---|---|---|---|---|
| U01 (8kMGyp…) | présent | absent | absent | aucun | aucun accès métier | aucune | Auth email sans profil métier |
| U02 (EfRVjs…) | présent | oui | capacité Agent | agent | actif | WztIdDPF… | aucun écart de rôle/statut observé |
| U03 (JhqZFb…) | présent | oui | accès manager | supervisor | actif | 9c400240… | alias supervisor → manager attendu |
| U04 (VQ35oS…) | présent | oui | capacité Agent | agent | actif | Qq7oEZFb… | aucun écart de rôle/statut observé |
| U05 (eedjQO…) | présent | oui | accès manager | supervisor | actif | Qq7oEZFb…, WztIdDPF… | alias supervisor → manager attendu |
| U06 (na0RT7…) | présent | oui | capacité Agent | agent | actif | 9c400240… | aucun écart de rôle/statut observé |
| U07 (ti0FSo…) | présent | absent | partenaire | cabiniste | actif | 8b34d0f9… | aucun écart de rôle/statut observé |
| U08 (vYrrBY…) | présent | oui | capacité Agent | agent | actif | 9c400240… | aucun écart de rôle/statut observé |
| U09 (vu2TCy…) | présent | oui | accès admin | admin | actif | aucune | aucun écart de rôle/statut observé |

Les deux profils `supervisor` Firestore correspondent bien à des `manager` SQL : compatibilité attendue, pas de migration effectuée. Un compte Auth email n’a ni profil Firestore ni partenaire SQL ; il doit être vérifié avec l’Admin avant provisioning ou désactivation. Aucun profil métier observé sans Auth dans l’échantillon complet des registres consultés. Aucun chevauchement Staff/partenaire observé actuellement, même si le code de fusion permettrait cette contradiction.

Droits effectifs : Admin actif via Firestore et `izytel_staff_access` ; Managers via alias Firestore et registre SQL, zones `territory_zones.manager_id` ; Agents via profil Firestore et `phase5_agent_capacities` actif/réseaux/zones ; Cabiniste via `partner_accounts.status` et zones/réseaux. La présence du profil commun `staff_profiles` seul ne constitue pas une autorisation. Les permissions exactes de chaque RPC et règles restent à tester, cette matrice ne prouve pas leur absence de vulnérabilités.

Conseillers Supabase sécurité consultés : 19 signalements INFO RLS sans policy, 1 WARN extension dans public, 57 WARN fonctions SECURITY DEFINER exécutables par anon, 59 par authenticated. Ce sont des indices à confronter aux gardes internes, pas une preuve d’accès non autorisé. Voir [RLS sans policy](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [extension public](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public), [exécution anon](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [exécution authenticated](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

