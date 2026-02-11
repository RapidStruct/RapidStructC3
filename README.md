# RapidStructC3

RapidStruct is a simple schema-based binary serialization format. Read up on the specs for more info on RapidStruct itself. This guide is only concerned with the usage of the C3 language library implementation.  To start using this library, simply copy rapidstruct.c3 to your source folder.  Below is a quick rundown of the basics.  For the sake of simplicity, we will force unwrap all optionals, but you probably won't want to do that in production.

## Schemas

Because RapidStruct is schema-based, you must have schema's defined. This is done by using an `RS_Schema`. A `RS_Schema` is simply a collection of types associated to tags and ultimately defines how the data will be represented when serialized. Create a schema either on the stack or the heap, either will work.  It just depends on you memeory needs.  After creation, simply add fields to it:  

~~~
RS_Schema subnetSchema;
subnetSchema.addFieldToSchema("IPV6", RS_FieldType.BOOL);
subnetSchema.addFieldToSchema("IPAddress", RS_FieldType.RAW);
subnetSchema.addFieldToSchema("CIDR", RS_FieldType.BYTE);
subnetSchema.addFieldToSchema("Name", RS_FieldType.STRING);
~~~

In this example we created a schema to describe a subnet.  First, we use a `BOOL` type to indicate if this is an IPv4 or IPv6 network. Then we are using a `RAW` type to represent the bytes of the IP address (`RAW` just indicates a byte array). We used the `BYTE` type to indicate the CIDR/mask length. And finally, a `STRING` to represent the name of the subnet.  All types are assumed to be unsigned.  You must convert them if you need signed values. `RAW` is obviously the most flexible and can essentially be used to represent anything.  `STRING` may be platform dependant, but generally speaking should at least support ASCII (the 1st seven bytes of UTF-8 codes is ASCII, for instance.)

## RS_Processor

The `RS_Processor` is what performs the serialization/deserialization.  You can have many `RS_Processors`, and I typically recommend that you have one per serialization/deserialization sequence.  That doesn't mean that you can't reuse them (you should), but they are not thread-safe by themselves.  In other words, if there's a specific serialization event that happens repeatedly, that should be handled by a dedicated `RS_Processor`, but don't use a single `RS_Processor` to handle many different serialization events unless the system is very simple and all the events happen in serial.  You first need to create an `RS_Arena`, and then you can create the `RS_Processor`:  

~~~
RS_Arena arena;
rapidstruct::initArena(&arena, 1024 * 1024);

RS_Processor* proc (RS_Processor*) rapidstruct::allocateOnArena(&arena, RS_Processor.sizeof);
rapidstruct::initProcessor(proc, &arena);
~~~

Here we created an `RS_Arena` with a 1 MiB allocation.  We then used the arena to allocate a `RS_Processor` and then we call `rapidstruct::initProcessor()`. An `RS_Arena` is a simple 8-byte aligned bump allocator that is used for handling memory needs for all things RapidStruct.  And as shown here, we also directly use it for allocating everything we need, like the `RS_Processor` itself.  This makes for easy cleanup when needed.  Also, the arena currently is a fixed size, so size it accordingly.  This could be a blessing or a curse depending on your perspective.  While serializing or deserializing, if you don't force unwrap returned optionals you can gracefully deal with failures due to running out of arena memory.

## RS_Struct

Next is the `RS_Struct`.  This is the core of the library and simply holds a common grouping of data.  In this example, I will simply continue to reuse the same `RS_Struct` over and over.  I recommend that you do the same unless you have a specific reason not to (E.g., multiple nested `RS_Struct`s of an unknown quantity may be difficult to repeatedly reuse).

~~~
RS_Struct* rsStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
rapidstruct::initStruct(rsStruct, &schema);
~~~

Here we allocated the `RS_Struct` with the arena and then called `rapidstruct::initStruct()`, associating it with a schema.

## Filling with Data

Now is about the time we can start to do something useful with the `RS_Struct`.  But first, in order to properly reuse the `RS_Processor` and `RS_Struct` we need to mark the first reusable memory address and then allocate the buffers for the processor:

~~~
rapidstruct::markProcessorMemBaseline(proc);
rapidstruct::setProcessorMemory()!!;
rapidstruct::setStructMemory(rsStruct, proc)!!
~~~

