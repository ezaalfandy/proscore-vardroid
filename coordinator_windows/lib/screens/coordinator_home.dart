import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/clip.dart';
import '../models/device.dart';
import '../models/mark.dart';
import '../providers/clip_explorer_provider.dart';
import '../providers/clip_provider.dart';
import '../providers/device_provider.dart';
import '../providers/mark_provider.dart';
import '../providers/playback_provider.dart';
import '../providers/server_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';
import '../widgets/clip_explorer/clip_explorer_panel.dart';
import '../widgets/device_status_row.dart';
import '../widgets/mjpeg_view.dart';
import '../widgets/playback_overlay.dart';
import '../widgets/status_dot.dart';
import '../widgets/var_badge.dart';
import '../widgets/var_button.dart';
import '../widgets/var_card.dart';

/// Navigation views for the coordinator home screen.
enum HomeNavView {
  overview,
  clipExplorer,
  settings,
}

class CoordinatorHome extends StatefulWidget {
  const CoordinatorHome({super.key});

  @override
  State<CoordinatorHome> createState() => _CoordinatorHomeState();
}

class _CoordinatorHomeState extends State<CoordinatorHome> {
  HomeNavView _currentView = HomeNavView.overview;

  @override
  void initState() {
    super.initState();
    // Auto-start server when app loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startServer();
    });
  }

  Future<void> _startServer() async {
    try {
      await context.read<ServerProvider>().startServer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start server: $e')),
        );
      }
    }
  }

  void _navigateTo(HomeNavView view) {
    setState(() {
      _currentView = view;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playbackProvider = context.watch<PlaybackProvider>();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Row(
              children: [
                _Sidebar(
                  currentView: _currentView,
                  onNavigate: _navigateTo,
                ),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),

            // Playback overlay (fullscreen when active)
            if (playbackProvider.isPlaybackActive)
              Positioned.fill(
                child: PlaybackOverlay(
                  onClose: () => playbackProvider.close(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_currentView) {
      case HomeNavView.overview:
        return _OverviewContent();
      case HomeNavView.clipExplorer:
        return const ClipExplorerPanel();
      case HomeNavView.settings:
        return const Center(child: Text('Settings - Coming Soon'));
    }
  }
}

/// Overview content with device grid, clips panel, and timeline.
class _OverviewContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Header(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 980;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.space5),
                child: isNarrow
                    ? Column(
                        children: [
                          _DeviceGrid(),
                          const SizedBox(height: AppSpacing.space5),
                          _ClipPanel(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _DeviceGrid()),
                          const SizedBox(width: AppSpacing.space5),
                          Expanded(flex: 2, child: _ClipPanel()),
                        ],
                      ),
              );
            },
          ),
        ),
        const _TimelineBar(),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentView,
    required this.onNavigate,
  });

  final HomeNavView currentView;
  final void Function(HomeNavView) onNavigate;

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<ServerProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          right: BorderSide(color: context.tokens.border),
        ),
      ),
      child: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SidebarHeader(isRecording: sessionProvider.isRecording),
                  const SizedBox(height: AppSpacing.space5),
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                    isActive: currentView == HomeNavView.overview,
                    onTap: () => onNavigate(HomeNavView.overview),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  _NavItem(
                    icon: Icons.video_library_outlined,
                    label: 'Clip Explorer',
                    isActive: currentView == HomeNavView.clipExplorer,
                    onTap: () => onNavigate(HomeNavView.clipExplorer),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    isActive: currentView == HomeNavView.settings,
                    onTap: () => onNavigate(HomeNavView.settings),
                  ),
                  const SizedBox(height: AppSpacing.space5),
                  Row(
                    children: [
                      Text('Server', style: context.text.titleMedium),
                      const SizedBox(width: AppSpacing.space2),
                      StatusDot(
                        status: serverProvider.isRunning
                            ? DeviceStatus.recording
                            : DeviceStatus.unpaired,
                        size: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    serverProvider.isRunning
                        ? 'Running on port ${serverProvider.port}'
                        : 'Stopped',
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text('Pairing', style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.space3),
                  VarCard(
                    background: context.tokens.surfaceAlt,
                    padding: const EdgeInsets.all(AppSpacing.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: serverProvider.pairingUrl != null
                              ? MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => _showLargeQrDialog(
                                      context,
                                      serverProvider.pairingUrl!,
                                    ),
                                    child: QrImageView(
                                      data: serverProvider.pairingUrl!,
                                      size: 100,
                                      backgroundColor: context.colors.onPrimary,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 100,
                                  height: 100,
                                  color: context.tokens.surfaceAlt,
                                  child: Center(
                                    child: Text(
                                      'Server not running',
                                      style: context.text.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: AppSpacing.space2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                serverProvider.currentToken?.token ?? '------',
                                style: context.text.bodyMedium?.copyWith(
                                  letterSpacing: 1.2,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16),
                              onPressed: serverProvider.isRunning
                                  ? () => serverProvider.refreshToken()
                                  : null,
                              tooltip: 'Refresh token',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text('Devices (${deviceProvider.connectedCount})', style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.space3),
                  if (deviceProvider.connectedDevices.isEmpty)
                    Text(
                      'No devices connected',
                      style: context.text.bodySmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    )
                  else
                    ...deviceProvider.connectedDevices.map(
                      (connected) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.space2),
                        child: Row(
                          children: [
                            StatusDot(
                              status: _mapDeviceState(connected.state),
                              size: 8,
                            ),
                            const SizedBox(width: AppSpacing.space2),
                            Expanded(
                              child: Text(
                                connected.assignedName,
                                style: context.text.bodySmall,
                              ),
                            ),
                            if (connected.batteryLevel != null)
                              Text(
                                '${connected.batteryLevel}%',
                                style: context.text.bodySmall?.copyWith(
                                  color: context.tokens.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Fixed bottom section
          Padding(
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VarButton.secondary(
                  label: serverProvider.isRunning ? 'Stop Server' : 'Start Server',
                  icon: serverProvider.isRunning ? Icons.stop : Icons.play_arrow,
                  onPressed: () async {
                    if (serverProvider.isRunning) {
                      await serverProvider.stopServer();
                    } else {
                      await serverProvider.startServer();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.space2),
                _RecordingButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DeviceStatus _mapDeviceState(DeviceRuntimeState state) {
    switch (state) {
      case DeviceRuntimeState.recording:
        return DeviceStatus.recording;
      case DeviceRuntimeState.paired:
      case DeviceRuntimeState.connected:
        return DeviceStatus.paired;
      case DeviceRuntimeState.connecting:
        return DeviceStatus.connecting;
      case DeviceRuntimeState.error:
      case DeviceRuntimeState.disconnected:
        return DeviceStatus.unpaired;
    }
  }
}

class _RecordingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final isRecording = sessionProvider.isRecording;

    return VarButton.ghost(
      label: isRecording ? 'Stop Recording' : 'Start Recording',
      icon: isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
      onPressed: () => _handleRecordingToggle(context, isRecording),
    );
  }

  void _handleRecordingToggle(BuildContext context, bool isRecording) {
    if (isRecording) {
      _confirmStopRecording(context);
    } else {
      _showStartSessionDialog(context);
    }
  }

  void _confirmStopRecording(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Stop recording?'),
          content: const Text(
            'All cameras will stop recording. This action cannot be undone.',
          ),
          actions: [
            VarButton.ghost(
              label: 'Cancel',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            VarButton.danger(
              label: 'Stop',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SessionProvider>().stopRecording();
              },
            ),
          ],
        );
      },
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.shield, color: context.colors.onPrimary),
        ),
        const SizedBox(width: AppSpacing.space3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VAR Coordinator', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.space1),
            Row(
              children: [
                StatusDot(
                  status: isRecording
                      ? DeviceStatus.recording
                      : DeviceStatus.paired,
                  size: 8,
                ),
                const SizedBox(width: AppSpacing.space2),
                Text(
                  isRecording
                      ? sessionProvider.formattedDuration
                      : 'Ready',
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = isActive ? context.colors.primary : Colors.transparent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space3,
          vertical: AppSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: isActive ? highlight.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? highlight.withOpacity(0.6) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? context.colors.primary : context.tokens.iconMuted,
            ),
            const SizedBox(width: AppSpacing.space2),
            Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: isActive ? context.colors.primary : context.colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final deviceProvider = context.watch<DeviceProvider>();
    final serverProvider = context.watch<ServerProvider>();
    final isRecording = sessionProvider.isRecording;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.tokens.border),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionProvider.currentSession?.title ?? 'No Active Session',
                style: context.text.displaySmall,
              ),
              const SizedBox(height: AppSpacing.space1),
              Text(
                isRecording
                    ? 'Recording - ${sessionProvider.formattedDuration}'
                    : 'Ready to record',
                style: context.text.bodySmall?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Wrap(
            spacing: AppSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              VarBadge(
                label: serverProvider.isRunning ? 'Server OK' : 'Server Off',
                color: serverProvider.isRunning
                    ? context.tokens.success
                    : context.colors.error,
              ),
              VarBadge(
                label: '${deviceProvider.connectedCount} Cameras',
                color: context.colors.secondary,
              ),
              VarButton.secondary(
                label: 'Add Mark',
                icon: Icons.flag_outlined,
                onPressed: isRecording
                    ? () => context.read<MarkProvider>().createMark()
                    : null,
              ),
              VarButton.primary(
                label: isRecording ? 'Recording' : 'Start Recording',
                icon: Icons.fiber_manual_record,
                onPressed: isRecording
                    ? null
                    : () {
                        _showStartSessionDialog(context);
                      },
              ),
              VarButton.danger(
                label: 'Stop',
                icon: Icons.stop_circle,
                onPressed: isRecording
                    ? () => _confirmStopRecording(context)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmStopRecording(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Stop recording?'),
          content: const Text(
            'All cameras will stop recording. This action cannot be undone.',
          ),
          actions: [
            VarButton.ghost(
              label: 'Cancel',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            VarButton.danger(
              label: 'Stop',
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<SessionProvider>().stopRecording();
              },
            ),
          ],
        );
      },
    );
  }
}

class _DeviceGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final devices = deviceProvider.connectedDevices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cameras', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.space3),
        if (devices.isEmpty)
          VarCard(
            background: context.tokens.surfaceAlt,
            padding: const EdgeInsets.all(AppSpacing.space5),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    size: 48,
                    color: context.tokens.iconMuted,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Text(
                    'No cameras connected',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    'Scan the QR code with a camera device to connect',
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.space4,
              crossAxisSpacing: AppSpacing.space4,
              childAspectRatio: 1.2,  // Taller cards for preview
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              return _DeviceCard(device: devices[index]);
            },
          ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final ConnectedDevice device;

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.read<ServerProvider>();

    return VarCard(
      background: context.tokens.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              StatusDot(status: _mapDeviceState(device.state)),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  device.assignedName,
                  style: context.text.titleMedium,
                ),
              ),
              if (device.slotName != null)
                VarBadge(
                  label: device.slotName!,
                  color: context.colors.secondary,
                ),
              // Preview toggle button
              IconButton(
                icon: Icon(
                  device.isPreviewAvailable ? Icons.videocam : Icons.videocam_off,
                  color: device.isPreviewAvailable
                      ? context.colors.primary
                      : context.tokens.iconMuted,
                  size: 20,
                ),
                onPressed: () {
                  if (device.isPreviewAvailable) {
                    serverProvider.stopPreview(device.id);
                  } else {
                    serverProvider.requestPreview(device.id);
                  }
                },
                tooltip: device.isPreviewAvailable ? 'Stop preview' : 'Start preview',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          // Preview area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: device.isPreviewAvailable
                  ? MjpegView(
                      url: device.previewUrl,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.black26,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_off_outlined,
                              color: context.tokens.iconMuted,
                              size: 32,
                            ),
                            const SizedBox(height: AppSpacing.space2),
                            Text(
                              'Preview off',
                              style: context.text.bodySmall?.copyWith(
                                color: context.tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.space3),
          // Status row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.battery_full, size: 14, color: context.tokens.iconMuted),
                    const SizedBox(width: 4),
                    Text(
                      device.batteryLevel != null ? '${device.batteryLevel}%' : '--',
                      style: context.text.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.space3),
                    Icon(Icons.sd_storage_outlined, size: 14, color: context.tokens.iconMuted),
                    const SizedBox(width: 4),
                    Text(
                      device.storageAvailableMb != null
                          ? '${(device.storageAvailableMb! / 1024).toStringAsFixed(1)}G'
                          : '--',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: device.isRecording
                      ? context.colors.error.withValues(alpha: 0.2)
                      : context.tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  device.isRecording ? 'REC' : 'STBY',
                  style: context.text.bodySmall?.copyWith(
                    color: device.isRecording
                        ? context.colors.error
                        : context.tokens.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DeviceStatus _mapDeviceState(DeviceRuntimeState state) {
    switch (state) {
      case DeviceRuntimeState.recording:
        return DeviceStatus.recording;
      case DeviceRuntimeState.paired:
      case DeviceRuntimeState.connected:
        return DeviceStatus.paired;
      case DeviceRuntimeState.connecting:
        return DeviceStatus.connecting;
      case DeviceRuntimeState.error:
      case DeviceRuntimeState.disconnected:
        return DeviceStatus.unpaired;
    }
  }
}

class _ClipPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final clipProvider = context.watch<ClipProvider>();
    final clips = clipProvider.clips;

    return VarCard(
      background: context.tokens.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Clips (${clips.length})', style: context.text.titleMedium),
              const Spacer(),
              VarButton.ghost(
                label: 'Open Folder',
                icon: Icons.folder_open_outlined,
                onPressed: () => clipProvider.openClipsDirectory(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.space2,
              horizontal: AppSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.tokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Clip', style: context.text.bodySmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Camera', style: context.text.bodySmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Size', style: context.text.bodySmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Status', style: context.text.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          if (clips.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.space4),
              child: Center(
                child: Text(
                  'No clips yet',
                  style: context.text.bodySmall?.copyWith(
                    color: context.tokens.textMuted,
                  ),
                ),
              ),
            )
          else
            ...clips.map((clip) => _ClipRow(clip: clip)),
        ],
      ),
    );
  }
}

class _ClipRow extends StatelessWidget {
  const _ClipRow({required this.clip});

  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final playbackProvider = context.read<PlaybackProvider>();
    final device = deviceProvider.getConnectedDevice(clip.deviceId);
    final cameraName = device?.assignedName ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.space2,
          horizontal: AppSpacing.space3,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.tokens.border),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                clip.id.substring(0, 8).toUpperCase(),
                style: context.text.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                cameraName,
                style: context.text.bodySmall?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(clip.formattedSize, style: context.text.bodySmall),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  _ClipStatusBadge(clip: clip),
                  const SizedBox(width: AppSpacing.space2),
                  // Play button for downloaded clips
                  if (clip.status == ClipStatus.downloaded && clip.localPath != null)
                    IconButton(
                      icon: Icon(
                        Icons.play_circle_outline,
                        color: context.colors.primary,
                        size: 20,
                      ),
                      onPressed: () => playbackProvider.openLocalFile(clip.localPath!),
                      tooltip: 'Play clip',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipStatusBadge extends StatelessWidget {
  const _ClipStatusBadge({required this.clip});

  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (clip.status) {
      ClipStatus.downloaded => ('Ready', context.tokens.success),
      ClipStatus.downloading => ('${(clip.downloadProgress * 100).toInt()}%', context.colors.secondary),
      ClipStatus.failed => ('Failed', context.colors.error),
      ClipStatus.pending => ('Pending', context.tokens.textMuted),
      ClipStatus.requested => ('Requested', context.colors.secondary),
      ClipStatus.generating => ('Generating', context.colors.secondary),
      ClipStatus.ready => ('Ready', context.tokens.success),
    };
    return VarBadge(label: label, color: color);
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar();

  @override
  Widget build(BuildContext context) {
    final markProvider = context.watch<MarkProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final marks = markProvider.marks;

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space5,
        vertical: AppSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(color: context.tokens.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Timeline Marks (${marks.length})', style: context.text.titleMedium),
              const Spacer(),
              VarButton.ghost(
                label: 'Add Mark',
                icon: Icons.flag,
                onPressed: sessionProvider.isRecording
                    ? () => markProvider.createMark()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Expanded(
            child: marks.isEmpty
                ? Center(
                    child: Text(
                      sessionProvider.isRecording
                          ? 'Press "Add Mark" to mark an incident'
                          : 'Start recording to add marks',
                      style: context.text.bodySmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final mark = marks[index];
                      return _MarkCard(
                        mark: mark,
                        sessionStart: sessionProvider.currentSession?.startedAt,
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: AppSpacing.space3),
                    itemCount: marks.length,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MarkCard extends StatelessWidget {
  const _MarkCard({required this.mark, this.sessionStart});

  final Mark mark;
  final DateTime? sessionStart;

  @override
  Widget build(BuildContext context) {
    final timecode = _formatTimecode();

    return InkWell(
      onTap: () => _showMarkOptions(context),
      child: VarCard(
        background: context.tokens.surfaceAlt,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space4,
          vertical: AppSpacing.space3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(mark.label ?? 'Mark', style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.space1),
            Text(
              timecode,
              style: context.text.bodySmall?.copyWith(
                color: context.tokens.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimecode() {
    if (sessionStart == null) {
      return mark.coordinatorTs.toIso8601String().substring(11, 19);
    }
    final offset = mark.coordinatorTs.difference(sessionStart!);
    final hours = offset.inHours.toString().padLeft(2, '0');
    final minutes = (offset.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (offset.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showMarkOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Request Clips'),
                subtitle: const Text('Download clips from all cameras'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<ClipProvider>().requestClipsForMark(mark.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Label'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showEditLabelDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: context.colors.error),
                title: Text('Delete Mark', style: TextStyle(color: context.colors.error)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<MarkProvider>().deleteMark(mark.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditLabelDialog(BuildContext context) {
    final controller = TextEditingController(text: mark.label);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Mark Label'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'Enter mark label',
            ),
          ),
          actions: [
            VarButton.ghost(
              label: 'Cancel',
              onPressed: () => Navigator.pop(dialogContext),
            ),
            VarButton.primary(
              label: 'Save',
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<MarkProvider>().updateMark(
                      mark.id,
                      label: controller.text,
                    );
              },
            ),
          ],
        );
      },
    );
  }
}

void _showLargeQrDialog(BuildContext context, String pairingUrl) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.space5),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Scan to Pair', style: context.text.titleLarge),
                      const SizedBox(width: AppSpacing.space3),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  QrImageView(
                    data: pairingUrl,
                    size: 300,
                    backgroundColor: context.colors.onPrimary,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  Text(
                    'Point your camera device at this QR code',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showStartSessionDialog(BuildContext context) async {
  final now = DateTime.now();
  final defaultEvent = 'Event ${_formatDate(now)}';
  final defaultSession = 'Session ${_formatDateTime(now)}';
  final eventController = TextEditingController(text: defaultEvent);
  final sessionController = TextEditingController(text: defaultSession);

  final result = await showDialog<_SessionInput>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Start Recording Session'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: eventController,
                decoration: const InputDecoration(
                  labelText: 'Event name',
                  hintText: 'Event name',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.space3),
              TextField(
                controller: sessionController,
                decoration: const InputDecoration(
                  labelText: 'Session name',
                  hintText: 'Match / session name',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  Navigator.of(dialogContext).pop(
                    _SessionInput(
                      eventName: eventController.text.trim(),
                      sessionName: sessionController.text.trim(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          VarButton.ghost(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          VarButton.primary(
            label: 'Start',
            onPressed: () {
              Navigator.of(dialogContext).pop(
                _SessionInput(
                  eventName: eventController.text.trim(),
                  sessionName: sessionController.text.trim(),
                ),
              );
            },
          ),
        ],
      );
    },
  );

  if (result == null) return;

  final eventName = result.eventName.isNotEmpty ? result.eventName : defaultEvent;
  final sessionName =
      result.sessionName.isNotEmpty ? result.sessionName : defaultSession;

  await context.read<SessionProvider>().startRecording(
        eventId: eventName,
        matchId: sessionName,
        title: sessionName,
      );
  context.read<MarkProvider>().clearMarks();
  context.read<ClipProvider>().clearClips();
}

String _formatDate(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDateTime(DateTime dateTime) {
  final date = _formatDate(dateTime);
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$date $hour$minute';
}

class _SessionInput {
  final String eventName;
  final String sessionName;

  const _SessionInput({
    required this.eventName,
    required this.sessionName,
  });
}
