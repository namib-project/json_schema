import 'package:json_schema3/json_schema3.dart';

abstract class SchemaUrlClient {
  Future<JsonSchema> createFromUrl(
    String schemaUrl, {
    SchemaVersion? schemaVersion,
    List<CustomVocabulary>? customVocabularies,
    Map<String, ValidationContext Function(ValidationContext context, String? instanceData)> customFormats = const {},
  });

  Future<Map<String, dynamic>?> getSchemaJsonFromUrl(String schemaUrl);
}
