
/*
 * Port of BaseNCodec from Apache commons
 *
 * See
 * http://svn.apache.org/viewvc/commons/proper/codec/trunk/src/main/java/org/apache/commons/codec/binary/BaseNCodec.java?revision=1435550&view=co
 */

part of base64;


/**
 * holds state of encoding/decoding
 */
class _Context {

  /**
   * Place holder for the bytes we're dealing with for our based logic.
   * Bitwise operations store and extract the encoding or decoding from this variable.
   */
  int ibitWorkArea = 0;

  /**
   * Place holder for the bytes we're dealing with for our based logic.
   * Bitwise operations store and extract the encoding or decoding from this variable.
   */
  int lbitWorkArea = 0;

  /**
   * Buffer for streaming.
   */
  List<int> buffer;

  /**
   * Position where next character should be written in the buffer.
   */
  int pos;

  /**
   * Position where next character should be read from the buffer.
   */
  int readPos;

  /**
   * Boolean flag to indicate the EOF has been reached. Once EOF has been reached, this object becomes useless,
   * and must be thrown away.
   */
  bool eof = false;

  /**
   * Variable tracks how many characters have been written to the current line. Only used when encoding. We use
   * it to make sure each encoded line never goes beyond lineLength (if lineLength > 0).
   */
  int currentLinePos = 0;

  /**
   * Writes to the buffer only occur after every 3/5 reads when encoding, and every 4/8 reads when decoding. This
   * variable helps track that.
   */
  int modulus =0;
}



/**
 * Abstract superclass for Base-N encoders and decoders.
 *
 *
 */
abstract class BaseNCodec  {
    /**
     * EOF
     */
    static final int EOF = -1;

    /**
     * PEM chunk size per RFC 1421 section 4.3.2.4.
     *

     * The character limit does not count the trailing CRLF, but counts all other characters, including any
     * equal signs.
     *
     * see <http://tools.ietf.org/html/rfc1421>
     */
    static final int PEM_CHUNK_SIZE = 64;

    static final int _DEFAULT_BUFFER_RESIZE_FACTOR = 2;

    /**
     * Defines the default buffer size - currently
     * - must be large enough for at least one encoded block+separator
     *
     * TODO: Does this really need to be this big?
     */
    static final int _DEFAULT_BUFFER_SIZE = 8192;

    /** Mask used to extract 8 bits, used in decoding bytes */
    final int _MASK_8BITS = 0xff;

    /**
     * Byte used to pad output.
     */
    static final int PAD_DEFAULT = '='.codeUnits[0]; // Allow static access to default

    final int PAD = PAD_DEFAULT; // instance variable just in case it needs to vary later

    /** Number of bytes in each full block of unencoded data, e.g. 4 for Base64 and 5 for Base32 */
    int _unencodedBlockSize;

    /** Number of bytes in each full block of encoded data, e.g. 3 for Base64 and 8 for Base32 */
    int _encodedBlockSize;

    /**
     * Chunksize for encoding. Not used when decoding.
     * A value of zero or less implies no chunking of the encoded data.
     * Rounded down to nearest multiple of encodedBlockSize.
     */
    int _lineLength;

    /**
     * Size of chunk separator. Not used unless {@link #lineLength} > 0.
     */
    int _chunkSeparatorLength;

    /**
     * Create a codec for base N encoding/decoding.
     *
     * Note [_lineLength] is rounded down to the nearest multiple of [_encodedBlockSize]
     * If [_chunkSeparatorLength] is zero, then chunking is disabled.
     *
     * [_unencodedBlockSize] the size of an unencoded block (e.g. Base64 = 3)
     * [_encodedBlockSize] the size of an encoded block (e.g. Base64 = 4)
     * lineLength if > 0, use chunking with a length [_lineLength]
     * [_chunkSeparatorLength] the chunk separator length, if relevant
     */
    BaseNCodec(this._unencodedBlockSize, this._encodedBlockSize,
                         this._lineLength, this._chunkSeparatorLength) {

        var useChunking = _lineLength > 0 && _chunkSeparatorLength > 0;
        _lineLength = useChunking ? (_lineLength ~/ _encodedBlockSize) * _encodedBlockSize : 0;
    }

    /**
     * Returns true if this object has buffered data for reading.
     */
    bool _hasData(_Context context) => context.buffer != null;

    /**
     * Returns the amount of buffered data available for reading.
     *
     *  context the context to be used
     * return The amount of buffered data available for reading.
     */
    int _available(_Context context) =>
        context.buffer != null ? context.pos - context.readPos : 0;


