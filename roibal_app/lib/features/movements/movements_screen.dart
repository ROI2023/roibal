// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/category.dart';
import '../../data/models/movement_item.dart';
import '../../data/providers/finance_providers.dart';
import '../../data/providers/movements_provider.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key});

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  DateTime _focusMonth = DateTime.now();
  bool _showIngresos = true;
  bool _showSalidas = true;
  bool _showLiquidaciones = true;

  final _searchController = TextEditingController();
  String _searchText = '';
  String? _filterCurrency;
  String? _filterCategoryId;
  String? _filterAccountId;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  DateTime get _startDate =>
      DateTime(_focusMonth.year, _focusMonth.month, 1);

  DateTime get _endDate {
    final now = DateTime.now();
    if (_focusMonth.year == now.year && _focusMonth.month == now.month) {
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(_focusMonth.year, _focusMonth.month + 1, 0);
  }

  void _prevMonth() => setState(() {
        _focusMonth = DateTime(_focusMonth.year, _focusMonth.month - 1);
        _filterDateFrom = null;
        _filterDateTo = null;
      });

  void _nextMonth() {
    final now = DateTime.now();
    if (_focusMonth.year == now.year && _focusMonth.month == now.month) return;
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + 1);
      _filterDateFrom = null;
      _filterDateTo = null;
    });
  }

  List<MovementItem> _applyFilters(List<MovementItem> items) {
    final search = _searchText.toLowerCase();
    return items.where((item) {
      if (!_showIngresos && item.movementType == MovementType.ingreso) {
        return false;
      }
      if (!_showSalidas && item.movementType == MovementType.salida) {
        return false;
      }
      if (!_showLiquidaciones &&
          item.movementType == MovementType.liquidacion) {
        return false;
      }
      if (search.isNotEmpty &&
          !item.description.toLowerCase().contains(search)) {
        return false;
      }
      if (_filterCurrency != null && item.currency != _filterCurrency) {
        return false;
      }
      if (_filterCategoryId != null &&
          item.categoryId != _filterCategoryId) {
        return false;
      }
      if (_filterAccountId != null && item.accountId != _filterAccountId) {
        return false;
      }
      if (_filterDateFrom != null) {
        final from = DateTime(
            _filterDateFrom!.year, _filterDateFrom!.month, _filterDateFrom!.day);
        if (item.date.isBefore(from)) return false;
      }
      if (_filterDateTo != null) {
        final to = DateTime(
            _filterDateTo!.year, _filterDateTo!.month, _filterDateTo!.day + 1);
        if (!item.date.isBefore(to)) return false;
      }
      return true;
    }).toList();
  }

  void _sortItems(List<MovementItem> items) {
    items.sort((a, b) {
      final cmp = switch (_sortColumnIndex) {
        1 => a.description.compareTo(b.description),
        2 => (a.categoryName ?? '').compareTo(b.categoryName ?? ''),
        3 => (a.accountName ?? '').compareTo(b.accountName ?? ''),
        4 => a.currency.compareTo(b.currency),
        5 => a.totalAmount.compareTo(b.totalAmount),
        _ => a.date.compareTo(b.date),
      };
      return _sortAscending ? cmp : -cmp;
    });
  }

  Map<String, ({double ingresos, double salidas})> _totals(
      List<MovementItem> items) {
    final map = <String, ({double ingresos, double salidas})>{};
    for (final item in items) {
      final cur = item.currency;
      final prev = map[cur] ?? (ingresos: 0.0, salidas: 0.0);
      if (item.movementType == MovementType.ingreso) {
        map[cur] = (ingresos: prev.ingresos + item.totalAmount, salidas: prev.salidas);
      } else if (item.movementType == MovementType.salida) {
        map[cur] = (ingresos: prev.ingresos, salidas: prev.salidas + item.totalAmount);
      }
    }
    return map;
  }

  Future<bool> _isGroupLinked(String transactionId) async {
    final rows = await supabase
        .from('group_expenses')
        .select('id')
        .eq('personal_transaction_id', transactionId)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> _editItem(MovementItem item) async {
    if (item.isTransfer) {
      _showInfo(
          'Las liquidaciones no pueden editarse individualmente.');
      return;
    }

    final isGroup = await _isGroupLinked(item.id);
    if (!mounted) return;

    if (isGroup) {
      _showInfo(
          'Este gasto pertenece a un evento grupal y solo puede editarse desde el grupo.');
      return;
    }

    final nameCtrl = TextEditingController(text: item.description);
    String? selectedCategoryId = item.categoryId;

    final categories = await ref.read(
        item.categoryType == CategoryType.income
            ? incomeCategoriesProvider.future
            : expenseCategoriesProvider.future);
    if (!mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Editar movimiento'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Descripción'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text('Categoría',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: categories
                        .map((c) => ChoiceChip(
                              label: Text(c.name),
                              selected: selectedCategoryId == c.id,
                              onSelected: (_) =>
                                  setS(() => selectedCategoryId = c.id),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;
    try {
      await supabase.from('transactions').update({
        'description': nameCtrl.text.trim().isEmpty
            ? item.description
            : nameCtrl.text.trim(),
        'category_id': selectedCategoryId,
      }).eq('id', item.id);
      ref.invalidate(movementsProvider);
    } catch (e) {
      if (mounted) _showError('Error al guardar: $e');
    }
  }

  Future<void> _deleteItem(MovementItem item) async {
    if (item.isTransfer) {
      _showInfo(
          'Las liquidaciones no pueden eliminarse individualmente.');
      return;
    }

    final isGroup = await _isGroupLinked(item.id);
    if (!mounted) return;

    if (isGroup) {
      _showInfo(
          'Este gasto pertenece a un evento grupal y debe eliminarse desde el grupo.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: Text('¿Eliminás "${item.description}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await supabase
          .from('transaction_movements')
          .delete()
          .eq('transaction_id', item.id);
      await supabase.from('transactions').delete().eq('id', item.id);
      ref.invalidate(movementsProvider);
    } catch (e) {
      if (mounted) _showError('Error al eliminar: $e');
    }
  }

  void _showInfo(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportPdf(List<MovementItem> items) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final monthLabel =
        DateFormat('MMMM yyyy', 'es').format(_focusMonth);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text('Movimientos · $monthLabel',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Fecha', 'Descripción', 'Tipo', 'Categoría', 'Cuenta', 'Moneda', 'Monto'
            ],
            data: items
                .map((i) => [
                      dateFmt.format(i.date),
                      i.description,
                      switch (i.movementType) {
                        MovementType.ingreso => 'Ingreso',
                        MovementType.salida => 'Salida',
                        MovementType.liquidacion => 'Liquidación',
                      },
                      i.categoryName ?? '-',
                      i.accountName ?? '-',
                      i.currency,
                      i.totalAmount.toStringAsFixed(2),
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'movimientos_${_focusMonth.year}_${_focusMonth.month.toString().padLeft(2, '0')}.pdf');
  }

  void _exportCsv(List<MovementItem> items) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final buf = StringBuffer();
    buf.writeln('Fecha,Descripción,Tipo,Categoría,Cuenta,Moneda,Monto');
    for (final item in items) {
      final tipo = switch (item.movementType) {
        MovementType.ingreso => 'Ingreso',
        MovementType.salida => 'Salida',
        MovementType.liquidacion => 'Liquidación',
      };
      final desc = item.description.replaceAll('"', '""');
      final cat = (item.categoryName ?? '-').replaceAll('"', '""');
      final acc = (item.accountName ?? '-').replaceAll('"', '""');
      buf.writeln(
          '"${dateFmt.format(item.date)}","$desc","$tipo","$cat","$acc","${item.currency}","${item.totalAmount.toStringAsFixed(2)}"');
    }
    final bytes = utf8.encode(buf.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download',
          'movimientos_${_focusMonth.year}_${_focusMonth.month.toString().padLeft(2, '0')}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _pickFilterDate(bool isFrom) async {
    final initial = isFrom
        ? (_filterDateFrom ?? _startDate)
        : (_filterDateTo ?? _endDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _startDate,
      lastDate: _endDate,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _filterDateFrom = picked;
        if (_filterDateTo != null && _filterDateTo!.isBefore(picked)) {
          _filterDateTo = picked;
        }
      } else {
        _filterDateTo = picked;
        if (_filterDateFrom != null && _filterDateFrom!.isAfter(picked)) {
          _filterDateFrom = picked;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final movAsync =
        ref.watch(movementsProvider((_startDate, _endDate)));
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final dateFmt = DateFormat('dd/MM/yyyy');
    final monthFmt = DateFormat('MMMM yyyy', 'es');
    final now = DateTime.now();
    final isCurrentMonth =
        _focusMonth.year == now.year && _focusMonth.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          movAsync.maybeWhen(
            data: (items) {
              final filtered = _applyFilters(items);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exportar PDF',
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _exportPdf(filtered),
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_chart_outlined),
                    tooltip: 'Exportar CSV',
                    onPressed:
                        filtered.isEmpty ? null : () => _exportCsv(filtered),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Navegador de mes ──────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left)),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _focusMonth,
                      firstDate: DateTime(2020),
                      lastDate: now,
                      initialEntryMode: DatePickerEntryMode.calendarOnly,
                    );
                    if (picked != null) {
                      setState(() {
                        _focusMonth =
                            DateTime(picked.year, picked.month);
                        _filterDateFrom = null;
                        _filterDateTo = null;
                      });
                    }
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      monthFmt.format(_focusMonth).toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                    onPressed: isCurrentMonth ? null : _nextMonth,
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),

          // ── Badges de tipo ───────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: movAsync.maybeWhen(
              data: (all) {
                final counts = {
                  MovementType.ingreso: 0,
                  MovementType.salida: 0,
                  MovementType.liquidacion: 0,
                };
                for (final i in all) {
                  counts[i.movementType] =
                      (counts[i.movementType] ?? 0) + 1;
                }
                return Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                          'Ingresos (${counts[MovementType.ingreso]})'),
                      selected: _showIngresos,
                      onSelected: (v) =>
                          setState(() => _showIngresos = v),
                      selectedColor: Colors.green.withValues(alpha: 0.2),
                      checkmarkColor: Colors.green,
                    ),
                    FilterChip(
                      label: Text(
                          'Salidas (${counts[MovementType.salida]})'),
                      selected: _showSalidas,
                      onSelected: (v) =>
                          setState(() => _showSalidas = v),
                      selectedColor: Colors.red.withValues(alpha: 0.2),
                      checkmarkColor: Colors.red,
                    ),
                    FilterChip(
                      label: Text(
                          'Liquidaciones (${counts[MovementType.liquidacion]})'),
                      selected: _showLiquidaciones,
                      onSelected: (v) =>
                          setState(() => _showLiquidaciones = v),
                      selectedColor: Colors.blueGrey.withValues(alpha: 0.2),
                    ),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 8),

          // ── Filtros de búsqueda ──────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar descripción...',
                          prefixIcon:
                              const Icon(Icons.search, size: 18),
                          suffixIcon: _searchText.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18),
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _searchText = '';
                                  }),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) =>
                            setState(() => _searchText = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Moneda
                    categories.maybeWhen(
                      orElse: () => const SizedBox.shrink(),
                      data: (_) => _CompactDropdown<String>(
                        hint: 'Moneda',
                        value: _filterCurrency,
                        items: const [
                          'ARS', 'USD', 'EUR', 'BRL', 'UYU', 'CLP'
                        ],
                        labelFor: (c) => c,
                        onChanged: (v) =>
                            setState(() => _filterCurrency = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Categoría
                    Expanded(
                      child: categories.maybeWhen(
                        orElse: () => const SizedBox.shrink(),
                        data: (cats) => _CompactDropdown<String>(
                          hint: 'Categoría',
                          value: _filterCategoryId,
                          items: cats.map((c) => c.id).toList(),
                          labelFor: (id) =>
                              cats
                                  .where((c) => c.id == id)
                                  .firstOrNull
                                  ?.name ??
                              id,
                          onChanged: (v) =>
                              setState(() => _filterCategoryId = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Cuenta
                    Expanded(
                      child: accounts.maybeWhen(
                        orElse: () => const SizedBox.shrink(),
                        data: (accs) => _CompactDropdown<String>(
                          hint: 'Cuenta',
                          value: _filterAccountId,
                          items: accs.map((a) => a.id).toList(),
                          labelFor: (id) =>
                              accs
                                  .where((a) => a.id == id)
                                  .firstOrNull
                                  ?.name ??
                              id,
                          onChanged: (v) =>
                              setState(() => _filterAccountId = v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fecha desde
                    OutlinedButton.icon(
                      onPressed: () => _pickFilterDate(true),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(_filterDateFrom != null
                          ? dateFmt.format(_filterDateFrom!)
                          : 'Desde'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                    ),
                    const SizedBox(width: 4),
                    OutlinedButton.icon(
                      onPressed: () => _pickFilterDate(false),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: Text(_filterDateTo != null
                          ? dateFmt.format(_filterDateTo!)
                          : 'Hasta'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8)),
                    ),
                    if (_filterDateFrom != null || _filterDateTo != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Quitar filtro de fecha',
                        onPressed: () => setState(() {
                          _filterDateFrom = null;
                          _filterDateTo = null;
                        }),
                      ),
                  ],
                ),
                // Limpiar todos los filtros
                if (_filterCurrency != null ||
                    _filterCategoryId != null ||
                    _filterAccountId != null ||
                    _searchText.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchText = '';
                        _filterCurrency = null;
                        _filterCategoryId = null;
                        _filterAccountId = null;
                        _filterDateFrom = null;
                        _filterDateTo = null;
                      }),
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(),

          // ── Tabla ────────────────────────────────────────────────────────
          Expanded(
            child: movAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allItems) {
                final filtered = _applyFilters(allItems);
                _sortItems(filtered);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Sin movimientos para este período',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final totals = _totals(filtered);

                return Column(
                  children: [
                    // Totales
                    _TotalsBar(totals: totals),
                    const Divider(height: 1),
                    // Tabla con scroll
                    Expanded(
                      child: _MovementsTable(
                        items: filtered,
                        sortColumnIndex: _sortColumnIndex,
                        sortAscending: _sortAscending,
                        onSort: (colIdx, asc) => setState(() {
                          _sortColumnIndex = colIdx;
                          _sortAscending = asc;
                        }),
                        onEdit: _editItem,
                        onDelete: _deleteItem,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Totals bar ─────────────────────────────────────────────────────────────

class _TotalsBar extends StatelessWidget {
  final Map<String, ({double ingresos, double salidas})> totals;
  const _TotalsBar({required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: totals.entries.map((e) {
          final neto = e.value.ingresos - e.value.salidas;
          return Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${e.key} ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('▲ ${formatCurrency(e.value.ingresos, e.key)}',
                    style: const TextStyle(color: Colors.green)),
                const Text('  '),
                Text('▼ ${formatCurrency(e.value.salidas, e.key)}',
                    style: const TextStyle(color: Colors.red)),
                const Text('  '),
                Text(
                  'Neto: ${formatCurrency(neto, e.key)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: neto >= 0 ? Colors.green : Colors.red),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Tabla con DataTable ─────────────────────────────────────────────────────

class _MovementsTable extends StatefulWidget {
  final List<MovementItem> items;
  final int sortColumnIndex;
  final bool sortAscending;
  final void Function(int, bool) onSort;
  final void Function(MovementItem) onEdit;
  final void Function(MovementItem) onDelete;

  const _MovementsTable({
    required this.items,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MovementsTable> createState() => _MovementsTableState();
}

class _MovementsTableState extends State<_MovementsTable> {
  static const int _rowsPerPage = 25;
  late final _Source _source;

  @override
  void initState() {
    super.initState();
    _source = _Source(
      widget.items,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }

  @override
  void didUpdateWidget(_MovementsTable old) {
    super.didUpdateWidget(old);
    _source.update(widget.items);
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  DataColumn _col(String label, int index) => DataColumn(
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onSort: (i, asc) => widget.onSort(i, asc),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: PaginatedDataTable(
        rowsPerPage: _rowsPerPage,
        availableRowsPerPage: const [25, 50, 100],
        onRowsPerPageChanged: null,
        sortColumnIndex: widget.sortColumnIndex,
        sortAscending: widget.sortAscending,
        columns: [
          _col('Fecha', 0),
          _col('Descripción', 1),
          _col('Categoría', 2),
          _col('Cuenta', 3),
          _col('Moneda', 4),
          _col('Monto', 5),
          const DataColumn(label: Text('')),
        ],
        source: _source,
      ),
    );
  }
}

class _Source extends DataTableSource {
  List<MovementItem> _items;
  final void Function(MovementItem) onEdit;
  final void Function(MovementItem) onDelete;

  _Source(
    this._items, {
    required this.onEdit,
    required this.onDelete,
  });

  void update(List<MovementItem> newItems) {
    _items = newItems;
    notifyListeners();
  }

  @override
  DataRow? getRow(int index) {
    if (index >= _items.length) return null;
    final item = _items[index];
    final dateFmt = DateFormat('dd/MM/yy');

    final (color, typeLabel) = switch (item.movementType) {
      MovementType.ingreso => (Colors.green, 'Ingreso'),
      MovementType.salida => (Colors.red, 'Salida'),
      MovementType.liquidacion => (Colors.blueGrey, 'Liquidación'),
    };

    final amountStr = item.movementType == MovementType.ingreso
        ? '+${item.totalAmount.toStringAsFixed(2)}'
        : '-${item.totalAmount.toStringAsFixed(2)}';

    return DataRow(cells: [
      DataCell(Text(dateFmt.format(item.date),
          style: const TextStyle(fontSize: 13))),
      DataCell(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item.description,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(typeLabel,
                style: TextStyle(fontSize: 10, color: color)),
          ),
        ],
      )),
      DataCell(Text(item.categoryName ?? '-',
          style: const TextStyle(fontSize: 13))),
      DataCell(Text(item.accountName ?? '-',
          style: const TextStyle(fontSize: 13))),
      DataCell(Text(item.currency,
          style: const TextStyle(fontSize: 13))),
      DataCell(Text(
        amountStr,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color),
      )),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!item.isTransfer) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: 'Editar',
              visualDensity: VisualDensity.compact,
              onPressed: () => onEdit(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: 'Eliminar',
              visualDensity: VisualDensity.compact,
              onPressed: () => onDelete(item),
            ),
          ],
        ],
      )),
    ]);
  }

  @override
  int get rowCount => _items.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

// ── Helper dropdown compacto ────────────────────────────────────────────────

class _CompactDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelFor;
  final void Function(T?) onChanged;

  const _CompactDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text('Todos', style: TextStyle(color: Theme.of(context).hintColor)),
        ),
        ...items.map((i) => DropdownMenuItem<T>(
              value: i,
              child: Text(labelFor(i),
                  overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
