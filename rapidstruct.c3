module rapidstruct;
import std::core::mem;

faultdef ARENA_OUT_OF_MEMORY, UNDEFINED_SCHEMA_TAG, SCHEMA_DEFINITION_MISMATCH;
alias Byte = char;
const uint EXPANSION_INCREMENT = 4096;

//********
//RS_Arena
//********

struct RS_Arena {
    void* rootPtr;
    void* nextPtr;
    usz currentBytesAllocated;
    usz size;
}

<*
This creates the arena and allocates memory of the specified size.
This returns the base memory address for the allocated memory, which may be null if there was a problem.
*>
fn void* initArena(RS_Arena* arena, usz size)
{
    arena.rootPtr = malloc(size);
    arena.nextPtr = arena.rootPtr;
    arena.size = size;

    return arena.rootPtr;
}

<*
Frees the memory in use by the arena
*>
fn void destroyArena(RS_Arena* arena)
{
    free(arena.rootPtr);
}

//This is just to mantain 8 byte allignment to keep things simple
const usz ARENA_ALIGNMENT = 8;
fn usz _calcAlignmentCorrection(usz allocSize) @private
{
	usz carry = ((usz) allocSize) % ARENA_ALIGNMENT;
	if(carry == 0) {
		return 0;
	}

	usz extraBump = ARENA_ALIGNMENT - carry;
	return extraBump;
}

<*
Allocates the requested memory on the arena specified and returns the pointer.
Returns null if there is not enough space on the arena to accomodate the requested size.
*>
fn void* allocOnArena(RS_Arena* arena, usz size)
{
    if(arena.currentBytesAllocated + size > arena.size) {
        return null;
    }

    void* block = arena.nextPtr;
	usz alignmentCorrection = _calcAlignmentCorrection(size);
    arena.nextPtr = (void*) (((Byte*) block) + size) + alignmentCorrection;
    arena.currentBytesAllocated += size;

    return block;
}

<*
Fully resets the arena.
If you are using this in the context of RapidStruct and it is being used by an RS_Processor, you should instead call resetProcessorToMemBaseline()
*>
fn void resetArena(RS_Arena* arena)
{
    arena.currentBytesAllocated = 0;
    arena.nextPtr = arena.rootPtr;
}

//*********
//RS_Schema
//*********

enum RS_FieldType : int
{
    BOOL,
    BYTE,
    SHORT,
    INT,
    LONG,
    FLOAT,
    DOUBLE,
    STRING,
    RAW,
    STRUCT
}

struct RS_Schema {
    RS_FieldType[256] fieldTypes;
    String[256] fieldTags;
    RS_Schema*[256] nestedSchemas;
    int tagCount;
}

<*
Adds a field definition to this schema.
Do not added a nested struct definition here, instead use RS_Schema.addStructToSchema()
@require type != RS_FieldType.STRUCT : "Must use RS_Schema.addStructToSchema() for nested structs"
*>
fn void RS_Schema.addFieldToSchema(&this, String tag, RS_FieldType type)
{
    if(type == RS_FieldType.STRUCT) {
        //TODO: is there a better way to handle this?
		//If you get past the contract somehow then do nothing as you need a schema with a struct.
		return;
    }

    //Check for duplicate tag definition
    for(int i = 0; i < this.tagCount; i++) {
        if(this.fieldTags[i] == tag) {
            //TODO: Is this the best way to handle this?
			//If you duplicate a tag, you overwrite it
			this.fieldTypes[i] = type;
			this.fieldTags[i] = tag;
			return;
        }
    }

    this.fieldTypes[this.tagCount] = type;
    this.fieldTags[this.tagCount] = tag;
    this.tagCount++;
}

<*
Adds a nested struct field definition to this schema.
*>
fn void RS_Schema.addStructToSchema(&this, String tag, RS_Schema* nestedSchemaToAdd)
{
    //Check for duplicate tag definition
    for(int i = 0; i < this.tagCount; i++) {
        if(this.fieldTags[i] == tag) {
            //TODO: Is this the best way to handle this?
			//If you duplicate a tag, you overwrite it
			this.fieldTypes[i] = RS_FieldType.STRUCT;
   			this.fieldTags[i] = tag;
    		this.nestedSchemas[i] = nestedSchemaToAdd;
			return;
        }
    }

    this.fieldTypes[this.tagCount] = RS_FieldType.STRUCT;
    this.fieldTags[this.tagCount] = tag;
    this.nestedSchemas[this.tagCount] = nestedSchemaToAdd;
    this.tagCount++;
}

