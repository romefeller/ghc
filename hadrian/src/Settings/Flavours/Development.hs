module Settings.Flavours.Development (developmentFlavour) where

import qualified Data.Set as Set

import Expression
import Flavour
import Packages
import {-# SOURCE #-} Settings.Default

-- Please update doc/flavours.md when changing this file.
developmentFlavour :: Stage -> Flavour
developmentFlavour ghcStage = defaultFlavour
    { name = "devel" ++ stageString ghcStage
    , args = defaultBuilderArgs <> developmentArgs ghcStage <> defaultPackageArgs
    , libraryWays = pure $ Set.fromList [vanilla]
    , rtsWays = pure $ Set.fromList [vanilla, debug, threaded, threadedDebug]
    , dynamicGhcPrograms = return False
    , ghcDebugAssertions = (>= Stage2) }
    where
      stageString Stage2 = "2"
      stageString Stage1 = "1"
      stageString Stage3 = "3"
      stageString s = error ("developmentFlavour not support for " ++ show s)

developmentArgs :: Stage -> Args
developmentArgs ghcStage = do
    stage <- getStage
    sourceArgs SourceArgs
        { hsDefault  = mconcat [ pure ["-O", "-H64m"],
                                 -- Disable optimization when building Cabal;
                                 -- this saves many minutes of build time.
                                 package cabal ? pure ["-O0"]]
        , hsLibrary  = notStage0 ? arg "-dlint"
        , hsCompiler = mconcat [stage0 ? arg "-O2",
                                 stage == predStage ghcStage ? pure ["-O0"]]
        , hsGhc      = stage == predStage ghcStage ? pure ["-O0"] }
