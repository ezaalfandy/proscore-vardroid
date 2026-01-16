import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/mock_data.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme_extensions.dart';
import '../widgets/device_status_row.dart';
import '../widgets/status_dot.dart';
import '../widgets/var_badge.dart';
import '../widgets/var_button.dart';
import '../widgets/var_card.dart';

class CoordinatorHome extends StatefulWidget {
  const CoordinatorHome({super.key});

  @override
  State<CoordinatorHome> createState() => _CoordinatorHomeState();
}

class _CoordinatorHomeState extends State<CoordinatorHome> {
  bool isRecording = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              isRecording: isRecording,
              onToggleRecording: _toggleRecording,
            ),
            Expanded(
              child: Column(
                children: [
                  _Header(
                    isRecording: isRecording,
                    onToggleRecording: _toggleRecording,
                  ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleRecording() {
    if (isRecording) {
      _confirmStopRecording();
      return;
    }
    setState(() {
      isRecording = true;
    });
  }

  void _confirmStopRecording() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stop recording?'),
          content: const Text(
            'All cameras will stop recording. This action cannot be undone.',
          ),
          actions: [
            VarButton.ghost(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
            VarButton.danger(
              label: 'Stop',
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  isRecording = false;
                });
              },
            ),
          ],
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.isRecording,
    required this.onToggleRecording,
  });

  final bool isRecording;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          right: BorderSide(color: context.tokens.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(isRecording: isRecording),
          const SizedBox(height: AppSpacing.space5),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Overview',
            isActive: true,
          ),
          const SizedBox(height: AppSpacing.space3),
          _NavItem(
            icon: Icons.movie_creation_outlined,
            label: 'Clips',
          ),
          const SizedBox(height: AppSpacing.space3),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
          ),
          const SizedBox(height: AppSpacing.space5),
          Text('Pairing', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.space3),
          VarCard(
            background: context.tokens.surfaceAlt,
            padding: const EdgeInsets.all(AppSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: QrImageView(
                    data: 'var://pairing/COORD-2026-0415',
                    size: 120,
                    backgroundColor: context.colors.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.space3),
                Text('Pairing Code', style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.space2),
                Text(
                  'COORD-2026-0415',
                  style: context.text.bodyMedium?.copyWith(
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space5),
          Text('Quick Actions', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.space3),
          VarButton.secondary(
            label: 'Open Session',
            icon: Icons.folder_open,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.space2),
          VarButton.secondary(
            label: 'Sync Clips',
            icon: Icons.sync,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.space5),
          Text('Devices', style: context.text.titleMedium),
          const SizedBox(height: AppSpacing.space3),
          ...MockData.devices.map(
            (device) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space2),
              child: Row(
                children: [
                  StatusDot(status: device.status, size: 8),
                  const SizedBox(width: AppSpacing.space2),
                  Expanded(
                    child: Text(
                      device.name,
                      style: context.text.bodySmall,
                    ),
                  ),
                  Text(
                    device.ip,
                    style: context.text.bodySmall?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          VarButton.ghost(
            label: isRecording ? 'Stop Recording' : 'Start Recording',
            icon: isRecording ? Icons.stop_circle : Icons.fiber_manual_record,
            onPressed: onToggleRecording,
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
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
                  isRecording ? 'Recording' : 'Ready',
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
  });

  final IconData icon;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final highlight = isActive ? context.colors.primary : Colors.transparent;
    return Container(
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isRecording,
    required this.onToggleRecording,
  });

  final bool isRecording;
  final VoidCallback onToggleRecording;

  @override
  Widget build(BuildContext context) {
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
              Text('Match 04 - Semi Final', style: context.text.displaySmall),
              const SizedBox(height: AppSpacing.space1),
              Text(
                'Arena 1 - Pencak Silat National Cup',
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
                label: 'Network OK',
                color: context.tokens.success,
              ),
              VarBadge(
                label: '4/4 Cameras',
                color: context.colors.secondary,
              ),
              VarButton.secondary(
                label: 'Add Mark',
                icon: Icons.flag_outlined,
                onPressed: () {},
              ),
              VarButton.primary(
                label: isRecording ? 'Recording' : 'Start Recording',
                icon: Icons.fiber_manual_record,
                onPressed: isRecording ? null : onToggleRecording,
              ),
              VarButton.danger(
                label: 'Stop',
                icon: Icons.stop_circle,
                onPressed: isRecording ? onToggleRecording : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cameras', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.space3),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.space4,
          crossAxisSpacing: AppSpacing.space4,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: MockData.devices.map((device) {
            return _DeviceCard(device: device);
          }).toList(),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    return VarCard(
      background: context.tokens.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(status: device.status),
              const SizedBox(width: AppSpacing.space2),
              Expanded(
                child: Text(
                  device.name,
                  style: context.text.titleMedium,
                ),
              ),
              Text(
                device.ip,
                style: context.text.bodySmall?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space4),
          DeviceStatusRow(
            icon: Icons.battery_full,
            label: 'Battery',
            value: '${device.battery}%',
          ),
          const SizedBox(height: AppSpacing.space2),
          DeviceStatusRow(
            icon: Icons.sd_storage_outlined,
            label: 'Storage',
            value: '${device.storage} GB',
          ),
          const SizedBox(height: AppSpacing.space2),
          DeviceStatusRow(
            icon: Icons.thermostat_outlined,
            label: 'Temp',
            value: '${device.temperature} C',
          ),
          const Spacer(),
          Text(
            'Last clip: ${device.lastClip}',
            style: context.text.bodySmall?.copyWith(
              color: context.tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VarCard(
      background: context.tokens.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Clips', style: context.text.titleMedium),
              const Spacer(),
              VarButton.ghost(
                label: 'Export Selected',
                icon: Icons.download_outlined,
                onPressed: () {},
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
                  child: Text('Duration', style: context.text.bodySmall),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Status', style: context.text.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.space2),
          ...MockData.clips.map((clip) {
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
                      child: Text(clip.label, style: context.text.bodyMedium),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        clip.camera,
                        style: context.text.bodySmall?.copyWith(
                          color: context.tokens.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(clip.duration, style: context.text.bodySmall),
                    ),
                    Expanded(
                      flex: 2,
                      child: _ClipStatusBadge(state: clip.state),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ClipStatusBadge extends StatelessWidget {
  const _ClipStatusBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      'Ready' => context.tokens.success,
      'Downloading' => context.colors.secondary,
      'Failed' => context.colors.error,
      _ => context.colors.secondary,
    };
    return VarBadge(label: state, color: color);
  }
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar();

  @override
  Widget build(BuildContext context) {
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
              Text('Timeline Marks', style: context.text.titleMedium),
              const Spacer(),
              VarButton.ghost(
                label: 'Add Mark',
                icon: Icons.flag,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space3),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final mark = MockData.marks[index];
                return VarCard(
                  background: context.tokens.surfaceAlt,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.space4,
                    vertical: AppSpacing.space3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mark.label, style: context.text.bodyMedium),
                      const SizedBox(height: AppSpacing.space1),
                      Text(
                        mark.timecode,
                        style: context.text.bodySmall?.copyWith(
                          color: context.tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.space3),
              itemCount: MockData.marks.length,
            ),
          ),
        ],
      ),
    );
  }
}
