{-# LANGUAGE MultiWayIf #-}

module Oracles.Flag (
    Flag (..), flag, getFlag,
    platformSupportsSharedLibs,
    platformSupportsGhciObjects,
    targetSupportsSMP,
    useLibffiForAdjustors,
    arSupportsDashL
    ) where

import Hadrian.Oracles.TextFile
import Hadrian.Expression

import Base
import Oracles.Setting

data Flag = ArSupportsAtFile
          | ArSupportsDashL
          | SystemArSupportsDashL
          | CrossCompiling
          | CcLlvmBackend
          | GhcUnregisterised
          | TablesNextToCode
          | GmpInTree
          | GmpFrameworkPref
          | LeadingUnderscore
          | SolarisBrokenShld
          | WithLibdw
          | WithLibnuma
          | HaveLibMingwEx
          | UseSystemFfi
          | BootstrapThreadedRts
          | BootstrapEventLoggingRts
          | UseLibffiForAdjustors

-- Note, if a flag is set to empty string we treat it as set to NO. This seems
-- fragile, but some flags do behave like this.
flag :: Flag -> Action Bool
flag f = do
    let key = case f of
            ArSupportsAtFile     -> "ar-supports-at-file"
            ArSupportsDashL      -> "ar-supports-dash-l"
            SystemArSupportsDashL-> "system-ar-supports-dash-l"
            CrossCompiling       -> "cross-compiling"
            CcLlvmBackend        -> "cc-llvm-backend"
            GhcUnregisterised    -> "ghc-unregisterised"
            TablesNextToCode     -> "tables-next-to-code"
            GmpInTree            -> "intree-gmp"
            GmpFrameworkPref     -> "gmp-framework-preferred"
            LeadingUnderscore    -> "leading-underscore"
            SolarisBrokenShld    -> "solaris-broken-shld"
            WithLibdw            -> "with-libdw"
            WithLibnuma          -> "with-libnuma"
            HaveLibMingwEx       -> "have-lib-mingw-ex"
            UseSystemFfi         -> "use-system-ffi"
            BootstrapThreadedRts -> "bootstrap-threaded-rts"
            BootstrapEventLoggingRts -> "bootstrap-event-logging-rts"
            UseLibffiForAdjustors -> "use-libffi-for-adjustors"
    value <- lookupSystemConfig key
    when (value `notElem` ["YES", "NO", ""]) . error $ "Configuration flag "
        ++ quote (key ++ " = " ++ value) ++ " cannot be parsed."
    return $ value == "YES"

-- | Get a configuration setting.
getFlag :: Flag -> Expr c b Bool
getFlag = expr . flag

-- | Does the platform support object merging (and therefore we can build GHCi objects
-- when appropriate).
platformSupportsGhciObjects :: Action Bool
platformSupportsGhciObjects =
    not . null <$> settingsFileSetting SettingsFileSetting_MergeObjectsCommand

arSupportsDashL :: Stage -> Action Bool
arSupportsDashL (Stage0 {}) = flag SystemArSupportsDashL
arSupportsDashL _           = flag ArSupportsDashL

platformSupportsSharedLibs :: Action Bool
platformSupportsSharedLibs = do
    windows       <- isWinTarget
    ppc_linux     <- anyTargetPlatform [ "powerpc-unknown-linux" ]
    solaris       <- anyTargetPlatform [ "i386-unknown-solaris2" ]
    solarisBroken <- flag SolarisBrokenShld
    return $ not (windows || ppc_linux || solaris && solarisBroken)

-- | Does the target support the threaded runtime system?
targetSupportsSMP :: Action Bool
targetSupportsSMP = do
  unreg <- flag GhcUnregisterised
  armVer <- targetArmVersion
  goodArch <- anyTargetArch ["i386"
                            , "x86_64"
                            , "powerpc"
                            , "powerpc64"
                            , "powerpc64le"
                            , "arm"
                            , "aarch64"
                            , "s390x"
                            , "riscv64"]
  if   -- The THREADED_RTS requires `BaseReg` to be in a register and the
       -- Unregisterised mode doesn't allow that.
     | unreg                -> return False
       -- We don't support load/store barriers pre-ARMv7. See #10433.
     | Just ver <- armVer
     , ver < ARMv7          -> return False
     | goodArch             -> return True
     | otherwise            -> return False

useLibffiForAdjustors :: Action Bool
useLibffiForAdjustors = flag UseLibffiForAdjustors