<*
Returns the key associated with a given tag.
Returns -1 if there is no definition for that tag.
*>
fn int RS_Schema.getSchemaKey(&this, String tag)
{
    for(int i = 0; i < this.tagCount; i++) {
        if(this.fieldTags[i] == tag) {
            return i;
        }
    }

    return -1;
}

//********
//RS_Field
//********

struct RS_Field {
    union {
        bool boolVal;
        Byte byteVal;
        ushort shortVal;
        uint intVal;
        ulong longVal;
        float floatVal;
        double doubleVal;
    }

    RS_FieldType type;

    //This is only used if this field is actually a struct
    RS_Struct* rs_struct;

    //These are only used for strings, raw bytes, and serialized rs_structs
    Byte* buffer;
    uint bufferLength;
}

<*
Accesses this RS_Field as a BOOL and sets its value.
This RS_Field must be of type BOOL to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.BOOL : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putBool(&this, bool val)
{
    this.boolVal = val;
}

<*
Accesses this RS_Field as a BYTE and sets its value.
This RS_Field must be of type BYTE to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.BYTE : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putByte(&this, Byte val)
{
    this.byteVal = val;
}

<*
Accesses this RS_Field as a SHORT and sets its value.
This RS_Field must be of type SHORT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.SHORT : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putShort(&this, ushort val)
{
    this.shortVal = val;
}

<*
Accesses this RS_Field as an INT and sets its value.
This RS_Field must be of type INT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.INT : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putInt(&this, uint val)
{
    this.intVal = val;
}

<*
Accesses this RS_Field as a LONG and sets its value.
This RS_Field must be of type LONG to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.LONG : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putLong(&this, ulong val)
{
    this.longVal = val;
}

<*
Accesses this RS_Field as a FLOAT and sets its value.
This RS_Field must be of type FLOAT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.FLOAT : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putFloat(&this, float val)
{
    this.floatVal = val;
}

<*
Accesses this RS_Field as a DOUBLE and sets its value.
This RS_Field must be of type DOUBLE to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.DOUBLE : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putDouble(&this, double val)
{
    this.doubleVal = val;
}

<*
Accesses this RS_Field as a STRING and sets its value.
This RS_Field must be of type STRING to use this method.
This may fail if the arena runs out of memory.
@require this.type == RS_FieldType.STRING : "RS_Field must be accessed as its own type"
*>
fn void? RS_Field.putString(&this, String s, RS_Processor* proc)
{
	Byte* buffer = (Byte*) allocOnArena(proc.arena, s.len);
	if(!buffer) {
		return ARENA_OUT_OF_MEMORY~;
	}

	mem::copy(buffer, &s[0], s.len);
	this.buffer = buffer;
	this.bufferLength = (uint) s.len;
}

<*
Accesses this RS_Field as a raw byte array and sets its value.
Unlike all of the other accessor methods, this one does not care about what it's actual type is.
You can use this however you wish, but this will be useless if it is a primitive type.
This may fail if the arena runs out of memory.
*>
fn void? RS_Field.putBytes(&this, Byte* bytes, int length, RS_Processor* proc)
{
    Byte* buffer = (Byte*) allocOnArena(proc.arena, length);
	if(!buffer) {
		return ARENA_OUT_OF_MEMORY~;
	}

    mem::copy(buffer, bytes, length);
    this.buffer = buffer;
    this.bufferLength = length;
}

<*
Accesses this RS_Field as a STRUCT and sets its value.
This RS_Field must be of type STRUCT to use this method.
@require this.type == RS_FieldType.STRUCT : "RS_Field must be accessed as its own type"
*>
fn void RS_Field.putStruct(&this, RS_Struct* rs_struct)
{
    this.rs_struct = rs_struct;
}

<*
Accesses this RS_Field as a BOOL and gets its value.
This RS_Field must be of type BOOL to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.BOOL : "RS_Field must be accessed as its own type"
*>
fn bool RS_Field.asBool(&this)
{
    return this.boolVal;
}

<*
Accesses this RS_Field as a BYTE and gets its value.
This RS_Field must be of type BYTE to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.BYTE : "RS_Field must be accessed as its own type"
*>
fn Byte RS_Field.asByte(&this)
{
    return this.byteVal;
}

<*
Accesses this RS_Field as a SHORT and gets its value.
This RS_Field must be of type SHORT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...).
@require this.type == RS_FieldType.SHORT : "RS_Field must be accessed as its own type"
*>
fn ushort RS_Field.asShort(&this)
{
    return this.shortVal;
}

<*
Accesses this RS_Field as a INT and gets its value.
This RS_Field must be of type INT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...)
@require this.type == RS_FieldType.INT : "RS_Field must be accessed as its own type"
*>
fn uint RS_Field.asInt(&this)
{
    return this.intVal;
}

