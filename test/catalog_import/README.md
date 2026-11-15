# Tests serveur du catalogue

Node.js 22.13+ ; PostgreSQL isolé en WebAssembly via PGlite 0.5.13. Aucun accès réseau ou identifiant de production n’est utilisé pendant les tests.

```powershell
npm ci --prefix test/catalog_import
node test/catalog_import/run.mjs
```

La dépendance est réservée aux tests ; aucune dépendance Flutter n’est ajoutée. Sur le poste de préparation, le script peut aussi réutiliser le PGlite déjà installé dans les outils de recette historiques. `IZYTEL_PGLITE_MODULE` permet de désigner explicitement une installation existante.

Les offres de `fixtures/offres.json` sont les propositions non vérifiées du modèle fourni ; les identifiants Admin, commandes et frais de test sont synthétiques. Le test de snapshot prouve la conservation des champs présents dans la fixture, sans prétendre que des colonnes de frais séparés existent dans le schéma de production.

Le lecteur du vrai XLSX se vérifie séparément avec Deno :

```powershell
deno test --config supabase/functions/izytel-catalog-import/deno.json --allow-read=assets/templates supabase/functions/izytel-catalog-import/xlsx_test.ts
```

Résultats et limites : [bilan de livraison](../../docs/catalog_offers/IMPLEMENTATION.md).
