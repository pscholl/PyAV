<<<<<<< HEAD
import sys
from av import open, AudioResampler
from sys import argv
from itertools import groupby
from collections import OrderedDict
from numpy import concatenate as concat, stack, empty, ndarray, asarray
from math import inf, floor, ceil, isinf
from re import split, match
from fractions import Fraction as frac

class avarray(ndarray):
    """ array with metadata from the libav container, i.e. sample-rate etc.,
    which is stored in the 'info' field
    """
    def __new__(cls, array, dtype=None, order=None, info=None):
        obj = asarray(array, dtype=dtype, order=order).view(cls)
        obj.info = info
        return obj

    def __array_finalize__(self, obj):
        if obj is None: return
        self.info = getattr(obj, 'info', None)

def mapstreams(strorfun, streams):
    """ select stream with a string specifier or a callable that filters
    streams to include the wanted ones.

    Args:
        strorfun: see the read() function for specifications
        streams:  a list of stream specifications from libav

    Returns:
        a filtered list of streams
    """
    #
    # select by name and throw exception if no stream is found
    #
    def bytag(tag, needle, streams):
        get = lambda x: x.metadata.get(tag, str(getattr(x,tag,''))).lower()
        sel = [x for x in streams if needle in get(x)]

        if len(sel) == 0:
            raise Exception("no stream found matching %s" % token)

        return sel

    #
    # select, probably overlapping streams, by the specifications given
    # in the single token
    #
    def _mapspecifier(token, streams):
        byname = lambda m,s: bytag('NAME', m, s)
        bytype = lambda t,s:\
                s.audio     if t=='a' else\
                s.video     if t=='v' else\
                s.subtitles if t=='s' else\
                s.data      if t=='d' else []
        bynumber = lambda t,n,s:\
                bytype(t,s) if n=='' else\
                [bytype(t,s)[int(n)]]

        selector = {
            r'([avsd]):(\d+)' : bynumber,
            r'([avsf]):'      : bytype,
            r'(\w+):(\w+)'    : bytag,
            r'(\w+)'          : byname, }

        for pattern, fun in selector.items():
            m = match(pattern, token)
            if m:
                streams = fun(*m.groups(), streams)
                return streams

        return []

    try:
        return strorfun(streams)

    except TypeError:
        return list(OrderedDict.fromkeys([ elem\
                 for token in split(r'(?<!\\) ', strorfun)\
                 for elem  in _mapspecifier(token, streams) ]))

