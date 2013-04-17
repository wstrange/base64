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

  const int _DEFAULT_BUFFER_RESIZE_FACTOR = 2;

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

  /**
   * Returns true if this object has buffered data for reading.
   */
  bool _hasData() => buffer != null;

  /**
   * Returns the amount of buffered data available for reading.
  *
   *  context the context to be used
   * return The amount of buffered data available for reading.
   */
  int _available() => buffer != null ? pos - readPos : 0;

  // get the results from the context buffer. Returns a new list
  List<int> getResults() {
    var b =buffer.sublist(readPos,pos);
    buffer = null;
    return b;
  }


  /**
   * Increases our buffer by the {@link #DEFAULT_BUFFER_RESIZE_FACTOR}.
   *
   */
  List<int> resizeBuffer(int bufsize) {
    if (buffer == null) {
      buffer = new Uint8List(bufsize);
      pos = 0;
      readPos = 0;
    } else {
      var b = new Uint8List(buffer.length * _DEFAULT_BUFFER_RESIZE_FACTOR);
      b.setRange(0, buffer.length, buffer, 0);
      buffer = b;
    }
    return buffer;
  }

  /**
   * Ensure that the buffer has room for [size] bytes
  *
   */
  List<int> ensureBufferSize(int size){
    if ((buffer == null) || (buffer.length < (pos + size))){
      return resizeBuffer(size);
    }
    return buffer;
  }

  // add a single byte value to the buffer. Advance the pointer
  addToBuffer(int value) => buffer[pos++] = value;

  void addListToBuffer(List<int> l){
    buffer.setRange(pos, pos + l.length,l);
    pos += l.length;
  }


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
    const int EOF = -1;

    /**
     * PEM chunk size per RFC 1421 section 4.3.2.4.
     *

     * The character limit does not count the trailing CRLF, but counts all other characters, including any
     * equal signs.
     *
     * see <http://tools.ietf.org/html/rfc1421>
     */
    const int PEM_CHUNK_SIZE = 64;
    /**
     * Defines the default buffer size - currently
     * - must be large enough for at least one encoded block+separator
     *
     * TODO: Does this really need to be this big?
     */
    const int _DEFAULT_BUFFER_SIZE = 8192;

    /** Mask used to extract 8 bits, used in decoding bytes */
    const int _MASK_8BITS = 0xff;

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
     * Get the default buffer size. Can be overridden.
     *
     * @return {@link #DEFAULT_BUFFER_SIZE}
     */
    int _getDefaultBufferSize() => _DEFAULT_BUFFER_SIZE;

    // white space characters
    static final List<int> _whiteSp = ' \n\r\t'.codeUnits;
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
        return context.getResults();
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
        return context.getResults();
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

