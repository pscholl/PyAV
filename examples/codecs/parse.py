import av
import av.datasets


# We want an H.264 stream in the Annex B byte-stream format.
# You can get this from the `bistream.py` example.
fh = open('night-sky.h264', 'rb')

codec = av.CodecContext.create('h264', 'r')

while True:

    chunk = fh.read(1 << 16)

    packets = codec.parse(chunk)
    print("Parsed {} packets from {} bytes:".format(len(packets), len(chunk)))

    for packet in packets:

        print('   ', packet)

        frames = codec.decode(packet)
        for frame in frames:
            print('       ', frame)

    # We wait until the end to bail so that the last empty `buf` flushes
    # the parser.
    if not chunk:
        break
