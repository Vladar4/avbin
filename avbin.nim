#  avbin.h
#  Copyright 2007-2008 Alex Holkner
#  Copyright 2011-2013 AVbin Team
#
#  This file is part of AVbin.
#
#  AVbin is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as
#  published by the Free Software Foundation; either version 3 of
#  the License, or (at your option) any later version.
#
#  AVbin is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this program.  If not, see
#  <http://www.gnu.org/licenses/>.
#

##  =====
##  AVbin
##  =====
##
##  AVbin is a binary release of a cross-platform, thin wrapper around Libav’s
##  video and audio decoding library, providing long-term binary compatibility
##  for applications and languages that need it.
##
##  AVbin procedures and objects
##  ----------------------------
##
##  To open a file and prepare it for decoding, the general procedure is:
##
##  - (Optionally) call ``avbin.have_feature()`` to check which features are
##    available.  This is only needed if your application may be deployed in
##    environments with older versions of AVbin than you are developing to.
##
##  - Initialize AVbin by calling ``avbin.init_options()``
##
##  - Open a sound or video file using ``avbin.open_filename()``
##
##  - Retrieve details of the file using ``avbin.file_info()``.  The resulting
##    ``AVbinFileInfo`` structure includes details such as:
##
##    - Start time and duration
##
##    - Number of audio and video streams
##
##    - Metadata such as title, artist, etc.
##
##  - Examine details of each stream using ``avbin.stream_info()``, passing
##    in each stream index as an integer from `0` to ``n_streams``.
##
##    For video streams, the ``AVbinStreamInfo`` structure includes:
##
##    - Video width and height, in pixels
##
##    - Pixel aspect ratio, expressed as a fraction
##
##    For audio streams, the structure includes:
##
##    - Sample rate, in Hz
##
##    - Bits per sample
##
##    - Channels (monoaural, stereo, or multichannel surround)
##
##  - For each stream you intend to decode, call ``avbin.open_stream()``.
##
##  When all information has been determined and the streams are open, you can
##  proceed to read and decode the file:
##
##  - Call ``avbin.read()`` to read a packet of data from the file.
##
##  - Examine the resulting ``AVbinPacket`` structure for the ``stream_index``,
##    which indicates how the packet should be decoded.  If the stream is
##    not one that you have opened, you can discard the packet and continue
##    with step 1 again.
##
##  - To decode an audio packet, repeatedly pass the data within the packet
##    to ``avbin.decode_audio()``, until there is no data left to consume or an
##    error is returned.
##
##  - To decode a video packet, pass the data within the packet to
##    ``avbin.decode_video()``, which will decode a single image in RGB format.
##
##  - Synchronise audio and video data by observing the
##    ``AVbinPacket.timestamp`` member.
##
##  When decoding is complete, call ``avbin.close_stream()`` on each stream and
##  ``avbin.close_file()`` on the open file.


when defined windows:
  const AVBIN_LIB = "avbin(|64).dll"
elif defined macosx:
  const AVBIN_LIB = "libavbin(|10).dylib"
else:
  const AVBIN_LIB = "libavbin.so(|.10)"


