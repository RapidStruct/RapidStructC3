import rapidstruct;

fn void e2eTestTag() @test
{
	bool origBoolVal = false;
	Byte origByteVal = 123;
	ushort origShortVal = 1234;
	uint origIntVal = 123456;
	ulong origLongVal = 123_456_789_012;
	float origFloatVal = 123.456;
	double origDoubleVal = 12345.6789;
	String origString = "Test string";
	Byte[*] origByteArray = {1, 2, 3, 4, 5};

	RS_Schema nestedSchema;
	nestedSchema.addFieldToSchema("Bool", RS_FieldType.BOOL);
	nestedSchema.addFieldToSchema("Byte", RS_FieldType.BYTE);
	nestedSchema.addFieldToSchema("Short", RS_FieldType.SHORT);
	nestedSchema.addFieldToSchema("Int", RS_FieldType.INT);
	nestedSchema.addFieldToSchema("Long", RS_FieldType.LONG);
	nestedSchema.addFieldToSchema("Float", RS_FieldType.FLOAT);
	nestedSchema.addFieldToSchema("Double", RS_FieldType.DOUBLE);
	nestedSchema.addFieldToSchema("String", RS_FieldType.STRING);
	nestedSchema.addFieldToSchema("ByteArray", RS_FieldType.RAW);

	RS_Schema mainSchema;
	mainSchema.addFieldToSchema("Bool", RS_FieldType.BOOL);
	mainSchema.addFieldToSchema("Byte", RS_FieldType.BYTE);
	mainSchema.addFieldToSchema("Short", RS_FieldType.SHORT);
	mainSchema.addFieldToSchema("Int", RS_FieldType.INT);
	mainSchema.addFieldToSchema("Long", RS_FieldType.LONG);
	mainSchema.addFieldToSchema("Float", RS_FieldType.FLOAT);
	mainSchema.addFieldToSchema("Double", RS_FieldType.DOUBLE);
	mainSchema.addFieldToSchema("String", RS_FieldType.STRING);
	mainSchema.addFieldToSchema("ByteArray", RS_FieldType.RAW);
	mainSchema.addStructToSchema("Struct", &nestedSchema);

	RS_Arena arena;
	rapidstruct::initArena(&arena, 1024 * 1024);
	RS_Processor* proc = (RS_Processor*) rapidstruct::allocOnArena(&arena, RS_Processor.sizeof);
	rapidstruct::initProcessor(proc, &arena);

	RS_Struct* mainStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(mainStruct, &mainSchema);

	rapidstruct::markProcessorMemBaseline(proc);
	rapidstruct::setProcessorMemory(proc)!!;

	rapidstruct::setStructMemory(mainStruct, proc)!!;

	int iterations = 10;
	for(int i = 0; i < iterations; i++) {
		RS_Struct* nestedStruct = rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
		rapidstruct::initStruct(nestedStruct, &nestedSchema);
		rapidstruct::setStructMemory(nestedStruct, proc)!!;

		nestedStruct.addBool("Bool", origBoolVal, proc)!!;
		nestedStruct.addByte("Byte", origByteVal, proc)!!;
		nestedStruct.addShort("Short", origShortVal, proc)!!;
		nestedStruct.addInt("Int", origIntVal, proc)!!;
		nestedStruct.addLong("Long", origLongVal, proc)!!;
		nestedStruct.addFloat("Float", origFloatVal, proc)!!;
		nestedStruct.addDouble("Double", origDoubleVal, proc)!!;
		nestedStruct.addString("String", origString, proc)!!;
		nestedStruct.addBytes("ByteArray", &origByteArray, origByteArray.len, proc)!!;

		mainStruct.addBool("Bool", origBoolVal, proc)!!;
		mainStruct.addByte("Byte", origByteVal, proc)!!;
		mainStruct.addShort("Short", origShortVal, proc)!!;
		mainStruct.addInt("Int", origIntVal, proc)!!;
		mainStruct.addLong("Long", origLongVal, proc)!!;
		mainStruct.addFloat("Float", origFloatVal, proc)!!;
		mainStruct.addDouble("Double", origDoubleVal, proc)!!;
		mainStruct.addString("String", origString, proc)!!;
		mainStruct.addBytes("ByteArray", &origByteArray, origByteArray.len, proc)!!;
		mainStruct.addStruct("Struct", nestedStruct, proc)!!;
	}

	uint bytesWritten;
	Byte* bytes = rapidstruct::writeStructToBytes(proc, mainStruct, &bytesWritten)!!;

	RS_Struct* dupMainStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(dupMainStruct, &mainSchema);
	rapidstruct::readBytesToStruct(proc, bytes, bytesWritten, dupMainStruct)!!;

	RS_Field*[] dupNestedStructFields = dupMainStruct.getAllWithTag("Struct", proc)!!;

	RS_Field*[] dupBoolFields = dupMainStruct.getAllWithTag("Bool", proc)!!;
	RS_Field*[] dupByteFields = dupMainStruct.getAllWithTag("Byte", proc)!!;
	RS_Field*[] dupShortFields = dupMainStruct.getAllWithTag("Short", proc)!!;
	RS_Field*[] dupIntFields = dupMainStruct.getAllWithTag("Int", proc)!!;
	RS_Field*[] dupLongFields = dupMainStruct.getAllWithTag("Long", proc)!!;
	RS_Field*[] dupFloatFields = dupMainStruct.getAllWithTag("Float", proc)!!;
	RS_Field*[] dupDoubleFields = dupMainStruct.getAllWithTag("Double", proc)!!;
	RS_Field*[] dupStringFields = dupMainStruct.getAllWithTag("String", proc)!!;
	RS_Field*[] dupByteArrayFields = dupMainStruct.getAllWithTag("ByteArray", proc)!!;

	for(int i = 0; i < iterations; i++) {
		RS_Struct* dupNestedStruct = dupNestedStructFields[i].asStruct();

		bool dupBoolVal = dupNestedStruct.get("Bool").asBool();
		Byte dupByteVal = dupNestedStruct.get("Byte").asByte();
		ushort dupShortVal = dupNestedStruct.get("Short").asShort();
		uint dupIntVal = dupNestedStruct.get("Int").asInt();
		ulong dupLongVal = dupNestedStruct.get("Long").asLong();
		float dupFloatVal = dupNestedStruct.get("Float").asFloat();
		double dupDoubleVal = dupNestedStruct.get("Double").asDouble();
		String dupString = dupNestedStruct.get("String").asString();
		RS_Field* dupByteArrayField = dupNestedStruct.get("ByteArray");
		Byte[] dupByteArray = dupByteArrayField.asBytes()[0 : dupByteArrayField.bufferLength];

		assert(dupBoolVal == origBoolVal);
		assert(dupByteVal == origByteVal);
		assert(dupShortVal == origShortVal);
		assert(dupIntVal == origIntVal);
		assert(dupLongVal == origLongVal);
		assert(dupFloatVal == origFloatVal);
		assert(dupDoubleVal == origDoubleVal);
		assert(dupString == origString);
		assert(dupByteArray == origByteArray[0 : origByteArray.len]);

		dupBoolVal = dupBoolFields[i].asBool();
		dupByteVal = dupByteFields[i].asByte();
		dupShortVal = dupShortFields[i].asShort();
		dupIntVal = dupIntFields[i].asInt();
		dupLongVal = dupLongFields[i].asLong();
		dupFloatVal = dupFloatFields[i].asFloat();
		dupDoubleVal = dupDoubleFields[i].asDouble();
		dupString = dupStringFields[i].asString();
		dupByteArrayField = dupByteArrayFields[i];
		dupByteArray = dupByteArrayField.asBytes()[0 : dupByteArrayField.bufferLength];

		assert(dupBoolVal == origBoolVal);
		assert(dupByteVal == origByteVal);
		assert(dupShortVal == origShortVal);
		assert(dupIntVal == origIntVal);
		assert(dupLongVal == origLongVal);
		assert(dupFloatVal == origFloatVal);
		assert(dupDoubleVal == origDoubleVal);
		assert(dupString == origString);
		assert(dupByteArray == origByteArray[0 : origByteArray.len]);
	}

	rapidstruct::destroyArena(&arena);
}

