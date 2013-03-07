/*
 * This is a port (including most of the comments) of the Apache Commons Base64 Codec
 *
 * See http://svn.apache.org/viewvc/commons/proper/codec/trunk/src/main/java/org/apache/commons/codec/binary/Base64.java?view=co
 *
 *
 */

library base64;


import 'dart:math';

part 'base_n_codec.dart';


/**
 * Provides Base64 encoding and decoding as defined by [RFC 2045] <http://www.ietf.org/rfc/rfc2045.txt>
 *
 *
 * This class implements section *6.8. Base64 Content-Transfer-Encoding* from RFC 2045. Multipurpose
 * Internet Mail Extensions (MIME) Part One: Format of Internet Message Bodies by Freed and Borenstein.
 *
 * The class can be parameterized in the following manner with various constructors:
 *
 * * URL-safe mode: Default off.
 * * Line length: Default 76. Line length that aren't multiples of 4 will still essentially end up being multiples of
 *    4 in the encoded data.
 * * Line separator: Default  is CRLF ("\r\n")
 *
 * Since this class operates directly on byte streams, and not character streams, it is hard-coded to only
 * encode/decode character encodings which are compatible with the lower 127 ASCII chart (ISO-8859-1, Windows-1252,
 * UTF-8, etc).
 *
 */
class Base64  extends BaseNCodec {

    /**
     * BASE32 characters are 6 bits in length.
     * They are formed by taking a block of 3 octets to form a 24-bit string,
     * which is converted into 4 BASE64 characters.
     */
    static final int _BITS_PER_ENCODED_BYTE = 6;
    static final int _BYTES_PER_UNENCODED_BLOCK = 3;
    static final int _BYTES_PER_ENCODED_BLOCK = 4;

    /**
     *  MIME chunk size per RFC 2045 section 6.8.
     *
     *
     * The character limit does not count the trailing CRLF, but counts all other characters, including any
     * equal signs.
     *
     * See <http://www.ietf.org/rfc/rfc2045.txt>
     */
    static final int _MIME_CHUNK_SIZE = 76;

    /** Mask used to extract 6 bits, used when encoding */
    static final int _MASK_6BITS = 0x3f;

    /**
     * Chunk separator per RFC 2045 section 2.1.
     *see [RFC 2045 section 2.1] (http://www.ietf.org/rfc/rfc2045.txt)
     */
    static final _CHUNK_SEPARATOR = const ['\r', '\n'];

    List<int> _lineSeparator;


    /**
     * Given a binary [code] in the range of 0 to 63, return
     * the character used to represent it in base64.
     * if [urlSafe] is true, use _ and - instead
     * of + and /
     */
    static int getCode(int code,bool urlSafe) {
      if( code >= 0 && code < 26 ) // A..Z
        return code +65;
      if( code >= 26 && code < 52) // a..z
        return (code -26) + 97;
      if( code >= 52 && code < 62 ) // 0..9
        return (code - 52) + 48;
      if( code == 62)
        return (urlSafe ?  45:43); // - and +
      if( code == 63 )
        return (urlSafe ?  95:47); // _ and /
      throw "code is out of range 0..63 $code";
    }

    // instance method
    int _lookupCode(int code) => getCode(code,_urlSafe);


    // true if we should encode using urlsafe characters
    bool _urlSafe = false;

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
    static final _DECODE_TABLE = const [
            -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
            -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
            -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, 62, -1, 63, 52, 53, 54,
            55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, -1, 0, 1, 2, 3, 4,
            5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23,
            24, 25, -1, -1, -1, -1, 63, -1, 26, 27, 28, 29, 30, 31, 32, 33, 34,
            35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    ];


    // Only one decode table currently; keep for consistency with Base32 code
   List<int> _decodeTable = _DECODE_TABLE;


    /**
     * Convenience variable to help us determine when our buffer is going to run out of room and needs resizing.
     * decodeSize = 3 + lineSeparator.length
     */
    int _decodeSize;

    /**
     * Convenience variable to help us determine when our buffer is going to run out of room and needs resizing.
     * encodeSize = 4 + lineSeparator.length
     */
    int _encodeSize;


