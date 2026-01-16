import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/device_storage_service.dart';
import 'package:var_protocol/var_protocol.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DeviceStorageService _storage = DeviceStorageService();

  String _resolution = '1080p';
  int _fps = 30;
  int _clipPreRoll = 10;
  int _clipPostRoll = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final resolution = await _storage.getVideoResolution();
    final fps = await _storage.getVideoFps();

    setState(() {
      _resolution = resolution;
      _fps = fps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildSection(
            title: 'Video Profile',
            children: [
              _buildDropdownTile(
                title: 'Resolution',
                value: _resolution,
                items: ['720p', '1080p', '4K'],
                onChanged: (value) async {
                  if (value != null) {
                    await _storage.setVideoResolution(value);
                    setState(() => _resolution = value);
                  }
                },
                icon: Icons.high_quality,
              ),
              _buildDropdownTile(
                title: 'Frame Rate',
                value: '$_fps fps',
                items: ['30 fps', '60 fps'],
                onChanged: (value) async {
                  if (value != null) {
                    final fps = int.parse(value.split(' ').first);
                    await _storage.setVideoFps(fps);
                    setState(() => _fps = fps);
                  }
                },
                icon: Icons.speed,
              ),
            ],
          ),
          _buildSection(
            title: 'Clip Export Defaults',
            children: [
              _buildSliderTile(
                title: 'Pre-roll',
                value: _clipPreRoll.toDouble(),
                min: 5,
                max: 30,
                divisions: 5,
                label: '$_clipPreRoll seconds',
                onChanged: (value) {
                  setState(() => _clipPreRoll = value.toInt());
                },
                icon: Icons.fast_rewind,
              ),
              _buildSliderTile(
                title: 'Post-roll',
                value: _clipPostRoll.toDouble(),
                min: 3,
                max: 15,
                divisions: 4,
                label: '$_clipPostRoll seconds',
                onChanged: (value) {
                  setState(() => _clipPostRoll = value.toInt());
                },
                icon: Icons.fast_forward,
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Clip Window'),
                subtitle: Text(
                  'Clips will include $_clipPreRoll seconds before and $_clipPostRoll seconds after marks',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'Network',
            children: [
              Consumer<ConnectionProvider>(
                builder: (context, connectionProvider, child) {
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: connectionProvider.getLastCoordinator(),
                    builder: (context, snapshot) {
                      final lastCoordinator = snapshot.data;

                      return ListTile(
                        leading: const Icon(Icons.router),
                        title: const Text('Last Coordinator'),
                        subtitle: Text(
                          lastCoordinator != null
                              ? '${lastCoordinator['host']}:${lastCoordinator['port']}'
                              : 'None',
                        ),
                        trailing: lastCoordinator != null
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () async {
                                  await _storage.clearPairingData();
                                  setState(() {});
                                },
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Device Information',
            children: [
              FutureBuilder<String?>(
                future: _storage.getDeviceId(),
                builder: (context, snapshot) {
                  return ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: const Text('Device ID'),
                    subtitle: Text(
                      snapshot.data?.substring(0, 8) ?? 'Unknown',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  );
                },
              ),
              Consumer<ConnectionProvider>(
                builder: (context, connectionProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.label),
                    title: const Text('Assigned Name'),
                    subtitle: Text(
                      connectionProvider.assignedName ?? 'Not assigned',
                    ),
                  );
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Storage',
            children: [
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Base Directory'),
                subtitle: const Text('/VAR/'),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Storage Info'),
                subtitle: const Text(
                  'Recordings are stored locally in the VAR directory',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          _buildSection(
            title: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.apps),
                title: Text('App Version'),
                subtitle: Text('0.1.0 MVP'),
              ),
              const ListTile(
                leading: Icon(Icons.code),
                title: Text('Protocol Version'),
                subtitle: Text(VarProtocol.version),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required Function(double) onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
      ),
      trailing: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
