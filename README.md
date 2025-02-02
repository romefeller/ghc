The Glasgow Haskell Compiler
============================

[![pipeline status](https://gitlab.haskell.org/ghc/ghc/badges/master/pipeline.svg?style=flat)](https://gitlab.haskell.org/ghc/ghc/commits/master)

This is the source tree for [GHC][1], a compiler and interactive
environment for the Haskell functional programming language.

For more information, visit [GHC's web site][1].

Information for developers of GHC can be found on the [GHC issue tracker][2], and you can also view [proposals for new GHC features][13].


Getting the Source
==================

There are two ways to get a source tree:

 1. *Download source tarballs*

    Download the GHC source distribution:

        ghc-<version>-src.tar.xz

    which contains GHC itself and the "boot" libraries.

 2. *Check out the source code from git*

        $ git clone --recurse-submodules git@gitlab.haskell.org:ghc/ghc.git

    Note: cloning GHC from Github requires a special setup. See [Getting a GHC
    repository from Github][7].

  *See the GHC team's working conventions regarding [how to contribute a patch to GHC](https://gitlab.haskell.org/ghc/ghc/wikis/working-conventions/fixing-bugs).* First time contributors are encouraged to get started by just sending a Merge Request.


Building & Installing
=====================

For full information on building GHC, see the [GHC Building Guide][3].
Here follows a summary - if you get into trouble, the Building Guide
has all the answers.

Before building GHC you may need to install some other tools and
libraries.  See, [Setting up your system for building GHC][8].

*NB.* In particular, you need [GHC][1] installed in order to build GHC,
because the compiler is itself written in Haskell.  You also need
[Happy][4], [Alex][5], and [Cabal][9].  For instructions on how
to port GHC to a new platform, see the [GHC Building Guide][3].

For building library documentation, you'll need [Haddock][6].  To build
the compiler documentation, you need [Sphinx](http://www.sphinx-doc.org/)
and Xelatex (only for PDF output).

**Quick start**: GHC is built using the [Hadrian build system](hadrian/README.md).
The following gives you a default build:

    $ ./boot
    $ ./configure
    $ hadrian/build         # can also say '-jX' for X number of jobs

  On Windows, you need an extra repository containing some build tools.
  These can be downloaded for you by configure. This only needs to be done once by running:

    $ ./configure --enable-tarballs-autodownload

  Additionally, on Windows, to run Hadrian you should run `hadrian/build.bat`
  instead of `hadrian/build`.

(NB: **Do you have multiple cores? Be sure to tell that to `hadrian`!** This can
save you hours of build time depending on your system configuration, and is
almost always a win regardless of how many cores you have. As a simple rule,
you should have about N+1 jobs, where `N` is the amount of cores you have.)

The `./boot` step is only necessary if this is a tree checked out
from git.  For source distributions downloaded from [GHC's web site][1],
this step has already been performed.

These steps give you the default build, which includes everything
optimised and built in various ways (eg. profiling libs are built).
It can take a long time.  To customise the build, see the file `HACKING.md`.

Filing bugs and feature requests
================================

If you've encountered what you believe is a bug in GHC, or you'd like
to propose a feature request, please let us know! Submit an [issue][10] and we'll be sure to look into it. Remember:
**Filing a bug is the best way to make sure your issue isn't lost over
time**, so please feel free.

If you're an active user of GHC, you may also be interested in joining
the [glasgow-haskell-users][11] mailing list, where developers and
GHC users discuss various topics and hang out.

Hacking & Developing GHC
========================

Once you've filed a bug, maybe you'd like to fix it yourself? That
would be great, and we'd surely love your company! If you're looking
to hack on GHC, check out the guidelines in the `HACKING.md` file in
this directory - they'll get you up to speed quickly.

Contributors & Acknowledgements
===============================

GHC in its current form wouldn't exist without the hard work of
[its many contributors][12]. Over time, it has grown to include the
efforts and research of many institutions, highly talented people, and
groups from around the world. We'd like to thank them all, and invite
you to join!

  [1]:  http://www.haskell.org/ghc/            "www.haskell.org/ghc/"
  [2]:  https://gitlab.haskell.org/ghc/ghc/issues
          "gitlab.haskell.org/ghc/ghc/issues"
  [3]:  https://gitlab.haskell.org/ghc/ghc/wikis/building
          "https://gitlab.haskell.org/ghc/ghc/wikis/building"
  [4]:  http://www.haskell.org/happy/          "www.haskell.org/happy/"
  [5]:  http://www.haskell.org/alex/           "www.haskell.org/alex/"
  [6]:  http://www.haskell.org/haddock/        "www.haskell.org/haddock/"
  [7]: https://gitlab.haskell.org/ghc/ghc/wikis/building/getting-the-sources#cloning-from-github
          "https://gitlab.haskell.org/ghc/ghc/wikis/building/getting-the-sources#cloning-from-github"
  [8]:  https://gitlab.haskell.org/ghc/ghc/wikis/building/preparation
          "https://gitlab.haskell.org/ghc/ghc/wikis/building/preparation"
  [9]:  http://www.haskell.org/cabal/          "http://www.haskell.org/cabal/"
  [10]: https://gitlab.haskell.org/ghc/ghc/issues
          "https://gitlab.haskell.org/ghc/ghc/issues"
  [11]: http://www.haskell.org/pipermail/glasgow-haskell-users/
          "http://www.haskell.org/pipermail/glasgow-haskell-users/"
  [12]: https://gitlab.haskell.org/ghc/ghc/wikis/team-ghc
          "https://gitlab.haskell.org/ghc/ghc/wikis/team-ghc"
  [13]: https://github.com/ghc-proposals/ghc-proposals
          "https://github.com/ghc-proposals/ghc-proposals"