<*
Accesses this RS_Field as a LONG and gets its value.
This RS_Field must be of type LONG to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...)
@require this.type == RS_FieldType.LONG : "RS_Field must be accessed as its own type"
*>
fn ulong RS_Field.asLong(&this)
{
    return this.longVal;
}

<*
Accesses this RS_Field as a FLOAT and gets its value.
This RS_Field must be of type FLOAT to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...)
@require this.type == RS_FieldType.FLOAT : "RS_Field must be accessed as its own type"
*>
fn float RS_Field.asFloat(&this)
{
    return this.floatVal;
}

<*
Accesses this RS_Field as a DOUBLE and gets its value.
This RS_Field must be of type DOUBLE to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...)
@require this.type == RS_FieldType.DOUBLE : "RS_Field must be accessed as its own type"
*>
fn double RS_Field.asDouble(&this)
{
    return this.doubleVal;
}

<*
Accesses this RS_Field as a STRING and gets its value.
This RS_Field must be of type STRING to use this method.
If you really want to access a RS_Struct as the wrong type, do so within the RS_Fields's union itself (I.e., .intVal, .floatVal, etc...)
@require this.type == RS_FieldType.STRING : "RS_Field must be accessed as its own type"
*>
fn String RS_Field.asString(&this)
{
	String s = (String) this.buffer[0 : this.bufferLength];
	return s;
}

<*
Accesses this RS_Field as a raw byte array and gets its value.
Unlike all of the other accessor methods, this one does not care about what it's actual type is.
You can use this however you wish, but this will be useless if it is a primitive type.
*>
fn Byte* RS_Field.asBytes(&this)
{
    return this.buffer;
}

<*
Accesses this RS_Field as a STRUCT and gets its value.
This RS_Field must be of type STRUCT to use this method.
@require this.type == RS_FieldType.STRUCT : "RS_Field must be accessed as its own type"
*>
fn RS_Struct* RS_Field.asStruct(&this)
{
    return this.rs_struct;
}

//*********
//RS_Struct
//*********

struct RS_Struct {
    RS_Schema *schema;
    Byte *schemaKeys;
    RS_Field** fields;
    uint fieldCount;
    uint fieldCapacity;
}

<*
Initializes this RS_Struct with the given schema and sets it to use an initial field capacity of 64.
One of the init functions must be called before use and before setStructMemory().
*>
fn void initStruct(RS_Struct* rs_struct, RS_Schema* schema)
{
    rs_struct.schema = schema;

    rs_struct.fieldCount = 0;
    //Initial default capacity of 64
    rs_struct.fieldCapacity = 64;
}

<*
Initializes this RS_Struct with the given schema and sets the initial field capacity.
One of the init functions must be called before use and before setStructMemory().
*>
fn void initStructWCapacity(RS_Struct* rs_struct, RS_Schema* schema, int initialFieldCapacity)
{
    rs_struct.schema = schema;

    rs_struct.fieldCount = 0;
    rs_struct.fieldCapacity = initialFieldCapacity;
}

<*
Resets this RS_Struct's fieldCount to 0.
Retains the fieldCapacity as it previously was, but allocates fresh memory to hold those fields.
This must be called before use, and after calling one of the init methods.
This should also be called if RS_Processor.resetToBaseline() was called.
This may fail if the arena runs out of memory.
*>
fn void? setStructMemory(RS_Struct* rs_struct, RS_Processor* proc)
{
	rs_struct.fieldCount = 0;

	Byte* schemaKeyArray = (Byte*) allocOnArena(proc.arena, rs_struct.fieldCapacity);
    RS_Field** fieldArray = (RS_Field**) allocOnArena(proc.arena, RS_Field*.sizeof * rs_struct.fieldCapacity);

	if(!schemaKeyArray || !fieldArray) {
		return ARENA_OUT_OF_MEMORY~;
	}

    rs_struct.schemaKeys = schemaKeyArray;
    rs_struct.fields = fieldArray;
}

<*
Internal function for an RS_Struct's field array.
This may fail if the arena runs out of memory.
*>
fn void? _struct_expandFieldArray(RS_Struct* rs_struct, RS_Processor* proc) @private
{
	//Just a simple doubling
	uint newfieldCapacity = rs_struct.fieldCapacity * 2;
	Byte* newSchemaKeyArray = (Byte*) allocOnArena(proc.arena, newfieldCapacity);
	RS_Field** newFieldArray = (RS_Field**) allocOnArena(proc.arena, RS_Field*.sizeof * newfieldCapacity);

	if(!newSchemaKeyArray || !newFieldArray) {
		return ARENA_OUT_OF_MEMORY~;
	}

	mem::copy(newSchemaKeyArray, rs_struct.schemaKeys, rs_struct.fieldCount);
	mem::copy(newFieldArray, rs_struct.fields, RS_Field*.sizeof * rs_struct.fieldCount);

	rs_struct.schemaKeys = newSchemaKeyArray;
	rs_struct.fields = newFieldArray;
	rs_struct.fieldCapacity = newfieldCapacity;
}

