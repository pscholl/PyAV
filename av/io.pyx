"""

  wrapper for the avio library to make reading and writing ffmpeg files
  pythonic and simple to use.

"""

import av, sys, re, numpy as np

def _mapstreams(stringorcallable, streams):
    try:
        return stringorcallable(streams)
    except TypeError:
        return [ elem\
                 for tokenlist in stringorcallable.split(' ')\
                 for elem in _mapselector(tokenlist, streams) ]

def _mapselector(tokenlist, streams):
    x = [ set(_mapspecifier(token, streams))\
          for token in tokenlist.split(',')]
    x = list(set.intersection(*x))

    if len(x) == 0:
        raise Exception("no stream found matching %s" % tokenlist)
    else:
        return x

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
        r'([avsf]):'      : bytype,
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
        self.selected = selected
        self.warned = False
        self.ar = audioresampler

    def __iter__(self):
        def perpts(it):
            """ collect all packets with matching pts fields, and store them
            in a dict() indexed by each stream.
            """
            pts, buf = .0, { k: [] for k in self.selected }

            for packet in it:
                frames = packet.decode()

                #
                # resample audio streams
                #
                if packet.stream.codec.type == 'audio':
                    frames = [ self.ar.resample(f) for f in frames ]

                #
                # check if ready to emit a buffer
                #
                if packet.pts is None:
                    break    # end-of-stream

                elif packet.pts != pts and\
                     all( len(v) for (s,v) in buf.items()\
                          if s.codec.type != 'subtitle'):

                        yield pts, buf
                        pts, buf = packet.pts, { k: [] for k in self.selected }

                #
                # add frames to buffer if any available
                #
                if frames is not None and\
                   len(frames) > 0 and\
                   frames[0] is not None:
                    buf[packet.stream].extend(frames)

            #
            # flush what is left in the buffers
            #
            if any( len(v) for v in buf.values() ):
                yield pts, buf

        self.packets = perpts(self.container)
        return self

    def __next__(self):
        #
        # read as many packets as required to forward the presentation
        # timestamp (pts) beyond what is buffered
        #
        pts, packets = next(self.packets)
        # sys.stderr.write("ftw %s\n" % packets)

        def audio(frames):
            """ concatenate multiple frames of audio date. When in packed format
            unpack to channel first alignment.
            """
            frames = [ f for f in frames if f is not None  ]

            if len(frames) == 0:
                return None

            f2a = lambda f: f.to_ndarray()
            p2u = lambda a,f: a.reshape((len(f.layout.channels), -1))

            return np.concatenate([\
                f2a(frame) if not frame.format.is_packed else\
                p2u(f2a(frame), frame) for frame in frames])

        def subtitle(frames, multiply):
            """ duplicate subtitles to match the global sampling rate given.
            """
            s2s = lambda f: f.ass.split(',')[-1]
            return np.array([s2s(f[0]) for f in frames]*multiply)

        packets.update( (s, audio(p)) \
            for (s,p) in packets.items() if s.codec.type == 'audio')

        # multiply all subtitle to have the same sampling frequency as the first
        # non-subtitle stream

        multiply = [ v for (k,v) in packets.items()\
                     if k.codec.type != 'subtitle' ]

        multiply = multiply[0].shape[-1]\
                   if len(multiply) and multiply[0] is not None\
                   else 1

        packets.update( (s, subtitle(p, multiply))\
            for (s,p) in packets.items() if s.codec.type == 'subtitle')

        # sys.stderr.write("wtf %s\n" % packets)
        return packets.values()

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
                 streams=lambda x: [s for s in x],
                 file=None,
                 rate=None,
                 secs=None,
                 info=None):

        if rate is not None:
            rate = int(rate)

        audioresampler = av.audio.resampler.AudioResampler(None, None, rate)

        # XXX rate can be None but secs not!

        container = av.open(file or sys.argv[1])
        selected = _mapstreams(streams, container.streams)
        demuxed = demuxedarr(container, selected, audioresampler)
        #windowed = windowarr(demuxed, rate, secs)

        if info is not None:
            for s in selected:
                info.append(s)

        return demuxed

class AvIOComplete(AvIO):
    """ returns the whole input file/stream
    """

    def __call__(self,
                 streams=lambda x: [s for s in x],
                 file=None,
                 rate=None):
        """
        read a multi-media file into memory completly.

        Args:
            streams: optional string or callable to specify streams, default is to read all
            file: string or open file object to be read
            rate: resample all streams to rate, defaults to read streams at rate given from file

        Returns:
            a tuple containing (streams, info) lists, the streams list contains
            all list as numpy arrays, while info holds a metadata information
            object for each stream.
        """

        info = []
        buf = AvIO.__call__(self, streams,file,rate,info=info)
        buf = map(list, zip(*buf))
        buf = map(np.hstack, buf)
        buf = list(buf)

        return buf, info

input = AvIO()
read = AvIOComplete()

if __name__ == '__main__':
    for a,b in input("a:27 a:26"):
        print(a, b)