def input(streams=lambda x: list(x), window=1000, rate=None, file=None):
    """ reads a multimedia file with ffmpeg/libav and returns blocks of
    for each stream in a demultiplexed way.

    Args:
        streams: optional stream or callable to select streams to be read,
                 default is to read all stream. Streams can be specified in
                 four ways with a selection string:
                 * by type and number (e.g. 'a:0' for the first audio
                   stream)
                 * just by type (e.g. 'v:' for all video streams)
                 * by a named tag (e.g. 'ENCODER:abc' to match all stream with
                   an ENCODER tag which contains abc)
                 * by the NAME tag (e.g. 'abc' matches all streams with a NAME
                   tag which contains abc)
                 multple string selectors can be combined by separating them
                 with a space, e.g. 'a:0 s:' select the first audio-stream, and
                 all contained subtitle streams.
        window: defaults to 1000ms, and will read until the EOF is reached.
                If any number is given, the method will yield a block of data
                whenever 'window' milli-seconds of data were read.
        rate: an integer [1-n] giving the audio-rate in Hz, on which all streams
              should be resampled to. Defaults to None, which select the rate in
              which each stream is stored in.
        file: optional string which specifies the input to be read, can be
              anything that libav/ffmpeg can read including, for example,
              tcp/udp/rtmp network streams, any file, or even pipes. For a
              complete list, see the
              [ffmpeg protocols](https://ffmpeg.org/ffmpeg-protocols.html)
              documentation.

    Returns:
        a tuple containing (streams, streaminfo) list, where the streams lists
        contains the data of each selected stream (it's a list of numpy
        arrays), and streaminfo is a list of meta-data information about the
        respective stream.
    """
    TIMEBASE = frac(1,1000)
    window *= TIMEBASE

    def perstep(container, selected):
        pts, buf = 0 * TIMEBASE, []
        for packet in container:
            #
            # one of the streams is done
            #
            if packet.pts is None:
                break

            packet_pts = packet.pts * packet.time_base

            #
            # this happens when streams of a container are encoded with too
            # much gaps between streams. This yields packets being decoded
            # after the pts has already been moved forward by another stream.
            #
            if packet_pts < pts:
                sys.stderr.write(\
                "WARN: file is encoded with asynchronous streams, streams are "+\
                "out of sync, re-encode with ffmpeg -max_interleave_delta 0\n")

            # sys.stderr.write("%s \n" % (packet.time_base))
            # sys.stderr.write("%s (%s) " % (pts, window))
            # for p in buf:
            #     sys.stderr.write("%s\n" % str(p))
            #     sys.stderr.write("%s: %s %s  " % (p.stream, p.pts * p.time_base, p.duration * p.time_base))
            # sys.stderr.write("\n")
            # sys.stderr.write("\n")

            #
            # check if the packet is below the presentation time
            # or if the buffer needs to be evicted
            #
            if packet_pts > pts + window:
                yield pts, buf
                pts, buf = pts+window, []

            buf.append(packet)

        #
        # flush the buffer at last
        #
        if len(buf):
            yield pts, buf

    #
    # initialize the audio-resampler, if required
    # and do a few sanity checks
    #
    resample = AudioResampler(rate=rate).resample

    if rate is not None and rate < 1:
        raise Exception("audio-rate must be larger than 1")

    #if window is not inf:
    #    check if sample rates are dividable by window
    #    if rate is not None

    def aud(s, packets, rest=None):
        #
        # extract and concatenate all data frames for these audio streams,
        # make sure to flush the resampler with resample(None).
        #
        # For audio-only: libav returns a frame that may contain more samples
        # than what the user specified in with window, hence we split the
        # resulting array here again.
        #
        frames = [resample(f) for p in packets for f in p.decode()] +\
                 [resample(None)]
        frames = [f.to_ndarray().T if not f.format.is_packed else\
                  f.to_ndarray().T.reshape((-1, len(f.layout.channels)))\
                  for f in frames if f is not None]

        if rest is not None:
            frames[0:0] = [rest]

        return avarray(concat(frames) if len(frames) else [], info=s)

    def vid(s, packets):
        #
        # stack all single images of a video streams
        #
        frames = [f.to_ndarray(format='rgb24').swapaxes(0,1)\
                  for p in packets for f in p.decode()]
        return avarray(stack(frames) if len(frames) else [], info=s)

    def sub(packets, pts, rest=None):
        #
        # only works for ass/text subtitle at the moment, extract only
        # start and end time, and text.
        # XXX support bitmap subs and additional optional subtitle attr
        # XXX subtitles should be a subclass of tuples then
        #
        content = lambda s:\
            ",".join(s.ass.split(',')[9:]).strip() if s.type == b'ass' else\
            s.text                                 if s.type == b'text' else\
            None
        beg = lambda p:  p.pts * p.time_base - pts
        end = lambda p: (p.pts + p.duration) * p.time_base - pts

        frames = [ (int(beg(p)/TIMEBASE), int(end(p)/TIMEBASE), content(s))\
                   for p in packets for ss in p.decode() for s in ss]

        if rest is not None:
            #
            # This is not very nice, but it removes all outdated subtitle frames
            # from the emission queue
            #
            rest = [ (b-window, e-window, t) for (b,e,t) in rest\
                     if e-window > 0 ]
            frames[0:0] = [rest]

        return frames


    #
    # here we actually start reading data from the container
    #
    container = open(file or argv[1])
    selected  = mapstreams(streams, container.streams)
    container = container.demux(list(selected))

    #
    # we create a buffer for each stream, that is filled at each
    # window step, with the decoded frames, 
    #
    out  = { s: None for s in selected }
    amax = { s: None               if isinf(window) else\
                int(window*rate)   if rate is not None else\
                int(window*s.rate) for s in out.keys() }

    for pts, buf in perstep(container, selected):
        #
        # make sure that groupby is working as expected (it works like unix' uniq)
        #
        buf = sorted(buf, key=lambda p: p.stream.index)

        out.update( (s,\
            aud(s,p, out[s])   if s.codec.type == 'audio' else\
            sub(p,pts, out[s]) if s.codec.type == 'subtitle' else\
            vid(s,p)           if s.codec.type == 'video' else\
            None)  for (s,p) in groupby(buf, lambda p: p.stream) )

        #
        # we need to yield in the same order as the stream selection input,
        # and make sure that not more than window-size is yielded. Only
        # audio and subtitle can contain data valid after pts+window.
        #
        yield [ out[s][:amax[s]] if s.codec.type == 'audio' else\
                out[s]           for s in selected ]

        #
        # now evict everything that was yielded, and became invalid in this
        # step.
        #
        out.update( (s,\
            out[s][amax[s]:]   if s.codec.type == 'audio' else\
            out[s]             if s.codec.type == 'subtitle' else\
            None               if s.codec.type == 'video' else\
            None)  for (s,p) in groupby(buf, lambda p: p.stream) )


