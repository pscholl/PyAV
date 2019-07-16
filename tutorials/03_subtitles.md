% reading closed captions / subtitle from media files

 This is typically used to provide time-keyed, and possibly video annotations for media-files. For example used for machine learning datasets, besides providing translations and hearing aids for media-file. You can read these subtitles with the av.io module as well:

   >>> from tests.common import fate_suite
   >>> from av.io import read
   >>>
   >>> # subfile = fate_suite('sub/madness.srt')
   >>> subfile = '/home/phil/src/ffmpeg/fate-suite/csv/matroska-with-small-single-track-and-subtitle'
   >>> s, info = read(file = subfile)
   >>> s
   [array([[1., 2.],
          [2., 4.],
          [3., 3.]]), array(['NULL', 'abc'], dtype='<U4')]


    >>> subfile = '01_1_E.mkv'
    >>> (s,a), info = read('s:0 a:0', file = subfile)
    >>> a.shape
    (5, 26075)
    >>> s.shape
    (26075,)

    >>> subfile = 'test.mkv'
    >>> (s,a), info = read('s: a:', file = subfile)
    >>> a.shape
    (3, 90000)
    >>> s.shape
    (90000,)