fn void e2eTestKey() @test
{
	bool origBoolVal = false;
	Byte origByteVal = 123;
	ushort origShortVal = 1234;
	uint origIntVal = 123456;
	ulong origLongVal = 123_456_789_012;
	float origFloatVal = 123.456;
	double origDoubleVal = 12345.6789;
	String origString = "Test string";
	Byte[*] origByteArray = {1, 2, 3, 4, 5};

	RS_Schema nestedSchema;
	RS_SchemaKey nestedBoolKey = nestedSchema.addFieldToSchema("Bool", RS_FieldType.BOOL);
	RS_SchemaKey nestedByteKey = nestedSchema.addFieldToSchema("Byte", RS_FieldType.BYTE);
	RS_SchemaKey nestedShortKey = nestedSchema.addFieldToSchema("Short", RS_FieldType.SHORT);
	RS_SchemaKey nestedIntKey = nestedSchema.addFieldToSchema("Int", RS_FieldType.INT);
	RS_SchemaKey nestedLongKey = nestedSchema.addFieldToSchema("Long", RS_FieldType.LONG);
	RS_SchemaKey nestedFloatKey = nestedSchema.addFieldToSchema("Float", RS_FieldType.FLOAT);
	RS_SchemaKey nestedDoubleKey = nestedSchema.addFieldToSchema("Double", RS_FieldType.DOUBLE);
	RS_SchemaKey nestedStringKey = nestedSchema.addFieldToSchema("String", RS_FieldType.STRING);
	RS_SchemaKey nestedByteArrayKey = nestedSchema.addFieldToSchema("ByteArray", RS_FieldType.RAW);

	RS_Schema mainSchema;
	RS_SchemaKey boolKey = mainSchema.addFieldToSchema("Bool", RS_FieldType.BOOL);
	RS_SchemaKey byteKey = mainSchema.addFieldToSchema("Byte", RS_FieldType.BYTE);
	RS_SchemaKey shortKey = mainSchema.addFieldToSchema("Short", RS_FieldType.SHORT);
	RS_SchemaKey intKey = mainSchema.addFieldToSchema("Int", RS_FieldType.INT);
	RS_SchemaKey longKey = mainSchema.addFieldToSchema("Long", RS_FieldType.LONG);
	RS_SchemaKey floatKey = mainSchema.addFieldToSchema("Float", RS_FieldType.FLOAT);
	RS_SchemaKey doubleKey = mainSchema.addFieldToSchema("Double", RS_FieldType.DOUBLE);
	RS_SchemaKey stringKey = mainSchema.addFieldToSchema("String", RS_FieldType.STRING);
	RS_SchemaKey byteArrayKey = mainSchema.addFieldToSchema("ByteArray", RS_FieldType.RAW);
	RS_SchemaKey structKey = mainSchema.addStructToSchema("Struct", &nestedSchema);

	RS_Arena arena;
	rapidstruct::initArena(&arena, 1024 * 1024);
	RS_Processor* proc = (RS_Processor*) rapidstruct::allocOnArena(&arena, RS_Processor.sizeof);
	rapidstruct::initProcessor(proc, &arena);

	RS_Struct* mainStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(mainStruct, &mainSchema);

	rapidstruct::markProcessorMemBaseline(proc);
	rapidstruct::setProcessorMemory(proc)!!;

	rapidstruct::setStructMemory(mainStruct, proc)!!;

	int iterations = 10;
	for(int i = 0; i < iterations; i++) {
		RS_Struct* nestedStruct = rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
		rapidstruct::initStruct(nestedStruct, &nestedSchema);
		rapidstruct::setStructMemory(nestedStruct, proc)!!;

		nestedStruct.addBoolWithKey(nestedBoolKey, origBoolVal, proc)!!;
		nestedStruct.addByteWithKey(nestedByteKey, origByteVal, proc)!!;
		nestedStruct.addShortWithKey(nestedShortKey, origShortVal, proc)!!;
		nestedStruct.addIntWithKey(nestedIntKey, origIntVal, proc)!!;
		nestedStruct.addLongWithKey(nestedLongKey, origLongVal, proc)!!;
		nestedStruct.addFloatWithKey(nestedFloatKey, origFloatVal, proc)!!;
		nestedStruct.addDoubleWithKey(nestedDoubleKey, origDoubleVal, proc)!!;
		nestedStruct.addStringWithKey(nestedStringKey, origString, proc)!!;
		nestedStruct.addBytesWithKey(nestedByteArrayKey, &origByteArray, origByteArray.len, proc)!!;

		mainStruct.addBoolWithKey(boolKey, origBoolVal, proc)!!;
		mainStruct.addByteWithKey(byteKey, origByteVal, proc)!!;
		mainStruct.addShortWithKey(shortKey, origShortVal, proc)!!;
		mainStruct.addIntWithKey(intKey, origIntVal, proc)!!;
		mainStruct.addLongWithKey(longKey, origLongVal, proc)!!;
		mainStruct.addFloatWithKey(floatKey, origFloatVal, proc)!!;
		mainStruct.addDoubleWithKey(doubleKey, origDoubleVal, proc)!!;
		mainStruct.addStringWithKey(stringKey, origString, proc)!!;
		mainStruct.addBytesWithKey(byteArrayKey, &origByteArray, origByteArray.len, proc)!!;
		mainStruct.addStructWithKey(structKey, nestedStruct, proc)!!;
	}

	uint bytesWritten;
	Byte* bytes = rapidstruct::writeStructToBytes(proc, mainStruct, &bytesWritten)!!;

	RS_Struct* dupMainStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(dupMainStruct, &mainSchema);
	rapidstruct::readBytesToStruct(proc, bytes, bytesWritten, dupMainStruct)!!;

	RS_Field*[] dupNestedStructFields = dupMainStruct.getAllWithKey(structKey, proc)!!;

	RS_Field*[] dupBoolFields = dupMainStruct.getAllWithKey(boolKey, proc)!!;
	RS_Field*[] dupByteFields = dupMainStruct.getAllWithKey(byteKey, proc)!!;
	RS_Field*[] dupShortFields = dupMainStruct.getAllWithKey(shortKey, proc)!!;
	RS_Field*[] dupIntFields = dupMainStruct.getAllWithKey(intKey, proc)!!;
	RS_Field*[] dupLongFields = dupMainStruct.getAllWithKey(longKey, proc)!!;
	RS_Field*[] dupFloatFields = dupMainStruct.getAllWithKey(floatKey, proc)!!;
	RS_Field*[] dupDoubleFields = dupMainStruct.getAllWithKey(doubleKey, proc)!!;
	RS_Field*[] dupStringFields = dupMainStruct.getAllWithKey(stringKey, proc)!!;
	RS_Field*[] dupByteArrayFields = dupMainStruct.getAllWithKey(byteArrayKey, proc)!!;

	for(int i = 0; i < iterations; i++) {
		RS_Struct* dupNestedStruct = dupNestedStructFields[i].asStruct();

		bool dupBoolVal = dupNestedStruct.getWithKey(nestedBoolKey).asBool();
		Byte dupByteVal = dupNestedStruct.getWithKey(nestedByteKey).asByte();
		ushort dupShortVal = dupNestedStruct.getWithKey(nestedShortKey).asShort();
		uint dupIntVal = dupNestedStruct.getWithKey(nestedIntKey).asInt();
		ulong dupLongVal = dupNestedStruct.getWithKey(nestedLongKey).asLong();
		float dupFloatVal = dupNestedStruct.getWithKey(nestedFloatKey).asFloat();
		double dupDoubleVal = dupNestedStruct.getWithKey(nestedDoubleKey).asDouble();
		String dupString = dupNestedStruct.getWithKey(nestedStringKey).asString();
		RS_Field* dupByteArrayField = dupNestedStruct.getWithKey(nestedByteArrayKey);
		Byte[] dupByteArray = dupByteArrayField.asBytes()[0 : dupByteArrayField.bufferLength];

		assert(dupBoolVal == origBoolVal);
		assert(dupByteVal == origByteVal);
		assert(dupShortVal == origShortVal);
		assert(dupIntVal == origIntVal);
		assert(dupLongVal == origLongVal);
		assert(dupFloatVal == origFloatVal);
		assert(dupDoubleVal == origDoubleVal);
		assert(dupString == origString);
		assert(dupByteArray == origByteArray[0 : origByteArray.len]);

		dupBoolVal = dupBoolFields[i].asBool();
		dupByteVal = dupByteFields[i].asByte();
		dupShortVal = dupShortFields[i].asShort();
		dupIntVal = dupIntFields[i].asInt();
		dupLongVal = dupLongFields[i].asLong();
		dupFloatVal = dupFloatFields[i].asFloat();
		dupDoubleVal = dupDoubleFields[i].asDouble();
		dupByteArrayField = dupByteArrayFields[i];
		dupByteArray = dupByteArrayField.asBytes()[0 : dupByteArrayField.bufferLength];

		assert(dupBoolVal == origBoolVal);
		assert(dupByteVal == origByteVal);
		assert(dupShortVal == origShortVal);
		assert(dupIntVal == origIntVal);
		assert(dupLongVal == origLongVal);
		assert(dupFloatVal == origFloatVal);
		assert(dupDoubleVal == origDoubleVal);
		assert(dupString == origString);
		assert(dupByteArray == origByteArray[0 : origByteArray.len]);
	}

	rapidstruct::destroyArena(&arena);
}