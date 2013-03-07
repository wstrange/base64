
import 'package:unittest/unittest.dart';

import 'package:base64/base64.dart';

import 'dart:utf';
import 'dart:math';


main() {


  test('Test basic encoding',  () {
    // default codec
    var b = new Base64.codec();
    // encoder with urlSafe encoding
    var b2 = new Base64.urlSafe();

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

  test('Random shit test', () {
    var b = new Base64.codec();

    var l = new List<int>(1000);
    var r = new Random();

    for(int i=0; i < 100; ++i) {
      // create a list with random bytes
      for(int j=0; j < l.length; ++j)
        l[j] = r.nextInt(255);

      // encode/decode
      var enc = b.encode(l);
      var dec = b.decode(enc);
      //print("list $l Encoded = $enc decoded = $dec");
      // see if we got back our original byte list
      expect(dec,equals(l));
    }
  });

}