type
  AVbinResult* {.size: sizeof(cint).} = enum  ##  \
    ##  Error-checked procedure result.
    AVBIN_RESULT_ERROR  = -1
    AVBIN_RESULT_OK     = 0

  AVbinStreamType* {.size: sizeof(cint).} = enum  ##  \
    ##  Type of a stream; currently only video and audio streams are supported.
    AVBIN_STREAM_TYPE_UNKNOWN = 0
    AVBIN_STREAM_TYPE_VIDEO   = 1
    AVBIN_STREAM_TYPE_AUDIO   = 2

  AVbinSampleFormat* {.size: sizeof(cint).} = enum  ##  \
    ##  The sample format for audio data.
    AVBIN_SAMPLE_FORMAT_U8      = 0 ##  Unsigned byte
    AVBIN_SAMPLE_FORMAT_S16     = 1 ##  Signed 16-bit integer
    AVBIN_SAMPLE_FORMAT_UNUSED  = 2 ##  Signed 24-bit integer  \
      ##  `AVBIN_SAMPLE_FORMAT_S24` removed upstream.
      ##  Removed here in AVbin 11
    AVBIN_SAMPLE_FORMAT_S32     = 3 ##  Signed 32-bit integer
    AVBIN_SAMPLE_FORMAT_FLOAT   = 4 ##  32-bit IEEE floating-point

  AVbinLogLevel* {.size: sizeof(cint).} = enum  ##  \
    ##  Threshold of logging verbosity.
    AVBIN_LOG_QUIET = -8
    AVBIN_LOG_PANIC = 0
    AVBIN_LOG_FATAL = 8
    AVBIN_LOG_ERROR = 16
    AVBIN_LOG_WARNING = 24
    AVBIN_LOG_INFO = 32
    AVBIN_LOG_VERBOSE = 40
    AVBIN_LOG_DEBUG = 48

  AVbinFile* = pointer    ##  Opaque open file handle.

  AVbinStream* = pointer  ##  Opaque open stream handle.

  AVbinTimestamp* = int64 ##  Point in time, or a time range; \
    ##  given in microseconds.

  AVbinFileInfo* = object ##  File details. \
    ##  The info struct is filled in by ``avbin.get_file_info()``.
    structureSize*: csize ##  Size of this structure, in bytes. \
      ##  This must be filled in by the application before passing to AVbin.
    nStreams*:  int32  ## Number of streams contained in the file.
    startTime*: AVbinTimestamp  ##  Starting time of all streams.
    duration*:  AVbinTimestamp   ##  Duration of the file. \
      ##  Does not include the time given in ``startTime``.
    title*:     array[512, char]    ##  File metadata \
      ##  Strings are NUL-terminated and may be omitted
      ##  (the first character `\0`) if the file does not contain appropriate
      ##  information. The encoding of the strings is unspecified.
    author*:    array[512, char]
    copyright*: array[512, char]
    comment*:   array[512, char]
    album*:     array[512, char]
    year*:      int32
    track*:     int32
    genre*:     array[32, char]

  AVbinStreamVideo* = object
    width*: uint32  ##  Width of the video image, in pixels.  \
      ##  This is the width of actual video data, and is not necessarily
      ##  the size the video is to be displayed at (see ``sampleAspectNum``).
    height*: uint32 ##  Height of the video image, in pixels.
    sampleAspectNum*: uint32
    sampleAspectDen*: uint32  ##  Aspect-ratio of each pixel. \
      ##  The aspect is given by dividing
      ##  ``sampleAspectNum`` by ``sampleAspectDen``.
    frameRateDen*: uint32
    frameRateNum*: uint32     ##  Frame rate, in frames per second. \
      ##  The frame rate is given by  dividing
      ##  ``frameRateNum by ``frameRateDen``.
      ##
      ##  ``Version 8`` requires ``frame_rate`` feature.
      ##
      ##  ``REMOVED IN VERSION 11`` - see note on ``avbin.have_feature()``.

  AVbinStreamAudio* = object
    sampleFormat*: AVbinSampleFormat  ##  Data type of audio samples.
    sampleRate*: uint32 ##  Number of samples per second, in Hz.
    sampleBits*: uint32 ##  Number of bits per sample; typically `8` or `16`.
    channels*: uint32   ##  Number of interleaved audio channels. \\
      ##  Typically `1` for monoaural, `2` for stereo. Higher channel numbers
      ##  are used for surround sound, however AVbin does not currently provide
      ##  a way to access the arrangement of these channels.

  AVbinStreamObj* = object {.union.}
    video*: AVbinStreamVideo
    audio*: AVbinStreamAudio

  AVbinStreamInfo* = object ##  Stream details. \
    ##  A stream is a single audio track or video.
    ##  Most audio files contain one audio stream.
    ##  Most video files contain one audio stream and one video stream.
    ##  More than one audio stream may indicate the presence of multiple
    ##  languages which can be selected (however at this time AVbin
    ##  does not provide language information).
    structureSize*: csize ##  Size of this structure, in bytes. \
      ##  This must be filled in by the  application before passing to AVbin.
    `type`*: AVbinStreamType  ##  The type of stream; either audio or video.
    stream*: AVbinStreamObj

  AVbinStreamVideo8* = object
    width*: uint32  ##  Width of the video image, in pixels.  \
      ##  This is the width of actual video data, and is not necessarily
      ##  the size the video is to be displayed at (see ``sampleAspectNum``).
    height*: uint32 ##  Height of the video image, in pixels.
    sampleAspectNum*: uint32
    sampleAspectDen*: uint32  ##  Aspect-ratio of each pixel.
      ##  The aspect is given by dividing
      ##  ``sampleAspectNum`` by ``sampleAspectDen``.
    frameRateNum*: uint32
    frameRateDen*: uint32 ##  Frame rate, in frames per second. \
      ##  The frame rate is given by dividing
      ##  ``frameRateNum`` by ``frameRateDen``.
      ##
      ##  ``Version 8`` requires ``frameRate`` extension.

  AVbinStreamAudio8* = object
    sampleFormat*: AVbinSampleFormat  ## Data type of audio samples.
    sampleRate*: uint32 ##  Number of samples per second, in Hz.
    sampleBits*: uint32 ##  Number of bits per sample; typically `8` or `16`.
    channels*:   uint32 ##  Number of interleaved audio channels.
      ##  Typically `1` for monoaural, `2` for stereo. Higher channel numbers
      ##  are used for surround sound, however AVbin does not currently provide
      ##  a way to access the arrangement of these channels.

  AVbinStreamObj8* = object {.union.}
    video*: AVbinStreamVideo8
    audio*: AVbinStreamAudio8

  AVbinStreamInfo8* = object  ##  Stream details, version 8.  \
    ##  A stream is a single audio track or video.
    ##  Most audio files contain one audio stream.
    ##  Most video files contain one audio stream and one video stream.
    ##  More than one audio stream may indicate the presence of multiple
    ##  languages which can be selected (however at this time
    ##  AVbin does not provide language information).
    structureSize*: csize ##  Size of this structure, in bytes. \
      ##  This must be filled in by the  application before passing to AVbin.
    `type`*: AVbinStreamType  ##  The type of stream; either audio or video.
    stream*: AVbinStreamObj8

  AVbinPacket* = object ##  A single packet of stream data. \\
    ##  The structure size must be initialised before passing
    ##  to ``avbin.read()``. The data will point to a block of memory
    ##  allocated by AVbin -- you must not free it.
    ##  The data will be valid until the next time you call ``avbin.read()``,
    ##  or until the file is closed.
    structureSize*: csize ##  Size of this structure, in bytes. \
      ##  This must be filled in by the application before passing to AVbin.
    timestamp*: AVbinTimestamp  ##  The time at which this packet is to be \
      ##  played. This can be used to synchronise audio and video data.
    streamIndex*: uint32  ##  The stream this packet contains data for.
    data*: ptr uint8
    size*: csize

  AVbinInfo* = object ##  Information about the AVbin library.  \
    ##  See ``avbin.get_info()``
    structureSize*: csize ## Size of this structure, in bytes.
      ##  This will be filled in for you by ``avbin.get_info()`` so that you
      ##  can determine which version of this struct  you have received.
      ##  For example:
      ##
      ##  .. code-block:: nim
      ##    var info: ptr AVbinInfo = avbin.get_info()
      ##    if info.structureSize == sizeof(AVbinInfo)
      ##    # You are safe to access the members of an AVbinInfo...
      ##
    version*: int32  ##  AVbin version as an integer.  \
      ##  This value is the same as returned by the ``avbin.get_version()``
      ##  procedure.  Consider using ``versionString`` instead.
    versionString*: cstring ##  AVbin version string, \
      ##  including pre-release information, i.e. "10-beta1".
    buildDate*: cstring ##  When the library was built, \
      ##  in strftime format "%Y-%m-%d %H:%M:%S %z"
    repo*: cstring      ##  URL to the AVbin repository used.
    commit*: cstring    ##  The commit of the AVbin repository used.
    backend*: cstring   ##  Which backend we are using: "libav" or "ffmpeg"
    backendVersionString*: cstring  ##  The version string  \
      ##  of the most recent tag of the backend.
      ##
      ##  ``Note:`` There may be custom patches *on top* of the backend version.
    backendRepo*: cstring ##  URL to the backend repository \
      ##  used for this release.
    backendCommit*: cstring ##  The commit hash of the backend repo \
      ##  used for the backend.

  AVbinOptions* = object  ##  Initialization Options
    structureSize*: csize ##  Size of this structure, in bytes. \
      ##  This must be filled in by the  application before passing to AVbin.
    threadCount*: int32   ##  Number of threads to attempt to use.  \
      ##  Using the recommended ``threadCount`` of `0` means try to detect
      ##  the number of CPU cores and set threads to (num cores + 1).
      ##  A ``threadCount`` of `1` or a negative number means single threaded.
      ##  Any other number will result in an attempt to set that many threads.

  AVbinLogCallback* = proc(
      module: cstring; level: AVbinLogLevel; message: cstring) {.cdecl.}  ##  \
    ##  Callback for log information.
    ##
    ##  ``module``  The name of the module where this message originated
    ##
    ##  ``level``   The log verbosity level of this message
    ##
    ##  ``message`` The formatted message.
    ##  The message may or may not contain newline characters.


