## Dictionary serializer for Godot 4.4 or later (typed dictionary support)
extends JSONSerializer

const INDEX_PREFIX: String = ":"

func _index_key(index: int, key: String) -> String:
	return str(index) + INDEX_PREFIX + key


func _unindex_key(key: String) -> String:
	return key.split(":", true, 1)[1]


func _get_id() -> Variant:
	return TYPE_DICTIONARY


func _serialize(instance: Variant, impl: JSONSerializationImpl) -> Variant:
	assert(instance is Dictionary, "instance not of type Dictionary")
	
	var serialized: Dictionary = {}
	
	var index: int = 0
	for key: Variant in instance:
		# NOTE: JSON keys need to be strings, so we use stringify here instead
		var serialized_key: String = impl.stringify(key)
		assert(!serialized_key.is_empty(), "serialized key (%s) empty for key (%s) of dictionary (%s)" \
		% [serialized_key, key, instance])
		var serialized_value: Variant = impl.serialize(instance[key])
		
		var indexed_key: String = _index_key(index, serialized_key)
		serialized[indexed_key] = serialized_value
		index += 1
	
	var result: Dictionary = {
		"k": {},
		"v": {},
		"d": serialized,
	}
	
	# Set key type
	if instance.is_typed_key():
		result.k = GodotJSONUtil.create_type_dict(impl, instance.get_typed_key_builtin(), 
		instance.get_typed_key_class_name(), instance.get_typed_key_script())
	
	# Set value type
	if instance.is_typed_value():
		result.v = GodotJSONUtil.create_type_dict(impl, instance.get_typed_value_builtin(), 
		instance.get_typed_value_class_name(), instance.get_typed_value_script())
	
	return result



func _deserialize(serialized: Variant, impl: JSONSerializationImpl) -> Variant:
	assert(serialized is Dictionary, "serialized (%s) not of type Dictionary" % serialized)
	assert(serialized.has("d"), "serialized (%s) missing key 'd'" % serialized)
	assert(serialized.has("k"), "serialized (%s) missing key 'k'" % serialized)
	assert(serialized.has("v"), "serialized (%s) missing key 'v'" % serialized)
	
	var dict: Dictionary
	
	# Untyped dictionary
	if serialized.k.is_empty() && serialized.v.is_empty():
		dict = {}
	else: # Typed dictionary
		var key_type: Variant.Type
		var key_class: StringName
		var key_script: Script
		if serialized.k.has("t"):
			key_type = serialized.k.t
		elif serialized.k.has("c"):
			key_type = TYPE_OBJECT
			key_class = serialized.k.c
		elif serialized.k.has("i"):
			var config_id: StringName = StringName(serialized.k.i)
			var config: JSONObjectConfig = impl.object_config_registry.get_config_by_id(config_id)
			assert(config != null, ("error determining dictionary key type; no JSONObjectConfig " + \
			"found with id (%s) when deserializing dictionary (%s)") % [config_id, serialized])
			var script: Script = config.get_class_script()
			assert(script != null, ("error determining dictionary key type; no script found " + \
			"for config (%s) when deserializing dictionary (%s)") % [config, serialized])
			
			key_type = TYPE_OBJECT
			key_class = script.get_instance_base_type()
			key_script = script
		else:
			key_type = TYPE_NIL
		
		var value_type: Variant.Type
		var value_class: StringName
		var value_script: Script
		if serialized.v.has("t"):
			value_type = serialized.v.t
		elif serialized.v.has("c"):
			value_type = TYPE_OBJECT
			value_class = serialized.v.c
		elif serialized.v.has("i"):
			var config_id: StringName = StringName(serialized.v.i)
			var config: JSONObjectConfig = impl.object_config_registry.get_config_by_id(config_id)
			assert(config != null, ("error determining dictionary value type; no JSONObjectConfig " + \
			"found with id (%s) when deserializing dictionary (%s)") % [config_id, serialized])
			var script: Script = config.get_class_script()
			assert(script != null, ("error determining dictionary value type; no script found " + \
			"for config (%s) when deserializing dictionary (%s)") % [config, serialized])
			value_type = TYPE_OBJECT
			value_class = script.get_instance_base_type()
			value_script = script
		else:
			value_type = TYPE_NIL
		
		dict = Dictionary({}, key_type, key_class, key_script, value_type, value_class, value_script)
	
	_deserialize_into(serialized, dict, impl)
	
	return dict


func _deserialize_into(serialized: Variant, instance: Variant, impl: JSONSerializationImpl) -> void:
	assert(instance is Dictionary, "instance not of type Dictionary")
	assert(serialized is Dictionary, "serialized not of type Dictionary")
	assert(serialized.has("d"), "serialized (%s) missing key 'd'" % serialized)
	assert(serialized.d is Dictionary, "serialized (%s) key (%s) not of type Dictionary" \
	% [serialized, serialized.d])
	
	for stringified_key: Variant in serialized.d:
		# JSON keys must be strings so we use parse instead of deserialize
		assert(stringified_key is String, ("key (%s) not of type String " + \
		"for serialized Dictionary (%s)") % [stringified_key, serialized.d])
		var unindexed_key: String = _unindex_key(stringified_key)
		var key: Variant = impl.parse(unindexed_key)
		var value: Variant = impl.deserialize(serialized.d[stringified_key])
		
		instance[key] = value