    /**
     * Get the default buffer size. Can be overridden.
     *
     * @return {@link #DEFAULT_BUFFER_SIZE}
     */
    int _getDefaultBufferSize() => _DEFAULT_BUFFER_SIZE;

    /**
     * Increases our buffer by the {@link #DEFAULT_BUFFER_RESIZE_FACTOR}.
     *  context the context to be used
     */
    List<int> _resizeBuffer(_Context context) {
        if (context.buffer == null) {
            context.buffer = new List<int>.fixedLength(_getDefaultBufferSize());
            context.pos = 0;
            context.readPos = 0;
        } else {
            var b = new List<int>.fixedLength(context.buffer.length * _DEFAULT_BUFFER_RESIZE_FACTOR);
            b.setRange(0, context.buffer.length, context.buffer, 0);
            context.buffer = b;
        }
        return context.buffer;
    }

    /**
     * Ensure that the buffer has room for [size] bytes
     *
     */
    List<int> _ensureBufferSize(int size, _Context context){
        if ((context.buffer == null) || (context.buffer.length < context.pos + size)){
            return _resizeBuffer(context);
        }
        return context.buffer;
    }

    /**
     * Extracts buffered data into the provided List, starting at position bPos, up to a maximum of bAvail
     * bytes. Returns how many bytes were actually extracted.

     *  [b]
     *            List to extract the buffered data into.
     *  bPos
     *            position in byte[] array to start extraction at.
     *  bAvail
     *            amount of bytes we're allowed to extract. We may extract fewer (if fewer are available).
     *  context
     *            the context to be used
     * returns The number of bytes successfully extracted into the provided List
     */
    int _readResults(List<int> b, int bPos, int bAvail, _Context context) {
        if (context.buffer != null) {
            var len = min(_available(context), bAvail);
            b.setRange(bPos, len, context.buffer, context.readPos);
            context.readPos += len;
            if (context.readPos >= context.pos) {
                context.buffer = null; // so hasData() will return false, and this method can return -1
            }
            return len;
        }
        return context.eof ? EOF : 0;
    }


    // white space characters
    static List<int> _whiteSp = ' \n\r\t'.codeUnits;
    /**
     * Checks if a byte value is whitespace or not.
     * Whitespace is taken to mean: space, tab, CR, LF
     *  byteToCheck
     *            the byte to check
     * @return true if byte is whitespace, false otherwise
     */
    static bool _isWhiteSpace(int byteToCheck) => _whiteSp.contains(byteToCheck);

    // abstract method subclass must implement to decode a list
    void _decodeList(List<int> inList, int inPos, final int inAvail, _Context context);

    /**
     * Decodes a list containing characters in the Base-N alphabet.
     *
     *  [data] A list containing Base-N character data
     * returns a list containing binary data
     */
    List<int> decode(List<int> data) {
        if (data == null || data.length == 0) {
            return data;
        }
        var context = new _Context();
        _decodeList(data, 0, data.length, context);
        _decodeList(data, 0, EOF, context); // Notify decoder of EOF.
        var result = new List<int>.fixedLength(context.pos);
        _readResults(result, 0, result.length, context);
        return result;
    }


    // abstract method. Subclass to provide implementation
    void _encodeList(List<int> inList, int inPos, int inAvail, _Context context);

    /**
     * Encodes a list of binary data into a List containing characters in the alphabet.
     *
     *  [data]
     *            a list containing binary data
     * returns A list containing only the base N alphabetic character data
     */

    List<int> encode(List<int> data) {
        if (data == null || data.length == 0) {
            return data;
        }
        var context = new _Context();
        _encodeList(data, 0, data.length, context);
        _encodeList(data, 0, EOF, context); // Notify encoder of EOF.
        var buf = new List<int>.fixedLength(context.pos - context.readPos);
        _readResults(buf, 0, buf.length, context);
        return buf;
    }

    /**
     * Encode a String of characters [s] into a BaseN encoded string
     *
     */
    String encodeString(String s) => new String.fromCharCodes(encode(s.codeUnits));

    /**
     * Decode a string of Base N encoded characters [s] into a String.
     */
    String decodeString(String s) => new String.fromCharCodes(decode(s.codeUnits));


    /**
     * Calculates the amount of space needed to encode the supplied array.
     *
     *  [data] - List which will later be encoded
     *
     */
    int getEncodedLength(List<int> data) {
        // Calculate non-chunked size - rounded up to allow for padding

        var len = ((data.length + _unencodedBlockSize-1)  ~/ _unencodedBlockSize) * _encodedBlockSize;
        if (_lineLength > 0) { // We're using chunking
            // Round up to nearest multiple
            len += ((len + _lineLength-1) ~/ _lineLength) * _chunkSeparatorLength;
        }
        return len;
    }
}

