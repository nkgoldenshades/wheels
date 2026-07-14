import 'package:flutter/foundation.dart';

import '../models/seat_layout.dart';

class SeatLayoutController extends ChangeNotifier {
  SeatLayoutController({required SeatLayout initialLayout})
    : _layout = initialLayout;

  SeatLayout _layout;

  SeatLayout get layout => _layout;

  CellType lastUsedType = CellType.seat;

  int? selectedRow;
  int? selectedCol;

  void select(int row, int col) {
    selectedRow = row;
    selectedCol = col;
    notifyListeners();
  }

  LayoutCell? cellAt(int row, int col) {
    return _layout.cells['$row:$col'];
  }

  CellType cellTypeAt(int row, int col) {
    return cellAt(row, col)?.type ?? CellType.empty;
  }

  void expandToInclude(int row, int col) {
    final newRows = row + 1 > _layout.rows ? row + 1 : _layout.rows;
    final newCols = col + 1 > _layout.cols ? col + 1 : _layout.cols;
    if (newRows == _layout.rows && newCols == _layout.cols) return;

    _layout = _layout.copyWith(rows: newRows, cols: newCols);
    notifyListeners();
  }

  void removeLastRow() {
    if (_layout.rows <= 1) return;
    final newRows = _layout.rows - 1;
    final nextCells = Map<String, LayoutCell>.from(_layout.cells);
    nextCells.removeWhere((key, value) => value.row >= newRows);

    _layout = _layout.copyWith(rows: newRows, cells: nextCells);
    if (selectedRow != null && selectedRow! >= newRows) {
      selectedRow = null;
      selectedCol = null;
    }
    notifyListeners();
  }

  void removeLastColumn() {
    if (_layout.cols <= 1) return;
    final newCols = _layout.cols - 1;
    final nextCells = Map<String, LayoutCell>.from(_layout.cells);
    nextCells.removeWhere((key, value) => value.col >= newCols);

    _layout = _layout.copyWith(cols: newCols, cells: nextCells);
    if (selectedCol != null && selectedCol! >= newCols) {
      selectedRow = null;
      selectedCol = null;
    }
    notifyListeners();
  }

  bool canEditCell(LayoutCell c) {
    if (c.type != CellType.seat) return true;
    return !c.isLocked;
  }

  void toggleLock(int row, int col) {
    final c = cellAt(row, col);
    if (c == null) return;
    if (c.type != CellType.seat) return;

    _layout = _layout.copyWith(
      cells: {
        ..._layout.cells,
        c.key: c.copyWith(isLocked: !c.isLocked),
      },
    );
    notifyListeners();
  }

  void resize(int rows, int cols) {
    if (rows <= 0 || cols <= 0) return;
    final nextCells = Map<String, LayoutCell>.from(_layout.cells);
    nextCells.removeWhere(
      (key, value) => value.row >= rows || value.col >= cols,
    );
    _layout = _layout.copyWith(rows: rows, cols: cols, cells: nextCells);

    if (selectedRow != null && selectedRow! >= rows) {
      selectedRow = null;
      selectedCol = null;
    }
    notifyListeners();
  }

  void updateImages(List<String> images) {
    _layout = _layout.copyWith(images: images);
    notifyListeners();
  }

  void addImage(String base64Image) {
    final currentImages = List<String>.from(_layout.images);
    if (currentImages.length < 4) {
      currentImages.add(base64Image);
      _layout = _layout.copyWith(images: currentImages);
      notifyListeners();
    }
  }

  void removeImage(int index) {
    final currentImages = List<String>.from(_layout.images);
    if (index >= 0 && index < currentImages.length) {
      currentImages.removeAt(index);
      _layout = _layout.copyWith(images: currentImages);
      notifyListeners();
    }
  }

  void fillAllSeats(int price) {
    final nextCells = Map<String, LayoutCell>.from(_layout.cells);
    for (int r = 0; r < _layout.rows; r++) {
      for (int c = 0; c < _layout.cols; c++) {
        final key = '$r:$c';
        if (!nextCells.containsKey(key)) {
          final seatName = _resolveSeatName(row: r, col: c, input: null);
          nextCells[key] = LayoutCell(
            row: r,
            col: c,
            type: CellType.seat,
            seatName: seatName,
            price: price,
          );
        }
      }
    }
    _layout = _layout.copyWith(cells: nextCells);
    notifyListeners();
  }

  void clearCell(int row, int col) {
    final c = cellAt(row, col);
    if (c != null && c.type == CellType.seat && c.isLocked) return;

    final next = Map<String, LayoutCell>.from(_layout.cells);
    next.remove('$row:$col');
    _layout = _layout.copyWith(cells: next);
    notifyListeners();
  }

