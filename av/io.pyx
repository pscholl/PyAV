import sys
from av import open
from sys import argv
from itertools import groupby
from collections import OrderedDict
from numpy import concatenate as concat, stack, empty, ndarray, asarray
from math import inf, floor, ceil, isinf
from re import split, match

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
    def bytag(needle, tag, streams):
        sel = [x for x in streams if\
               needle in x.metadata.get(tag, str(getattr(x,tag,''))).lower()]

        if len(sel) == 0:
            raise Exception("no stream found matchin %s" % token)

        return sel

    #
    # select, probably overlapping streams, by the specifications given
    # in the single token
    #
    def _mapspecifier(token, streams):
        byname = lambda m,s: bytag(m, 'NAME', s)
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


def input(streams=lambda x: list(x), window=1000, file=None):
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
    def perstep(container, selected):
        pts, buf  = 0, []

        for packet in container:
            #
            # one of the streams is done
            #
            if packet.pts is None:
                break

            # for p in buf:
            #     sys.stderr.write("%s %s  " % (p.pts, p.duration))
            # sys.stderr.write("\n")

            #
            # check if the packet is below the presentation time
            # or if the buffer needs to be evicted
            #
            if packet.pts < pts + window:
                buf.append(packet)

            else:
                #
                # yield the buffer and remove all packets that
                # are not valid anymore, and forward pts
                #
                yield pts, [p for p in buf if p.pts < pts + window]

                pts += window
                buf = [p for p in buf\
                       if p.pts + p.duration > pts and\
                          p.stream.codec.type == 'subtitle']
                buf.append(packet)

        #
        # flush the buffer at last
        #
        while len(buf):
            pts += window
            buf = [p for p in buf\
                   if p.pts + p.duration > pts and\
                      p.stream.codec.type == 'subtitle']

            yield pts, [p for p in buf if p.pts < pts + window]

    def aud(s, packets):
        #
        # extract and concatenate all data frames for these audio streams
        # XXX this is the place for re-sampling
        #
        frames = [f.to_ndarray().T if not f.format.is_packed else\
                  f.to_ndarray().T.reshape((-1, len(f.layout.channels)))\
                  for p in packets for f in p.decode()]
        return avarray(concat(frames), info=s)

    def vid(s, packets):
        #
        # stack all single images of a video streams
        #
        frames = [f.to_ndarray(format='rgb24').swapaxes(0,1) for p in packets for f in p.decode()]
        return avarray(stack(frames), info=s)

    def sub(packets, pts):
        #
        # only works for ass/text subtitle at the moment, extract only
        # beginning and end time, and add the current text label to it
        # prior to emission
        # XXX support bitmap subs and additional optional subtitle attr
        # XXX subtitles are a subclass of tuples then
        #
        content = lambda s:\
            s.ass.split(',')[-1].strip() if s.type == b'ass' else\
            s.text                       if s.type == b'text' else\
            None
        beg = lambda p:\
            p.pts - pts if p.pts > pts else 0
        end = lambda p:\
            p.pts + p.duration - pts if p.pts + p.duration < pts + window else window

        frames = [ (beg(p), end(p), content(s))\
                   for p in packets for ss in p.decode() for s in ss]
        return frames


    #
    # here we actually start reading data from the container
    #
    container = open(file or argv[1])
    selected  = mapstreams(streams, container.streams)
    container = container.demux(list(selected))

    for pts, buf in perstep(container, selected):
        buf = sorted(buf, key=lambda p: p.stream.index)
        #
        # we need to keep the order in which the stream were selected,
        # hence we create a dict with all keys, and then add a default
        # empty list for each prior to inserting the current frames
        #
        out = { k: [] for k in selected }
        out.update( (s, list(v))\
                    for (s,v) in groupby(buf, lambda p: p.stream) )
        out.update( (s, aud(s,p)    if s.codec.type == 'audio' else\
                        vid(s,p)    if s.codec.type == 'video' else\
                        sub(p, pts) if s.codec.type == 'subtitle' else\
                        None) for (s,p) in out.items() )

        sys.stderr.write("%f %s %s\n" % (pts, buf, out))
        yield list(out.values())

def read(streams=lambda x: list(x), file=None):
    return list(input(streams, inf, file))[0]

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
        scl /= 1000.

    for (a,b,label) in labels:
        a, b = floor(a*scl), ceil(b*scl)
        out[a:b] = label

        #if b > dim:
        #    raise Exception("end of annotation beyond data dimension, wrong rate?")

    return out

if __name__ == '__main__':
    for a,b in read("a:27 a:26", window=1000):
        print(a, b)
