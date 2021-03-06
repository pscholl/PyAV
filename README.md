PyAV
====

This is a branch of the pyav library, with a simplified version to read multi-media file. Its main purpose is for reading multi-modal Activity Recognition datasets, like the [wetlab](http://earth.informatik.uni-freiburg.de/datasets/ubicomp2015) with is encoded in multiple matroska files. You can download an example file [here](http://earth.informatik.uni-freiburg.de/uploads/104.mkv), which contains video, audio and subtitle streams with a name tag. The video contains secondary evidence, audio streams encode sensor data (acceleration in this example), and the subtitle stream contains the ground-truth data. You can read, for example, read the sensor and groundtruth data with:

```
from av.io import read, annotate

acc, groundtruth = read('a: s:', file='104.mkv')
print(acc.info, acc.shape, len(gt))
av.AudioStream #1 flac at 50Hz, 3.0, s16 at 0x7f3ec930e440 (122880, 3)

# getting from a list of labels to an array of labels in-sync with sensordata
labels = annotate(acc, groundtruth)
print(labels.shape)
(122880, )
```

More example are in the [tutorials/](tutorials/) directory.

Introduction to pyav
--------------------

[![Travis Build Status][travis-badge]][travis] [![AppVeyor Build Status][appveyor-badge]][appveyor] \
[![GitHub Test Status][github-tests-badge]][github-tests] \

This is a branch of the pyav library, with a simplified version to read multi-media file. Its main purpose is for reading multi-modal Activity Recognition datasets, like the [wetlab](http://earth.informatik.uni-freiburg.de/datasets/ubicomp2015) with is encoded in multiple matroska files. You can download an example file [here](http://earth.informatik.uni-freiburg.de/uploads/104.mkv), which contains video, audio and subtitle streams with a name tag. The video contains secondary evidence, audio streams encode sensor data (acceleration in this example), and the subtitle stream contains the ground-truth data. You can read, for example, read the sensor and groundtruth data with:

```
from av.io import read, annotate

acc, groundtruth = read('a: s:', file='104.mkv')
print(acc.info, acc.shape, len(gt))
av.AudioStream #1 flac at 50Hz, 3.0, s16 at 0x7f3ec930e440 (122880, 3)

# getting from a list of labels to an array of labels in-sync with sensordata
labels = annotate(acc, groundtruth)
print(labels.shape)
(122880, )
```

More example are in the [tutorial/](tutorial/) directory.

Introduction to pyav
--------------------

[![Travis Build Status][travis-badge]][travis] [![AppVeyor Build Status][appveyor-badge]][appveyor] \
>>>>>>> more info in the READMe
[![Gitter Chat][gitter-badge]][gitter] [![Documentation][docs-badge]][docs] \

PyAV is a Pythonic binding for the [FFmpeg][ffmpeg] libraries. We aim to provide all of the power and control of the underlying library, but manage the gritty details as much as possible.

PyAV is for direct and precise access to your media via containers, streams, packets, codecs, and frames. It exposes a few transformations of that data, and helps you get your data to/from other packages (e.g. Numpy and Pillow).

This power does come with some responsibility as working with media is horrendously complicated and PyAV can't abstract it away or make all the best decisions for you. If the `ffmpeg` command does the job without you bending over backwards, PyAV is likely going to be more of a hindrance than a help.

But where you can't work without it, PyAV is a critical tool.


Installation
------------

Due to the complexity of the dependencies, PyAV is not always the easiest Python package to install. The most straight-foward install is via [conda-forge][conda-forge]:

```
conda install av -c conda-forge
```

See the [Conda quick install][conda-install] docs to get started with (mini)Conda.

If you want to use your existing FFmpeg/Libav, the C-source version of PyAV is on [PyPI][pypi]:

```
pip install av
```

And if you want to build from the absolute source (for development or testing):

```
git clone git@github.com:mikeboers/PyAV
cd PyAV
source scripts/activate.sh

# Either install the testing dependencies:
pip install --upgrade -r tests/requirements.txt
# or have it all, including FFmpeg, built/installed for you:
./scripts/build-deps

# Build PyAV.
make
```

---

Have fun, [read the docs][docs], [come chat with us][gitter], and good luck!



[conda-badge]: https://img.shields.io/conda/vn/conda-forge/av.svg?colorB=CCB39A
[conda]: https://anaconda.org/conda-forge/av
[docs-badge]: https://img.shields.io/badge/docs-on%20mikeboers.com-blue.svg
[docs]: http://docs.mikeboers.com/pyav/develop/
[gitter-badge]: https://img.shields.io/gitter/room/nwjs/nw.js.svg?logo=gitter&colorB=cc2b5e
[gitter]: https://gitter.im/mikeboers/PyAV
[pypi-badge]: https://img.shields.io/pypi/v/av.svg?colorB=CCB39A
[pypi]: https://pypi.org/project/av

[github-tests-badge]: https://github.com/mikeboers/PyAV/workflows/tests/badge.svg
[github-tests]: https://github.com/mikeboers/PyAV/actions?workflow=tests
[github-badge]: https://img.shields.io/badge/dynamic/xml.svg?label=github&url=https%3A%2F%2Fraw.githubusercontent.com%2Fmikeboers%2FPyAV%2Fdevelop%2FVERSION.txt&query=.&colorB=CCB39A&prefix=v
[github]: https://github.com/mikeboers/PyAV

[ffmpeg]: http://ffmpeg.org/
[conda-forge]: https://conda-forge.github.io/
[conda-install]: https://conda.io/docs/install/quick.html

