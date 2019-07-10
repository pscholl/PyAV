% read audio-stream from a multi-media file

 Hey there, welcome to the tutorial section for the python-avio library. In this tutorial you will learn how to read audio data from a multi-media file, and how to convert to a python numpy array for further processing.

 In python-avio a simple wrapper for the ffmpeg library suite is provided, the turorials will concentrate on a pythonic wrapper for pyav, which will allow (simplified) access to the data in a multi-media file. There are two versions of this wrapper. One that loads the selected streams of the file completly into memory before returning results. This is called the read() method. The other one returns an iterator, which allows you load only parts of the file into memory before discarding it again. The size of those parts can be defined. But first let's look at loading a file completly into memory. For this we first import a data-source (ffmpeg's fate-suit in this case), and the read() method:

    >>> from tests.common import fate_suite
    >>> from av.io import read
    >>>
    >>> audiofile = fate_suite('audio-reference/chorusnoise_2ch_44kHz_s16.wav')

 Now to load a file, the easiest way is to specify just the file to load and all stream will be loaded and returned with a metadata object. Since a multi-media file can contain multiple streams, a tuple of two lists is returned:

    >>> streams, info = read(file=audiofile)
    >>> len(info), info[0].rate, info[0].channels, info[0].format
    (1, 44100, 2, <av.AudioFormat s16>)

 The stream list contains the data in the audio-streams as a numpy array, i.e.:

    >>> print( streams[0].shape )
    (2, 93209)

 The audio stream is actually 2.11 seconds long, hence the second dimension of the array is the sample number, while the first dimension is the channel of the audio-file. If you know what kind of file you are reading you can use python's tuple extraction syntax to make data reading a little bit more obvious:

    >>> (audio, *_), info = read(file=audiofile)
    >>> print(audio.shape)
    (2, 93209)

 which extracts the first list element in the returned tuple, while ignoring all subsequent elements if there are any. This can happen when your file contains multiple streams for example. Let's imagine that you like to extract audio data at a pre-determined rate, or have all streams sampled at the same rate. This requires a re-sampling of the audio/data stream to this rate, and pyav can do that for you. Just add a parameter to the read() method:

    >>> (audio, *_), info = read(file=audiofile, rate=50)
    >>> print(audio.shape)
    (2, 90)

 Now, you have the data re-sampled to 50Hz (the lowest rate is 1Hz), so only 90 samples are returned. Luckily we already know that our input file only contains audio-data, and no subtitle neither video streams. Otherwise we might read streams that we do not need later on, increasing the overhead for reading data. We can however specify which streams should be read, and we have multiple options for that. The first one is to supply a callable, that will receive the list of streams that are in the file and must return a list of streams to be read. For example only reading audio streams:

    >>> audioonly = lambda streams: [s for s in streams if s.type == 'audio']
    >>> (audio, *_), info = read(file=audiofile, streams=audioonly)
    >>> print(audio.shape)
    (2, 93209)

 Instead of doing this with a callable, a number of shortcuts can also be used. For example, to access via type and stream number, we can use 'a:n', 'v:n', 's:n', and 'd:n'. This will select either the n-th audio, video, subtitle or data stream. You can leave 'n' to select all streams of a certain type. For example all audio streams:

    >>> videofile = fate_suite('mkv/test7_cut.mkv')
    >>> (audio, *_), info = read(file=videofile, streams='a:')
    >>> print(audio.shape)
    (2, 146432)

Or with a number, and you can mix multiple selectors by separating them with a space:

    >>> (audio, *_), info = read(file=videofile, streams='a:0 a:')

You can also select them by the tags specified for each stream, or if they carry a NAME tag, just a string is enough to match'em:

    >>> videofile = fate_suite('mkv/codec_delay_opus.mkv')
    >>> (audio, *_), info = read(file=videofile, streams='ENCODER:libopus')

The above example matroska file contains one stream:

ffprobe ./fate-suite/mkv/codec_delay_opus.mkv 
Input #0, matroska,webm, from './fate-suite/mkv/codec_delay_opus.mkv':
  Metadata:
    title           : lavftest
    ENCODER         : Lavf57.44.100
  Duration: 00:00:01.03, start: -0.007000, bitrate: 74 kb/s
    Stream #0:0: Audio: opus, 48000 Hz, mono, fltp (default)
    Metadata:
      ENCODER         : Lavc57.50.100 libopus
      DURATION        : 00:00:01.026000000

and as you can see from the ffprobe output, the first stream contains two tags (ENCODER and DURATION). With the above syntax we can match the content of the tags. So since "ENCODER         : Lavc57.50.100 libopus" contains libopus, the 'ENCODER:libopus' string selects this stream. One additional way is to match a 'NAME' tag. Streams that contain such a tag, can be selected simply by supplying a substring that is contained in the NAME tag. For example, read(streams='abc acc') would match all streams, where the NAME tag's value contains either 'abc' or 'acc'.

These are all the ways to select streams from your containers. As file input you can use any URL that ffmpeg would handle, for example you also read from a TCP stream with '''read(file="tcp:192.168.0.1:2222")'''. See the [ffmpeg protocol](https://www.ffmpeg.org/ffmpeg-protocols.html) for more details.

