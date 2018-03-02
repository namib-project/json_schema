// Copyright 2013-2018 Workiva Inc.
//
// Licensed under the Boost Software License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.boost.org/LICENSE_1_0.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This software or document includes material copied from or derived
// from JSON-Schema-Test-Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite),
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms:
//
//     Copyright (c) 2012 Julian Berman
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//     THE SOFTWARE.

import 'dart:async';

import 'package:path/path.dart' as path_lib;

import 'package:json_schema/src/json_schema/schema_type.dart';
import 'package:json_schema/src/json_schema/validator.dart';
import 'package:json_schema/src/json_schema/global_platform_functions.dart';
import 'package:json_schema/src/json_schema/utils.dart';

/// Constructed with a json schema, either as string or Map. Validation of
/// the schema itself is done on construction. Any errors in the schema
/// result in a FormatException being thrown.
class JsonSchema {
  JsonSchema._fromMap(this._root, this._schemaMap, this._path) {
    _initialize();
    _addSchema(path, this);
  }

  JsonSchema._fromRootMap(this._schemaMap) {
    _initialize();
  }

  // --------------------------------------------------------------------------
  // Root Schema
  // --------------------------------------------------------------------------
  JsonSchema get root => _root;
  Map get schemaMap => _schemaMap;
  String get path => _path;
  num get multipleOf => _multipleOf;
  num get maximum => _maximum;
  num get minimum => _minimum;
  int get maxLength => _maxLength;
  int get minLength => _minLength;
  RegExp get pattern => _pattern;
  List get enumValues => _enumValues;
  List<JsonSchema> get allOf => _allOf;
  List<JsonSchema> get anyOf => _anyOf;
  List<JsonSchema> get oneOf => _oneOf;
  JsonSchema get notSchema => _notSchema;
  Map<String, JsonSchema> get definitions => _definitions;
  Uri get id => _id;
  String get ref => _ref;
  String get description => _description;
  String get title => _title;
  List<SchemaType> get schemaTypeList => _schemaTypeList;


  // --------------------------------------------------------------------------
  // Schema Items
  // --------------------------------------------------------------------------

  /// To match all items to a schema
  JsonSchema get items => _items;

  /// To match each item in array to a schema
  List<JsonSchema> get itemsList => _itemsList;
  dynamic get additionalItems => _additionalItems;
  int get maxItems => _maxItems;
  int get minItems => _minItems;
  bool get uniqueItems => _uniqueItems;

  // --------------------------------------------------------------------------
  // Schema Properties
  // --------------------------------------------------------------------------
  List<String> get requiredProperties => _requiredProperties;
  int get maxProperties => _maxProperties;
  int get minProperties => _minProperties;
  Map<String, JsonSchema> get properties => _properties;
  bool get additionalProperties => _additionalProperties;
  JsonSchema get additionalPropertiesSchema => _additionalPropertiesSchema;
  Map<RegExp, JsonSchema> get patternProperties => _patternProperties;
  Map<String, JsonSchema> get schemaDependencies => _schemaDependencies;
  Map<String, List<String>> get propertyDependencies => _propertyDependencies;
  dynamic get defaultValue => _defaultValue;

  /// Map of path to schema object
  Map<String, JsonSchema> get refMap => _refMap;

  static Future<JsonSchema> createSchemaFromUrl(String schemaUrl) {
    if (globalCreateJsonSchemaFromUrl == null) {
      throw new StateError('no globalCreateJsonSchemaFromUrl defined!');
    }
    return globalCreateJsonSchemaFromUrl(schemaUrl);
  }

  /// Create a schema from a [data]
  /// Typically [data] is result of JSON.decode(jsonSchemaString)
  static Future<JsonSchema> createSchema(Map data) => new JsonSchema._fromRootMap(data)._thisCompleter.future;

  /// Validate [instance] against this schema
  bool validate(dynamic instance) => new Validator(this).validate(instance);

  bool get exclusiveMaximum => _exclusiveMaximum == null || _exclusiveMaximum;
  bool get exclusiveMinimum => _exclusiveMinimum == null || _exclusiveMinimum;

  bool propertyRequired(String property) => _requiredProperties != null && _requiredProperties.contains(property);

  /// Given path, follow all references to an end path pointing to schema
  String endPath(String path) {
    _pathsEncountered.clear();
    return _endPath(path);
  }