    /**
     * Creates a Base64 codec used for decoding (all modes) and encoding in both URL-unsafe and safe mode.
     *
     *
     * Line lengths that aren't multiples of 4 will still essentially end up being multiples of 4 in the encoded data.
     *
     * When decoding all variants are supported.
     *
     *
     * * [lineLength]
     *            Each line of encoded data will be at most of the given length (rounded down to nearest multiple of
     *            4). If lineLength <= 0, then the output will not be divided into lines (chunks). Ignored when
     *            decoding.
     * * [lineSeparator]
     *            Each line of encoded data will end with this sequence of bytes.
     * * [urlSafe]
     *            Instead of emitting '+' and '/' we emit '-' and '_' respectively. urlSafe is only applied to encode
     *            operations. Decoding seamlessly handles both modes.
     *            *Note: no padding is added when using the URL-safe alphabet.*
     */
    Base64(int lineLength, String lineSeparator, this._urlSafe):
      super(_BYTES_PER_UNENCODED_BLOCK,
          _BYTES_PER_ENCODED_BLOCK,
             lineLength,
             lineSeparator == null ? 0 : lineSeparator.length) {

      _encodeSize = _BYTES_PER_ENCODED_BLOCK;

      if (lineSeparator != null) {
          if (lineLength > 0){ // null line-sep forces no chunking rather than throwing IAE
              _encodeSize = _BYTES_PER_ENCODED_BLOCK + lineSeparator.length;
              _lineSeparator = lineSeparator.codeUnits ;
          }
       }
        _decodeSize = _encodeSize - 1;
    }

    /**
     * Creates a new Base64 encoder using Url-safe encoding, default
     * line lengths, and no padding
     */
    Base64.urlSafe():super(_BYTES_PER_UNENCODED_BLOCK,
        _BYTES_PER_ENCODED_BLOCK, 0,0) {
      _encodeSize = _BYTES_PER_ENCODED_BLOCK;
      _decodeSize = _encodeSize - 1;
      _urlSafe = true;
    }

    /**
     * Create a default codec.
     * Used MIME_CHUNKSIZE line lenths, URL unsafe,
     */
    Base64.codec():super(_BYTES_PER_UNENCODED_BLOCK,
        _BYTES_PER_ENCODED_BLOCK, _MIME_CHUNK_SIZE,0) {

      _lineSeparator = _CHUNK_SEPARATOR;
      _encodeSize = _BYTES_PER_ENCODED_BLOCK + _lineSeparator.length;
      _decodeSize = _encodeSize - 1;
      _urlSafe = false;
    }

    /**
     *
     * Encodes all of the provided data, starting at inPos, for inAvail bytes. Must be called at least twice: once with
     * the data to encode, and once with inAvail set to "-1" to alert encoder that EOF has been reached, to flush last
     * remaining bytes (if not multiple of 3).
     *
     * *Note: no padding is added when encoding using the URL-safe alphabet*
     *
     * Thanks to "commons" project in ws.apache.org for the bitwise operations, and general approach.
     * http://svn.apache.org/repos/asf/webservices/commons/trunk/modules/util/
     *
     * [in]
     *             array of binary data to base64 encode.
     * [inPos]
     *            Position to start reading data from.
     * [inAvail]
     *            Amount of bytes available from input for encoding.
     * [context]
     *            the context to be used
     */

