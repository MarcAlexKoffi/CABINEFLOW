-- PROPOSITION A VALIDER SEPAREMENT. JAMAIS EXECUTEE PAR CETTE MISSION.
-- Constat : TRUNCATE / REFERENCES / TRIGGER accordes a anon et authenticated
-- sur ces deux tables. Flutter utilise SELECT et des RPC controlees.
-- Ce script ne modifie ni SELECT, ni EXECUTE, ni les regles de role/zone.
-- Les JWT Firebase pouvant utiliser le role SQL anon, conserver cette
-- compatibilite et recetter toutes les RPC avant application definitive.
-- Par defaut, ROLLBACK : aucune modification persistante si execute tel quel.
begin;
revoke truncate, references, trigger
  on table public.customer_conversations, public.customer_messages
  from anon, authenticated;

-- Apres validation explicite, substituer COMMIT a ROLLBACK pour appliquer.
rollback;

-- Retour a l'etat de privileges observe (a revoir si l'etat serveur a change) :
-- grant truncate, references, trigger
--   on table public.customer_conversations, public.customer_messages
--   to anon, authenticated;

-- La politique de lecture Support globale est un sujet distinct :
-- auditer les prerequis de la migration WC6 locale et le schema reel.
-- Ne pas appliquer ce lot comme correction de l'isolation territoriale.
