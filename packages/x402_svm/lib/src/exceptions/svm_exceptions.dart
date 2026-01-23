class MintAccountNotFoundException implements Exception {
  final String mint;

  const MintAccountNotFoundException(this.mint);
}
