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
        print(a, b)