def read(streams=lambda x: list(x), rate=None, file=None):
    return list(input(streams, inf, rate, file))[0]

def annotate(frames, labels, rate=None):
    """ this is a helper function to convert from a time-centric view of
    subtitle tuples, i.e. (beg, end, caption) where beg and end are timestamps in
    milli-second and caption is a string, to a time-discrete view, i.e. an array
    in which each entry designates a value for a clearly defined duration (one
    period of the sampling rate).

    Args:
     frames: an array, of which the first dimension will be taken to generate an
             array of labels of the same length.

     labels: a list of tuples (beg, end, label) that will be convrted to a
             discrete-time view, beg and end are timestamp in milli-seconds,
             relative to the first sample in the frames array.

     rate: an optional argument, if not specified frames.info.sample_rate will
           be used (which is added by the read() and input() method). Sepcifies
           the rate to convert to in Hz.

    Returns:
     an array of size nx1 where n is equal to the first dimension of the frames
     array. Each entry of the retunerd array will be equal to the caption/label
     that was active at that time, i.e. taking any index i in the returned
     array, beg <= i*rate*1000 < end iff the value at index i is equal to any
     label in the labels array.
    """
    dim = frames.shape[0]
    out = empty((dim,), dtype=object); out[:] = 'NULL'

    try: # assume timebase to be 1/1000
        scl = rate or frames.info.sample_rate
    except:
        scl = rate or frames.info.framerate
    finally:
        scl *= frames.info.time_base

    for (a,b,label) in labels:
        a, b = floor(a*scl), ceil(b*scl)
        out[a:b] = label

        #if b > dim:
        #    raise Exception("end of annotation beyond data dimension, wrong rate?")

    return out

if __name__ == '__main__':
    for a,b in read("a:27 a:26", window=1000):
=======
"""

  wrapper for the avio library to make reading and writing ffmpeg files
  pythonic and simple to use.

"""

import av, sys, re, numpy as np

def _mapstreams(string, streams):
    return [ _mapstream(tokenlist, streams)\
             for tokenlist in string.split(' ')]

