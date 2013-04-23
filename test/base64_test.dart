import 'package:unittest/unittest.dart';


import 'package:base64/base64_codec.dart';

import 'dart:math';
import 'dart:async';
import 'dart:io';



var random = new Random(0xCAFEBABE);

// fill list l with random bytes
fillRandom(List<int> l) {
  for(int j=0; j < l.length; ++j)
    l[j] = random.nextInt(255);
}

var regex = new RegExp( r'[\r\n=]');
// strip all line breaks and padding
String urlSafeString(String s) => s.replaceAll(regex, '');

/**
 * Test Base64 codec
 */
main() {
// default codec
  var codec = Base64Codec.codec;
  // encoder with urlSafe encoding
  var urlSafeCodec = Base64Codec.urlSafeCodec;

  // test strings and their expected encoding
  var expected = {
                   "a":     "YQ==",
                   "ab":    "YWI=",
                   "test": "dGVzdA==",
                   "this is a test 12345678910": "dGhpcyBpcyBhIHRlc3QgMTIzNDU2Nzg5MTA=",
"The rain in spain falls mainly in the plane. This should wrap":
"VGhlIHJhaW4gaW4gc3BhaW4gZmFsbHMgbWFpbmx5IGluIHRoZSBwbGFuZS4gVGhp\r\ncyBzaG91bGQgd3JhcA==",
"No. The rain in spain does not fall in the plane. It falls in the plain, which is quite a different thing than the plane.":
"Tm8uIFRoZSByYWluIGluIHNwYWluIGRvZXMgbm90IGZhbGwgaW4gdGhlIHBsYW5l\r\nLiBJdCBmYWxscyBpbiB0aGUgcGxhaW4sIHdoaWNoIGlzIHF1aXRlIGEgZGlmZmVy\r\nZW50IHRoaW5nIHRoYW4gdGhlIHBsYW5lLg=="
  };

  // same map - but using List of code units instead of String
  var expectedCodeUnits = new Map();
  expected.forEach( (k,v) => expectedCodeUnits[k.codeUnits] = v.codeUnits);

  test('Debug', () {
    //expect(codec.decodeString('YQ'), equals('a'));
    expect(codec.decodeString('YWI'), equals('ab'));
  });

  test('Decode test', () {
    expected.forEach( (input,encoded) {
      expect(codec.decodeString(encoded), equals(input));
      // trim the padding - should still decode OK
      var p = urlSafeString(encoded);
      expect(codec.decodeString(p), equals(input));
    });
  });

  test('Test basic encoding',  () {
    expected.forEach(  (input,encoded) {
      expect( codec.encodeString(input,useLineSep:true), equals(encoded));
      // urlEncoded strings have no padding on the end
      var p = urlSafeString(encoded);
      expect( urlSafeCodec.encodeString(input), equals(p));
    });


    expected.keys.forEach( (k) {
      var e = codec.encodeString(k);
      // encode/decode should get back the same thing
      expect( k,equals( codec.decodeString(e)) );
    });
  });



  test('Random bytes test', () {
    for(int i=0; i < 100; ++i) {
      // create random length list...
      var l = new List<int>(random.nextInt(2048));
      // fill it with random bytes
      fillRandom(l);
      // encode/decode
      var enc = codec.encodeList(l);
      var dec = codec.decodeList(enc);
      // see if we got back what we started with
      expect(dec,equals(l));
    }
  });

  const iterations = 10000;


  // test used for timing encoding/decoding times
  test('CODEC benchmark test two', () {
    var l = new List<int>(1000);
    fillRandom(l);
    var w = new Stopwatch()..start();
    for( int i =0; i < iterations; ++i ) {
      var enc = codec.encodeList(l);
      var dec = codec.decodeList(enc);
      // for benchmark comment this out - it really slows down the timing
      //expect(dec,equals(l));
    }
    print("Elapsed time $iterations iterations is ${w.elapsedMilliseconds} msec");

  } );

  test('Base64 Encode Stream transformer', () {
    expectedCodeUnits.forEach( (k,v) {
      var t = codec.encodeTransformer;
      var stream = new Stream.fromIterable(k);
      var buf = new List();
      stream.transform(t).listen( (d) => buf.add(d),
          onDone:
            expectAsync0( () {
              //print("$v\n$buf");
              expect(buf,equals(v));
            })
          );
    }); // end test
  });

  test('Base64 Decode Stream Transformer', () {
    expectedCodeUnits.forEach( (k,v) {
      var t = codec.decodeTransformer;
      var stream = new Stream.fromIterable(v);
      var buf = new List();
      stream.transform(t).listen( (d) => buf.add(d),
          onDone:
            expectAsync0( () {
              //print("$k\n$buf");
              expect(buf,equals(k));
            })
          );
    }); // end test

  });


  test('Base64 Encode/Decode Stream transformer', () {
    // pipelines the encode-> decode to see
    // if we get back what we started with
    expectedCodeUnits.forEach( (k,v) {
      var stream = new Stream.fromIterable(k);
      var buf = new List();
      stream
        .transform(codec.encodeTransformer)
        .transform(codec.decodeTransformer)
        .listen( (d) => buf.add(d),
          onDone:
            expectAsync0( () {
              //print("$k\n$buf");
              expect(buf,equals(k));
            })
          );
    }); // end test
  });


  test('File Streaming test',() {
    var f = new File('test/base64_test.dart');
    var buf = new List();

    f.readAsBytes().then( expectAsync1((bytes) {
      new Stream.fromIterable(bytes)
      .transform(codec.encodeTransformer)
      .transform(codec.decodeTransformer)
      .listen( (d) => buf.add(d),
        onDone:
          expectAsync0( () {
            //print( new String.fromCharCodes(buf));
            expect(buf,equals(bytes));
          })
        );
    }));
  });

}