# Procedures

# Information about AVbin

proc getVersion*(): int32 {.
    cdecl, importc: "avbin_get_version", dynlib: AVBIN_LIB.}
  ##  Get the linked version of AVbin.
  ##
  ##  Version numbers are always integer, there are no "minor" or "patch"
  ##  revisions. All AVbin versions are backward and forward compatible,
  ##  modulo the required feature set.

proc getInfo*(): ptr AVbinInfo {.
    cdecl, importc: "avbin_get_info", dynlib: AVBIN_LIB.}
  ##  Get information about the linked version of AVbin.
  ##
  ##  See the AVbinInfo definition.

proc getFFmpegRevision*(): int32 {.deprecated,
    cdecl, importc: "avbin_get_ffmpeg_revision", dynlib: AVBIN_LIB.}
  ##  Get the SVN revision of FFmpeg.
  ##
  ##  This is built into AVbin as it is built.
  ##
  ##  ``DEPRECATED:``
  ##  Use ``avbin.getLibavCommit()`` or ``avbin.getLibavVersion()`` instead.
  ##
  ##  This always returns `0` now that we use Libav from Git.
  ##  This procedure will be removed in AVbin 12.

proc getAudioBufferSize*(): csize {.deprecated,
    cdecl, importc: "avbin_get_audio_buffer_size", dynlib: AVBIN_LIB.}
  ##  Get the minimum audio buffer size, in bytes.
  ##
  ##  ``DEPRECATED:``
  ##  Why is this even here?  It just returns the number `192000`.
  ##  It has been removed upstream, so we'll remove it as well some time soon.

