import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/group_event.dart';

const _kCurrencies = ['ARS', 'USD', 'EUR', 'BRL', 'UYU', 'CLP'];

class CreateGroupEventScreen extends ConsumerStatefulWidget {
  const CreateGroupEventScreen({super.key});

  @override
  ConsumerState<CreateGroupEventScreen> createState() => _CreateGroupEventScreenState();
}

class _CreateGroupEventScreenState extends ConsumerState<CreateGroupEventScreen> {
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String _baseCurrency = 'ARS';
  SplitMode _splitMode = SplitMode.perCurrency;
  bool _saving = false;
  Uint8List? _coverBytes;
  String? _coverMime;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _coverBytes = bytes;
      _coverMime = file.mimeType ?? 'image/jpeg';
    });
  }

  Future<String?> _uploadCover(String eventId) async {
    if (_coverBytes == null) return null;
    final path = '$eventId/cover.jpg';
    await supabase.storage.from('group-covers').uploadBinary(
          path,
          _coverBytes!,
          fileOptions: FileOptions(upsert: true, contentType: _coverMime),
        );
    return supabase.storage.from('group-covers').getPublicUrl(path);
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _startDate) : _startDate,
      firstDate: isEnd ? _startDate : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresá un nombre para el evento');
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final userMeta = supabase.auth.currentUser!.userMetadata;

      // Crear el evento
      final eventRow = await supabase
          .from('group_events')
          .insert({
            'created_by': userId,
            'name': name,
            'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
            'end_date': _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
            'status': 'open',
            'split_mode': _splitMode == SplitMode.perCurrency ? 'per_currency' : 'base_currency',
            'base_currency': _baseCurrency,
          })
          .select()
          .single();

      // Agregar al creador como primer miembro accepted
      await supabase.from('group_members').insert({
        'event_id': eventRow['id'],
        'user_id': userId,
        'display_name': userMeta?['full_name'] as String? ?? supabase.auth.currentUser!.email,
        'status': 'accepted',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // Subir foto de portada si el usuario eligió una
      final coverUrl = await _uploadCover(eventRow['id'] as String);
      if (coverUrl != null) {
        await supabase.from('group_events')
            .update({'cover_image_url': coverUrl})
            .eq('id', eventRow['id'] as String);
      }

      if (mounted) context.pushReplacement('/groups/${eventRow['id']}');
    } catch (e) {
      _showError('No se pudo crear el evento: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo evento grupal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Foto de portada opcional
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                image: _coverBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_coverBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _coverBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 8),
                        Text('Foto de portada (opcional)',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.outline)),
                      ],
                    )
                  : Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: FilledButton.tonal(
                          onPressed: _pickCover,
                          child: const Text('Cambiar foto'),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del evento',
              hintText: 'Ej: Vacaciones Brasil, Departamento 2026',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),
          Text('Fechas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isEnd: false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('Desde: ${dateFmt.format(_startDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isEnd: true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_endDate != null
                      ? 'Hasta: ${dateFmt.format(_endDate!)}'
                      : 'Hasta: (opcional)'),
                ),
              ),
            ],
          ),
          if (_endDate != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _endDate = null),
                child: const Text('Quitar fecha fin'),
              ),
            ),
          const SizedBox(height: 24),
          Text('Moneda base', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _kCurrencies
                .map((c) => ChoiceChip(
                      label: Text(c),
                      selected: _baseCurrency == c,
                      onSelected: (_) => setState(() => _baseCurrency = c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          Text('Modo de reparto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          RadioGroup<SplitMode>(
            groupValue: _splitMode,
            onChanged: (v) => setState(() => _splitMode = v!),
            child: Column(
              children: [
                RadioListTile<SplitMode>(
                  value: SplitMode.perCurrency,
                  title: const Text('Por moneda'),
                  subtitle: const Text('Cada moneda tiene su propio % de responsabilidad'),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<SplitMode>(
                  value: SplitMode.baseCurrency,
                  title: const Text('Sobre total convertido'),
                  subtitle: const Text('Todo se convierte a la moneda base para un único %'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear evento'),
          ),
        ],
      ),
    );
  }
}
