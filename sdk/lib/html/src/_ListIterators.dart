// Copyright (c) 2011, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of html;

// Iterator for arrays with fixed size.
class FixedSizeListIterator<T> extends _VariableSizeListIterator<T> {
  FixedSizeListIterator(List<T> array)
      : super(array),
        _length = array.length;

  bool get hasNext => _length > _pos;

  final int _length;  // Cache array length for faster access.
}

// Iterator for arrays with variable size.
class _VariableSizeListIterator<T> implements Iterator<T> {
  _VariableSizeListIterator(List<T> array)
      : _array = array,
        _pos = 0;

  bool get hasNext => _array.length > _pos;

  T next() {
    if (!hasNext) {
      throw new StateError("No more elements");
    }
    return _array[_pos++];
  }

  final List<T> _array;
  int _pos;
}
