% reading closed captions / subtitle from media files

 This is typically used to provide time-keyed, and possibly video annotations for media-files. For example used for machine learning datasets, besides providing translations and hearing aids for media-file. You can read these subtitles with the av.io module as well:

    >>> from tests.common import fate_suite
    >>> from av.io import read
    >>>
    >>> # subfile = fate_suite('sub/madness.srt')
    >>> subfile = '/home/phil/src/ffmpeg-old/fate-suite/csv/matroska-with-small-single-track-and-subtitle'
    >>> s, info = read(file = subfile)
    >>> s
    [array([[1., 2.],
           [2., 4.],
           [3., 3.]]), array(['NULL\r\n', 'abc\r\n'], dtype='<U6')]


