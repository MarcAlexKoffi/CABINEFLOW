-- IzyTel Phase 3 - correctif de cloture runtime.
-- Un Agent perd volontairement la visibilite RLS sur une commande juste apres
-- son refus. Le resultat utile de la transition doit donc revenir du meme RPC
-- atomique, sans SELECT client supplementaire.

create or replace function public.phase4_agent_action(
  p_order_id text,
  p_action text,
  p_reason text default null
)
returns jsonb
language plpgsql
set search_path to ''
as $$
declare
  v_uid text := nullif(btrim(coalesce((select auth.jwt()->>'sub'), '')), '');
  v_row public.phase4_assignment_orders;
begin
  v_row := private.phase4_agent_action_internal(p_order_id, p_action, p_reason);

  return jsonb_build_object(
    'ok', true,
    'action', p_action,
    'assignment_state', v_row.assignment_state,
    'reassigned', (
      p_action = 'refuse'
      and v_row.assignment_state = 'assigned'
      and v_row.assigned_agent_id is not null
      and v_row.assigned_agent_id is distinct from v_uid
    ),
    'manual_required', (
      p_action = 'refuse'
      and v_row.assignment_state = 'manual_required'
    )
  );
end;
$$;

revoke all on function public.phase4_agent_action(text, text, text) from public;
grant execute on function public.phase4_agent_action(text, text, text)
  to anon, authenticated, service_role;
