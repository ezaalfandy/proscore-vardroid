import 'package:flutter/material.dart';

/// Breadcrumb navigation widget for clip explorer.
class ExplorerBreadcrumb extends StatelessWidget {
  final List<String> items;
  final void Function(int index)? onTap;

  const ExplorerBreadcrumb({
    super.key,
    required this.items,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _buildBreadcrumbItems(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreadcrumbItems(BuildContext context) {
    final widgets = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final isLast = i == items.length - 1;

      widgets.add(
        InkWell(
          onTap: isLast ? null : () => onTap?.call(i),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              items[i],
              style: TextStyle(
                color: isLast ? Colors.black87 : Colors.blue[700],
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                decoration: isLast ? null : TextDecoration.underline,
              ),
            ),
          ),
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.grey[500],
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
