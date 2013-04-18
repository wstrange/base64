import 'package:unittest/unittest.dart';


import 'package:base64/base64.dart';

import 'dart:utf';
import 'dart:math';



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

  test("debug", () {
    var b = new Base64.defaultCodec();
    expect( b.encodeString("a"), equals("YQ=="));
  });

  test('Test basic encoding',  () {
    // default codec
    var b = new Base64.defaultCodec();
    // encoder with urlSafe encoding
    var b2 = new Base64.urlSafeCodec();

    // test strings and their expected encoding
    var expected = { "a":     "YQ==",
                     "ab":    "YWI=",
                     "test": "dGVzdA==",
                     "this is a test 12345678910": "dGhpcyBpcyBhIHRlc3QgMTIzNDU2Nzg5MTA="
          };


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

}

