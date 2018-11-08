from __future__ import print_function

import sys
import re


mode = None
mode_transitions = {
    (None, 'python'): '\n\n::\n\n',
    ('rst', 'python'): '\n\n::\n\n',
    ('rst', 'bash'): '\n\n.. code-block:: bash\n\n',
    ('rst', 'txt'): '\n\n.. code-block:: none\n\n',
}

input_ = sys.stdin.read()
input_ = input_.strip()
lines = input_.splitlines()

for line in lines:

    line = line.rstrip()

    start_mode = mode

    # Skip opening blank lines.
    if not mode:
        if not line:
            continue
        mode = 'python'

    if re.match(r'\s*## (bash|txt)$', line):
        start_mode = 'rst'
        mode = line.split()[-1]

    elif mode == 'python' and re.match('\\s*(\'\'\'|""")', line):
        mode = 'rst'

    elif mode == 'rst' and re.search('(\'\'\'|""")$', line):
        mode = 'python'

    transition = mode_transitions.get((start_mode, mode))
    if transition:
        sys.stdout.write(transition)

    if mode in ('python', 'txt', 'bash'):
        print('    {}'.format(line))

    elif mode in ('rst', ):
        print(line)

    else:
        raise ValueError("Unknown mode {!r}.".format(mode))