def _mapstream(tokenlist, streams):
    x = [ set(_mapspecifier(token, streams))\
          for token in tokenlist.split(',')]
    x = list(set.intersection(*x))

    if len(x) == 1:
        return x[0]
    elif len(x) > 1:
        raise Exception("too many streams found matching %s: %s" % (tokenlist, x))
    else:
        raise Exception("no stream found matching %s" % tokenlist)

def _mapspecifier(token, streams):
    byname = lambda m,s: [x for x in s if\
            m in x.metadata.get('NAME', '')]
    bytype = lambda t,s:\
            s.audio     if t=='a' else\
            s.video     if t=='v' else\
            s.subtitles if t=='s' else\
            s.data      if t=='d' else []
    bynumber = lambda t,n,s:\
            bytype(t,s) if n=='' else\
            [bytype(t,s)[int(n)]]
    bynamedtag = lambda k,v,s: [x for x in s if\
            v in x.metadata.get(k, str(getattr(x, k, '')))]

    selector = {
        r'([avsd]):(\d+)' : bynumber,
        r'(\w+):(\w+)'    : bynamedtag,
        r'(\w+)'          : byname, }

    for pattern, fun in selector.items():
        match = re.match(pattern, token)
        if match:
            streams = fun(*match.groups(), streams)
            return streams

    return []

class demuxedarr:
    """ iterate multiple streams in synchronized fashion, return
    when a complete video, audio, subtitle or data plane has been
    read, returning copies of all other streams.
    """
    def __init__(self, container, selected, audioresampler):
        self.container = container.demux(selected)
        self.buffer = {s:None for s in selected}
        self.ar = audioresampler

    def __iter__(self):
        return self

    def __doemit(self, type):
        values = [v for (k,v) in self.buffer.items() if isinstance(k, type)]
        keys = [k for (k,v) in self.buffer.items() if isinstance(k, type)]

        if all([v is not None for v in values]):
            for s in keys:
                self.buffer[s] = None
            return values

        return None

    def __next__(self):
        for packet in self.container:
            frames = packet.decode()

            if len(frames) == 0:
                raise StopIteration()

            if len(frames) > 1:
                raise Exception("more than one frame per packet is not supported")

            if self.buffer[packet.stream] is not None:
                raise Exception("stream decoded twice without emitting, do selected streams have the same sampling rate?")

            frames[0].pts = None
            frame = self.ar.resample(frames[0])
            #frame = frames[0]

            if frame is None:
                continue

            self.buffer[packet.stream] = frame.to_nd_array()
            audio = self.__doemit(av.audio.stream.AudioStream)

            if audio: return audio

class windowarr:
    """ Iterates over frames, and stacks them together to a larger time-window
    block.
    """
    def __init__(self, frames, rate, secs):
        self.frames = frames
        self.multiplier = secs * rate

        if self.multiplier - int(self.multiplier):
            raise Exception("window must be dividable by rate")

        self.multiplier = int(self.multiplier)

    def __iter__(self):
        return self

    def __next__(self):
        frame = next(self.frames)
        n, window = frame[0].shape[1], next(self.frames)

        while n < self.multiplier:
            n += frame[0].shape[1]
            window.extend(frame)

        dimens = len(frame)
        window = [ np.hstack(window[i::dimens]) for i in range(dimens) ]

        return window

class AvIO(object):
    def __init__(self):
        pass

    def __call__(self,
                 streams=None,
                 file=None,
                 rate=None,
                 secs=None):

        if rate is not None:
            rate = int(rate)

        audioresampler = av.audio.resampler.AudioResampler(None, None, rate)

        # XXX rate can be None but secs not!

        container = av.open(file or sys.argv[1])
        selected = _mapstreams(streams, container.streams)
        demuxed = demuxedarr(container, selected, audioresampler)
        windowed = windowarr(demuxed, rate, secs)

        return windowed

input = AvIO()

if __name__ == '__main__':
    for a,b in input("a:27 a:26"):
>>>>>>> add the first test in a tutorial session
        print(a, b)