<*
Internal function for taking a field and storing it on an RS_Struct's field array.
This may fail if the field array has to be expanded and the arena runs out of memory.
*>
fn void? _struct_storeField(RS_Struct* rs_struct, RS_Field* field, Byte schemaKey, RS_Processor* proc) @private
{
    if(rs_struct.fieldCount == rs_struct.fieldCapacity) {
        //Expand things here
		_struct_expandFieldArray(rs_struct, proc)!;
    }

    rs_struct.fields[rs_struct.fieldCount] = field;

    rs_struct.schemaKeys[rs_struct.fieldCount] = schemaKey;
    rs_struct.fieldCount++;
}

<*
Takes an RS_Field pointer and stores it on this RS_Struct's field array.
Again, only stores the pointer.
This may fail if the field array has to be expanded and the arena runs out of memory or a tag was passed that is undefined or of the wrong type.
*>
fn void? RS_Struct.add(&this, String tag, RS_Field* field, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(field.type != this.schema.fieldTypes[schemaKey]) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Returns the first RS_Field* that matches the given tag.
Returns null if this RS_Struct does not contain any field with that tag.
*>
fn RS_Field* RS_Struct.get(&this, String tag)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    for(int i = 0; i < this.fieldCount; i++) {
        if(this.schemaKeys[i] == schemaKey) {
            return this.fields[i];
        }
    }

    return null;
}

<*
Returns an RS_Field* array containing all RS_Fields that have then passed tag.
Will return an empty array if there are no fields with a matching tag.
This allocates the resulting array on the arena associated with the passed RS_Processor, and may fail if the arena runs out of memory.
*>
fn RS_Field*[]? RS_Struct.getAllWithTag(&this, String tag, RS_Processor* proc)
{
	int count = 0;
	int schemaKey = this.schema.getSchemaKey(tag);
    for(int i = 0; i < this.fieldCount; i++) {
        if(this.schemaKeys[i] == schemaKey) {
            count++;
        }
    }

	RS_Field** fieldArrayPtr = allocOnArena(proc.arena, (RS_Struct*.sizeof) * count);
	if(!fieldArrayPtr) {
		return ARENA_OUT_OF_MEMORY~;
	}
	RS_Field*[] fieldArray = fieldArrayPtr[0 : count];

	int putCount = 0;
	for(int i = 0; i < this.fieldCount; i++) {
		if(this.schemaKeys[i] == schemaKey) {
			fieldArray[putCount] = this.fields[i];
			putCount++;
		}
	}

	return fieldArray;
}

<*
Returns true if there is at least one field in this RS_Struct that has a matching tag.
Returns false if there are none.
*>
fn bool RS_Struct.hasField(&this, String tag)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    for(int i = 0; i < this.fieldCount; i++) {
        if(this.schemaKeys[i] == schemaKey) {
            return true;
        }
    }

    return false;
}

