import 'package:flutter/material.dart';
import '../models/plan.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/plan_service.dart';
import '../theme.dart';
import 'detail_screen.dart';

class PlanScreen extends StatefulWidget {
  final PlanService planService;
  final ApiService apiService;
  final LocationService? locationService;

  const PlanScreen({
    super.key,
    required this.planService,
    required this.apiService,
    this.locationService,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  /// Splits items into incomplete (sorted by sortOrder) followed by completed.
  List<PlanItem> _sortedItems(List<PlanItem> items) {
    final incomplete =
        items.where((i) => !i.completed).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final completed =
        items.where((i) => i.completed).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [...incomplete, ...completed];
  }

  Future<void> _showNotesDialog(PlanItem item) async {
    final controller = TextEditingController(text: item.notes);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add notes for this step...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result != item.notes) {
      widget.planService.updateItem(item.id, notes: result);
    }
  }

  Future<void> _confirmDelete(PlanItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Step'),
        content: Text('Remove "${item.entityName}" from your plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.planService.removeFromPlan(item.id);
    }
  }

  void _navigateToDetail(PlanItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(
          apiService: widget.apiService,
          entityId: item.entityId,
          entityName: item.entityName,
          planService: widget.planService,
          locationService: widget.locationService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Plan'),
        automaticallyImplyLeading: false,
      ),
      body: ListenableBuilder(
        listenable: widget.planService,
        builder: (context, _) {
          final allItems = widget.planService.items;
          final isLoading = widget.planService.loading;

          if (isLoading && allItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (allItems.isEmpty) {
            return _buildEmptyState(context);
          }

          final sorted = _sortedItems(allItems);

          return RefreshIndicator(
            onRefresh: () => widget.planService.syncWithServer(),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              itemCount: sorted.length,
              onReorder: (oldIndex, newIndex) {
                // ReorderableListView adjusts newIndex when moving down
                if (newIndex > oldIndex) newIndex--;
                final reordered = List<PlanItem>.from(sorted);
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                // Update sortOrder values
                final updated = reordered
                    .asMap()
                    .entries
                    .map((e) => e.value.copyWith(sortOrder: e.key))
                    .toList();
                widget.planService.reorder(updated);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final item = sorted[index];
                final stepNumber = index + 1;

                return _PlanItemCard(
                  key: ValueKey(item.id),
                  item: item,
                  stepNumber: stepNumber,
                  onTap: () => _navigateToDetail(item),
                  onToggleCompleted: () {
                    widget.planService
                        .updateItem(item.id, completed: !item.completed);
                  },
                  onEditNotes: () => _showNotesDialog(item),
                  onDelete: () => _confirmDelete(item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined,
              size: 64, color: AppColors.muted(context).withAlpha(128)),
          const SizedBox(height: 16),
          Text(
            'Your plan is empty',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'My Plan helps you organize the services you need. '
              'Search for services, then tap "Add to Plan" on any '
              'listing to create your personalized action list.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 14,
                height: 1.5,
                color: AppColors.muted(context),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(
              'You can add notes, track progress, and keep '
              'everything in one place.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 13,
                height: 1.4,
                color: AppColors.muted(context).withAlpha(180),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanItemCard extends StatelessWidget {
  final PlanItem item;
  final int stepNumber;
  final VoidCallback onTap;
  final VoidCallback onToggleCompleted;
  final VoidCallback onEditNotes;
  final VoidCallback onDelete;

  const _PlanItemCard({
    super.key,
    required this.item,
    required this.stepNumber,
    required this.onTap,
    required this.onToggleCompleted,
    required this.onEditNotes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Opacity(
      opacity: item.completed ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          border: Border.all(color: AppColors.cardBorderOf(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent(context).withAlpha(30),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$stepNumber',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent(context),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Entity name
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      item.entityName,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent(context),
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),

                  // Address line
                  if (item.addressLine1 != null &&
                      item.addressLine1!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _buildAddressText(),
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: AppColors.muted(context),
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ],

                  // Phone
                  if (item.phone != null && item.phone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.phone!,
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 13,
                        color: AppColors.muted(context),
                        decoration: item.completed
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ],

                  // Notes area
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onEditNotes,
                    child: item.notes.isNotEmpty
                        ? Text(
                            item.notes,
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: AppColors.muted(context),
                              decoration: item.completed
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          )
                        : Text(
                            'Tap to add notes',
                            style: TextStyle(
                              fontFamily: 'DMSans',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color:
                                  AppColors.muted(context).withAlpha(128),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right side: checkbox + drag handle
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: item.completed,
                    onChanged: (_) => onToggleCompleted(),
                    activeColor: AppColors.greenTextOf(context),
                  ),
                ),
                const SizedBox(height: 12),
                Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: AppColors.muted(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // We handle deletion in the dialog
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade700),
      ),
      child: cardContent,
    );
  }

  String _buildAddressText() {
    final parts = <String>[];
    if (item.addressLine1 != null && item.addressLine1!.isNotEmpty) {
      parts.add(item.addressLine1!);
    }
    if (item.city != null && item.city!.isNotEmpty) {
      if (item.state != null && item.state!.isNotEmpty) {
        parts.add('${item.city}, ${item.state}');
      } else {
        parts.add(item.city!);
      }
    } else if (item.state != null && item.state!.isNotEmpty) {
      parts.add(item.state!);
    }
    return parts.join(', ');
  }
}
