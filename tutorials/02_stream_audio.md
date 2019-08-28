% stream data from a ffmpeg URL

 While reading a file completely into memory is a convenient way to read data, there are situations where you do not want to wait until the data source is closed, or where you do not want to keep the whole file in memory. For example, when streaming live-data from your device, you usually do not want to wait for the recording to stop before processing it's data, or keep the whole recording indefinitely in memory. These are the situations where the streaming API into play.

 Instead of using the 'read' function, we can use the 'input' in pretty much the same way. Only one parameter called 'window' is added. This window specifies the duration of data that is collected before a new block of data is yielded by the iterator. This means, the input is read in blocks, which span a duration of window. The window is specified in milli-seconds. For example to read an audio-file in blocks of one second, you can do:

    >>> from tests.common import fate_suite
    >>> from av.io import input
    >>>
    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')
    >>> numframes = 0
    >>> for stream, in input('a:0', 1000, audiofile):
    ...   numframes += stream.shape[0]
    >>> numframes
    93209

 The default window size is equivalent to 1000ms, so the following calls will yield the sample results as above:

    >>> numframes = 0
    >>> for stream, in input(file = audiofile):
    ...   numframes += stream.shape[0]
    >>> numframes
    93209

 The streaming API is most useful for video data:

    >>> for aud,vid in input(file = fate_suite('mkv/1242-small.mkv')):
    ...    print(vid.shape)
    (11, 1280, 718, 3)
