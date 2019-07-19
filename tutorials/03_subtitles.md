% reading closed captions / subtitle from media files

 This is typically used to provide time-keyed, and possibly video annotations for media-files. For example used for machine learning datasets, besides providing translations and hearing aids for media-files. You can read these subtitles with the av.io module as well:

    >>> from tests.common import fate_suite
    >>> from av.io import read, annotate
    >>>
    >>> # subfile = fate_suite('sub/madness.srt')
    >>> subfile = '/home/phil/src/ffmpeg/fate-suite/csv/matroska-with-small-single-track-and-subtitle'
    >>> streams = read(file = subfile)
    >>> streams
    [avarray([[1., 2., 3.],
             [2., 4., 3.]]), [(0, 20, 'NULL'), (20, 40, 'abc')]]

 As you could guess, the subtitles are returned as tuples consisting of a start time, end time and a string that represents the caption at that timespan. Time is expreseed in milli-seconds (actually this is the time_base definition of libav, so this can change). To correlate the labels with a video or audio stream, you will need to figure the sampling rate of respective stream. This can be done via the 'info' attribute of a video/audio stream and can be used to scale the timestamps:

    >>> aud, sub = streams
    >>> aud.info.sample_rate
    50
    >>> [ (int(a * aud.info.sample_rate / 1000),\
    ...    int(b * aud.info.sample_rate / 1000),\
    ...    text) for (a,b,text) in sub ]
    [(0, 1, 'NULL'), (1, 2, 'abc')]

 After scaling, the start end end time can be used to index the audio stream. This will leave the subtitle list sparsely sampled. To resample the subtitle array on another stream's discrete time, you can use the 'annotate' method provided by av.io:

    >>> annotate(aud, sub)
    array(['NULL', 'abc'], dtype=object)
    >>> aud.shape
    (2, 3)
    >>> annotate(aud, sub).shape
    (2,)


 This will transform the subtitle array to a list of strings, with the same dimesion as the stream provided as the first argument to the annotate method. For example, when generating the labels for a machine-learning task this method can be used to generate the target based on a data input stream.