  /// Returns paths of all paths
  Set get paths => new Set.from(_schemaRefs.keys)..addAll(_refMap.keys);

  /// Method to find schema from path
  JsonSchema resolvePath(String path) {
    while (_schemaRefs.containsKey(path)) {
      path = _schemaRefs[path];
    }
    return _refMap[path];
  }

  FormatException _boolError(String key, dynamic instance) => _error('$key must be boolean: $instance');
  FormatException _numError(String key, dynamic instance) => _error('$key must be num: $instance');
  FormatException _intError(String key, dynamic instance) => _error('$key must be int: $instance');
  FormatException _stringError(String key, dynamic instance) => _error('$key must be string: $instance');
  FormatException _objectError(String key, dynamic instance) => _error('$key must be object: $instance');
  FormatException _arrayError(String key, dynamic instance) => _error('$key must be array: $instance');
  FormatException _schemaError(String key, dynamic instance) => _error('$key must be valid schema object: $instance');

  FormatException _error(String msg) {
    msg = '$_path: $msg';
    // if (logFormatExceptions) _logger.warning(msg); TODO: re-add logger
    return new FormatException(msg);
  }

  String _requireString(String key, dynamic value) {
    if (value is String) return value;
    throw _stringError(key, value);
  }

  dynamic _requireNonNegative(String key, dynamic value) {
    if (value < 0) throw _error('$key must be non-negative: $value');
    return value;
  }

  int _requireNonNegativeInt(String key, dynamic value) {
    if (value is int) return _requireNonNegative(key, value);
    throw _intError(key, value);
  }

  /// Add a ref'd JsonSchema to the map of available Schemas.
  _addSchema(String path, JsonSchema schema) => _refMap[path] = schema;

  
  _getMultipleOf(dynamic value) {
    if (value is! num) throw _numError('multiple', value);
    if (value <= 0) throw _error('multipleOf must be > 0: $value');
    _multipleOf = value;
  }

  _getMaximum(dynamic value) {
    if (value is! num) throw _numError('maximum', value);
    _maximum = value;
  }

  _getExclusiveMaximum(dynamic value) {
    if (value is! bool) throw _boolError('exclusiveMaximum', value);
    _exclusiveMaximum = value;
  }

  _getMinimum(dynamic value) {
    if (value is! num) throw _numError('minimum', value);
    _minimum = value;
  }

  _getExclusiveMinimum(dynamic value) {
    if (value is! bool) throw _boolError('exclusiveMinimum', value);
    _exclusiveMinimum = value;
  }

  _getMaxLength(dynamic value) => _maxLength = _requireNonNegativeInt('maxLength', value);
  _getMinLength(dynamic value) => _minLength = _requireNonNegativeInt('minLength', value);

  _getPattern(dynamic value) {
    if (value is! String) throw _stringError('pattern', value);
    _pattern = new RegExp(value);
  }

  _makeSchema(String path, dynamic schema, assigner(JsonSchema rhs)) {
    if (schema is! Map) throw _schemaError(path, schema);
    if (_registerSchemaRef(path, schema)) {
      _schemaAssignments.add(() => assigner(_resolvePath(path)));
    } else {
      assigner(_createSubSchema(schema, path));
    }
  }

  _getProperties(dynamic value) {
    if (value is Map) {
      value.forEach((property, subSchema) =>
          _makeSchema('$_path/properties/$property', subSchema, (rhs) => _properties[property] = rhs));
    } else {
      throw _objectError('properties', value);
    }
  }

  _getItems(dynamic value) {
    if (value is Map) {
      _makeSchema('$_path/items', value, (rhs) => _items = rhs);
    } else if (value is List) {
      int index = 0;
      _itemsList = new List(value.length);
      for (int i = 0; i < value.length; i++) {
        _makeSchema('$_path/items/${index++}', value[i], (rhs) => _itemsList[i] = rhs);
      }
    } else {
      throw _error('items must be object or array: $value');
    }
  }

  _getAdditionalItems(dynamic value) {
    if (value is bool) {
      _additionalItems = value;
    } else if (value is Map) {
      _makeSchema('$_path/additionalItems', value, (rhs) => _additionalItems = rhs);
    } else {
      throw _error('additionalItems must be boolean or object: $value');
    }
  }

