import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/features/agents/data/repositories/supabase_agent_personal_profile_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';

class AgentDirectoryAvatar extends StatefulWidget {
  const AgentDirectoryAvatar({
    super.key,
    required this.agentId,
    required this.name,
    this.size = 42,
    this.onTap,
    this.repository,
  });

  final String agentId;
  final String name;
  final double size;
  final VoidCallback? onTap;
  final SupabaseAgentPersonalProfileRepository? repository;

  @override
  State<AgentDirectoryAvatar> createState() => _AgentDirectoryAvatarState();
}

class _AgentDirectoryAvatarState extends State<AgentDirectoryAvatar> {
  Future<String?>? _avatarUrlFuture;

  @override
  void initState() {
    super.initState();
    _reloadAvatar();
  }

  @override
  void didUpdateWidget(covariant AgentDirectoryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId ||
        oldWidget.repository != widget.repository) {
      _reloadAvatar();
    }
  }

  void _reloadAvatar() {
    if (!SupabaseBootstrap.isInitialized && widget.repository == null) {
      _avatarUrlFuture = Future<String?>.value(null);
      return;
    }

    final SupabaseAgentPersonalProfileRepository repository =
        widget.repository ?? SupabaseAgentPersonalProfileRepository();
    _avatarUrlFuture = repository
        .fetchDirectoryAvatarUrl(widget.agentId)
        .catchError((Object _) => null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _avatarUrlFuture,
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        return IzyTelAvatar(
          name: widget.name,
          size: widget.size,
          imageUrl: snapshot.data,
          onTap: widget.onTap,
        );
      },
    );
  }
}
