# Copyright 2008 Micah Richert, Alex Holkner
# Copyright 2012-2013 AVbin Team
#
# This file is part of AVbin.
#
# AVbin is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3 of
# the License, or (at your option) any later version.
#
# AVbin is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#

##  Example use of AVbin.
##
##  Prints out AVbin details, then stream details, then exits.
##
##  ``TODO``: Clean up, comment.

import os, strutils, avbin

proc main() =

  if avbin.init() != AVBIN_RESULT_OK:
    echo "Fatal: Couldn't initialize AVbin"
    return

  # To store command-line flags
  var
    verbose = false # -v, --verbose
    help = false    # -h, --help
    filename = ""   # media file to inspect

  # Process command-line arguments
  for i in 1..paramCount():
    if paramStr(i) in ["-v", "--verbose"]:
      verbose = true
    elif paramStr(i) in ["-h", "--help"]:
      help = true
    elif filename == "":
      filename = paramStr(i)
    else:
      echo "Invalid argument.  Try --help\n"
      return

  # Print help usage and exit, if that's what was selected
  if help:
    echo "Usage: avbin_dump [options] [filename]\n"
    echo "-h, --help     Print this help message."
    echo "-v, --verbose  Run through each packet in the media file and print out some info.\n"
    return

  var info: ptr AVbinInfo = avbin.get_info()

  echo "AVbin $1 (feature version $2) built on $3\n  Repo: $4\n  Commit: $5\n" % [
    $info.versionString,  # $1
    $info.version,        # $2
    $info.buildDate,      # $3
    $info.repo,           # $4
    $info.commit]         # $5

  echo "Backend: $1 $2\n  Repo: $3\n  Commit: $4\n" % [
    $info.backend,              # $1
    $info.backendVersionString, # $2
    $info.repo,                 # $3
    $info.backendCommit]        # $4

  if filename == "":
    echo "If you specify a media file, we will print information about it, for example:\n./avbin_dump some_file.mp3"
    return

  var file: AVbinFile = avbin.openFilename(filename)
  if file == nil:
    echo "Unable to open file", filename
    return

  var fileinfo: AVbinFileInfo
  fileinfo.structureSize = sizeof(fileinfo)

  if avbin.fileInfo(file, addr(fileinfo)) != AVBIN_RESULT_OK:
    return

  echo "#streams ", fileinfo.nStreams
  echo "start time ", fileinfo.startTime
  echo "duration $1 ($2:$3:$4)\n" % [
    $fileinfo.duration,                               # $1
    $(fileinfo.duration div (1000000 * 60 * 60)),     # $2
    $((fileinfo.duration div (1000000 * 60)) mod 60), # $3
    $((fileinfo.duration div 1000000) mod 60)]        # $4

  echo "Title: ", fileinfo.title.join
  echo "Author: ", fileinfo.author.join
  echo "Copyright: ", fileinfo.copyright.join
  echo "Comment: ", fileinfo.comment.join
  echo "Album: ", fileinfo.album.join
  echo "Track: ", fileinfo.track
  echo "Year: ", fileinfo.year
  echo "Genre: ", fileinfo.genre.join

  var
    videoStream, audioStream: AVbinStream
    videoStreamIndex = -1
    audioStreamIndex = -1
    width, height: uint32

  for streamIndex in 0'i32..<fileinfo.nStreams:
    var streamInfo: AVbinStreamInfo8
    streaminfo.structureSize = sizeof(streaminfo)

    discard avbin.streamInfo(file, streamIndex, cast[ptr AVbinStreamInfo](addr(streamInfo)))

    # VIDEO
    if streamInfo.type == AVBIN_STREAM_TYPE_VIDEO:
      echo "video stream at $1, width $2, height $3" % [
        $streamIndex,                     # $1
        $streamInfo.stream.video.width,   # $2
        $streamInfo.stream.video.height]  # $3
      width = streamInfo.stream.video.width
      height = streamInfo.stream.video.height
      videoStreamIndex = streamIndex
      videoStream = avbin.openStream(file, streamIndex)

    # AUDIO
    elif streaminfo.type == AVBIN_STREAM_TYPE_AUDIO:
      echo "audio stream at $1, rate $2, bits $3, chan $4" % [
        $streamIndex,                         # $1
        $streaminfo.stream.audio.sampleRate,  # $2
        $streamInfo.stream.audio.sampleBits,  # $3
        $streamInfo.stream.audio.channels]    # $4
      audioStreamIndex = streamIndex
      audioStream = avbin.openStream(file, streamIndex)

  if not verbose:
    return

  var packet: AVbinPacket
  packet.structureSize = sizeof(packet)

  while avbin.read(file, addr(packet)) == AVBIN_RESULT_OK:

    # VIDEO
    if packet.streamIndex == videoStreamIndex.uint32:
      var videoBuffer: ptr uint8 = cast[ptr uint8](alloc(width*height*3))
      if avbin.decodeVideo(videoStream, packet.data, packet.size, videoBuffer) <= 0:
        echo "could not read video packet"
      else:
        echo "read video frame"

      # do something with videoBuffer

      dealloc(videoBuffer)

    # AUDIO
    if packet.streamIndex.int == audioStreamIndex:
      var
        audioBuffer: array[1024*1024, uint8]
        bytesLeft: int = sizeof(audioBuffer)
        bytesOut = bytesLeft
        bytesRead = 0
        audio_data: ptr uint8 = addr(audioBuffer[0])

    template `+`[T](p: ptr T, off: int): ptr T =
      cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

      bytesRead = avbin.decodeAudio(audioStream, packet.data, packet.size, audioData, addr(bytesOut))
      while bytesRead > 0:
        packet.data += bytesread
        packet.size -= bytesread
        audioData += bytesOut
        bytesLeft -= bytesOut
        bytesOut = bytesLeft

      var nrBytes: int = audioData - audioBuffer

      echo "[$1] read audio packet of size $2 bytes" % [
        packet.timestamp, # $1
        nrBytes]          # $2

      # do something with audioBuffer ... but don't free it since it is a local array

  if video_stream != nil:
    avbin.closeStream(videoStream)

  if audio_stream != nil:
    avbin.closeStream(audioStream)

  avbin.closeFile(file)

main()

