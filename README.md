#Base64 Codec for Dart
========================
A Base64 Codec for the [Dart language][dart]. 

Encodes/Decodes to Base64. Has options for url safe encoding, line breaks

Licensed under Apache 2.0


##Example Usage
--------

	// get a codec instance
	var c = new Base64Codec(urlSafe:true)
	// or get one of the static instances.
	var codec = Base64Codec.codec
	var urlSafe = Base64Codec.urlSafeCodec
	
	// encode a string
	var encodedString = urlSafe.encodeString("foo");
	// decode a string
	var foo = codec.decodeString(decodedString);
	
	var data = [24,56,78];
	// encode binary data - use line breaks 
	var d = codec.encodeList(data,useLineSep:true);
	// decode List data
	var e = codec.decode(d);
	
	// Use as a Stream Transformer to encode streams
	stream.transform( Base64Codec.codec.encodeTransformer).listen(....)
	
	// Or decode streams
	stream.transform(Base64Codec.codec.decodeTransformer).listen(...)
	
	

See the dartdoc for more options