    void _encodeList(List<int> inList, int inPos, int inAvail, _Context context) {
        if (context.eof) {
            return;
        }
        // inAvail < 0 is how we're informed of EOF in the underlying data we're
        // encoding.
        if (inAvail < 0) {
            context.eof = true;
            if (0 == context.modulus && _lineLength == 0) {
                return; // no leftovers to process and not using chunking
            }
            var buffer = _ensureBufferSize(_encodeSize, context);
            var savedPos = context.pos;
            switch (context.modulus) { // 0-2
                case 0 : // nothing to do here
                    break;
                case 1 : // 8 bits = 6 + 2
                    // top 6 bits:
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 2) & _MASK_6BITS);
                    // remaining 2:
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea << 4) & _MASK_6BITS);
                    // URL-SAFE skips the padding to further reduce size.
                    if ( ! _urlSafe) {
                        buffer[context.pos++] = PAD;
                        buffer[context.pos++] = PAD;
                    }
                    break;

                case 2 : // 16 bits = 6 + 6 + 4
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 10) & _MASK_6BITS);
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 4) & _MASK_6BITS);
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea << 2) & _MASK_6BITS);
                    // URL-SAFE skips the padding to further reduce size.
                    if ( ! _urlSafe) {
                        buffer[context.pos++] = PAD;
                    }
                    break;
                default:
                    throw "Impossible modulus ${context.modulus}";
            }
            context.currentLinePos += context.pos - savedPos; // keep track of current line position
            // if currentPos == 0 we are at the start of a line, so don't add CRLF
            if (_lineLength > 0 && context.currentLinePos > 0) {
                buffer.setRange(context.pos, _lineSeparator.length, _lineSeparator, 0);
                context.pos += _lineSeparator.length;
            }
        } else {
            for (int i = 0; i < inAvail; i++) {
                var buffer = _ensureBufferSize(_encodeSize, context);
                context.modulus = (context.modulus+1) % _BYTES_PER_UNENCODED_BLOCK;
                int b = inList[inPos++];
                if (b < 0) {
                    b += 256;
                }
                context.ibitWorkArea = (context.ibitWorkArea << 8) + b; //  BITS_PER_BYTE
                if (0 == context.modulus) { // 3 bytes = 24 bits = 4 * 6 bits to extract
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 18) & _MASK_6BITS);
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 12) & _MASK_6BITS);
                    buffer[context.pos++] = _lookupCode((context.ibitWorkArea >> 6) & _MASK_6BITS);
                    buffer[context.pos++] = _lookupCode(context.ibitWorkArea & _MASK_6BITS);
                    context.currentLinePos += _BYTES_PER_ENCODED_BLOCK;
                    if (_lineLength > 0 && _lineLength <= context.currentLinePos) {
                        buffer.setRange(context.pos, _lineSeparator.length, _lineSeparator, 0);
                        context.pos += _lineSeparator.length;
                        context.currentLinePos = 0;
                    }
                }
            }
        }
    }

    /**
     *
     * Decodes all of the provided data, starting at inPos, for inAvail bytes. Should be called at least twice: once
     * with the data to decode, and once with inAvail set to "-1" to alert decoder that EOF has been reached. The "-1"
     * call is not necessary when decoding, but it doesn't hurt, either.
     *
     * Ignores all non-base64 characters. This is how chunked (e.g. 76 character) data is handled, since CR and LF are
     * silently ignored, but has implications for other bytes, too. This method subscribes to the garbage-in,
     * garbage-out philosophy: it will not check the provided data for validity.
     *
     * Thanks to "commons" project in ws.apache.org for the bitwise operations, and general approach.
     * http://svn.apache.org/repos/asf/webservices/commons/trunk/modules/util/
     *
     *
     * [in]
     *            byte[] array of ascii data to base64 decode.
     * [inPos]
     *            Position to start reading data from.
     * [inAvail]
     *            Amount of bytes available from input for encoding.
     * [context]
     *            the context to be used
     */
   _decodeList(List<int> inList, int inPos, final int inAvail, _Context context) {
        if (context.eof) {
            return;
        }
        if (inAvail < 0) {
            context.eof = true;
        }
        for (int i = 0; i < inAvail; i++) {
            var buffer = _ensureBufferSize(_decodeSize, context);
            var b = inList[inPos++];
            if (b == PAD) {
                // We're done.
                context.eof = true;
                break;
            } else {
                if (b >= 0 && b < _DECODE_TABLE.length) {
                    var result = _DECODE_TABLE[b];
                    if (result >= 0) {
                        context.modulus = (context.modulus+1) % _BYTES_PER_ENCODED_BLOCK;
                        context.ibitWorkArea = (context.ibitWorkArea << _BITS_PER_ENCODED_BYTE) + result;
                        if (context.modulus == 0) {
                            buffer[context.pos++] = ((context.ibitWorkArea >> 16) & _MASK_8BITS);
                            buffer[context.pos++] = ((context.ibitWorkArea >> 8) & _MASK_8BITS);
                            buffer[context.pos++] = (context.ibitWorkArea & _MASK_8BITS);
                        }
                    }
                }
            }
        }

        // Two forms of EOF as far as base64 decoder is concerned: actual
        // EOF (-1) and first time '=' character is encountered in stream.
        // This approach makes the '=' padding characters completely optional.
        if (context.eof && context.modulus != 0) {
            var buffer = _ensureBufferSize(_decodeSize, context);

            // We have some spare bits remaining
            // Output all whole multiples of 8 bits and ignore the rest
            switch (context.modulus) {
//              case 0 : // impossible, as excluded above
                case 1 : // 6 bits - ignore entirely
                    // TODO not currently tested; perhaps it is impossible?
                    break;
                case 2 : // 12 bits = 8 + 4
                    context.ibitWorkArea = context.ibitWorkArea >> 4; // dump the extra 4 bits
                    buffer[context.pos++] = ((context.ibitWorkArea) & _MASK_8BITS);
                    break;
                case 3 : // 18 bits = 8 + 8 + 2
                    context.ibitWorkArea = context.ibitWorkArea >> 2; // dump 2 bits
                    buffer[context.pos++] = ((context.ibitWorkArea >> 8) & _MASK_8BITS);
                    buffer[context.pos++] = ((context.ibitWorkArea) & _MASK_8BITS);
                    break;
                default:
                    throw "Impossible modulus ${context.modulus}";
            }
        }
    }

}

