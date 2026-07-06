import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/group_event.dart';
import '../../data/providers/group_providers.dart';

class GroupEventsListScreen extends ConsumerWidget {
  const GroupEventsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(myGroupEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos grupales')),
      body: events.when(
        data: (data) => data.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No tenés eventos grupales todavía.',
                        style: TextStyle(color: Colors.grey)),
                    SizedBox(height: 8),
                    Text('Creá uno con el botón +',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myGroupEventsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _EventCard(event: data[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/groups/new');
          ref.invalidate(myGroupEventsProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final GroupEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final subtitle = event.endDate != null
        ? '${dateFormat.format(event.startDate)} – ${dateFormat.format(event.endDate!)}'
        : 'Desde ${dateFormat.format(event.startDate)}';

    return Card(
      child: ListTile(
        leading: const Icon(Icons.group_outlined),
        title: Text(event.name),
        subtitle: Text(subtitle),
        trailing: _StatusChip(event.status),
        onTap: () => context.push('/groups/${event.id}'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final GroupEventStatus status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      GroupEventStatus.open => ('Abierto', Colors.green),
      GroupEventStatus.pending => ('Pendiente', Colors.orange),
      GroupEventStatus.balanced => ('Saldado', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
