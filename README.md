
My `f`, `g` and `m` commands

The `fgm` package remembers the matches returned by `find`
and `grep` commands and lets you refer to those results by
numeric id for use in other commands.

Example:

    $ build fgm.bash.inc      # produces fgm.bash
    $ source fgm.bash

    # find .js files
    $ f .js
    1 foo.js
    2 test/bar.js
    3.test/baz.js
    4 app/main/js

    # run `wc` on the third match
    $ m 3 wc

    $ g newtype Int
    1 ./src/Name/Id.hs:75:newtype Id = Id Int
    2 ./src/Name/Id.hs:100:newtype IdSet = IdSet IS.IntSet
    3 ./src/Util/GMap.hs:17:newtype instance GSet Int = GSetInt IS.IntSet
    ...

    # open vi on the second match
    $ m 2 vi

