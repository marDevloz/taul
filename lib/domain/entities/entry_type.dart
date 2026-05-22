enum EntryType {
  glossary('GLOSARIO'),
  note('NOTA'),
  idea('IDEA'),
  credential('CREDENCIAL');

  final String label;
  const EntryType(this.label);

  static EntryType fromLabel(String label) {
    return EntryType.values.firstWhere(
      (e) => e.label == label,
      orElse: () => EntryType.note,
    );
  }
}