proc haveFeature*(feature: cstring): int32 {.
    cdecl, importc: "avbin_have_feature", dynlib: AVBIN_LIB.}
  ##  Determine if AVbin includes a requested feature.
  ##
  ##  When future versions of AVbin include more functionality, that
  ##  functionality can be tested for by calling this procedure.  The following
  ##  features can be tested for:
  ##  - "frame_rate" - ``AVbinStreamInfo8``, ``frameRate`` variables.
  ##  - "options" - ``avbin.initOptions()``, ``AVbinOptions`` (multi-threading)
  ##  - "info" - ``avbin.getInfo()``, ``AVbinInfo``
  ##
  ##  ``NOTE:`` The "frame_rate" feature was available in versions 9 and 10,
  ##  but removed in version 11.  Populating ``rFrameRate`` was considered
  ##  an unreliable hack upstream and removed. If you try to access it in the
  ##  upstream library, it is always {`0`, `0`}.  Perhaps we can find
  ##  a different source of frame rate and re-enable this feature in the future.
  ##
  ##  ``Return`` `1` The feature is present, or `0` otherwise.

# Global AVbin procedures

proc init*(): AVbinResult {.
    cdecl, importc: "avbin_init", dynlib: AVBIN_LIB.}
  ##  One of the ``avbin.init*`` procedures must be called
  ##  before opening a file to initialize AVbin.
  ##  Check the return value for success before continuing.
  ##
  ##  Initialize AVbin with basic features.
  ##  Consider instead ``avbin.initOptions()``

