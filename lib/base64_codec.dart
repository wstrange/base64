
library base64_codec;

import 'dart:math';
import 'dart:typeddata';
import 'dart:async';

/*
 * Base64 Codec
 *
 * Encode or decode to Base64 representation [http://en.wikipedia.org/wiki/Base64]
 *
 */

class Base64Codec {
  // true if we should encode using urlsafe characters
  bool _urlSafe = false;

  /** Mask used to extract 6 bits, used when encoding */
  const int _MASK_6BITS = 0x3f;

  // The '=' PAD character used in Base64 for padding
  const int PAD =  61;
  // CR and LF constants -for line breaks;
  const int CR = 13;
  const int LF = 10;

  // if we are using CR/LF seperators
  const MAX_LENGTH = 64;

  const _BITS_PER_ENCODED_BYTE = 6;
  const _BYTES_PER_ENCODED_BLOCK = 4;



  // Lookup tables for base64 characters
  static final List<int> _codeList = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.codeUnits;
  // url safe avoids use of + / chars
  static final List<int> _urlSafeCodeList = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'.codeUnits;

  // lookup table - initialized from above
  List<int> _LT;

  Base64Codec(this._urlSafe) {
    _LT = _urlSafe ? _urlSafeCodeList : _codeList;
  }


  /**
   * This array is a lookup table that translates Unicode characters drawn from the "Base64 Alphabet" (as specified
   * in Table 1 of RFC 2045) into their 6-bit positive integer equivalents. Characters that are not in the Base64
   * alphabet but fall within the bounds of the array are translated to -1.
  *
   * Note: '+' and '-' both decode to 62. '/' and '_' both decode to 63. This means decoder seamlessly handles both
   * URL_SAFE and STANDARD base64. (The encoder, on the other hand, needs to know ahead of time what to emit).
  *
   * Thanks to "commons" project in ws.apache.org for this code.
   * http://svn.apache.org/repos/asf/webservices/commons/trunk/modules/util/
   */
  static const _DECODE_TABLE = const [
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
      -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, 62, -1, 63, 52, 53, 54,
      55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1, 0, 1, 2, 3, 4,
      5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
      24, 25, -1, -1, -1, -1, 63, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34,
      35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51];


  // Encodes 3 input bytes into 4 base64 characters
  // There *must* be 3 bytes available, and there must be 4 bytes in the outList
  void _encode3to4(List<int> inList, int inPos, List<int> outList, int outPos) {
    // Copy next three bytes into lower 24 bits of int, paying attension to sign.
    int i = ((inList[inPos++] & 0xff) << 16) & 0xffffffff;
    i |= ((inList[inPos++] & 0xff) << 8) & 0xffffffff;
    i |= (inList[inPos++] & 0xff);
    outList[outPos++] = _LT[(i >> 18) & _MASK_6BITS];
    outList[outPos++] = _LT[(i >> 12) & _MASK_6BITS];
    outList[outPos++] = _LT[(i >> 6) & _MASK_6BITS];
    outList[outPos++] = _LT[i & _MASK_6BITS];
  }

  // handle the last 1..3 bytes with padding ('=')

  void _encodeRemainder(List <int> inList, int inPos, List<int> outList, int outPos) {
    int modulus = inList.length - inPos;

    if( modulus == 0)
      return; // nothing to do.

    int i = ((inList[inPos] & 0xff) << 10) & 0xffffffff;
    if (modulus == 2 )
      i = i | (((inList[inPos+1] & 0xff) << 2) & 0xffffffff);

    outList[outPos++] = _LT[ i >> 12];
    outList[outPos++] = _LT[( i >> 6) & _MASK_6BITS];
    if( _urlSafe && modulus == 1)
      return; // we are done.
    outList[outPos++] = modulus == 2 ?  _LT[ i & _MASK_6BITS] : PAD;
    if( _urlSafe )
      return; // done again.
    outList[outPos++] = PAD;
  }