<*
Creates and adds a BOOL field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addBool(&this, String tag, bool val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.BOOL) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putBool(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a BYTE field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addByte(&this, String tag, Byte val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.BYTE) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putByte(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a SHORT field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addShort(&this, String tag, ushort val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.SHORT) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putShort(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds an INT field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addInt(&this, String tag, uint val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.INT) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putInt(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a LONG field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addLong(&this, String tag, ulong val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
   	if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.LONG) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putLong(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a FLOAT field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addFloat(&this, String tag, float val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.FLOAT) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putFloat(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a DOUBLE field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addDouble(&this, String tag, double val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
	if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.DOUBLE) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putDouble(val);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a STRING field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addString(&this, String tag, String val, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.STRING) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putString(val, proc)!;

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a RAW field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addBytes(&this, String tag, Byte* byteArray, int arrayLength, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.RAW) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putBytes(byteArray, arrayLength, proc)!;

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

<*
Creates and adds a nested STRUCT field with the given tag and value.
This may fail if there is not enough memory in the arena to support allocating a field or any other allocations relating to adding a field.
This also may fail if the tag is undefined or the tag belongs to a different type.
*>
fn void? RS_Struct.addStruct(&this, String tag, RS_Struct* nestedStruct, RS_Processor* proc)
{
    int schemaKey = this.schema.getSchemaKey(tag);
    if(schemaKey == -1) {
		return UNDEFINED_SCHEMA_TAG~;
    }

	if(this.schema.fieldTypes[schemaKey] != RS_FieldType.STRUCT) {
		return SCHEMA_DEFINITION_MISMATCH~;
	}

    RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
	if(!field) {
		return ARENA_OUT_OF_MEMORY~;
	}

    field.type = this.schema.fieldTypes[schemaKey];
    field.putStruct(nestedStruct);

    _struct_storeField(this, field, (Byte) schemaKey, proc)!;
}

//************
//RS_Byte(...)
//************

fn ulong _calcNewBufferSize(ulong currentCapacity, ulong currentUsage, ulong nextSize) @private
{
	ulong remainingCapacity = currentCapacity - currentUsage;
    ulong overflow = nextSize - remainingCapacity;

    ulong expansionFactor = overflow / EXPANSION_INCREMENT;
    if(expansionFactor < 1) {
        expansionFactor = 1;
    } else {
        ulong carry = overflow % EXPANSION_INCREMENT;
        if(carry > 1) {
            expansionFactor++;
        }
    }

    ulong newBufferCapacity = currentCapacity + (expansionFactor * EXPANSION_INCREMENT);
	return newBufferCapacity;
}

//*************
//RS_ByteWriter
//*************

//The byte reader and writer are mostly just private
//implementation details and generally can be ignored
//by the library user unless modifying things

struct RS_ByteWriter {
    Byte* buffer;
    uint bufferCapacity;
    uint currentPos;

    uint[1024] marks;
    int currentMark;

    RS_Arena* arena;
}

fn void _initByteWriter(RS_ByteWriter* writer, RS_Arena* arena) @private
{
	writer.bufferCapacity = EXPANSION_INCREMENT;
	writer.arena = arena;
}

/*
Retains the bufferCapacity, but allocates fresh memory to back that buffer.
This should be called after RS_Processor.reset();
*/
fn void? _setByteWriterMemory(RS_ByteWriter* writer, RS_Arena* arena)
{
	writer.currentPos = 0;
    writer.currentMark = -1;
	writer.buffer = (Byte*) allocOnArena(arena, writer.bufferCapacity);
	if(!writer.buffer) {
		return ARENA_OUT_OF_MEMORY~;
	}
}

fn int RS_ByteWriter.numBytesRemaining(&this)
{
    return this.bufferCapacity - this.currentPos;
}

fn void RS_ByteWriter.pushMark(&this)
{
    this.currentMark++;
    this.marks[this.currentMark] = this.currentPos;
}

fn void RS_ByteWriter.popMark(&this)
{
    this.currentMark--;
}

fn void RS_ByteWriter.goToLastMark(&this)
{
    this.currentPos = this.marks[this.currentMark];
}

fn void? RS_ByteWriter.expandbuffer(&this, int nextWriteSize)
{
	ulong newBufferCapacity = _calcNewBufferSize(this.bufferCapacity, this.currentPos, nextWriteSize);
    Byte* newBuffer = (Byte*) allocOnArena(this.arena, newBufferCapacity);
	if(!newBuffer) {
		return ARENA_OUT_OF_MEMORY~;
	}

    mem::copy(newBuffer, this.buffer, this.bufferCapacity);
    this.buffer = newBuffer;
    this.bufferCapacity = (uint) newBufferCapacity;
}

fn void? RS_ByteWriter.write(&this, Byte b)
{
    if(this.currentPos + 1 >= this.bufferCapacity) {
        this.expandbuffer(1)!;
    }

	this.buffer[this.currentPos] = b;
	this.currentPos++;
}

fn void? RS_ByteWriter.writeBytes(&this, Byte* array, int arrayLength)
{
    if(this.currentPos + arrayLength >= this.bufferCapacity) {
        this.expandbuffer(arrayLength)!;
    }

    mem::copy(&this.buffer[this.currentPos], array, arrayLength);
    this.currentPos += arrayLength;
}

fn Byte*? RS_ByteWriter.getTrimmedbufferCopy(&this, int* copyLength)
{
    int length = this.currentPos - this.marks[this.currentMark];
    Byte* copy = (Byte*) allocOnArena(this.arena, length);
	if(!copy) {
		return ARENA_OUT_OF_MEMORY~;
	}

    mem::copy(copy, &this.buffer[this.marks[this.currentMark]], length);
    *copyLength = length;

    return copy;
}

//*************
//RS_ByteReader
//*************

//The byte reader and writer are mostly just private
//implementation details and generally can be ignored
//by the library user unless modifying things

struct RS_ByteReader {
    Byte* buffer;
    uint bufferCapacity;
    uint currentPos;

    uint[1024] marks;
    int currentMarkIndex;

    uint[1024] lengths;
    int currentLengthIndex;

    RS_Arena* arena;
}

fn void _initByteReader(RS_ByteReader* reader, RS_Arena* arena) @private
{
	reader.bufferCapacity = EXPANSION_INCREMENT;
	reader.arena = arena;
}

fn void? _setByteReaderMemory(RS_ByteReader* reader, RS_Arena* arena)
{
	reader.buffer = (Byte*) allocOnArena(arena, reader.bufferCapacity);
	if(!reader.buffer) {
		return ARENA_OUT_OF_MEMORY~;
	}

	reader.currentPos = 0;
    reader.currentMarkIndex = -1;
    reader.lengths[0] = 0;
    reader.currentLengthIndex = 0;
}

fn int RS_ByteReader.numBytesRemaining(&this)
{
    return this.lengths[this.currentLengthIndex] - this.currentPos;
}

fn void? RS_ByteReader.expandbuffer(&this, int nextWriteSize)
{
	ulong newBufferCapacity = _calcNewBufferSize(this.bufferCapacity, this.currentPos, nextWriteSize);	
	Byte* newBuffer = (Byte*) allocOnArena(this.arena, newBufferCapacity);
	if(!newBuffer) {
		return ARENA_OUT_OF_MEMORY~;
	}

    mem::copy(newBuffer, this.buffer, this.bufferCapacity);
    this.buffer = newBuffer;
    this.bufferCapacity = (uint) newBufferCapacity;
}

fn void? RS_ByteReader.pushBytes(&this, Byte* array, int arrayLength)
{
    if(this.currentPos + arrayLength >= this.bufferCapacity) {
        this.expandbuffer(arrayLength)!;
    }

    this.currentMarkIndex++;
    this.marks[this.currentMarkIndex] = this.currentPos;

    int oldLength = this.lengths[this.currentLengthIndex];
    mem::copy(&this.buffer[oldLength], array, arrayLength);
    this.currentPos = oldLength;

    this.currentLengthIndex++;
    this.lengths[this.currentLengthIndex] = oldLength + arrayLength;
}

fn void RS_ByteReader.popBytes(&this)
{
    this.currentPos = this.marks[this.currentMarkIndex];
    this.currentMarkIndex--;
    this.currentLengthIndex--;
}

fn Byte RS_ByteReader.read(&this)
{
    Byte b = this.buffer[this.currentPos];
    this.currentPos++;
    return b;
}

/*
Fills the passed array with the next set of bytes.
Attempts to fill the entire array, but may not have enough bytes left.
This returns the number of bytes that were actually read into the array.
*/
fn int RS_ByteReader.readBytes(&this, Byte* array, int arrayLength)
{
    int bytesLeft = this.numBytesRemaining();
    int bytesRead = arrayLength < bytesLeft ? arrayLength : bytesLeft;
    mem::copy(array, &this.buffer[this.currentPos], bytesRead);
    this.currentPos += bytesRead;
    return bytesRead;
}

//************
//RS_Processor
//************

struct RS_Processor {
    RS_ByteWriter* writer;
    RS_ByteReader* reader;

    RS_Arena* arena;

    //Used for arena resets in order to not overwrite things we need.  I.e., the RS_ByteReader/Writer itself, etc...
    void* basePtr;
    ulong baseBytesAlloc;
}

<*
Initializes this RS_Processor with the given arena.
Before RS_Processor use, you SHOULD call markProcessorMemBaseline() and you MUST also call setProcessorMemory() as that allocates buffers needed for serialization/deserialization.
*>
fn void initProcessor(RS_Processor* proc, RS_Arena* arena)
{
    proc.arena = arena;

	//We won't check for null on these allocs because If you can't get enough
	//memory on the arena for this, you have real problems you need to fix
    proc.writer = (RS_ByteWriter*) allocOnArena(arena, RS_ByteWriter.sizeof);
    proc.reader = (RS_ByteReader*) allocOnArena(arena, RS_ByteReader.sizeof);

	_initByteWriter(proc.writer, arena);
	_initByteReader(proc.reader, arena);

	//Calling this to at least minimally prevent all arena memory from being overwritten.
	markProcessorMemBaseline(proc);
}

<*
This tells the processor/arena to mark the first reusable memory address.
If you need to keep things around that you don't want freed/corrupted, allocate them first, and then call this.
When setProcessorMemory() is called, it will revert back to this baseline address and starting writing from there
*>
fn void markProcessorMemBaseline(RS_Processor* proc)
{
	proc.basePtr = proc.arena.nextPtr;
    proc.baseBytesAlloc = proc.arena.currentBytesAllocated;
}

<*
Reverts the processor/arena's memory indexer/pointer to the place where setProcessorMemBaseline() was last called.
It then allocates various buffers needed for a serialization or deserialization event.
This MUST be called before using an RS_Processor.
Also, when cyclical serializations/deserializations occur, call this at the beginning of every cycle as it reverts to the beginning of the reusable address space and reacquires the buffers it needs.
This can technically fail, but shouldn't if you've successfully called this before.
*>
fn void? setProcessorMemory(RS_Processor* proc)
{
	proc.arena.nextPtr = proc.basePtr;
    proc.arena.currentBytesAllocated = proc.baseBytesAlloc;

	_setByteWriterMemory(proc.writer, proc.arena)!;
	_setByteReaderMemory(proc.reader, proc.arena)!;
}

<*
Takes an RS_Struct and serializes it to a byte array.
the integer pointer passed in will be dereferenced and modified to reflect how long the byte array is.
This serializes the data into network byte order/big endian, as is the RapidStruct standard.
This may fail if the arena runs out of memory while performing this serialization event.
*>
fn Byte*? writeStructToBytes(RS_Processor* proc, RS_Struct* rs_struct, int* bytesWritten)
{
    proc.writer.pushMark();

    for(int i = 0; i < rs_struct.fieldCount; i++) {
        //write the index/tag first
        Byte schemaKey = rs_struct.schemaKeys[i];
        RS_Field* field = rs_struct.fields[i];
        proc.writer.write(schemaKey)!;

        //Determine if it's a variable length field or not
        //Because if that's the case, we need to specify the length
        if(field.type == RS_FieldType.STRING || field.type == RS_FieldType.RAW || field.type == RS_FieldType.STRUCT) {
            if(field.type == RS_FieldType.STRUCT) {
                //We have to actually serialize to bytes first to get the length for a struct.
                int nestedStructBytesWritten;
                Byte* structBytes = writeStructToBytes(proc, field.rs_struct, &nestedStructBytesWritten)!;
                field.putBytes(structBytes, nestedStructBytesWritten, proc)!;
            }

            int dataLength = field.bufferLength;
            if(dataLength > 65535) {
                //TODO: Do something here that reflects we cannot serialize that many bytes because we are limited to a two-byte length value.
            }
            proc.writer.write((Byte) ((dataLength & 0xFFFF) >> 8))!;
            proc.writer.write((Byte) (dataLength & 0xFF))!;
        }

        //Write the actual data
		//All this crazy bitshifting stuff is to enforce network byte order/big endian
        switch(field.type) {
            case BOOL:
                proc.writer.write((Byte) field.boolVal)!;
            case BYTE:
                proc.writer.write((Byte) field.byteVal)!;
            case SHORT:
                //proc.writer.writeBytes((Byte*) &field.shortVal, 2)!;
				proc.writer.write((Byte) (field.shortVal >> 8))!;
				proc.writer.write((Byte) (field.shortVal & 0xFF))!;
            case INT:
                //proc.writer.writeBytes((Byte*) &field.intVal, 4)!;
				proc.writer.write((Byte) (field.intVal >> 24) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal >> 16) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal >> 8) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal & 0xFF))!;
            case LONG:
                //proc.writer.writeBytes((Byte*) &field.longVal, 8)!;
				proc.writer.write((Byte) (field.longVal >> 56) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 48) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 40) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 32) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 24) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 16) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 8) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal & 0xFF))!;
            case FLOAT:
                //proc.writer.writeBytes((Byte*) &field.floatVal, 4)!;
				//Use the int type from the union to perfrom bitshifting
				proc.writer.write((Byte) (field.intVal >> 24) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal >> 16) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal >> 8) & 0xFF)!;
				proc.writer.write((Byte) (field.intVal & 0xFF))!;
            case DOUBLE:
                //proc.writer.writeBytes((Byte*) &field.doubleVal, 8)!;
				//Use the long type from the union to perfrom bitshifting
				proc.writer.write((Byte) (field.longVal >> 56) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 48) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 40) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 32) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 24) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 16) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal >> 8) & 0xFF)!;
				proc.writer.write((Byte) (field.longVal & 0xFF))!;

            case STRING:
            case RAW:
            case STRUCT:
                proc.writer.writeBytes(field.buffer, field.bufferLength)!;
        }
    }

    int structBytesWritten;
    Byte* bytes = proc.writer.getTrimmedbufferCopy(&structBytesWritten)!;
    proc.writer.goToLastMark();
    proc.writer.popMark();

    *bytesWritten = structBytesWritten;
    return bytes;
}

