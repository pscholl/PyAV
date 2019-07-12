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

    def __packets2frames(self, ps):
        def aud(ps):
            try:
                frames = [ self.ar.resample(f) for p in ps for f in p.decode() ]
                frames = [ f for f in frames if f is not None ]
                return None if len(frames) == 0 else frames
            except:
                return None

        def vid(ps):
            return None if not all(p.stream.codec.type=='video' for p in ps) else\
                   [ f for p in ps for f in p.decode() ]

        def sub(ps):
            return None if not all(p.stream.codec.type=='subtitle' for p in ps) else\
                   [ f for p in ps for f in p.decode() ]

        return None if len(ps)==0 else\
               aud(ps) or vid(ps) or sub(ps)


    def __iter__(self):
        def perpts(it):
            """ collect all packets with matching pts fields, and store them
            in a dict() indexed by each stream.
            """
            pts, buf = .0, { k: [] for k in self.selected }

            def toframes():
                frames = { s: self.__packets2frames(ps)\
                           for (s,ps) in buf.items() }
                valid = all( b is not None for (s,b) in frames.items()\
                             if s.codec.type != 'subtitle' )

                # sys.stderr.write("etf %s %s\n" % (valid, frames))
                return frames if valid else None

            for packet in it:
                #
                # check for end-of-stream
                #
                if packet.pts is None:
                    break

                #
                # check if ready to emit
                #
                elif packet.pts != pts:
                    frames = toframes()
                    if frames:
                        yield pts, frames

                    pts, buf = packet.pts,\
                    { s: [p for p in ps if p.pts+p.duration > packet.pts]\
                      for (s,ps) in buf.items() }

                #
                # add the current packet to buf
                #
                buf[packet.stream].append(packet)

            #
            # flush buffer at the end
            #
            frames = toframes()
            if frames:
                yield pts, frames

        self.frames = perpts(self.container)
        return self

    def __next__(self):
        #
        # read as many packets as required to forward the presentation
        # timestamp (pts) beyond what is buffered
        #
        pts, frames = next(self.frames)

        def aud(frames):
            """ concatenate multiple frames of audio date. When in packed format
            unpack to channel first alignment.
            """
            if len(frames) == 0:
                return None

            f2a = lambda f: f.to_ndarray()
            p2u = lambda a,f: a.reshape((len(f.layout.channels), -1))

            return np.concatenate([\
                f2a(frame) if not frame.format.is_packed else\
                p2u(f2a(frame), frame) for frame in frames])

        def vid(frames):
            return None

        def sub(frames):
            """ duplicate subtitles to match the global sampling rate given.
            """
            s2s = lambda f: f.ass.split(',')[-1]
            sub = (s2s(f[0]) for f in frames)
            return np.array( list(sub) ) if frames and len(frames) else None

        frames.update( (s, aud(p) if s.codec.type == 'audio' else\
                           vid(p) if s.codec.type == 'video' else\
                           sub(p) if s.codec.type == 'subtitle' else\
                           None) \
                        for (s,p) in frames.items() )

        # sys.stderr.write("wtf %s\n" % frames)
        return frames.values()

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
