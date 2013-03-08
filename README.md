Base64 Codec for Dart
========================
A port of the Apache commons Base64 codec for the [Dart language][dart]. 

Encodes/Decodes to Base64. Has options for url safe encoding, setting line lengths, etc.

Licensed under Apache 2.0 (to be consistent with the original Java source).


Usage
--------

	// get a codec instance
	var b64 = new Base64.defaultCodec();
	// OR get a url safe codec instance
	var b64 = new Base64.urlSafeCodec();
	
	// encode a string
	var newstring = b64.encodeString("foo");
	// decode a string
	var foo = b64.decodeString(newString);
	
	var data = [24,56,78];
	// encode binary data
	var d = b64.encode(data);
	// decode data
	var e = b64.decode(d);
	

See the dartdoc for other constructor options





