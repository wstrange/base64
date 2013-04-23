library base64_codec;

import 'dart:math';
import 'dart:typeddata';
import 'dart:async';

/**
 * Base64 Codec to encode or decode Base64.
 *
 * See [Base64 Encoding](http://en.wikipedia.org/wiki/Base64).
 *
 * The encoder can produce standard or "URL Safe" encoding by avoiding
 * the use of padding and using the '-' and '_'  characters in place of  '+' and '\'.
 *
 * The [encodeString] and [encodeList] methods can optionally insert line breaks (\r \n)
 * after every 64 characters.
 *
 * ## Sample Usage:
 *
 *      var encodedList = Base64Codec.codec.encodeList(myList,useLineSep:true);
 *      var decodedList = Base64Codec.decodeList(myList);
 *
 * This takes inspiration from the Apache Commons and MIG Codecs.
 *
 */


class Base64Codec {
  // true if we should encode using urlsafe characters (no padding, no + or /)
  bool _urlSafe = false;

  /** Mask used to extract 6 bits, used when encoding */
  const int _MASK_6BITS = 0x3f;
  /// Padding character (=)
  const int PAD =  61; // The '=' PAD character used in Base64 padding
  /// CR seperator
  const int CR = 13;
  /// LF seperator
  const int LF = 10;


  const _MAX_LENGTH= 64; // PEM line length

  const _BITS_PER_ENCODED_BYTE = 6;
  const _BYTES_PER_ENCODED_BLOCK = 4;


  // Lookup tables for base64 characters
  static final List<int> _codeList = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'.codeUnits;
  // same as above - but url safe avoids use of + / chars
  static final List<int> _urlSafeCodeList = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'.codeUnits;

  // lookup table - initialized from above
  List<int> _LT;

  /// Create a new [Base64Codec] instance. If [urlSafe] is true
  /// the Codec will encode using URL safe characters (no + /)
  /// and will not use padding (=)
  Base64Codec({bool urlSafe:false}) {
    _urlSafe = urlSafe;
    _LT = _urlSafe ? _urlSafeCodeList : _codeList;
  }


  /*
   * A lookup table that translates Unicode characters drawn from the "Base64 Alphabet" (as specified
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


  // Encodes 3 input bytes in [inList] into 4 base64 bytes in [outList]
  // There *must* be 3 bytes available, and there must be 4 bytes in the outList
  void _encode3to4(List<int> inList, int inPos, List<int> outList, int outPos) {
    // Copy next three bytes into lower 24 bits of int, paying attension to sign.
    // We must mask left shifts to avoid overflow  conversion into a big int
    int i = ((inList[inPos++] & 0xff) << 16) & 0xffffffff;
    i |= ((inList[inPos++] & 0xff) << 8) & 0xffffffff;
    i |= (inList[inPos++] & 0xff);
    outList[outPos++] = _LT[(i >> 18) & _MASK_6BITS];
    outList[outPos++] = _LT[(i >> 12) & _MASK_6BITS];
    outList[outPos++] = _LT[(i >> 6) & _MASK_6BITS];
    outList[outPos++] = _LT[i & _MASK_6BITS];
  }

  // encode the last 1..3 bytes. Pad as needed with '=' if not using urlSafe
  void _encodeRemainder(List <int> inList, int inPos, List<int> outList, int outPos) {
    int left = inList.length - inPos;

    if( left == 0)
      return; // nothing to do.

    int i = ((inList[inPos] & 0xff) << 10) & 0xffffffff;
    if (left == 2 )
      i = i | (((inList[inPos+1] & 0xff) << 2) & 0xffffffff);

    outList[outPos++] = _LT[ i >> 12];
    outList[outPos++] = _LT[( i >> 6) & _MASK_6BITS];
    if( _urlSafe && left == 1)
      return; //
    outList[outPos++] = left == 2 ?  _LT[ i & _MASK_6BITS] : PAD;
    if( _urlSafe )
      return; // done again.
    outList[outPos++] = PAD;
  }

  /// encode [inList] to Base64. If [useLineSep] is true, use line
  /// seperators (\r \n) after every 64 characters.
  /// Returns a [List<int>] of Base64 encoded characters
  List<int> encodeList(List<int> inList, {bool useLineSep : false}) {
    if( inList == null || inList.length == 0)
      return new List();

    int lenEven = (inList.length ~/ 3) * 3;   // Length of even 24-bits.
    int destLen = ((inList.length - 1) ~/ 3 + 1) * 4;
    // calculate number of \r \n line chars that we need to add
    int lineChars = (useLineSep ? (destLen - 1) ~/ _MAX_LENGTH * 2 : 0);
    destLen += lineChars ; // Length of output array

    if( _urlSafe ) {
      // we need to shorten the destination array by the number
      // of pad bytes that will be on the end of this array
      int x = inList.length - lenEven; // bytes left over at the end
      if (x == 1) // one byte
          destLen -= 2; // adjust for 2 null bytes at the end
      if( x == 2) // two bytes
          destLen -= 1; // adjust for single null byte
    }

    var outList = new Uint8List(destLen);
    var outPos = 0;
    var i = 0;

    // encode each set of 3 bytes
    for( int lineChars = 0; i < lenEven; i += 3) {
      _encode3to4(inList,i,outList,outPos);
      outPos += 4;
      if( useLineSep ) {
        lineChars += 4; // we encoded 4 bytes
        if(  lineChars >= _MAX_LENGTH) {
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

  /// Encode String [input] to a base 64 string. If [useLineSep] is true
  /// output \r \n after every 64 characters
  String encodeString(String input,{bool useLineSep: false} ) =>
       new String.fromCharCodes(encodeList(input.codeUnits, useLineSep :useLineSep));

  /// Decode a base64 [input] string and return a string made of the decoded code units
  String decodeString(String input) =>
      new String.fromCharCodes(decodeList(input.codeUnits));

  /**
   * Decode [inList] from Base64 to a list of bytes.
   *
   * Note that Line breaks, white space and padding are ignored by the decoder.
   * This method can handle both "standard" and "URL safe" encoded input. You
   * do not need a special URL Safe instance for *decoding* (only encoding)
   *
   */
  List<int> decodeList(List<int> inList) {
    if( inList == null || inList.length ==0)
      return new List();

    // allocate an array big enough to hold the output.
    // Without scanning the input first it is hard to know how big
    // to make the output array
    // This might be too big, but we will return a subset of this buffer later
    int sz = (inList.length ~/ 4) * 3 + 2;
    var buffer = new Uint8List(sz);
    int bytes = decodeToBuffer(inList,buffer);

    int diff = buffer.length - bytes;
    //print("** Size diff =$diff");
    return new Uint8List.view(buffer.buffer, 0, buffer.length - diff);
  }