  void setSpace(int row, int col) {
    expandToInclude(row, col);

    final existing = cellAt(row, col);
    if (existing != null &&
        existing.type == CellType.seat &&
        existing.isLocked) {
      return;
    }

    final c = LayoutCell(row: row, col: col, type: CellType.space);
    _layout = _layout.copyWith(cells: {..._layout.cells, c.key: c});
    lastUsedType = CellType.space;
    notifyListeners();
  }

  void setSeat({
    required int row,
    required int col,
    required String? seatName,
    required int? price,
    int? securityDeposit,
    SeatKind seatKind = SeatKind.seat,
    SeatGender gender = SeatGender.any,
    bool locked = false,
  }) {
    expandToInclude(row, col);

    final existing = cellAt(row, col);
    if (existing != null &&
        existing.type == CellType.seat &&
        existing.isLocked) {
      return;
    }

    final resolvedName = _resolveSeatName(row: row, col: col, input: seatName);
    final resolvedPrice = (price ?? 0);
    if (resolvedName.trim().isEmpty) {
      throw StateError('Seat name is required');
    }
    if (resolvedPrice <= 0) {
      throw StateError('Seat price must be > 0');
    }

    final unique = _ensureUniqueName(
      resolvedName.trim(),
      ignoreKey: '$row:$col',
    );

    final c = LayoutCell(
      row: row,
      col: col,
      type: CellType.seat,
      seatName: unique,
      price: resolvedPrice,
      securityDeposit: securityDeposit,
      seatKind: seatKind,
      gender: gender,
      isLocked: locked,
    );

    _layout = _layout.copyWith(cells: {..._layout.cells, c.key: c});
    lastUsedType = CellType.seat;
    notifyListeners();
  }

  void convertSeatToSpace(int row, int col) {
    final c = cellAt(row, col);
    if (c == null) return;
    if (c.type != CellType.seat) return;
    if (c.isLocked) return;

    setSpace(row, col);
  }

  String _resolveSeatName({
    required int row,
    required int col,
    required String? input,
  }) {
    final candidate = (input ?? '').trim();
    if (candidate.isNotEmpty) return candidate;
    return '${_rowToLetters(row)}${col + 1}';
  }

  String _ensureUniqueName(String base, {required String ignoreKey}) {
    final norm = base.trim();
    final used = <String>{};
    for (final e in _layout.cells.entries) {
      if (e.key == ignoreKey) continue;
      final c = e.value;
      if (c.type != CellType.seat) continue;
      final name = c.seatName;
      if (name == null) continue;
      used.add(name.trim().toLowerCase());
    }

    if (!used.contains(norm.toLowerCase())) return norm;

    var i = 1;
    while (true) {
      final next = '$norm-$i';
      if (!used.contains(next.toLowerCase())) return next;
      i++;
    }
  }

  static String _rowToLetters(int row) {
    var n = row;
    var s = '';
    while (true) {
      final rem = n % 26;
      s = String.fromCharCode(65 + rem) + s;
      n = (n ~/ 26) - 1;
      if (n < 0) break;
    }
    return s;
  }

  void validate() {
    if (_layout.rows <= 0 || _layout.cols <= 0) {
      throw StateError('Grid size must be positive');
    }

    final seenKeys = <String>{};
    final seenNames = <String>{};

    for (final entry in _layout.cells.entries) {
      final key = entry.key;
      if (!seenKeys.add(key)) {
        throw StateError('Duplicate cell key: $key');
      }

      final c = entry.value;
      if (c.row < 0 ||
          c.col < 0 ||
          c.row >= _layout.rows ||
          c.col >= _layout.cols) {
        throw StateError('Cell out of bounds: $key');
      }

      if (c.type == CellType.empty) {
        throw StateError('Empty cells should not be stored');
      }

      if (c.type == CellType.space) {
        if (c.seatName != null || c.price != null || c.isLocked) {
          throw StateError('Space cell must not have seat data');
        }
      }

      if (c.type == CellType.seat) {
        final name = (c.seatName ?? '').trim();
        if (name.isEmpty) throw StateError('Seat name missing at $key');
        final price = c.price ?? 0;
        if (price <= 0) throw StateError('Invalid seat price at $key');

        final norm = name.toLowerCase();
        if (!seenNames.add(norm)) {
          throw StateError('Duplicate seat name: $name');
        }
      } else {
        // For non-seat, keep these at defaults to avoid leaking metadata.
        if (c.seatKind != SeatKind.seat || c.gender != SeatGender.any) {
          throw StateError('Non-seat cell must not have seat kind/gender');
        }
      }
    }
  }
}
