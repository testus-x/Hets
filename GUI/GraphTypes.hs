{- |
Module      :  $Header$
Description :  Types for the Central GUI of Hets
Copyright   :  (c) Jorina Freya Gerken, Till Mossakowski, Uni Bremen 2002-2006
License     :  similar to LGPL, see HetCATS/LICENSE.txt or LIZENZ.txt

Maintainer  :  till@informatik.uni-bremen.de
Stability   :  provisional
Portability :  non-portable (imports Logic)
-}

module GUI.GraphTypes
    ( GInfo(..)
    , InternalNames(..)
    , ConvFunc
    , LibFunc
    , DaVinciGraphTypeSyn
    , Colors(..)
    , getColor
    , emptyGInfo
    , copyGInfo
    , lockGlobal
    , tryLockGlobal
    , unlockGlobal
    )
    where

import GUI.GraphAbstraction(GraphInfo, initgraphs)
import GUI.ProofManagement (GUIMVar)
import GUI.History(CommandHistory, emptyCommandHistory)

import Static.DevGraph

import Common.LibName
import Common.Id(nullRange)

import Driver.Options(HetcatsOpts(uncolored), defaultHetcatsOpts)

import Data.IORef
import qualified Data.Map as Map

import Control.Concurrent.MVar

import DaVinciGraph
import GraphDisp

data InternalNames = InternalNames
                     { showNames :: Bool
                     , updater :: [(String,(String -> String) -> IO ())]
                     }

-- | Global datatype for all GUI functions
data GInfo = GInfo
             { -- Global
               libEnvIORef :: IORef LibEnv
             , gi_hetcatsOpts :: HetcatsOpts
             , windowCount :: MVar Integer
             , exitMVar :: MVar ()
             , globalLock :: MVar ()
             , globalHist :: MVar ([[LIB_NAME]],[[LIB_NAME]])
             , commandHist :: CommandHistory
             , functionLock :: MVar ()
               -- Local
             , gi_LIB_NAME :: LIB_NAME
             , gi_GraphInfo :: GraphInfo
             , internalNamesIORef :: IORef InternalNames
             , proofGUIMVar :: GUIMVar
             }

{- | Type of the convertGraph function. Used as type of a parameter of some
     functions in GraphMenu and GraphLogic. -}
type ConvFunc = GInfo -> String -> LibFunc -> IO ()

type LibFunc =  GInfo -> IO DaVinciGraphTypeSyn

type DaVinciGraphTypeSyn =
     Graph DaVinciGraph
           DaVinciGraphParms
           DaVinciNode
           DaVinciNodeType
           DaVinciNodeTypeParms
           DaVinciArc
           DaVinciArcType
           DaVinciArcTypeParms

-- | Colors to use.
data Colors = Black
            | Blue
            | Coral
            | Green
            | Yellow
            | Khaki
            deriving (Eq, Ord, Show)

-- | Creates an empty GInfo
emptyGInfo :: IO GInfo
emptyGInfo = do
  iorLE <- newIORef emptyLibEnv
  graphInfo <- initgraphs
  iorIN <- newIORef $ InternalNames False []
  guiMVar <- newEmptyMVar
  gl <- newEmptyMVar
  fl <- newEmptyMVar
  exit <- newEmptyMVar
  wc <- newMVar 0
  gh <- newMVar ([],[])
  ch <- emptyCommandHistory
  return $ GInfo { libEnvIORef = iorLE
                  , gi_LIB_NAME = Lib_id $ Indirect_link "" nullRange "" noTime
                 , gi_GraphInfo = graphInfo
                 , internalNamesIORef = iorIN
                 , gi_hetcatsOpts = defaultHetcatsOpts
                 , proofGUIMVar = guiMVar
                 , windowCount = wc
                 , exitMVar = exit
                 , globalLock = gl
                 , globalHist = gh
                 , commandHist = ch
                 , functionLock = fl
                 }

-- | Creates an empty GInfo
copyGInfo :: GInfo -> LIB_NAME -> IO GInfo
copyGInfo gInfo newLN = do
  graphInfo <- initgraphs
  iorIN <- newIORef $ InternalNames False []
  guiMVar <- newEmptyMVar
  return $ gInfo { gi_LIB_NAME = newLN
                 , gi_GraphInfo = graphInfo
                 , internalNamesIORef = iorIN
                 , proofGUIMVar = guiMVar
                 }

{- | Acquire the global lock. If already locked it waits till it is unlocked
     again.-}
lockGlobal :: GInfo -> IO ()
lockGlobal (GInfo { globalLock = lock }) = putMVar lock ()

-- | Tries to acquire the global lock. Return False if already acquired.
tryLockGlobal :: GInfo -> IO Bool
tryLockGlobal (GInfo { globalLock = lock }) = tryPutMVar lock ()

-- | Releases the global lock.
unlockGlobal :: GInfo -> IO ()
unlockGlobal (GInfo { globalLock = lock }) = do
  unlocked <- tryTakeMVar lock
  case unlocked of
    Just () -> return ()
    Nothing -> error "Global lock wasn't locked."

-- | Generates the colortable
colors :: Map.Map (Colors, Bool, Bool) (String, String)
colors = Map.fromList
  [ ((Black,  False, False), ("gray0",           "gray0" ))
  , ((Black,  False, True ), ("gray30",          "gray5" ))
  , ((Blue,   False, False), ("RoyalBlue3",      "gray20"))
  , ((Blue,   False, True ), ("RoyalBlue1",      "gray23"))
  , ((Blue,   True,  False), ("SteelBlue3",      "gray27"))
  , ((Blue,   True,  True ), ("SteelBlue1",      "gray30"))
  , ((Coral,  False, False), ("coral3",          "gray40"))
  , ((Coral,  False, True ), ("coral1",          "gray43"))
  , ((Coral,  True,  False), ("LightSalmon2",    "gray47"))
  , ((Coral,  True,  True ), ("LightSalmon",     "gray50"))
  , ((Green,  False, False), ("MediumSeaGreen",  "gray60"))
  , ((Green,  False, True ), ("PaleGreen3",      "gray63"))
  , ((Green,  True,  False), ("PaleGreen2",      "gray67"))
  , ((Green,  True,  True ), ("LightGreen",      "gray70"))
  , ((Yellow, False, False), ("gold2",           "gray78"))
  , ((Yellow, False, True ), ("gold",            "gray81"))
  , ((Khaki,  False, False), ("LightGoldenrod3", "gray85"))
  , ((Khaki,  False, True ), ("LightGoldenrod",  "gray88"))
  ]

-- | Converts colors to grayscale if needed
getColor :: HetcatsOpts
         -> Colors -- ^ Colorname
         -> Bool -- ^ Colorvariant
         -> Bool -- ^ Lightvariant
         -> String
getColor opts c v l = case Map.lookup (c, v, l) colors of
  Just (cname, gname) -> if uncolored opts then gname else cname
  Nothing -> error $ "Color not defined: "
                  ++ (if v then "alternative " else "")
                  ++ (if l then "light " else "")
                  ++ show c