  /**
   * Decode [inList] from Base64 into the supplied [buffer].
   * The buffer must be large enough to accept all of the decoded bytes.
   * Returns the number of bytes that were decoded.
   *
   * Use this method if you know you can safely reusue the target buffer
   * and you are sure it is large enough.
   */
  int decodeToBuffer(List<int> inList, List<int> buffer) {
    var outPos =0;
    int ibitWorkArea = 0;
    bool eof = false;
    int modulus = 0;
    for (int i = 0; i < inList.length; i++) {
      var b = inList[i];
      if (b == PAD) {
          eof = true;
          break;
      }
      else {
        if (b >= 0 && b < _DECODE_TABLE.length) {
            var result = _DECODE_TABLE[b];
            if (result >= 0) {
                modulus = (modulus+1) % _BYTES_PER_ENCODED_BLOCK;
                // https://groups.google.com/a/dartlang.org/d/msg/misc/6u9UNNLRjZw/YE9bV99lWyoJ
                ibitWorkArea = ((ibitWorkArea << _BITS_PER_ENCODED_BYTE) & 0xffffffff) | result;
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
    // && o ||
    if (eof || modulus != 0) {
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
    return outPos;
  }

  /**
   * Return a [StreamTransformer]
   * that transform a stream of ints (bytes) to a Base64 encoded stream.
   * Standard encoding will be used (64 bytes on a line,
   * no url safe characters).
   *
   * This will not be as efficient as using the [encodeList] method
   * but is preferable when the input stream is large and
   * you do not wish to pre-allocate buffer space to hold the entire
   * input stream.
   *
   * Sample Usage:
   *
   * [:
   *   someStream.transform(Base64.codec.encodeTransformer).listen( (e) ...)
   * :]
   */

  StreamTransformer get encodeTransformer {
    var buffer = new List<int>(3);
    var encList = new List<int>(4);
    int count =0;
    int lineCount = 0;


    return  new StreamTransformer(
      handleData: (int data,sink) {
        buffer[count++] = data;
        //print("add $data count=$count line=$lineCount");
        // 3 bytes can now be encoded to 4
        if( count == 3) {
          codec._encode3to4(buffer,0,encList,0);
          encList.forEach( (item) => sink.add(item));
          count = 0;
          lineCount += 4; // 4 bytes written to output
          if( lineCount >= _MAX_LENGTH) {
            sink.add(CR);
            sink.add(LF);
            lineCount = 0;
          }
        }
      },
      handleDone: (sink) {
        //print("DONE: count=$count line=$lineCount");
        // any bytes left over?
        if( count != 0) {
          // check line count
          if( lineCount >= _MAX_LENGTH) {
            sink.add(CR);
            sink.add(LF);
          }
          // create just remainder bytes in array
          var buf = buffer.sublist(0,count);
          codec._encodeRemainder(buf,0,encList,0);
          encList.forEach( (item) => sink.add(item));
        }
        sink.close();
      }
    );
  }

  /**
   * Return a [StreamTransformer] that decodes a stream
   * of Base64 bytes to their original byte value.
   *
   * This is not an efficient way of decoding and
   * [decodeList] should be used if possible.
   *
   * Use this when the input stream is large and you do not want to
   * allocate a buffer for the entire contents before decoding.
   *
   * Sample:
   *
   * [:
   *    someStream.transform( Base64Codec.codec.decodeTransformer).listen(...)
   * :]
   */

  StreamTransformer get decodeTransformer {
    var buffer = new List();
    var outBuf = new List(3);

    int count =0;

    return new StreamTransformer(
      handleData: (data,sink) {
        // ignore any bytes that are not in the B64 alphabet
        if( _DECODE_TABLE[data] != -1) {
          buffer.add(data);
          // we know that 4 base64 chars decodes to 3 bytes
          if( ++count >= 4) {
            decodeToBuffer(buffer,outBuf);
            //print("Decode $buffer");
            for(int i=0; i < 3; ++i)
              sink.add(outBuf[i]);
            count =0;
            buffer.clear();
          }
        }
      },
      handleDone: (sink) {

        if( count > 0) { // handle any remaining Base64 chars
          var b = decodeList(buffer);
          //print("DONE: count=$count buf=$buffer b=$b");
          b.forEach( (i) => sink.add(i));
        }
        sink.close();
     });
  }

  /// An instance of a standard [Base64Codec]. The encoding is not url Safe
  static final Base64Codec codec = new Base64Codec(urlSafe:false);
  /// An instance of a URL Safe [Base64Codec]. Will not use padding or + \ chars
  static final Base64Codec urlSafeCodec  = new Base64Codec(urlSafe:true);



}