  _getMaxItems(dynamic value) => _maxItems = _requireNonNegativeInt('maxItems', value);
  _getMinItems(dynamic value) => _minItems = _requireNonNegativeInt('minItems', value);
  _getUniqueItems(dynamic value) {
    if (value is! bool) throw _boolError('uniqueItems', value);
    _uniqueItems = value;
  }

  _getRequired(dynamic value) {
    if (value is! List) throw _arrayError('required', value);
    if (value.length == 0) throw _error('required must be a non-empty array: $value');
    _requiredProperties = new List.from(value);
  }

  _getMaxProperties(dynamic value) => _maxProperties = _requireNonNegativeInt('maxProperties', value);
  _getMinProperties(dynamic value) => _minProperties = _requireNonNegativeInt('minProperties', value);
  _getAdditionalProperties(dynamic value) {
    if (value is bool) {
      _additionalProperties = value;
    } else if (value is Map) {
      _makeSchema('$_path/additionalProperties', value, (rhs) => _additionalPropertiesSchema = rhs);
    } else {
      throw _error('additionalProperties must be a bool or valid schema object: $value');
    }
  }

  _getPatternProperties(dynamic value) {
    if (value is! Map) throw _objectError('patternProperties', value);

    value.forEach(
        (k, v) => _makeSchema('$_path/patternProperties/$k', v, (rhs) => _patternProperties[new RegExp(k)] = rhs));
  }

  _getDependencies(dynamic value) {
    if (value is Map) {
      value.forEach((k, v) {
        if (v is Map) {
          _makeSchema('$_path/dependencies/$k', v, (rhs) => _schemaDependencies[k] = rhs);
        } else if (v is List) {
          if (v.length == 0) throw _error('property dependencies must be non-empty array');

          final Set uniqueDeps = new Set();
          v.forEach((propDep) {
            if (propDep is! String) throw _stringError('propertyDependency', v);

            if (uniqueDeps.contains(propDep)) throw _error('property dependencies must be unique: $v');

            _propertyDependencies.putIfAbsent(k, () => []).add(propDep);
            uniqueDeps.add(propDep);
          });
        } else {
          throw _error('dependency values must be object or array: $v');
        }
      });
    } else {
      throw _objectError('dependencies', value);
    }
  }

  _getEnum(dynamic value) {
    if (value is List) {
      if (value.length == 0) throw _error('enum must be a non-empty array: $value');
      int i = 0;
      value.forEach((v) {
        for (int j = i + 1; j < value.length; j++) {
          if (JsonSchemaUtils.jsonEqual(value[i], value[j]))
            throw _error('enum values must be unique: $value [$i]==[$j]');
        }
        i++;
        _enumValues.add(v);
      });
    } else {
      throw _arrayError('enum', value);
    }
  }

  _getType(dynamic value) {
    if (value is String) {
      _schemaTypeList = [SchemaType.fromString(value)];
    } else if (value is List) {
      _schemaTypeList = value.map((v) => SchemaType.fromString(v)).toList();
    } else {
      throw _error('type must be string or array: ${value.runtimeType}');
    }
    if (_schemaTypeList.contains(null)) throw _error('type(s) invalid $value');
  }

  _requireListOfSchema(String key, dynamic value, schemaAdder(JsonSchema schema)) {
    if (value is List) {
      if (value.length == 0) throw _error('$key array must not be empty');
      for (int i = 0; i < value.length; i++) {
        _makeSchema('$_path/$key/$i', value[i], (rhs) => schemaAdder(rhs));
      }
    } else {
      throw _arrayError(key, value);
    }
  }

  _getAllOf(dynamic value) => _requireListOfSchema('allOf', value, (schema) => _allOf.add(schema));
  _getAnyOf(dynamic value) => _requireListOfSchema('anyOf', value, (schema) => _anyOf.add(schema));
  _getOneOf(dynamic value) => _requireListOfSchema('oneOf', value, (schema) => _oneOf.add(schema));
  _getNot(dynamic value) {
    if (value is Map) {
      _makeSchema('$_path/not', value, (rhs) => _notSchema = rhs);
    } else {
      throw _objectError('not', value);
    }
  }

  _getDefinitions(dynamic value) {
    if (value is Map) {
      value.forEach((k, v) => _makeSchema('$_path/definitions/$k', v, (rhs) => _definitions[k] = rhs));
    } else {
      throw _objectError('definition', value);
    }
  }