proc initOptions*(options: ptr AVbinOptions): AVbinResult {.
    cdecl, importc: "avbin_init_options", dynlib: AVBIN_LIB.}
  ##  One of the ``avbin.init*`` procedures must be called
  ##  before opening a file to initialize AVbin.
  ##  Check the return value for success before continuing.
  ##
  ##  Initialize AVbin with ``options``.
  ##
  ##  ``options``  If ``nil``, use defaults.
  ##  Otherwise create and populate an instance of ``AVbinOptions`` to supply.

proc setLogLevel*(level: AVbinLogLevel): AVbinResult {.
    cdecl, importc: "avbin_set_log_level", dynlib: AVBIN_LIB.}
  ##  Set the log level verbosity.

proc setLogCallback*(callback: AVbinLogCallback): AVbinResult {.
    cdecl, importc: "avbin_set_log_callback", dynlib: AVBIN_LIB.}
  ##  Set a custom log ``callback``.
  ##  By default, log messages are printed to standard error.
  ##  Providing a ``nil`` callback restores this default handler.

# File handling procedures

proc openFilename*(filename: cstring): AVbinFile {.
    cdecl, importc: "avbin_open_filename", dynlib: AVBIN_LIB.}
  ##  Open a media file given its ``filename``.
  ##
  ##  ``Return`` ``nil`` if the file could not be opened,
  ##  or is not of a recognised file format.

proc openFilenameWithFormat*(filename: cstring;
  format: cstring): AVbinFile {.
    cdecl, importc: "avbin_open_filename_with_format", dynlib: AVBIN_LIB.}
  ##  Open a media file given its ``filename`` and ``format``.
  ##
  ##  ``Return`` ``nil`` if the file could not be opened,
  ##  or is not of a recognised file format.

proc closeFile*(file: AVbinFile) {.
    cdecl, importc: "avbin_close_file", dynlib: AVBIN_LIB.}
  ##  Close a media file.

proc seekFile*(file: AVbinFile; timestamp: AVbinTimestamp): AVbinResult {.
    cdecl, importc: "avbin_seek_file", dynlib: AVBIN_LIB.}
  ##  Seek to a timestamp within a file.
  ##
  ##  For video files, the first keyframe before the requested ``timestamp``
  ##  will be seeked to.  For audio files, the first audio packet before the
  ##  requested ``timestamp`` is used.

proc fileInfo*(file: AVbinFile; info: ptr AVbinFileInfo): AVbinResult {.
    cdecl, importc: "avbin_file_info", dynlib: AVBIN_LIB.}
  ##  Get information about the opened file.
  ##
  ##  The ``info`` struct must be allocated by the application and have its
  ##  ``structureSize`` member filled in correctly.  On return, the structure
  ##  will be filled with file details.

# Stream procedures

