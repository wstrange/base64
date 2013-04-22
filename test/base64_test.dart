import 'package:unittest/unittest.dart';


import 'package:base64/base64.dart';
import 'package:base64/base64_codec.dart';

import 'dart:utf';
import 'dart:math';
import 'dart:async';



var random = new Random(0xCAFEBABE);

// fill list l with random bytes
fillRandom(List<int> l) {
  for(int j=0; j < l.length; ++j)
    l[j] = random.nextInt(255);
}


/**
 * Test Base64 codec
 */
main() {
  // test strings and their expected encoding
  var expected = { "a":     "YQ==",
                   "ab":    "YWI=",
                   "test": "dGVzdA==",
                   "this is a test 12345678910": "dGhpcyBpcyBhIHRlc3QgMTIzNDU2Nzg5MTA=",
"The rain in spain falls mainly in the plane. This should wrap":
"VGhlIHJhaW4gaW4gc3BhaW4gZmFsbHMgbWFpbmx5IGluIHRoZSBwbGFuZS4gVGhp\r\ncyBzaG91bGQgd3JhcA==",

"No. The rain in spain does not fall in the plane. It falls in the plain, which is quite a different thing than the plane.":
"Tm8uIFRoZSByYWluIGluIHNwYWluIGRvZXMgbm90IGZhbGwgaW4gdGhlIHBsYW5l\r\nLiBJdCBmYWxscyBpbiB0aGUgcGxhaW4sIHdoaWNoIGlzIHF1aXRlIGEgZGlmZmVy\r\nZW50IHRoaW5nIHRoYW4gdGhlIHBsYW5lLg=="
  };

  test("debug", () {
    var codec = new Base64Codec(false);
    var urlSafeCodec = new Base64Codec(true);
    expected.forEach(  (k,v) {
      var inList = k.codeUnits;
      var outList = v.codeUnits;
      var r = codec.encodeList(inList, useLineSep:true);
      expect(r , equals(outList));
      print("Encoded = $r");
      var s = codec.decodeList(r);
      expect(s, equals(inList));
      print("Decoded = $s");
      //expect( enc.encodeString(k,useLineSep:true), equals(v));
      // urlEncoded strings have no padding on the end
      //expect( urlSafeEnc.encodeString(k), equals(v.replaceAll('=', '')));
    });

  });

  test('Test basic encoding',  () {
    // default codec
    var b = new Base64.defaultCodec();
    // encoder with urlSafe encoding
    var b2 = new Base64.urlSafeCodec();


    expected.forEach(  (k,v) {
      expect( b.encodeString(k), equals(v));
      // urlEncoded strings have no padding on the end
      expect( b2.encodeString(k), equals(v.replaceAll('=', '')));
    });

    expected.keys.forEach( (k) {
      var e = b.encodeString(k);
      // encode/decode should get back the same thing
      expect( k,equals( b.decodeString(e)) );
    });
  });

  test('line break test', () {
    var s = "test 1234567890AB";
    // tested using http://www.motobit.com/util/base64-decoder-encoder.asp

    // new codec with line length of 12
    var b = new Base64(12, '\n', false);
    // should get two lines
    var xx = b.encodeString(s).trim().split('\n');
    //print(" xx = $xx");
    expect(xx.length, equals(2));
    expect(xx[0], equals('dGVzdCAxMjM0'));
    expect(xx[1], equals('NTY3ODkwQUI='));

    // make sure we get back what we started with
    expect(b.decodeString(b.encodeString(s)), equals(s));
  });

  test('Random bytes test', () {
    var b = new Base64.defaultCodec();


    for(int i=0; i < 100; ++i) {
      // create random length list...
      var l = new List<int>(random.nextInt(2048));
      // fill it with random bytes
      fillRandom(l);
      // encode/decode
      var enc = b.encode(l);
      var dec = b.decode(enc);
      // see if we got back what we started with
      expect(dec,equals(l));
    }
  });

  const iterations = 10000;

  // test used for timing encoding/decoding times
  test('CODEC benchmark test', () {
    var l = new List<int>(1000);
    var b = new Base64.defaultCodec();
    fillRandom(l);
    var w = new Stopwatch()..start();
    for( int i =0; i < iterations; ++i ) {
      var enc = b.encode(l);
      var dec = b.decode(enc);
    }
    print("Elapsed time for $iterations iterations is ${w.elapsedMilliseconds} msec");

  } );

  // test used for timing encoding/decoding times
  test('CODEC benchmark test two', () {
    var l = new List<int>(1000);
    var codec = new Base64Codec(false);
    fillRandom(l);
    var w = new Stopwatch()..start();
    for( int i =0; i < iterations; ++i ) {
      var enc = codec.encodeList(l);
      var dec = codec.decodeList(enc);
      // for benchmark comment this out - it really slows down the timing
      //expect(dec,equals(l));
    }
    print("Elapsed time for $iterations iterations is ${w.elapsedMilliseconds} msec");

  } );

  solo_test('Base64 Encode Stream transformer', () {
    var msg = "Hello World".codeUnits;
    var stream = new Stream.fromIterable(msg);

    var t = (new Base64Codec(false)).encodeTransform;

    var buf = new List();
    stream.transform( t)
      .listen( (d) => buf.add(d),
          onDone:
            expectAsync0( () => print("encoded buf $buf")));

  });

}