  _getRef(dynamic value) {
    if (value is String) {
      _ref = value;
      if (_ref.length == 0) throw _error('\$ref must be non-empty string');
      if (_ref[0] != '#') {
        final refSchemaFuture = createSchemaFromUrl(_ref).then((schema) => _addSchema(_ref, schema));
        _retrievalRequests.add(refSchemaFuture);
      }
    } else {
      throw _stringError(r'$ref', value);
    }
  }

  _getSchema(dynamic value) {
    if (value is String) {
      if (value != 'http://json-schema.org/draft-04/schema#') {
        throw _error('Only draft 4 schema supported');
      }
    } else {
      throw _stringError(r'$ref', value);
    }
  }

  _getId(dynamic value) {
    if (value is String) {
      final String id = _requireString('id', value);
      try {
        _id = Uri.parse(id);
      } catch (e) {
        throw _error('id must be a valid URI: $value ($e)');
      }
    } else {
      throw _stringError('id', value);
    }
  }

  _getTitle(dynamic value) => _title = _requireString('title', value);
  _getDescription(dynamic value) => _description = _requireString('description', value);
  _getDefault(dynamic value) => _defaultValue = value;
  _getFormat(dynamic value) {
    _format = _requireString('format', value);
  }

  String get format => _format;

  static Map _accessMap = {
    'multipleOf': (s, v) => s._getMultipleOf(v),
    'maximum': (s, v) => s._getMaximum(v),
    'exclusiveMaximum': (s, v) => s._getExclusiveMaximum(v),
    'minimum': (s, v) => s._getMinimum(v),
    'exclusiveMinimum': (s, v) => s._getExclusiveMinimum(v),
    'maxLength': (s, v) => s._getMaxLength(v),
    'minLength': (s, v) => s._getMinLength(v),
    'pattern': (s, v) => s._getPattern(v),
    'properties': (s, v) => s._getProperties(v),
    'maxProperties': (s, v) => s._getMaxProperties(v),
    'minProperties': (s, v) => s._getMinProperties(v),
    'additionalProperties': (s, v) => s._getAdditionalProperties(v),
    'dependencies': (s, v) => s._getDependencies(v),
    'patternProperties': (s, v) => s._getPatternProperties(v),
    'items': (s, v) => s._getItems(v),
    'additionalItems': (s, v) => s._getAdditionalItems(v),
    'maxItems': (s, v) => s._getMaxItems(v),
    'minItems': (s, v) => s._getMinItems(v),
    'uniqueItems': (s, v) => s._getUniqueItems(v),
    'required': (s, v) => s._getRequired(v),
    'default': (s, v) => s._getDefault(v),
    'enum': (s, v) => s._getEnum(v),
    'type': (s, v) => s._getType(v),
    'allOf': (s, v) => s._getAllOf(v),
    'anyOf': (s, v) => s._getAnyOf(v),
    'oneOf': (s, v) => s._getOneOf(v),
    'not': (s, v) => s._getNot(v),
    'definitions': (s, v) => s._getDefinitions(v),
    'id': (s, v) => s._getId(v),
    '\$ref': (s, v) => s._getRef(v),
    '\$schema': (s, v) => s._getSchema(v),
    'title': (s, v) => s._getTitle(v),
    'description': (s, v) => s._getDescription(v),
    'format': (s, v) => s._getFormat(v),
  };

  void _validateSchema() {
    // _logger.info('Validating schema $_path'); TODO: re-add logger

    if (_registerSchemaRef(_path, _schemaMap)) {
      // _logger.info('Top level schema is ref: $_schemaRefs'); TODO: re-add logger
    }

    _schemaMap.forEach((k, v) {
      final accessor = _accessMap[k];
      if (accessor != null) {
        accessor(this, v);
      } else {
        _freeFormMap[path_lib.join(_path, _normalizePath(k))] = v;
      }
    });

    if (_exclusiveMinimum != null && _minimum == null) throw _error('exclusiveMinimum requires minimum');

    if (_exclusiveMaximum != null && _maximum == null) throw _error('exclusiveMaximum requires maximum');

    if (_root == this) {
      _schemaAssignments.forEach((assignment) => assignment());
      if (_retrievalRequests.isNotEmpty) {
        Future.wait(_retrievalRequests).then((_) => _thisCompleter.complete(_resolvePath('#')));
      } else {
        _thisCompleter.complete(_resolvePath('#'));
      }
      // _logger.info('Marked $_path complete'); TODO: re-add logger
    }

    // _logger.info('Completed Validating schema $_path'); TODO: re-add logger
  }


