String? checkNotEmpty(String? value, {String errorMessage = "Invalid input!"}) {
  if (value == null || value.isEmpty) {
    return errorMessage;
  }
  return null;
}
