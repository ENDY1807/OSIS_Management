import 'package:flutter/material.dart';
import 'pelanggaran_screen.dart';
import 'kebaikan_screen.dart';
class KarakterSiswaScreen extends StatefulWidget {
  final String username;
  final int initialSubTab;
  const KarakterSiswaScreen({super.key, this.username = '', this.initialSubTab = 0});

  @override
  State<KarakterSiswaScreen> createState() => _KarakterSiswaScreenState();
}

class _KarakterSiswaScreenState extends State<KarakterSiswaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialSubTab.clamp(0, 1),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: _tabCtrl.index == 0
                    ? (isDark ? const Color(0xFFEF4444).withAlpha(50) : const Color(0xFFFEE2E2))
                    : (isDark ? const Color(0xFF10B981).withAlpha(50) : const Color(0xFFD1FAE5)),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _tabCtrl.index == 0
                      ? const Color(0xFFEF4444).withAlpha(160)
                      : const Color(0xFF10B981).withAlpha(160),
                  width: 1.2,
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: EdgeInsets.zero,
              labelColor: _tabCtrl.index == 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF059669),
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('Pelanggaran Siswa'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, size: 17),
                      SizedBox(width: 6),
                      Text('Catatan Kebaikan'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          PelanggaranScreen(username: widget.username),
          KebaikanScreen(username: widget.username),
        ],
      ),
    );
  }
}