  /// Function that contains most constructor logic for various constructors.
  void _initialize() {
    if (_root == null) {
      _root = this;
      _path = '#';
      _addSchema('#', this);
      _thisCompleter = new Completer();
    } else {
      _schemaRefs = _root._schemaRefs;
      _refMap = _root._refMap;
      _freeFormMap = _root._freeFormMap;
      _thisCompleter = _root._thisCompleter;
      _schemaAssignments = _root._schemaAssignments;
    }

    _validateSchema();
  }

  String _endPath(String path) {
    if (_pathsEncountered.contains(path)) throw _error('Encountered path cycle ${_pathsEncountered}, adding $path');

    final referredTo = _schemaRefs[path];
    if (referredTo == null) {
      return path;
    } else {
      _pathsEncountered.add(path);
      return _endPath(referredTo);
    }
  }

  JsonSchema _resolvePath(String original) {
    final String path = endPath(original);
    final JsonSchema result = _refMap[path];
    if (result == null) {
      final schema = _freeFormMap[path];
      if (schema is! Map) throw _schemaError('free-form property $original at $path', schema);
      return new JsonSchema._fromMap(_root, schema, path);
    }
    return result;
  }

  bool _registerSchemaRef(String path, dynamic schemaDefinition) {
    if (schemaDefinition is Map) {
      final dynamic ref = schemaDefinition[r'$ref'];
      if (ref != null) {
        if (ref is String) {
          // _logger.info('Linking $path to $ref'); TODO: re-add logger
          _schemaRefs[path] = ref;
          return true;
        } else {
          throw _stringError('\$ref', ref);
        }
      }
    }
    return false;
  }

  static String _normalizePath(String path) => path.replaceAll('~', '~0').replaceAll('/', '~1').replaceAll('%', '%25');

  JsonSchema _createSubSchema(dynamic schemaDefinition, String path) {
    assert(!_schemaRefs.containsKey(path));
    assert(!_refMap.containsKey(path));
    return new JsonSchema._fromMap(_root, schemaDefinition, path);
  }

  String toString() => '${_schemaMap}';

  JsonSchema _root;
  Map _schemaMap = {};
  String _path;
  num _multipleOf;
  num _maximum;
  bool _exclusiveMaximum;
  num _minimum;
  bool _exclusiveMinimum;
  int _maxLength;
  int _minLength;
  RegExp _pattern;
  List _enumValues = [];
  /// 
  List<JsonSchema> _allOf = [];
  List<JsonSchema> _anyOf = [];
  List<JsonSchema> _oneOf = [];
  JsonSchema _notSchema;
  Map<String, JsonSchema> _definitions = {};
  Uri _id;
  String _ref;
  String _description;
  String _title;
  List<SchemaType> _schemaTypeList;
  JsonSchema _items;
  List<JsonSchema> _itemsList;
  dynamic _additionalItems;
  int _maxItems;
  int _minItems;
  bool _uniqueItems = false;
  List<String> _requiredProperties;
  int _maxProperties;
  int _minProperties = 0;
  Map<String, JsonSchema> _properties = {};
  bool _additionalProperties;
  JsonSchema _additionalPropertiesSchema;
  Map<RegExp, JsonSchema> _patternProperties = {};
  Map<String, JsonSchema> _schemaDependencies = {};
  Map<String, List<String>> _propertyDependencies = {};
  dynamic _defaultValue;
  Map<String, JsonSchema> _refMap = {};

  /// For schemas with $ref maps path of schema to $ref path
  Map<String, String> _schemaRefs = {};

  /// Assignments to call for resolution upon end of parse
  List _schemaAssignments = [];

  /// Maps any non-key top level property to its original value
  Map<String, dynamic> _freeFormMap = {};

  /// Completer that fires when the JsonSchema has finished building.
  Completer _thisCompleter = new Completer();
  
  /// HTTP(S) requests to fetch ref'd schemas.
  List<Future<JsonSchema>> _retrievalRequests = [];

  /// Set of strings to gaurd against path cycles
  Set<String> _pathsEncountered = new Set();

  /// Support for optional formats (date-time, uri, email, ipv6, hostname)
  String _format;
}
