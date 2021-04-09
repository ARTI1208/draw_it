extension ExtendedList<E> on List<E> {

  set safeLast(E newLast) {
    if (isEmpty) {
      add(newLast);
    } else {
      this[length - 1] = newLast;
    }
  }
}