proc streamInfo*(file: AVbinFile;
  streamIndex: int32; info: ptr AVbinStreamInfo): AVbinResult {.
    cdecl, importc: "avbin_stream_info", dynlib: AVBIN_LIB.}
  ##  Get information about a stream within the file.
  ##
  ##  The info struct must be allocated by the application and have its
  ##  ``structureSize`` member filled in correctly.  On return, the structure
  ##  will be filled with stream details.
  ##
  ##  Ensure that ``streamIndex`` is less than ``nStreams``
  ##  given in the file info.
  ##
  ##  ``file``        The file to examine.
  ##
  ##  ``streamIndex`` The number of the stream within the file.
  ##
  ##  ``info``        Returned stream information.

proc openStream*(file: AVbinFile; streamIndex: int32): AVbinStream {.
    cdecl, importc: "avbin_open_stream", dynlib: AVBIN_LIB.}
  ##  Open a stream for decoding.
  ##
  ##  If you intend to decode audio or video from a file, you must open the
  ##  stream first.  The returned opaque handle should be passed to the relevant
  ##  decode procedure when a packet for that stream is read.
  ##
  ##  ``Return`` pointer to the ``AVbinStream``,
  ##  or ``nil`` if there are any problems.

proc closeStream*(stream: AVbinStream) {.
    cdecl, importc: "avbin_close_stream", dynlib: AVBIN_LIB.}
  ##  Close a file stream.

# Reading and decoding procedures

proc read*(file: AVbinFile; packet: ptr AVbinPacket): AVbinResult {.
    cdecl, importc: "avbin_read", dynlib: AVBIN_LIB.}
  ##  Read a packet from the file.
  ##
  ##  The packet struct must be allocated by the application and have its
  ##  structure_size member filled in correctly. On return, the structure
  ##  will be filled with a packet of data. The actual data pointer within
  ##  the packet must not be freed, and is valid until the next call to
  ##  ``avbin.read()``.
  ##
  ##  Applications should examine the packet's stream index to match it with
  ##  an appropriate open stream handle, or discard it if none match.
  ##  The packet data can then be passed to the relevant decode procedure.

proc decodeAudio*(stream: AVbinStream;
  dataIn: ptr uint8; sizeIn: csize;
  dataOut: ptr uint8; sizeOut: ptr cint): int32 {.
    cdecl, importc: "avbin_decode_audio", dynlib: AVBIN_LIB.}
  ##  Decode some audio data.
  ##
  ##  You must ensure that ``dataOut`` is at least as big as the minimum audio
  ##  buffer size (see ``avbin.getAudioBufferSize()``).
  ##
  ##  ``stream``  The stream to decode.
  ##
  ##  ``dataIn``  Incoming data, as read from a packet.
  ##
  ##  ``sizeIn``  Size of dataIn, in bytes.
  ##
  ##  ``dataOut`` Decoded audio data buffer, provided by application.
  ##
  ##  ``sizeOut`` Number of bytes of ``dataOut`` used.
  ##
  ##  ``Return`` the number of bytes of ``dataIn`` actually used, or `-1` if
  ##  there was an error.
  ##  You should call this procedure repeatedly as long as the return value
  ##  is greater than `0`.

proc decodeVideo*(stream: AVbinStream;
  dataIn: ptr uint8;
  sizeIn: csize; dataOut: ptr uint8): int32 {.
    cdecl, importc: "avbin_decode_video", dynlib: AVBIN_LIB.}
  ##  Decode a video frame image.
  ##
  ##  The size of ``dataOut`` must be large enough to hold the entire image.
  ##  This is width * height * 3 (images are always in 8-bit RGB format).
  ##
  ##  ``stream``  The stream to decode.
  ##
  ##  ``dataIn``  Incoming data, as read from a packet.
  ##
  ##  ``sizeIn``  Size of ``dataIn``, in bytes.
  ##
  ##  ``dataOut`` Decoded image data.
  ##
  ##  ``Return`` the number of bytes of ``dataIn`` actually used.
  ##  Any remaining bytes can be discarded, or `-1` if there was an error