  List<int> encodeList(List<int> inList, {bool useLineSep : false}) {

    if( inList == null || inList.length == 0)
      return new List();


    int eLen = (inList.length ~/ 3) * 3;              // Length of even 24-bits.
    int cCnt = ((inList.length - 1) ~/ 3 + 1) * 4;   // Returned character count
    int dLen = cCnt + (useLineSep ? (cCnt - 1) ~/ 76 * 2 : 0); // Length of returned array

    if( _urlSafe ) {
      // need to make sure we dont allocate too many bytes
      int x = inList.length - eLen;
      if (x == 1)
          dLen -= 2;
      if( x == 2)
          dLen -= 1;
    }
    var outList = new List<int>(dLen);
    var outPos = 0;
    var i = 0;

    for( int lineChars = 0; i < eLen; i += 3) {
      _encode3to4(inList,i,outList,outPos);
      outPos += 4;
      if( useLineSep ) {
        lineChars += 4; // we encoded 4 bytes
        if(  lineChars >= MAX_LENGTH) {
          outList[outPos++] = CR;
          outList[outPos++] = LF;
          lineChars = 0;
        }
      }
    }

    // now handle any remainder
    _encodeRemainder(inList,i,outList,outPos);

    return outList;
  }

  String encodeString(String input,{bool useLineSep: false} ) =>
       new String.fromCharCodes(encodeList(input.codeUnits, useLineSep :useLineSep));

  /**
   * Decode the provided List of Base64 bytes
   *
   */
  List<int> decodeList(List<int> inList) {
    if( inList == null || inList.length ==0)
      return new List();
    // allocate an array big enough to hold the output.
    // This might be too big, but we will return a subset of this buffer later
    int sz = (inList.length ~/ 4) * 3 + 1;
    var buffer = new Uint8List(sz);
    var outPos =0;
    int ibitWorkArea = 0;
    bool eof = false;
    int modulus = 0;
    for (int i = 0; i < inList.length; i++) {
      var b = inList[i];
      if (b == PAD) {
          // We're done.
          eof = true;
          break;
      }
      else {
        if (b >= 0 && b < _DECODE_TABLE.length) {
            var result = _DECODE_TABLE[b];
            if (result >= 0) {
                modulus = (modulus+1) % _BYTES_PER_ENCODED_BLOCK;
                // https://groups.google.com/a/dartlang.org/d/msg/misc/6u9UNNLRjZw/YE9bV99lWyoJ
                ibitWorkArea = ((ibitWorkArea << _BITS_PER_ENCODED_BYTE) & 0xffffffff) + result;
                if (modulus == 0) {
                    buffer[outPos++] = ((ibitWorkArea >> 16) & 0xff);
                    buffer[outPos++] = ((ibitWorkArea >> 8) & 0xff);
                    buffer[outPos++] = (ibitWorkArea & 0xff);
                }
            }
        }
      }
    }
    // Two forms of EOF as far as base64 decoder is concerned: actual
    // EOF (-1) and first time '=' character is encountered in stream.
    // This approach makes the '=' padding characters completely optional.
    if (eof && modulus != 0) {
      // We have some spare bits remaining
      // Output all whole multiples of 8 bits and ignore the rest
      switch (modulus) {
          case 2 : // 12 bits = 8 + 4
              ibitWorkArea = ibitWorkArea >> 4; // dump the extra 4 bits
              buffer[outPos++] = ((ibitWorkArea) & 0xff);
              break;
          case 3 : // 18 bits = 8 + 8 + 2
              ibitWorkArea = ibitWorkArea >> 2; // dump 2 bits
              buffer[outPos++] = ((ibitWorkArea >> 8) & 0xff);
              buffer[outPos++] = ((ibitWorkArea) & 0xff);
              break;
          default:
      }
    }

    // buffer was same size - so we can just return it
    if( outPos == buffer.length) return buffer;
    // else - we made buffer too big. Return a smaller buffer by
    // creating a view on the larger buffer
    int diff = buffer.length - outPos;
    return new Uint8List.view(buffer.buffer, 0, buffer.length - diff);
  }


  StreamTransformer get encodeTransform {
    var buffer = new List();

    var t = new StreamTransformer(
      handleData: (data,sink) {
        buffer.add(data);
      },
      handleDone: (sink) {
        var l = encodeList(buffer);
        l.forEach( (v) => sink.add(v));
        sink.close();
     });

    return t;
  }

  StreamTransformer get decodeTransform {
    var buffer = new List();

    var t = new StreamTransformer(
      handleData: (data,sink) {
        buffer.add(data);
      },
      handleDone: (sink) {
        var l = decodeList(buffer);
        l.forEach( (v) => sink.add(v));
        sink.close();
     });

    return t;
  }




}