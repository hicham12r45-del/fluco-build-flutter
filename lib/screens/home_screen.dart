import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/github_models.dart';
import '../services/auth_manager.dart';
import '../theme/app_theme.dart';
import 'build_progress_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthManager authManager;

  const HomeScreen({super.key, required this.authManager});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<FlutterProject> _recentProjects = [];

  Future<void> _pickProjectFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'اختر مجلد مشروع Flutter',
    );
    if (path == null) return;

    final name = path.split('/').last;
    setState(() {
      _recentProjects.insert(0, FlutterProject(name: name, path: path, packageName: 'com.example.$name'));
    });
  }

  void _startBuild(FlutterProject project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuildProgressScreen(authManager: widget.authManager, project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(text: 'Fluco ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Build', style: TextStyle(color: AppTheme.accent)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen(authManager: widget.authManager)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 14, backgroundColor: AppTheme.surfaceAlt),
                          const SizedBox(width: 6),
                          Text(
                            '@${widget.authManager.username ?? ''}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: _pickProjectFolder,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.create_new_folder_outlined, color: AppTheme.accent, size: 32),
                        SizedBox(height: 10),
                        Text('اختر مجلد مشروع Flutter', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text(
                          'اضغط هنا لتصفح المجلدات على جهازك',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'المشاريع الأخيرة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            if (_recentProjects.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text('لا توجد مشاريع بعد', style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: _recentProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final project = _recentProjects[index];
                    return _ProjectCard(project: project, onBuild: () => _startBuild(project));
                  },
                ),
              ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final FlutterProject project;
  final VoidCallback onBuild;

  const _ProjectCard({required this.project, required this.onBuild});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.flutter_dash_rounded, color: Colors.lightBlueAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  project.packageName,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onBuild,
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: const Text('بناء'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