<*
This takes a byte array and deserializes it into the passed RS_Struct.
This deserializes the data from network byte order/big endian, as is the RapidStruct standard.
This may fail for a variety of reasons, and running out of memory in the arena is the primary concern.
*>
fn void? readBytesToStruct(RS_Processor* proc, Byte* rawData, int rawDataLength, RS_Struct* rs_struct)
{
    setStructMemory(rs_struct, proc)!;
    proc.reader.pushBytes(rawData, rawDataLength)!;

    while(proc.reader.numBytesRemaining() > 0) {
        //Get schema key/index
        int schemaKey = proc.reader.read();
        RS_Field* field = (RS_Field*) allocOnArena(proc.arena, RS_Field.sizeof);
		if(!field) {
			return ARENA_OUT_OF_MEMORY~;
		}

        field.type = rs_struct.schema.fieldTypes[schemaKey];
        RS_Schema* nestedSchema = null;

        int length = 0;

        switch(field.type) {
            case BOOL:
            case BYTE:
                length = 1;

            case SHORT:
                length = 2;

            case INT:
            case FLOAT:
                length = 4;

            case LONG:
            case DOUBLE:
                length = 8;

            case STRING:
            case RAW:
            {
                length = proc.reader.read() << 8;
                length += proc.reader.read();
            }

            case STRUCT:
            {
                length = proc.reader.read() << 8;
                length += proc.reader.read();

                //Retrieve nested schema
                nestedSchema = rs_struct.schema.nestedSchemas[schemaKey];
            }
        }

        Byte* rawValue = (Byte*) allocOnArena(proc.arena, length);
		if(!rawValue) {
			return ARENA_OUT_OF_MEMORY~;
		}
        int bytesRead = proc.reader.readBytes(rawValue, length);
        if(bytesRead < length) {
            //TODO: do something here because we underflowed
        }

		//All this crazy bitshifting stuff is to enforce network byte order/big endian
        switch(field.type) {
            case BOOL:
                field.boolVal = *(bool*) rawValue;
            case BYTE:
                field.byteVal = *(Byte*) rawValue;
            case SHORT:
			{
                //field.shortVal = *(short*) rawValue;
				field.shortVal = rawValue[0] << 8;
				field.shortVal += rawValue[1];
			}
			case INT:
			{
                //field.intVal = *(int*) rawValue;
				field.intVal = rawValue[0] << 24;
				field.intVal += rawValue[1] << 16;
				field.intVal += rawValue[2] << 8;
				field.intVal += rawValue[3];
			}
			case LONG:
			{
                //field.longVal = *(long*) rawValue;
				field.longVal = ((ulong) rawValue[0]) << 56;
				field.longVal += ((ulong) rawValue[1]) << 48;
				field.longVal += ((ulong) rawValue[2]) << 40;
				field.longVal += ((ulong) rawValue[3]) << 32;
				field.longVal += ((ulong) rawValue[4]) << 24;
				field.longVal += ((ulong) rawValue[5]) << 16;
				field.longVal += ((ulong) rawValue[6]) << 8;
				field.longVal += ((ulong) rawValue[7]);
			}
			case FLOAT:
			{
                //field.floatVal = *(float*) rawValue;
				//Using intVal from the union to perform bitshifting
				field.intVal = rawValue[0] << 24;
				field.intVal += rawValue[1] << 16;
				field.intVal += rawValue[2] << 8;
				field.intVal += rawValue[3];
			}
            case DOUBLE:
			{
                //field.doubleVal = *(double*) rawValue;
				//Using longVal from the union to perform bitshifting
				field.longVal = ((ulong) rawValue[0]) << 56;
				field.longVal += ((ulong) rawValue[1]) << 48;
				field.longVal += ((ulong) rawValue[2]) << 40;
				field.longVal += ((ulong) rawValue[3]) << 32;
				field.longVal += ((ulong) rawValue[4]) << 24;
				field.longVal += ((ulong) rawValue[5]) << 16;
				field.longVal += ((ulong) rawValue[6]) << 8;
				field.longVal += ((ulong) rawValue[7]);
			}
            case STRING:
            case RAW:
                field.putBytes(rawValue, length, proc)!;

            case STRUCT:
            {
                RS_Struct* nestedStruct = (RS_Struct*) allocOnArena(proc.arena, RS_Struct.sizeof);
				if(!nestedStruct) {
					return ARENA_OUT_OF_MEMORY~;
				}
                initStruct(nestedStruct, nestedSchema);
				setStructMemory(nestedStruct, proc)!;
                readBytesToStruct(proc, rawValue, length, nestedStruct)!;
                field.putStruct(nestedStruct);
            }
        }

        rs_struct.add(rs_struct.schema.fieldTags[schemaKey], field, proc)!;
    }

    proc.reader.popBytes();
}