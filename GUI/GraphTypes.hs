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
    , mergeHistoryLast2Entries
    )
    where

import GUI.GraphAbstraction(GraphInfo, initgraphs)
import GUI.ProofManagement (GUIMVar)
import GUI.UDGUtils

import Common.LibName
import Common.Id(nullRange)

import Driver.Options(HetcatsOpts(uncolored), defaultHetcatsOpts)

import Data.IORef
import qualified Data.Map as Map

import Control.Concurrent.MVar

import Interfaces.DataTypes
import Interfaces.Utils


data InternalNames = InternalNames
                     { showNames :: Bool
                     , updater :: [(String,(String -> String) -> IO ())]
                     }

-- | Global datatype for all GUI functions
data GInfo = GInfo
             { -- Global
               intState :: IORef IntState
             , hetcatsOpts :: HetcatsOpts
             , windowCount :: MVar Integer
             , exitMVar :: MVar ()
             , globalLock :: MVar ()
             , functionLock :: MVar ()
             , libGraphLock :: MVar ()
             , openGraphs :: IORef (Map.Map LIB_NAME GInfo)
               -- Local
             , libName :: LIB_NAME
             , graphInfo :: GraphInfo
             , internalNamesIORef :: IORef InternalNames
             , proofGUIMVar :: GUIMVar
             }

{- | Type of the convertGraph function. Used as type of a parameter of some
     functions in GraphMenu and GraphLogic. -}
type ConvFunc = GInfo -> String -> LibFunc -> IO ()

type LibFunc = GInfo -> IO ()

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
  intSt <- newIORef emptyIntState
  gi <- initgraphs
  oGraphs <- newIORef Map.empty
  iorIN <- newIORef $ InternalNames False []
  guiMVar <- newEmptyMVar
  gl <- newEmptyMVar
  fl <- newEmptyMVar
  exit <- newEmptyMVar
  lgl  <- newEmptyMVar
  wc <- newMVar 0
  return $ GInfo { -- Global
                   intState = intSt
                 , hetcatsOpts = defaultHetcatsOpts
                 , windowCount = wc
                 , exitMVar = exit
                 , globalLock = gl
                 , functionLock = fl
                 , libGraphLock = lgl
                 , openGraphs = oGraphs
                   -- Local
                 , libName = Lib_id $ Indirect_link "" nullRange "" noTime
                 , graphInfo = gi
                 , internalNamesIORef = iorIN
                 , proofGUIMVar = guiMVar
                 }

-- | Creates an empty GInfo
copyGInfo :: GInfo -> LIB_NAME -> IO GInfo
copyGInfo gInfo ln = do
  gi <- initgraphs
  iorIN <- newIORef $ InternalNames False []
  guiMVar <- newEmptyMVar
  -- Change local parts
  let gInfo' = gInfo { libName = ln
                     , graphInfo = gi
                     , internalNamesIORef = iorIN
                     , proofGUIMVar = guiMVar
                     }
  oGraphs <- readIORef $ openGraphs gInfo
  writeIORef (openGraphs gInfo) $ Map.insert ln gInfo' oGraphs
  return gInfo'

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


-- combine last two history entries into one entry (both steps are undone
-- in one call
mergeHistoryLast2Entries :: GInfo -> IO ()
mergeHistoryLast2Entries gInfo = do
   ost <- readIORef $ intState gInfo
   let ulst = undoList $ i_hist ost
   case ulst of
    x:y:m -> do
              let z = Int_CmdHistoryDescription {
                          cmdName = (cmdName x) ++ "\n"++ (cmdName y),
                          cmdDescription = (cmdDescription x) ++
                                           (cmdDescription y) }
                  nwst= ost {
                         i_hist = (i_hist ost) {
                                     undoList = z:m
                                     }
                           }
              writeIORef (intState gInfo) nwst
              return ()
    _ -> return ()
