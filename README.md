#Base64 Codec for Dart
========================
A Base64 Codec for Dart.

Encodes/Decodes to Base64. Has options for url safe encoding, line breaks

Licensed under Apache 2.0


##Example Usage
--------

	// get a codec instance
	var c = new Base64Codec(urlSafe:true)
	// or get one of the static instances.
	var codec = Base64Codec.codec
	var urlSafe = Base64Codec.urlSafeCodec
	
	// encode a string to Base64
	var encodedString = urlSafe.encodeString("foo");
	// decode a string
	var foo = codec.decodeString(encodedString);
	
	var data = [24,56,78];
	// encode a List of bytes - use line breaks 
	var d = codec.encodeList(data,useLineSep:true);
	// decode a Base64 encoded list
	var e = codec.decode(d);
	
	// Use as a Stream Transformer to encode streams to Base64
	stream.transform( Base64Codec.codec.encodeTransformer).listen(....)
	
	// Or decode streams
	stream.transform(Base64Codec.codec.decodeTransformer).listen(...)
	
	

See the dartdoc for more options