This tells the `RS_Processor` to record the `RS_Arena`'s next available address.  `setProcessorMemory()` then allocates memory from the arena to use as buffers during serialization/deserialization.  When we want do more serializations, we will call `setProcessorMemory()` again, which will put us back to the baseline point in the `RS_Arena`'s memory, and then will reallocate the needed buffers again.  We use `markProcessorMemBaseline()` to prevent overriding things we are still using that we also allocated on the arena (I.e., the `RS_Processor` and `RS_Struct`).  The function `rapidstruct::setStructMemory(RS_Struct*, RS_Processor*)` allocates the necessary memory needed for the `RS_Struct`'s own internal buffer for holding fields, etc.  At a minimum, that needs to be called after `rapidstruct::initStruct()`, and anytime that the `RS_Struct`'s memory may be corrupted (as in calling `setProcessorMemory()`).  Now, let's actually add some data:  

~~~
rsStruct.addBool("IPV6", false, proc)!!;
char[*] address = {192, 168, 0, 1};
rsStruct.addBytes("IPAddress, address, address.len, proc)!!;
rsStruct.addByte("CIDR", 24, proc)!!;
rsStruct.addString("Name", "Home network", proc)!!;
~~~

This should be mostly self explanatory.  You pass in the `RS_Processor` because an `RS_Field` has to be instantiated for every field that is added, we use the `RS_Processor`'s associated `RS_Arena` to handle that.  **TODO: insert error handling details here when finished, like "what happends when an undefined schema tag is used?"** **FYI**, you can add more than one piece of data under the same tag as long as it is the same type. I.e., you could add another raw byte array with the tag "IPAddress", but it would be up to the receiver of the serialized bytes to know to look for an additional byte array with the tag "IPAddress".  Now let's serialize some data!

## Serialization

Now we can take the `RS_Struct` and turn it into some raw bytes! To do that, simply call the following:

~~~
int bytesWritten;
char* serialBytes = rapidstruct::writeStructToBytes(proc, rsStruct, &bytesWritten)!!;
~~~

That's basically it.  You know have an `RS_Struct` in a byte pointer/array.  In that example, `bytesWritten` is how long the array/memory segment is.  After you do something with the bytes (copy, send over the network, etc), you can then call `setProcessorMemory()` and `rapidstruct::setStructMemory()` and then fill with more data, send it, and repeat...

## Deserialization

Alright, you're on the receiving end of those bytes. What now? the setup is exactly the same through the [RS_Struct](#rs_struct) section.  So create and initialize your `RS_Arena`, `RS_Processor`, and `RS_Struct`. After that is complete, call the following:  

~~~
...
rapidstruct::initStruct(rsStruct, schema);
//Do not call rapidstruct::setStructMemory() when deserializing as that is done
//in the readBytesToStruct() function below and you will waste memory in the RS_Arena

char* serialBytes = ...(from disk, network, etc)
rapidstruct::readBytesToStruct(proc, serialBytes, serialBytesLength, rsStruct)!!;
~~~

That uses the `RS_Processor` to deserialize the bytes passed and fill the passed `RS_Struct` with the deserialized data. You can then grab the data:  

~~~
bool ipv6 = rsStruct.get("IPV6").asBool();
RS_Field* addressField = rsStruct.get("IPAddress");
char* addressBytes = addressField.asBytes();
int addressLength = addressField.bufferLength;
char cidr = rsStruct.get("CIDR").asByte();
String subnetName = rsStruct.get("Name").asString();

//This is optional as .asString() returns a String and not a char*/ZString
int subnetNameLength = rsStruct.get("Name").bufferLength;
~~~

Now you have some useful data to do things with!

## Nesting an RS_Struct

You can also nest an `RS_Struct` inside of another `RS_Struct`.  That nested `RS_Struct` also has to have a schema.  You add it with following method: `RS_Struct.addStruct(String tag, RS_Struct* nestedStruct, RS_Processor* proc)`:

~~~
//Create the nested RS_Struct...
RS_Struct nestedrsStruct;
rapidstruct::initStruct(&nestedrsStruct, nestedSchema);
rapidstruct::setStructMemory(nestedrsStruct, proc)!!;

rsStruct.addStruct("NestedStructTag", &nestedrsStruct, proc)!!;
~~~

And to grab the nested `RS_Struct` after deserialization:  

~~~
//Instantiate and deserialize the main RS_Struct...
RS_Struct* outerrsStruct = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
rapidstruct::initStruct(outerrsStruct, schema);
rapidstruct::readBytesToStruct(proc, serialBytes, serialBytesLength, outerrsStruct)!!;

//Retrieve the nested RS_Struct
RS_Struct* nestedrsStruct = outerrsStruct.get("NestedStructTag").asStruct();
~~~

## Cleanup

If you need your memory back for whatever reason and you're completely done using the things allocated with a `RS_Arena` (like `RS_Struct` and `RS_Processor` in the examples), simply call `rapidstruct::destroyArena(RS_Arena*);` and that will free the memory that was used.

## Quick Facts

- All of your data that is **NOT** of a primitive type (primitives meaning int, float, etc) lives in a buffer that is backed by a `RS_Arena`.  That means that if you have a byte array (or similar) that was deserialized and you call `setProcessorMemory()` and then start deserializing again, that byte array may now be corrupted.  So once you receive some data and deserialize it into a `RS_Struct`, it is probably best to copy the data you need AND THEN do your processing so that you can safely reuse your `RS_Processor`, `RS_Struct`, etc.  
- The maximum number of defined tags in a schema is 256, as they are represented with 1-byte.
- You can have an essentially unlimited amount of fields in one RS_Struct if they share tags.  This is limited by your `RS_Arena` size, of course.
- The maximum length of the variable-length field types (`RAW`, `STRING`, and `STRUCT`-which is a nested `RS_Struct`) is 65535, as they are prepended with a 2-byte length when serialized.


## Full Serialization Example

Below is a full example of how one might serialize data.

~~~
import rapidstruct;

fn int main()
{
	RS_Schema birthdaySchema;
	birthdaySchema.addFieldToSchema("Day", RS_FieldType.BYTE);
	birthdaySchema.addFieldToSchema("Month", RS_FieldType.BYTE);
	birthdaySchema.addFieldToSchema("Year", RS_FieldType.SHORT);
	birthdaySchema.addFieldToSchema("Name", RS_FieldType.STRING);

	//RS_Processor setup
    RS_Arena arena;
    rapidstruct::initArena(&arena, 1024 * 1024);
    RS_Processor* proc = (RS_Processor*) rapidstruct::allocOnArena(&arena, RS_Processor.sizeof);
    rapidstruct::initProcessor(proc, &arena);

    //Main struct
    RS_Struct* rs_birthday = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(rs_birthday, &birthdaySchema);
	rapidstruct::markProcessorMemBaseline(proc);

	while(hasMoreWorkToDo()) {
        //set memory on every iteration
		rapidstruct::setProcessorMemory(proc)!!;
		rapidstruct::setStructMemory(rs_birthday, proc)!!;

		char day;
		char month;
		ushort year;
		String name;
		functionThatGetsBirthdays(&day, &month, &year, &name);

		rs_birthday.addByte("Day", day, proc)!!;
		rs_birthday.addByte("Month", month, proc)!!;
		rs_birthday.addShort("Year", year, proc)!!;
		rs_birthday.addString("Name", name, proc)!!;

		int bytesWritten;
   		char* birthdayBytes = rapidstruct::writeStructToBytes(proc, rs_birthday, &bytesWritten)!!;

		functionThatSendsBytesOverNetwork(birthdayBytes, bytesWritten);
	}

	//Call this if you need your memory back
	rapidstruct::destroyArena(&arena);

	return 0;
}
~~~

## Full Deseralization Example

Below is a full example of how one might deserialize data.

~~~
import rapidstruct;

fn int main()
{
	RS_Schema birthdaySchema;
	birthdaySchema.addFieldToSchema("Day", RS_FieldType.BYTE);
	birthdaySchema.addFieldToSchema("Month", RS_FieldType.BYTE);
	birthdaySchema.addFieldToSchema("Year", RS_FieldType.SHORT);
	birthdaySchema.addFieldToSchema("Name", RS_FieldType.STRING);

	//RS_Processor setup
    RS_Arena arena;
    rapidstruct::initArena(&arena, 1024 * 1024);
    RS_Processor* proc = (RS_Processor*) rapidstruct::allocOnArena(&arena, RS_Processor.sizeof);
    rapidstruct::initProcessor(proc, &arena);

    //Main struct
    RS_Struct* rs_birthday = (RS_Struct*) rapidstruct::allocOnArena(&arena, RS_Struct.sizeof);
	rapidstruct::initStruct(rs_birthday, &birthdaySchema);
	rapidstruct::markProcessorMemBaseline(proc);

	while(hasMoreWorkToDo()) {
		//set memory on every iteration, but we don't have to worry
        //about calling setStructMemory() on deserialization as
        //That is called by rapidstruct::readBytesToStruct()
		rapidstruct::setProcessorMemory(proc)!!;

		char* birthdayBytes;
		int bytesReceived;
		functionThatReceivesBytesOverTheNetwork(&birthdayBytes, &bytesReceived);

		rapidstruct::readBytesToStruct(proc, birthdayBytes, bytesReceived, rs_birthday)!!;
		char day = rs_birthday.get("Day").asByte();
		char month = rs_birthday.get("Month").asByte();
		ushort year = rs_birthday.get("Year").asShort();
		String name = rs_birthday.get("Name").asString();

		functionThatDisplaysBirthday(day, month, year, name);
	}

	//Call this if you need your memory back
	rapidstruct::destroyArena(&arena);

	return 0;
}
~~~